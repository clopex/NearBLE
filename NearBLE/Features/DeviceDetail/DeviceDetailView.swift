import SwiftUI

struct DeviceDetailView: View {
    @EnvironmentObject private var bleScanner: BLEScannerService
    @EnvironmentObject private var entitlementStore: AppEntitlementStore
    @EnvironmentObject private var favoritesStore: FavoritesStore

    let deviceID: UUID
    let initialDevice: BLEDevice

    @State private var isShowingAIChat = false
    @State private var isShowingPaywall = false

    private var device: BLEDevice {
        bleScanner.device(with: deviceID) ?? initialDevice
    }

    private var inspectionState: BLEInspectionState {
        bleScanner.inspectionState(for: deviceID)
    }

    private var isFavorite: Bool {
        favoritesStore.isFavorite(deviceID: deviceID)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                summaryCard
                askAICard
                inspectionCard
                signalCard
                observedDataCard
                identifiersCard
            }
            .padding(20)
        }
        .navigationTitle(device.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: toggleFavorite) {
                    Image(systemName: isFavorite ? "star.fill" : "star")
                        .font(.headline)
                        .foregroundStyle(isFavorite ? Color.yellow : Color.secondary)
                }
                .accessibilityLabel(isFavorite ? "Remove favorite" : "Add favorite")
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationDestination(isPresented: $isShowingAIChat) {
            AIChatView(device: device)
        }
        .fullScreenCover(isPresented: $isShowingPaywall) {
            NavigationStack {
                PaywallView(source: .aiLimit)
            }
        }
        .onAppear {
            if bleScanner.isScanning {
                bleScanner.stopScan()
            }
        }
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: device.isConnectable ? "dot.radiowaves.left.and.right" : "antenna.radiowaves.left.and.right.slash")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(device.isConnectable ? Color.accentColor : Color.secondary)
                    .frame(width: 48, height: 48)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.accentColor.opacity(device.isConnectable ? 0.12 : 0.08))
                    )

                VStack(alignment: .leading, spacing: 6) {
                    Text(device.displayName)
                        .font(.title3.weight(.semibold))

                    Text(device.localName ?? device.name ?? "No broadcast name")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 8) {
                        if isFavorite {
                            detailPill(title: "Favorite", tint: .yellow)
                        }

                        detailPill(
                            title: device.isConnectable ? "Connectable" : "Advertisement only",
                            tint: device.isConnectable ? .green : .secondary
                        )

                        detailPill(title: "\(device.rssi) dBm", tint: .cyan)
                    }
                }

                Spacer(minLength: 0)
            }

            Text(device.lastSeenLabel)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .background(cardBackground)
    }

    private var askAICard: some View {
        VStack(spacing: 18) {
            Button(action: openAIFlow) {
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.cyan, Color.accentColor],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 92, height: 92)
                            .shadow(color: Color.cyan.opacity(0.28), radius: 20, y: 10)

                        Circle()
                            .stroke(Color.white.opacity(0.28), lineWidth: 1)
                            .frame(width: 92, height: 92)

                        Image(systemName: "sparkles")
                            .font(.system(size: 34, weight: .bold))
                            .foregroundStyle(.white)

                        if !entitlementStore.isPro {
                            Image(systemName: "lock.fill")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white)
                                .padding(8)
                                .background(Circle().fill(Color.black.opacity(0.22)))
                                .offset(x: 28, y: 28)
                        }
                    }

                    VStack(spacing: 4) {
                        Text("Ask AI")
                            .font(.headline)
                            .foregroundStyle(.primary)

                        Text(entitlementStore.isPro ? "Explain this BLE device" : "Pro feature")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.cyan.opacity(0.1),
                            Color.accentColor.opacity(0.06)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.cyan.opacity(0.18), lineWidth: 1)
        )
    }

    private var inspectionCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Connect & Inspect")
                .font(.headline)

            Text(inspectionState.title)
                .font(.subheadline.weight(.semibold))

            Text(inspectionState.message)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Button("Connect & Inspect", action: connectAndInspect)
                    .buttonStyle(.borderedProminent)
                    .disabled(!device.isConnectable || !inspectionState.canStartInspection)

                Button("Disconnect", action: disconnectDevice)
                    .buttonStyle(.bordered)
                    .disabled(!inspectionState.canDisconnect)
            }

            if let snapshot = bleScanner.inspectionSnapshot(for: deviceID) {
                if snapshot.services.isEmpty {
                    Text("This peripheral did not expose any services.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(snapshot.services) { service in
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text(service.uuid)
                                    .font(.subheadline.monospaced())

                                Spacer(minLength: 12)

                                if service.isPrimary {
                                    detailPill(title: "Primary", tint: .green)
                                }
                            }

                            if service.characteristics.isEmpty {
                                Text("No characteristics exposed.")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            } else {
                                ForEach(service.characteristics) { characteristic in
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(characteristic.uuid)
                                            .font(.footnote.monospaced())
                                            .foregroundStyle(.primary)

                                        Text(characteristic.properties.joined(separator: " • "))
                                            .font(.footnote)
                                            .foregroundStyle(.secondary)
                                    }
                                    .padding(12)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .fill(Color(.tertiarySystemFill))
                                    )
                                }
                            }
                        }
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Color(.tertiarySystemBackground))
                        )
                    }
                }
            }
        }
        .padding(20)
        .background(cardBackground)
    }

    private var signalCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Signal")
                .font(.headline)

            HStack(alignment: .center, spacing: 16) {
                DetailSignalBarsView(level: device.signalBars)
                    .scaleEffect(1.3)
                    .frame(width: 42, height: 36)

                VStack(alignment: .leading, spacing: 4) {
                    Text("\(device.rssi) dBm")
                        .font(.title2.weight(.semibold))
                        .monospacedDigit()

                    Text(signalDescription(for: device.rssi))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)
            }
        }
        .padding(20)
        .background(cardBackground)
    }

    private var observedDataCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Observed Data")
                .font(.headline)

            detailRow(title: "Manufacturer Data", value: device.manufacturerDataHex ?? "Not available")

            VStack(alignment: .leading, spacing: 8) {
                Text("Advertised Services")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)

                if device.advertisedServices.isEmpty {
                    Text("No advertised services in the latest packet.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 10)], spacing: 10) {
                        ForEach(device.advertisedServices, id: \.self) { service in
                            Text(service)
                                .font(.footnote.monospaced())
                                .foregroundStyle(.primary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(Color(.tertiarySystemFill))
                                )
                        }
                    }
                }
            }
        }
        .padding(20)
        .background(cardBackground)
    }

    private var identifiersCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Identifiers")
                .font(.headline)

            detailRow(title: "Peripheral UUID", value: device.id.uuidString)
            detailRow(title: "Discovery State", value: device.isConnectable ? "Can attempt connection" : "Advertisement packet only")
        }
        .padding(20)
        .background(cardBackground)
    }

    private func detailRow(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)

            Text(value)
                .font(.body.monospaced())
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func detailPill(title: String, tint: Color) -> some View {
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

    private func connectAndInspect() {
        bleScanner.connectAndInspect(deviceID: deviceID)
    }

    private func disconnectDevice() {
        bleScanner.disconnect(deviceID: deviceID)
    }

    private func toggleFavorite() {
        favoritesStore.toggle(deviceID: deviceID)
    }

    private func openAIFlow() {
        if entitlementStore.isPro {
            isShowingAIChat = true
        } else {
            isShowingPaywall = true
        }
    }

    private func signalDescription(for rssi: Int) -> String {
        if rssi >= -55 {
            return "Strong nearby signal"
        }

        if rssi >= -67 {
            return "Good stable signal"
        }

        if rssi >= -80 {
            return "Medium range signal"
        }

        return "Weak or distant signal"
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(Color(.secondarySystemBackground))
    }
}

private struct DetailSignalBarsView: View {
    let level: Int

    var body: some View {
        HStack(alignment: .bottom, spacing: 4) {
            ForEach(0..<4, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(index < level ? Color.green : Color.secondary.opacity(0.25))
                    .frame(width: 6, height: CGFloat(12 + (index * 6)))
            }
        }
    }
}
