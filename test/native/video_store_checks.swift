import Foundation
import CryptoKit

// swiftc -O -module-cache-path /tmp/video-vault-module-cache ios/Runner/EncryptedVideoStore.swift test/native/video_store_checks.swift -o /tmp/video_store_checks
// /usr/bin/time -l /tmp/video_store_checks --large
@main
enum VideoStoreChecks {
    static let chunk = 1_048_576
    static let fm = FileManager.default

    static func check(_ condition: @autoclosure () throws -> Bool, _ message: String) throws {
        if try !condition() { throw NSError(domain: "VideoStoreChecks", code: 1,
                                        userInfo: [NSLocalizedDescriptionKey: message]) }
    }

    static func expect(_ error: VideoVaultError, _ body: () throws -> Void) throws {
        do { try body() } catch let actual as VideoVaultError {
            try check(actual == error, "Expected \(error), got \(actual)")
            return
        }
        throw NSError(domain: "VideoStoreChecks", code: 2,
                      userInfo: [NSLocalizedDescriptionKey: "Expected \(error)"])
    }

    static func writeSource(_ url: URL, size: Int64) throws -> SHA256.Digest {
        try check(fm.createFile(atPath: url.path, contents: nil), "Create source")
        let handle = try FileHandle(forWritingTo: url)
        defer { try? handle.close() }
        let block = Data((0..<chunk).map { UInt8(truncatingIfNeeded: $0 &* 31 &+ $0 / 251) })
        var hash = SHA256()
        var remaining = size
        while remaining > 0 {
            try autoreleasepool {
                let data = Data(block.prefix(Int(min(Int64(chunk), remaining))))
                try handle.write(contentsOf: data)
                hash.update(data: data)
                remaining -= Int64(data.count)
            }
        }
        try handle.synchronize()
        return hash.finalize()
    }

    static func digest(_ url: URL) throws -> SHA256.Digest {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hash = SHA256()
        while try autoreleasepool(invoking: { () throws -> Bool in
            let data = try handle.read(upToCount: chunk) ?? Data()
            if data.isEmpty { return false }
            hash.update(data: data)
            return true
        }) {}
        return hash.finalize()
    }

