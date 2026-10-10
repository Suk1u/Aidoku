//
//  AppleBooksComponents.swift
//  Aidoku
//
//  Created by Antigravity on 10/10/26.
//

import SwiftUI

// MARK: - 书签数据模型
struct EbookBookmark: Identifiable, Codable, Equatable {
    let id: UUID
    let chapterIndex: Int
    let chapterTitle: String
    let pageIndex: Int
    let pageDisplay: Int
    let previewText: String
    let date: Date

    init(
        id: UUID = UUID(),
        chapterIndex: Int,
        chapterTitle: String,
        pageIndex: Int,
        pageDisplay: Int,
        previewText: String,
        date: Date = Date()
    ) {
        self.id = id
        self.chapterIndex = chapterIndex
        self.chapterTitle = chapterTitle
        self.pageIndex = pageIndex
        self.pageDisplay = pageDisplay
        self.previewText = previewText
        self.date = date
    }
}

// MARK: - 顶部「本章还剩 X 页」原生液态玻璃胶囊指示器
struct AppleBooksTopPill: View {
    let remainingPages: Int

    var body: some View {
        Text("本章还剩 \(max(0, remainingPages)) 页")
            .font(.system(.footnote, design: .default, weight: .medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .liquidGlassPill()
    }
}

// MARK: - 底部「X/Y 页」原生液态玻璃居中胶囊指示器
struct AppleBooksBottomPill: View {
    let currentPage: Int
    let totalPages: Int

    var body: some View {
        Text("\(currentPage)/\(max(1, totalPages)) 页")
            .font(.system(.footnote, design: .default, weight: .medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .liquidGlassPill()
    }
}

// MARK: - 右下角快捷原生液态玻璃操作菜单 (HIG 规范，无手动描边与厚重阴影)
struct AppleBooksQuickMenu: View {
    var onOpenToc: () -> Void
    var onOpenSearch: () -> Void
    var onOpenSettings: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Button(action: onOpenToc) {
                HStack(spacing: 16) {
                    Text("目录")
                        .font(.system(.body, design: .default))
                    Spacer()
                    Image(systemName: "list.bullet")
                        .font(.system(size: 17, weight: .medium))
                }
                .padding(.horizontal, 16)
                .frame(minHeight: 48)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Divider()
                .padding(.horizontal, 16)

            Button(action: onOpenSearch) {
                HStack(spacing: 16) {
                    Text("在图书中搜索")
                        .font(.system(.body, design: .default))
                    Spacer()
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 17, weight: .medium))
                }
                .padding(.horizontal, 16)
                .frame(minHeight: 48)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Divider()
                .padding(.horizontal, 16)

            Button(action: onOpenSettings) {
                HStack(spacing: 16) {
                    Text("主题与设置")
                        .font(.system(.body, design: .default))
                    Spacer()
                    Text("大小")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.secondary.opacity(0.18), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                .padding(.horizontal, 16)
                .frame(minHeight: 48)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .frame(width: 208)
        .liquidGlass(in: RoundedRectangle(cornerRadius: 20, style: .continuous), prominent: true)
    }
}

// MARK: - 底部横向悬浮原生液态玻璃操作栏 (分享、阅读模式、书签)
struct AppleBooksBottomBar: View {
    @Binding var isBookmarked: Bool
    @Binding var readingMode: EbookReadingMode
    var onShare: () -> Void
    var onToggleBookmark: () -> Void

    var body: some View {
        HStack(spacing: 24) {
            // 分享按钮 (触控区域 ≥ 44pt)
            Button(action: onShare) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.primary)
            }
            .higTouchTarget()

            // 阅读模式切换 (左右翻页 / 连续垂直滚动)
            Button {
                readingMode = (readingMode == .paged ? .scroll : .paged)
            } label: {
                Image(systemName: readingMode == .paged ? "book.pages" : "scroll")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.primary)
            }
            .higTouchTarget()

            // 书签按钮
            Button(action: onToggleBookmark) {
                Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(isBookmarked ? Color.red : Color.primary)
            }
            .higTouchTarget()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 8)
        .liquidGlassPill(prominent: true)
    }
}

// MARK: - 原生 NavigationStack 目录/书签抽屉 (TOC Sheet)
struct AppleBooksTocSheet: View {
    let bookTitle: String
    let currentChapterIndex: Int
    let currentPageIndex: Int
    let totalPages: Int
    let chapters: [(id: Int, title: String, page: Int)]
    let bookmarks: [EbookBookmark]
    var onSelectChapter: (Int) -> Void
    var onSelectBookmark: (EbookBookmark) -> Void
    var onDeleteBookmark: (EbookBookmark) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var selectedTab: Int = 0 // 0: 章节, 1: 书签, 2: 笔记与标记

    var body: some View {
        PlatformNavigationStack {
            VStack(spacing: 0) {
                // 顶部导航信息条 (8pt 栅格)
                HStack(spacing: 16) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.secondary)
                            .frame(width: 32, height: 32)
                            .background(Color.secondary.opacity(0.16), in: Circle())
                    }
                    .higTouchTarget()

                    Spacer()

                    VStack(spacing: 2) {
                        Text(bookTitle)
                            .font(.system(.headline, design: .default))
                            .lineLimit(1)
                        Text("第 \(currentPageIndex + 1)/\(max(1, totalPages)) 页")
                            .font(.system(.caption, design: .default))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Color.clear
                        .frame(width: 44, height: 44)
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 8)

                // 原生分段控制器：章节 / 书签 / 标记
                Picker("", selection: $selectedTab) {
                    Text("章节").tag(0)
                    Text("书签").tag(1)
                    Text("标记").tag(2)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.bottom, 16)

                Divider()

                // 内容列表
                if selectedTab == 0 {
                    chapterListView
                } else if selectedTab == 1 {
                    bookmarkListView
                } else {
                    highlightListView
                }
            }
            .background(Color(uiColor: .systemBackground))
        }
    }

