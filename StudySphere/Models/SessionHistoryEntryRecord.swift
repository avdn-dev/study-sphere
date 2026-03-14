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

    init(
        id: UUID,
        sessionName: String,
        date: Date,
        durationSeconds: TimeInterval,
        participantCount: Int,
        distractionCount: Int,
        focusScore: Double
    ) {
        self.id = id
        self.sessionName = sessionName
        self.date = date
        self.durationSeconds = durationSeconds
        self.participantCount = participantCount
        self.distractionCount = distractionCount
        self.focusScore = focusScore
    }
}

extension SessionHistoryEntryRecord {
    convenience init(from entry: SessionHistoryEntry) {
        self.init(
            id: entry.id,
            sessionName: entry.sessionName,
            date: entry.date,
            durationSeconds: entry.durationSeconds,
            participantCount: entry.participantCount,
            distractionCount: entry.distractionCount,
            focusScore: entry.focusScore
        )
    }

    func toEntry() -> SessionHistoryEntry {
        SessionHistoryEntry(
            id: id,
            sessionName: sessionName,
            date: date,
            durationSeconds: durationSeconds,
            participantCount: participantCount,
            distractionCount: distractionCount,
            focusScore: focusScore
        )
    }
}

extension SessionHistoryEntry {
    init(record: SessionHistoryEntryRecord) {
        self.init(
            id: record.id,
            sessionName: record.sessionName,
            date: record.date,
            durationSeconds: record.durationSeconds,
            participantCount: record.participantCount,
            distractionCount: record.distractionCount,
            focusScore: record.focusScore
        )
    }
}

