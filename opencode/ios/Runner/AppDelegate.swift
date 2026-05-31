import UIKit
import Flutter

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let controller = window?.rootViewController as! FlutterViewController
    let channel = FlutterMethodChannel(
      name: "dev.opencode/ziti",
      binaryMessenger: controller.binaryMessenger
    )

    channel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
      switch call.method {
      case "enroll":
        result(["enrolled": false, "connected": false, "error": "iOS CocoaPods integration pending"] as [String: Any])
      case "connect":
        result(["enrolled": false, "connected": false, "error": "iOS CocoaPods integration pending"] as [String: Any])
      case "getStatus":
        result(["enrolled": false, "connected": false] as [String: Any])
      case "disconnect":
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
