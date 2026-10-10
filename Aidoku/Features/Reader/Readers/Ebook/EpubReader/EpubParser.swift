//
//  EpubParser.swift
//  Aidoku
//
//  Created by Antigravity on 10/9/26.
//

import Foundation
import SwiftSoup
import UIKit
import ZIPFoundation

/// EPUB 单章节数据模型
struct EpubChapter: Identifiable, Equatable {
    let id: Int
    let title: String
    let href: String
    let htmlContent: String
    let plainTextContent: String

    var wordCount: Int {
        plainTextContent.count
    }
}

/// EPUB 标准目录项模型（支持 NCX / Nav XHTML）
struct EpubTocItem: Identifiable, Equatable {
    let id: Int
    let title: String
    let href: String
    var chapterIndex: Int
}

/// EPUB 电子书数据模型
struct EpubBook: Equatable {
    let title: String
    let author: String
    let coverImage: UIImage?
    let chapters: [EpubChapter]
    let tocItems: [EpubTocItem]
    let baseDirectory: URL?
}

/// 基于 ZIPFoundation 与 SwiftSoup 的轻量级 EPUB 解析器
final class EpubParser {
    enum ParserError: Error, LocalizedError {
        case fileNotFound
        case unarchiveFailed
        case containerNotFound
        case opfNotFound
        case emptyChapters

        var errorDescription: String? {
            switch self {
            case .fileNotFound:
                return "EPUB 文件未找到"
            case .unarchiveFailed:
                return "EPUB 解压解包失败"
            case .containerNotFound:
                return "未找到 META-INF/container.xml 结构清单"
            case .opfNotFound:
                return "未找到 OPF 书籍描述文件"
            case .emptyChapters:
                return "未解析到有效章节内容"
            }
        }
    }

