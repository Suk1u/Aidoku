//
//  AppleBooksComponents.swift
//  Aidoku
//
//  Created by Antigravity on 10/9/26.
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

// MARK: - 顶部「本章还剩 X 页」胶囊指示器
struct AppleBooksTopPill: View {
    let remainingPages: Int

    var body: some View {
        Text("本章还剩 \(max(0, remainingPages)) 页")
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 5)
            .background(.ultraThinMaterial, in: Capsule())
            .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 3)
    }
}

// MARK: - 底部「X/Y 页」居中胶囊指示器
struct AppleBooksBottomPill: View {
    let currentPage: Int
    let totalPages: Int

    var body: some View {
        Text("\(currentPage)/\(max(1, totalPages)) 页")
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 5)
            .background(.ultraThinMaterial, in: Capsule())
            .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 3)
    }
}

// MARK: - 视频同款右下角快捷毛玻璃操作菜单
struct AppleBooksQuickMenu: View {
    var onOpenToc: () -> Void
    var onOpenSearch: () -> Void
    var onOpenSettings: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Button(action: onOpenToc) {
                HStack {
                    Text("目录")
                        .font(.system(size: 16))
                    Spacer()
                    Image(systemName: "list.bullet")
                        .font(.system(size: 16, weight: .medium))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Divider()
                .padding(.horizontal, 12)

            Button(action: onOpenSearch) {
                HStack {
                    Text("在图书中搜索")
                        .font(.system(size: 16))
                    Spacer()
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 16, weight: .medium))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Divider()
                .padding(.horizontal, 12)

            Button(action: onOpenSettings) {
                HStack {
                    Text("主题与设置")
                        .font(.system(size: 16))
                    Spacer()
                    Text("大小")
                        .font(.system(size: 14, weight: .semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.18), in: RoundedRectangle(cornerRadius: 6))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .frame(width: 200)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.24), radius: 18, x: 0, y: 8)
    }
}

// MARK: - 底部横向悬浮操作栏（分享、模式、书签）
struct AppleBooksBottomBar: View {
    @Binding var isBookmarked: Bool
    @Binding var readingMode: EbookReadingMode
    var onShare: () -> Void
    var onToggleBookmark: () -> Void

    var body: some View {
        HStack(spacing: 24) {
            // 分享
            Button(action: onShare) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.primary)
            }

            // 阅读模式切换 (左右翻页 / 连续滚动)
            Button {
                readingMode = (readingMode == .paged ? .scroll : .paged)
            } label: {
                Image(systemName: readingMode == .paged ? "book.pages" : "scroll")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.primary)
            }

            // 书签
            Button(action: onToggleBookmark) {
                Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(isBookmarked ? Color.red : Color.primary)
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(
            Capsule()
                .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.18), radius: 14, x: 0, y: 6)
    }
}

// MARK: - 视频同款高仿目录/书签抽屉 (TOC Sheet)
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

    @State private var selectedTab: Int = 0 // 0: 章节, 1: 书签, 2: 高亮标记

    var body: some View {
        PlatformNavigationStack {
            VStack(spacing: 0) {
                // 顶部标题与页码
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.secondary)
                            .frame(width: 32, height: 32)
                            .background(Color.secondary.opacity(0.15), in: Circle())
                    }

                    Spacer()

                    VStack(spacing: 2) {
                        Text(bookTitle)
                            .font(.system(size: 16, weight: .semibold))
                            .lineLimit(1)
                        Text("第 \(currentPageIndex + 1)/\(max(1, totalPages)) 页")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Color.clear
                        .frame(width: 32, height: 32)
                }
                .padding(.horizontal, 18)
                .padding(.top, 14)
                .padding(.bottom, 12)

                // 分段选择器：章节 / 书签 / 高亮标记
                Picker("", selection: $selectedTab) {
                    Text("章节").tag(0)
                    Text("书签").tag(1)
                    Text("高亮标记").tag(2)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 18)
                .padding(.bottom, 12)

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
                    HStack {
                        Text(chapter.title)
                            .font(.system(size: 16))
                            .foregroundStyle(chapter.id == currentChapterIndex ? .primary : .secondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)

                        Spacer()

                        Text("\(chapter.page)")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(
                        chapter.id == currentChapterIndex
                            ? Color.secondary.opacity(0.18)
                            : Color.clear,
                        in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                    )
                }
                .buttonStyle(.plain)
                .listRowInsets(EdgeInsets(top: 2, leading: 14, bottom: 2, trailing: 14))
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
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "bookmark")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                    Text("尚无书签")
                        .font(.subheadline)
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
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(bookmark.chapterTitle)
                                        .font(.system(size: 15, weight: .medium))
                                    Spacer()
                                    Text("第 \(bookmark.pageDisplay) 页")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                if !bookmark.previewText.isEmpty {
                                    Text(bookmark.previewText)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                            }
                            .padding(.vertical, 4)
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

    // 高亮标记列表
    private var highlightListView: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "highlighter")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("暂无笔记与高亮")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }
}

// MARK: - 主题与设置面板 (Themes & Settings Sheet)
struct AppleBooksThemeSettingsSheet: View {
    @Binding var fontSize: Double
    @Binding var textThemeRaw: String
    @Binding var readingMode: EbookReadingMode
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            // 顶部小横条
            Capsule()
                .fill(Color.secondary.opacity(0.3))
                .frame(width: 36, height: 5)
                .padding(.top, 10)

            // 字号调节器
            HStack {
                Button {
                    if fontSize > 12 { fontSize -= 1 }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "textformat.size.smaller")
                        Text("小")
                    }
                    .font(.system(size: 15, weight: .medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.secondary.opacity(0.15), in: RoundedRectangle(cornerRadius: 10))
                }

                Text("\(Int(fontSize))")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(width: 44)

                Button {
                    if fontSize < 36 { fontSize += 1 }
                } label: {
                    HStack(spacing: 4) {
                        Text("大")
                        Image(systemName: "textformat.size.larger")
                    }
                    .font(.system(size: 15, weight: .medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.secondary.opacity(0.15), in: RoundedRectangle(cornerRadius: 10))
                }
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, 20)

            // 纸张与背景主题色盘
            HStack(spacing: 16) {
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
                                        textThemeRaw == theme.rawValue ? Color.accentColor : Color.secondary.opacity(0.25),
                                        lineWidth: textThemeRaw == theme.rawValue ? 3 : 1
                                    )
                            )
                            .overlay(
                                Text("Aa")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(Color(theme.textColor))
                            )
                    }
                }
            }
            .padding(.horizontal, 20)

            // 翻页模式切换
            HStack(spacing: 12) {
                Button {
                    readingMode = .paged
                } label: {
                    HStack {
                        Image(systemName: "book.pages")
                        Text("左右翻页")
                    }
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(readingMode == .paged ? Color.accentColor : Color.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        readingMode == .paged ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.15),
                        in: RoundedRectangle(cornerRadius: 10)
                    )
                }

                Button {
                    readingMode = .scroll
                } label: {
                    HStack {
                        Image(systemName: "scroll")
                        Text("连续滚动")
                    }
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(readingMode == .scroll ? Color.accentColor : Color.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        readingMode == .scroll ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.15),
                        in: RoundedRectangle(cornerRadius: 10)
                    )
                }
            }
            .padding(.horizontal, 20)
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
