import AppTrackingTransparency
import Flutter
import FirebaseMessaging
import TikTokBusinessSDK
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    initializeTikTokSDK()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    if let updateRegistrar = engineBridge.pluginRegistry.registrar(
      forPlugin: "BarqAppUpdate"
    ) {
      let updateChannel = FlutterMethodChannel(
        name: "com.barqwadih.app/app_update",
        binaryMessenger: updateRegistrar.messenger()
      )
      updateChannel.setMethodCallHandler { call, result in
        guard call.method == "installedInfo" else {
          result(FlutterMethodNotImplemented)
          return
        }
        result([
          "bundleId": Bundle.main.bundleIdentifier ?? "",
          "version": Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "",
          "osVersion": UIDevice.current.systemVersion,
        ])
      }
    }

    if let trackingRegistrar = engineBridge.pluginRegistry.registrar(
      forPlugin: "BarqMarketingTracking"
    ) {
      let trackingChannel = FlutterMethodChannel(
        name: "com.barqwadih.app/marketing_tracking",
        binaryMessenger: trackingRegistrar.messenger()
      )
      trackingChannel.setMethodCallHandler { [weak self] call, result in
        self?.handleTrackingCall(call, result: result)
      }
    }

    // firebase_messaging installs its notification-center delegate from the
    // UIApplicationDidFinishLaunching observer. With Flutter's implicit
    // engine, plugins are registered after that notification has already
    // fired, so finish the plugin's launch setup explicitly. Without this,
    // FCM can create and upload a token but incoming APNs notifications never
    // reach FirebaseMessaging.onMessage / onMessageOpenedApp.
    if let messagingPlugin = engineBridge.pluginRegistry.valuePublished(
      byPlugin: "FLTFirebaseMessagingPlugin"
    ) {
      let launchSelector = NSSelectorFromString(
        "application_onDidFinishLaunchingNotification:"
      )
      if messagingPlugin.responds(to: launchSelector) {
        let launchNotification = Notification(
          name: UIApplication.didFinishLaunchingNotification,
          object: UIApplication.shared
        )
        messagingPlugin.perform(launchSelector, with: launchNotification)
      }
    }

    if let pushRegistrar = engineBridge.pluginRegistry.registrar(
      forPlugin: "BarqPushRegistration"
    ) {
      let pushChannel = FlutterMethodChannel(
        name: "com.barqwadih.app/push_registration",
        binaryMessenger: pushRegistrar.messenger()
      )
      pushChannel.setMethodCallHandler { call, result in
        switch call.method {
        case "registerForRemoteNotifications":
          // Dart invokes this only after Firebase.initializeApp() completes, so
          // Firebase Messaging is ready when iOS returns the APNs device token.
          UIApplication.shared.registerForRemoteNotifications()
          result(nil)

        case "setBadgeCount":
          // Only a push can move the badge from the server side, so reading
          // notifications inside the app has to reset it from here — otherwise
          // the icon keeps advertising notifications already seen.
          let arguments = call.arguments as? [String: Any] ?? [:]
          let count = arguments["count"] as? Int ?? 0
          if #available(iOS 16.0, *) {
            UNUserNotificationCenter.current().setBadgeCount(count)
          } else {
            UIApplication.shared.applicationIconBadgeNumber = count
          }
          if count == 0 {
            UNUserNotificationCenter.current().removeAllDeliveredNotifications()
          }
          result(nil)

        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }

    guard let registrar = engineBridge.pluginRegistry.registrar(
      forPlugin: "BarqImageUploadPreprocessor"
    ) else {
      return
    }

    let channel = FlutterMethodChannel(
      name: "com.barqwadih.app/image_upload_preprocessor",
      binaryMessenger: registrar.messenger()
    )
    channel.setMethodCallHandler { call, result in
      guard call.method == "normalizeToJpeg" else {
        result(FlutterMethodNotImplemented)
        return
      }

      guard
        let arguments = call.arguments as? [String: Any],
        let sourcePath = arguments["path"] as? String
      else {
        result(
          FlutterError(
            code: "invalid_arguments",
            message: "Missing image path.",
            details: nil
          )
        )
        return
      }

      let maxDimension = CGFloat(arguments["maxDimension"] as? Int ?? 1440)
      let quality = CGFloat(arguments["quality"] as? Double ?? 0.76)

      DispatchQueue.global(qos: .userInitiated).async {
        do {
          let outputPath = try Self.normalizeImageToJpeg(
            at: sourcePath,
            maxDimension: maxDimension,
            quality: quality
          )
          DispatchQueue.main.async { result(outputPath) }
        } catch {
          DispatchQueue.main.async {
            result(
              FlutterError(
                code: "image_conversion_failed",
                message: "Could not prepare the image for upload.",
                details: error.localizedDescription
              )
            )
          }
        }
      }
    }
  }

  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    // Set the token explicitly because Firebase's AppDelegate swizzler can
    // also be installed after launch when using an implicit Flutter engine.
    // Firebase infers sandbox vs production from the embedded provisioning
    // profile. This also handles locally signed Profile builds correctly.
    Messaging.messaging().apnsToken = deviceToken
    super.application(
      application,
      didRegisterForRemoteNotificationsWithDeviceToken: deviceToken
    )
  }

  private func initializeTikTokSDK() {
    guard
      let businessAppId = trackingSetting("TikTokBusinessAppId"),
      let tiktokAppId = trackingSetting("TikTokAppId"),
      let appSecret = trackingSetting("TikTokAppSecret"),
      let config = TikTokConfig(
        accessToken: appSecret,
        appId: businessAppId,
        tiktokAppId: tiktokAppId
      )
    else {
      return
    }

    // Barq Wadih does not use StoreKit for its commission payments. Only
    // backend-confirmed payments should ever be reported as purchases.
    config.disablePaymentTracking()
    config.disableAutoEnhancedDataPostbackEvent()
    TikTokBusiness.initializeSdk(config)
  }

  private func handleTrackingCall(
    _ call: FlutterMethodCall,
    result: @escaping FlutterResult
  ) {
    switch call.method {
    case "trackTikTokEvent":
      guard
        let arguments = call.arguments as? [String: Any],
        let name = arguments["name"] as? String,
        !name.isEmpty
      else {
        result(
          FlutterError(
            code: "invalid_event",
            message: "Event name is required.",
            details: nil
          )
        )
        return
      }
      let event = TikTokBaseEvent(
        eventName: name,
        properties: arguments["properties"] as? [String: Any] ?? [:],
        eventId: arguments["eventId"] as? String
      )
      TikTokBusiness.trackTTEvent(event)
      result(nil)

    case "identifyTikTokUser":
      let arguments = call.arguments as? [String: Any] ?? [:]
      TikTokBusiness.logout()
      TikTokBusiness.identify(
        withExternalID: arguments["externalId"] as? String,
        externalUserName: arguments["username"] as? String,
        phoneNumber: arguments["phone"] as? String,
        email: arguments["email"] as? String
      )
      result(nil)

    case "logoutTikTokUser":
      TikTokBusiness.logout()
      result(nil)

    case "requestTrackingAuthorization":
      requestTrackingAuthorization(result: result)

    case "getSnapAppData":
      result(buildSnapAppData())

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func requestTrackingAuthorization(result: @escaping FlutterResult) {
    if #available(iOS 14, *) {
      TikTokBusiness.requestTrackingAuthorization { status in
        DispatchQueue.main.async {
          result(status == ATTrackingManager.AuthorizationStatus.authorized.rawValue)
        }
      }
    } else {
      result(true)
    }
  }

  private func buildSnapAppData() -> [String: Any] {
    let bundle = Bundle.main
    let bundleId = bundle.bundleIdentifier ?? "com.barqwadih.app"
    let shortVersion = bundle.object(
      forInfoDictionaryKey: "CFBundleShortVersionString"
    ) as? String ?? ""
    let buildVersion = bundle.object(
      forInfoDictionaryKey: "CFBundleVersion"
    ) as? String ?? ""
    let screen = UIScreen.main
    let pixelWidth = Int(screen.bounds.width * screen.scale)
    let pixelHeight = Int(screen.bounds.height * screen.scale)
    let storage = deviceStorageInGigabytes()
    let trackingEnabled: Bool
    if #available(iOS 14, *) {
      trackingEnabled = ATTrackingManager.trackingAuthorizationStatus == .authorized
    } else {
      trackingEnabled = true
    }

    return [
      "app_id": trackingSetting("SnapchatIosAppId") ?? "6800784915",
      "advertiser_tracking_enabled": trackingEnabled,
      "extinfo": [
        "i2",
        bundleId,
        shortVersion,
        buildVersion,
        UIDevice.current.systemVersion,
        UIDevice.current.model,
        Locale.current.identifier,
        TimeZone.current.abbreviation() ?? "",
        "",
        pixelWidth,
        pixelHeight,
        String(format: "%.2f", screen.scale),
        ProcessInfo.processInfo.processorCount,
        storage.total,
        storage.free,
        TimeZone.current.identifier,
      ],
    ]
  }

  private func deviceStorageInGigabytes() -> (total: Int64, free: Int64) {
    guard
      let attributes = try? FileManager.default.attributesOfFileSystem(
        forPath: NSHomeDirectory()
      ),
      let total = attributes[.systemSize] as? NSNumber,
      let free = attributes[.systemFreeSize] as? NSNumber
    else {
      return (0, 0)
    }
    let bytesPerGigabyte = 1024.0 * 1024.0 * 1024.0
    return (
      Int64(total.doubleValue / bytesPerGigabyte),
      Int64(free.doubleValue / bytesPerGigabyte)
    )
  }

  private func trackingSetting(_ key: String) -> String? {
    guard
      let value = Bundle.main.object(forInfoDictionaryKey: key) as? String,
      !value.isEmpty,
      !value.hasPrefix("$(")
    else {
      return nil
    }
    return value
  }

  override func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    NSLog("APNs registration failed: %@", error.localizedDescription)
    super.application(
      application,
      didFailToRegisterForRemoteNotificationsWithError: error
    )
  }

  private static func normalizeImageToJpeg(
    at sourcePath: String,
    maxDimension: CGFloat,
    quality: CGFloat
  ) throws -> String {
    guard let image = UIImage(contentsOfFile: sourcePath) else {
      throw ImageConversionError.unreadableImage
    }

    let sourceSize = image.size
    let longestSide = max(sourceSize.width, sourceSize.height)
    // Keep each image around 650 KB or less. Ten images plus multipart fields
    // then remain below the production PHP request limit, while the backend
    // still has enough pixels to generate its 1280px detail variant.
    let byteTarget = 650_000
    let sizeCandidates: [CGFloat] = [maxDimension, 1200, 960]
    let qualityCandidates: [CGFloat] = [
      min(max(quality, 0.42), 0.90),
      0.66,
      0.56,
      0.46,
    ]
    var encodedData: Data?

    for candidateMaxDimension in sizeCandidates {
      let candidateScale = min(1, candidateMaxDimension / longestSide)
      let candidateSize = CGSize(
        width: max(1, floor(sourceSize.width * candidateScale)),
        height: max(1, floor(sourceSize.height * candidateScale))
      )
      let normalized = render(image, at: candidateSize)

      for candidateQuality in qualityCandidates {
        guard
          let candidateData = normalized.jpegData(
            compressionQuality: candidateQuality
          )
        else {
          continue
        }
        encodedData = candidateData
        if candidateData.count <= byteTarget {
          break
        }
      }
      if let encodedData, encodedData.count <= byteTarget {
        break
      }
    }

    guard let data = encodedData else {
      throw ImageConversionError.encodingFailed
    }

    let outputURL = FileManager.default.temporaryDirectory
      .appendingPathComponent("barq-upload-\(UUID().uuidString).jpg")
    try data.write(to: outputURL, options: .atomic)
    return outputURL.path
  }

  private static func render(_ image: UIImage, at size: CGSize) -> UIImage {
    let format = UIGraphicsImageRendererFormat.default()
    format.scale = 1
    format.opaque = true
    let renderer = UIGraphicsImageRenderer(size: size, format: format)
    return renderer.image { context in
      UIColor.white.setFill()
      context.fill(CGRect(origin: .zero, size: size))
      image.draw(in: CGRect(origin: .zero, size: size))
    }
  }

  private enum ImageConversionError: LocalizedError {
    case unreadableImage
    case encodingFailed

    var errorDescription: String? {
      switch self {
      case .unreadableImage:
        return "The selected image could not be read."
      case .encodingFailed:
        return "The selected image could not be encoded as JPEG."
      }
    }
  }
}
