import Combine
import Foundation
import SwiftData

@MainActor
final class ScanHistoryStore: ObservableObject {
    @Published private(set) var latestSessionSummary: ScanSessionSummary?

    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        refreshLatestSessionSummary()
    }

    func saveSession(startedAt: Date, endedAt: Date, devices: [BLEDevice]) {
        guard !devices.isEmpty else { return }

        let sortedDevices = devices.sorted { lhs, rhs in
            if lhs.rssi == rhs.rssi {
                return lhs.discoveryOrder < rhs.discoveryOrder
            }

            return lhs.rssi > rhs.rssi
        }

        let session = ScanSessionRecord(
            startedAt: startedAt,
            endedAt: endedAt,
            uniqueDeviceCount: sortedDevices.count,
            duration: endedAt.timeIntervalSince(startedAt),
            devices: sortedDevices.map { device in
                ScanSessionDeviceRecord(
                    peripheralID: device.id.uuidString,
                    name: device.displayName,
                    rssi: device.rssi,
                    manufacturerDataHex: device.manufacturerDataHex,
                    advertisedServicesCSV: device.advertisedServices.joined(separator: ", "),
                    isConnectable: device.isConnectable,
                    discoveryOrder: device.discoveryOrder
                )
            }
        )

        modelContext.insert(session)

        do {
            try modelContext.save()
        } catch {
            assertionFailure("Failed to save scan session: \(error)")
        }

        latestSessionSummary = summary(for: session)
    }

    func refreshLatestSessionSummary() {
        var descriptor = FetchDescriptor<ScanSessionRecord>(
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1

        do {
            latestSessionSummary = try modelContext.fetch(descriptor).first.map(summary(for:))
        } catch {
            latestSessionSummary = nil
        }
    }

    private func summary(for session: ScanSessionRecord) -> ScanSessionSummary {
        let topDeviceNames = session.devices
            .sorted { lhs, rhs in
                if lhs.rssi == rhs.rssi {
                    return lhs.discoveryOrder < rhs.discoveryOrder
                }

                return lhs.rssi > rhs.rssi
            }
            .prefix(3)
            .map(\.name)

        return ScanSessionSummary(
            startedAt: session.startedAt,
            endedAt: session.endedAt,
            uniqueDeviceCount: session.uniqueDeviceCount,
            duration: session.duration,
            topDeviceNames: Array(topDeviceNames)
        )
    }
}
