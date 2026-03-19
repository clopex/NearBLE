import Foundation

struct ScanSessionSummary: Equatable {
    let startedAt: Date
    let endedAt: Date
    let uniqueDeviceCount: Int
    let duration: TimeInterval
    let topDeviceNames: [String]
}
