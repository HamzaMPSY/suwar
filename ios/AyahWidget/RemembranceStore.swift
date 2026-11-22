import Foundation

struct RemembranceVerse: Decodable {
    let id: String
    let surahId: Int
    let ayahNumber: Int
    let topic: String
    let surahName: String
    let context: String
    let compact: Bool
    let sourceText: String
    var lexicalText: String {
        guard let range = sourceText.range(of: "\\s+[٠-٩۰-۹0-9]+$", options: .regularExpression) else { return sourceText }
        let digits = sourceText[range].compactMap { $0.wholeNumberValue }.map(String.init).joined()
        guard Int(digits) == ayahNumber else { return sourceText }
        return String(sourceText[..<range.lowerBound])
    }
    var reference: String { "\(surahName) · \(ayahNumber) · ورش" }
}

struct RemembranceSettings {
    let topic: String
    let offset: Int
    var dictionary: [String: Any] { ["topic": topic, "offset": offset] }
}

enum RemembranceStore {
    static let group = "group.com.suwar.suwar"
    static let topics = ["all": "كل المعاني", "comfort": "طمأنينة", "jannah": "الجنة", "power": "قدرة الله"]
    static var defaults: UserDefaults? { UserDefaults(suiteName: group) }
    static let verses: [RemembranceVerse] = {
        guard let url = Bundle.main.url(forResource: "verses", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let entries = try? JSONDecoder().decode([RemembranceVerse].self, from: data) else { return [] }
        return entries
    }()
    static func settings() -> RemembranceSettings {
        let topic = defaults?.string(forKey: "ayah.topic") ?? "all"
        return RemembranceSettings(topic: topics[topic] == nil ? "all" : topic,
            offset: max(0, defaults?.integer(forKey: "ayah.offset") ?? 0))
    }
    static func setTopic(_ value: String) throws {
        guard topics[value] != nil, let preferences = defaults else {
            throw NSError(domain: "SuwarAyah", code: 1)
        }
        preferences.set(value, forKey: "ayah.topic")
        preferences.set(0, forKey: "ayah.offset")
    }
    static func next() throws {
        guard let preferences = defaults else { throw NSError(domain: "SuwarAyah", code: 1) }
        preferences.set((settings().offset + 1) % 1000000, forKey: "ayah.offset")
    }
    static func selected(date: Date, settings: RemembranceSettings, compact: Bool) -> RemembranceVerse? {
        let pool = verses.filter { (settings.topic == "all" || $0.topic == settings.topic) && (!compact || $0.compact) }
        guard !pool.isEmpty else { return nil }
        var local = Calendar(identifier: .gregorian)
        local.timeZone = .current
        let components = local.dateComponents([.year, .month, .day], from: date)
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(secondsFromGMT: 0)!
        guard let day = utc.date(from: components) else { return nil }
        let index = (Int(day.timeIntervalSince1970 / 86400) + settings.offset) % pool.count
        return pool[(index + pool.count) % pool.count]
    }
}
