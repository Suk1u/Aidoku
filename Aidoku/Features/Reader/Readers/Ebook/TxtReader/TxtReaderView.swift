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

    // MARK: - Page & Navigation State
    @State private var currentPageIndex: Int = 0
    @State private var pages: [String] = []
    @State private var showTocSheet = false
    @State private var showControls = false

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

    var body: some View {
        ZStack {
            Color(theme.backgroundColor)
                .ignoresSafeArea()

            if chapters.isEmpty {
                emptyView
            } else {
                Group {
                    if readingMode == .paged {
                        pagedContentView
                    } else {
                        scrollContentView
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture { location in
                    handleTap(at: location)
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
        VStack(spacing: 0) {
            // 顶部章节简标
            HStack {
                Text(currentChapter?.title ?? "")
                    .font(.caption)
                    .foregroundStyle(Color(theme.textColor).opacity(0.6))
                    .lineLimit(1)
                Spacer()
                Text("第 \(currentChapterIndex + 1) / \(chapters.count) 章")
                    .font(.caption2)
                    .foregroundStyle(Color(theme.textColor).opacity(0.5))
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .padding(.bottom, 6)

            // 正文页面
            GeometryReader { geo in
                if !pages.isEmpty && currentPageIndex < pages.count {
                    Text(pages[currentPageIndex])
                        .font(.system(size: fontSize))
                        .lineSpacing(lineSpacing)
                        .foregroundStyle(Color(theme.textColor))
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 8)
                }
            }

            // 底部页码指示
            HStack {
                Spacer()
                Text("\(currentPageIndex + 1) / \(max(1, pages.count))")
                    .font(.caption2)
                    .foregroundStyle(Color(theme.textColor).opacity(0.5))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 10)
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

                // 章节切换快速导航按钮
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
                .padding(.bottom, 48)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
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

                // 阅读模式切换按钮
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

                // 字号调节
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

            // 底部章节进度切换栏
            VStack(spacing: 12) {
                HStack {
                    Button("上一章") {
                        if currentChapterIndex > 0 {
                            currentChapterIndex -= 1
                        }
                    }
                    .disabled(currentChapterIndex <= 0)

                    Slider(
                        value: Binding(
                            get: { Double(currentChapterIndex) },
                            set: { currentChapterIndex = Int($0) }
                        ),
                        in: 0...Double(max(0, chapters.count - 1)),
                        step: 1
                    )

                    Button("下一章") {
                        if currentChapterIndex < chapters.count - 1 {
                            currentChapterIndex += 1
                        }
                    }
                    .disabled(currentChapterIndex >= chapters.count - 1)
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
            List(chapters) { chapter in
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
            .navigationTitle("目录")
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
            Image(systemName: "doc.text")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("无文本内容")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Helpers
    private func recalculatePages() {
        guard let content = currentChapter?.content else {
            pages = []
            return
        }
        // 根据字号大致估算每页字符容量
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
            // 点击左侧：上一页
            if readingMode == .paged {
                turnPage(forward: false)
            } else {
                withAnimation { showControls.toggle() }
            }
        } else if location.x > screenWidth - tapMargin {
            // 点击右侧：下一页
            if readingMode == .paged {
                turnPage(forward: true)
            } else {
                withAnimation { showControls.toggle() }
            }
        } else {
            // 点击中部：切换菜单浮层
            withAnimation {
                showControls.toggle()
            }
        }
    }

    private func turnPage(forward: Bool) {
        if forward {
            if currentPageIndex < pages.count - 1 {
                currentPageIndex += 1
            } else if currentChapterIndex < chapters.count - 1 {
                // 自动进入下一章
                currentChapterIndex += 1
                currentPageIndex = 0
            }
        } else {
            if currentPageIndex > 0 {
                currentPageIndex -= 1
            } else if currentChapterIndex > 0 {
                // 回到上一章最后一页
                currentChapterIndex -= 1
                recalculatePages()
                currentPageIndex = max(0, pages.count - 1)
            }
        }
    }
}
