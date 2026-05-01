import SwiftUI

/// GitHub-style contribution heatmap of every capture in the vault.
///
/// One cell per day, 7 rows (Sun–Sat) × 53 columns. Color intensity buckets
/// per-day capture count. Clicking a populated cell switches to the Library
/// tab and filters down to that day. The user can scrub between years with
/// the prev/next buttons in the header.
struct MardiTimelineView: View {
    @EnvironmentObject var env: AppEnvironment
    @Binding var tab: DashboardTab
    @Binding var dayFilter: Date?

    @State private var counts: [Date: Int] = [:]
    @State private var year: Int = Calendar(identifier: .gregorian).component(.year, from: Date())
    @State private var hoveredDay: Date? = nil
    @State private var loading: Bool = true

    private let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.firstWeekday = 1 // Sunday — matches GitHub's grid orientation.
        return c
    }()

    var body: some View {
        VStack(spacing: 0) {
            header
            BrailleDivider(color: Palette.neonOrange.opacity(0.45)).padding(.horizontal, 4)
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 22) {
                    statsRow
                    heatmapPanel
                    legendRow
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 22)
            }
            .background(
                ZStack {
                    Palette.charcoal
                    BrailleField(color: Palette.brailleDim, opacity: 0.20, fontSize: 13, density: 0.18)
                }
            )
        }
        .task {
            await load()
        }
    }

    // MARK: - Chrome

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 7) {
                    Text("⠶⠶")
                        .monoFont(11)
                        .foregroundStyle(Palette.neonOrange)
                    Text("[MARDI :: TIMELINE]")
                        .monoFont(12, weight: .bold)
                        .tracking(2)
                        .foregroundStyle(Palette.textPrimary)
                }
                Text("captures per day · click any cell to filter the library")
                    .monoFont(9)
                    .foregroundStyle(Palette.textMuted)
            }
            Spacer()
            yearSwitcher
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(
            ZStack {
                Palette.panelSlate
                BrailleField(color: Palette.brailleDim, opacity: 0.40, fontSize: 10, density: 0.30)
            }
        )
    }

    private var yearSwitcher: some View {
        HStack(spacing: 8) {
            Button(action: { year -= 1 }) {
                Text("← \(year - 1)")
                    .monoFont(10, weight: .bold)
                    .tracking(1.2)
            }
            .buttonStyle(.pixel(Palette.textSecondary))
            HStack(spacing: 5) {
                Text("⡶").monoFont(11, weight: .bold).foregroundStyle(Palette.neonOrange)
                Text("\(String(year))")
                    .monoFont(13, weight: .bold)
                    .tracking(2)
                    .foregroundStyle(Palette.textPrimary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Palette.neonOrange.opacity(0.10))
            .pixelBorder(Palette.neonOrange, width: 1)
            Button(action: { year += 1 }) {
                Text("\(year + 1) →")
                    .monoFont(10, weight: .bold)
                    .tracking(1.2)
            }
            .buttonStyle(.pixel(Palette.textSecondary))
            .disabled(year >= calendar.component(.year, from: Date()))
        }
    }

    private var statsRow: some View {
        let s = stats
        return HStack(spacing: 12) {
            statCard(label: "TOTAL", value: "\(s.total)", tint: Palette.neonCyan, glyph: "⣿")
            statCard(label: "ACTIVE DAYS", value: "\(s.activeDays)", tint: Palette.neonViolet, glyph: "⠿")
            statCard(label: "BEST DAY", value: s.bestDayLabel, tint: Palette.neonMagenta, glyph: "⣿⣿")
            statCard(label: "STREAK", value: "\(s.currentStreak) d", tint: Palette.neonOrange, glyph: "⡶")
        }
    }

    private func statCard(label: String, value: String, tint: Color, glyph: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Text(glyph)
                    .monoFont(10, weight: .bold)
                    .foregroundStyle(tint)
                Text(label)
                    .monoFont(9, weight: .bold)
                    .tracking(1.3)
                    .foregroundStyle(Palette.textMuted)
            }
            Text(value)
                .monoFont(15, weight: .bold)
                .tracking(0.8)
                .foregroundStyle(Palette.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Palette.panelSlateHi)
        .pixelBorder(tint.opacity(0.45), width: 1)
    }

    private var heatmapPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 5) {
                Text("⡶").monoFont(10, weight: .bold).foregroundStyle(Palette.neonOrange)
                Text("HEATMAP").monoFont(9, weight: .bold).tracking(1.5).foregroundStyle(Palette.textMuted)
                Spacer()
                if let day = hoveredDay {
                    Text(tooltip(for: day).uppercased())
                        .monoFont(9, weight: .bold)
                        .tracking(1.2)
                        .foregroundStyle(Palette.textSecondary)
                }
            }
            HeatmapGrid(
                year: year,
                counts: counts,
                hovered: $hoveredDay,
                onTap: handleTap(day:),
                calendar: calendar
            )
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(Palette.panelSlate)
        .pixelBorder(Palette.neonOrange.opacity(0.45), width: 1)
    }

    private var legendRow: some View {
        HStack(spacing: 8) {
            Text("LESS")
                .monoFont(9, weight: .bold)
                .tracking(1.5)
                .foregroundStyle(Palette.textMuted)
            ForEach(0..<5, id: \.self) { bucket in
                Rectangle()
                    .fill(HeatmapGrid.colorForBucket(bucket))
                    .frame(width: 12, height: 12)
                    .pixelBorder(Palette.border.opacity(0.6), width: 1)
            }
            Text("MORE")
                .monoFont(9, weight: .bold)
                .tracking(1.5)
                .foregroundStyle(Palette.textMuted)
            Spacer()
        }
    }

    // MARK: - Logic

    private struct Stats {
        var total: Int
        var activeDays: Int
        var bestDay: Date?
        var bestCount: Int
        var currentStreak: Int

        var bestDayLabel: String {
            guard let day = bestDay else { return "—" }
            return "\(bestCount) on \(Self.shortFmt.string(from: day))"
        }

        nonisolated(unsafe) static let shortFmt: DateFormatter = {
            let f = DateFormatter()
            f.dateFormat = "MMM d"
            return f
        }()
    }

    private var stats: Stats {
        let cal = calendar
        let yearCounts = counts.filter { cal.component(.year, from: $0.key) == year }
        let total = yearCounts.values.reduce(0, +)
        let active = yearCounts.count
        var best: (Date, Int)? = nil
        for (d, c) in yearCounts {
            if best == nil || c > best!.1 {
                best = (d, c)
            }
        }

        // Current streak — consecutive days ending today (or yesterday if today is empty).
        var streak = 0
        var cursor = cal.startOfDay(for: Date())
        if counts[cursor] == nil {
            cursor = cal.date(byAdding: .day, value: -1, to: cursor) ?? cursor
        }
        while let count = counts[cursor], count > 0 {
            streak += 1
            cursor = cal.date(byAdding: .day, value: -1, to: cursor) ?? cursor
        }

        return Stats(
            total: total,
            activeDays: active,
            bestDay: best?.0,
            bestCount: best?.1 ?? 0,
            currentStreak: streak
        )
    }

    private func handleTap(day: Date) {
        dayFilter = day
        tab = .library
        env.lastToast = "Filtering library to \(Stats.shortFmt.string(from: day))."
    }

    private func tooltip(for day: Date) -> String {
        let count = counts[day] ?? 0
        return "\(Stats.shortFmt.string(from: day)) · \(count) capture\(count == 1 ? "" : "s")"
    }

    private func load() async {
        loading = true
        defer { loading = false }
        do {
            let bucketed = try await env.store.countsByDay()
            counts = bucketed
        } catch {
            counts = [:]
        }
    }
}

