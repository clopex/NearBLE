import Foundation

enum AppConfiguration {
    static var geminiAPIKey: String? {
        if let environmentKey = ProcessInfo.processInfo.environment["GEMINI_API_KEY"], !environmentKey.isEmpty {
            return environmentKey
        }

        if let secretsURL = Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
           let secretsData = try? Data(contentsOf: secretsURL),
           let plist = try? PropertyListSerialization.propertyList(from: secretsData, format: nil) as? [String: Any],
           let plistKey = plist["GEMINI_API_KEY"] as? String {
            let trimmedPlistKey = plistKey.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedPlistKey.isEmpty {
                return trimmedPlistKey
            }
        }

        if let infoKey = Bundle.main.object(forInfoDictionaryKey: "GEMINI_API_KEY") as? String {
            let trimmedInfoKey = infoKey.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedInfoKey.isEmpty {
                return trimmedInfoKey
            }
        }

        return nil
    }
}
