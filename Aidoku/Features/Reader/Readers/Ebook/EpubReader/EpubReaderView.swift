//
//  EpubReaderView.swift
//  Aidoku
//
//  Created by Antigravity on 10/9/26.
//

import SwiftUI
import WebKit

struct EpubReaderView: View {
    let book: EpubBook
    @State var currentChapterIndex: Int = 0

    // MARK: - Reading Mode & Typography Settings
    @AppStorage("Reader.ebookReadingMode") private var readingModeRaw = EbookReadingMode.paged.rawValue
    @AppStorage("Reader.ebookFontSize") private var fontSize: Double = 18.0
    @AppStorage("Reader.ebookLineSpacing") private var lineSpacing: Double = 1.6
    @AppStorage(ReaderTextTheme.userDefaultsKey) private var textThemeRaw = ReaderTextTheme.default.rawValue
    @AppStorage("Reader.ebookBookmarks") private var bookmarksData: Data = Data()

    // MARK: - Navigation & Controls State
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

    private var remainingChapters: Int {
        max(0, book.chapters.count - (currentChapterIndex + 1))
    }

    @State private var bookmarks: [EbookBookmark] = []

    private var isCurrentChapterBookmarked: Bool {
        bookmarks.contains { $0.chapterIndex == currentChapterIndex }
    }