    static func temporaryRecoveryChecks(in base: URL) throws {
        let root = base.appendingPathComponent("recovery-vault")
        let temporary = base.appendingPathComponent("recovery-temporary")
        let source = base.appendingPathComponent("recovery-source.mov")
        try Data([1, 2, 3, 4]).write(to: source)
        let store = try EncryptedVideoStore(root: root, temporary: temporary,
                                            keyProvider: { SymmetricKey(data: Data(repeating: 7, count: 32)) })
        let first = try store.importVideo(from: source, name: "First", fileExtension: "mov",
                                          cancelled: { false }, progress: { _ in })
        let second = try store.importVideo(from: source, name: "Second", fileExtension: "mov",
                                           cancelled: { false }, progress: { _ in })
        try fm.removeItem(at: temporary)
        try check(try store.list().count == 2, "List recovers missing temporary directory")
        try check(fm.fileExists(atPath: temporary.path), "List recreates cache")
        try fm.removeItem(at: temporary)
        try store.delete(id: second.id)
        try check(fm.fileExists(atPath: temporary.path), "Delete recreates cache")
        try check(!fm.fileExists(atPath: root.appendingPathComponent(second.id).path), "Delete succeeds without cache")
        try fm.removeItem(at: temporary)
        let a = try store.decrypt(id: first.id, cancelled: { false }, progress: { _ in })
        let b = try store.decrypt(id: first.id, cancelled: { false }, progress: { _ in })
        try check(try digest(a) == digest(source), "Decrypt recovers missing cache")
        try store.removeTemporary(url: a)
        try store.removeTemporary(url: a)
        try check(!fm.fileExists(atPath: a.path), "Targeted cleanup is idempotent")
        try check(try digest(b) == digest(source), "Targeted cleanup preserves other active plaintext")

        let outside = base.appendingPathComponent("video-\(UUID().uuidString).mov")
        try Data([9]).write(to: outside)
        let unrelated = temporary.appendingPathComponent("unrelated.mov")
        try Data([8]).write(to: unrelated)
        var remoteFile = URLComponents(url: a, resolvingAgainstBaseURL: false)!
        remoteFile.host = "other-host"
        for invalid in [outside, unrelated, temporary,
                        remoteFile.url!,
                        base.appendingPathComponent("recovery-temporary-other").appendingPathComponent(a.lastPathComponent),
                        temporary.appendingPathComponent("nested").appendingPathComponent(a.lastPathComponent),
                        URL(string: "https://example.com/" + a.lastPathComponent)!] {
            try expect(.invalidFile) { try store.removeTemporary(url: invalid) }
        }
        try check(try Data(contentsOf: outside) == Data([9]), "Outside file retained")
        try check(try Data(contentsOf: unrelated) == Data([8]), "Unrelated temporary file retained")
        let directory = temporary.appendingPathComponent("video-\(UUID().uuidString).mov")
        try fm.createDirectory(at: directory, withIntermediateDirectories: false)
        try expect(.invalidFile) { try store.removeTemporary(url: directory) }
        try fm.removeItem(at: directory)
        for destination in [outside, base.appendingPathComponent("missing-link-target")] {
            try fm.createSymbolicLink(at: a, withDestinationURL: destination)
            try expect(.invalidFile) { try store.removeTemporary(url: a) }
            try fm.removeItem(at: a)
        }

        try fm.removeItem(at: temporary)
        for destination in [base, base.appendingPathComponent("missing-directory")] {
            try fm.createSymbolicLink(at: temporary, withDestinationURL: destination)
            try expect(.invalidFile) { _ = try store.list() }
            try expect(.invalidFile) { try store.removeTemporary(url: a) }
            try expect(.invalidFile) { try store.deleteAll() }
            try fm.removeItem(at: temporary)
        }
        try Data([5]).write(to: temporary)
        try expect(.invalidFile) { try store.prepare() }
        try fm.removeItem(at: temporary)
        try store.removeTemporary(url: a)
        try check(fm.fileExists(atPath: temporary.path), "Targeted cleanup recovers absent cache")
        try fm.removeItem(at: temporary)
        try store.deleteAll()
        try check(fm.fileExists(atPath: temporary.path), "DeleteAll recreates cache")
        try check(try store.list().isEmpty, "DeleteAll succeeds without cache")
        try check(try Data(contentsOf: outside) == Data([9]), "Cache validation never deletes outside files")
        print("PASS: missing-cache recovery, scoped cleanup, outside paths, invalid entries, symlinks")
    }

