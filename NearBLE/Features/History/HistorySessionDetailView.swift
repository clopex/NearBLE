import SwiftUI

struct HistorySessionDetailView: View {
    @EnvironmentObject private var favoritesStore: FavoritesStore

    let session: HistorySessionSnapshot

    @State private var selectedDevice: HistorySavedDeviceSnapshot?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                summaryCard

                VStack(alignment: .leading, spacing: 14) {
                    Text("Captured Devices")
                        .font(.headline)

                    LazyVStack(spacing: 12) {
                        ForEach(session.devices) { device in
                            Button {
                                selectedDevice = device
                            } label: {
                                HistorySavedDeviceRow(
                                    device: device,
                                    isFavorite: favoritesStore.isFavorite(deviceID: device.bleDevice.id)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(20)
        }
        .navigationTitle("Session Detail")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemGroupedBackground))
        .navigationDestination(item: $selectedDevice) { device in
            DeviceDetailView(deviceID: device.bleDevice.id, initialDevice: device.bleDevice)
        }
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(session.startedAt, format: .dateTime.weekday(.wide).month().day().hour().minute())
                    .font(.title3.weight(.semibold))

                Text(timeRangeLabel)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                HistoryDetailMetricPill(
                    title: "\(session.uniqueDeviceCount) devices",
                    systemImage: "sensor.tag.radiowaves.forward",
                    tint: .cyan
                )

                HistoryDetailMetricPill(
                    title: durationLabel,
                    systemImage: "timer",
                    tint: .green
                )

                if let strongestSignal = session.strongestSignal {
                    HistoryDetailMetricPill(
                        title: "\(strongestSignal) dBm",
                        systemImage: "dot.radiowaves.left.and.right",
                        tint: .blue
                    )
                }
            }

            if !session.topDeviceNames.isEmpty {
                Text(session.topDeviceNames.joined(separator: " • "))
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(Color.primary.opacity(0.05), lineWidth: 1)
        )
    }

    private var timeRangeLabel: String {
        "\(session.startedAt.formatted(.dateTime.hour().minute())) - \(session.endedAt.formatted(.dateTime.hour().minute()))"
    }

    private var durationLabel: String {
        let totalSeconds = max(Int(session.duration.rounded()), 1)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60

        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        }

        return "\(seconds)s"
    }
}

private struct HistorySavedDeviceRow: View {
    let device: HistorySavedDeviceSnapshot
    let isFavorite: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: device.isConnectable ? "dot.radiowaves.left.and.right" : "antenna.radiowaves.left.and.right.slash")
                .font(.title3)
                .foregroundStyle(device.isConnectable ? Color.accentColor : Color.secondary)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(device.displayName)
                    .font(.headline)

                Text(device.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 16)

            VStack(alignment: .trailing, spacing: 6) {
                if isFavorite {
                    Image(systemName: "star.fill")
                        .font(.caption)
                        .foregroundStyle(.yellow)
                }

                HistoryDeviceSignalBars(level: device.signalBars)

                Text("\(device.rssi) dBm")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

private struct HistoryDetailMetricPill: View {
    let title: String
    let systemImage: String
    let tint: Color

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.caption.weight(.medium))
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                Capsule(style: .continuous)
                    .fill(tint.opacity(0.12))
            )
    }
}

private struct HistoryDeviceSignalBars: View {
    let level: Int

    var body: some View {
        HStack(alignment: .bottom, spacing: 3) {
            ForEach(0..<4, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(index < level ? Color.green : Color.secondary.opacity(0.25))
                    .frame(width: 4, height: CGFloat(8 + (index * 4)))
            }
        }
        .frame(height: 24)
    }
}
