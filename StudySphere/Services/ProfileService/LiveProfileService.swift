import Foundation
import MultipeerConnectivity
import SwiftData
import VISOR

@Observable
final class LiveProfileService: ProfileService {

    private enum DefaultsKeys {
      static let profile = "profile.userProfile.67"
      static let sessionHistory: String = "profile.sessionHistory.67"
    }

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - State

    private let modelContext: ModelContext
    var profile: UserProfile?
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
            let defaultAvatar = "person.circle.fill"

            let newPeerID = MCPeerID(displayName: defaultName)
            let peerIDData = (try? NSKeyedArchiver.archivedData(withRootObject: newPeerID, requiringSecureCoding: true)) ?? Data()

            let defaultProfile = UserProfile(
              id: UUID(),
              name: defaultName,
              avatarSystemName: defaultAvatar,
              peerIDData: peerIDData
            )

            profile = defaultProfile

            let encoder = JSONEncoder()
            if let encoded = try? encoder.encode(defaultProfile) {
              defaults.set(encoded, forKey: DefaultsKeys.profile)
            }
        }

        loadSessionHistoryFromSwiftData()

        // One-time migration: if SwiftData is empty but UserDefaults has legacy history, migrate then remove key
        if sessionHistory.isEmpty,
           let historyData = defaults.data(forKey: DefaultsKeys.sessionHistory),
           let decodedHistory = try? decoder.decode([SessionHistoryEntry].self, from: historyData),
           !decodedHistory.isEmpty {
            for entry in decodedHistory {
                let record = SessionHistoryEntryRecord(from: entry)
                modelContext.insert(record)
            }
            try? modelContext.save()
            defaults.removeObject(forKey: DefaultsKeys.sessionHistory)
            loadSessionHistoryFromSwiftData()
        }
    }

    private func loadSessionHistoryFromSwiftData() {
        let descriptor = FetchDescriptor<SessionHistoryEntryRecord>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        guard let records = try? modelContext.fetch(descriptor) else {
            sessionHistory = []
            return
        }
        sessionHistory = records.map { $0.toEntry() }
    }

    func saveProfile(name: String, avatarSystemName: String) {
        let defaults = UserDefaults.standard
        let encoder = JSONEncoder()

        if let existing = profile {
            let updated = UserProfile(
              id: existing.id,
              name: name,
              avatarSystemName: avatarSystemName,
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
              avatarSystemName: avatarSystemName,
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
        sessionHistory.append(entry)
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
