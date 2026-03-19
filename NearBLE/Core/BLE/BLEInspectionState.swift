import Foundation

enum BLEInspectionState: Equatable {
    case idle
    case connecting
    case discoveringServices
    case discoveringCharacteristics
    case ready
    case failed(String)

    var title: String {
        switch self {
        case .idle:
            return "Not inspected yet"
        case .connecting:
            return "Connecting"
        case .discoveringServices:
            return "Discovering services"
        case .discoveringCharacteristics:
            return "Discovering characteristics"
        case .ready:
            return "Inspection complete"
        case .failed:
            return "Inspection failed"
        }
    }

    var message: String {
        switch self {
        case .idle:
            return "Connect to the device to inspect its GATT services and characteristics."
        case .connecting:
            return "NearBLE is opening a BLE connection to this peripheral."
        case .discoveringServices:
            return "The device connected. Now discovering its available services."
        case .discoveringCharacteristics:
            return "Services were found. NearBLE is now reading characteristic metadata."
        case .ready:
            return "Services and characteristics are ready to inspect."
        case .failed(let reason):
            return reason
        }
    }

    var canStartInspection: Bool {
        switch self {
        case .idle, .failed:
            return true
        case .connecting, .discoveringServices, .discoveringCharacteristics, .ready:
            return false
        }
    }

    var canDisconnect: Bool {
        switch self {
        case .connecting, .discoveringServices, .discoveringCharacteristics, .ready:
            return true
        case .idle, .failed:
            return false
        }
    }
}