    static func run() throws {
        let base = fm.temporaryDirectory.appendingPathComponent("video-store-checks-\(UUID().uuidString)")
        try fm.createDirectory(at: base, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: base) }
        let root = base.appendingPathComponent("vault")
        let temporary = base.appendingPathComponent("temporary")
        let key = SymmetricKey(data: Data(repeating: 0x42, count: 32))
        var keyReads = 0
        let store = try EncryptedVideoStore(root: root, temporary: temporary, keyProvider: {
            keyReads += 1
            return key
        })
        try store.prepare()
        try check(keyReads == 0, "prepare must not access the key")
        try check(try store.list().isEmpty, "New vault must be empty")
        try check(keyReads == 0, "Empty list must not access the key")
        let unrelated = temporary.appendingPathComponent("unrelated.mov")
        try Data([1, 2, 3]).write(to: unrelated)
        let leftover = temporary.appendingPathComponent("video-\(UUID().uuidString).mov")
        try Data([4]).write(to: leftover)
        let abandoned = root.appendingPathComponent(".staging-\(UUID().uuidString)")
        try fm.createDirectory(at: abandoned, withIntermediateDirectories: false)
        try store.prepare()
        try check(fm.fileExists(atPath: unrelated.path), "prepare preserves unrelated files")
        try check(!fm.fileExists(atPath: leftover.path) && !fm.fileExists(atPath: abandoned.path), "prepare clears module leftovers")
        try check(keyReads == 0, "Cleanup never reads keys")
        try fm.removeItem(at: unrelated)
        let source = base.appendingPathComponent("original.mov")
        let expected = try writeSource(source, size: Int64(chunk * 2 + 193))
        var progress: [Double] = []
        let info = try store.importVideo(from: source, name: "Private holiday", fileExtension: "MOV",
                                         cancelled: { false }, progress: { progress.append($0) })
        try check(info.size == Int64(chunk * 2 + 193), "Plaintext size")
        try check(info.fileExtension == "mov", "Normalized extension")
        try check(info.importedAt > 1_000_000_000_000, "Milliseconds timestamp")
        try check(info.dictionary["name"] as? String == info.name, "Dictionary contract")
        try check(progress.first == 0 && progress.last == 1 && progress == progress.sorted(), "Import progress")
        try check(try store.list().map(\.id) == [info.id], "List record")
        let output = try store.decrypt(id: info.id, cancelled: { false }, progress: { _ in })
        try check(try digest(output) == expected, "Cross-chunk roundtrip")
        try check(keyReads == 3, "Keys must be fetched per operation")
        try check(fm.fileExists(atPath: source.path), "Source retained")
        try store.clearTemporary()
        try check(!fm.fileExists(atPath: output.path), "Temporary cleanup")

        let wrong = try EncryptedVideoStore(root: root, temporary: temporary,
                                            keyProvider: { SymmetricKey(size: .bits256) })
        try expect(.corruptFile) { _ = try wrong.list() }
        try expect(.corruptFile) { _ = try wrong.decrypt(id: info.id, cancelled: { false }, progress: { _ in }) }
        for id in ["../escape", "", "../../\(info.id)", info.id + "/child"] {
            try expect(.invalidFile) { try store.delete(id: id) }
            try expect(.invalidFile) { _ = try store.decrypt(id: id, cancelled: { false }, progress: { _ in }) }
        }
        try expect(.invalidFile) {
            _ = try store.importVideo(from: source, name: "Bad", fileExtension: "../mov",
                                      cancelled: { false }, progress: { _ in })
        }