// MARK: - Heatmap grid

private struct HeatmapGrid: View {
    let year: Int
    let counts: [Date: Int]
    @Binding var hovered: Date?
    var onTap: (Date) -> Void
    let calendar: Calendar

    private let cellSize: CGFloat = 12
    private let cellGap: CGFloat = 3

    var body: some View {
        let cols = weekColumns()
        VStack(alignment: .leading, spacing: 6) {
            monthLabels(weeks: cols)
            HStack(alignment: .top, spacing: 6) {
                dayLabels
                weekColumnsView(cols: cols)
            }
        }
    }

    /// Each entry is a column of 7 (Sun..Sat) optional dates. nil = before
    /// year start or after year end.
    private func weekColumns() -> [[Date?]] {
        var components = DateComponents()
        components.year = year
        components.month = 1
        components.day = 1
        guard let jan1 = calendar.date(from: components) else { return [] }
        let weekday = calendar.component(.weekday, from: jan1) // 1 = Sunday
        var cursor = calendar.date(byAdding: .day, value: -(weekday - 1), to: jan1) ?? jan1
        components.month = 12
        components.day = 31
        guard let dec31 = calendar.date(from: components) else { return [] }
        let dec31Weekday = calendar.component(.weekday, from: dec31)
        let trailingFill = 7 - dec31Weekday
        let endCursor = calendar.date(byAdding: .day, value: trailingFill, to: dec31) ?? dec31

        var columns: [[Date?]] = []
        while cursor <= endCursor {
            var col: [Date?] = []
            for _ in 0..<7 {
                let inYear = calendar.component(.year, from: cursor) == year
                col.append(inYear ? calendar.startOfDay(for: cursor) : nil)
                cursor = calendar.date(byAdding: .day, value: 1, to: cursor) ?? cursor
            }
            columns.append(col)
        }
        return columns
    }

