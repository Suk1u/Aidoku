//
//  TxtReaderView.swift
//  Aidoku
//
//  Created by Antigravity on 10/9/26.
//

import SwiftUI

struct TxtReaderView: View {
    let chapters: [TxtChapter]
    @State var currentChapterIndex: Int = 0

    // MARK: - Reading Mode & Typography Settings
    @AppStorage("Reader.ebookReadingMode") private var readingModeRaw = EbookReadingMode.paged.rawValue
    @AppStorage("Reader.ebookFontSize") private var fontSize: Double = 18.0
    @AppStorage("Reader.ebookLineSpacing") private var lineSpacing: Double = 7.0
    @AppStorage(ReaderTextTheme.userDefaultsKey) private var textThemeRaw = ReaderTextTheme.default.rawValue
    @AppStorage("Reader.ebookBookmarks") private var bookmarksData: Data = Data()

    // MARK: - Page & Navigation State
    @State private var currentPageIndex: Int = 0
    @State private var pages: [String] = []
    @State private var showTocSheet = false
    @State private var showSettingsSheet = false
    @State private var showSearchSheet = false
    @State private var showControls = false
    @State private var searchText = ""

    private var readingMode: EbookReadingMode {
        get { EbookReadingMode(rawValue: readingModeRaw) ?? .paged }
        set { readingModeRaw = newValue.rawValue }
    }

    private var theme: ReaderTextTheme {
        ReaderTextTheme(rawValue: textThemeRaw) ?? .default
    }

    private var currentChapter: TxtChapter? {
        guard currentChapterIndex >= 0 && currentChapterIndex < chapters.count else { return nil }
        return chapters[currentChapterIndex]
    }

    private var remainingPagesInChapter: Int {
        max(0, pages.count - (currentPageIndex + 1))
    }

    private var bookmarks: [EbookBookmark] {
        get {
            (try? JSONDecoder().decode([EbookBookmark].self, from: bookmarksData)) ?? []
        }
        set {
            bookmarksData = (try? JSONEncoder().encode(newValue)) ?? Data()
        }
    }

    private var isCurrentPageBookmarked: Bool {
        bookmarks.contains {
            $0.chapterIndex == currentChapterIndex && $0.pageIndex == currentPageIndex
        }
    }

    var body: some View {
        ZStack {
            Color(theme.backgroundColor)
                .ignoresSafeArea()

            if chapters.isEmpty {
                emptyView
            } else {
                VStack(spacing: 0) {
                    // 顶部胶囊：本章还剩 X 页
                    if readingMode == .paged {
                        AppleBooksTopPill(remainingPages: remainingPagesInChapter)
                            .padding(.top, 10)
                            .opacity(showControls ? 0.4 : 0.85)
                    }

                    // 正文阅读区域
                    Group {
                        if readingMode == .paged {
                            pagedContentView
                        } else {
                            scrollContentView
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 0)
                            .onEnded { value in
                                handleTap(at: value.location)
                            }
                    )

                    // 底部胶囊：当前/总页数
                    if readingMode == .paged {
                        AppleBooksBottomPill(currentPage: currentPageIndex + 1, totalPages: pages.count)
                            .padding(.bottom, 12)
                            .opacity(showControls ? 0.4 : 0.85)
                    }
                }

                // 悬浮交互浮层 (Apple Books Quick Menu & Bottom Bar)
                if showControls {
                    controlsOverlay
                }
            }
        }
        .sheet(isPresented: $showTocSheet) {
            let chapterItems = chapters.map {
                (id: $0.id, title: $0.title, page: max(1, $0.id * 5 + 1))
            }
            AppleBooksTocSheet(
                bookTitle: currentChapter?.title ?? "正文",
                currentChapterIndex: currentChapterIndex,
                currentPageIndex: currentPageIndex,
                totalPages: pages.count,
                chapters: chapterItems,
                bookmarks: bookmarks,
                onSelectChapter: { newIndex in
                    currentChapterIndex = newIndex
                    currentPageIndex = 0
                    recalculatePages()
                },
                onSelectBookmark: { bookmark in
                    currentChapterIndex = bookmark.chapterIndex
                    currentPageIndex = bookmark.pageIndex
                    recalculatePages()
                },
                onDeleteBookmark: { bookmark in
                    var currentList = bookmarks
                    currentList.removeAll { $0.id == bookmark.id }
                    bookmarks = currentList
                }
            )
        }
        .sheet(isPresented: $showSettingsSheet) {
            AppleBooksThemeSettingsSheet(
                fontSize: $fontSize,
                textThemeRaw: $textThemeRaw,
                readingMode: Binding(
                    get: { readingMode },
                    set: { readingModeRaw = $0.rawValue }
                )
            )
        }
        .onAppear {
            recalculatePages()
        }
        .onChange(of: currentChapterIndex) { _ in
            currentPageIndex = 0
            recalculatePages()
        }
        .onChange(of: fontSize) { _ in
            recalculatePages()
        }
    }

