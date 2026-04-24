//
//  Router.swift
//  Router
//

import SwiftUI
import Combine
import UIKit

// MARK: - Routable Protocol

/// 路由目标协议：所有可路由页面必须遵循此协议
protocol Routable: Hashable, Identifiable {
    /// 纯视图（不包含 RootRouter）
    var view: AnyView { get }
}

extension Routable {
    var id: Self { self }
}

// MARK: - RouteTransition

/// 路由转场方式
enum RouteTransition {
    case push
    case sheet
    case fullScreenCover
    case alert(AlertConfig)
    case windowSheet(WindowSheetConfig = .init())
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

    init(
        detents: [WindowSheetDetent] = [.large],
        initialDetentIndex: Int? = nil,
        cornerRadius: CGFloat = 12,
        backgroundOpacity: CGFloat = 0.3,
        showDragIndicator: Bool = true,
        dismissOnDragDown: Bool = true
    ) {
        self.detents = detents.isEmpty ? [.large] : detents
        self.initialDetentIndex = initialDetentIndex
        self.cornerRadius = cornerRadius
        self.backgroundOpacity = backgroundOpacity
        self.showDragIndicator = showDragIndicator
        self.dismissOnDragDown = dismissOnDragDown
    }

    /// 单个 detent 便捷初始化
    init(
        detent: WindowSheetDetent,
        cornerRadius: CGFloat = 12,
        backgroundOpacity: CGFloat = 0.3,
        showDragIndicator: Bool = true,
        dismissOnDragDown: Bool = true
    ) {
        self.init(
            detents: [detent],
            cornerRadius: cornerRadius,
            backgroundOpacity: backgroundOpacity,
            showDragIndicator: showDragIndicator,
            dismissOnDragDown: dismissOnDragDown
        )
    }
}

// MARK: - Router

/// 泛型路由管理器,统一管理 Push/Sheet/FullScreenCover/Alert/WindowSheet
final class Router<Destination: Routable>: ObservableObject {

    // MARK: - Navigation State

    /// NavigationStack 路径
    @Published var path = NavigationPath()

    /// 路由栈记录（用于 dismiss(to:) 查找）
    private var pathStack: [Destination] = []

    /// Sheet 展示的目标
    @Published var sheet: Destination?

    /// FullScreenCover 展示的目标
    @Published var fullScreenCover: Destination?

    /// Alert 配置
    @Published var alertConfig: AlertConfig?

    /// WindowSheet 展示的目标
    @Published var windowSheet: Destination?

    /// WindowSheet 配置（present 时赋值）
    var windowSheetConfig: WindowSheetConfig = .init()

    /// 父级 dismiss 链（用于跨模态层级传递）
    var parentDismiss: ((Int) -> Void)?
    /// 父级 dismiss(to:) 链
    var parentDismissTo: ((Destination) -> Void)?

    // MARK: - Navigate

    /// 导航到指定目标
    func present(to destination: Destination, via transition: RouteTransition = .push) {
        switch transition {
        case .push:
            path.append(destination)
            pathStack.append(destination)
        case .sheet:
            sheet = destination
        case .fullScreenCover:
            fullScreenCover = destination
        case .alert(let config):
            alertConfig = config
        case .windowSheet(let config):
            windowSheetConfig = config
            windowSheet = destination
        }
    }

    // MARK: - Dismiss

    /// 返回指定层数（每个 transition 计 1 层，超出当前 Router 层级自动传递给父级）
    func dismiss(_ count: Int = 1) {
        var remaining = count
        // 1. 关 alert
        if remaining > 0, alertConfig != nil {
            alertConfig = nil
            remaining -= 1
        }
        // 2. pop 导航栈（每个计 1 层）
        let popCount = min(remaining, path.count)
        if popCount > 0 {
            path.removeLast(popCount)
            pathStack.removeLast(popCount)
            remaining -= popCount
        }
        // 3. 关 sheet
        if remaining > 0, sheet != nil {
            sheet = nil
            remaining -= 1
        }
        // 4. 关 fullScreenCover
        if remaining > 0, fullScreenCover != nil {
            fullScreenCover = nil
            remaining -= 1
        }
        // 5. 关 windowSheet
        if remaining > 0, windowSheet != nil {
            windowSheet = nil
            remaining -= 1
        }
        // 6. 还有剩余，传递给父级 Router
        if remaining > 0 {
            parentDismiss?(remaining)
        }
    }

    /// 返回根页面并关闭所有模态（包括父级）
    func dismissAll() {
        alertConfig = nil
        path.removeLast(path.count)
        pathStack.removeAll()
        sheet = nil
        fullScreenCover = nil
        windowSheet = nil
        // 传递给父级，用足够大的数确保全部关闭
        parentDismiss?(Int.max)
    }

