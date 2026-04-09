import WidgetKit
import SwiftUI

nonisolated struct WidgetData {
    let isRunning: Bool
    let activeMode: String
    let siteLabel: String
    let completed: Int
    let total: Int
    let working: Int
    let failed: Int
    let noAcc: Int
    let tempDis: Int
    let permDis: Int
    let successRate: Double
    let isPaused: Bool
    let isStopping: Bool
    let statusLabel: String
    let elapsed: String
    let eta: String
    let concurrency: Int
    let networkMode: String
    let speedPerMin: Double
    let totalCredentials: Int
    let totalCards: Int
    let workingCredentials: Int
    let workingCards: Int
    let lifetimeTested: Int
    let lifetimeWorking: Int
    let lifetimeRate: Double
    let totalBatches: Int
    let lastUpdate: Date

    static func load() -> WidgetData {
        let d = UserDefaults(suiteName: "group.app.rork.ve5l1conjgc135kle8kuj")
        let ts = d?.double(forKey: "widget_lastUpdate") ?? 0
        return WidgetData(
            isRunning: d?.bool(forKey: "widget_isRunning") ?? false,
            activeMode: d?.string(forKey: "widget_activeMode") ?? "none",
            siteLabel: d?.string(forKey: "widget_siteLabel") ?? "",
            completed: d?.integer(forKey: "widget_completed") ?? 0,
            total: d?.integer(forKey: "widget_total") ?? 0,
            working: d?.integer(forKey: "widget_working") ?? 0,
            failed: d?.integer(forKey: "widget_failed") ?? 0,
            noAcc: d?.integer(forKey: "widget_noAcc") ?? 0,
            tempDis: d?.integer(forKey: "widget_tempDis") ?? 0,
            permDis: d?.integer(forKey: "widget_permDis") ?? 0,
            successRate: d?.double(forKey: "widget_successRate") ?? 0,
            isPaused: d?.bool(forKey: "widget_isPaused") ?? false,
            isStopping: d?.bool(forKey: "widget_isStopping") ?? false,
            statusLabel: d?.string(forKey: "widget_statusLabel") ?? "IDLE",
            elapsed: d?.string(forKey: "widget_elapsed") ?? "--",
            eta: d?.string(forKey: "widget_eta") ?? "--",
            concurrency: d?.integer(forKey: "widget_concurrency") ?? 4,
            networkMode: d?.string(forKey: "widget_networkMode") ?? "--",
            speedPerMin: d?.double(forKey: "widget_speedPerMin") ?? 0,
            totalCredentials: d?.integer(forKey: "widget_totalCredentials") ?? 0,
            totalCards: d?.integer(forKey: "widget_totalCards") ?? 0,
            workingCredentials: d?.integer(forKey: "widget_workingCredentials") ?? 0,
            workingCards: d?.integer(forKey: "widget_workingCards") ?? 0,
            lifetimeTested: d?.integer(forKey: "widget_lifetimeTested") ?? 0,
            lifetimeWorking: d?.integer(forKey: "widget_lifetimeWorking") ?? 0,
            lifetimeRate: d?.double(forKey: "widget_lifetimeRate") ?? 0,
            totalBatches: d?.integer(forKey: "widget_totalBatches") ?? 0,
            lastUpdate: ts > 0 ? Date(timeIntervalSince1970: ts) : .distantPast
        )
    }

    var progress: Double {
        guard total > 0 else { return 0 }
        return Double(completed) / Double(total)
    }

    var statusColor: Color {
        if isStopping { return .red }
        if isPaused { return .orange }
        if isRunning { return .green }
        return .secondary
    }

    var siteColor: Color {
        switch activeMode {
        case "login": .green
        case "ppsr": .teal
        default: .cyan
        }
    }

    var siteIcon: String {
        switch activeMode {
        case "login": "rectangle.split.2x1.fill"
        case "ppsr": "bolt.shield.fill"
        default: "circle"
        }
    }

    var isStale: Bool {
        Date().timeIntervalSince(lastUpdate) > 300
    }
}

