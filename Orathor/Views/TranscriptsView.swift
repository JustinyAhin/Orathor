import SwiftUI

struct TranscriptsView: View {
    let historyService: TranscriptHistoryService
    @State private var playbackService = AudioPlaybackService()
    @State private var searchText = ""

    private var filteredEntries: [TranscriptEntry] {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return historyService.entries }
        return historyService.entries.filter { entry in
            entry.text.localizedCaseInsensitiveContains(query)
            || (entry.targetAppName?.localizedCaseInsensitiveContains(query) ?? false)
        }
    }

    private var groupedByDate: [(date: String, entries: [TranscriptEntry])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: filteredEntries) { entry in
            calendar.startOfDay(for: entry.timestamp)
        }
        return grouped
            .sorted { $0.key > $1.key }
            .map { (date: formatDateHeader($0.key), entries: $0.value) }
    }

    var body: some View {
        Group {
            if historyService.entries.isEmpty {
                ContentUnavailableView(
                    "No transcripts yet",
                    systemImage: "text.quote",
                    description: Text("Start dictating to see your transcripts here.")
                )
            } else if filteredEntries.isEmpty {
                ContentUnavailableView.search(text: searchText)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: Spacing.xxl, pinnedViews: .sectionHeaders) {
                        Text("\(filteredEntries.count) transcripts")
                            .font(OType.caption)
                            .foregroundStyle(Color.textTertiary)

                        ForEach(groupedByDate, id: \.date) { group in
                            Section {
                                VStack(spacing: 0) {
                                    ForEach(Array(group.entries.enumerated()), id: \.element.id) { index, entry in
                                        if index > 0 {
                                            SubtleDivider(leadingInset: 56)
                                        }
                                        MainTranscriptRow(
                                            entry: entry,
                                            searchText: searchText,
                                            historyService: historyService,
                                            playbackService: playbackService
                                        )
                                    }
                                }
                                .cardStyle(padding: 0)
                            } header: {
                                Text(group.date)
                                    .sectionHeaderStyle()
                                    .padding(.vertical, Spacing.xxs)
                                    .padding(.horizontal, Spacing.xxs)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.surfacePrimary)
                            }
                        }
                    }
                    .padding(Spacing.xxl)
                }
            }
        }
        .navigationTitle("Transcripts")
        .searchable(text: $searchText, prompt: "Search transcripts...")
    }

    private func formatDateHeader(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            return date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
        }
    }
}