    /// 返回到指定路由（保留该路由及其之前的栈，支持跨模态穿透）
    func dismiss(to destination: Destination) {
        if let index = pathStack.lastIndex(of: destination) {
            // 目标在当前 Router 中
            let pathRemoveCount = pathStack.count - index - 1
            let extra = (alertConfig != nil ? 1 : 0)
                      + (sheet != nil ? 1 : 0)
                      + (fullScreenCover != nil ? 1 : 0)
                      + (windowSheet != nil ? 1 : 0)
            dismiss(extra + pathRemoveCount)
        } else {
            // 目标不在当前 Router，关闭当前所有层级，传递给父级
            dismissAll()
            parentDismissTo?(destination)
        }
    }
}

// MARK: - RootRouter

/// 根路由器视图
/// - Push: 在同一个 NavigationStack 内导航
/// - Sheet/FullScreenCover: 自动包装新的 RootRouter——无限嵌套
struct RootRouter<Content: View>: View {
    @StateObject private var router: Router<AppRoute>
    @StateObject private var windowSheetCoordinator = WindowSheetCoordinator()
    let content: () -> Content
    
    /// 从父级环境读取 dismiss 链
    @Environment(\.parentRouterDismiss) private var parentDismiss
    @Environment(\.parentRouterDismissTo) private var parentDismissTo

    init(@ViewBuilder content: @escaping () -> Content) {
        self._router = StateObject(wrappedValue: Router<AppRoute>())
        self.content = content
    }
    
    var body: some View {
        NavigationStack(path: $router.path) {
            content()
                .navigationDestination(for: AppRoute.self) { destination in
                    destination.view
                }
        }
        .sheet(item: $router.sheet) { destination in
            NestedRouter(destination: destination, parentRouter: router)
        }
        .fullScreenCover(item: $router.fullScreenCover) { destination in
            NestedRouter(destination: destination, parentRouter: router)
        }
        .alert(item: $router.alertConfig) { config in
            config.alert()
        }
        .onChange(of: router.windowSheet) { newValue in
            if let destination = newValue {
                windowSheetCoordinator.present(
                    destination: destination,
                    config: router.windowSheetConfig,
                    parentRouter: router
                )
            } else {
                windowSheetCoordinator.dismissIfNeeded()
            }
        }
        .environmentObject(router)
        .onAppear {
            router.parentDismiss = parentDismiss
            router.parentDismissTo = parentDismissTo
        }
    }
}

// MARK: - NestedRouter

/// 嵌套路由器：Sheet/FullScreenCover 自动包装新的 RootRouter
struct NestedRouter: View {
    let destination: AppRoute
    let parentRouter: Router<AppRoute>
    
    var body: some View {
        RootRouter {
            destination.view
        }
        .environment(\.parentRouterDismiss) { count in
            parentRouter.dismiss(count)
        }
        .environment(\.parentRouterDismissTo) { destination in
            parentRouter.dismiss(to: destination)
        }
    }
}

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
            let detentIndex = interaction?.currentDetentIndex ?? 0
            let detentCount = interaction?.detentCount ?? 1
            // 可关闭 或 可切换档位时允许
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
    /// 对于内容区域，shouldBegin 返回 false → 立即失败 → ScrollView 正常工作
    /// 对于指示条/左边缘，shouldBegin 返回 true → 我们优先 → sheet 拖拽生效
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return otherGestureRecognizer is UIPanGestureRecognizer
    }
}

// MARK: - WindowSheetCoordinator

/// 管理 WindowSheet 的 UIWindow 生命周期
@MainActor
final class WindowSheetCoordinator: ObservableObject {
    private var window: UIWindow?
    private let dismissSubject = PassthroughSubject<Void, Never>()

    func present(destination: AppRoute, config: WindowSheetConfig, parentRouter: Router<AppRoute>) {
        guard window == nil else { return }
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive })
        else { return }

        // 创建 UIKit ↔ SwiftUI 交互桥接
        let interaction = SheetInteraction()
        let panHandler = SheetPanHandler()
        panHandler.interaction = interaction
        panHandler.dismissOnDragDown = config.dismissOnDragDown
        interaction.detentCount = config.detents.count

        let hasFitContent = config.detents.contains(.fitContent)

        let container = WindowSheetContainerView(
            config: config,
            interaction: interaction,
            dismissTrigger: dismissSubject.eraseToAnyPublisher(),
            onDismissCompleted: { [weak self, weak parentRouter] in
                self?.removeWindow()
                parentRouter?.windowSheet = nil
            },
            measurementView: hasFitContent ? AnyView(destination.view) : nil
        ) {
            NestedRouter(destination: destination, parentRouter: parentRouter)
        }

        let w = UIWindow(windowScene: scene)
        w.windowLevel = .normal + 1
        w.backgroundColor = .clear

        let hostVC = NoSafeAreaHostingController(rootView: container)
        hostVC.sheetPanHandler = panHandler
        hostVC.view.backgroundColor = .clear
        panHandler.attach(to: hostVC.view)
        w.rootViewController = hostVC
        w.makeKeyAndVisible()
        self.window = w
    }

    func dismissIfNeeded() {
        guard window != nil else { return }
        dismissSubject.send()
    }

    private func removeWindow() {
        window?.isHidden = true
        window = nil
    }
}

