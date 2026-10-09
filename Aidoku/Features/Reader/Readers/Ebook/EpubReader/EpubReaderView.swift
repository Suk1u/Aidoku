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

    // MARK: - Navigation & Controls State
    @State private var showTocSheet = false
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

    var body: some View {
        ZStack {
            Color(theme.backgroundColor)
                .ignoresSafeArea()

            if book.chapters.isEmpty {
                emptyView
            } else {
                VStack(spacing: 0) {
                    // 顶部简要章节状态
                    headerBar

                    // 章节内容展示容器
                    if let chapter = currentChapter {
                        EpubHtmlWebView(
                            html: styledHtml(for: chapter),
                            baseURL: book.baseDirectory,
                            onCenterTap: {
                                withAnimation { showControls.toggle() }
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

                    // 底部简要进度
                    footerBar
                }

                // 悬浮工具浮层
                if showControls {
                    controlsOverlay
                }
            }
        }
        .sheet(isPresented: $showTocSheet) {
            tocSheetView
        }
    }

    // MARK: - Header & Footer Bars
    private var headerBar: some View {
        HStack {
            Text(currentChapter?.title ?? book.title)
                .font(.caption)
                .foregroundStyle(Color(theme.textColor).opacity(0.6))
                .lineLimit(1)
            Spacer()
            Text("第 \(currentChapterIndex + 1) / \(book.chapters.count) 章")
                .font(.caption2)
                .foregroundStyle(Color(theme.textColor).opacity(0.5))
        }
        .padding(.horizontal, 20)
        .padding(.top, 6)
        .padding(.bottom, 4)
    }

    private var footerBar: some View {
        HStack {
            Text(book.title)
                .font(.caption2)
                .foregroundStyle(Color(theme.textColor).opacity(0.4))
                .lineLimit(1)
            Spacer()
            Text("\(Int(Double(currentChapterIndex + 1) / Double(max(1, book.chapters.count)) * 100))%")
                .font(.caption2)
                .foregroundStyle(Color(theme.textColor).opacity(0.5))
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
    }

    // MARK: - Controls Overlay
    private var controlsOverlay: some View {
        VStack {
            // 顶部栏
            HStack {
                Button {
                    showTocSheet = true
                } label: {
                    Image(systemName: "list.bullet")
                        .font(.system(size: 18))
                        .padding(10)
                        .background(.ultraThinMaterial, in: Circle())
                }

                Spacer()

                // 阅读模式切换
                Button {
                    readingModeRaw = (readingMode == .paged ? EbookReadingMode.scroll : .paged).rawValue
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: readingMode == .paged ? "book.pages" : "scroll")
                        Text(readingMode.title)
                            .font(.caption.weight(.medium))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial, in: Capsule())
                }

                // 字号切换
                HStack(spacing: 8) {
                    Button {
                        if fontSize > 12 { fontSize -= 1 }
                    } label: {
                        Image(systemName: "textformat.size.smaller")
                            .padding(8)
                            .background(.ultraThinMaterial, in: Circle())
                    }

                    Button {
                        if fontSize < 32 { fontSize += 1 }
                    } label: {
                        Image(systemName: "textformat.size.larger")
                            .padding(8)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)

            Spacer()

            // 底部章节快切滑块
            VStack(spacing: 12) {
                HStack {
                    Button("上一章") {
                        previousChapter()
                    }
                    .disabled(currentChapterIndex <= 0)

                    Slider(
                        value: Binding(
                            get: { Double(currentChapterIndex) },
                            set: { currentChapterIndex = Int($0) }
                        ),
                        in: 0...Double(max(0, book.chapters.count - 1)),
                        step: 1
                    )

                    Button("下一章") {
                        nextChapter()
                    }
                    .disabled(currentChapterIndex >= book.chapters.count - 1)
                }
                .font(.footnote)
            }
            .padding(14)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
    }

    // MARK: - Table of Contents Sheet
    private var tocSheetView: some View {
        NavigationStack {
            List(book.chapters) { chapter in
                Button {
                    currentChapterIndex = chapter.id
                    showTocSheet = false
                } label: {
                    HStack {
                        Text(chapter.title)
                            .foregroundStyle(chapter.id == currentChapterIndex ? .accentColor : .primary)
                        Spacer()
                        if chapter.id == currentChapterIndex {
                            Image(systemName: "checkmark")
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                }
            }
            .navigationTitle("目录 (\(book.chapters.count))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") {
                        showTocSheet = false
                    }
                }
            }
        }
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
                padding: 12px 18px 48px 18px !important;
                margin: 0 !important;
                word-wrap: break-word !important;
                -webkit-text-size-adjust: 100% !important;
            }
            img {
                max-width: 100% !important;
                height: auto !important;
                display: block !important;
                margin: 12px auto !important;
                border-radius: 8px !important;
            }
            p {
                margin: 0 0 1em 0 !important;
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
