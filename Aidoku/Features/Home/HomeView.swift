//
//  HomeView.swift
//  Aidoku
//
//  Created by Antigravity on 10/9/26.
//

import AidokuRunner
import LocalAuthentication
import SwiftUI
import SwiftUIIntrospect

struct HomeView: View {
    // MARK: - Reading Insights State
    @State private var insightsData: InsightsData = .init()
    @State private var statsGridHeight: CGFloat = 240
    @State private var shouldAnimateGridHeightChange = false

    // MARK: - History State
    @StateObject private var historyViewModel = HistoryView.ViewModel()
    @State private var searchText = ""
    @State private var entryToDelete: HistoryEntry?
    @State private var showClearHistoryConfirm = false
    @State private var showDeleteConfirm = false

    @State private var triggerLoadMoreVisibleCheck = false
    @State private var loadTask: Task<(), Never>?
    @State private var locked = UserDefaults.standard.bool(forKey: "History.lockHistoryTab")
    @State private var listSelection: String?
    @State private var openingLastRead = false

    @EnvironmentObject private var path: NavigationCoordinator

    var body: some View {
        Group {
            if locked {
                lockedView
            } else {
                contentList
            }
        }
        .customSearchable(
            text: $searchText,
            stacked: false,
            onSubmit: {
                Task {
                    await historyViewModel.search(query: searchText, delay: false)
                }
            },
            onCancel: {
                Task {
                    await historyViewModel.search(query: searchText, delay: false)
                }
            }
        )
        .environment(\.autocorrectionDisabled, true)
        .onChange(of: searchText) { newValue in
            Task {
                await historyViewModel.search(query: newValue, delay: true)
            }
        }
        .animation(.default, value: historyViewModel.filteredHistory)
        .navigationTitle(NSLocalizedString("HOME"))
        .navigationBarTitleDisplayMode(.automatic)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if UserDefaults.standard.bool(forKey: "History.lockHistoryTab") {
                    Button {
                        if locked {
                            Task {
                                await unlock()
                            }
                        } else {
                            locked = true
                        }
                    } label: {
                        Image(systemName: locked ? "lock" : "lock.open")
                    }
                }
                Button {
                    showClearHistoryConfirm = true
                } label: {
                    Image(systemName: "trash")
                }
            }
        }
        .confirmationDialogOrAlert(
            NSLocalizedString("CLEAR_READ_HISTORY"),
            isPresented: $showClearHistoryConfirm,
            titleVisibility: .visible
        ) {
            Button(NSLocalizedString("CLEAR"), role: .destructive) {
                historyViewModel.clearHistory()
                Task {
                    await reloadInsights()
                }
            }
        } message: {
            Text(NSLocalizedString("CLEAR_READ_HISTORY_TEXT"))
        }
        .confirmationDialogOrAlert(
            NSLocalizedString("CLEAR_READ_HISTORY"),
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button(NSLocalizedString("REMOVE"), role: .destructive) {
                if let entryToDelete {
                    Task {
                        await historyViewModel.removeHistory(entry: entryToDelete)
                        await reloadInsights()
                    }
                }
            }
            Button(NSLocalizedString("REMOVE_ALL_MANGA_HISTORY"), role: .destructive) {
                if let entryToDelete {
                    Task {
                        await historyViewModel.removeHistory(entry: entryToDelete, all: true)
                        await reloadInsights()
                    }
                }
            }
        } message: {
            Text(NSLocalizedString("CLEAR_READ_HISTORY_TEXT"))
        }
        .onReceive(NotificationCenter.default.publisher(for: .historyLockTabSetting)) { _ in
            locked = UserDefaults.standard.bool(forKey: "History.lockHistoryTab")
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
            locked = UserDefaults.standard.bool(forKey: "History.lockHistoryTab")
        }
        .onReceive(NotificationCenter.default.publisher(for: .historyTabReselected)) { _ in
            Task {
                await continueReading()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .historyAdded)) { _ in
            Task {
                await reloadInsights()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .historyRemoved)) { _ in
            Task {
                await reloadInsights()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .updateHistory)) { _ in
            Task {
                await reloadInsights()
            }
        }
        .task {
            await reloadInsights()
        }
        .refreshable {
            await reloadInsights()
            await historyViewModel.search(query: searchText, delay: false)
        }
    }

    // MARK: - Main Content List
    @ViewBuilder
    private var contentList: some View {
        List(selection: $listSelection) {
            // MARK: Top Section: Reading Analysis (Insights)
            if searchText.isEmpty {
                Section {
                    readingAnalyticsContent
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 12, trailing: 16))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                } header: {
                    Text(NSLocalizedString("INSIGHTS"))
                        .font(.system(size: 15).weight(.semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.none)
                        .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 4, trailing: 20))
                }
            }

            // MARK: Bottom Section: Reading History
            Section {
                // Section header for History
            } header: {
                Text(NSLocalizedString("HISTORY"))
                    .font(.system(size: 15).weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.none)
                    .listRowInsets(EdgeInsets(top: 14, leading: 20, bottom: 4, trailing: 20))
            }

            if historyViewModel.filteredHistory.isEmpty && historyViewModel.loadingState == .complete {
                emptyHistoryView
            } else {
                let sections = historyViewModel.filteredHistory.values.sorted { $0.daysAgo < $1.daysAgo }
                ForEach(sections, id: \.daysAgo) { section in
                    if !section.entries.isEmpty {
                        Section {
                            ForEach(section.entries, id: \.chapterId) { entry in
                                cellView(entry: entry)
                            }
                        } header: {
                            headerView(daysAgo: section.daysAgo)
                        }
                    }
                }

                loadMoreView
            }
        }
        .listStyle(.grouped)
        .environment(\.defaultMinListRowHeight, 1)
        .environment(\.defaultMinListHeaderHeight, 1)
        .listSectionSpacingPlease(10)
        .scrollBackgroundHiddenPlease()
        .scrollDismissesKeyboardImmediately()
        .background(Color(uiColor: .systemGroupedBackground))
    }

    // MARK: - Reading Analytics Card Block
    @ViewBuilder
    private var readingAnalyticsContent: some View {
        VStack(spacing: 14) {
            // Streaks
            HStack(spacing: 8) {
                InsightPlatterView {
                    Group {
                        if insightsData.currentStreak > 1 {
                            VStack(spacing: 0) {
                                Text(NSLocalizedString("CURRENT_STREAK"))
                                    .font(.system(size: 14))
                                VStack(spacing: -5) {
                                    Text(insightsData.currentStreak, format: .number.notation(.compactName))
                                        .font(.system(size: 38).weight(.bold))
                                    Text(NSLocalizedString("DAYS"))
                                        .font(.body.weight(.semibold))
                                        .multilineTextAlignment(.center)
                                }
                            }
                        } else {
                            VStack(spacing: 4) {
                                Text(NSLocalizedString("NO_CURRENT_STREAK"))
                                    .font(.headline)
                                Text(NSLocalizedString("NO_CURRENT_STREAK_TEXT"))
                                    .font(.subheadline)
                                    .multilineTextAlignment(.center)
                            }
                        }
                    }
                    .padding(12)
                    .frame(height: 110)
                    .frame(maxWidth: .infinity)
                }

                if insightsData.longestStreak > insightsData.currentStreak && insightsData.longestStreak > 1 {
                    InsightPlatterView {
                        VStack(spacing: 0) {
                            Text(NSLocalizedString("LONGEST_STREAK"))
                                .font(.system(size: 14))
                            VStack(spacing: -5) {
                                Text(insightsData.longestStreak, format: .number.notation(.compactName))
                                    .font(.system(size: 38).weight(.bold))
                                Text(NSLocalizedString("DAYS"))
                                    .font(.body.weight(.semibold))
                                    .multilineTextAlignment(.center)
                            }
                        }
                        .padding(12)
                        .frame(height: 110)
                        .frame(maxWidth: .infinity)
                    }
                }
            }

            // Heatmap
            InsightPlatterView {
                HStack(spacing: 0) {
                    LinearGradient(
                        gradient: Gradient(
                            colors: [
                                Color(UIColor.secondarySystemGroupedBackground),
                                Color(UIColor.secondarySystemGroupedBackground).opacity(0)
                            ]
                        ),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .flipsForRightToLeftLayoutDirection(true)
                    .frame(width: 12)
                    .zIndex(1)

                    HeatmapView(data: insightsData.heatmapData)
                        .padding(.vertical, 12)
                        .zIndex(0)

                    LinearGradient(
                        gradient: Gradient(
                            colors: [
                                Color(UIColor.secondarySystemGroupedBackground).opacity(0),
                                Color(UIColor.secondarySystemGroupedBackground)
                            ]
                        ),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .flipsForRightToLeftLayoutDirection(true)
                    .frame(width: 12)
                    .zIndex(1)
                }
            }

            // Stats Grid (Chapters / Pages / Series / Hours)
            StatsGridView(
                chartLabel: NSLocalizedString("CHAPTER_PLURAL"),
                chartSingularLabel: NSLocalizedString("CHAPTER_SINGULAR"),
                chartData: insightsData.chartData,
                items: insightsData.statsData,
                height: $statsGridHeight
            )
            .frame(height: statsGridHeight)
        }
        .animation(shouldAnimateGridHeightChange ? .default : nil, value: statsGridHeight)
        .onChangeWrapper(of: statsGridHeight) { oldValue, _ in
            if oldValue != 0 {
                shouldAnimateGridHeightChange = true
            }
        }
    }

    private func reloadInsights() async {
        insightsData = await InsightsData.get()
    }

    // MARK: - History Views
    private var emptyHistoryView: some View {
        InsightPlatterView {
            VStack(spacing: 8) {
                Image(systemName: "book.closed")
                    .font(.system(size: 28))
                    .foregroundStyle(.secondary)
                Text(NSLocalizedString("NO_HISTORY"))
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(NSLocalizedString("NO_HISTORY_TEXT"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.vertical, 24)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity)
        }
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }

    private var lockedView: some View {
        VStack(spacing: 12) {
            Image(systemName: "lock.fill")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)

            Text(NSLocalizedString("HISTORY_LOCKED"))
                .fontWeight(.medium)

            Button(NSLocalizedString("VIEW_HISTORY")) {
                Task {
                    await unlock()
                }
            }
        }
        .padding(.top, -52)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .systemGroupedBackground))
    }

    private func headerView(daysAgo: Int) -> some View {
        Text(Date.makeRelativeDate(days: daysAgo))
            .font(.body.weight(.medium))
            .foregroundStyle(.primary)
            .foregroundColor(.primary)
            .textCase(.none)
            .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20))
    }

    private func cellView(entry: HistoryEntry) -> some View {
        let source = historyViewModel.sourceCache[entry.chapterId.sourceKey]
        let manga = historyViewModel.mangaCache[entry.chapterId.mangaIdentifier]
        return HomeHistoryEntryCell(
            entry: entry,
            source: source,
            manga: manga,
            chapter: historyViewModel.chapterCache[entry.chapterId]
        ) {
            if let manga {
                path.push(MangaViewController(manga: manga, parent: path.rootViewController))
            }
        }
        .equatable()
        .contentShape(Rectangle())
        .listRowSeparator(.hidden, edges: .top)
        .listRowSeparator(.visible, edges: .bottom)
        .introspect(.listCell, on: .iOS(.v16, .v17, .v18, .v26, .v27)) { entity in
            guard let cell = entity as? UICollectionViewListCell, cell.tag != 1 else { return }
            cell.backgroundConfiguration = UIBackgroundConfiguration.listPlainCell()
            cell.tag = 1
        }
        .swipeActions(edge: .trailing) {
            Button {
                entryToDelete = entry
                showDeleteConfirm = true
            } label: {
                Label(NSLocalizedString("DELETE"), systemImage: "trash")
            }
            .tint(.red)
        }
        .id(entry.chapterId)
        .tag(entry.chapterId)
        .offsetListSeparator()
    }

    @ViewBuilder
    private var loadMoreView: some View {
        VStack {
            if historyViewModel.loadingState != .complete {
                ProgressView()
                    .progressViewStyle(.circular)
                    .onReportScrollVisibilityChange(trigger: $triggerLoadMoreVisibleCheck) { visible in
                        Task {
                            await loadTask?.value
                            if visible {
                                tryLoadingMore()
                            }
                        }
                    }
                    .onChange(of: historyViewModel.filteredHistory) { _ in
                        Task {
                            try? await Task.sleep(nanoseconds: 10_000_000)
                            triggerLoadMoreVisibleCheck = true
                        }
                    }
                    .onAppear {
                        tryLoadingMore()
                    }
            }
        }
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .listRowInsets(.zero)
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private func tryLoadingMore() {
        loadTask = Task {
            if historyViewModel.loadingState == .idle {
                await historyViewModel.loadMore()
            }
        }
    }

    private func continueReading() async {
        guard !locked, !openingLastRead else { return }
        openingLastRead = true
        defer { openingLastRead = false }

        let mangaId = await CoreDataManager.shared.container.performBackgroundTask { context in
            CoreDataManager.shared.getRecentHistory(limit: 1, offset: 0, context: context)
                .first
                .map { $0.identifier.mangaIdentifier }
        }
        guard let mangaId else { return }

        var manga = historyViewModel.mangaCache[mangaId]
        if manga == nil {
            manga = await CoreDataManager.shared.container.performBackgroundTask { context in
                CoreDataManager.shared.getManga(
                    mangaId: mangaId,
                    context: context
                )?.toNewManga()
            }
        }

        let (chapters, nextChapter) = await MangaManager.shared.getNextChapter(
            mangaId: mangaId,
            fallbackChapters: manga?.chapters,
            fetchIfNeeded: true
        )

        var targetManga = manga ?? AidokuRunner.Manga(sourceKey: mangaId.sourceKey, key: mangaId.mangaKey, title: "")
        if !chapters.isEmpty {
            targetManga.chapters = chapters
        }

        guard
            let rootViewController = path.rootViewController,
            rootViewController.view.window != nil,
            rootViewController.navigationController?.topViewController === rootViewController
        else { return }

        guard
            let chapter = nextChapter,
            let source = SourceManager.shared.store.source(for: mangaId.sourceKey)
        else {
            guard
                SourceManager.shared.store.isInstalled(sourceKey: mangaId.sourceKey) || !targetManga.title.isEmpty
            else {
                return
            }
            path.push(MangaViewController(manga: targetManga, parent: rootViewController))
            return
        }

        let readerController = ReaderViewController(
            source: source,
            manga: targetManga,
            chapter: chapter
        )
        let navigationController = ReaderNavigationController(readerViewController: readerController)
        navigationController.modalPresentationStyle = .fullScreen
        path.present(navigationController)
    }

    private func unlock() async {
        let context = LAContext()
        let success: Bool

        do {
            success = try await context.evaluatePolicy(
                .defaultPolicy,
                localizedReason: NSLocalizedString("AUTH_FOR_HISTORY")
            )
        } catch {
            return
        }

        guard success else { return }
        locked = false
    }
}

