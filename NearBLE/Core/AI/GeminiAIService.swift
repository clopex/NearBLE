import Foundation

struct GeminiAIService {
    private let session: URLSession
    private let model = "gemini-2.5-flash"

    init(session: URLSession = .shared) {
        self.session = session
    }

    func askAboutDevice(question: String, device: BLEDevice) async throws -> String {
        guard let apiKey = AppConfiguration.geminiAPIKey else {
            throw GeminiAIError.missingAPIKey
        }

        let prompt = """
        You are helping inspect a Bluetooth Low Energy device inside an iOS app called NearBLE.

        Device context:
        - Name: \(device.displayName)
        - Local name: \(device.localName ?? "n/a")
        - Peripheral UUID: \(device.id.uuidString)
        - RSSI: \(device.rssi) dBm
        - Connectable: \(device.isConnectable ? "yes" : "no")
        - Manufacturer data: \(device.manufacturerDataHex ?? "n/a")
        - Advertised services: \(device.advertisedServices.isEmpty ? "none" : device.advertisedServices.joined(separator: ", "))

        User question:
        \(question)

        Answer briefly and practically. Explain what the observed BLE data suggests, what is uncertain, and what the user can inspect next if needed.
        """

        let body = GeminiGenerateRequest(
            contents: [
                GeminiContent(
                    role: "user",
                    parts: [GeminiPart(text: prompt)]
                )
            ]
        )

        var request = URLRequest(
            url: URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent")!
        )
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GeminiAIError.invalidResponse
        }

        guard 200..<300 ~= httpResponse.statusCode else {
            let apiError = try? JSONDecoder().decode(GeminiErrorEnvelope.self, from: data)
            throw GeminiAIError.requestFailed(apiError?.error.message ?? "Gemini returned status \(httpResponse.statusCode).")
        }

        let decoded = try JSONDecoder().decode(GeminiGenerateResponse.self, from: data)
        let text = decoded.candidates?
            .compactMap(\.content.parts)
            .flatMap { $0 }
            .compactMap(\.text)
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let text, !text.isEmpty else {
            throw GeminiAIError.emptyResponse
        }

        return text
    }
}

enum GeminiAIError: LocalizedError {
    case missingAPIKey
    case invalidResponse
    case requestFailed(String)
    case emptyResponse

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Gemini API key is missing."
        case .invalidResponse:
            return "Gemini returned an invalid response."
        case .requestFailed(let message):
            return message
        case .emptyResponse:
            return "Gemini returned an empty answer."
        }
    }
}

private struct GeminiGenerateRequest: Encodable {
    let contents: [GeminiContent]
}

private struct GeminiContent: Encodable {
    let role: String
    let parts: [GeminiPart]
}

private struct GeminiPart: Encodable {
    let text: String
}

private struct GeminiGenerateResponse: Decodable {
    let candidates: [GeminiCandidate]?
}

private struct GeminiCandidate: Decodable {
    let content: GeminiCandidateContent
}

private struct GeminiCandidateContent: Decodable {
    let parts: [GeminiCandidatePart]
}

private struct GeminiCandidatePart: Decodable {
    let text: String?
}

private struct GeminiErrorEnvelope: Decodable {
    let error: GeminiRemoteError
}

private struct GeminiRemoteError: Decodable {
    let message: String
}
