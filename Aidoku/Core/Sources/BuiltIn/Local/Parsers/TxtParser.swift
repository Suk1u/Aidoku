//
//  TxtParser.swift
//  Aidoku
//
//  Created by Antigravity on 10/9/26.
//

import Foundation

/// TXT 电子书章节数据模型
struct TxtChapter: Identifiable, Equatable {
    let id: Int
    let title: String
    let content: String

    var wordCount: Int {
        content.count
    }
}

/// TXT 文本智能解析器
final class TxtParser {
    /// 常用中文及英文小说章节标题匹配正则
    private static let chapterRegexPattern =
        #"^\s*(第[0-9一二三四五六七八九十百千万]+[章回节卷集部篇话]|Chapter\s+[0-9]+|Section\s+[0-9]+|[0-9]{1,4}\s+).*$"#

    /// 从文件 URL 读取并智能解析编码
    static func parse(url: URL) -> [TxtChapter] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        return parse(data: data)
    }

    /// 从原始 Data 自动探测编码解析
    static func parse(data: Data) -> [TxtChapter] {
        // 尝试常用编码顺序：UTF-8 -> GB18030/GBK -> UTF-16
        var text: String?
        if let utf8 = String(data: data, encoding: .utf8) {
            text = utf8
        } else {
            // GB18030 兼容 GBK 和 GB2312
            let cfGB18030 = CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)
            let nsGB18030 = CFStringConvertEncodingToNSStringEncoding(cfGB18030)
            if let gbk = String(data: data, encoding: String.Encoding(rawValue: nsGB18030)) {
                text = gbk
            } else if let utf16 = String(data: data, encoding: .utf16) {
                text = utf16
            } else {
                text = String(decoding: data, as: UTF8.self)
            }
        }

        guard let validText = text, !validText.isEmpty else { return [] }
        return parse(text: validText)
    }

    /// 解析完整文本内容
    static func parse(text: String) -> [TxtChapter] {
        let lines = text.components(separatedBy: .newlines)
        guard let regex = try? NSRegularExpression(pattern: chapterRegexPattern, options: [.caseInsensitive]) else {
            return [TxtChapter(id: 0, title: "正文", content: text)]
        }

        var chapters: [TxtChapter] = []
        var currentTitle = "序言"
        var currentBodyLines: [String] = []
        var chapterIndex = 0

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let isChapterTitle: Bool
            if trimmed.count <= 60 && !trimmed.isEmpty {
                let range = NSRange(location: 0, length: (line as NSString).length)
                isChapterTitle = regex.firstMatch(in: line, options: [], range: range) != nil
            } else {
                isChapterTitle = false
            }

            if isChapterTitle {
                let body = currentBodyLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
                if !body.isEmpty || !chapters.isEmpty {
                    chapters.append(TxtChapter(id: chapterIndex, title: currentTitle, content: body))
                    chapterIndex += 1
                }
                currentTitle = trimmed
                currentBodyLines = []
            } else {
                currentBodyLines.append(line)
            }
        }

        // 添加末尾章节
        let finalBody = currentBodyLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        if !finalBody.isEmpty || chapters.isEmpty {
            chapters.append(TxtChapter(id: chapterIndex, title: currentTitle, content: finalBody))
        }

        return chapters
    }

    /// 根据字符数与行预算将长章节内容分页
    static func paginate(content: String, charsPerPage: Int = 800) -> [String] {
        guard charsPerPage > 0 else { return [content] }
        var pages: [String] = []
        var current = ""
        let paragraphs = content.components(separatedBy: "\n")

        for p in paragraphs {
            let paragraph = p.trimmingCharacters(in: .whitespaces)
            if paragraph.isEmpty { continue }

            if current.count + paragraph.count > charsPerPage && !current.isEmpty {
                pages.append(current.trimmingCharacters(in: .whitespacesAndNewlines))
                current = ""
            }

            if paragraph.count > charsPerPage {
                // 单段超长切割
                var str = paragraph
                while !str.isEmpty {
                    let take = min(charsPerPage, str.count)
                    let index = str.index(str.startIndex, offsetBy: take)
                    pages.append(String(str[..<index]))
                    str = String(str[index...])
                }
            } else {
                current += "    " + paragraph + "\n\n"
            }
        }

        if !current.isEmpty {
            pages.append(current.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        return pages.isEmpty ? [content] : pages
    }
}