        let record = root.appendingPathComponent(info.id)
        let content = record.appendingPathComponent("content.bin")
        let metadata = record.appendingPathComponent("metadata.bin")
        // Only the small test fixture is loaded wholesale; --large stays incremental.
        let originalContent = try Data(contentsOf: content)
        let originalMetadata = try Data(contentsOf: metadata)
        let referenceKey = HKDF<SHA256>.deriveKey(inputKeyMaterial: key, salt: originalContent[32..<64],
                                                 info: Data(("video-vault-v1:" + info.id).utf8), outputByteCount: 32)
        let referenceMetadata = try AES.GCM.open(AES.GCM.SealedBox(combined: originalMetadata), using: referenceKey,
                                                  authenticating: originalContent.prefix(64) + Data(info.id.utf8) + Data("metadata".utf8))
        try check(try JSONDecoder().decode(EncryptedVideoInfo.self, from: referenceMetadata).id == info.id,
                  "iOS 13 HKDF implementation matches CryptoKit HKDF")
        try check(originalContent.range(of: Data("Private holiday".utf8)) == nil, "No plaintext name in content")
        try check(originalMetadata.range(of: Data("Private holiday".utf8)) == nil, "Metadata encrypted")
        var corrupt = originalContent
        corrupt[100] ^= 0x80
        try corrupt.write(to: content)
        try expect(.corruptFile) { _ = try store.decrypt(id: info.id, cancelled: { false }, progress: { _ in }) }
        try originalContent.dropLast().write(to: content)
        try expect(.corruptFile) { _ = try store.decrypt(id: info.id, cancelled: { false }, progress: { _ in }) }
        var appended = originalContent
        appended.append(0)
        try appended.write(to: content)
        try expect(.corruptFile) { _ = try store.decrypt(id: info.id, cancelled: { false }, progress: { _ in }) }
        var reordered = originalContent
        let sealedChunk = chunk + 28
        reordered.replaceSubrange(64..<(64 + sealedChunk), with: originalContent[(64 + sealedChunk)..<(64 + sealedChunk * 2)])
        reordered.replaceSubrange((64 + sealedChunk)..<(64 + sealedChunk * 2), with: originalContent[64..<(64 + sealedChunk)])
        try reordered.write(to: content)
        try expect(.corruptFile) { _ = try store.decrypt(id: info.id, cancelled: { false }, progress: { _ in }) }
        try originalContent.write(to: content)
        var unsupported = originalContent
        unsupported[11] = 2
        try unsupported.write(to: content)
        try expect(.unsupportedVersion) { _ = try store.list() }
        for range in [16..<24, 24..<32] {
            var oversized = originalContent
            oversized.replaceSubrange(range, with: Data(repeating: 255, count: 8))
            try oversized.write(to: content)
            try expect(.corruptFile) { _ = try store.list() }
        }
        try originalContent.write(to: content)
        var badMetadata = originalMetadata
        badMetadata[15] ^= 1
        try badMetadata.write(to: metadata)
        try expect(.corruptFile) { _ = try store.list() }
        try originalMetadata.write(to: metadata)
        try check(try fm.contentsOfDirectory(atPath: temporary.path).isEmpty, "Failure cleanup")

        var cancel = false
        try expect(.cancelled) {
            _ = try store.importVideo(from: source, name: "Cancelled", fileExtension: "mov",
                                      cancelled: { cancel }, progress: { if $0 > 0 { cancel = true } })
        }
        try check(try fm.contentsOfDirectory(atPath: root.path) == [info.id], "No cancelled staging")
        cancel = false
        try expect(.cancelled) {
            _ = try store.decrypt(id: info.id, cancelled: { cancel }, progress: { if $0 > 0 { cancel = true } })
        }
        try check(try fm.contentsOfDirectory(atPath: temporary.path).isEmpty, "Cancelled plaintext cleaned")
        cancel = false
        try expect(.cancelled) {
            _ = try store.importVideo(from: source, name: "Cancel at commit", fileExtension: "mov",
                                      cancelled: { cancel }, progress: { if $0 == 1 { cancel = true } })
        }
        try check(try fm.contentsOfDirectory(atPath: root.path) == [info.id], "Cancellation before atomic commit")
        let link = base.appendingPathComponent("source-link.mov")
        try fm.createSymbolicLink(at: link, withDestinationURL: source)
        try expect(.invalidFile) {
            _ = try store.importVideo(from: link, name: "Link", fileExtension: "mov", cancelled: { false }, progress: { _ in })
        }
        try fm.removeItem(at: content)
        try fm.createSymbolicLink(at: content, withDestinationURL: source)
        try expect(.corruptFile) { _ = try store.list() }
        try fm.removeItem(at: content)
        try originalContent.write(to: content)
        var reentrantError: VideoVaultError?
        _ = try store.decrypt(id: info.id, cancelled: { false }, progress: { _ in
            do { _ = try store.list() } catch { reentrantError = error as? VideoVaultError }
        })
        try check(reentrantError == .busy, "Reentrant operations rejected")
        try store.clearTemporary()
        try check(try digest(source) == expected, "Source unchanged")

