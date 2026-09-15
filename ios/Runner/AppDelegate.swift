import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let storageChannel = FlutterMethodChannel(
      name: "com.indifit.indifit/storage_protection",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    storageChannel.setMethodCallHandler { call, result in
      guard call.method == "protectSensitivePath" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard
        let arguments = call.arguments as? [String: Any],
        let path = arguments["path"] as? String
      else {
        result(FlutterError(code: "INVALID_PATH", message: "A storage path is required.", details: nil))
        return
      }

      do {
        var url = URL(fileURLWithPath: path)
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try url.setResourceValues(values)
        try FileManager.default.setAttributes(
          [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
          ofItemAtPath: path
        )
        result(nil)
      } catch {
        result(
          FlutterError(
            code: "STORAGE_PROTECTION_FAILED",
            message: "Could not protect sensitive local storage.",
            details: error.localizedDescription
          )
        )
      }
    }

    let liveActivityChannel = FlutterMethodChannel(
      name: "com.indifit.indifit/rest_live_activity",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    liveActivityChannel.setMethodCallHandler { call, result in
      if #available(iOS 16.1, *) {
        switch call.method {
        case "areActivitiesEnabled":
          result(RestTimerLiveActivityManager.shared.areActivitiesEnabled)
        case "startLiveActivity":
          guard
            let arguments = call.arguments as? [String: Any],
            let periodId = arguments["periodId"] as? String,
            let exerciseName = arguments["exerciseName"] as? String,
            let targetSeconds = arguments["targetSeconds"] as? Int,
            let expiryEpochMs = (arguments["expiryEpochMs"] as? NSNumber)?.doubleValue
          else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid or missing arguments for startLiveActivity.", details: nil))
            return
          }
          let restEndDate = Date(timeIntervalSince1970: expiryEpochMs / 1000.0)
          let started = RestTimerLiveActivityManager.shared.start(
            periodId: periodId,
            exerciseName: exerciseName,
            targetSeconds: targetSeconds,
            restEndDate: restEndDate
          )
          result(started)
        case "updateLiveActivity":
          guard
            let arguments = call.arguments as? [String: Any],
            let periodId = arguments["periodId"] as? String,
            let exerciseName = arguments["exerciseName"] as? String,
            let targetSeconds = arguments["targetSeconds"] as? Int,
            let expiryEpochMs = (arguments["expiryEpochMs"] as? NSNumber)?.doubleValue
          else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid or missing arguments for updateLiveActivity.", details: nil))
            return
          }
          let isCompleted = arguments["isCompleted"] as? Bool ?? false
          let restEndDate = Date(timeIntervalSince1970: expiryEpochMs / 1000.0)
          RestTimerLiveActivityManager.shared.update(
            periodId: periodId,
            exerciseName: exerciseName,
            targetSeconds: targetSeconds,
            restEndDate: restEndDate,
            isCompleted: isCompleted
          )
          result(true)
        case "endLiveActivity":
          let arguments = call.arguments as? [String: Any]
          let periodId = arguments?["periodId"] as? String
          let immediate = arguments?["immediate"] as? Bool ?? true
          RestTimerLiveActivityManager.shared.end(periodId: periodId, immediate: immediate)
          result(true)
        default:
          result(FlutterMethodNotImplemented)
        }
      } else {
        if call.method == "areActivitiesEnabled" {
          result(false)
        } else {
          result(false)
        }
      }
    }
  }
}
