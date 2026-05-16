//
//  RouteTransitions.swift
//  Router
//

import SwiftUI

// MARK: - RoutePresentation

/// 统一路由呈现信息（枚举路由和注册路由共用）
struct RoutePresentation: Identifiable {
    let id = UUID()
    let view: AnyView
    /// 裸视图（不含 NavigationStack），用于 WindowSheet fitContent 测量
    var rawView: AnyView?
    var sheetConfig: SheetConfig = .init()
    var windowSheetConfig: WindowSheetConfig = .init()
    var windowToastConfig: WindowToastConfig = .init()
}

// MARK: - PushConfig

/// Push 转场配置
struct PushConfig {
    /// 是否隐藏 TabBar
    var hidesTabBar: Bool

    init(hidesTabBar: Bool = false) {
        self.hidesTabBar = hidesTabBar
    }
}

// MARK: - RouteTransition

/// 路由转场方式
enum RouteTransition {
    case push(PushConfig = .init())
    case sheet(SheetConfig = .init())
    case fullScreenCover
    case alert(AlertConfig)
    case windowSheet(WindowSheetConfig = .init())
    case windowPush
    case windowAlert
    case windowToast(WindowToastConfig = .init())
    case windowFade
}

// MARK: - SheetConfig

/// 原生 Sheet 配置（控制高度档位、拖拽指示条等）
struct SheetConfig {
    /// 高度档位（默认 .large）
    var detents: Set<PresentationDetent>
    /// 是否显示拖拽指示条
    var showDragIndicator: Bool

    init(
        detents: Set<PresentationDetent> = [.large],
        showDragIndicator: Bool = false
    ) {
        self.detents = detents
        self.showDragIndicator = showDragIndicator
    }

    /// 便捷初始化：单个档位
    init(detent: PresentationDetent, showDragIndicator: Bool = false) {
        self.detents = [detent]
        self.showDragIndicator = showDragIndicator
    }
}

// MARK: - AlertConfig

/// Alert 配置
struct AlertConfig: Identifiable {
    let id = UUID()
    let alert: () -> Alert

    init(_ alert: @escaping () -> Alert) {
        self.alert = alert
    }
}

// MARK: - WindowToastPosition

/// Toast 显示位置
enum WindowToastPosition {
    case top
    case bottom
}

// MARK: - WindowToastConfig

/// WindowToast 配置
struct WindowToastConfig {
    /// 显示位置
    var position: WindowToastPosition
    /// 自动消失时长（秒），nil 表示不自动消失
    var duration: TimeInterval?
    /// 是否点击 Toast 关闭
    var dismissOnTap: Bool
    /// 是否显示背景遮罩
    var showDimming: Bool
    /// 背景遮罩透明度
    var backgroundOpacity: CGFloat

    init(
        position: WindowToastPosition = .top,
        duration: TimeInterval? = 3.0,
        dismissOnTap: Bool = true,
        showDimming: Bool = false,
        backgroundOpacity: CGFloat = 0.15
    ) {
        self.position = position
        self.duration = duration
        self.dismissOnTap = dismissOnTap
        self.showDimming = showDimming
        self.backgroundOpacity = backgroundOpacity
    }
}

// MARK: - WindowSheetDetent

/// WindowSheet 高度模式
enum WindowSheetDetent: Equatable {
    /// 全屏
    case fullScreen
    /// 大（~92% 屏幕高度）
    case large
    /// 半屏（50%）
    case half
    /// 自定义百分比（0~1）
    case percentage(CGFloat)
    /// 固定高度（pt）
    case fixedHeight(CGFloat)
    /// 自适应内容高度
    case fitContent
}

// MARK: - WindowSheetConfig

/// WindowSheet 配置
struct WindowSheetConfig {
    /// 可停靠的高度位置（支持多个，拖拽可在不同位置间切换；按高度升序排列）
    var detents: [WindowSheetDetent]
    /// 初始停靠位置索引（排序后的 detents 索引，默认 0 即最小高度）
    var initialDetentIndex: Int?
    /// 圆角半径
    var cornerRadius: CGFloat
    /// 背景遮罩透明度
    var backgroundOpacity: CGFloat
    /// 是否显示拖拽指示条
    var showDragIndicator: Bool
    /// 是否支持下滑关闭
    var dismissOnDragDown: Bool
    /// 内容背景色（用于全屏时顶部安全区填充）
    var contentBackgroundColor: Color
    /// 是否在接近顶部时自动添加安全区 padding（false 则忽略顶部安全区）
    var respectsTopSafeArea: Bool

    init(
        detents: [WindowSheetDetent] = [.large],
        initialDetentIndex: Int? = nil,
        cornerRadius: CGFloat = 12,
        backgroundOpacity: CGFloat = 0.3,
        showDragIndicator: Bool = true,
        dismissOnDragDown: Bool = true,
        contentBackgroundColor: Color = Color(.systemGroupedBackground),
        respectsTopSafeArea: Bool = true
    ) {
        self.detents = detents.isEmpty ? [.large] : detents
        self.initialDetentIndex = initialDetentIndex
        self.cornerRadius = cornerRadius
        self.backgroundOpacity = backgroundOpacity
        self.showDragIndicator = showDragIndicator
        self.dismissOnDragDown = dismissOnDragDown
        self.contentBackgroundColor = contentBackgroundColor
        self.respectsTopSafeArea = respectsTopSafeArea
    }

    /// 单个 detent 便捷初始化
    init(
        detent: WindowSheetDetent,
        cornerRadius: CGFloat = 12,
        backgroundOpacity: CGFloat = 0.3,
        showDragIndicator: Bool = true,
        dismissOnDragDown: Bool = true,
        contentBackgroundColor: Color = Color(.systemGroupedBackground),
        respectsTopSafeArea: Bool = true
    ) {
        self.init(
            detents: [detent],
            cornerRadius: cornerRadius,
            backgroundOpacity: backgroundOpacity,
            showDragIndicator: showDragIndicator,
            dismissOnDragDown: dismissOnDragDown,
            contentBackgroundColor: contentBackgroundColor,
            respectsTopSafeArea: respectsTopSafeArea
        )
    }
}