nonisolated struct SitchomaticEntry: TimelineEntry {
    let date: Date
    let data: WidgetData
}

nonisolated struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SitchomaticEntry {
        SitchomaticEntry(date: .now, data: .load())
    }

    func getSnapshot(in context: Context, completion: @escaping (SitchomaticEntry) -> Void) {
        completion(SitchomaticEntry(date: .now, data: .load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SitchomaticEntry>) -> Void) {
        let data = WidgetData.load()
        let entry = SitchomaticEntry(date: .now, data: data)
        let nextUpdate: Date
        if data.isRunning {
            nextUpdate = Date().addingTimeInterval(30)
        } else {
            nextUpdate = Date().addingTimeInterval(900)
        }
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }
}

struct SitchomaticWidgetView: View {
    @Environment(\.widgetFamily) var family
    var entry: SitchomaticEntry

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(data: entry.data)
        case .systemMedium:
            MediumWidgetView(data: entry.data)
        case .systemLarge:
            LargeWidgetView(data: entry.data)
        case .accessoryCircular:
            CircularAccessoryView(data: entry.data)
        case .accessoryRectangular:
            RectangularAccessoryView(data: entry.data)
        case .accessoryInline:
            InlineAccessoryView(data: entry.data)
        default:
            SmallWidgetView(data: entry.data)
        }
    }
}

struct SmallWidgetView: View {
    let data: WidgetData

    var body: some View {
        if data.isRunning {
            runningSmall
        } else {
            idleSmall
        }
    }

    private var runningSmall: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Circle()
                    .fill(data.statusColor)
                    .frame(width: 6, height: 6)
                Text(data.statusLabel)
                    .font(.system(size: 9, weight: .heavy, design: .monospaced))
                    .foregroundStyle(data.statusColor)
                Spacer()
                Image(systemName: data.siteIcon)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(data.siteColor)
            }

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("\(data.completed)")
                    .font(.system(size: 32, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.6)
                Text("/\(data.total)")
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.5))
            }

            ProgressView(value: data.progress)
                .tint(data.siteColor)

            HStack(spacing: 0) {
                Label("\(data.working)", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(.green)
                Spacer()
                Label("\(data.failed)", systemImage: "xmark.circle.fill")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(.red)
                Spacer()
                Text("\(Int(data.successRate * 100))%")
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .foregroundStyle(rateColor(data.successRate))
            }
        }
        .containerBackground(for: .widget) {
            Color.black
        }
    }

    private var idleSmall: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: "bolt.shield.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.cyan)
                Text("SITCH")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)
                Spacer()
            }

            Spacer()

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text("\(data.workingCredentials)")
                        .font(.system(size: 24, weight: .black, design: .monospaced))
                        .foregroundStyle(.green)
                    Text("HITS")
                        .font(.system(size: 9, weight: .heavy, design: .monospaced))
                        .foregroundStyle(.green.opacity(0.6))
                }
                Text("\(data.totalCredentials) credentials · \(data.totalCards) cards")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.4))
            }

            if data.lifetimeTested > 0 {
                HStack(spacing: 4) {
                    Text("\(formatNumber(data.lifetimeTested))")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.6))
                    Text("LIFETIME")
                        .font(.system(size: 8, weight: .heavy, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.25))
                }
            }
        }
        .containerBackground(for: .widget) {
            Color.black
        }
    }

    private func formatNumber(_ n: Int) -> String {
        if n >= 1000 { return String(format: "%.1fK", Double(n) / 1000) }
        return "\(n)"
    }
}

struct MediumWidgetView: View {
    let data: WidgetData

    var body: some View {
        if data.isRunning {
            runningMedium
        } else {
            idleMedium
        }
    }

