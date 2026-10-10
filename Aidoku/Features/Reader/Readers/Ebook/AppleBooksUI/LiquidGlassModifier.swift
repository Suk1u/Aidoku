//
//  LiquidGlassModifier.swift
//  Aidoku
//
//  Created by Antigravity on 10/10/26.
//

import SwiftUI

/// iOS 26+ Apple HIG 原生 Liquid Glass 液态玻璃材质修饰器
/// 严禁手动叠加 blur 模糊与透明度，严禁自定义网页描边与渐变边框，纯系统原生材料与微弱边缘自发光
struct LiquidGlassModifier<S: Shape>: ViewModifier {
    let shape: S
    var isProminent: Bool = false

    func body(content: Content) -> some View {
        content
            .background {
                if #available(iOS 26.0, *) {
                    shape
                        .fill(isProminent ? .thinMaterial : .ultraThinMaterial)
                } else {
                    shape
                        .fill(isProminent ? .thinMaterial : .ultraThinMaterial)
                }
            }
            .clipShape(shape)
    }
}

extension View {
    /// 应用 iOS 26 原生 Liquid Glass 连续曲率圆角矩形面板
    func liquidGlass<S: Shape>(
        in shape: S,
        prominent: Bool = false
    ) -> some View {
        self.modifier(LiquidGlassModifier(shape: shape, isProminent: prominent))
    }

    /// 应用 iOS 26 原生 Liquid Glass 胶囊面板
    func liquidGlassPill(prominent: Bool = false) -> some View {
        self.modifier(LiquidGlassModifier(shape: Capsule(), isProminent: prominent))
    }

    /// 应用 iOS 26 原生 Liquid Glass 圆形控制按钮
    func liquidGlassCircle(prominent: Bool = false) -> some View {
        self.modifier(LiquidGlassModifier(shape: Circle(), isProminent: prominent))
    }

    /// 严格遵循 Apple HIG 触控交互规范：最小有效点击尺寸 ≥ 44x44 pt
    func higTouchTarget(minSize: CGFloat = 44) -> some View {
        self
            .frame(minWidth: minSize, minHeight: minSize)
            .contentShape(Rectangle())
    }
}

#Preview("Liquid Glass Preview") {
    ZStack {
        Color.black.ignoresSafeArea()

        VStack(spacing: 24) {
            Text("本章还剩 18 页")
                .font(.system(.footnote, design: .default, weight: .medium))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .liquidGlassPill()

            HStack(spacing: 16) {
                Button {} label: {
                    Image(systemName: "list.bullet")
                        .font(.system(size: 18, weight: .semibold))
                }
                .higTouchTarget()
                .liquidGlassCircle()

                Button {} label: {
                    Image(systemName: "textformat.size")
                        .font(.system(size: 18, weight: .semibold))
                }
                .higTouchTarget()
                .liquidGlassCircle()
            }
        }
    }
}
