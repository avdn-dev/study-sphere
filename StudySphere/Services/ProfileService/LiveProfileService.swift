import Foundation
import MultipeerConnectivity
import SwiftData
import UIKit
import VISOR

@Observable
final class LiveProfileService: ProfileService {

    private enum DefaultsKeys {
      static let profile = "profile.userProfile.67"
    }

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - State

    private let modelContext: ModelContext
    var profile: UserProfile?
    var profileImage: UIImage? {
        guard let data = profile?.avatarImageData else { return nil }
        return UIImage(data: data)
    }
    var displayName: String { profile?.name ?? "Student" }
    var peerID: MCPeerID? { profile?.peerID }
    var sessionHistory: [SessionHistoryEntry] = []

    // MARK: - Profile

    func load() {
        let defaults = UserDefaults.standard
        let decoder = JSONDecoder()

        if let profileData = defaults.data(forKey: DefaultsKeys.profile),
           let decodedProfile = try? decoder.decode(UserProfile.self, from: profileData) {
            profile = decodedProfile
        } else {
            let defaultName = "Student"

            let newPeerID = MCPeerID(displayName: defaultName)
            let peerIDData = (try? NSKeyedArchiver.archivedData(withRootObject: newPeerID, requiringSecureCoding: true)) ?? Data()

            let defaultProfile = UserProfile(
              id: UUID(),
              name: defaultName,
              avatarImageData: nil,
              peerIDData: peerIDData
            )

            profile = defaultProfile

            let encoder = JSONEncoder()
            if let encoded = try? encoder.encode(defaultProfile) {
              defaults.set(encoded, forKey: DefaultsKeys.profile)
            }
        }

        loadSessionHistoryFromSwiftData()
    }

    private func loadSessionHistoryFromSwiftData() {
        let descriptor = FetchDescriptor<SessionHistoryEntryRecord>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        guard let records = try? modelContext.fetch(descriptor) else {
            sessionHistory = []
            #if DEBUG
            seedMockSessionHistory()
            #endif
            return
        }
        sessionHistory = records.map { $0.toEntry() }

        #if DEBUG
        if sessionHistory.isEmpty {
            seedMockSessionHistory()
        }
        #endif
    }

    #if DEBUG
    private func seedMockSessionHistory() {
        let peers = [
            ParticipantAnalytics(id: UUID(), name: "Alex Rivera", focusScore: 0.92, focusDurationSeconds: 4320, distractionCount: 1),
            ParticipantAnalytics(id: UUID(), name: "Jordan Smyth", focusScore: 0.87, focusDurationSeconds: 3960, distractionCount: 3),
            ParticipantAnalytics(id: UUID(), name: "Maya Chen", focusScore: 0.64, focusDurationSeconds: 2880, distractionCount: 6),
        ]

        let entries: [SessionHistoryEntry] = [
//            SessionHistoryEntry(
//                id: UUID(),
//                sessionName: "Morning Deep Work",
//                date: Date().addingTimeInterval(-3600),
//                durationSeconds: 15720,
//                participantCount: 4,
//                distractionCount: 10,
//                focusScore: 0.984,
//                participantAnalytics: peers
//            ),
//            SessionHistoryEntry(
//                id: UUID(),
//                sessionName: "Afternoon Sprint",
//                date: Date().addingTimeInterval(-86400),
//                durationSeconds: 5400,
//                participantCount: 3,
//                distractionCount: 5,
//                focusScore: 0.88,
//                participantAnalytics: [
//                    ParticipantAnalytics(id: UUID(), name: "Alex Rivera", focusScore: 0.95, focusDurationSeconds: 5100, distractionCount: 1),
//                    ParticipantAnalytics(id: UUID(), name: "Maya Chen", focusScore: 0.78, focusDurationSeconds: 4200, distractionCount: 4),
//                ]
//            ),
//            SessionHistoryEntry(
//                id: UUID(),
//                sessionName: "Evening Review",
//                date: Date().addingTimeInterval(-172800),
//                durationSeconds: 3600,
//                participantCount: 2,
//                distractionCount: 3,
//                focusScore: 0.82,
//                participantAnalytics: [
//                    ParticipantAnalytics(id: UUID(), name: "Jordan Smyth", focusScore: 0.90, focusDurationSeconds: 3240, distractionCount: 1),
//                    ParticipantAnalytics(id: UUID(), name: "Maya Chen", focusScore: 0.72, focusDurationSeconds: 2520, distractionCount: 2),
//                ]
//            ),
        ]

        for entry in entries {
            addHistoryEntry(entry)
        }
    }
    #endif

    func saveProfile(name: String, avatarImageData: Data?) {
        let defaults = UserDefaults.standard
        let encoder = JSONEncoder()

        if let existing = profile {
            let updated = UserProfile(
              id: existing.id,
              name: name,
              avatarImageData: avatarImageData,
              peerIDData: existing.peerIDData
            )
            profile = updated

            if let encoded = try? encoder.encode(updated) {
              defaults.set(encoded, forKey: DefaultsKeys.profile)
            }
        } else {
            let peerID = MCPeerID(displayName: name)
            let peerIDData = (try? NSKeyedArchiver.archivedData(withRootObject: peerID, requiringSecureCoding: true)) ?? Data()

            let newProfile = UserProfile(
              id: UUID(),
              name: name,
              avatarImageData: avatarImageData,
              peerIDData: peerIDData
            )
            profile = newProfile

            if let encoded = try? encoder.encode(newProfile) {
              defaults.set(encoded, forKey: DefaultsKeys.profile)
            }
        }
    }

    // MARK: - History

    func addHistoryEntry(_ entry: SessionHistoryEntry) {
        let record = SessionHistoryEntryRecord(from: entry)
        modelContext.insert(record)
        try? modelContext.save()
        sessionHistory.insert(entry, at: 0)
    }

    func clearHistory() {
        let descriptor = FetchDescriptor<SessionHistoryEntryRecord>()
        guard let records = try? modelContext.fetch(descriptor) else { return }
        for record in records {
            modelContext.delete(record)
        }
        try? modelContext.save()
        sessionHistory = []
    }
}
