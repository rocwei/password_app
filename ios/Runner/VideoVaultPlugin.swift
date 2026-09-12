import AVFoundation
import AVKit
import Flutter
import MobileCoreServices
import PhotosUI
import UIKit

// All UI/session state lives on main; file work is serialized and cancellable.
private final class VideoWork {
    private let lock = NSLock()
    private var stopped = false
    let coordinator = NSFileCoordinator()
    var isCancelled: Bool { lock.lock(); defer { lock.unlock() }; return stopped }
    func cancel() { lock.lock(); stopped = true; lock.unlock(); coordinator.cancel() }
}

final class VideoVaultPlugin: NSObject, UIDocumentPickerDelegate,
    UIImagePickerControllerDelegate, UINavigationControllerDelegate, UIAdaptivePresentationControllerDelegate {
    private let channel: FlutterMethodChannel
    private weak var host: UIViewController?
    private let queue = DispatchQueue(label: "com.rocwei.password.video-files", qos: .userInitiated)
    private var store: EncryptedVideoStore?
    private var session: String?
    private var work: VideoWork?
    private var pending: FlutterResult?
    private var pendingOpen: (token: String, result: FlutterResult)?
    private var picker: UIViewController?
    private var player: VideoPlaybackContainer?
    private var providerProgress: Progress?
    private var privacyCover: UIView?
    private var cleanupBackgroundTask: UIBackgroundTaskIdentifier = .invalid
    private var observers: [NSObjectProtocol] = []
    private let notificationCenter: NotificationCenter
    private let applicationState: () -> UIApplication.State
    private let makeStore: () throws -> EncryptedVideoStore

    init(messenger: FlutterBinaryMessenger, host: UIViewController,
         notificationCenter: NotificationCenter = .default,
         applicationState: @escaping () -> UIApplication.State = { UIApplication.shared.applicationState },
         makeStore: @escaping () throws -> EncryptedVideoStore = { try EncryptedVideoStore() }) {
        self.host = host
        self.notificationCenter = notificationCenter
        self.applicationState = applicationState
        self.makeStore = makeStore
        channel = FlutterMethodChannel(name: "com.rocwei.password/video_vault", binaryMessenger: messenger)
        super.init()
        channel.setMethodCallHandler { [weak self] call, result in self?.handle(call, result: result) }
        queue.async { [self] in
            do {
                let storage = try makeStore()
                try storage.prepare()
                store = storage
            } catch { /* Opening the vault retries startup cleanup and reports failure. */ }
        }
        let center = notificationCenter
        observers.append(center.addObserver(forName: UIApplication.willResignActiveNotification, object: nil, queue: .main) { [weak self] _ in
            self?.cover()
            self?.player?.pause()
        })
        observers.append(center.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            self?.privacyCover?.removeFromSuperview()
            self?.privacyCover = nil
            self?.channel.invokeMethod("event", arguments: ["type": "applicationForegrounded"])
            self?.openWhenActive()
        })
        observers.append(center.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { [weak self] _ in
            self?.closeSession(result: nil)
            self?.channel.invokeMethod("event", arguments: ["type": "applicationBackgrounded"])
        })
        observers.append(center.addObserver(forName: UIApplication.protectedDataWillBecomeUnavailableNotification, object: nil, queue: .main) { [weak self] _ in
            self?.closeSession(result: nil)
        })
    }

    deinit { observers.forEach(notificationCenter.removeObserver) }

    private func storage() throws -> EncryptedVideoStore {
        if let store = store { return store }
        // Retry a failed startup cleanup rather than permanently disabling the feature.
        let storage = try makeStore()
        try storage.prepare()
        store = storage
        return storage
    }

    private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any] ?? [:]
        switch call.method {
        case "open":
            guard applicationState() != .background else { result(error(.locked)); return }
            guard work == nil, session == nil else { result(error(.busy)); return }
            let token = UUID().uuidString
            session = token
            pendingOpen = (token, result)
            openWhenActive()
        case "close": closeSession(result: result)
        case "deleteAll":
            closeSession(result: nil)
            queue.async { [self] in
                do { try storage().deleteAll(); DispatchQueue.main.async { result(nil) } }
                catch { DispatchQueue.main.async { [self] in result(flutterError(error)) } }
            }
        case "cancel":
            guard authorized(args) else { result(error(.locked)); return }
            cancelOperation()
            queue.async { [self] in
                do { try storage().clearTemporary(); DispatchQueue.main.async { result(nil) } }
                catch { DispatchQueue.main.async { [self] in result(flutterError(error)) } }
            }
        default:
            guard authorized(args) else { result(error(.locked)); return }
            guard work == nil, player == nil else { result(error(.busy)); return }
            let task = VideoWork()
            work = task
            pending = result
            switch call.method {
            case "list": run(task) { try self.storage().list().map(\.dictionary) }
            case "delete":
                guard let id = args["id"] as? String else { finish(task, failure: .invalidFile); return }
                run(task) { try self.storage().delete(id: id); return nil }
            case "import":
                if args["source"] as? String == "photos" { selectPhoto(task) }
                else { selectFile(task) }
            case "play":
                guard let id = args["id"] as? String else { finish(task, failure: .invalidFile); return }
                play(id, task: task, done: args["done"] as? String ?? "Done")
            default: finish(task, failure: .invalidFile)
            }
        }
    }

    private func openWhenActive() {
        // LocalAuthentication can reply before UIApplication becomes active.
        // Wait for that notification, not an arbitrary delay or another password.
        guard applicationState() == .active, let request = pendingOpen else { return }
        pendingOpen = nil
        queue.async { [self] in
            do {
                try storage().prepare()
                DispatchQueue.main.async { [self] in
                    guard session == request.token else { request.result(error(.locked)); return }
                    switch applicationState() {
                    case .active: request.result(request.token)
                    case .inactive: pendingOpen = request
                    default:
                        session = nil
                        request.result(error(.locked))
                    }
                }
            } catch { DispatchQueue.main.async { [self] in
                if session == request.token { session = nil }
                request.result(flutterError(error))
            } }
        }
    }

    private func authorized(_ args: [String: Any]) -> Bool {
        guard let token = args["session"] as? String, let session = session else { return false }
        return token == session && applicationState() == .active
    }

    private func run(_ task: VideoWork, operation: @escaping () throws -> Any?) {
        queue.async { [self] in
            do {
                if task.isCancelled { throw VideoVaultError.cancelled }
                let value = try operation()
                DispatchQueue.main.async { self.finish(task, value: value) }
            } catch { DispatchQueue.main.async { self.finish(task, thrown: error) } }
        }
    }

    private func finish(_ task: VideoWork, value: Any? = nil, failure: VideoVaultError? = nil, thrown: Error? = nil) {
        guard work === task else { return }
        let callback = pending
        pending = nil; work = nil; providerProgress = nil
        if task.isCancelled { callback?(error(.cancelled)) }
        else if let failure = failure { callback?(error(failure)) }
        else if let thrown = thrown { callback?(flutterError(thrown)) }
        else { callback?(value) }
    }

    private func emit(_ task: VideoWork, phase: String, fraction: Double?) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, self.work === task, !task.isCancelled else { return }
            self.channel.invokeMethod("event", arguments: ["type": "progress", "phase": phase,
                "progress": fraction as Any? ?? NSNull()])
        }
    }

    private func cancelOperation() {
        work?.cancel()
        providerProgress?.cancel(); providerProgress = nil
        if let picker = picker { picker.dismiss(animated: false); self.picker = nil }
        if let task = work { finish(task) }
    }

    private func closeSession(result: FlutterResult?) {
        let waiting = pendingOpen
        pendingOpen = nil
        waiting?.result(error(.locked))
        if applicationState() == .background, cleanupBackgroundTask == .invalid {
            cleanupBackgroundTask = UIApplication.shared.beginBackgroundTask(withName: "Video vault cleanup") { [weak self] in
                self?.work?.cancel()
                self?.endCleanupBackgroundTask()
            }
        }
        session = nil
        cancelOperation()
        if let player = player {
            player.stop()
            player.dismiss(animated: false)
            self.player = nil
        }
        channel.invokeMethod("event", arguments: ["type": "locked"])
        queue.async { [self] in
            do {
                try storage().clearTemporary()
                DispatchQueue.main.async { [self] in endCleanupBackgroundTask(); result?(nil) }
            } catch {
                DispatchQueue.main.async { [self] in
                    endCleanupBackgroundTask()
                    channel.invokeMethod("event", arguments: ["type": "cleanupFailed"])
                    result?(flutterError(error))
                }
            }
        }
    }

    private func endCleanupBackgroundTask() {
        if cleanupBackgroundTask != .invalid {
            UIApplication.shared.endBackgroundTask(cleanupBackgroundTask)
            cleanupBackgroundTask = .invalid
        }
    }

    private func cover() {
        guard session != nil, privacyCover == nil, let window = host?.view.window else { return }
        let view = UIView(frame: window.bounds)
        view.backgroundColor = .black
        view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        window.addSubview(view)
        privacyCover = view
    }

    private func selectFile(_ task: VideoWork) {
        let view = UIDocumentPickerViewController(documentTypes: [kUTTypeMovie as String], in: .open)
        view.allowsMultipleSelection = false
        view.delegate = self
        picker = view
        host?.present(view, animated: true)
        view.presentationController?.delegate = self
    }

    private func selectPhoto(_ task: VideoWork) {
        if #available(iOS 14, *) {
            var config = PHPickerConfiguration()
            config.filter = .videos
            config.selectionLimit = 1
            config.preferredAssetRepresentationMode = .current
            let view = PHPickerViewController(configuration: config)
            view.delegate = self
            picker = view
            host?.present(view, animated: true)
            view.presentationController?.delegate = self
        } else {
            guard UIImagePickerController.isSourceTypeAvailable(.photoLibrary) else {
                finish(task, failure: .invalidFile); return
            }
            let view = UIImagePickerController()
            view.sourceType = .photoLibrary
            view.mediaTypes = [kUTTypeMovie as String]
            view.videoExportPreset = AVAssetExportPresetPassthrough
            view.delegate = self
            picker = view
            host?.present(view, animated: true)
            view.presentationController?.delegate = self
        }
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        guard picker === controller else { return }
        picker = nil
        if let task = work { finish(task, failure: .cancelled) }
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard picker === controller else { return }
        picker = nil
        guard let task = work else { return }
        guard let url = urls.first else { finish(task, failure: .cancelled); return }
        // Scoped access remains valid until all coordinated reading completes.
        let scoped = url.startAccessingSecurityScopedResource()
        queue.async { [self] in
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            var coordinationError: NSError?
            var fileError: Error?
            var info: EncryptedVideoInfo?
            task.coordinator.coordinate(readingItemAt: url, options: [], error: &coordinationError) { source in
                do { info = try importSource(source, task: task, name: source.lastPathComponent) }
                catch { fileError = error }
            }
            DispatchQueue.main.async { [self] in
                finish(task, value: info?.dictionary, thrown: fileError ?? coordinationError)
            }
        }
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        guard self.picker === picker else { return }
        picker.dismiss(animated: true)
        self.picker = nil
        if let task = work { finish(task, failure: .cancelled) }
    }

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        guard self.picker === picker else { return }
        picker.dismiss(animated: true)
        self.picker = nil
        guard let task = work else { return }
        guard let url = info[.mediaURL] as? URL else { finish(task, failure: .invalidFile); return }
        run(task) { try self.importSource(url, task: task, name: url.lastPathComponent).dictionary }
    }

    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        guard picker === presentationController.presentedViewController else { return }
        picker = nil
        if let task = work { task.cancel(); finish(task) }
    }

    private func importSource(_ url: URL, task: VideoWork, name: String) throws -> EncryptedVideoInfo {
        if task.isCancelled { throw VideoVaultError.cancelled }
        let ext = url.pathExtension.lowercased()
        guard ["mp4", "mov", "m4v"].contains(ext) else { throw VideoVaultError.invalidFile }
        emit(task, phase: "checking", fraction: nil)
        let asset = AVURLAsset(url: url)
        let signal = DispatchSemaphore(value: 0)
        asset.loadValuesAsynchronously(forKeys: ["playable", "hasProtectedContent", "tracks"]) { signal.signal() }
        while signal.wait(timeout: .now() + .milliseconds(100)) == .timedOut {
            if task.isCancelled { asset.cancelLoading(); throw VideoVaultError.cancelled }
        }
        for key in ["playable", "hasProtectedContent", "tracks"] {
            guard asset.statusOfValue(forKey: key, error: nil) == .loaded else { throw VideoVaultError.invalidFile }
        }
        guard asset.isPlayable, !asset.hasProtectedContent,
              !asset.tracks(withMediaType: .video).isEmpty else { throw VideoVaultError.invalidFile }
        return try storage().importVideo(from: url, name: name, fileExtension: ext,
            cancelled: { task.isCancelled }, progress: { self.emit(task, phase: "encrypting", fraction: $0) })
    }

    private func play(_ id: String, task: VideoWork, done: String) {
        queue.async { [self] in
            do {
                let url = try storage().decrypt(id: id, cancelled: { task.isCancelled },
                    progress: { self.emit(task, phase: "decrypting", fraction: $0) })
                DispatchQueue.main.async { [self] in
                    guard work === task, !task.isCancelled, session != nil,
                          applicationState() == .active else {
                        // Inactive is not necessarily background (for example Control Center).
                        // Still finish the request and remove its plaintext instead of hanging.
                        task.cancel()
                        finish(task)
                        queue.async { [self] in
                            do { try storage().removeTemporary(url: url) }
                            catch { DispatchQueue.main.async { [self] in
                                channel.invokeMethod("event", arguments: ["type": "cleanupFailed"])
                            } }
                        }
                        return
                    }
                    let container = VideoPlaybackContainer(url: url, done: done)
                    container.onClose = { [weak self, weak container] in
                        guard let self = self, self.player === container else { return }
                        container?.stop()
                        self.player = nil
                        self.queue.async {
                            do {
                                try self.storage().clearTemporary()
                                DispatchQueue.main.async { self.channel.invokeMethod("event", arguments: ["type": "playbackClosed"]) }
                            } catch {
                                DispatchQueue.main.async { self.channel.invokeMethod("event", arguments: ["type": "cleanupFailed"]) }
                            }
                        }
                    }
                    container.onFailure = { [weak self] in
                        self?.channel.invokeMethod("event", arguments: ["type": "playbackFailed"])
                    }
                    player = container
                    host?.present(container, animated: true) { [weak self, weak container] in
                        guard let self = self, self.session != nil, self.player === container,
                              self.applicationState() == .active else { return }
                        container?.start()
                    }
                    finish(task)
                }
            } catch { DispatchQueue.main.async { self.finish(task, thrown: error) } }
        }
    }

    private func error(_ code: VideoVaultError) -> FlutterError {
        FlutterError(code: code.rawValue, message: nil, details: nil)
    }

    private func flutterError(_ value: Error) -> FlutterError {
        if let code = value as? VideoVaultError { return error(code) }
        let ns = value as NSError
        if ns.domain == NSCocoaErrorDomain && ns.code == NSFileWriteOutOfSpaceError { return error(.insufficientSpace) }
        return error(.ioFailure)
    }
}

