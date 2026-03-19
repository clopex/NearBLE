import SwiftUI

private struct AIChatMessage: Identifiable {
    enum Role {
        case user
        case model
    }

    let id = UUID()
    let role: Role
    let text: String
}

struct AIChatView: View {
    let device: BLEDevice

    private let bottomAnchorID = "chat-bottom-anchor"

    @State private var prompt = ""
    @State private var messages: [AIChatMessage] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @FocusState private var isPromptFocused: Bool

    private let aiService = GeminiAIService()

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        contextCard

                        if messages.isEmpty {
                            starterCard
                        } else {
                            ForEach(messages) { message in
                                messageBubble(message)
                            }
                        }

                        if isLoading {
                            typingIndicator
                        }

                        if let errorMessage {
                            errorCard(errorMessage)
                        }

                        Color.clear
                            .frame(height: 1)
                            .id(bottomAnchorID)
                    }
                    .padding(20)
                }
                .onChange(of: messages.count) { _, _ in
                    scrollToBottom(with: proxy)
                }
                .onChange(of: isLoading) { _, _ in
                    scrollToBottom(with: proxy)
                }
                .onChange(of: errorMessage) { _, _ in
                    scrollToBottom(with: proxy)
                }
                .onChange(of: isPromptFocused) { _, focused in
                    guard focused else { return }
                    scrollToBottom(with: proxy)
                }
            }

            composer
        }
        .navigationTitle("Ask AI")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .background(Color(.systemGroupedBackground))
    }

    private func scrollToBottom(with proxy: ScrollViewProxy) {
        DispatchQueue.main.async {
            withAnimation(.easeOut(duration: 0.22)) {
                proxy.scrollTo(bottomAnchorID, anchor: .bottom)
            }
        }
    }

    private var contextCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(device.displayName)
                .font(.headline)

            Text("Gemini gets the current BLE context for this device: RSSI, connectable state, manufacturer data and advertised services.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                aiPill("\(device.rssi) dBm", tint: .cyan)
                aiPill(device.isConnectable ? "Connectable" : "Ad only", tint: device.isConnectable ? .green : .secondary)
            }
        }
        .padding(18)
        .background(cardBackground)
    }

    private var starterCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Try asking")
                .font(.headline)

            Text("What kind of device is this?\nWhat does this manufacturer data suggest?\nIs this signal strong enough to be nearby?")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(18)
        .background(cardBackground)
    }

    private var composer: some View {
        VStack(spacing: 12) {
            Divider()

            HStack(alignment: .bottom, spacing: 12) {
                TextField("Ask about this BLE device…", text: $prompt, axis: .vertical)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color(.secondarySystemBackground))
                    )
                    .lineLimit(1...4)
                    .focused($isPromptFocused)

                Button {
                    Task {
                        await sendPrompt()
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading ? Color.secondary.opacity(0.2) : Color.accentColor)
                            .frame(width: 48, height: 48)

                        if isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "arrow.up")
                                .font(.headline.weight(.bold))
                                .foregroundStyle(.white)
                        }
                    }
                }
                .buttonStyle(.plain)
                .disabled(prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
        .background(.ultraThinMaterial)
    }

    private var typingIndicator: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text("AI")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                TypingIndicatorView()
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color(red: 0.82, green: 0.95, blue: 0.82))
                    )
            }

            Spacer(minLength: 40)
        }
    }

    @ViewBuilder
    private func messageBubble(_ message: AIChatMessage) -> some View {
        HStack {
            if message.role == .model {
                VStack(alignment: .leading, spacing: 6) {
                    Text("AI")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color(red: 0.14, green: 0.34, blue: 0.16))

                    Text(message.text)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .textSelection(.enabled)
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color(red: 0.82, green: 0.95, blue: 0.82))
                )

                Spacer(minLength: 40)
            } else {
                Spacer(minLength: 40)

                Text(message.text)
                    .font(.body)
                    .foregroundStyle(.white)
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.accentColor)
                    )
            }
        }
    }

    private func errorCard(_ message: String) -> some View {
        Text(message)
            .font(.footnote)
            .foregroundStyle(.red)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.red.opacity(0.08))
            )
    }

    private func aiPill(_ title: String, tint: Color) -> some View {
        Text(title)
            .font(.caption.weight(.medium))
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(tint.opacity(0.12))
            )
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(Color(.secondarySystemBackground))
    }

    @MainActor
    private func sendPrompt() async {
        let trimmedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPrompt.isEmpty, !isLoading else { return }

        errorMessage = nil
        isLoading = true
        isPromptFocused = false
        prompt = ""
        messages.append(AIChatMessage(role: .user, text: trimmedPrompt))

        do {
            let response = try await aiService.askAboutDevice(question: trimmedPrompt, device: device)
            messages.append(AIChatMessage(role: .model, text: response))
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }

        isLoading = false
    }
}

private struct TypingIndicatorView: View {
    @State private var animate = false

    var body: some View {
        HStack(alignment: .center, spacing: 6) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(Color(red: 0.18, green: 0.46, blue: 0.20).opacity(0.8))
                    .frame(width: 7, height: 7)
                    .scaleEffect(animate ? 1 : 0.72)
                    .opacity(animate ? 1 : 0.32)
                    .animation(
                        .easeInOut(duration: 0.55)
                            .repeatForever()
                            .delay(Double(index) * 0.18),
                        value: animate
                    )
            }
        }
        .frame(height: 20)
        .onAppear {
            animate = true
        }
    }
}
