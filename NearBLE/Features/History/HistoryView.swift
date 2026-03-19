import SwiftUI

struct HistoryView: View {
    var body: some View {
        List {
            ContentUnavailableView {
                Label("No History Yet", systemImage: "clock.arrow.circlepath")
            } description: {
                Text("Scan sessions and saved discoveries will appear here once persistence is added.")
            }
        }
        .navigationTitle("History")
        .listStyle(.insetGrouped)
    }
}
