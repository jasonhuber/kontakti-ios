import WidgetKit
import SwiftUI

/// Today inbox widget. Single widget definition that supports a range of
/// `WidgetFamily` values so the user can place it on:
///   - the iPhone home screen (small / medium / large)
///   - the iPhone lock screen (accessory families)
///   - an Apple Watch face (accessory families show up automatically in
///     watchOS 10+ once the user adds them via the iPhone Watch app)
struct TodayWidget: Widget {
    private let kind = KontaktiWidgetSharedConfig.widgetKind

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TodayProvider()) { entry in
            TodayWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
                .widgetURL(URL(string: "kontakti://today"))
        }
        .configurationDisplayName("Kontakti Today")
        .description("Today's reach-outs at a glance.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .systemLarge,
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline
        ])
    }
}

@main
struct KontaktiWidgetBundle: WidgetBundle {
    var body: some Widget {
        TodayWidget()
    }
}
