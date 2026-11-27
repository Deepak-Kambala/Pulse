import SwiftUI

struct InsightsView: View {
    @EnvironmentObject var monitor: SystemMonitor
    @State private var selectedCategory: InsightCategory? = nil

    private var visibleInsights: [InsightItem] {
        monitor.insights.filter { item in
            !item.isDismissed && (selectedCategory == nil || item.category == selectedCategory)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SectionHeader(
                    title: "Pulse Insights",
                    subtitle: "Deterministic local diagnostics derived from live system measurements"
                ) {
                    Picker("Category", selection: $selectedCategory) {
                        Text("All").tag(InsightCategory?.none)
                        ForEach(InsightCategory.allCases, id: \.self) { cat in
                            Text(cat.rawValue).tag(InsightCategory?.some(cat))
                        }
                    }
                    .frame(width: 150)
                }

                if visibleInsights.isEmpty {
                    PulseCard {
                        HStack(spacing: 12) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 24))
                                .foregroundStyle(PulseTheme.healthy)
                            VStack(alignment: .leading, spacing: 3) {
                                Text("System Operating Normally")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(PulseTheme.primaryText)
                                Text("No anomalies or threshold violations have been detected in the current monitoring window.")
                                    .font(.system(size: 12))
                                    .foregroundStyle(PulseTheme.secondaryText)
                            }
                        }
                    }
                } else {
                    ForEach(visibleInsights) { item in
                        PulseCard {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack(alignment: .top) {
                                    StatusPill(status: item.severity.status, customLabel: item.severity.rawValue)
                                    Text(item.category.rawValue)
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(PulseTheme.secondaryText)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(Capsule().fill(PulseTheme.secondaryCard))
                                    Spacer()
                                    Text(PulseFormat.timestampFormatter.string(from: item.detectedAt))
                                        .font(.system(size: 11))
                                        .foregroundStyle(PulseTheme.secondaryText)
                                }

                                Text(item.title)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(PulseTheme.primaryText)

                                Text(item.description)
                                    .font(.system(size: 12))
                                    .foregroundStyle(PulseTheme.secondaryText)

                                if !item.evidence.isEmpty {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Supporting Evidence")
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundStyle(PulseTheme.secondaryText)
                                        ForEach(item.evidence, id: \.self) { line in
                                            Text("• \(line)")
                                                .font(.system(size: 11, design: .monospaced))
                                                .foregroundStyle(PulseTheme.primaryText)
                                        }
                                    }
                                    .padding(10)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(RoundedRectangle(cornerRadius: 8).fill(PulseTheme.secondaryCard))
                                }

                                HStack {
                                    Label(item.suggestedAction, systemImage: "wrench.and.screwdriver")
                                        .font(.system(size: 11))
                                        .foregroundStyle(PulseTheme.accent)
                                    Spacer()
                                    if !item.isAcknowledged {
                                        Button("Acknowledge") {
                                            monitor.acknowledgeInsight(item.id)
                                        }
                                        .buttonStyle(.bordered)
                                    } else {
                                        Text("Acknowledged")
                                            .font(.system(size: 11))
                                            .foregroundStyle(PulseTheme.secondaryText)
                                    }
                                    Button("Dismiss") {
                                        monitor.dismissInsight(item.id)
                                    }
                                    .buttonStyle(.plain)
                                    .font(.system(size: 11))
                                    .foregroundStyle(PulseTheme.secondaryText)
                                }
                            }
                        }
                    }
                }
            }
            .padding(22)
        }
        .background(PulseTheme.background)
    }
}
