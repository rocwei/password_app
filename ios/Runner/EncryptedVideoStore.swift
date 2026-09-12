import Foundation
import CryptoKit
import Security
import Darwin

enum VideoVaultError: String, Error {
    case cancelled, locked, busy, invalidFile, unsupportedVersion, corruptFile
    case insufficientSpace, keyUnavailable, cleanupFailed, ioFailure
}

struct EncryptedVideoInfo: Codable {
    let id: String
    let name: String
    let size: Int64
    let importedAt: Double
    let fileExtension: String

    var dictionary: [String: Any] {
        ["id": id, "name": name, "size": size, "importedAt": importedAt,
         "fileExtension": fileExtension]
    }
}

// All entry points are synchronous and must run on a serial, non-main worker queue.
// Never retain a master key on the store between operations.
final class EncryptedVideoStore {
    private static let chunkSize = 1_048_576
    private static let maximumSize: Int64 = 1 << 40
    private static let maximumMetadataSize = 16_384
    private static let magic = Data("VIDVAULT".utf8)
    private let root: URL
    private let temporary: URL
    private let keyProvider: (() throws -> SymmetricKey)?
    private let service: String
    private let fm = FileManager.default
    private let operationLock = NSLock()

    init(root: URL? = nil, temporary: URL? = nil,
         keyProvider: (() throws -> SymmetricKey)? = nil) throws {
        let fm = FileManager.default
        self.root = try root ?? fm.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                      appropriateFor: nil, create: true)
            .appendingPathComponent("EncryptedVideos", isDirectory: true)
        self.temporary = try temporary ?? fm.url(for: .cachesDirectory, in: .userDomainMask,
                                                 appropriateFor: nil, create: true)
            .appendingPathComponent("EncryptedVideoTemporary", isDirectory: true)
        self.keyProvider = keyProvider
        self.service = (Bundle.main.bundleIdentifier ?? "native.video-vault") + ".video-vault"
        try perform {
            guard self.root.isFileURL, self.temporary.isFileURL else { throw VideoVaultError.invalidFile }
            let rootPath = self.root.resolvingSymlinksInPath().standardizedFileURL.path
            let tempPath = self.temporary.resolvingSymlinksInPath().standardizedFileURL.path
            guard rootPath != tempPath, !rootPath.hasPrefix(tempPath + "/"),
                  !tempPath.hasPrefix(rootPath + "/") else { throw VideoVaultError.invalidFile }
            try makeDirectory(self.root)
            try makeDirectory(self.temporary)
        }
    }

    func prepare() throws {
        try perform {
            try validateDirectories()
            try clean(root, matching: Self.isStaging)
            try clearTemporaryFiles()
        }
    }

    func list() throws -> [EncryptedVideoInfo] {
        try perform {
            try validateDirectories()
            let records = try recordDirectories()
            if records.isEmpty { return [] }
            let master = try masterKey(create: false)
            return try records.map { try readRecord($0, master: master).info }
                .sorted { $0.importedAt == $1.importedAt ? $0.id < $1.id : $0.importedAt > $1.importedAt }
        }
    }

    func importVideo(from source: URL, name: String, fileExtension: String,
                     cancelled: () -> Bool, progress: (Double) -> Void) throws -> EncryptedVideoInfo {
        try perform {
            try validateDirectories()
            try checkCancelled(cancelled)
            guard source.isFileURL, Self.validName(name), Self.validExtension(fileExtension) else {
                throw VideoVaultError.invalidFile
            }
            try requireType(source, .typeRegular, error: .invalidFile)
            let input = try FileHandle(forReadingFrom: source)
            defer { try? input.close() }
            var sourceStat = stat()
            guard fstat(input.fileDescriptor, &sourceStat) == 0,
                  (sourceStat.st_mode & S_IFMT) == S_IFREG,
                  sourceStat.st_size > 0, sourceStat.st_size <= Self.maximumSize else {
                throw VideoVaultError.invalidFile
            }
            let size = Int64(sourceStat.st_size)
            let count = (size + Int64(Self.chunkSize) - 1) / Int64(Self.chunkSize)
            try requireSpace(size + count * 28 + 64 + Int64(Self.maximumMetadataSize), at: root)
            let master = try masterKey(create: true)
            let id = UUID().uuidString
            let info = EncryptedVideoInfo(id: id, name: name, size: size,
                                          importedAt: Date().timeIntervalSince1970 * 1000,
                                          fileExtension: fileExtension.lowercased())
            let salt = try randomBytes(32)
            let header = Self.magic + Self.number(UInt32(1)) + Self.number(UInt32(Self.chunkSize))
                + Self.number(UInt64(size)) + Self.number(UInt64(count)) + salt
            let key = derivedKey(master, salt: salt, id: id)
            let encoded = try JSONEncoder().encode(info)
            let metadata = try seal(encoded, key: key, aad: header + Data(id.utf8) + Data("metadata".utf8))
            guard metadata.count <= Self.maximumMetadataSize else { throw VideoVaultError.invalidFile }
            let binding = header + Data(id.utf8) + Data(SHA256.hash(data: metadata)) + Data("chunk".utf8)
            let staging = root.appendingPathComponent(".staging-" + id, isDirectory: true)
            var output: FileHandle?
            do {
                try makeDirectory(staging)
                let metadataHandle = try createProtectedFile(staging.appendingPathComponent("metadata.bin"))
                do {
                    try write(metadata, to: metadataHandle)
                    try metadataHandle.synchronize()
                    try metadataHandle.close()
                } catch {
                    try? metadataHandle.close()
                    throw error
                }
                let content = try createProtectedFile(staging.appendingPathComponent("content.bin"))
                output = content
                try write(header, to: content)
                progress(0)
                var consumed: Int64 = 0
                for index in 0..<count {
                    try autoreleasepool {
                        try checkCancelled(cancelled)
                        let length = Int(min(Int64(Self.chunkSize), size - consumed))
                        let plaintext = try readExactly(input, count: length, error: .invalidFile)
                        let encrypted = try seal(plaintext, key: key,
                                                 aad: binding + Self.number(UInt64(index)))
                        try write(encrypted, to: content)
                        consumed += Int64(length)
                        progress(Double(consumed) / Double(size))
                    }
                }
                guard try read(input, count: 1).isEmpty else { throw VideoVaultError.invalidFile }
                var finalStat = stat()
                guard fstat(input.fileDescriptor, &finalStat) == 0, finalStat.st_size == sourceStat.st_size,
                      finalStat.st_mtimespec.tv_sec == sourceStat.st_mtimespec.tv_sec,
                      finalStat.st_mtimespec.tv_nsec == sourceStat.st_mtimespec.tv_nsec else {
                    throw VideoVaultError.invalidFile
                }
                try content.synchronize()
                try content.close()
                output = nil
                try checkCancelled(cancelled)
                // A same-parent rename publishes both files together, never a partial record.
                try fm.moveItem(at: staging, to: root.appendingPathComponent(id, isDirectory: true))
                return info
            } catch {
                try? output?.close()
                try removeAfterFailure(staging)
                throw error
            }
        }
    }

    func decrypt(id: String, cancelled: () -> Bool, progress: (Double) -> Void) throws -> URL {
        try perform {
            let directory = try recordURL(id)
            try checkCancelled(cancelled)
            let record = try readRecord(directory, master: masterKey(create: false))
            try requireSpace(record.info.size, at: temporary)
            let destination = temporary.appendingPathComponent("video-" + UUID().uuidString + "." + record.info.fileExtension)
            let input = try FileHandle(forReadingFrom: directory.appendingPathComponent("content.bin"))
            defer { try? input.close() }
            guard try readExactly(input, count: 64) == record.header else { throw VideoVaultError.corruptFile }
            var output: FileHandle?
            do {
                let plaintext = try createProtectedFile(destination)
                output = plaintext
                progress(0)
                var written: Int64 = 0
                for index in 0..<record.count {
                    try autoreleasepool {
                        try checkCancelled(cancelled)
                        let length = Int(min(Int64(Self.chunkSize), record.info.size - written))
                        let encrypted = try readExactly(input, count: length + 28)
                        let data = try unseal(encrypted, key: record.key,
                                              aad: record.binding + Self.number(UInt64(index)))
                        guard data.count == length else { throw VideoVaultError.corruptFile }
                        try write(data, to: plaintext)
                        written += Int64(data.count)
                        progress(Double(written) / Double(record.info.size))
                    }
                }
                guard written == record.info.size, try read(input, count: 1).isEmpty else {
                    throw VideoVaultError.corruptFile
                }
                try plaintext.synchronize()
                try plaintext.close()
                output = nil
                try checkCancelled(cancelled)
                return destination
            } catch {
                try? output?.close()
                try removeAfterFailure(destination)
                throw error
            }
        }
    }

    func delete(id: String) throws {
        try perform {
            let directory = try recordURL(id)
            try removeAfterFailure(directory)
        }
    }

    func clearTemporary() throws {
        try perform {
            try validateDirectories()
            try clearTemporaryFiles()
        }
    }

    func removeTemporary(url: URL) throws {
        try perform {
            guard url.isFileURL, url.host == temporary.host, url.query == nil, url.fragment == nil,
                  url.deletingLastPathComponent().path == temporary.path,
                  Self.isTemporary(url.lastPathComponent) else { throw VideoVaultError.invalidFile }
            try validateDirectories()
            if let type = try existingType(url) {
                guard type == .typeRegular else { throw VideoVaultError.invalidFile }
                try removeAfterFailure(url)
            }
        }
    }

    func deleteAll() throws {
        try perform {
            try validateDirectories()
            var failed = false
            do { try clean(root, matching: { Self.isRecord($0) || Self.isStaging($0) }) } catch { failed = true }
            do { try clearTemporaryFiles() } catch { failed = true }
            guard !failed else { throw VideoVaultError.cleanupFailed }
            // Injected providers have no keychain side effects, including deletion.
            if keyProvider == nil {
                let status = SecItemDelete(keyQuery() as CFDictionary)
                guard status == errSecSuccess || status == errSecItemNotFound else { throw keychainError(status) }
            }
        }
    }

    private struct Record {
        let info: EncryptedVideoInfo
        let header: Data
        let count: Int64
        let key: SymmetricKey
        let binding: Data
    }

    private func readRecord(_ directory: URL, master: SymmetricKey) throws -> Record {
        try requireType(directory, .typeDirectory, error: .corruptFile)
        let contentURL = directory.appendingPathComponent("content.bin")
        let metadataURL = directory.appendingPathComponent("metadata.bin")
        let contentSize = try regularSize(contentURL)
        let metadataSize = try regularSize(metadataURL)
        guard contentSize >= 64, metadataSize >= 28, metadataSize <= Int64(Self.maximumMetadataSize) else {
            throw VideoVaultError.corruptFile
        }
        let content = try FileHandle(forReadingFrom: contentURL)
        defer { try? content.close() }
        let header = try readExactly(content, count: 64)
        guard header.prefix(8) == Self.magic else { throw VideoVaultError.corruptFile }
        guard Self.integer(header, 8, 4) == 1 else { throw VideoVaultError.unsupportedVersion }
        let length = Self.integer(header, 16, 8)
        let count = Self.integer(header, 24, 8)
        guard Self.integer(header, 12, 4) == UInt64(Self.chunkSize), length > 0,
              length <= UInt64(Self.maximumSize),
              count == (length + UInt64(Self.chunkSize) - 1) / UInt64(Self.chunkSize),
              UInt64(contentSize) == 64 + length + count * 28 else { throw VideoVaultError.corruptFile }
        let id = directory.lastPathComponent
        guard Self.isRecord(id), UUID(uuidString: id)?.uuidString == id else { throw VideoVaultError.corruptFile }
        let key = derivedKey(master, salt: Data(header[32..<64]), id: id)
        let metadataHandle = try FileHandle(forReadingFrom: metadataURL)
        defer { try? metadataHandle.close() }
        let metadata = try readExactly(metadataHandle, count: Int(metadataSize))
        guard try read(metadataHandle, count: 1).isEmpty else { throw VideoVaultError.corruptFile }
        let encoded = try unseal(metadata, key: key, aad: header + Data(id.utf8) + Data("metadata".utf8))
        let info: EncryptedVideoInfo
        do { info = try JSONDecoder().decode(EncryptedVideoInfo.self, from: encoded) }
        catch { throw VideoVaultError.corruptFile }
        guard info.id == id, info.size == Int64(length), Self.validName(info.name),
              Self.validExtension(info.fileExtension), info.fileExtension == info.fileExtension.lowercased(),
              info.importedAt.isFinite, info.importedAt >= 0 else { throw VideoVaultError.corruptFile }
        return Record(info: info, header: header, count: Int64(count), key: key,
                      binding: header + Data(id.utf8) + Data(SHA256.hash(data: metadata)) + Data("chunk".utf8))
    }

    private func perform<T>(_ body: () throws -> T) throws -> T {
        guard !Thread.isMainThread, operationLock.try() else { throw VideoVaultError.busy }
        defer { operationLock.unlock() }
        do { return try body() } catch let error as VideoVaultError { throw error }
        catch { throw mappedError(error) }
    }

    private func mappedError(_ error: Error) -> VideoVaultError {
        let error = error as NSError
        if error.domain == NSCocoaErrorDomain {
            if error.code == NSFileWriteOutOfSpaceError { return .insufficientSpace }
            if error.code == NSFileReadNoPermissionError || error.code == NSFileWriteNoPermissionError { return .locked }
        }
        if error.domain == NSPOSIXErrorDomain {
            if error.code == Int(ENOSPC) || error.code == Int(EDQUOT) { return .insufficientSpace }
            if error.code == Int(EACCES) || error.code == Int(EPERM) { return .locked }
        }
        if let underlying = error.userInfo[NSUnderlyingErrorKey] as? Error { return mappedError(underlying) }
        return .ioFailure
    }

    private func checkCancelled(_ cancelled: () -> Bool) throws {
        if cancelled() { throw VideoVaultError.cancelled }
    }

    private static func validName(_ name: String) -> Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && name.utf8.count <= 1024
            && !name.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) })
    }

    private static func validExtension(_ value: String) -> Bool {
        !value.isEmpty && value.utf8.count <= 16 && value.utf8.allSatisfy {
            (48...57).contains($0) || (65...90).contains($0) || (97...122).contains($0)
        }
    }

    private static func isRecord(_ name: String) -> Bool {
        name.utf8.count == 36 && UUID(uuidString: name)?.uuidString == name.uppercased()
    }

    private static func isStaging(_ name: String) -> Bool {
        name.hasPrefix(".staging-") && isRecord(String(name.dropFirst(9)))
    }

    private static func isTemporary(_ name: String) -> Bool {
        guard name.hasPrefix("video-") else { return false }
        let parts = name.dropFirst(6).split(separator: ".", omittingEmptySubsequences: false)
        return parts.count == 2 && isRecord(String(parts[0])) && validExtension(String(parts[1]))
    }

    private func recordURL(_ id: String) throws -> URL {
        guard Self.isRecord(id), let uuid = UUID(uuidString: id) else { throw VideoVaultError.invalidFile }
        try validateDirectories()
        return root.appendingPathComponent(uuid.uuidString, isDirectory: true)
    }

    private func recordDirectories() throws -> [URL] {
        try fm.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)
            .filter { Self.isRecord($0.lastPathComponent) }
    }

    private func validateDirectories() throws {
        try requireType(root, .typeDirectory, error: .invalidFile)
        if let type = try existingType(temporary) {
            guard type == .typeDirectory else { throw VideoVaultError.invalidFile }
        } else {
            try makeDirectory(temporary)
        }
    }

    private func existingType(_ url: URL) throws -> FileAttributeType? {
        do {
            let attributes = try fm.attributesOfItem(atPath: url.path)
            guard let type = attributes[.type] as? FileAttributeType else { throw VideoVaultError.invalidFile }
            return type
        } catch let error as NSError {
            if error.domain == NSCocoaErrorDomain,
               error.code == NSFileNoSuchFileError || error.code == NSFileReadNoSuchFileError { return nil }
            throw error
        }
    }

    private func requireType(_ url: URL, _ type: FileAttributeType, error: VideoVaultError) throws {
        let attributes = try fm.attributesOfItem(atPath: url.path)
        guard attributes[.type] as? FileAttributeType == type else { throw error }
    }

    private func regularSize(_ url: URL) throws -> Int64 {
        let attributes = try fm.attributesOfItem(atPath: url.path)
        guard attributes[.type] as? FileAttributeType == .typeRegular,
              let size = attributes[.size] as? NSNumber, size.int64Value >= 0 else { throw VideoVaultError.corruptFile }
        return size.int64Value
    }

    private var protectionAttributes: [FileAttributeKey: Any] {
        var attributes: [FileAttributeKey: Any] = [.posixPermissions: 0o600]
        #if os(iOS)
        attributes[.protectionKey] = FileProtectionType.complete
        #endif
        return attributes
    }

    private func makeDirectory(_ url: URL) throws {
        var attributes = protectionAttributes
        attributes[.posixPermissions] = 0o700
        if let type = try existingType(url) {
            guard type == .typeDirectory else { throw VideoVaultError.invalidFile }
            try fm.setAttributes(attributes, ofItemAtPath: url.path)
        } else {
            try fm.createDirectory(at: url, withIntermediateDirectories: true, attributes: attributes)
        }
        var protectedURL = url
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try protectedURL.setResourceValues(values)
    }

    private func createProtectedFile(_ url: URL) throws -> FileHandle {
        var options: Data.WritingOptions = [.withoutOverwriting]
        #if os(iOS)
        options.insert(.completeFileProtection)
        #endif
        try Data().write(to: url, options: options)
        try fm.setAttributes(protectionAttributes, ofItemAtPath: url.path)
        // The file and its parent have complete protection before any plaintext is written.
        var protectedURL = url
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try protectedURL.setResourceValues(values)
        return try FileHandle(forWritingTo: url)
    }

    private func requireSpace(_ bytes: Int64, at url: URL) throws {
        let attributes = try fm.attributesOfFileSystem(forPath: url.path)
        guard let free = attributes[.systemFreeSize] as? NSNumber else { throw VideoVaultError.ioFailure }
        guard free.int64Value >= bytes + 8 * 1024 * 1024 else { throw VideoVaultError.insufficientSpace }
    }

    private func clearTemporaryFiles() throws {
        try clean(temporary, matching: Self.isTemporary)
    }

    private func clean(_ directory: URL, matching predicate: (String) -> Bool) throws {
        let entries: [URL]
        do { entries = try fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) }
        catch { throw VideoVaultError.cleanupFailed }
        var failed = false
        for entry in entries where predicate(entry.lastPathComponent) {
            do { try fm.removeItem(at: entry) } catch { failed = true }
        }
        if failed { throw VideoVaultError.cleanupFailed }
    }

    private func removeAfterFailure(_ url: URL) throws {
        do { try fm.removeItem(at: url) }
        catch let error as NSError {
            if error.domain == NSCocoaErrorDomain && error.code == NSFileNoSuchFileError { return }
            throw VideoVaultError.cleanupFailed
        }
    }

    private static func number<T: FixedWidthInteger>(_ value: T) -> Data {
        var bigEndian = value.bigEndian
        return withUnsafeBytes(of: &bigEndian) { Data($0) }
    }

    private static func integer(_ data: Data, _ offset: Int, _ count: Int) -> UInt64 {
        data[offset..<(offset + count)].reduce(UInt64(0)) { ($0 << 8) | UInt64($1) }
    }

    private func readExactly(_ handle: FileHandle, count: Int,
                             error: VideoVaultError = .corruptFile) throws -> Data {
        guard count >= 0, count <= Self.chunkSize + 28 else { throw error }
        var result = Data()
        result.reserveCapacity(count)
        while result.count < count {
            let part = try read(handle, count: count - result.count)
            guard !part.isEmpty else { throw error }
            result.append(part)
        }
        return result
    }

    // The throwing FileHandle read/write overloads require iOS 13.4.
    private func read(_ handle: FileHandle, count: Int) throws -> Data {
        guard count > 0, count <= Self.chunkSize + 28 else { throw VideoVaultError.corruptFile }
        var data = Data(count: count)
        let length = try data.withUnsafeMutableBytes { buffer -> Int in
            while true {
                let result = Darwin.read(handle.fileDescriptor, buffer.baseAddress!, count)
                if result >= 0 { return result }
                if errno != EINTR { throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno)) }
            }
        }
        data.count = length
        return data
    }

    private func write(_ data: Data, to handle: FileHandle) throws {
        try data.withUnsafeBytes { buffer in
            var offset = 0
            while offset < buffer.count {
                let result = Darwin.write(handle.fileDescriptor, buffer.baseAddress!.advanced(by: offset), buffer.count - offset)
                if result > 0 { offset += result }
                else if result == 0 { throw VideoVaultError.ioFailure }
                else if errno != EINTR { throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno)) }
            }
        }
    }

    private func randomBytes(_ count: Int) throws -> Data {
        var bytes = Data(count: count)
        let status = bytes.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, count, $0.baseAddress!) }
        guard status == errSecSuccess else { throw VideoVaultError.keyUnavailable }
        return bytes
    }

    private func derivedKey(_ master: SymmetricKey, salt: Data, id: String) -> SymmetricKey {
        // RFC 5869 extract + one 32-byte expand block; CryptoKit HKDF starts at iOS 14.
        let material = master.withUnsafeBytes { Data($0) }
        let extracted = HMAC<SHA256>.authenticationCode(for: material, using: SymmetricKey(data: salt))
        let expanded = HMAC<SHA256>.authenticationCode(for: Data(("video-vault-v1:" + id).utf8) + Data([1]),
                                                      using: SymmetricKey(data: extracted))
        return SymmetricKey(data: expanded)
    }

    private func seal(_ data: Data, key: SymmetricKey, aad: Data) throws -> Data {
        guard let combined = try AES.GCM.seal(data, using: key, authenticating: aad).combined else {
            throw VideoVaultError.ioFailure
        }
        return combined
    }

    private func unseal(_ data: Data, key: SymmetricKey, aad: Data) throws -> Data {
        do { return try AES.GCM.open(AES.GCM.SealedBox(combined: data), using: key, authenticating: aad) }
        catch { throw VideoVaultError.corruptFile }
    }

    private func keyQuery() -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
         kSecAttrAccount as String: "master-key", kSecAttrSynchronizable as String: false]
    }

    private func masterKey(create: Bool) throws -> SymmetricKey {
        if let provider = keyProvider {
            let key = try provider()
            guard key.bitCount == 256 else { throw VideoVaultError.keyUnavailable }
            return key
        }
        var query = keyQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var value: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &value)
        if status == errSecSuccess {
            guard let data = value as? Data, data.count == 32 else { throw VideoVaultError.keyUnavailable }
            return SymmetricKey(data: data)
        }
        guard status == errSecItemNotFound else { throw keychainError(status) }
        let hasCiphertext = try fm.contentsOfDirectory(atPath: root.path)
            .contains { Self.isRecord($0) || Self.isStaging($0) }
        guard create, !hasCiphertext else { throw VideoVaultError.keyUnavailable }
        let data = try randomBytes(32)
        var insertion = keyQuery()
        insertion[kSecValueData as String] = data
        insertion[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        let result = SecItemAdd(insertion as CFDictionary, nil)
        if result == errSecDuplicateItem { return try masterKey(create: false) }
        guard result == errSecSuccess else { throw keychainError(result) }
        return SymmetricKey(data: data)
    }

    private func keychainError(_ status: OSStatus) -> VideoVaultError {
        status == errSecInteractionNotAllowed ? .locked : .keyUnavailable
    }
}
