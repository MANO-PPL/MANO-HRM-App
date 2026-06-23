import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var backgroundTask: UIBackgroundTaskIdentifier = .invalid

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let controller = window?.rootViewController as? FlutterViewController
    if let binaryMessenger = controller?.binaryMessenger {
      let backgroundChannel = FlutterMethodChannel(name: "co.mano.attendance/background", binaryMessenger: binaryMessenger)
      backgroundChannel.setMethodCallHandler { [weak self] (call, result) in
        guard let self = self else {
          result(FlutterMethodNotImplemented)
          return
        }
        if call.method == "startBackgroundTask" {
          self.backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "UploadAttendance") {
            UIApplication.shared.endBackgroundTask(self.backgroundTask)
            self.backgroundTask = .invalid
          }
          result(true)
        } else if call.method == "endBackgroundTask" {
          if self.backgroundTask != .invalid {
            UIApplication.shared.endBackgroundTask(self.backgroundTask)
            self.backgroundTask = .invalid
          }
          result(true)
        } else {
          result(FlutterMethodNotImplemented)
        }
      }
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