        let emptySource = base.appendingPathComponent("empty.mov")
        try Data().write(to: emptySource)
        try expect(.invalidFile) {
            _ = try store.importVideo(from: emptySource, name: "Empty", fileExtension: "mov", cancelled: { false }, progress: { _ in })
        }
        let sparse = base.appendingPathComponent("sparse.mov")
        try Data().write(to: sparse)
        let sparseHandle = try FileHandle(forWritingTo: sparse)
        try sparseHandle.truncate(atOffset: (1 << 40) + 1)
        try expect(.invalidFile) {
            _ = try store.importVideo(from: sparse, name: "Too large", fileExtension: "mov", cancelled: { false }, progress: { _ in })
        }
        let free = (try fm.attributesOfFileSystem(forPath: root.path)[.systemFreeSize] as! NSNumber).uint64Value
        if free + 16 * 1024 * 1024 <= 1 << 40 {
            try sparseHandle.truncate(atOffset: free + 16 * 1024 * 1024)
            let readsBeforePreflight = keyReads
            try expect(.insufficientSpace) {
                _ = try store.importVideo(from: sparse, name: "No space", fileExtension: "mov", cancelled: { false }, progress: { _ in })
            }
            try check(keyReads == readsBeforePreflight, "Space preflight precedes key access")
        }
        try sparseHandle.close()
        try fm.removeItem(at: sparse)

        let second = try store.importVideo(from: source, name: "Second", fileExtension: "mp4", cancelled: { false }, progress: { _ in })
        try check(try store.list().map(\.id) == [second.id, info.id], "Newest first")
        let secondDirectory = root.appendingPathComponent(second.id)
        let secondContent = try Data(contentsOf: secondDirectory.appendingPathComponent("content.bin"))
        try check(secondContent != originalContent, "Per-file randomized encryption")
        let secondMetadataURL = secondDirectory.appendingPathComponent("metadata.bin")
        let secondMetadata = try Data(contentsOf: secondMetadataURL)
        try originalMetadata.write(to: secondMetadataURL)
        try expect(.corruptFile) { _ = try store.decrypt(id: second.id, cancelled: { false }, progress: { _ in }) }
        try secondMetadata.write(to: secondMetadataURL)
        try store.delete(id: second.id)
        try store.delete(id: second.id)
        try check(try store.list().map(\.id) == [info.id], "Individual delete is idempotent")

        let unavailable = try EncryptedVideoStore(root: root, temporary: temporary,
                                                  keyProvider: { throw VideoVaultError.keyUnavailable })
        try expect(.keyUnavailable) { _ = try unavailable.list() }
        try unavailable.deleteAll()
        try unavailable.deleteAll()
        try check(try store.list().isEmpty, "deleteAll works without a key and is idempotent")
        try check(fm.fileExists(atPath: source.path), "deleteAll preserves import source")
        print("PASS: roundtrip, metadata, key lifecycle, tampering, paths, cancellation, cleanup, deleteAll")
        try temporaryRecoveryChecks(in: base)

        if CommandLine.arguments.contains("--large") {
            let large = base.appendingPathComponent("large.mov")
            let size = Int64(2) * 1024 * 1024 * 1024 + 137
            print("Large check: \(size) bytes; run with /usr/bin/time -l for peak resident memory")
            let expectedLarge = try writeSource(large, size: size)
            let largeInfo = try store.importVideo(from: large, name: "Large", fileExtension: "mov",
                                                   cancelled: { false }, progress: { _ in })
            let decoded = try store.decrypt(id: largeInfo.id, cancelled: { false }, progress: { _ in })
            try check(try digest(decoded) == expectedLarge, "Large incremental digest")
            try store.deleteAll()
            print("PASS: >=2 GiB incremental roundtrip")
        }
    }

    static func main() {
        let finished = DispatchSemaphore(value: 0)
        DispatchQueue(label: "video-store-checks.worker").async {
            do { try run() } catch {
                fputs("FAIL: \(error)\n", stderr)
                exit(1)
            }
            finished.signal()
        }
        finished.wait()
    }
}
