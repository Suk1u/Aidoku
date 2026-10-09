//
//  TxtReaderViewController.swift
//  Aidoku
//
//  Created by Antigravity on 10/9/26.
//

import AidokuRunner
import SwiftUI
import UIKit

final class TxtReaderViewController: UIViewController, ReaderReaderDelegate {
    let source: AidokuRunner.Source?
    let manga: AidokuRunner.Manga
    var chapter: AidokuRunner.Chapter

    var readingMode: ReadingMode = .ebookPaged
    weak var delegate: ReaderHoldingDelegate?

    private var chapters: [TxtChapter] = []
    private var hostingController: UIHostingController<TxtReaderView>?

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
        loadTextContent()
    }

    private func loadTextContent() {
        // 尝试从章节本地文件或 URL 读取
        var parsedChapters: [TxtChapter] = []

        if let url = chapter.url ?? manga.url {
            if FileManager.default.fileExists(atPath: url.path) {
                parsedChapters = TxtParser.parse(url: url)
            }
        }

        // 若无现成文件，提供默认章节占位
        if parsedChapters.isEmpty {
            let title = chapter.title ?? manga.title
            let sampleContent = """
            \(title)

            欢迎使用 Aidoku 电子书阅读器。
            本章节文本内容正在载入中，您可通过工具栏切换左右翻页与连续滚动模式，亦可在设置中个性化定制字号、行距与纸张配色主题。
            """
            parsedChapters = [TxtChapter(id: 0, title: title, content: sampleContent)]
        }

        self.chapters = parsedChapters

        let rootView = TxtReaderView(chapters: parsedChapters, currentChapterIndex: 0)
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
        loadTextContent()
    }
}
