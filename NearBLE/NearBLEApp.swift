//
//  NearBLEApp.swift
//  NearBLE
//
//  Created by Adis Mulabdic on 17. 3. 2026..
//

import SwiftUI

@main
struct NearBLEApp: App {
    @StateObject private var bleScanner = BLEScannerService()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(bleScanner)
        }
    }
}
