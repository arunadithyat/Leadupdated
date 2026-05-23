import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let channelName = "lead_calling/dialer"

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let success = super.application(application, didFinishLaunchingWithOptions: launchOptions)

    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(name: channelName, binaryMessenger: controller.binaryMessenger)
      channel.setMethodCallHandler { [weak self] call, result in
        self?.handle(call: call, result: result)
      }
    }

    return success
  }

  private func handle(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let phoneNumber = args["phoneNumber"] as? String else {
      result(FlutterError(code: "INVALID_ARGUMENT", message: "Phone number missing", details: nil))
      return
    }

    switch call.method {
    case "autoCall", "openDialer":
      result(openPhoneDialer(phoneNumber: phoneNumber))
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func openPhoneDialer(phoneNumber: String) -> Bool {
    guard let url = URL(string: "tel:\(phoneNumber)"), UIApplication.shared.canOpenURL(url) else {
      return false
    }

    UIApplication.shared.open(url, options: [:], completionHandler: nil)
    return true
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
