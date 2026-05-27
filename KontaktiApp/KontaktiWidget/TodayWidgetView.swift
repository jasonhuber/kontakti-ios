import SwiftUI
import WidgetKit

/// Root view that branches on `widgetFamily`. Supports home-screen
/// (`systemSmall`/`Medium`/`Large`) and accessory families used by the
/// iPhone lock screen and Apple Watch face (`accessoryCircular`,
/// `accessoryRectangular`, `accessoryInline`).
struct TodayWidgetView: View {
    let entry: TodayEntry
    @Environment(\.widgetFamily) private var family

    private let indigo = Color(red: 0.31, green: 0.27, blue: 0.90)

    var body: some View {
        switch family {
        case .systemSmall:
            smallView
        case .systemMedium:
            mediumView
        case .systemLarge:
            largeView
        case .accessoryCircular:
            circularAccessory
        case .accessoryRectangular:
            rectangularAccessory
        case .accessoryInline:
            inlineAccessory
        default:
            smallView
        }
    }

    // MARK: - Home screen

    private var smallView: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "tray.full.fill")
                    .foregroundColor(indigo)
                Spacer()
                Text("\(entry.totalCount)")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
            }
            Text(entry.totalCount == 1 ? "reach-out today" : "reach-outs today")
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer(minLength: 0)
            if let top = entry.items.first {
                Text(top.personName)
                    .font(.caption.bold())
                    .lineLimit(1)
                Text(top.kindLabel)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            } else {
                Text("All caught up")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
    }

    private var mediumView: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            ForEach(entry.items.prefix(2)) { item in
                row(item)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
    }

    private var largeView: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            ForEach(entry.items.prefix(4)) { item in
                row(item)
                if item.id != entry.items.prefix(4).last?.id {
                    Divider()
                }
            }
            Spacer(minLength: 0)
        }
        .padding(14)
    }

    private var header: some View {
        HStack {
            Image(systemName: "tray.full.fill")
                .foregroundColor(indigo)
            Text("Today")
                .font(.headline)
            Spacer()
            Text("\(entry.totalCount)")
                .font(.title3.bold())
                .foregroundColor(indigo)
        }
    }

    private func row(_ item: TodaySnapshotItem) -> some View {
        HStack(spacing: 10) {
            initialsBadge(for: item.personName)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.personName)
                    .font(.subheadline.bold())
                    .lineLimit(1)
                Text(item.reason)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            Image(systemName: item.iconName)
                .font(.caption)
                .foregroundColor(indigo)
        }
    }

    private func initialsBadge(for name: String) -> some View {
        let parts = name.split(separator: " ")
        let initials = parts.prefix(2).compactMap { $0.first.map(String.init) }.joined()
        return Text(initials.isEmpty ? "?" : initials)
            .font(.caption.bold())
            .foregroundColor(.white)
            .frame(width: 28, height: 28)
            .background(indigo)
            .clipShape(Circle())
    }

    // MARK: - Accessory (lock screen + watch face)

    private var circularAccessory: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 0) {
                Image(systemName: "tray.full.fill")
                    .font(.caption2)
                Text("\(entry.totalCount)")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.5)
            }
        }
        .widgetAccentable()
    }

    private var rectangularAccessory: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: "tray.full.fill")
                Text("Kontakti")
                    .font(.caption2.bold())
            }
            .widgetAccentable()
            if entry.totalCount == 0 {
                Text("All caught up")
                    .font(.caption2)
            } else {
                Text("\(entry.totalCount) reach-out\(entry.totalCount == 1 ? "" : "s") today")
                    .font(.caption.bold())
                if let top = entry.items.first {
                    Text(top.personName)
                        .font(.caption2)
                        .lineLimit(1)
                }
            }
        }
    }

    private var inlineAccessory: some View {
        Text(entry.totalCount == 0
             ? "Kontakti · all caught up"
             : "Kontakti · \(entry.totalCount) reach-out\(entry.totalCount == 1 ? "" : "s")")
    }
}
