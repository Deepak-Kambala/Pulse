import Foundation

struct HistoryRepository: Sendable {
    private let db: DatabaseManager

    init(db: DatabaseManager = .shared) {
        self.db = db
    }

    func loadSnapshots(for range: HistoryTimeRange) async -> [MetricSnapshot] {
        let since = Date().addingTimeInterval(-range.seconds)
        return (try? await db.fetchSnapshots(since: since)) ?? []
    }

    func recordSnapshot(_ snapshot: MetricSnapshot) async {
        try? await db.insertSnapshot(snapshot)
    }

    func prune(retentionDays: Int) async {
        try? await db.pruneOlderThan(days: max(1, retentionDays))
    }

    func clearAll() async {
        try? await db.clearAllHistory()
    }

    static func summarize(_ values: [(Date, Double)]) -> MetricSummaryStats? {
        guard !values.isEmpty else { return nil }
        var minVal = Double.greatestFiniteMagnitude
        var maxVal = -Double.greatestFiniteMagnitude
        var maxDate: Date?
        var sum = 0.0
        for (date, val) in values {
            if val < minVal { minVal = val }
            if val > maxVal {
                maxVal = val
                maxDate = date
            }
            sum += val
        }
        return MetricSummaryStats(
            minimum: minVal,
            average: sum / Double(values.count),
            peak: maxVal,
            peakTime: maxDate
        )
    }
}
