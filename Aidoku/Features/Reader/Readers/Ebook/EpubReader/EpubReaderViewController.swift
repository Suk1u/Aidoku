//
//  EpubReaderViewController.swift
//  Aidoku
//
//  Created by Antigravity on 10/9/26.
//

import AidokuRunner
import SwiftUI
import UIKit

final class EpubReaderViewController: UIViewController, ReaderReaderDelegate {
    let source: AidokuRunner.Source?
    let manga: AidokuRunner.Manga
    var chapter: AidokuRunner.Chapter

    var readingMode: ReadingMode = .ebookPaged
    weak var delegate: ReaderHoldingDelegate?

    private var parsedBook: EpubBook?
    private var hostingController: UIHostingController<EpubReaderView>?

    init(source: AidokuRunner.Source?, manga: AidokuRunner.Manga, chapter: AidokuRunner.Chapter) {
        self.source = source
        self.manga = manga
        self.chapter = chapter
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = ReaderTextTheme.getCurrentBackground()
        loadEpubContent()
    }

    private func loadEpubContent() {
        var book: EpubBook?

        if let fileURL = resolveLocalFileURL(extension: "epub") {
            book = try? EpubParser.parse(url: fileURL)
        }

        // 默认章节结构保底
        let finalBook: EpubBook
        if let book {
            finalBook = book
        } else {
            let defaultTitle = chapter.title ?? manga.title
            let placeholderHtml = """
            <h2>\(defaultTitle)</h2>
            <p>正在加载 EPUB 电子书内容...</p>
            <p>本模块支持排版样式呈现、自适应图文混排及目录快速跳转。点击屏幕两侧可切换章节与翻页，点击屏幕中部可呼出工具栏进行阅读模式切换。</p>
            """
            let defaultChapter = EpubChapter(
                id: 0,
                title: defaultTitle,
                href: "chapter_0.xhtml",
                htmlContent: placeholderHtml,
                plainTextContent: "正在加载 EPUB 电子书内容..."
            )
            finalBook = EpubBook(
                title: manga.title,
                author: manga.authors?.joined(separator: ", ") ?? "作者",
                coverImage: nil,
                chapters: [defaultChapter],
                tocItems: [EpubTocItem(id: 0, title: defaultTitle, href: "chapter_0.xhtml", chapterIndex: 0)],
                baseDirectory: nil
            )
        }

        self.parsedBook = finalBook

        let rootView = EpubReaderView(book: finalBook, currentChapterIndex: 0)
        let hosting = UIHostingController(rootView: rootView)
        hostingController = hosting

        addChild(hosting)
        hosting.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(hosting.view)
        NSLayoutConstraint.activate([
            hosting.view.topAnchor.constraint(equalTo: view.topAnchor),
            hosting.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hosting.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hosting.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        hosting.didMove(toParent: self)
    }

    // MARK: - ReaderReaderDelegate
    func moveLeft() {}
    func moveRight() {}
    func sliderMoved(value: CGFloat) {}
    func sliderStopped(value: CGFloat) {}

    func setChapter(_ chapter: AidokuRunner.Chapter, startPage: Int) {
        self.chapter = chapter
        loadEpubContent()
    }

    private func resolveLocalFileURL(extension expectedExt: String) -> URL? {
        // 1. Direct chapter.url
        if let url = chapter.url, FileManager.default.fileExists(atPath: url.path) {
            return url
        }
        // 2. Direct manga.url
        if let url = manga.url, FileManager.default.fileExists(atPath: url.path) {
            return url
        }
        // 3. Documents/Local/<manga.key>/<chapter.key>
        let documentsDir = FileManager.default.documentDirectory
        let directChapterURL = documentsDir
            .appendingPathComponent("Local")
            .appendingPathComponent(manga.key)
            .appendingPathComponent(chapter.key)
        if FileManager.default.fileExists(atPath: directChapterURL.path) {
            return directChapterURL
        }
        // 4. Scan folder Documents/Local/<manga.key> for matching extension
        let mangaFolder = documentsDir
            .appendingPathComponent("Local")
            .appendingPathComponent(manga.key)
        if let items = try? FileManager.default.contentsOfDirectory(atPath: mangaFolder.path) {
            for item in items {
                if item.lowercased().hasSuffix(".\(expectedExt)") {
                    let fileURL = mangaFolder.appendingPathComponent(item)
                    if FileManager.default.fileExists(atPath: fileURL.path) {
                        return fileURL
                    }
                }
            }
        }
        return nil
    }
}
