import Foundation

enum AppConfiguration {
    private static let bundledGeminiKey = "AIzaSyAtqAoJj8QzchgeVraeDKxsL5fLwHUFQSA"

    static var geminiAPIKey: String? {
        if let environmentKey = ProcessInfo.processInfo.environment["GEMINI_API_KEY"], !environmentKey.isEmpty {
            return environmentKey
        }

        if let infoKey = Bundle.main.object(forInfoDictionaryKey: "GEMINI_API_KEY") as? String {
            let trimmedInfoKey = infoKey.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedInfoKey.isEmpty {
                return trimmedInfoKey
            }
        }

        return bundledGeminiKey
    }
}
