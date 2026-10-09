//
//  BookType.swift
//  Aidoku
//
//  Created by Antigravity on 10/9/26.
//

import Foundation
import AidokuRunner

/// 书籍类型枚举：区分漫画与电子书（EPUB、TXT等流式文本格式）
enum BookType: String, Codable, CaseIterable {
    case manga = "manga"
    case epub = "epub"
    case txt = "txt"

    var isEbook: Bool {
        self == .epub || self == .txt
    }

    var displayName: String {
        switch self {
        case .manga:
            return "漫画"
        case .epub:
            return "EPUB 电子书"
        case .txt:
            return "TXT 纯文本"
        }
    }

    /// 根据 URL/路径后缀智能判定书籍类型
    static func detect(url: URL?) -> BookType {
        guard let url else { return .manga }
        let ext = url.pathExtension.lowercased()
        if ext == "epub" {
            return .epub
        } else if ext == "txt" || ext == "text" {
            return .txt
        }
        return .manga
    }

    /// 根据标题、章节或键值智能判定书籍类型
    static func detect(title: String?, key: String?) -> BookType {
        let text = "\(title ?? "") \(key ?? "")".lowercased()
        if text.hasSuffix(".epub") || text.contains(".epub ") || text.contains(".epub") {
            return .epub
        } else if text.hasSuffix(".txt") || text.contains(".txt ") || text.contains(".txt") {
            return .txt
        }
        return .manga
    }
}

/// 电子书阅读模式枚举（翻页模式 / 连续垂直滚动模式）
enum EbookReadingMode: String, Codable, CaseIterable {
    case paged = "paged"
    case scroll = "scroll"

    var title: String {
        switch self {
        case .paged:
            return "左右翻页"
        case .scroll:
            return "连续滚动"
        }
    }
}

extension AidokuRunner.Manga {
    var bookType: BookType {
        if let url = self.url {
            let detected = BookType.detect(url: url)
            if detected != .manga {
                return detected
            }
        }
        return BookType.detect(title: title, key: key)
    }

    var isEbook: Bool {
        bookType.isEbook
    }
}
