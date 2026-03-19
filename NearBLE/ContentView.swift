//
//  ContentView.swift
//  NearBLE
//
//  Created by Adis Mulabdic on 17. 3. 2026..
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            NavigationStack {
                ScannerView()
            }
            .tabItem {
                Label("Scanner", systemImage: "dot.radiowaves.left.and.right")
            }

            NavigationStack {
                HistoryView()
            }
            .tabItem {
                Label("History", systemImage: "clock.arrow.circlepath")
            }

            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape")
            }
        }
    }
}