    // 章节列表
    private var chapterListView: some View {
        ScrollViewReader { proxy in
            List(chapters, id: \.id) { chapter in
                Button {
                    onSelectChapter(chapter.id)
                    dismiss()
                } label: {
                    HStack(spacing: 16) {
                        Text(chapter.title)
                            .font(.system(.body, design: .default))
                            .foregroundStyle(chapter.id == currentChapterIndex ? .primary : .secondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)

                        Spacer()

                        Text("\(chapter.page)")
                            .font(.system(.callout, design: .default))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 16)
                    .frame(minHeight: 48)
                    .background(
                        chapter.id == currentChapterIndex
                            ? Color.secondary.opacity(0.18)
                            : Color.clear,
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                    )
                }
                .buttonStyle(.plain)
                .listRowInsets(EdgeInsets(top: 2, leading: 8, bottom: 2, trailing: 8))
                .listRowSeparator(.hidden)
                .id(chapter.id)
            }
            .listStyle(.plain)
            .onAppear {
                proxy.scrollTo(currentChapterIndex, anchor: .center)
            }
        }
    }

    // 书签列表
    private var bookmarkListView: some View {
        Group {
            if bookmarks.isEmpty {
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "bookmark")
                        .font(.system(size: 44, weight: .light))
                        .foregroundStyle(.secondary)
                    Text("尚无添加的书签")
                        .font(.system(.subheadline, design: .default))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            } else {
                List {
                    ForEach(bookmarks) { bookmark in
                        Button {
                            onSelectBookmark(bookmark)
                            dismiss()
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(bookmark.chapterTitle)
                                        .font(.body.weight(.medium))
                                    Spacer()
                                    Text("第 \(bookmark.pageDisplay) 页")
                                        .font(.system(.caption, design: .default))
                                        .foregroundStyle(.secondary)
                                }
                                if !bookmark.previewText.isEmpty {
                                    Text(bookmark.previewText)
                                        .font(.system(.caption, design: .default))
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                            }
                            .padding(.vertical, 8)
                            .frame(minHeight: 48)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                onDeleteBookmark(bookmark)
                            } label: {
                                Label("删除", systemImage: "trash")
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    // 标记列表
    private var highlightListView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "highlighter")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(.secondary)
            Text("暂无高亮与划线笔记")
                .font(.system(.subheadline, design: .default))
                .foregroundStyle(.secondary)
            Spacer()
        }
    }
}

// MARK: - 原生主题与排版设置面板 (Apple HIG 规范)
struct AppleBooksThemeSettingsSheet: View {
    @Binding var fontSize: Double
    @Binding var textThemeRaw: String
    @Binding var readingMode: EbookReadingMode
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 24) {
            // 顶部抓手
            Capsule()
                .fill(Color.secondary.opacity(0.3))
                .frame(width: 36, height: 5)
                .padding(.top, 12)

            // 字号调节器 (触控热区 ≥ 44pt，8pt 栅格)
            HStack(spacing: 16) {
                Button {
                    if fontSize > 12 { fontSize -= 1 }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "textformat.size.smaller")
                        Text("小")
                    }
                    .font(.subheadline.weight(.medium))
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 44)
                    .background(Color.secondary.opacity(0.16), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                Text("\(Int(fontSize))")
                    .font(.title3.weight(.bold))
                    .frame(width: 48)

                Button {
                    if fontSize < 36 { fontSize += 1 }
                } label: {
                    HStack(spacing: 8) {
                        Text("大")
                        Image(systemName: "textformat.size.larger")
                    }
                    .font(.subheadline.weight(.medium))
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 44)
                    .background(Color.secondary.opacity(0.16), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, 24)

            // 原生纸张主题色盘选择器 (每个圆盘 44x44 pt)
            HStack(spacing: 20) {
                ForEach(ReaderTextTheme.allCases, id: \.rawValue) { theme in
                    Button {
                        textThemeRaw = theme.rawValue
                    } label: {
                        Circle()
                            .fill(Color(theme.backgroundColor))
                            .frame(width: 44, height: 44)
                            .overlay(
                                Circle()
                                    .stroke(
                                        textThemeRaw == theme.rawValue ? Color.accentColor : Color.secondary.opacity(0.24),
                                        lineWidth: textThemeRaw == theme.rawValue ? 3 : 1
                                    )
                            )
                            .overlay(
                                Text("Aa")
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(Color(theme.textColor))
                            )
                    }
                    .higTouchTarget()
                }
            }
            .padding(.horizontal, 24)

            // 阅读翻页模式切换 (左右翻页 / 连续滚动，触控区域 ≥ 44pt)
            HStack(spacing: 16) {
                Button {
                    readingMode = .paged
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "book.pages")
                        Text("左右翻页")
                    }
                    .font(.body.weight(.medium))
                    .foregroundStyle(readingMode == .paged ? Color.accentColor : Color.primary)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 48)
                    .background(
                        readingMode == .paged ? Color.accentColor.opacity(0.16) : Color.secondary.opacity(0.14),
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                    )
                }

                Button {
                    readingMode = .scroll
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "scroll")
                        Text("连续滚动")
                    }
                    .font(.body.weight(.medium))
                    .foregroundStyle(readingMode == .scroll ? Color.accentColor : Color.primary)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 48)
                    .background(
                        readingMode == .scroll ? Color.accentColor.opacity(0.16) : Color.secondary.opacity(0.14),
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                    )
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .sheetHeight260()
        .background(Color(uiColor: .systemBackground))
    }
}

private extension View {
    @ViewBuilder
    func sheetHeight260() -> some View {
        if #available(iOS 16.0, *) {
            self.presentationDetents([.height(260)])
        } else {
            self
        }
    }
}

// MARK: - Previews for iOS 26+ Apple HIG
#Preview("TOC Sheet Preview") {
    AppleBooksTocSheet(
        bookTitle: "败犬女主太多了！",
        currentChapterIndex: 1,
        currentPageIndex: 0,
        totalPages: 24,
        chapters: [
            (id: 0, title: "序言", page: 1),
            (id: 1, title: "~第一败~ 初次见面，我是水岛小春", page: 20),
            (id: 2, title: "~第二败~ 刨冰上的甜蜜糖浆", page: 60)
        ],
        bookmarks: [],
        onSelectChapter: { _ in },
        onSelectBookmark: { _ in },
        onDeleteBookmark: { _ in }
    )
}

#Preview("Theme Settings Sheet Preview") {
    AppleBooksThemeSettingsSheet(
        fontSize: .constant(18),
        textThemeRaw: .constant("default"),
        readingMode: .constant(.paged)
    )
}
