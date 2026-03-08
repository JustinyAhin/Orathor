import SwiftUI

enum TranscriptFilter: String, CaseIterable {
    case today = "Today"
    case thisWeek = "This Week"
    case thisMonth = "This Month"
    case allTime = "All Time"

    func matches(_ date: Date) -> Bool {
        let calendar = Calendar.current
        switch self {
        case .today:
            return calendar.isDateInToday(date)
        case .thisWeek:
            return calendar.isDate(date, equalTo: Date(), toGranularity: .weekOfYear)
        case .thisMonth:
            return calendar.isDate(date, equalTo: Date(), toGranularity: .month)
        case .allTime:
            return true
        }
    }
}

struct TranscriptsView: View {
    let historyService: TranscriptHistoryService
    @State private var playbackService = AudioPlaybackService()
    @State private var searchText = ""
    @State private var selectedFilter: TranscriptFilter = .allTime

    private var filteredEntries: [TranscriptEntry] {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        var results = historyService.entries.filter { selectedFilter.matches($0.timestamp) }
        if !query.isEmpty {
            results = results.filter { entry in
                entry.text.localizedCaseInsensitiveContains(query)
                || (entry.targetAppName?.localizedCaseInsensitiveContains(query) ?? false)
            }
        }
        return results
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
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Text("Transcripts")
                    .font(OType.largeTitle)
                    .foregroundStyle(Color.textPrimary)
                searchBar
                filterPills
            }
            .padding(.horizontal, Spacing.xxl)
            .padding(.top, Spacing.xxl)
            .padding(.bottom, Spacing.md)

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
                        HStack {
                            Text("\(filteredEntries.count) transcripts")
                                .font(OType.caption)
                                .foregroundStyle(Color.textTertiary)
                            Spacer()
                        }

                        ForEach(groupedByDate, id: \.date) { group in
                            Section {
                                LazyVStack(spacing: Spacing.xxxs) {
                                    ForEach(group.entries) { entry in
                                        TranscriptEntryRow(
                                            entry: entry,
                                            searchText: searchText,
                                            historyService: historyService,
                                            playbackService: playbackService
                                        )
                                    }
                                }
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
    }

    private var searchBar: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "magnifyingglass")
                .font(OType.caption)
                .foregroundStyle(Color.textTertiary)
            TextField("Search transcripts...", text: $searchText)
                .textFieldStyle(.plain)
                .font(OType.body)
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(OType.caption)
                        .foregroundStyle(Color.textTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.xs)
        .background(Color.surfaceSecondary, in: RoundedRectangle(cornerRadius: Radius.sm))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.sm)
                .stroke(Color.borderSubtle, lineWidth: 0.5)
        )
    }

    private var filterPills: some View {
        HStack(spacing: Spacing.xxs) {
            ForEach(TranscriptFilter.allCases, id: \.self) { filter in
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        selectedFilter = filter
                    }
                } label: {
                    Text(filter.rawValue)
                        .font(OType.captionMedium)
                        .foregroundStyle(
                            selectedFilter == filter
                                ? Color.textPrimary
                                : Color.textTertiary
                        )
                        .padding(.horizontal, Spacing.md)
                        .padding(.vertical, Spacing.xs)
                        .background(
                            selectedFilter == filter
                                ? Color.surfaceElevated
                                : Color.clear,
                            in: RoundedRectangle(cornerRadius: Radius.sm)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(Spacing.xxxs)
        .background(Color.surfaceSecondary, in: RoundedRectangle(cornerRadius: Radius.md))
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
