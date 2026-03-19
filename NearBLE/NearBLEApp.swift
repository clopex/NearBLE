//
//  NearBLEApp.swift
//  NearBLE
//
//  Created by Adis Mulabdic on 17. 3. 2026..
//

import SwiftUI
import SwiftData

@main
struct NearBLEApp: App {
    private let modelContainer: ModelContainer
    @StateObject private var bleScanner: BLEScannerService
    @StateObject private var scanHistoryStore: ScanHistoryStore
    @StateObject private var favoritesStore: FavoritesStore
    @StateObject private var entitlementStore: AppEntitlementStore

    init() {
        do {
            modelContainer = try ModelContainer(
                for: ScanSessionRecord.self,
                ScanSessionDeviceRecord.self
            )
        } catch {
            fatalError("Failed to create model container: \(error)")
        }

        let historyStore = ScanHistoryStore(modelContext: modelContainer.mainContext)
        _scanHistoryStore = StateObject(wrappedValue: historyStore)
        _bleScanner = StateObject(wrappedValue: BLEScannerService(historyStore: historyStore))
        _favoritesStore = StateObject(wrappedValue: FavoritesStore())
        _entitlementStore = StateObject(wrappedValue: AppEntitlementStore())
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(bleScanner)
                .environmentObject(scanHistoryStore)
                .environmentObject(favoritesStore)
                .environmentObject(entitlementStore)
        }
        .modelContainer(modelContainer)
    }
}