// MARK: - WindowSheetContainerView

/// WindowSheet 容器视图：处理遮罩、圆角、多档位拖拽吸附与弹出/收回动画
struct WindowSheetContainerView<Content: View>: View {
    let config: WindowSheetConfig
    @ObservedObject var interaction: SheetInteraction
    let dismissTrigger: AnyPublisher<Void, Never>
    let onDismissCompleted: () -> Void
    /// 仅用于 fitContent 测量的裸视图（不含 NavigationStack）
    let measurementView: AnyView?
    @ViewBuilder let content: () -> Content

    @State private var isPresented = false
    @State private var currentDetentIndex: Int = 0
    @State private var measuredContentHeight: CGFloat = 0

    private var screenHeight: CGFloat { UIScreen.main.bounds.height }

    /// 是否包含 fitContent 模式
    private var hasFitContent: Bool {
        config.detents.contains(.fitContent)
    }

    /// 将 detent 解析为具体高度
    private func resolveHeight(_ detent: WindowSheetDetent) -> CGFloat {
        switch detent {
        case .fullScreen:        return screenHeight
        case .large:             return screenHeight * 0.92
        case .half:              return screenHeight * 0.5
        case .percentage(let p): return screenHeight * min(max(p, 0), 1)
        case .fixedHeight(let h): return min(h, screenHeight)
        case .fitContent:        return min(measuredContentHeight, screenHeight * 0.92)
        }
    }

    /// 所有 detent 高度（升序排列）
    private var sortedHeights: [CGFloat] {
        config.detents.map { resolveHeight($0) }.sorted()
    }

    /// 最大 detent 高度（Sheet frame 使用此值）
    private var maxHeight: CGFloat {
        sortedHeights.last ?? screenHeight * 0.92
    }

    /// 当前 detent 高度
    private var currentHeight: CGFloat {
        let heights = sortedHeights
        guard currentDetentIndex >= 0, currentDetentIndex < heights.count else {
            return heights.last ?? screenHeight * 0.92
        }
        return heights[currentDetentIndex]
    }

    /// 遮罩透明度系数（随当前可见高度变化）
    private var dimFraction: Double {
        let visibleHeight = sheetFrameHeight - max(0, interaction.dragOffset)
        let effective = max(0, visibleHeight)
        return maxHeight > 0 ? max(0, min(1, Double(effective / maxHeight))) : 1
    }

    /// Sheet frame 高度（向上拖时增大，向下拖时保持不变）
    private var sheetFrameHeight: CGFloat {
        let drag = interaction.dragOffset
        if drag >= 0 {
            // 向下拖 或 静止：保持当前档位高度
            return currentHeight
        }
        // 向上拖：frame 增大，不超过 maxHeight（超出部分橡皮筋）
        let extra = -drag
        let available = maxHeight - currentHeight
        if extra <= available {
            return currentHeight + extra
        }
        let excess = extra - available
        return maxHeight + pow(excess, 0.7) * 0.15
    }

