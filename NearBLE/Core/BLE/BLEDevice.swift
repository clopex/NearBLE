import Foundation

struct BLEDevice: Identifiable, Hashable {
    let id: UUID
    let discoveryOrder: Int
    var name: String?
    var localName: String?
    var rssi: Int
    var strongestRSSISeen: Int? = nil
    var lastSeenAt: Date
    var manufacturerDataHex: String?
    var advertisedServices: [String]
    var isConnectable: Bool

    var normalizedDisplayName: String? {
        let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedName.isEmpty, trimmedName != "Unknown Device" else {
            return nil
        }

        return trimmedName.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }

    var stableSortRSSI: Int {
        max(rssi, strongestRSSISeen ?? rssi)
    }

    var displayName: String {
        if let name, !name.isEmpty {
            return name
        }

        if let localName, !localName.isEmpty {
            return localName
        }

        return "Unknown Device"
    }

    var subtitle: String {
        if let manufacturerDataHex, !manufacturerDataHex.isEmpty {
            return manufacturerDataHex
        }

        if !advertisedServices.isEmpty {
            return advertisedServices.joined(separator: ", ")
        }

        return id.uuidString
    }

    var lastSeenLabel: String {
        let age = Date.now.timeIntervalSince(lastSeenAt)

        if age < 5 {
            return "Seen just now"
        }

        if age < 30 {
            return "Seen moments ago"
        }

        if age < 60 {
            return "Seen under 1 min ago"
        }

        let minutes = Int(age / 60)
        return "Seen \(minutes)m ago"
    }

    var signalBars: Int {
        if stableSortRSSI >= -55 {
            return 4
        }

        if stableSortRSSI >= -67 {
            return 3
        }

        if stableSortRSSI >= -80 {
            return 2
        }

        return 1
    }

    func mergedForDisplay(with other: BLEDevice) -> BLEDevice {
        BLEDevice(
            id: stableSortRSSI >= other.stableSortRSSI ? id : other.id,
            discoveryOrder: min(discoveryOrder, other.discoveryOrder),
            name: preferredNonEmpty(name, other.name),
            localName: preferredNonEmpty(localName, other.localName),
            rssi: max(rssi, other.rssi),
            strongestRSSISeen: max(strongestRSSISeen ?? rssi, other.strongestRSSISeen ?? other.rssi),
            lastSeenAt: max(lastSeenAt, other.lastSeenAt),
            manufacturerDataHex: preferredNonEmpty(manufacturerDataHex, other.manufacturerDataHex),
            advertisedServices: Array(Set(advertisedServices + other.advertisedServices)).sorted(),
            isConnectable: isConnectable || other.isConnectable
        )
    }

    private func preferredNonEmpty(_ lhs: String?, _ rhs: String?) -> String? {
        if let lhs, !lhs.isEmpty {
            return lhs
        }

        if let rhs, !rhs.isEmpty {
            return rhs
        }

        return nil
    }
}