    private func monthLabels(weeks: [[Date?]]) -> some View {
        HStack(alignment: .center, spacing: cellGap) {
            // Day-label gutter spacer to align with grid.
            Color.clear.frame(width: 22, height: 10)
            HStack(spacing: cellGap) {
                ForEach(Array(weeks.enumerated()), id: \.offset) { idx, col in
                    if let label = monthLabel(for: col, columnIndex: idx, weeks: weeks) {
                        Text(label)
                            .monoFont(9, weight: .bold)
                            .tracking(1.0)
                            .foregroundStyle(Palette.textMuted)
                            .frame(width: cellSize, alignment: .leading)
                    } else {
                        Color.clear.frame(width: cellSize, height: 10)
                    }
                }
            }
        }
    }

    private func monthLabel(for column: [Date?], columnIndex: Int, weeks: [[Date?]]) -> String? {
        guard let firstReal = column.compactMap({ $0 }).first else { return nil }
        let day = calendar.component(.day, from: firstReal)
        // Show the month label on the first column where its 1st day appears.
        guard day <= 7 else { return nil }
        // Avoid printing the same month twice in a row when columns straddle.
        if columnIndex > 0 {
            let prev = weeks[columnIndex - 1]
            if let prevReal = prev.compactMap({ $0 }).first,
               calendar.component(.month, from: prevReal) == calendar.component(.month, from: firstReal) {
                return nil
            }
        }
        let f = DateFormatter()
        f.dateFormat = "MMM"
        return f.string(from: firstReal).uppercased()
    }

    private var dayLabels: some View {
        VStack(alignment: .trailing, spacing: cellGap) {
            ForEach(0..<7, id: \.self) { row in
                Text(label(for: row))
                    .monoFont(8, weight: .bold)
                    .tracking(0.8)
                    .foregroundStyle(Palette.textMuted)
                    .frame(width: 22, height: cellSize, alignment: .trailing)
            }
        }
    }

    private func label(for row: Int) -> String {
        switch row {
        case 1: "Mon"
        case 3: "Wed"
        case 5: "Fri"
        default: ""
        }
    }

    private func weekColumnsView(cols: [[Date?]]) -> some View {
        HStack(alignment: .top, spacing: cellGap) {
            ForEach(Array(cols.enumerated()), id: \.offset) { _, col in
                VStack(spacing: cellGap) {
                    ForEach(0..<7, id: \.self) { row in
                        cell(for: col[row])
                    }
                }
            }
        }
    }

    private func cell(for day: Date?) -> some View {
        Group {
            if let day {
                let count = counts[day] ?? 0
                let bucket = HeatmapGrid.bucket(for: count)
                let isHovered = hovered == day
                Rectangle()
                    .fill(HeatmapGrid.colorForBucket(bucket))
                    .frame(width: cellSize, height: cellSize)
                    .overlay(
                        Rectangle()
                            .strokeBorder(isHovered ? Palette.neonOrange : Color.black.opacity(0.45), lineWidth: isHovered ? 1.5 : 0.5)
                    )
                    .shadow(color: isHovered ? Palette.neonOrange.opacity(0.6) : .clear, radius: isHovered ? 4 : 0)
                    .contentShape(Rectangle())
                    .onHover { hovering in
                        hovered = hovering ? day : (hovered == day ? nil : hovered)
                    }
                    .onTapGesture {
                        guard count > 0 else { return }
                        onTap(day)
                    }
                    .help(tooltip(day: day, count: count))
            } else {
                Color.clear.frame(width: cellSize, height: cellSize)
            }
        }
    }

    private func tooltip(day: Date, count: Int) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEE, MMM d, yyyy"
        return "\(f.string(from: day)) · \(count) capture\(count == 1 ? "" : "s")"
    }

    static func bucket(for count: Int) -> Int {
        switch count {
        case 0: 0
        case 1...2: 1
        case 3...5: 2
        case 6...9: 3
        default: 4
        }
    }

    static func colorForBucket(_ bucket: Int) -> Color {
        switch bucket {
        case 0: Palette.panelSlateHi
        case 1: Palette.neonCyan.opacity(0.30)
        case 2: Palette.neonCyan.opacity(0.55)
        case 3: Palette.neonMagenta.opacity(0.55)
        default: Palette.neonMagenta.opacity(0.90)
        }
    }
}