    /// 解析指定 URL 的 EPUB 文件
    static func parse(url: URL) throws -> EpubBook {
        let fileManager = FileManager.default
        let extractDir = fileManager.temporaryDirectory.appendingPathComponent("epub_\(UUID().uuidString)")
        try fileManager.createDirectory(at: extractDir, withIntermediateDirectories: true)

        defer {
            // 解析完毕后若无需保留原始解压目录可做清理（或根据生命周期管理）
        }

        // 解压 EPUB 归档
        do {
            try fileManager.unzipItem(at: url, to: extractDir)
        } catch {
            throw ParserError.unarchiveFailed
        }

        // 1. 读取 META-INF/container.xml
        let containerUrl = extractDir.appendingPathComponent("META-INF/container.xml")
        guard fileManager.fileExists(atPath: containerUrl.path),
              let containerXml = try? String(contentsOf: containerUrl, encoding: .utf8) else {
            throw ParserError.containerNotFound
        }

        let containerDoc = try SwiftSoup.parse(containerXml, "", Parser.xmlParser())
        guard let rootfile = try containerDoc.select("rootfile").first() else {
            throw ParserError.opfNotFound
        }
        let opfRelativePath = try rootfile.attr("full-path")
        let opfUrl = extractDir.appendingPathComponent(opfRelativePath)
        guard fileManager.fileExists(atPath: opfUrl.path),
              let opfXml = try? String(contentsOf: opfUrl, encoding: .utf8) else {
            throw ParserError.opfNotFound
        }

        let opfDir = opfUrl.deletingLastPathComponent()
        let opfDoc = try SwiftSoup.parse(opfXml, "", Parser.xmlParser())

        // 2. 提取书籍元数据
        let title = (try? opfDoc.select("dc\\:title").text())
            ?? (try? opfDoc.select("title").text())
            ?? url.deletingPathExtension().lastPathComponent
        let author = (try? opfDoc.select("dc\\:creator").text())
            ?? (try? opfDoc.select("creator").text())
            ?? "未知作者"

        // 3. 解析 manifest 与多源深度封面提取
        var manifest: [String: String] = [:]
        var manifestTypes: [String: String] = [:]
        var coverHref: String?
        let items = try opfDoc.select("manifest > item")
        for item in items {
            let id = try item.attr("id")
            let href = try item.attr("href")
            let mediaType = try item.attr("media-type")
            let properties = try item.attr("properties")
            manifest[id] = href
            manifestTypes[id] = mediaType

            // 规则 A: EPUB 3 标准 properties="cover-image"
            if properties.contains("cover-image") {
                coverHref = href
            }
        }

        // 规则 B: EPUB 2 标准 <meta name="cover" content="item_id"/>
        if coverHref == nil {
            if let metaCover = try? opfDoc.select("metadata > meta[name=cover]").first(),
               let contentId = try? metaCover.attr("content"),
               let href = manifest[contentId] {
                coverHref = href
            }
        }

        // 规则 C: <guide><reference type="cover" href="..."/>
        if coverHref == nil {
            if let guideCover = try? opfDoc.select("guide > reference[type=cover]").first(),
               let href = try? guideCover.attr("href") {
                let cleanHref = href.components(separatedBy: "#").first ?? href
                let ext = (cleanHref as NSString).pathExtension.lowercased()
                if ["jpg", "jpeg", "png", "webp", "gif"].contains(ext) {
                    coverHref = cleanHref
                } else {
                    let coverHtmlUrl = opfDir.appendingPathComponent(cleanHref)
                    if let html = try? String(contentsOf: coverHtmlUrl, encoding: .utf8),
                       let doc = try? SwiftSoup.parse(html),
                       let img = try? doc.select("img, image").first() {
                        let src = (try? img.attr("src")) ?? (try? img.attr("xlink:href"))
                        if let src, !src.isEmpty {
                            coverHref = coverHtmlUrl.deletingLastPathComponent().appendingPathComponent(src).lastPathComponent
                        }
                    }
                }
            }
        }

        // 规则 D: Manifest 中带 "cover" 关键字的图片项
        if coverHref == nil {
            for (id, href) in manifest {
                let lowerId = id.lowercased()
                let lowerHref = href.lowercased()
                let mediaType = manifestTypes[id]?.lowercased() ?? ""
                if (lowerId.contains("cover") || lowerHref.contains("cover")) &&
                    (mediaType.hasPrefix("image/") || ["jpg", "jpeg", "png", "webp"].contains((href as NSString).pathExtension.lowercased())) {
                    coverHref = href
                    break
                }
            }
        }

        // 提取并加载封面图片数据
        var coverImage: UIImage?
        if let coverHref {
            let coverUrl = opfDir.appendingPathComponent(coverHref)
            if let data = try? Data(contentsOf: coverUrl) {
                coverImage = UIImage(data: data)
            }
        }

        // 规则 E: 若上述仍未找到封面，扫描首个章节文档中的第一张大图兜底
        if coverImage == nil {
            let firstItemrefs = try opfDoc.select("spine > itemref").prefix(2)
            for itemref in firstItemrefs {
                if let idref = try? itemref.attr("idref"),
                   let href = manifest[idref] {
                    let chapterUrl = opfDir.appendingPathComponent(href)
                    if let html = try? String(contentsOf: chapterUrl, encoding: .utf8),
                       let doc = try? SwiftSoup.parse(html),
                       let img = try? doc.select("img, image").first() {
                        let src = (try? img.attr("src")) ?? (try? img.attr("xlink:href"))
                        if let src, !src.isEmpty {
                            let imgUrl = chapterUrl.deletingLastPathComponent().appendingPathComponent(src)
                            if let data = try? Data(contentsOf: imgUrl), let imgData = UIImage(data: data) {
                                coverImage = imgData
                                break
                            }
                        }
                    }
                }
            }
        }

        // 规则 F: 彻底无图时，自动生成符合 HIG 极简质感封面
        if coverImage == nil {
            coverImage = EbookCoverGenerator.generate(title: title, author: author)
        }

        // 4. 解析 EPUB 2/3 标准目录 (NCX 与 Nav.xhtml)
        var navHref: String?
        var ncxHref: String?

        // 查找 EPUB 3 的 Nav 文档
        for (id, href) in manifest {
            let item = try? opfDoc.select("manifest > item[id='\(id)']").first()
            let properties = (try? item?.attr("properties")) ?? ""
            if properties.contains("nav") {
                navHref = href
                break
            }
        }

        // 查找 EPUB 2 的 NCX 文档
        if let spineTocId = try? opfDoc.select("spine").attr("toc"), !spineTocId.isEmpty {
            ncxHref = manifest[spineTocId]
        }
        if ncxHref == nil {
            for (_, href) in manifest {
                if href.lowercased().hasSuffix(".ncx") {
                    ncxHref = href
                    break
                }
            }
        }

        var tocItems: [EpubTocItem] = []
        var hrefToTitle: [String: String] = [:]

        // A. 尝试解析 EPUB 3 Nav XHTML
        if let navHref {
            let navUrl = opfDir.appendingPathComponent(navHref)
            if let navXml = try? String(contentsOf: navUrl, encoding: .utf8),
               let navDoc = try? SwiftSoup.parse(navXml),
               let navLinks = try? navDoc.select("nav[epub\\:type='toc'] a, nav#toc a, nav a") {
                var tocIndex = 0
                for a in navLinks {
                    let title = (try? a.text()) ?? ""
                    let href = (try? a.attr("href")) ?? ""
                    let cleanHref = href.components(separatedBy: "#").first ?? href
                    if !title.isEmpty && !cleanHref.isEmpty {
                        hrefToTitle[cleanHref] = title
                        tocItems.append(EpubTocItem(id: tocIndex, title: title, href: href, chapterIndex: 0))
                        tocIndex += 1
                    }
                }
            }
        }

        // B. 尝试解析 EPUB 2 NCX
        if tocItems.isEmpty, let ncxHref {
            let ncxUrl = opfDir.appendingPathComponent(ncxHref)
            if let ncxXml = try? String(contentsOf: ncxUrl, encoding: .utf8),
               let ncxDoc = try? SwiftSoup.parse(ncxXml, "", Parser.xmlParser()),
               let navPoints = try? ncxDoc.select("navPoint") {
                var tocIndex = 0
                for point in navPoints {
                    let title = (try? point.select("navLabel > text").text()) ?? ""
                    let src = (try? point.select("content").attr("src")) ?? ""
                    let cleanHref = src.components(separatedBy: "#").first ?? src
                    if !title.isEmpty && !cleanHref.isEmpty {
                        hrefToTitle[cleanHref] = title
                        tocItems.append(EpubTocItem(id: tocIndex, title: title, href: src, chapterIndex: 0))
                        tocIndex += 1
                    }
                }
            }
        }

        // 5. 解析 spine 章节阅读顺序
        var chapters: [EpubChapter] = []
        var hrefToChapterIndex: [String: Int] = [:]
        let itemrefs = try opfDoc.select("spine > itemref")
        var chapterIndex = 0

        for itemref in itemrefs {
            let idref = try itemref.attr("idref")
            guard let href = manifest[idref] else { continue }

            let chapterUrl = opfDir.appendingPathComponent(href)
            guard let chapterHtml = try? String(contentsOf: chapterUrl, encoding: .utf8) else { continue }

            let chapterDoc = try SwiftSoup.parse(chapterHtml)

            // 智能提取章节标题：优先匹配标准目录（NCX/Nav），其次匹配 h1..h3，最后兜底
            let cleanHref = href.components(separatedBy: "#").first ?? href
            let chapterTitle = hrefToTitle[cleanHref]
                ?? (try? chapterDoc.select("h1, h2, h3").first()?.text())
                ?? (try? chapterDoc.select("title").first()?.text())
                ?? "第 \(chapterIndex + 1) 章"

            let plainText = (try? chapterDoc.body()?.text()) ?? ""
            if plainText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                continue
            }

            chapters.append(
                EpubChapter(
                    id: chapterIndex,
                    title: chapterTitle,
                    href: href,
                    htmlContent: chapterHtml,
                    plainTextContent: plainText
                )
            )
            hrefToChapterIndex[cleanHref] = chapterIndex
            chapterIndex += 1
        }

        guard !chapters.isEmpty else {
            throw ParserError.emptyChapters
        }

        // 将 TOC 目录项精准关联到章节索引
        var resolvedTocItems: [EpubTocItem] = []
        for var item in tocItems {
            let clean = item.href.components(separatedBy: "#").first ?? item.href
            if let mappedIndex = hrefToChapterIndex[clean] {
                item.chapterIndex = mappedIndex
                resolvedTocItems.append(item)
            }
        }
        if resolvedTocItems.isEmpty {
            resolvedTocItems = chapters.map {
                EpubTocItem(id: $0.id, title: $0.title, href: $0.href, chapterIndex: $0.id)
            }
        }

        return EpubBook(
            title: title,
            author: author,
            coverImage: coverImage,
            chapters: chapters,
            tocItems: resolvedTocItems,
            baseDirectory: opfDir
        )
    }
}