    var body: some View {
        ZStack {
            Color(theme.backgroundColor)
                .ignoresSafeArea()

            if book.chapters.isEmpty {
                emptyView
            } else {
                VStack(spacing: 0) {
                    // 顶部 Apple Books 风格胶囊：剩余章节
                    AppleBooksTopPill(remainingPages: remainingChapters)
                        .padding(.top, 10)
                        .opacity(showControls ? 0.4 : 0.85)

                    // 章节网页富文本呈现容器
                    if let chapter = currentChapter {
                        EpubHtmlWebView(
                            html: styledHtml(for: chapter),
                            baseURL: book.baseDirectory,
                            onCenterTap: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    showControls.toggle()
                                }
                            },
                            onLeftTap: {
                                previousChapter()
                            },
                            onRightTap: {
                                nextChapter()
                            }
                        )
                        .id("\(currentChapterIndex)_\(textThemeRaw)_\(fontSize)")
                    }

                    // 底部 Apple Books 风格胶囊：当前/总章节
                    AppleBooksBottomPill(
                        currentPage: currentChapterIndex + 1,
                        totalPages: book.chapters.count
                    )
                    .padding(.bottom, 12)
                    .opacity(showControls ? 0.4 : 0.85)
                }

                // 悬浮交互浮层 (Apple Books Quick Menu & Bottom Bar)
                if showControls {
                    controlsOverlay
                }
            }
        }
        .sheet(isPresented: $showTocSheet) {
            let chapterItems = book.chapters.map {
                (id: $0.id, title: $0.title, page: max(1, $0.id * 10 + 1))
            }
            AppleBooksTocSheet(
                bookTitle: book.title,
                currentChapterIndex: currentChapterIndex,
                currentPageIndex: currentChapterIndex,
                totalPages: book.chapters.count,
                chapters: chapterItems,
                bookmarks: bookmarks,
                onSelectChapter: { newIndex in
                    currentChapterIndex = newIndex
                },
                onSelectBookmark: { bookmark in
                    currentChapterIndex = bookmark.chapterIndex
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
            if let decoded = try? JSONDecoder().decode([EbookBookmark].self, from: bookmarksData) {
                bookmarks = decoded
            }
        }
        .onChange(of: bookmarks) { newBookmarks in
            if let encoded = try? JSONEncoder().encode(newBookmarks) {
                bookmarksData = encoded
            }
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
                    get: { isCurrentChapterBookmarked },
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
        .transition(.opacity.combined(with: .scale(scale: 0.96)))
    }

    private var emptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: "books.vertical")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("无可用章节")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Actions
    private func previousChapter() {
        if currentChapterIndex > 0 {
            currentChapterIndex -= 1
        }
    }

    private func nextChapter() {
        if currentChapterIndex < book.chapters.count - 1 {
            currentChapterIndex += 1
        }
    }

    private func toggleBookmark() {
        var currentList = bookmarks
        if let index = currentList.firstIndex(where: { $0.chapterIndex == currentChapterIndex }) {
            currentList.remove(at: index)
        } else {
            let preview = currentChapter?.plainTextContent.prefix(80) ?? ""
            let newBookmark = EbookBookmark(
                chapterIndex: currentChapterIndex,
                chapterTitle: currentChapter?.title ?? "第 \(currentChapterIndex + 1) 章",
                pageIndex: currentChapterIndex,
                pageDisplay: currentChapterIndex + 1,
                previewText: String(preview)
            )
            currentList.append(newBookmark)
        }
        bookmarks = currentList
    }

    private func shareCurrentBook() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else { return }

        let shareText = "正在阅读《\(book.title)》- \(currentChapter?.title ?? "")"
        let activityVC = UIActivityViewController(activityItems: [shareText], applicationActivities: nil)
        rootVC.present(activityVC, animated: true)
    }

    // MARK: - CSS Injected HTML Builder
    private func styledHtml(for chapter: EpubChapter) -> String {
        let bgColor = hexString(from: theme.backgroundColor)
        let textColor = hexString(from: theme.textColor)

        let injectedCss = """
        <style>
            html, body {
                background-color: \(bgColor) !important;
                color: \(textColor) !important;
                font-size: \(fontSize)px !important;
                line-height: \(lineSpacing) !important;
                font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif !important;
                padding: 16px 22px 64px 22px !important;
                margin: 0 !important;
                word-wrap: break-word !important;
                -webkit-text-size-adjust: 100% !important;
            }
            img {
                max-width: 100% !important;
                height: auto !important;
                display: block !important;
                margin: 14px auto !important;
                border-radius: 8px !important;
            }
            p {
                margin: 0 0 1.1em 0 !important;
                text-indent: 2em !important;
            }
            h1, h2, h3, h4, h5, h6 {
                color: \(textColor) !important;
                text-align: center !important;
                margin-top: 1.2em !important;
                margin-bottom: 0.8em !important;
            }
            a {
                color: #007AFF !important;
                text-decoration: none !important;
            }
        </style>
        """

        if chapter.htmlContent.contains("<head>") {
            return chapter.htmlContent.replacingOccurrences(of: "<head>", with: "<head>\(injectedCss)")
        } else {
            return "<html><head>\(injectedCss)</head><body>\(chapter.htmlContent)</body></html>"
        }
    }

    private func hexString(from color: UIColor) -> String {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "#%02lX%02lX%02lX", lroundf(Float(r * 255)), lroundf(Float(g * 255)), lroundf(Float(b * 255)))
    }
}

// MARK: - WKWebView Wrapper with Tap Area Dispatch
private struct EpubHtmlWebView: UIViewRepresentable {
    let html: String
    let baseURL: URL?
    var onCenterTap: (() -> Void)?
    var onLeftTap: (() -> Void)?
    var onRightTap: (() -> Void)?

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear

        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        tapGesture.delegate = context.coordinator
        webView.addGestureRecognizer(tapGesture)

        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.parent = self
        webView.loadHTMLString(html, baseURL: baseURL)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var parent: EpubHtmlWebView

        init(_ parent: EpubHtmlWebView) {
            self.parent = parent
        }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let view = gesture.view else { return }
            let location = gesture.location(in: view)
            let width = view.bounds.width
            let tapMargin = width * 0.28

            if location.x < tapMargin {
                parent.onLeftTap?()
            } else if location.x > width - tapMargin {
                parent.onRightTap?()
            } else {
                parent.onCenterTap?()
            }
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            true
        }
    }
}