// MARK: - History Entry Cell for Home
private struct HomeHistoryEntryCell: View, @MainActor Equatable {
    let entry: HistoryEntry
    let source: AidokuRunner.Source?
    let manga: AidokuRunner.Manga?
    let chapter: AidokuRunner.Chapter?
    var onPressed: (() -> Void)?

    private static let coverImageWidth: CGFloat = 56

    var body: some View {
        Button {
            onPressed?()
        } label: {
            HStack(spacing: 12) {
                MangaCoverView(
                    source: source,
                    coverImage: manga?.cover ?? "",
                    width: Self.coverImageWidth,
                    height: Self.coverImageWidth * 3/2,
                    downsampleWidth: Self.coverImageWidth
                )
                VStack(alignment: .leading, spacing: 4) {
                    Text(manga?.title ?? "")
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .foregroundStyle(.primary)
                    Text(makeSubtitle())
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                        .lineLimit(1)
                    if let additionalEntryCount = entry.additionalEntryCount, additionalEntryCount > 0 {
                        let text = Text(String(format: NSLocalizedString("%lld_PLUS_MORE"), additionalEntryCount))
                            .foregroundStyle(.secondary)
                            .font(.footnote)
                            .lineLimit(1)
                        if #available(iOS 16.0, *) {
                            text.contentTransition(.numericText())
                        } else {
                            text
                        }
                    }
                }
                Spacer()
            }
        }
        .tint(.primary)
    }

    func makeSubtitle() -> String {
        var components: [String] = []
        if let volumeNum = chapter?.volumeNumber, volumeNum >= 0 {
            if let chapterNum = chapter?.chapterNumber, chapterNum >= 0 {
                components.append([
                    String(format: NSLocalizedString("VOL_X"), volumeNum),
                    String(format: NSLocalizedString("CH_X"), chapterNum)
                ].joined(separator: " "))
            } else {
                components.append(String(format: NSLocalizedString("VOL_SPACE_X"), volumeNum))
            }
        } else if let chapterNum = chapter?.chapterNumber, chapterNum >= 0 {
            components.append(String(format: NSLocalizedString("CH_SPACE_X"), chapterNum))
        } else if let title = chapter?.title, chapter?.chapterNumber == nil && chapter?.volumeNumber == nil {
            components.append(title)
        }
        if let currentPage = entry.currentPage, let totalPages = entry.totalPages, currentPage > 0, currentPage < totalPages {
            components.append(String(format: NSLocalizedString("PAGE_X_OF_X"), currentPage, totalPages))
        }
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        components.append(formatter.string(from: entry.date))
        return components.joined(separator: " - ")
    }

    static func == (lhs: HomeHistoryEntryCell, rhs: HomeHistoryEntryCell) -> Bool {
        lhs.entry == rhs.entry && lhs.manga == rhs.manga && lhs.chapter == rhs.chapter
    }
}
