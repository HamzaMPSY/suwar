import Flutter
import UIKit
import WidgetKit

final class AyahWidgetChannel {
    private let channel: FlutterMethodChannel
    private var pending: String?
    init(messenger: FlutterBinaryMessenger) {
        channel = FlutterMethodChannel(name: "suwar/ayah_widget", binaryMessenger: messenger)
        channel.setMethodCallHandler { [weak self] call, result in
            guard let self = self else { return }
            do {
                switch call.method {
                case "getState": result(RemembranceStore.settings().dictionary)
                case "setTopic":
                    guard let topic = call.arguments as? String else { throw NSError(domain: "SuwarAyah", code: 2) }
                    try RemembranceStore.setTopic(topic)
                    self.reload()
                    result(RemembranceStore.settings().dictionary)
                case "next":
                    try RemembranceStore.next()
                    self.reload()
                    result(RemembranceStore.settings().dictionary)
                case "requestPin": result(false) // iOS placement is user-controlled.
                case "consumeAyahLaunch":
                    let id = self.pending
                    self.pending = nil
                    result(id)
                default: result(FlutterMethodNotImplemented)
                }
            } catch { result(FlutterError(code: "ayah_widget_error", message: error.localizedDescription, details: nil)) }
        }
    }
    private func reload() {
        if #available(iOS 14.0, *) { WidgetCenter.shared.reloadTimelines(ofKind: "SuwarAyahWidget") }
    }
    @discardableResult func handle(_ url: URL) -> Bool {
        guard url.scheme == "suwar", url.host == "ayah" else { return false }
        let parts = url.pathComponents.filter { $0 != "/" }
        guard parts.count == 2, let surah = Int(parts[0]), let ayah = Int(parts[1]) else { return false }
        let id = "\(surah):\(ayah)"
        guard RemembranceStore.verses.contains(where: { $0.id == id }) else { return false }
        pending = id
        channel.invokeMethod("openAyah", arguments: nil)
        return true
    }
}
