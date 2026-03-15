import Foundation

enum AlertSound: String, Codable, CaseIterable, Sendable {
    case carAlarm = "car-alarm"
    case fah = "fah"
    case sixSeven = "six-seven"

    var displayName: String {
        switch self {
        case .carAlarm: "Car Alarm"
        case .fah: "Fah"
        case .sixSeven: "Six Seven"
        }
    }

    var url: URL? {
        Bundle.main.url(forResource: rawValue, withExtension: "wav")
    }
}
