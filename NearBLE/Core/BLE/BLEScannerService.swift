import Combine
import CoreBluetooth
import Foundation

@MainActor
final class BLEScannerService: NSObject, ObservableObject {
    enum Availability: Equatable {
        case unknown
        case permissionRequired
        case ready
        case bluetoothOff
        case unauthorized
        case unsupported
        case resetting

        var title: String {
            switch self {
            case .unknown:
                return "Initializing Bluetooth"
            case .permissionRequired:
                return "Bluetooth Permission Needed"
            case .ready:
                return "Bluetooth Ready"
            case .bluetoothOff:
                return "Bluetooth Is Off"
            case .unauthorized:
                return "Bluetooth Access Needed"
            case .unsupported:
                return "Bluetooth Unsupported"
            case .resetting:
                return "Bluetooth Resetting"
            }
        }

        var message: String {
            switch self {
            case .unknown:
                return "NearBLE is waiting for CoreBluetooth to report the current state."
            case .permissionRequired:
                return "Tap the scanner button to request Bluetooth access and start discovering nearby devices."
            case .ready:
                return "Ready to scan for nearby BLE devices."
            case .bluetoothOff:
                return "Turn Bluetooth on in Control Center or Settings to start scanning."
            case .unauthorized:
                return "Allow Bluetooth access in Settings so the app can discover nearby devices."
            case .unsupported:
                return "This device does not support Bluetooth Low Energy scanning."
            case .resetting:
                return "Bluetooth is temporarily resetting. Scanning will resume when it is ready."
            }
        }
    }

    @Published private(set) var availability: Availability = .unknown
    @Published private(set) var devices: [BLEDevice] = []
    @Published private(set) var isScanning = false

    private var centralManager: CBCentralManager!
    private var cachedDevices: [UUID: BLEDevice] = [:]
    private var pendingPublishTask: Task<Void, Never>?
    private var shouldStartScanningWhenReady = false
    private var discoverySequence = 0

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
        updateAvailability(for: CBCentralManager.authorization, state: .unknown)
    }

    func toggleScan() {
        isScanning ? stopScan() : requestScan()
    }

    func refreshScan() {
        guard availability == .ready else { return }
        beginScan(resetResults: true)
    }

    var canToggleScan: Bool {
        switch availability {
        case .unauthorized, .unsupported, .resetting, .bluetoothOff:
            return false
        case .unknown, .permissionRequired, .ready:
            return true
        }
    }

    private func requestScan(resetResults: Bool = true) {
        shouldStartScanningWhenReady = true

        guard CBCentralManager.authorization != .denied, CBCentralManager.authorization != .restricted else {
            updateAvailability(for: CBCentralManager.authorization, state: centralManager.state)
            return
        }

        guard centralManager.state == .poweredOn else { return }
        beginScan(resetResults: resetResults)
    }

    private func beginScan(resetResults: Bool) {
        if resetResults {
            pendingPublishTask?.cancel()
            pendingPublishTask = nil
            cachedDevices.removeAll()
            devices.removeAll()
            discoverySequence = 0
        }

        centralManager.stopScan()
        centralManager.scanForPeripherals(
            withServices: nil,
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: true]
        )
        isScanning = true
        shouldStartScanningWhenReady = false
    }

    func stopScan() {
        centralManager.stopScan()
        isScanning = false
        shouldStartScanningWhenReady = false
    }

    func device(with id: UUID) -> BLEDevice? {
        cachedDevices[id]
    }

    private func upsertDevice(
        peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi: NSNumber
    ) {
        let localName = advertisementData[CBAdvertisementDataLocalNameKey] as? String
        let manufacturerData = advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data
        let serviceUUIDs = (advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID]) ?? []
        let isConnectable = advertisementData[CBAdvertisementDataIsConnectable] as? Bool ?? false
        let discoveryOrder = cachedDevices[peripheral.identifier]?.discoveryOrder ?? nextDiscoveryOrder()

        let device = BLEDevice(
            id: peripheral.identifier,
            discoveryOrder: discoveryOrder,
            name: peripheral.name,
            localName: localName,
            rssi: rssi.intValue,
            lastSeenAt: .now,
            manufacturerDataHex: manufacturerData?.hexString,
            advertisedServices: serviceUUIDs.map(\.uuidString),
            isConnectable: isConnectable
        )

        cachedDevices[peripheral.identifier] = device
        schedulePublish()
    }

    private func nextDiscoveryOrder() -> Int {
        let current = discoverySequence
        discoverySequence += 1
        return current
    }

    private func schedulePublish() {
        guard pendingPublishTask == nil else { return }

        pendingPublishTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 250_000_000)

            await MainActor.run {
                guard let self else { return }
                self.pendingPublishTask = nil
                self.devices = self.cachedDevices.values.sorted { lhs, rhs in
                    if lhs.discoveryOrder == rhs.discoveryOrder {
                        return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
                    }

                    return lhs.discoveryOrder < rhs.discoveryOrder
                }
            }
        }
    }

    private func updateAvailability(for authorization: CBManagerAuthorization, state: CBManagerState) {
        if authorization == .denied || authorization == .restricted {
            availability = .unauthorized
            isScanning = false
            shouldStartScanningWhenReady = false
            return
        }

        switch state {
        case .poweredOn:
            availability = authorization == .notDetermined ? .permissionRequired : .ready
        case .poweredOff:
            availability = .bluetoothOff
            isScanning = false
        case .unsupported:
            availability = .unsupported
            isScanning = false
            shouldStartScanningWhenReady = false
        case .resetting:
            availability = .resetting
            isScanning = false
        case .unauthorized:
            availability = .unauthorized
            isScanning = false
            shouldStartScanningWhenReady = false
        case .unknown:
            availability = authorization == .notDetermined ? .permissionRequired : .unknown
        @unknown default:
            availability = .unknown
        }
    }
}

extension BLEScannerService: CBCentralManagerDelegate {
    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.updateAvailability(for: CBCentralManager.authorization, state: central.state)

            if self.shouldStartScanningWhenReady, self.availability == .ready, central.state == .poweredOn {
                self.beginScan(resetResults: true)
            }
        }
    }

    nonisolated func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        guard RSSI.intValue != 127 else { return }

        Task { @MainActor [weak self] in
            self?.upsertDevice(peripheral: peripheral, advertisementData: advertisementData, rssi: RSSI)
        }
    }
}

private extension Data {
    var hexString: String {
        map { String(format: "%02X", $0) }.joined(separator: " ")
    }
}
