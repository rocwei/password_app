import Flutter
import CryptoKit
import UIKit
import XCTest
@testable import Runner

class RunnerTests: XCTestCase {
  private var messenger: VaultMessenger!
  private var plugin: VideoVaultPlugin!
  private var center: NotificationCenter!
  private var state: UIApplication.State = .active
  private var directory: URL!

  override func setUpWithError() throws {
    messenger = VaultMessenger()
    center = NotificationCenter()
    state = .active
    directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let root = directory.appendingPathComponent("vault")
    let temp = directory.appendingPathComponent("playback")
    plugin = VideoVaultPlugin(messenger: messenger, host: UIViewController(),
      notificationCenter: center, applicationState: { [unowned self] in self.state },
      makeStore: { try EncryptedVideoStore(root: root, temporary: temp,
        keyProvider: { SymmetricKey(data: Data(repeating: 7, count: 32)) }) })
  }

  override func tearDownWithError() throws {
    let closed = expectation(description: "worker cleanup finished")
    messenger.invoke("close") { _ in closed.fulfill() }
    wait(for: [closed], timeout: 5)
    plugin = nil
    try FileManager.default.removeItem(at: directory)
  }

  func testBiometricReturnWaitsForActiveBeforeOpening() {
    state = .inactive
    let opened = expectation(description: "opens after becoming active")
    var replied = false
    messenger.invoke("open") { value in
      replied = true
      XCTAssertNotNil(value as? String, "Face ID success must not become a busy error")
      opened.fulfill()
    }
    XCTAssertFalse(replied, "Inactive is a transition, not a failed verification")
    state = .active
    center.post(name: UIApplication.didBecomeActiveNotification, object: nil)
    wait(for: [opened], timeout: 5)
  }

  func testBackgroundCancelsPendingOpenAndDoesNotResurrectIt() {
    state = .inactive
    let cancelled = expectation(description: "pending open cancelled")
    var replies = 0
    messenger.invoke("open") { value in
      replies += 1
      XCTAssertEqual((value as? FlutterError)?.code, "locked")
      cancelled.fulfill()
    }
    state = .background
    center.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
    state = .active
    center.post(name: UIApplication.didBecomeActiveNotification, object: nil)
    wait(for: [cancelled], timeout: 5)
    XCTAssertEqual(replies, 1)
    XCTAssertTrue(messenger.events.contains("locked"))
  }

  func testInactiveDoesNotLockButRealBackgroundDoes() {
    let opened = expectation(description: "opened")
    messenger.invoke("open") { _ in opened.fulfill() }
    wait(for: [opened], timeout: 5)
    state = .inactive
    center.post(name: UIApplication.willResignActiveNotification, object: nil)
    XCTAssertFalse(messenger.events.contains("locked"))
    XCTAssertFalse(messenger.events.contains("applicationBackgrounded"))
    state = .background
    center.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
    XCTAssertTrue(messenger.events.contains("locked"))
    XCTAssertTrue(messenger.events.contains("applicationBackgrounded"))
  }
}

private final class VaultMessenger: NSObject, FlutterBinaryMessenger {
  private let codec = FlutterStandardMethodCodec.sharedInstance()
  private var handler: FlutterBinaryMessageHandler?
  var events: [String] = []

  func invoke(_ method: String, reply: @escaping (Any?) -> Void) {
    handler?(codec.encode(FlutterMethodCall(methodName: method, arguments: nil))) { data in
      reply(data.map { self.codec.decodeEnvelope($0) } ?? nil)
    }
  }

  func send(onChannel channel: String, message: Data?) {
    guard let message = message, let event = codec.decodeMethodCall(message).arguments as? [String: Any],
          let type = event["type"] as? String else { return }
    events.append(type)
  }
  func send(onChannel channel: String, message: Data?, binaryReply callback: FlutterBinaryReply?) {
    send(onChannel: channel, message: message)
    callback?(nil)
  }
  func setMessageHandlerOnChannel(_ channel: String, binaryMessageHandler handler: FlutterBinaryMessageHandler?) -> FlutterBinaryMessengerConnection {
    self.handler = handler
    return 1
  }
  func cleanUpConnection(_ connection: FlutterBinaryMessengerConnection) { handler = nil }
}
