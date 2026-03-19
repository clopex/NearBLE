import Foundation
import SwiftData

struct HistorySessionSnapshot: Identifiable, Hashable {
    let id: PersistentIdentifier
    let startedAt: Date
    let endedAt: Date
    let uniqueDeviceCount: Int
    let duration: TimeInterval
    let strongestSignal: Int?
    let devices: [HistorySavedDeviceSnapshot]

    init(session: ScanSessionRecord) {
        let sortedDevices = session.devices.sorted { lhs, rhs in
            if lhs.rssi == rhs.rssi {
                return lhs.discoveryOrder < rhs.discoveryOrder
            }

            return lhs.rssi > rhs.rssi
        }

        id = session.persistentModelID
        startedAt = session.startedAt
        endedAt = session.endedAt
        uniqueDeviceCount = session.uniqueDeviceCount
        duration = session.duration
        strongestSignal = sortedDevices.first?.rssi
        devices = sortedDevices.map { HistorySavedDeviceSnapshot(record: $0, seenAt: session.endedAt) }
    }

    var topDeviceNames: [String] {
        Array(devices.prefix(3).map(\.displayName))
    }
}

struct HistorySavedDeviceSnapshot: Identifiable, Hashable {
    let id: String
    let peripheralID: String
    let name: String
    let rssi: Int
    let manufacturerDataHex: String?
    let advertisedServices: [String]
    let isConnectable: Bool
    let discoveryOrder: Int
    let seenAt: Date

    init(record: ScanSessionDeviceRecord, seenAt: Date) {
        self.id = "\(record.peripheralID)-\(record.discoveryOrder)"
        self.peripheralID = record.peripheralID
        self.name = record.name
        self.rssi = record.rssi
        self.manufacturerDataHex = record.manufacturerDataHex
        self.advertisedServices = record.advertisedServicesCSV
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        self.isConnectable = record.isConnectable
        self.discoveryOrder = record.discoveryOrder
        self.seenAt = seenAt
    }

    var displayName: String {
        name.isEmpty ? "Unknown Device" : name
    }

    var subtitle: String {
        if let manufacturerDataHex, !manufacturerDataHex.isEmpty {
            return manufacturerDataHex
        }

        if !advertisedServices.isEmpty {
            return advertisedServices.joined(separator: ", ")
        }

        return peripheralID
    }

    var signalBars: Int {
        if rssi >= -55 {
            return 4
        }

        if rssi >= -67 {
            return 3
        }

        if rssi >= -80 {
            return 2
        }

        return 1
    }

    var bleDevice: BLEDevice {
        BLEDevice(
            id: UUID(uuidString: peripheralID) ?? UUID(),
            discoveryOrder: discoveryOrder,
            name: name.isEmpty ? nil : name,
            localName: nil,
            rssi: rssi,
            lastSeenAt: seenAt,
            manufacturerDataHex: manufacturerDataHex,
            advertisedServices: advertisedServices,
            isConnectable: isConnectable
        )
    }
}
