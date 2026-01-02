import UIKit
import Flutter

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var methodChannel: FlutterMethodChannel?

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

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
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
