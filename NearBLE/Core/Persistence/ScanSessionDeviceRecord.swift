import Foundation
import SwiftData

@Model
final class ScanSessionDeviceRecord {
    var peripheralID: String
    var name: String
    var rssi: Int
    var manufacturerDataHex: String?
    var advertisedServicesCSV: String
    var isConnectable: Bool
    var discoveryOrder: Int

    init(
        peripheralID: String,
        name: String,
        rssi: Int,
        manufacturerDataHex: String?,
        advertisedServicesCSV: String,
        isConnectable: Bool,
        discoveryOrder: Int
    ) {
        self.peripheralID = peripheralID
        self.name = name
        self.rssi = rssi
        self.manufacturerDataHex = manufacturerDataHex
        self.advertisedServicesCSV = advertisedServicesCSV
        self.isConnectable = isConnectable
        self.discoveryOrder = discoveryOrder
    }
}
