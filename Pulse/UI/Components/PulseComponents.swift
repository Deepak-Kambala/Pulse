import SwiftUI
import Charts

struct PulseBrandIcon: View {
    var size: CGFloat = 28
    var cornerRadius: CGFloat = 7

    var body: some View {
        Group {
            if let url = Bundle.main.url(forResource: "PulseLogo", withExtension: "png") ?? Bundle.moduleLogoURL,
               let nsImage = NSImage(contentsOf: url) {
                Image(nsImage: nsImage)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fill)
            } else {
                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: size * 0.52, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [PulseTheme.accent, PulseTheme.secondaryAccent],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .background(PulseTheme.secondaryCard)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

private extension Bundle {
    static var moduleLogoURL: URL? {
        #if SWIFT_PACKAGE
        return Bundle.module.url(forResource: "PulseLogo", withExtension: "png")
        #else
        return nil
        #endif
    }
}

struct PulseCard<Content: View>: View {
    let isInteractive: Bool
    var padding: CGFloat = 16
    @ViewBuilder let content: Content
    @State private var isHovered = false

    init(isInteractive: Bool = false, padding: CGFloat = 16, @ViewBuilder content: () -> Content) {
        self.isInteractive = isInteractive
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(PulseTheme.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(
                        isInteractive && isHovered ? PulseTheme.accent.opacity(0.4) : PulseTheme.hairline,
                        lineWidth: 1
                    )
            )
            .animation(.easeOut(duration: 0.14), value: isHovered)
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
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(customLabel ?? status.label)
                .font(.system(size: 11, weight: .medium))
                .lineLimit(1)
        }
        .fixedSize(horizontal: true, vertical: true)
        .foregroundStyle(color)
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(
            Capsule(style: .continuous)
                .fill(color.opacity(0.10))
        )
        .overlay(
            Capsule(style: .continuous)
                .strokeBorder(color.opacity(0.20), lineWidth: 0.5)
        )
    }
}

struct MetricStripItem: Identifiable {
    let id = UUID()
    let label: String
    let value: String
    var detail: String? = nil
    var status: HealthStatus? = nil
}

struct MetricStrip: View {
    let items: [MetricStripItem]

    var body: some View {
        PulseCard(padding: 0) {
            HStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    if index > 0 {
                        Rectangle()
                            .fill(PulseTheme.hairline)
                            .frame(width: 1)
                            .padding(.vertical, 14)
                    }
                    VStack(alignment: .leading, spacing: 5) {
                        Text(item.label.uppercased())
                            .font(.system(size: 10, weight: .semibold))
                            .tracking(0.5)
                            .foregroundStyle(PulseTheme.secondaryText)
                            .lineLimit(1)

                        HStack(spacing: 6) {
                            if let status = item.status {
                                Circle()
                                    .fill(PulseTheme.color(for: status))
                                    .frame(width: 7, height: 7)
                            }
                            Text(item.value)
                                .font(.system(size: 21, weight: .semibold, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(PulseTheme.primaryText)
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                        }

                        if let detail = item.detail {
                            Text(detail)
                                .font(.system(size: 11))
                                .foregroundStyle(PulseTheme.tertiaryText)
                                .lineLimit(1)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }
            }
        }
        .fixedSize(horizontal: false, vertical: true)
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
        PulseCard(padding: 14) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(title.uppercased())
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(0.5)
                        .foregroundStyle(PulseTheme.secondaryText)
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    if let status {
                        Circle()
                            .fill(PulseTheme.color(for: status))
                            .frame(width: 7, height: 7)
                    }
                }
                Text(value)
                    .font(.system(size: 21, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(PulseTheme.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(PulseTheme.tertiaryText)
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
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 20, weight: .semibold))
                    .tracking(-0.3)
                    .foregroundStyle(PulseTheme.primaryText)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(PulseTheme.secondaryText)
            }
            Spacer()
            trailing
        }
        .padding(.bottom, 2)
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
                .fill(PulseTheme.secondaryCard.opacity(0.6))
                .overlay(
                    Text("Sampling…")
                        .font(.system(size: 10))
                        .foregroundStyle(PulseTheme.tertiaryText)
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
                            colors: [color.opacity(0.18), color.opacity(0.0)],
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
                    .lineStyle(StrokeStyle(lineWidth: 1.6))
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
        .padding(.vertical, 3)
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
        VStack(alignment: .leading, spacing: 10) {
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
            .frame(height: 8)
            .padding(2)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(PulseTheme.secondaryCard)
            )

            HStack(spacing: 16) {
                ForEach(segments) { seg in
                    HStack(spacing: 6) {
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
        .fixedSize(horizontal: false, vertical: true)
    }
}