    private var runningMedium: some View {
        VStack(spacing: 8) {
            HStack {
                HStack(spacing: 4) {
                    Circle()
                        .fill(data.statusColor)
                        .frame(width: 6, height: 6)
                    Image(systemName: data.siteIcon)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(data.siteColor)
                    Text(data.siteLabel)
                        .font(.system(size: 10, weight: .heavy, design: .monospaced))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }

                Spacer()

                HStack(spacing: 3) {
                    Text(data.statusLabel)
                        .font(.system(size: 9, weight: .heavy, design: .monospaced))
                        .foregroundStyle(data.statusColor)
                    if data.speedPerMin > 0 {
                        Text("·")
                            .foregroundStyle(.white.opacity(0.3))
                        Text(String(format: "%.1f/m", data.speedPerMin))
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
            }

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(data.completed)/\(data.total)")
                        .font(.system(size: 22, weight: .black, design: .monospaced))
                        .foregroundStyle(.white)
                        .minimumScaleFactor(0.7)

                    ProgressView(value: data.progress)
                        .tint(data.siteColor)

                    HStack(spacing: 0) {
                        Text(data.elapsed)
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.5))
                        Spacer()
                        Text(data.eta)
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                }

                VStack(spacing: 6) {
                    HStack(spacing: 10) {
                        miniStat(value: data.working, label: "HIT", color: .green)
                        miniStat(value: data.noAcc, label: "NA", color: .red)
                    }
                    HStack(spacing: 10) {
                        miniStat(value: data.tempDis, label: "TD", color: .orange)
                        miniStat(value: data.permDis, label: "PD", color: .purple)
                    }
                }
                .frame(width: 100)
            }
        }
        .containerBackground(for: .widget) {
            Color.black
        }
    }

    private var idleMedium: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 5) {
                    Image(systemName: "bolt.shield.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.cyan)
                    Text("SITCHOMATIC")
                        .font(.system(size: 12, weight: .black, design: .monospaced))
                        .foregroundStyle(.white)
                }

                Spacer()

                HStack(spacing: 3) {
                    Text("\(data.workingCredentials)")
                        .font(.system(size: 28, weight: .black, design: .monospaced))
                        .foregroundStyle(.green)
                    VStack(alignment: .leading, spacing: 0) {
                        Text("WORKING")
                            .font(.system(size: 8, weight: .heavy, design: .monospaced))
                            .foregroundStyle(.green.opacity(0.6))
                        Text("of \(data.totalCredentials)")
                            .font(.system(size: 8, weight: .medium, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.35))
                    }
                }

                if data.totalCards > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "creditcard.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(.teal.opacity(0.6))
                        Text("\(data.workingCards)/\(data.totalCards) cards alive")
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 8) {
                if data.lifetimeTested > 0 {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("LIFETIME")
                            .font(.system(size: 8, weight: .heavy, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.25))
                        Text(formatLargeNumber(data.lifetimeTested))
                            .font(.system(size: 16, weight: .heavy, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.7))
                        Text("tested")
                            .font(.system(size: 8, weight: .medium, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.3))
                    }
                }

                Spacer()

                HStack(spacing: 8) {
                    lifetimeStat(value: "\(Int(data.lifetimeRate * 100))%", label: "RATE", color: rateColor(data.lifetimeRate))
                    lifetimeStat(value: "\(data.totalBatches)", label: "RUNS", color: .white.opacity(0.6))
                }
            }
        }
        .containerBackground(for: .widget) {
            Color.black
        }
    }

    private func miniStat(value: Int, label: String, color: Color) -> some View {
        VStack(spacing: 1) {
            Text("\(value)")
                .font(.system(size: 14, weight: .heavy, design: .monospaced))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 7, weight: .heavy, design: .monospaced))
                .foregroundStyle(color.opacity(0.5))
        }
    }

    private func lifetimeStat(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 1) {
            Text(value)
                .font(.system(size: 12, weight: .heavy, design: .monospaced))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 7, weight: .heavy, design: .monospaced))
                .foregroundStyle(.white.opacity(0.25))
        }
    }

    private func formatLargeNumber(_ n: Int) -> String {
        if n >= 10000 { return String(format: "%.1fK", Double(n) / 1000) }
        if n >= 1000 { return String(format: "%.1fK", Double(n) / 1000) }
        return "\(n)"
    }
}