    /// Sheet 相对底部的偏移（仅向下拖时产生）
    private var sheetOffset: CGFloat {
        if !isPresented { return screenHeight }
        return max(0, interaction.dragOffset)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            // 遮罩背景
            Color.black
                .opacity(isPresented ? config.backgroundOpacity * dimFraction : 0)
                .ignoresSafeArea()
                .onTapGesture { animateDismiss() }

            // Sheet 主体
            VStack(spacing: 0) {
                if config.showDragIndicator {
                    dragIndicator
                }
                content()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(height: sheetFrameHeight)
            .overlay(
                // fitContent 测量：用裸视图（无 NavigationStack）测量自然高度
                Group {
                    if let mv = measurementView {
                        VStack(spacing: 0) {
                            if config.showDragIndicator {
                                dragIndicator
                            }
                            mv
                        }
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: UIScreen.main.bounds.width)
                        .hidden()
                        .background(
                            GeometryReader { geo in
                                Color.clear.preference(key: ContentHeightPrefKey.self, value: geo.size.height)
                            }
                        )
                    }
                }
                , alignment: .top
            )
            .onPreferenceChange(ContentHeightPrefKey.self) { h in
                if hasFitContent && h > 0 {
                    measuredContentHeight = h
                }
            }
            .background(.regularMaterial)
            .clipShape(RoundedCornerShape(radius: config.cornerRadius, corners: [.topLeft, .topRight]))
            .offset(y: sheetOffset)
        }
        .ignoresSafeArea()
        .onAppear {
            let count = sortedHeights.count
            if let idx = config.initialDetentIndex, idx >= 0, idx < count {
                currentDetentIndex = idx
            } else {
                // 单个 detent 默认最大；多个 detent 默认最小
                currentDetentIndex = count > 1 ? 0 : count - 1
            }
            interaction.currentSheetHeight = currentHeight
            interaction.currentDetentIndex = currentDetentIndex
            interaction.detentCount = sortedHeights.count
            withAnimation(.spring(response: 0.45, dampingFraction: 0.86)) {
                isPresented = true
            }
        }
        .onReceive(dismissTrigger) { _ in
            animateDismiss()
        }
        .onReceive(interaction.dragEnded) { (translation, velocity) in
            let predicted = translation + velocity * 0.2
            let targetHeight = currentHeight - predicted
            snapToDetent(targetHeight: targetHeight, isDraggingDown: translation > 0)
        }
    }

    // MARK: - Snap Logic

    /// 根据目标高度吸附到最近的 detent，或关闭
    private func snapToDetent(targetHeight: CGFloat, isDraggingDown: Bool) {
        let heights = sortedHeights
        let smallestHeight = heights.first ?? 0

        // 向下拖拽且目标低于最小 detent 的 60% → 关闭
        if config.dismissOnDragDown && isDraggingDown && targetHeight < smallestHeight * 0.6 {
            animateDismiss()
            return
        }

        // 找到距离目标最近的 detent
        var bestIndex = currentDetentIndex
        var bestDist: CGFloat = .infinity
        for (i, h) in heights.enumerated() {
            let dist = abs(targetHeight - h)
            if dist < bestDist {
                bestDist = dist
                bestIndex = i
            }
        }

        let newHeight = heights[bestIndex]
        // 档位切换和 dragOffset 归零必须在同一个动画块内，避免闪烁
        withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
            currentDetentIndex = bestIndex
            interaction.dragOffset = 0
        }
        // 非动画属性在动画块后更新
        interaction.currentDetentIndex = bestIndex
        interaction.currentSheetHeight = newHeight
    }

    // MARK: - Subviews

    /// 拖拽指示条
    private var dragIndicator: some View {
        Capsule()
            .fill(Color(.systemGray3))
            .frame(width: 36, height: 5)
            .padding(.top, 8)
            .padding(.bottom, 4)
    }

    /// 执行关闭动画并回调
    private func animateDismiss() {
        guard isPresented else { return }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
            isPresented = false
            interaction.dragOffset = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            onDismissCompleted()
        }
    }
}

// MARK: - Helper Types

/// 移除安全区域的 UIHostingController（兼容 iOS 16+）
private class NoSafeAreaHostingController<V: View>: UIHostingController<V> {
    var sheetPanHandler: SheetPanHandler?

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        guard let windowInsets = view.window?.safeAreaInsets else { return }
        let target = UIEdgeInsets(
            top: -windowInsets.top,
            left: -windowInsets.left,
            bottom: -windowInsets.bottom,
            right: -windowInsets.right
        )
        if additionalSafeAreaInsets != target {
            additionalSafeAreaInsets = target
        }
    }
}

private struct ContentHeightPrefKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

/// 仅顶部圆角的自定义 Shape
struct RoundedCornerShape: Shape {
    var radius: CGFloat
    var corners: UIRectCorner

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

// MARK: - ParentRouterDismiss Environment Key

private struct ParentRouterDismissKey: EnvironmentKey {
    static let defaultValue: (Int) -> Void = { _ in }
}

private struct ParentRouterDismissToKey: EnvironmentKey {
    static let defaultValue: (AppRoute) -> Void = { _ in }
}

extension EnvironmentValues {
    var parentRouterDismiss: (Int) -> Void {
        get { self[ParentRouterDismissKey.self] }
        set { self[ParentRouterDismissKey.self] = newValue }
    }
    var parentRouterDismissTo: (AppRoute) -> Void {
        get { self[ParentRouterDismissToKey.self] }
        set { self[ParentRouterDismissToKey.self] = newValue }
    }
}
