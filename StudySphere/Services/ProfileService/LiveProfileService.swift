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
            return
        }
        sessionHistory = records.map { $0.toEntry() }
    }

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
