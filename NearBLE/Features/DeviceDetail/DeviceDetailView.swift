import SwiftUI

struct DeviceDetailView: View {
    @EnvironmentObject private var bleScanner: BLEScannerService

    let deviceID: UUID
    let initialDevice: BLEDevice

    private var device: BLEDevice {
        bleScanner.device(with: deviceID) ?? initialDevice
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                summaryCard
                askAICard
                signalCard
                observedDataCard
                identifiersCard
            }
            .padding(20)
        }
        .navigationTitle(device.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemGroupedBackground))
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
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.cyan)
                    .frame(width: 42, height: 42)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.cyan.opacity(0.12))
                    )

                VStack(alignment: .leading, spacing: 6) {
                    Text("Ask AI")
                        .font(.headline)

                    Text("Get a quick explanation of what this BLE advertisement data might mean using Gemini.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            NavigationLink {
                AIChatView(device: device)
            } label: {
                Label("Ask AI", systemImage: "arrow.up.right.circle.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
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
