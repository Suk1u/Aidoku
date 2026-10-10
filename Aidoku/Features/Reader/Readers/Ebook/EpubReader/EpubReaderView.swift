//
//  EpubReaderView.swift
//  Aidoku
//
//  Created by Antigravity on 10/10/26.
//

import SwiftUI

/// 纯原生 SwiftUI EPUB 电子书阅读器（iOS 26+ 原生 Liquid Glass 界面与 Apple HIG 规范）
/// 彻底移除 WKWebView / HTML / CSS / Tailwind，仅使用系统原生排版与液态玻璃材质
struct EpubReaderView: View {
    let book: EpubBook
    @State var currentChapterIndex: Int = 0

    // MARK: - 阅读模式与排版参数
    @AppStorage("Reader.ebookReadingMode") private var readingModeRaw = EbookReadingMode.paged.rawValue
    @AppStorage("Reader.ebookFontSize") private var fontSize: Double = 18.0
    @AppStorage("Reader.ebookLineSpacing") private var lineSpacing: Double = 8.0
    @AppStorage(ReaderTextTheme.userDefaultsKey) private var textThemeRaw = ReaderTextTheme.default.rawValue
    @AppStorage("Reader.ebookBookmarks") private var bookmarksData: Data = Data()

    // MARK: - 页面与交互状态
    @State private var currentPageIndex: Int = 0
    @State private var pagedContent: [String] = []
    @State private var bookmarks: [EbookBookmark] = []
    @State private var showTocSheet = false
    @State private var showSettingsSheet = false
    @State private var showControls = false

    private var readingMode: EbookReadingMode {
        get { EbookReadingMode(rawValue: readingModeRaw) ?? .paged }
        set { readingModeRaw = newValue.rawValue }
    }

    private var theme: ReaderTextTheme {
        ReaderTextTheme(rawValue: textThemeRaw) ?? .default
    }

    private var currentChapter: EpubChapter? {
        guard currentChapterIndex >= 0 && currentChapterIndex < book.chapters.count else { return nil }
        return book.chapters[currentChapterIndex]
    }

    private var remainingPagesInChapter: Int {
        if readingMode == .paged {
            return max(0, pagedContent.count - (currentPageIndex + 1))
        } else {
            return max(0, book.chapters.count - (currentChapterIndex + 1))
        }
    }

    private var isCurrentPageBookmarked: Bool {
        bookmarks.contains {
            $0.chapterIndex == currentChapterIndex && $0.pageIndex == currentPageIndex
        }
    }

