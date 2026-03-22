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
    @Published private(set) var inspectionStates: [UUID: BLEInspectionState] = [:]
    @Published private(set) var inspectionSnapshots: [UUID: BLEInspectionSnapshot] = [:]
    @Published private(set) var isScanning = false

    private let historyStore: ScanHistoryStore?
    private var centralManager: CBCentralManager!
    private var cachedDevices: [UUID: BLEDevice] = [:]
    private var peripheralsByID: [UUID: CBPeripheral] = [:]
    private var inspectionBuilders: [UUID: InspectionBuilder] = [:]
    private var pendingPublishTask: Task<Void, Never>?
    private var shouldStartScanningWhenReady = false
    private var currentSessionStartedAt: Date?
    private var discoverySequence = 0

    init(historyStore: ScanHistoryStore? = nil) {
        self.historyStore = historyStore
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
        if resetResults, isScanning {
            finalizeCurrentSession()
        }

        if resetResults {
            pendingPublishTask?.cancel()
            pendingPublishTask = nil
            cachedDevices.removeAll()
            devices.removeAll()
            discoverySequence = 0
            currentSessionStartedAt = .now
        } else if currentSessionStartedAt == nil {
            currentSessionStartedAt = .now
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
        guard isScanning else { return }
        centralManager.stopScan()
        isScanning = false
        shouldStartScanningWhenReady = false
        finalizeCurrentSession()
    }

    func device(with id: UUID) -> BLEDevice? {
        cachedDevices[id]
    }

    func inspectionState(for id: UUID) -> BLEInspectionState {
        inspectionStates[id] ?? .idle
    }

    func inspectionSnapshot(for id: UUID) -> BLEInspectionSnapshot? {
        inspectionSnapshots[id]
    }

    func connectAndInspect(deviceID: UUID) {
        guard centralManager.state == .poweredOn else {
            inspectionStates[deviceID] = .failed("Bluetooth must be on before connecting to a device.")
            return
        }

        guard let peripheral = peripheralsByID[deviceID] else {
            inspectionStates[deviceID] = .failed("This device is no longer in memory. Scan again and retry.")
            return
        }

        inspectionStates[deviceID] = .connecting
        inspectionSnapshots[deviceID] = nil
        inspectionBuilders[deviceID] = InspectionBuilder()
        peripheral.delegate = self
        centralManager.connect(peripheral)
    }

    func disconnect(deviceID: UUID) {
        guard let peripheral = peripheralsByID[deviceID] else { return }
        centralManager.cancelPeripheralConnection(peripheral)
        inspectionStates[deviceID] = .idle
    }

    private func upsertDevice(
        peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi: NSNumber
    ) {
        let previousDevice = cachedDevices[peripheral.identifier]
        let localName = advertisementData[CBAdvertisementDataLocalNameKey] as? String
        let manufacturerData = advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data
        let serviceUUIDs = (advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID]) ?? []
        let isConnectable = advertisementData[CBAdvertisementDataIsConnectable] as? Bool ?? false
        let discoveryOrder = previousDevice?.discoveryOrder ?? nextDiscoveryOrder()
        let strongestRSSISeen = max(previousDevice?.strongestRSSISeen ?? previousDevice?.rssi ?? rssi.intValue, rssi.intValue)

        let device = BLEDevice(
            id: peripheral.identifier,
            discoveryOrder: discoveryOrder,
            name: peripheral.name,
            localName: localName,
            rssi: rssi.intValue,
            strongestRSSISeen: strongestRSSISeen,
            lastSeenAt: .now,
            manufacturerDataHex: manufacturerData?.hexString,
            advertisedServices: serviceUUIDs.map(\.uuidString),
            isConnectable: isConnectable
        )

        peripheralsByID[peripheral.identifier] = peripheral
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
            try? await Task.sleep(nanoseconds: 450_000_000)

            await MainActor.run {
                guard let self else { return }
                self.pendingPublishTask = nil
                self.devices = self.cachedDevices.values.sorted { lhs, rhs in
                    if lhs.stableSortRSSI == rhs.stableSortRSSI {
                        if lhs.discoveryOrder == rhs.discoveryOrder {
                            return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
                        }

                        return lhs.discoveryOrder < rhs.discoveryOrder
                    }

                    return lhs.stableSortRSSI > rhs.stableSortRSSI
                }
            }
        }
    }

    private func updateAvailability(for authorization: CBManagerAuthorization, state: CBManagerState) {
        if authorization == .denied || authorization == .restricted {
            if isScanning {
                stopScan()
            }
            availability = .unauthorized
            shouldStartScanningWhenReady = false
            return
        }

        switch state {
        case .poweredOn:
            availability = authorization == .notDetermined ? .permissionRequired : .ready
        case .poweredOff:
            if isScanning {
                stopScan()
            }
            availability = .bluetoothOff
        case .unsupported:
            if isScanning {
                stopScan()
            }
            availability = .unsupported
            shouldStartScanningWhenReady = false
        case .resetting:
            if isScanning {
                stopScan()
            }
            availability = .resetting
        case .unauthorized:
            if isScanning {
                stopScan()
            }
            availability = .unauthorized
            shouldStartScanningWhenReady = false
        case .unknown:
            availability = authorization == .notDetermined ? .permissionRequired : .unknown
        @unknown default:
            availability = .unknown
        }
    }

    private func finalizeCurrentSession() {
        guard let currentSessionStartedAt else { return }

        historyStore?.saveSession(
            startedAt: currentSessionStartedAt,
            endedAt: .now,
            devices: Array(cachedDevices.values)
        )

        self.currentSessionStartedAt = nil
    }

    private func inspectionFailureMessage(_ error: Error?, fallback: String) -> String {
        if let localizedError = error as? LocalizedError, let description = localizedError.errorDescription, !description.isEmpty {
            return description
        }

        if let error {
            return error.localizedDescription
        }

        return fallback
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

    nonisolated func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            peripheral.delegate = self
            self.inspectionStates[peripheral.identifier] = .discoveringServices
            self.inspectionBuilders[peripheral.identifier] = InspectionBuilder()
            peripheral.discoverServices(nil)
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: (any Error)?) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.inspectionStates[peripheral.identifier] = .failed(
                self.inspectionFailureMessage(error, fallback: "Unable to connect to this peripheral.")
            )
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: (any Error)?) {
        Task { @MainActor [weak self] in
            guard let self else { return }

            if let error {
                self.inspectionStates[peripheral.identifier] = .failed(
                    self.inspectionFailureMessage(error, fallback: "The peripheral disconnected unexpectedly.")
                )
            } else if self.inspectionState(for: peripheral.identifier) != .ready {
                self.inspectionStates[peripheral.identifier] = .idle
            }
        }
    }
}