    // MARK: - Paged View (左右翻页模式)
    private var pagedContentView: some View {
        GeometryReader { _ in
            if !pages.isEmpty && currentPageIndex < pages.count {
                Text(pages[currentPageIndex])
                    .font(.system(size: fontSize))
                    .lineSpacing(lineSpacing)
                    .foregroundStyle(Color(theme.textColor))
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(.horizontal, 26)
                    .padding(.vertical, 8)
            }
        }
    }

    // MARK: - Scroll View (连续垂直滚动模式)
    private var scrollContentView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if let chapter = currentChapter {
                    Text(chapter.title)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(Color(theme.textColor))
                        .padding(.bottom, 8)

                    Text(chapter.content)
                        .font(.system(size: fontSize))
                        .lineSpacing(lineSpacing)
                        .foregroundStyle(Color(theme.textColor))
                        .multilineTextAlignment(.leading)
                }

                HStack {
                    if currentChapterIndex > 0 {
                        Button("上一章") {
                            currentChapterIndex -= 1
                        }
                        .buttonStyle(.bordered)
                    }

                    Spacer()

                    if currentChapterIndex < chapters.count - 1 {
                        Button("下一章") {
                            currentChapterIndex += 1
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding(.top, 24)
                .padding(.bottom, 60)
            }
            .padding(.horizontal, 26)
            .padding(.vertical, 16)
        }
    }

    // MARK: - Apple Books Controls Overlay
    private var controlsOverlay: some View {
        VStack {
            Spacer()

            // 右下角悬浮快捷菜单 (目录 / 搜索 / 主题与设置)
            HStack {
                Spacer()
                AppleBooksQuickMenu(
                    onOpenToc: {
                        showTocSheet = true
                    },
                    onOpenSearch: {
                        showTocSheet = true
                    },
                    onOpenSettings: {
                        showSettingsSheet = true
                    }
                )
            }
            .padding(.trailing, 20)
            .padding(.bottom, 12)

            // 底部悬浮操作胶囊 (分享 / 模式 / 书签)
            AppleBooksBottomBar(
                isBookmarked: Binding(
                    get: { isCurrentPageBookmarked },
                    set: { _ in toggleBookmark() }
                ),
                readingMode: Binding(
                    get: { readingMode },
                    set: { readingModeRaw = $0.rawValue }
                ),
                onShare: {
                    shareCurrentChapter()
                },
                onToggleBookmark: {
                    toggleBookmark()
                }
            )
            .padding(.bottom, 24)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.96)))
    }

    private var emptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("无文本内容")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Helpers & Actions
    private func recalculatePages() {
        guard let content = currentChapter?.content else {
            pages = []
            return
        }
        let baseChars = 750
        let factor = max(0.5, 18.0 / fontSize)
        let charsPerPage = Int(Double(baseChars) * factor)
        pages = TxtParser.paginate(content: content, charsPerPage: charsPerPage)
        if currentPageIndex >= pages.count {
            currentPageIndex = max(0, pages.count - 1)
        }
    }

    private func handleTap(at location: CGPoint) {
        let screenWidth = UIScreen.main.bounds.width
        let tapMargin = screenWidth * 0.3

        if location.x < tapMargin {
            if readingMode == .paged {
                turnPage(forward: false)
            } else {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    showControls.toggle()
                }
            }
        } else if location.x > screenWidth - tapMargin {
            if readingMode == .paged {
                turnPage(forward: true)
            } else {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    showControls.toggle()
                }
            }
        } else {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                showControls.toggle()
            }
        }
    }

    private func turnPage(forward: Bool) {
        if forward {
            if currentPageIndex < pages.count - 1 {
                currentPageIndex += 1
            } else if currentChapterIndex < chapters.count - 1 {
                currentChapterIndex += 1
                currentPageIndex = 0
            }
        } else {
            if currentPageIndex > 0 {
                currentPageIndex -= 1
            } else if currentChapterIndex > 0 {
                currentChapterIndex -= 1
                recalculatePages()
                currentPageIndex = max(0, pages.count - 1)
            }
        }
    }

    private func toggleBookmark() {
        var currentList = bookmarks
        if let index = currentList.firstIndex(where: { $0.chapterIndex == currentChapterIndex && $0.pageIndex == currentPageIndex }) {
            currentList.remove(at: index)
        } else {
            let preview = pages.indices.contains(currentPageIndex)
                ? String(pages[currentPageIndex].prefix(80))
                : ""
            let newBookmark = EbookBookmark(
                chapterIndex: currentChapterIndex,
                chapterTitle: currentChapter?.title ?? "第 \(currentChapterIndex + 1) 章",
                pageIndex: currentPageIndex,
                pageDisplay: currentPageIndex + 1,
                previewText: preview
            )
            currentList.append(newBookmark)
        }
        bookmarks = currentList
    }

    private func shareCurrentChapter() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController,
              let text = currentChapter?.content else { return }

        let activityVC = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        rootVC.present(activityVC, animated: true)
    }
}
