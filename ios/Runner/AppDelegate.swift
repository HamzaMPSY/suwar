import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var ayahWidgetChannel: AyahWidgetChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    if let controller = window?.rootViewController as? FlutterViewController {
      ayahWidgetChannel = AyahWidgetChannel(messenger: controller.binaryMessenger)
      if let url = launchOptions?[.url] as? URL { ayahWidgetChannel?.handle(url) }
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  override func application(_ app: UIApplication, open url: URL,
      options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
    if ayahWidgetChannel?.handle(url) == true { return true }
    return super.application(app, open: url, options: options)
  }
}