extension BLEScannerService: CBPeripheralDelegate {
    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: (any Error)?) {
        Task { @MainActor [weak self] in
            guard let self else { return }

            if let error {
                self.inspectionStates[peripheral.identifier] = .failed(
                    self.inspectionFailureMessage(error, fallback: "Failed to discover services.")
                )
                return
            }

            let services = peripheral.services ?? []
            if services.isEmpty {
                self.inspectionSnapshots[peripheral.identifier] = BLEInspectionSnapshot(services: [])
                self.inspectionStates[peripheral.identifier] = .ready
                return
            }

            self.inspectionStates[peripheral.identifier] = .discoveringCharacteristics
            self.inspectionBuilders[peripheral.identifier] = InspectionBuilder(
                pendingServiceIDs: Set(services.map(\.uuid.uuidString)),
                services: [:]
            )

            for service in services {
                peripheral.discoverCharacteristics(nil, for: service)
            }
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: (any Error)?) {
        Task { @MainActor [weak self] in
            guard let self else { return }

            if let error {
                self.inspectionStates[peripheral.identifier] = .failed(
                    self.inspectionFailureMessage(error, fallback: "Failed to discover characteristics.")
                )
                return
            }

            let serviceUUID = service.uuid.uuidString
            let characteristics = (service.characteristics ?? []).map { characteristic in
                BLEInspectionSnapshot.Characteristic(
                    id: characteristic.uuid.uuidString,
                    uuid: characteristic.uuid.uuidString,
                    properties: characteristic.properties.displayNames
                )
            }

            var builder = self.inspectionBuilders[peripheral.identifier] ?? InspectionBuilder()
            builder.pendingServiceIDs.remove(serviceUUID)
            builder.services[serviceUUID] = BLEInspectionSnapshot.Service(
                id: serviceUUID,
                uuid: serviceUUID,
                isPrimary: service.isPrimary,
                characteristics: characteristics
            )
            self.inspectionBuilders[peripheral.identifier] = builder

            guard builder.pendingServiceIDs.isEmpty else { return }

            let snapshot = BLEInspectionSnapshot(
                services: builder.services.values.sorted { $0.uuid < $1.uuid }
            )
            self.inspectionSnapshots[peripheral.identifier] = snapshot
            self.inspectionStates[peripheral.identifier] = .ready
        }
    }
}

private extension BLEScannerService {
    struct InspectionBuilder {
        var pendingServiceIDs: Set<String> = []
        var services: [String: BLEInspectionSnapshot.Service] = [:]
    }
}

private extension Data {
    var hexString: String {
        map { String(format: "%02X", $0) }.joined(separator: " ")
    }
}

private extension CBCharacteristicProperties {
    var displayNames: [String] {
        var names: [String] = []

        if contains(.read) { names.append("Read") }
        if contains(.write) { names.append("Write") }
        if contains(.writeWithoutResponse) { names.append("Write No Response") }
        if contains(.notify) { names.append("Notify") }
        if contains(.indicate) { names.append("Indicate") }
        if contains(.broadcast) { names.append("Broadcast") }
        if contains(.authenticatedSignedWrites) { names.append("Signed Write") }
        if contains(.extendedProperties) { names.append("Extended") }

        return names.isEmpty ? ["No Flags"] : names
    }
}