@available(iOS 14, *)
extension VideoVaultPlugin: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        guard self.picker === picker else { return }
        picker.dismiss(animated: true)
        self.picker = nil
        guard let task = work else { return }
        guard let provider = results.first?.itemProvider else { finish(task, failure: .cancelled); return }
        emit(task, phase: "loading", fraction: nil)
        providerProgress = provider.loadFileRepresentation(forTypeIdentifier: kUTTypeMovie as String) { [weak self] url, error in
            guard let self = self else { return }
            guard let url = url else {
                DispatchQueue.main.async { self.finish(task, failure: .ioFailure) }; return
            }
            // The provider's URL expires when this callback returns. Keep the callback
            // alive while our serialized worker reads it; never copy a whole video into RAM.
            self.queue.sync {
                do {
                    let name = provider.suggestedName ?? url.lastPathComponent
                    let info = try self.importSource(url, task: task, name: name)
                    DispatchQueue.main.async { self.finish(task, value: info.dictionary) }
                } catch { DispatchQueue.main.async { self.finish(task, thrown: error) } }
            }
        }
    }
}

// Compose the system player; AVPlayerViewController itself must not be subclassed.
private final class VideoPlaybackContainer: UIViewController {
    private let playback: AVPlayer
    private let controller = AVPlayerViewController()
    private let done: String
    private var observation: NSKeyValueObservation?
    var onClose: (() -> Void)?
    var onFailure: (() -> Void)?

