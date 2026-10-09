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

/// EPUB 电子书数据模型
struct EpubBook: Equatable {
    let title: String
    let author: String
    let coverImage: UIImage?
    let chapters: [EpubChapter]
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

        // 3. 解析 manifest (id -> href)
        var manifest: [String: String] = [:]
        var coverHref: String?
        let items = try opfDoc.select("manifest > item")
        for item in items {
            let id = try item.attr("id")
            let href = try item.attr("href")
            let properties = try item.attr("properties")
            manifest[id] = href

            if properties.contains("cover-image") || id.lowercased().contains("cover") {
                coverHref = href
            }
        }

        // 提取封面图片
        var coverImage: UIImage?
        if let coverHref {
            let coverUrl = opfDir.appendingPathComponent(coverHref)
            if let data = try? Data(contentsOf: coverUrl) {
                coverImage = UIImage(data: data)
            }
        }

        // 4. 解析 spine 章节阅读顺序
        var chapters: [EpubChapter] = []
        let itemrefs = try opfDoc.select("spine > itemref")
        var chapterIndex = 0

        for itemref in itemrefs {
            let idref = try itemref.attr("idref")
            guard let href = manifest[idref] else { continue }

            let chapterUrl = opfDir.appendingPathComponent(href)
            guard let chapterHtml = try? String(contentsOf: chapterUrl, encoding: .utf8) else { continue }

            let chapterDoc = try SwiftSoup.parse(chapterHtml)

            // 智能提取章节标题
            let chapterTitle = (try? chapterDoc.select("h1, h2, h3").first()?.text())
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
            chapterIndex += 1
        }

        guard !chapters.isEmpty else {
            throw ParserError.emptyChapters
        }

        return EpubBook(
            title: title,
            author: author,
            coverImage: coverImage,
            chapters: chapters,
            baseDirectory: opfDir
        )
    }
}
