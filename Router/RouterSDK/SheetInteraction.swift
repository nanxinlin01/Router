//
//  SheetInteraction.swift
//  Router
//

import SwiftUI
import Combine
import UIKit

// MARK: - SheetInteraction

/// Sheet 拖拽交互状态（UIKit Pan ↔ SwiftUI 桥接）
final class SheetInteraction: ObservableObject {
    /// 当前拖拽偏移量（UIKit Pan 写入，SwiftUI 读取）
    @Published var dragOffset: CGFloat = 0
    /// 拖拽结束事件（translation, velocity）
    let dragEnded = PassthroughSubject<(CGFloat, CGFloat), Never>()
    /// 当前 sheet 可见高度（供 UIKit 手势判断指示条区域）
    var currentSheetHeight: CGFloat = 0
    /// 当前停靠档位索引（SwiftUI 写入，UIKit 读取）
    var currentDetentIndex: Int = 0
    /// 档位总数
    var detentCount: Int = 1
}

// MARK: - SheetPanHandler

/// UIKit Pan 手势处理器：仅从左侧边缘 + 指示条区域触发，不拦截内容区域（下拉刷新等正常工作）
final class SheetPanHandler: NSObject, UIGestureRecognizerDelegate {
    weak var panGesture: UIPanGestureRecognizer?
    weak var interaction: SheetInteraction?
    var dismissOnDragDown: Bool = true
    /// 拖拽指示条触摸区域高度
    var indicatorHeight: CGFloat = 40
    /// 左侧边缘触发宽度
    var leftEdgeWidth: CGFloat = 44

    /// 手势是否从左侧边缘开始（斜划时水平分量也贡献偏移）
    private var startedFromEdge = false

    /// 添加 pan 手势到指定视图
    func attach(to view: UIView) {
        guard panGesture == nil else { return }
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        pan.delegate = self
        view.addGestureRecognizer(pan)
        self.panGesture = pan
    }

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard let view = gesture.view else { return }
        switch gesture.state {
        case .began:
            let loc = gesture.location(in: view)
            startedFromEdge = loc.x <= leftEdgeWidth
        case .changed:
            let t = gesture.translation(in: view)
            // 左边缘斜划时：水平分量也贡献一半偏移，让对角线手势更灵敏
            let effective = startedFromEdge ? t.y + abs(t.x) * 0.5 : t.y
            interaction?.dragOffset = effective
        case .ended, .cancelled:
            let t = gesture.translation(in: view)
            let v = gesture.velocity(in: view)
            let effectiveT = startedFromEdge ? t.y + abs(t.x) * 0.5 : t.y
            let effectiveV = startedFromEdge ? v.y + abs(v.x) * 0.3 : v.y
            interaction?.dragEnded.send((effectiveT, effectiveV))
            startedFromEdge = false
        default:
            break
        }
    }

    // MARK: - UIGestureRecognizerDelegate

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let pan = gestureRecognizer as? UIPanGestureRecognizer,
              let view = pan.view else { return false }

        let location = pan.location(in: view)
        let sheetHeight = interaction?.currentSheetHeight ?? 0
        let sheetVisibleTop = view.bounds.height - sheetHeight

        // 触摸必须在 sheet 可见区域内
        guard location.y >= sheetVisibleTop else { return false }

        // 1. 指示条区域：允许任意垂直方向拖拽
        let isInIndicator = location.y < sheetVisibleTop + indicatorHeight
        if isInIndicator {
            let velocity = pan.velocity(in: view)
            return abs(velocity.y) > abs(velocity.x)
        }

        // 2. 左侧边缘区域：只要触摸在边缘就允许，不检查方向
        if location.x <= leftEdgeWidth {
            // 导航栏有 push 页面时，优先让导航返回（pop），不拦截
            if Self.hasNavDepth(in: view) {
                return false
            }
            let detentIndex = interaction?.currentDetentIndex ?? 0
            let detentCount = interaction?.detentCount ?? 1
            return dismissOnDragDown || detentIndex > 0
                || (detentCount > 1 && detentIndex < detentCount - 1)
        }

        // 3. 其它区域（内容区域）：不拦截
        return false
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
        return false
    }

    /// 让其它手势（如 ScrollView pan）等待我们的手势失败后才激活
    /// 但不拦截导航返回手势（UIScreenEdgePanGestureRecognizer）
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        // 导航返回的边缘手势不要拦截
        if otherGestureRecognizer is UIScreenEdgePanGestureRecognizer {
            return false
        }
        return otherGestureRecognizer is UIPanGestureRecognizer
    }

    // MARK: - Helpers

    /// 检查视图层级中是否存在有 push 页面的 UINavigationController
    static func hasNavDepth(in view: UIView) -> Bool {
        // 向上查找 UINavigationController
        var responder: UIResponder? = view
        while let r = responder {
            if let nav = r as? UINavigationController, nav.viewControllers.count > 1 {
                return true
            }
            responder = r.next
        }
        // 向下查找
        return findNavigationController(in: view)?.viewControllers.count ?? 0 > 1
    }

    private static func findNavigationController(in view: UIView) -> UINavigationController? {
        for child in view.subviews {
            if let nav = child.next as? UINavigationController, nav.viewControllers.count > 1 {
                return nav
            }
            if let found = findNavigationController(in: child) {
                return found
            }
        }
        return nil
    }
}
