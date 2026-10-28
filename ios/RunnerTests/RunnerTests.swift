import Flutter
import UIKit
import XCTest
@testable import Runner

class RunnerTests: XCTestCase {
  func testSceneUsesTheRegisteredEngine() throws {
    let appDelegate = try XCTUnwrap(UIApplication.shared.delegate as? AppDelegate)
    let ready = expectation(for: NSPredicate { _, _ in
      appDelegate.window?.rootViewController is FlutterViewController
        && appDelegate.window?.windowScene != nil
    }, evaluatedWith: nil)
    wait(for: [ready], timeout: 10)
    let controller = try XCTUnwrap(appDelegate.window?.rootViewController as? FlutterViewController)
    XCTAssertTrue(controller.engine === appDelegate.flutterEngine)
    XCTAssertNotNil(appDelegate.window?.windowScene)
    for plugin in ["FPPPackageInfoPlusPlugin", "SharedPreferencesPlugin", "FlutterSecureStoragePlugin", "LocalAuthPlugin"] {
      XCTAssertTrue(controller.engine.hasPlugin(plugin), plugin)
    }
    let controllers = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
      .flatMap { $0.windows }.compactMap { $0.rootViewController as? FlutterViewController }
    XCTAssertEqual(controllers.count, 1)
    XCTAssertTrue(controllers.first === controller)
  }

  func testColdBitcoinUriIsPendingExactlyOnce() throws {
    let delegate = AppDelegate()
    defer { withExtendedLifetime(delegate) {} }
    let messenger = RecordingMessenger()
    delegate.configurePlatformChannels(messenger: messenger)
    let url = try XCTUnwrap(URL(string: "bitcoin:qa-cold-fixture"))
    XCTAssertTrue(delegate.handleBitcoinUri(url, notifyDart: false))
    XCTAssertTrue(messenger.sent.isEmpty)
    XCTAssertEqual(try messenger.call("onl.coconut.wallet/os", "getPendingBitcoinUri") as? String, url.absoluteString)
    XCTAssertNil(try messenger.call("onl.coconut.wallet/os", "getInitialBitcoinUri"))
  }

  func testWarmBitcoinUriUsesTheSameMessenger() throws {
    let delegate = AppDelegate()
    defer { withExtendedLifetime(delegate) {} }
    let messenger = RecordingMessenger()
    delegate.configurePlatformChannels(messenger: messenger)
    let url = try XCTUnwrap(URL(string: "BITCOIN:qa-warm-fixture"))
    XCTAssertTrue(delegate.application(UIApplication.shared, open: url, options: [:]))
    let sent = try XCTUnwrap(messenger.sent.last)
    XCTAssertEqual(sent.0, "onl.coconut.wallet/os")
    let call = FlutterStandardMethodCodec.sharedInstance().decodeMethodCall(sent.1)
    XCTAssertEqual(call.method, "onBitcoinUri")
    XCTAssertEqual(call.arguments as? String, url.absoluteString)
    XCTAssertEqual(try messenger.call("onl.coconut.wallet/os", "getPendingBitcoinUri") as? String, url.absoluteString)
    XCTAssertNil(try messenger.call("onl.coconut.wallet/os", "getPendingBitcoinUri"))
    XCTAssertFalse(delegate.handleBitcoinUri(try XCTUnwrap(URL(string: "https://example.invalid/"))))
    XCTAssertNil(try messenger.call("onl.coconut.wallet/os", "getPendingBitcoinUri"))
  }

  func testAllCustomChannelFamiliesRemainRegisteredWithoutConnectingHardware() throws {
    let delegate = AppDelegate()
    defer { withExtendedLifetime(delegate) {} }
    let messenger = RecordingMessenger()
    delegate.configurePlatformChannels(messenger: messenger)
    for name in ["onl.coconut.wallet/os", "onl.coconut.wallet/device-dek", "bitbox02", "trezor",
                 "bitbox02/connectivity", "trezor/connectivity"] {
      XCTAssertNotNil(messenger.handlers[name], name)
    }
    XCTAssertEqual(try messenger.call("bitbox02", "isConnected") as? Bool, false)
    XCTAssertEqual(try messenger.call("trezor", "isConnected") as? Bool, false)
    XCTAssertNil(try messenger.call("onl.coconut.wallet/os", "unsupported-test-method"))
  }
}

private final class RecordingMessenger: NSObject, FlutterBinaryMessenger {
  var handlers: [String: FlutterBinaryMessageHandler] = [:]
  var sent: [(String, Data)] = []
  private var connection: FlutterBinaryMessengerConnection = 0

  func send(onChannel channel: String, message: Data?) {
    if let message { sent.append((channel, message)) }
  }

  func send(onChannel channel: String, message: Data?, binaryReply callback: FlutterBinaryReply?) {
    send(onChannel: channel, message: message)
    callback?(nil)
  }

  func setMessageHandlerOnChannel(_ channel: String, binaryMessageHandler handler: FlutterBinaryMessageHandler?) -> FlutterBinaryMessengerConnection {
    handlers[channel] = handler
    connection += 1
    return connection
  }

  func cleanUpConnection(_ connection: FlutterBinaryMessengerConnection) {}

  func call(_ channel: String, _ method: String) throws -> Any? {
    let handler = try XCTUnwrap(handlers[channel])
    let codec = FlutterStandardMethodCodec.sharedInstance()
    var reply: Data?
    var replied = false
    handler(codec.encode(FlutterMethodCall(methodName: method, arguments: nil))) {
      reply = $0
      replied = true
    }
    XCTAssertTrue(replied, method)
    guard let reply else { return nil }
    return codec.decodeEnvelope(reply)
  }
}