    var body: some View {
        ZStack {
            // 背景纸张底色
            Color(theme.backgroundColor)
                .ignoresSafeArea()

            if book.chapters.isEmpty {
                emptyStateView
            } else {
                VStack(spacing: 0) {
                    // MARK: 顶部安全区液态玻璃胶囊「本章还剩 X 页」
                    topPillView
                        .padding(.top, 8)
                        .padding(.bottom, 8)

                    // MARK: 原生排版主阅读内容区
                    Group {
                        if readingMode == .paged {
                            nativePagedContentView
                        } else {
                            nativeScrollContentView
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 0)
                            .onEnded { value in
                                handleScreenTap(at: value.location)
                            }
                    )

                    // MARK: 底部安全区液态玻璃胶囊「当前页/总页数」
                    bottomPillView
                        .padding(.top, 8)
                        .padding(.bottom, 12)
                }

                // MARK: 悬浮 Liquid Glass 控件层 (呼出状态)
                if showControls {
                    liquidGlassControlsOverlay
                }
            }
        }
        .sheet(isPresented: $showTocSheet) {
            let tocItems = book.tocItems.isEmpty
                ? book.chapters.map { (id: $0.id, title: $0.title, page: max(1, $0.id + 1)) }
                : book.tocItems.map { (id: $0.id, title: $0.title, page: max(1, $0.chapterIndex + 1)) }

            AppleBooksTocSheet(
                bookTitle: book.title,
                currentChapterIndex: currentChapterIndex,
                currentPageIndex: currentPageIndex,
                totalPages: max(1, pagedContent.count),
                chapters: tocItems,
                bookmarks: bookmarks,
                onSelectChapter: { newIndex in
                    currentChapterIndex = newIndex
                    currentPageIndex = 0
                    paginateCurrentChapter()
                },
                onSelectBookmark: { bookmark in
                    currentChapterIndex = bookmark.chapterIndex
                    currentPageIndex = bookmark.pageIndex
                    paginateCurrentChapter()
                },
                onDeleteBookmark: { bookmark in
                    bookmarks.removeAll { $0.id == bookmark.id }
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
            if let decoded = try? JSONDecoder().decode([EbookBookmark].self, from: bookmarksData) {
                bookmarks = decoded
            }
            paginateCurrentChapter()
        }
        .onChange(of: bookmarks) { newBookmarks in
            if let encoded = try? JSONEncoder().encode(newBookmarks) {
                bookmarksData = encoded
            }
        }
        .onChange(of: currentChapterIndex) { _ in
            currentPageIndex = 0
            paginateCurrentChapter()
        }
        .onChange(of: fontSize) { _ in
            paginateCurrentChapter()
        }
    }

    // MARK: - 顶部与底部液态玻璃胶囊
    @ViewBuilder
    private var topPillView: some View {
        AppleBooksTopPill(remainingPages: remainingPagesInChapter)
            .opacity(showControls ? 0.35 : 0.9)
            .animation(.easeInOut(duration: 0.2), value: showControls)
    }

    @ViewBuilder
    private var bottomPillView: some View {
        let currentDisplay = readingMode == .paged ? currentPageIndex + 1 : currentChapterIndex + 1
        let totalDisplay = readingMode == .paged ? max(1, pagedContent.count) : max(1, book.chapters.count)
        AppleBooksBottomPill(currentPage: currentDisplay, totalPages: totalDisplay)
            .opacity(showControls ? 0.35 : 0.9)
            .animation(.easeInOut(duration: 0.2), value: showControls)
    }

    // MARK: - 左右仿真翻页视图 (纯原生 SwiftUI 渲染)
    private var nativePagedContentView: some View {
        GeometryReader { _ in
            if !pagedContent.isEmpty && currentPageIndex < pagedContent.count {
                VStack(alignment: .leading, spacing: 0) {
                    if currentPageIndex == 0, let title = currentChapter?.title {
                        Text(title)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(Color(theme.textColor))
                            .padding(.bottom, 16)
                    }

                    Text(pagedContent[currentPageIndex])
                        .font(.system(size: fontSize, design: .serif))
                        .lineSpacing(lineSpacing)
                        .foregroundStyle(Color(theme.textColor))
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 8)
            }
        }
    }

    // MARK: - 连续垂直滚动视图 (纯原生 SwiftUI 渲染)
    private var nativeScrollContentView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let chapter = currentChapter {
                    Text(chapter.title)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(Color(theme.textColor))
                        .padding(.bottom, 12)

                    let paragraphs = chapter.plainTextContent
                        .components(separatedBy: "\n")
                        .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }

                    ForEach(Array(paragraphs.enumerated()), id: \.offset) { _, para in
                        Text("　　" + para.trimmingCharacters(in: .whitespaces))
                            .font(.system(size: fontSize, design: .serif))
                            .lineSpacing(lineSpacing)
                            .foregroundStyle(Color(theme.textColor))
                            .multilineTextAlignment(.leading)
                            .padding(.bottom, 6)
                    }
                }

                // 章节快速跳转操作按钮
                HStack(spacing: 16) {
                    if currentChapterIndex > 0 {
                        Button("上一章") {
                            currentChapterIndex -= 1
                        }
                        .higTouchTarget()
                        .buttonStyle(.bordered)
                    }

                    Spacer()

                    if currentChapterIndex < book.chapters.count - 1 {
                        Button("下一章") {
                            currentChapterIndex += 1
                        }
                        .higTouchTarget()
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding(.top, 24)
                .padding(.bottom, 64)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
    }

    // MARK: - Liquid Glass 原生悬浮控件浮层
    private var liquidGlassControlsOverlay: some View {
        VStack(spacing: 16) {
            Spacer()

            // 右下角多功能快捷液态玻璃菜单
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
            .padding(.trailing, 24)

            // 底部横向液态玻璃操作条 (分享、阅读模式、书签)
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
                    shareCurrentBook()
                },
                onToggleBookmark: {
                    toggleBookmark()
                }
            )
            .padding(.bottom, 24)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.98)))
    }

    // MARK: - 空状态视图
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "book.closed")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(.secondary)
            Text("无可用书籍内容")
                .font(.system(.headline, design: .default))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - 逻辑与辅助动作
    private func paginateCurrentChapter() {
        guard let content = currentChapter?.plainTextContent else {
            pagedContent = []
            return
        }
        let baseChars = 700
        let factor = max(0.5, 18.0 / fontSize)
        let charsPerPage = Int(Double(baseChars) * factor)
        pagedContent = TxtParser.paginate(content: content, charsPerPage: charsPerPage)
        if currentPageIndex >= pagedContent.count {
            currentPageIndex = max(0, pagedContent.count - 1)
        }
    }

    private func handleScreenTap(at location: CGPoint) {
        let screenWidth = UIScreen.main.bounds.width
        let tapThreshold = screenWidth * 0.30

        if location.x < tapThreshold {
            if readingMode == .paged {
                turnPage(forward: false)
            } else {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    showControls.toggle()
                }
            }
        } else if location.x > screenWidth - tapThreshold {
            if readingMode == .paged {
                turnPage(forward: true)
            } else {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    showControls.toggle()
                }
            }
        } else {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                showControls.toggle()
            }
        }
    }

    private func turnPage(forward: Bool) {
        if forward {
            if currentPageIndex < pagedContent.count - 1 {
                currentPageIndex += 1
            } else if currentChapterIndex < book.chapters.count - 1 {
                currentChapterIndex += 1
                currentPageIndex = 0
            }
        } else {
            if currentPageIndex > 0 {
                currentPageIndex -= 1
            } else if currentChapterIndex > 0 {
                currentChapterIndex -= 1
                paginateCurrentChapter()
                currentPageIndex = max(0, pagedContent.count - 1)
            }
        }
    }

    private func toggleBookmark() {
        if let index = bookmarks.firstIndex(where: { $0.chapterIndex == currentChapterIndex && $0.pageIndex == currentPageIndex }) {
            bookmarks.remove(at: index)
        } else {
            let preview = pagedContent.indices.contains(currentPageIndex)
                ? String(pagedContent[currentPageIndex].prefix(80))
                : (currentChapter.map { String($0.plainTextContent.prefix(80)) } ?? "")
            let newBookmark = EbookBookmark(
                chapterIndex: currentChapterIndex,
                chapterTitle: currentChapter?.title ?? "第 \(currentChapterIndex + 1) 章",
                pageIndex: currentPageIndex,
                pageDisplay: currentPageIndex + 1,
                previewText: preview
            )
            bookmarks.append(newBookmark)
        }
    }

    private func shareCurrentBook() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else { return }

        let shareText = "正在阅读《\(book.title)》· \(currentChapter?.title ?? "")"
        let activityVC = UIActivityViewController(activityItems: [shareText], applicationActivities: nil)
        rootVC.present(activityVC, animated: true)
    }
}

#Preview("EpubReaderView Preview") {
    let sampleChapter = EpubChapter(
        id: 0,
        title: "第一章 春日的重逢",
        href: "chapter1.xhtml",
        htmlContent: "",
        plainTextContent: "四月的微风拂过樱花树梢，初升的阳光洒在静谧的街道上。走在通往学园的坂道上，空气中弥漫着青草与花瓣的芬芳。"
    )
    let sampleBook = EpubBook(
        title: "败犬女主太多了！",
        author: "雨森たきび",
        coverImage: nil,
        chapters: [sampleChapter],
        tocItems: [EpubTocItem(id: 0, title: "第一章 春日的重逢", href: "chapter1.xhtml", chapterIndex: 0)],
        baseDirectory: nil
    )
    EpubReaderView(book: sampleBook)
}