struct LargeWidgetView: View {
    let data: WidgetData

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                HStack(spacing: 5) {
                    Image(systemName: "bolt.shield.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.cyan)
                    Text("SITCHOMATIC")
                        .font(.system(size: 12, weight: .black, design: .monospaced))
                        .foregroundStyle(.white)
                }
                Spacer()
                if data.isRunning {
                    HStack(spacing: 3) {
                        Circle()
                            .fill(data.statusColor)
                            .frame(width: 6, height: 6)
                        Text(data.statusLabel)
                            .font(.system(size: 9, weight: .heavy, design: .monospaced))
                            .foregroundStyle(data.statusColor)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(data.statusColor.opacity(0.15))
                    .clipShape(Capsule())
                } else {
                    Text("IDLE")
                        .font(.system(size: 9, weight: .heavy, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }

            if data.isRunning {
                runningLargeBody
            } else {
                idleLargeBody
            }
        }
        .containerBackground(for: .widget) {
            Color.black
        }
    }

    private var runningLargeBody: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: data.siteIcon)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(data.siteColor)
                Text(data.siteLabel)
                    .font(.system(size: 11, weight: .heavy, design: .monospaced))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Spacer()
                if data.speedPerMin > 0 {
                    Text(String(format: "%.1f/min", data.speedPerMin))
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.4))
                }
            }

            HStack(alignment: .bottom, spacing: 4) {
                Text("\(data.completed)")
                    .font(.system(size: 36, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)
                Text("/ \(data.total)")
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.4))
                Spacer()
                Text("\(Int(data.successRate * 100))%")
                    .font(.system(size: 20, weight: .black, design: .monospaced))
                    .foregroundStyle(rateColor(data.successRate))
            }

            ProgressView(value: data.progress)
                .tint(data.siteColor)

            HStack {
                Text(data.elapsed)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.5))
                Spacer()
                Text("ETA \(data.eta)")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.35))
            }

            HStack(spacing: 6) {
                resultBox(value: data.working, label: "WORKING", color: .green, icon: "checkmark.circle.fill")
                resultBox(value: data.noAcc, label: "NO ACC", color: .red, icon: "xmark.circle.fill")
                resultBox(value: data.tempDis, label: "TEMP DIS", color: .orange, icon: "clock.badge.exclamationmark")
                resultBox(value: data.permDis, label: "PERM DIS", color: .purple, icon: "lock.fill")
            }

            Spacer(minLength: 0)

            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "network")
                        .font(.system(size: 9))
                    Text(data.networkMode)
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                }
                .foregroundStyle(.white.opacity(0.3))

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 9))
                    Text("×\(data.concurrency)")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                }
                .foregroundStyle(.white.opacity(0.3))
            }
        }
    }

    private var idleLargeBody: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("CREDENTIALS")
                        .font(.system(size: 8, weight: .heavy, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.3))
                    HStack(alignment: .bottom, spacing: 4) {
                        Text("\(data.workingCredentials)")
                            .font(.system(size: 28, weight: .black, design: .monospaced))
                            .foregroundStyle(.green)
                        Text("/ \(data.totalCredentials)")
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.3))
                    }
                    Text("working")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundStyle(.green.opacity(0.5))
                }

                Spacer()

                if data.totalCards > 0 {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("CARDS")
                            .font(.system(size: 8, weight: .heavy, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.3))
                        HStack(alignment: .bottom, spacing: 4) {
                            Text("\(data.workingCards)")
                                .font(.system(size: 28, weight: .black, design: .monospaced))
                                .foregroundStyle(.teal)
                            Text("/ \(data.totalCards)")
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.3))
                        }
                        Text("alive")
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundStyle(.teal.opacity(0.5))
                    }
                }
            }

            Divider().background(.white.opacity(0.1))

            HStack(spacing: 12) {
                lifetimeBox(value: formatLargeNumber(data.lifetimeTested), label: "TESTED", color: .white.opacity(0.7))
                lifetimeBox(value: formatLargeNumber(data.lifetimeWorking), label: "FOUND", color: .green)
                lifetimeBox(value: "\(Int(data.lifetimeRate * 100))%", label: "RATE", color: rateColor(data.lifetimeRate))
                lifetimeBox(value: "\(data.totalBatches)", label: "BATCHES", color: .cyan)
            }

            Spacer(minLength: 0)

            if data.lastUpdate != .distantPast {
                Text("Updated \(data.lastUpdate, style: .relative) ago")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.2))
            }
        }
    }

    private func resultBox(value: Int, label: String, color: Color, icon: String) -> some View {
        VStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(color)
            Text("\(value)")
                .font(.system(size: 16, weight: .heavy, design: .monospaced))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 7, weight: .heavy, design: .monospaced))
                .foregroundStyle(color.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(color.opacity(0.08))
        .clipShape(.rect(cornerRadius: 8))
    }

    private func lifetimeBox(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 14, weight: .heavy, design: .monospaced))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 7, weight: .heavy, design: .monospaced))
                .foregroundStyle(.white.opacity(0.25))
        }
        .frame(maxWidth: .infinity)
    }

    private func formatLargeNumber(_ n: Int) -> String {
        if n >= 10000 { return String(format: "%.1fK", Double(n) / 1000) }
        return "\(n)"
    }
}

