import UIKit
import Flutter
import LocalAuthentication

@main
@objc class AppDelegate: FlutterAppDelegate {
    private var methodChannel: FlutterMethodChannel?
    private var osMethodChannel: FlutterMethodChannel?
    private var pendingBitcoinUri: String?
    private var bitbox02Handler: Bitbox02MethodHandler?
    private let deviceDekKeystore = DeviceDekKeystore()
    private let deviceDekQueue = DispatchQueue(label: "onl.coconut.wallet.device-dek")
    private var trezorHandler: TrezorMethodHandler?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    guard let controller = window?.rootViewController as? FlutterViewController else {
      return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    // Flutter Method Channel 설정
    methodChannel = FlutterMethodChannel(
      name: "onl.coconut.wallet/app-event-icon",
      binaryMessenger: controller.binaryMessenger
    )

    methodChannel?.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
      if call.method == "changeAppEventIcon" {
        if let args = call.arguments as? [String: Any],
           let appEventIconChange = args["app_event_icon_change"] as? Bool {
          // 이벤트 아이콘 이름 설정 (Flutter에서 전달받음)
          let iconName: String?
          if appEventIconChange {
            // icon_name이 전달되면 사용, 없으면 기본값 "birthday" 사용
            iconName = args["icon_name"] as? String ?? "birthday"
          } else {
            iconName = nil
          }
          self?.setApplicationIconName(iconName, result: result)
        } else {
          result(FlutterError(
            code: "INVALID_ARGUMENT",
            message: "app_event_icon_change must be a boolean",
            details: nil
          ))
        }
      } else if call.method == "getCurrentIconName" {
        // 현재 설정된 아이콘 이름 반환
        let currentIconName = UIApplication.shared.alternateIconName
        result(currentIconName)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }

    osMethodChannel = FlutterMethodChannel(
      name: "onl.coconut.wallet/os",
      binaryMessenger: controller.binaryMessenger
    )

    osMethodChannel?.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
      if call.method == "getInitialBitcoinUri" || call.method == "getPendingBitcoinUri" {
        result(self?.pendingBitcoinUri)
        self?.pendingBitcoinUri = nil
      } else if call.method == "isDevicePasscodeSet" {
        let context = LAContext()
        var error: NSError?
        result(context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error))
      } else if call.method == "openDeviceSecuritySettings" {
        // iOS는 화면 잠금 설정으로 이동하는 공식 URL을 제공하지 않는다.
        // 지원되는 기기에서는 암호 설정 화면을 열고, 실패하면 앱 설정 화면을 연다.
        let passcodeSettingsURL = URL(string: "App-Prefs:root=TOUCHID_PASSCODE")
        let fallbackURL = URL(string: UIApplication.openSettingsURLString)
        guard let passcodeSettingsURL else {
          result(false)
          return
        }

        UIApplication.shared.open(passcodeSettingsURL, options: [:]) { success in
          guard !success, let fallbackURL else {
            result(success)
            return
          }
          UIApplication.shared.open(fallbackURL, options: [:]) { fallbackSuccess in
            result(fallbackSuccess)
          }
        }
      } else {
        result(FlutterMethodNotImplemented)
      }
    }

    let deviceDekChannel = FlutterMethodChannel(
      name: "onl.coconut.wallet/device-dek",
      binaryMessenger: controller.binaryMessenger
    )
    deviceDekChannel.setMethodCallHandler { [weak self] call, result in
      guard let self,
            let arguments = call.arguments as? [String: Any],
            let alias = arguments["alias"] as? String else {
        result(FlutterError(code: "INVALID_ARGUMENT", message: "alias is required", details: nil))
        return
      }
      self.deviceDekQueue.async {
        do {
          switch call.method {
          case "wrap":
            guard let data = (arguments["plaintext"] as? FlutterStandardTypedData)?.data else {
              throw NSError(domain: "DeviceDekKeystore", code: 3)
            }
            do {
              let ciphertext = try self.deviceDekKeystore.wrap(alias: alias, plaintext: data)
              DispatchQueue.main.async {
                result([
                  "ciphertext": FlutterStandardTypedData(bytes: ciphertext),
                  "protection": "iosSecureEnclave",
                ])
              }
            } catch {
              DispatchQueue.main.async {
                result(FlutterError(
                  code: "HARDWARE_UNAVAILABLE",
                  message: error.localizedDescription,
                  details: nil
                ))
              }
            }
          case "unwrap":
            guard let data = (arguments["ciphertext"] as? FlutterStandardTypedData)?.data else {
              throw NSError(domain: "DeviceDekKeystore", code: 4)
            }
            let plaintext = try self.deviceDekKeystore.unwrap(
              alias: alias,
              ciphertext: data
            )
            DispatchQueue.main.async {
              result(FlutterStandardTypedData(bytes: plaintext))
            }
          case "delete":
            self.deviceDekKeystore.delete(alias: alias)
            DispatchQueue.main.async { result(nil) }
          default:
            DispatchQueue.main.async { result(FlutterMethodNotImplemented) }
          }
        } catch {
          DispatchQueue.main.async {
            result(FlutterError(
              code: "KEYSTORE_FAILED",
              message: error.localizedDescription,
              details: nil
            ))
          }
        }
      }
    }

    if let url = launchOptions?[.url] as? URL,
       url.scheme?.lowercased() == "bitcoin" {
      pendingBitcoinUri = url.absoluteString
    }

    bitbox02Handler = Bitbox02MethodHandler(messenger: controller.binaryMessenger)
    trezorHandler = TrezorMethodHandler(messenger: controller.binaryMessenger)

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey : Any] = [:]
  ) -> Bool {
    guard url.scheme?.lowercased() == "bitcoin" else {
      return super.application(app, open: url, options: options)
    }

    let uri = url.absoluteString
    pendingBitcoinUri = uri
    osMethodChannel?.invokeMethod("onBitcoinUri", arguments: uri)
    return true
  }

  // MARK: - App Icon 변경
  private func setApplicationIconName(_ iconName: String?, result: @escaping FlutterResult) {
    // 대체 아이콘 지원 여부 확인
    guard UIApplication.shared.supportsAlternateIcons else {
      result(FlutterError(
        code: "NOT_SUPPORTED",
        message: "Alternate icons are not supported on this device",
        details: nil
      ))
      return
    }

    
    // 아이콘 변경 실행
    UIApplication.shared.setAlternateIconName(iconName) { error in
      if let error = error {
        result(FlutterError(
          code: "ICON_CHANGE_FAILED",
          message: error.localizedDescription,
          details: nil
        ))
      } else {
        result(nil)
      }
    }
  }
}
