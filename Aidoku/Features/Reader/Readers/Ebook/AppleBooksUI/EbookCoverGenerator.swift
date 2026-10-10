//
//  EbookCoverGenerator.swift
//  Aidoku
//
//  Created by Antigravity on 10/10/26.
//

import UIKit

/// 电子书封面生成器：遵循 Apple HIG 极简质感设计规范
/// 为 TXT 小说或缺少封面的 EPUB 自动生成高精度质感书封
final class EbookCoverGenerator {
    /// 为电子书生成符合 HIG 原生深色调质感封面
    static func generate(
        title: String,
        author: String? = nil,
        size: CGSize = CGSize(width: 600, height: 900)
    ) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let cgContext = ctx.cgContext

            // 1. 深色极简背景渐变
            let colors = [
                UIColor(red: 28/255, green: 28/255, blue: 32/255, alpha: 1).cgColor,
                UIColor(red: 16/255, green: 16/255, blue: 18/255, alpha: 1).cgColor
            ] as CFArray
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            if let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: [0.0, 1.0]) {
                cgContext.drawLinearGradient(
                    gradient,
                    start: .zero,
                    end: CGPoint(x: 0, y: size.height),
                    options: []
                )
            }

            // 2. 书脊立体边缘微光
            let spineWidth: CGFloat = 16
            let spineRect = CGRect(x: 0, y: 0, width: spineWidth, height: size.height)
            UIColor.white.withAlphaComponent(0.05).setFill()
            UIRectFillUsingBlendMode(spineRect, .sourceOver)

            let spineLine = CGRect(x: spineWidth, y: 0, width: 1.5, height: size.height)
            UIColor.black.withAlphaComponent(0.4).setFill()
            UIRectFill(spineLine)

            // 3. 内部优雅圆角边框细线
            let inset: CGFloat = 36
            let borderRect = CGRect(x: inset, y: inset, width: size.width - inset * 2, height: size.height - inset * 2)
            let borderPath = UIBezierPath(roundedRect: borderRect, cornerRadius: 10)
            borderPath.lineWidth = 1.0
            UIColor.white.withAlphaComponent(0.12).setStroke()
            borderPath.stroke()

            // 4. 书名排版
            let displayTitle = title.isEmpty ? "文学作品" : title
            let titleFont = UIFont.systemFont(ofSize: 38, weight: .bold)
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .center
            paragraphStyle.lineSpacing = 8

            let titleAttrs: [NSAttributedString.Key: Any] = [
                .font: titleFont,
                .foregroundColor: UIColor.white.withAlphaComponent(0.92),
                .paragraphStyle: paragraphStyle
            ]

            let titleRect = CGRect(
                x: inset + 24,
                y: size.height * 0.30,
                width: size.width - (inset + 24) * 2,
                height: 220
            )
            (displayTitle as NSString).draw(in: titleRect, withAttributes: titleAttrs)

            // 5. 作者名称
            let displayAuthor = author?.isEmpty == false ? author! : "精选读本"
            let authorFont = UIFont.systemFont(ofSize: 20, weight: .medium)
            let authorAttrs: [NSAttributedString.Key: Any] = [
                .font: authorFont,
                .foregroundColor: UIColor.white.withAlphaComponent(0.50),
                .paragraphStyle: paragraphStyle
            ]
            let authorRect = CGRect(
                x: inset + 24,
                y: size.height * 0.62,
                width: size.width - (inset + 24) * 2,
                height: 48
            )
            (displayAuthor as NSString).draw(in: authorRect, withAttributes: authorAttrs)

            // 6. 底部质感徽章
            let footerAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 13, weight: .semibold),
                .foregroundColor: UIColor.white.withAlphaComponent(0.30),
                .paragraphStyle: paragraphStyle,
                .kern: 4
            ]
            let footerRect = CGRect(
                x: inset,
                y: size.height - inset - 32,
                width: size.width - inset * 2,
                height: 24
            )
            ("ELECTRONIC EDITION" as NSString).draw(in: footerRect, withAttributes: footerAttrs)
        }
    }
}
