import SwiftUI
import Charts

struct PulseCard<Content: View>: View {
    let isInteractive: Bool
    @ViewBuilder let content: Content
    @State private var isHovered = false

    init(isInteractive: Bool = false, @ViewBuilder content: () -> Content) {
        self.isInteractive = isInteractive
        self.content = content()
    }

    var body: some View {
        content
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(PulseTheme.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(
                        isInteractive && isHovered ? PulseTheme.accent.opacity(0.45) : PulseTheme.border,
                        lineWidth: 1
                    )
            )
            .animation(.easeOut(duration: 0.15), value: isHovered)
            .onHover { hovering in
                if isInteractive { isHovered = hovering }
            }
    }
}

struct StatusPill: View {
    let status: HealthStatus
    var customLabel: String? = nil

    var body: some View {
        let color = PulseTheme.color(for: status)
        HStack(spacing: 5) {
            Image(systemName: status.symbolName)
                .font(.system(size: 10, weight: .semibold))
            Text(customLabel ?? status.label)
                .font(.system(size: 11, weight: .medium))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(
            Capsule(style: .continuous)
                .fill(color.opacity(0.12))
        )
        .overlay(
            Capsule(style: .continuous)
                .strokeBorder(color.opacity(0.25), lineWidth: 0.5)
        )
    }
}

struct PulseStatTile: View {
    let title: String
    let value: String
    let subtitle: String?
    let status: HealthStatus?

    init(title: String, value: String, subtitle: String? = nil, status: HealthStatus? = nil) {
        self.title = title
        self.value = value
        self.subtitle = subtitle
        self.status = status
    }

    var body: some View {
        PulseCard {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(title)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(PulseTheme.secondaryText)
                    Spacer()
                    if let status {
                        StatusPill(status: status)
                    }
                }
                Text(value)
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(PulseTheme.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(PulseTheme.secondaryText)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct SectionHeader<Trailing: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let trailing: Trailing

    init(title: String, subtitle: String, @ViewBuilder trailing: () -> Trailing = { EmptyView() }) {
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing()
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(PulseTheme.primaryText)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(PulseTheme.secondaryText)
            }
            Spacer()
            trailing
        }
        .padding(.bottom, 4)
    }
}

struct SparklineChart: View {
    let points: [(Date, Double)]
    let color: Color
    let maxY: Double?

    init(points: [(Date, Double)], color: Color = PulseTheme.accent, maxY: Double? = 100) {
        self.points = points
        self.color = color
        self.maxY = maxY
    }

    var body: some View {
        if points.count < 2 {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(PulseTheme.secondaryCard)
                .overlay(
                    Text("Collecting samples…")
                        .font(.system(size: 10))
                        .foregroundStyle(PulseTheme.secondaryText)
                )
        } else {
            Chart {
                ForEach(Array(points.enumerated()), id: \.offset) { idx, pt in
                    AreaMark(
                        x: .value("Sample", idx),
                        y: .value("Value", pt.1)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [color.opacity(0.24), color.opacity(0.0)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)

                    LineMark(
                        x: .value("Sample", idx),
                        y: .value("Value", pt.1)
                    )
                    .foregroundStyle(color)
                    .lineStyle(StrokeStyle(lineWidth: 1.75))
                    .interpolationMethod(.catmullRom)
                }
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .chartYScale(domain: 0...(maxY ?? max(1, (points.map(\.1).max() ?? 1) * 1.15)))
        }
    }
}

struct KeyValueRow: View {
    let key: String
    let value: String
    var valueColor: Color = PulseTheme.primaryText

    var body: some View {
        HStack {
            Text(key)
                .font(.system(size: 12))
                .foregroundStyle(PulseTheme.secondaryText)
            Spacer()
            Text(value)
                .font(.system(size: 12, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(valueColor)
                .lineLimit(1)
        }
        .padding(.vertical, 2)
    }
}

struct SegmentedBarSegment: Identifiable {
    let id = UUID()
    let label: String
    let value: Double
    let color: Color
}

struct SegmentedBar: View {
    let segments: [SegmentedBarSegment]
    let total: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            GeometryReader { geo in
                HStack(spacing: 2) {
                    ForEach(segments) { seg in
                        let ratio = total > 0 ? max(0, seg.value / total) : 0
                        if ratio > 0.005 {
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .fill(seg.color)
                                .frame(width: max(4, geo.size.width * ratio - 2))
                        }
                    }
                    Spacer(minLength: 0)
                }
            }
            .frame(height: 10)
            .padding(2)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(PulseTheme.secondaryCard)
            )

            FlowLayoutLegend(segments: segments)
        }
    }
}

private struct FlowLayoutLegend: View {
    let segments: [SegmentedBarSegment]

    var body: some View {
        HStack(spacing: 14) {
            ForEach(segments) { seg in
                HStack(spacing: 5) {
                    Circle()
                        .fill(seg.color)
                        .frame(width: 7, height: 7)
                    Text(seg.label)
                        .font(.system(size: 11))
                        .foregroundStyle(PulseTheme.secondaryText)
                }
            }
        }
    }
}
