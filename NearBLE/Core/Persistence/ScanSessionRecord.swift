import Foundation
import SwiftData

@Model
final class ScanSessionRecord {
    var startedAt: Date
    var endedAt: Date
    var uniqueDeviceCount: Int
    var duration: TimeInterval
    @Relationship(deleteRule: .cascade) var devices: [ScanSessionDeviceRecord]

    init(
        startedAt: Date,
        endedAt: Date,
        uniqueDeviceCount: Int,
        duration: TimeInterval,
        devices: [ScanSessionDeviceRecord]
    ) {
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.uniqueDeviceCount = uniqueDeviceCount
        self.duration = duration
        self.devices = devices
    }
}
