import Foundation
import SwiftData

@Model
final class SessionHistoryEntryRecord {
    var id: UUID
    var sessionName: String
    var date: Date
    var durationSeconds: TimeInterval
    var participantCount: Int
    var distractionCount: Int
    var focusScore: Double
    var participantAnalyticsData: Data?

    init(
        id: UUID,
        sessionName: String,
        date: Date,
        durationSeconds: TimeInterval,
        participantCount: Int,
        distractionCount: Int,
        focusScore: Double,
        participantAnalyticsData: Data? = nil
    ) {
        self.id = id
        self.sessionName = sessionName
        self.date = date
        self.durationSeconds = durationSeconds
        self.participantCount = participantCount
        self.distractionCount = distractionCount
        self.focusScore = focusScore
        self.participantAnalyticsData = participantAnalyticsData
    }
}

extension SessionHistoryEntryRecord {
    convenience init(from entry: SessionHistoryEntry) {
        let analyticsData = try? JSONEncoder().encode(entry.participantAnalytics)
        self.init(
            id: entry.id,
            sessionName: entry.sessionName,
            date: entry.date,
            durationSeconds: entry.durationSeconds,
            participantCount: entry.participantCount,
            distractionCount: entry.distractionCount,
            focusScore: entry.focusScore,
            participantAnalyticsData: analyticsData
        )
    }

    func toEntry() -> SessionHistoryEntry {
        let analytics: [ParticipantAnalytics]
        if let data = participantAnalyticsData,
           let decoded = try? JSONDecoder().decode([ParticipantAnalytics].self, from: data) {
            analytics = decoded
        } else {
            analytics = []
        }
        return SessionHistoryEntry(
            id: id,
            sessionName: sessionName,
            date: date,
            durationSeconds: durationSeconds,
            participantCount: participantCount,
            distractionCount: distractionCount,
            focusScore: focusScore,
            participantAnalytics: analytics
        )
    }
}

extension SessionHistoryEntry {
    init(record: SessionHistoryEntryRecord) {
        self = record.toEntry()
    }
}
