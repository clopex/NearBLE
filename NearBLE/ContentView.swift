//
//  ContentView.swift
//  NearBLE
//
//  Created by Adis Mulabdic on 17. 3. 2026..
//

import SwiftUI

struct ContentView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isShowingSplash = true

    var body: some View {
        ZStack {
            mainTabs

            if isShowingSplash {
                SplashView()
                    .transition(reduceMotion ? .opacity : .asymmetric(
                        insertion: .opacity,
                        removal: .scale(scale: 1.03).combined(with: .opacity)
                    ))
                    .zIndex(1)
            }
        }
        .task {
            guard isShowingSplash else { return }

            try? await Task.sleep(for: .milliseconds(reduceMotion ? 350 : 900))

            withAnimation(reduceMotion ? .easeOut(duration: 0.18) : .easeInOut(duration: 0.35)) {
                isShowingSplash = false
            }
        }
    }

    private var mainTabs: some View {
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
