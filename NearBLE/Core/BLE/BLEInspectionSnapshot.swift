import Foundation

struct BLEInspectionSnapshot: Equatable {
    struct Service: Identifiable, Equatable {
        let id: String
        let uuid: String
        let isPrimary: Bool
        let characteristics: [Characteristic]
    }

    struct Characteristic: Identifiable, Equatable {
        let id: String
        let uuid: String
        let properties: [String]
    }

    let services: [Service]
}