struct CircularAccessoryView: View {
    let data: WidgetData

    var body: some View {
        if data.isRunning {
            ZStack {
                AccessoryWidgetBackground()
                let progress = data.total > 0 ? Double(data.completed) / Double(data.total) : 0
                ProgressView(value: progress) {
                    VStack(spacing: 0) {
                        Text("\(data.completed)")
                            .font(.system(size: 14, weight: .heavy, design: .monospaced))
                        Text("/\(data.total)")
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
                .progressViewStyle(.circular)
            }
        } else {
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 0) {
                    Text("\(data.workingCredentials)")
                        .font(.system(size: 16, weight: .heavy, design: .monospaced))
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

struct RectangularAccessoryView: View {
    let data: WidgetData

    var body: some View {
        if data.isRunning {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 3) {
                    Image(systemName: data.siteIcon)
                        .font(.system(size: 9, weight: .bold))
                    Text(data.siteLabel)
                        .font(.system(size: 10, weight: .heavy, design: .monospaced))
                        .lineLimit(1)
                    Spacer()
                    Text(data.statusLabel)
                        .font(.system(size: 8, weight: .heavy, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                ProgressView(value: data.progress)
                HStack {
                    Text("\(data.completed)/\(data.total)")
                        .font(.system(size: 11, weight: .heavy, design: .monospaced))
                    Spacer()
                    Text("✓\(data.working)")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                    Text("✗\(data.failed)")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
        } else {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 3) {
                    Image(systemName: "bolt.shield.fill")
                        .font(.system(size: 9, weight: .bold))
                    Text("SITCH")
                        .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    Spacer()
                    Text("IDLE")
                        .font(.system(size: 8, weight: .heavy, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text("\(data.workingCredentials) hits")
                        .font(.system(size: 11, weight: .heavy, design: .monospaced))
                    Spacer()
                    Text("\(data.totalCredentials) creds")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                if data.lifetimeTested > 0 {
                    Text("\(data.lifetimeTested) lifetime tested")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

struct InlineAccessoryView: View {
    let data: WidgetData

    var body: some View {
        if data.isRunning {
            Text("\(data.completed)/\(data.total) · ✓\(data.working)")
        } else {
            Text("\(data.workingCredentials) hits · \(data.totalCredentials) creds")
        }
    }
}

private func rateColor(_ rate: Double) -> Color {
    if rate >= 0.5 { return .green }
    if rate >= 0.2 { return .yellow }
    return .red
}

struct SitchomaticWidget: Widget {
    let kind: String = "SitchomaticWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            SitchomaticWidgetView(entry: entry)
        }
        .configurationDisplayName("Sitchomatic")
        .description("Live batch progress and credential stats at a glance.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .systemLarge,
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline
        ])
        .containerBackgroundRemovable(false)
    }
}