    init(url: URL, done: String) {
        self.done = done
        playback = AVPlayer(url: url)
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .fullScreen
        playback.allowsExternalPlayback = false
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        controller.player = playback
        controller.allowsPictureInPicturePlayback = false
        controller.updatesNowPlayingInfoCenter = false
        addChild(controller)
        view.addSubview(controller.view)
        controller.view.translatesAutoresizingMaskIntoConstraints = false
        controller.didMove(toParent: self)
        let button = UIButton(type: .system)
        button.setTitle(done, for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.addTarget(self, action: #selector(close), for: .touchUpInside)
        view.addSubview(button)
        button.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            button.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            button.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            button.heightAnchor.constraint(greaterThanOrEqualToConstant: 44),
            button.widthAnchor.constraint(greaterThanOrEqualToConstant: 60),
            controller.view.topAnchor.constraint(equalTo: button.bottomAnchor),
            controller.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            controller.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            controller.view.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
        observation = playback.currentItem?.observe(\.status, options: [.new, .initial]) { [weak self] item, _ in
            guard item.status == .failed else { return }
            DispatchQueue.main.async { self?.onFailure?(); self?.close() }
        }
    }
    func start() { playback.play() }
    func pause() { playback.pause() }
    func stop() { playback.pause(); observation = nil; playback.replaceCurrentItem(with: nil); controller.player = nil }
    @objc private func close() { stop(); dismiss(animated: true) }
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if isBeingDismissed || presentingViewController == nil { onClose?(); onClose = nil }
    }
}
