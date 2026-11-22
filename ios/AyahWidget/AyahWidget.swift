import WidgetKit
import SwiftUI

struct AyahEntry: TimelineEntry {
    let date: Date
    let settings: RemembranceSettings
}
struct AyahProvider: TimelineProvider {
    func placeholder(in context: Context) -> AyahEntry {
        AyahEntry(date: Date(), settings: RemembranceSettings(topic: "comfort", offset: 0))
    }
    func getSnapshot(in context: Context, completion: @escaping (AyahEntry) -> Void) {
        completion(AyahEntry(date: Date(), settings: RemembranceStore.settings()))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<AyahEntry>) -> Void) {
        let now = Date()
        let settings = RemembranceStore.settings()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let midnight = calendar.startOfDay(for: now)
        var entries = [AyahEntry(date: now, settings: settings)]
        for day in 1...7 {
            if let date = calendar.date(byAdding: .day, value: day, to: midnight) {
                entries.append(AyahEntry(date: date, settings: settings))
            }
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

struct AyahWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: AyahEntry
    private var compact: Bool { family == .accessoryRectangular }
    private let green = Color(red: 23/255, green: 63/255, blue: 53/255)
    private let paper = Color(red: 1, green: 252/255, blue: 245/255)
    @ViewBuilder var body: some View {
        if #available(iOSApplicationExtension 17.0, *) {
            content.containerBackground(for: .widget) { compact ? Color.clear : paper }
        } else {
            content.background(compact ? Color.clear : paper)
        }
    }
    @ViewBuilder private var content: some View {
        if let verse = RemembranceStore.selected(date: entry.date, settings: entry.settings, compact: compact) {
            VStack(alignment: .trailing, spacing: compact ? 3 : 12) {
                if !compact {
                    Text("سُوَر · \(RemembranceStore.topics[verse.topic] ?? "")")
                        .font(.system(size: 12)).foregroundStyle(green.opacity(0.8))
                }
                Text(verbatim: verse.lexicalText)
                    .font(.custom("KFGQPCWARSHUthmanicScript-Regul", fixedSize: compact ? 17 : 25))
                    .multilineTextAlignment(.trailing)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(compact ? 1 : 4)
                Text(verbatim: verse.reference).font(.system(size: compact ? 10 : 12))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
            .foregroundStyle(compact ? Color.primary : green)
            .environment(\.layoutDirection, .rightToLeft)
            .widgetURL(URL(string: "suwar://ayah/\(verse.surahId)/\(verse.ayahNumber)"))
            .accessibilityElement(children: .combine)
        } else {
            Text("افتح سُوَر لتحديث الأداة").font(.caption)
        }
    }
}

@main
struct SuwarAyahWidget: Widget {
    let kind = "SuwarAyahWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: AyahProvider()) { entry in
            AyahWidgetView(entry: entry)
        }
        .configurationDisplayName("آية تُطمئنك")
        .description("آيات كاملة من رواية ورش عن الطمأنينة والجنة وقدرة الله.")
        .supportedFamilies([.accessoryRectangular, .systemMedium])
    }
}
