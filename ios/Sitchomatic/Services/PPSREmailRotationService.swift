import Foundation

@MainActor
class PPSREmailRotationService {
    static let shared = PPSREmailRotationService()

    private let storageKey = "email_csv_list_v1"

    var emails: [String] = []

    init() {
        UserDefaults.standard.removeObject(forKey: storageKey)
    }

    func nextEmail() -> String? { nil }
    func importFromCSV(_ text: String) -> Int { 0 }
    func resetToDefault() {}
    func clear() {}
    var count: Int { 0 }
    var hasEmails: Bool { false }
}
