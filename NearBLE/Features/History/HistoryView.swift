import SwiftUI
import SwiftData

struct HistoryView: View {
    @Query(sort: \ScanSessionRecord.startedAt, order: .reverse)
    private var sessions: [ScanSessionRecord]

    var body: some View {
        Group {
            if sessions.isEmpty {
                ContentUnavailableView {
                    Label("No History Yet", systemImage: "clock.arrow.circlepath")
                } description: {
                    Text("Completed scan sessions will appear here once you stop a scan with nearby devices detected.")
                }
            } else {
                List {
                    ForEach(groupedSessions) { section in
                        Section(section.title) {
                            ForEach(section.sessions) { session in
                                NavigationLink(value: session) {
                                    HistorySessionRow(session: session)
                                }
                                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                                    .listRowBackground(Color.clear)
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
        }
        .navigationTitle("History")
        .background(Color(.systemGroupedBackground))
        .navigationDestination(for: HistorySessionSnapshot.self) { session in
            HistorySessionDetailView(session: session)
        }
    }

    private var groupedSessions: [HistoryDaySection] {
        let snapshots = sessions.map(HistorySessionSnapshot.init)
        let grouped = Dictionary(grouping: snapshots) { session in
            Calendar.current.startOfDay(for: session.startedAt)
        }

        return grouped
            .map { date, sessions in
                HistoryDaySection(
                    date: date,
                    title: date.formatted(.dateTime.weekday(.wide).month().day()),
                    sessions: sessions.sorted { $0.startedAt > $1.startedAt }
                )
            }
            .sorted { $0.date > $1.date }
    }
}

private struct HistorySessionRow: View {
    let session: HistorySessionSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(session.startedAt, format: .dateTime.hour().minute())
                        .font(.headline)

                    Text(timeRangeLabel)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                SessionMetricPill(
                    title: "\(session.uniqueDeviceCount) devices",
                    systemImage: "sensor.tag.radiowaves.forward",
                    tint: .cyan
                )
            }

            if !topDeviceNames.isEmpty {
                Text(topDeviceNames.joined(separator: " • "))
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
            }

            HStack(spacing: 10) {
                SessionMetricPill(
                    title: durationLabel,
                    systemImage: "timer",
                    tint: .green
                )

                if let strongestSignal {
                    SessionMetricPill(
                        title: "\(strongestSignal) dBm",
                        systemImage: "dot.radiowaves.left.and.right",
                        tint: .blue
                    )
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.primary.opacity(0.05), lineWidth: 1)
        )
    }

    private var topDeviceNames: [String] {
        session.topDeviceNames
    }

    private var strongestSignal: Int? {
        session.strongestSignal
    }

    private var timeRangeLabel: String {
        let endedAt = session.endedAt.formatted(.dateTime.hour().minute())
        return "\(session.startedAt.formatted(.dateTime.hour().minute())) - \(endedAt)"
    }

    private var durationLabel: String {
        let totalSeconds = max(Int(session.duration.rounded()), 1)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60

        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        }

        return "\(seconds)s"
    }
}

private struct SessionMetricPill: View {
    let title: String
    let systemImage: String
    let tint: Color

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.caption.weight(.medium))
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                Capsule(style: .continuous)
                    .fill(tint.opacity(0.12))
            )
    }
}

private struct HistoryDaySection: Identifiable {
    let date: Date
    let title: String
    let sessions: [HistorySessionSnapshot]

    var id: Date { date }
}
