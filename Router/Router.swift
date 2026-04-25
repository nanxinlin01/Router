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

    /// Sheet 配置（present 时赋值）
    var sheetConfig: SheetConfig = .init()

    /// FullScreenCover 展示的目标
    @Published var fullScreenCover: Destination?

    /// Alert 配置
    @Published var alertConfig: AlertConfig?

    /// WindowSheet 展示的目标
    @Published var windowSheet: Destination?

    /// WindowSheet 配置（present 时赋值）
    var windowSheetConfig: WindowSheetConfig = .init()

    /// WindowPush 展示的目标
    @Published var windowPush: Destination?

    /// WindowAlert 展示的目标
    @Published var windowAlert: Destination?

    /// WindowToast 展示的目标
    @Published var windowToast: Destination?

    /// WindowToast 配置（present 时赋值）
    var windowToastConfig: WindowToastConfig = .init()

    /// WindowFade 展示的目标
    @Published var windowFade: Destination?

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
        case .sheet(let config):
            sheetConfig = config
            sheet = destination
        case .fullScreenCover:
            fullScreenCover = destination
        case .alert(let config):
            alertConfig = config
        case .windowSheet(let config):
            windowSheetConfig = config
            windowSheet = destination
        case .windowPush:
            windowPush = destination
        case .windowAlert:
            windowAlert = destination
        case .windowToast(let config):
            windowToastConfig = config
            windowToast = destination
        case .windowFade:
            windowFade = destination
        }
    }

    // MARK: - Dismiss

    /// 返回指定层数（每个 transition 计 1 层，超出当前 Router 层级自动传递给父级）
    func dismiss(_ count: Int = 1) {
        var remaining = count
        // 1. 关 windowAlert（最高优先级，覆盖在最顶层）
        if remaining > 0, windowAlert != nil {
            windowAlert = nil
            remaining -= 1
        }
        // 2. 关 alert
        if remaining > 0, alertConfig != nil {
            alertConfig = nil
            remaining -= 1
        }
        // 3. pop 导航栈（每个计 1 层）
        let popCount = min(remaining, path.count)
        if popCount > 0 {
            path.removeLast(popCount)
            pathStack.removeLast(popCount)
            remaining -= popCount
        }
        // 4. 关 sheet
        if remaining > 0, sheet != nil {
            sheet = nil
            remaining -= 1
        }
        // 5. 关 fullScreenCover
        if remaining > 0, fullScreenCover != nil {
            fullScreenCover = nil
            remaining -= 1
        }
        // 6. 关 windowSheet
        if remaining > 0, windowSheet != nil {
            windowSheet = nil
            remaining -= 1
        }
        // 7. 关 windowPush
        if remaining > 0, windowPush != nil {
            windowPush = nil
            remaining -= 1
        }
        // 8. 关 windowFade
        if remaining > 0, windowFade != nil {
            windowFade = nil
            remaining -= 1
        }
        // 9. 还有剩余，传递给父级 Router
        if remaining > 0 {
            parentDismiss?(remaining)
        }
    }

    /// 返回根页面并关闭所有模态（包括父级）
    func dismissAll() {
        windowToast = nil
        windowFade = nil
        windowAlert = nil
        alertConfig = nil
        path.removeLast(path.count)
        pathStack.removeAll()
        sheet = nil
        fullScreenCover = nil
        windowSheet = nil
        windowPush = nil
        windowFade = nil
        // 传递给父级，用足够大的数确保全部关闭
        parentDismiss?(Int.max)
    }

    /// 返回到指定路由（保留该路由及其之前的栈，支持跨模态穿透）
    func dismiss(to destination: Destination) {
        if let index = pathStack.lastIndex(of: destination) {
            // 目标在当前 Router 中
            let pathRemoveCount = pathStack.count - index - 1
            let extra = (windowAlert != nil ? 1 : 0)
                      + (alertConfig != nil ? 1 : 0)
                      + (sheet != nil ? 1 : 0)
                      + (fullScreenCover != nil ? 1 : 0)
                      + (windowSheet != nil ? 1 : 0)
                      + (windowPush != nil ? 1 : 0)
                      + (windowFade != nil ? 1 : 0)
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
    @StateObject private var windowPushCoordinator = WindowPushCoordinator()
    @StateObject private var windowAlertCoordinator = WindowAlertCoordinator()
    @StateObject private var windowToastCoordinator = WindowToastCoordinator()
    @StateObject private var windowFadeCoordinator = WindowFadeCoordinator()
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
                .presentationDetents(router.sheetConfig.detents)
                .presentationDragIndicator(router.sheetConfig.showDragIndicator ? .visible : .hidden)
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
        .onChange(of: router.windowPush) { newValue in
            if let destination = newValue {
                windowPushCoordinator.present(
                    destination: destination,
                    parentRouter: router
                )
            } else {
                windowPushCoordinator.dismissIfNeeded()
            }
        }
        .onChange(of: router.windowAlert) { newValue in
            if let destination = newValue {
                windowAlertCoordinator.present(
                    destination: destination,
                    parentRouter: router
                )
            } else {
                windowAlertCoordinator.dismissIfNeeded()
            }
        }
        .onChange(of: router.windowToast) { newValue in
            if let destination = newValue {
                windowToastCoordinator.present(
                    destination: destination,
                    config: router.windowToastConfig,
                    parentRouter: router
                )
            } else {
                windowToastCoordinator.dismissIfNeeded()
            }
        }
        .onChange(of: router.windowFade) { newValue in
            if let destination = newValue {
                windowFadeCoordinator.present(
                    destination: destination,
                    parentRouter: router
                )
            } else {
                windowFadeCoordinator.dismissIfNeeded()
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
        // 级别基于当前场景窗口数，支持多层嵌套
        w.windowLevel = .normal + 100
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
    @State private var cachedTopSafeArea: CGFloat = 0

    /// 实时读取屏幕高度（支持旋转）
    private var screenHeight: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first(where: { $0.activationState == .foregroundActive })?
            .windows.first?.bounds.height ?? UIScreen.main.bounds.height
    }

    /// 当 sheet 接近顶部安全区时，动态增加顶部 padding；向下拖时逐渐收回
    private var dynamicTopPadding: CGFloat {
        guard config.respectsTopSafeArea else { return 0 }
        let gap = screenHeight - sheetFrameHeight + max(0, interaction.dragOffset)
        return max(0, cachedTopSafeArea - gap)
    }

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
            ZStack(alignment: .top) {
                // 填充顶部安全区间距，颜色与内容背景一致
                config.contentBackgroundColor
                content()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.top, dynamicTopPadding)
                if config.showDragIndicator && dynamicTopPadding <= 0
                    && (interaction.dragOffset > 0 || (screenHeight - sheetFrameHeight) > max(cachedTopSafeArea, 20)) {
                    dragIndicator
                }
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
                        .frame(maxWidth: .infinity)
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
            updateTopSafeArea()
            withAnimation(.spring(response: 0.45, dampingFraction: 0.86)) {
                isPresented = true
            }
        }
        .onReceive(dismissTrigger) { _ in
            animateDismiss()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
            // 旋转后延迟一帧等待布局完成，再更新安全区
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                updateTopSafeArea()
            }
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

    /// 更新顶部安全区缓存（旋转后安全区可能变化）
    private func updateTopSafeArea() {
        if let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }),
           let w = windowScene.windows.first {
            cachedTopSafeArea = w.safeAreaInsets.top
        }
    }
}

// MARK: - Helper Types

/// WindowPush 左侧边缘手势处理器：纯 UIKit 驱动窗口位移
final class PushEdgePanHandler: NSObject, UIGestureRecognizerDelegate {
    weak var edgeGesture: UIScreenEdgePanGestureRecognizer?
    weak var pushWindow: UIWindow?
    weak var previousWindow: UIWindow?
    weak var dimmingView: UIView?
    var onPopCompleted: (() -> Void)?

    /// 实时屏幕宽度（支持旋转）
    private var currentScreenWidth: CGFloat {
        pushWindow?.bounds.width ?? UIScreen.main.bounds.width
    }

    func attach(to view: UIView) {
        guard edgeGesture == nil else { return }
        let edge = UIScreenEdgePanGestureRecognizer(target: self, action: #selector(handleEdgePan(_:)))
        edge.edges = .left
        edge.delegate = self
        view.addGestureRecognizer(edge)
        self.edgeGesture = edge
    }

    @objc private func handleEdgePan(_ gesture: UIScreenEdgePanGestureRecognizer) {
        guard let view = gesture.view else { return }
        let screenWidth = currentScreenWidth
        switch gesture.state {
        case .began:
            // 手势开始时校正 previousWindow 位置，修复旋转后 frame 异常
            if let prev = previousWindow {
                prev.transform = .identity
                prev.frame = pushWindow?.frame ?? prev.frame
                prev.transform = CGAffineTransform(translationX: -screenWidth * 0.3, y: 0)
            }
        case .changed:
            let tx = max(0, gesture.translation(in: view).x)
            let fraction = min(1, tx / screenWidth)
            pushWindow?.transform = CGAffineTransform(translationX: tx, y: 0)
            previousWindow?.transform = CGAffineTransform(translationX: -screenWidth * 0.3 * (1 - fraction), y: 0)
            dimmingView?.alpha = 0.15 * (1 - fraction)
        case .ended, .cancelled:
            let tx = gesture.translation(in: view).x
            let vx = gesture.velocity(in: view).x
            let fraction = tx / screenWidth
            if vx > 500 || fraction > 0.4 {
                // 完成 pop
                let remaining = screenWidth - tx
                let duration = min(0.3, max(0.1, TimeInterval(remaining / max(vx, 500))))
                UIView.animate(withDuration: duration, delay: 0, options: .curveEaseOut, animations: {
                    self.pushWindow?.transform = CGAffineTransform(translationX: self.currentScreenWidth, y: 0)
                    self.previousWindow?.transform = .identity
                    self.dimmingView?.alpha = 0
                }, completion: { _ in
                    self.onPopCompleted?()
                })
            } else {
                // 回弹
                UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseOut, animations: {
                    self.pushWindow?.transform = .identity
                    self.previousWindow?.transform = CGAffineTransform(translationX: -self.currentScreenWidth * 0.3, y: 0)
                    self.dimmingView?.alpha = 0.15
                })
            }
        default:
            break
        }
    }

    // MARK: - UIGestureRecognizerDelegate

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let view = gestureRecognizer.view else { return false }
        return !SheetPanHandler.hasNavDepth(in: view)
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return false
    }
}

// MARK: - WindowPushCoordinator

/// 管理 WindowPush 的 UIWindow 生命周期，纯 UIKit 动画驱动
@MainActor
final class WindowPushCoordinator: ObservableObject {
    private var window: UIWindow?
    private var previousWindow: UIWindow?
    private var dimmingView: UIView?
    private var panHandler: PushEdgePanHandler?
    private weak var parentRouter: Router<AppRoute>?
    private var boundsObservation: NSKeyValueObservation?

    func present(destination: AppRoute, parentRouter: Router<AppRoute>) {
        guard window == nil else { return }
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive })
        else { return }

        self.parentRouter = parentRouter
        let screenBounds = UIScreen.main.bounds
        let screenWidth = screenBounds.width

        // 记住底层 window（排除 Toast/Alert 等高层级窗口，避免它们被 Push 动画偏移）
        let prevWindow = scene.windows.last(where: { !$0.isHidden && $0.windowLevel < .alert })
        self.previousWindow = prevWindow

        // 在底层 window 上添加变暗遮罩
        let dimView = UIView(frame: prevWindow?.bounds ?? UIScreen.main.bounds)
        dimView.backgroundColor = .black
        dimView.alpha = 0
        dimView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        prevWindow?.addSubview(dimView)
        self.dimmingView = dimView

        // 创建新 window
        let content = NestedRouter(destination: destination, parentRouter: parentRouter)
        let w = UIWindow(windowScene: scene)
        w.windowLevel = .normal + 100
        w.backgroundColor = .systemBackground
        // 左侧阴影
        w.layer.shadowColor = UIColor.black.cgColor
        w.layer.shadowOpacity = 0.2
        w.layer.shadowRadius = 10
        w.layer.shadowOffset = CGSize(width: -5, height: 0)

        let hostVC = UIHostingController(rootView: content)
        hostVC.view.backgroundColor = .systemBackground
        w.rootViewController = hostVC
        w.makeKeyAndVisible()
        // 强制布局后再设置初始位置
        hostVC.view.setNeedsLayout()
        hostVC.view.layoutIfNeeded()
        w.transform = CGAffineTransform(translationX: screenWidth, y: 0)
        self.window = w

        // 设置手势
        let handler = PushEdgePanHandler()
        handler.pushWindow = w
        handler.previousWindow = prevWindow
        handler.dimmingView = dimView
        handler.onPopCompleted = { [weak self] in
            self?.onGesturePopCompleted()
        }
        handler.attach(to: hostVC.view)
        self.panHandler = handler

        // Push 动画（下一个 runloop 确保布局完成）
        DispatchQueue.main.async { [weak w, weak prevWindow, weak self] in
            guard let w = w else { return }
            let screenWidth = w.bounds.width
            UIView.animate(withDuration: 0.35, delay: 0, options: .curveEaseOut, animations: {
                w.transform = .identity
                prevWindow?.transform = CGAffineTransform(translationX: -screenWidth * 0.3, y: 0)
                self?.dimmingView?.alpha = 0.15
            })
        }

        // 监听窗口 bounds 变化（旋转时触发），重新计算 previousWindow 偏移
        boundsObservation = w.observe(\.bounds, options: [.new, .old]) { [weak self] _, change in
            guard let oldVal = change.oldValue, let newVal = change.newValue,
                  oldVal.size != newVal.size else { return }
            Task { @MainActor [weak self] in
                self?.updateLayoutAfterRotation()
            }
        }
    }

    /// 屏幕旋转后重新计算偏移量
    private func updateLayoutAfterRotation() {
        guard let w = window else { return }
        let newWidth = w.bounds.width
        // Push 窗口已完全展示（transform == .identity）时，重新设置底层偏移
        if w.transform == .identity, let prev = previousWindow {
            // 旋转时 UIKit 对带 transform 的 window 调整 frame 可能导致 center 异常
            // 先重置 transform→修正 frame→再应用偏移
            prev.transform = .identity
            prev.frame = w.frame
            prev.transform = CGAffineTransform(translationX: -newWidth * 0.3, y: 0)
        }
    }

    /// 程序化 dismiss（router.windowPush = nil 触发）
    func dismissIfNeeded() {
        guard let w = window else { return }
        let screenWidth = w.bounds.width
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseIn, animations: {
            w.transform = CGAffineTransform(translationX: screenWidth, y: 0)
            self.previousWindow?.transform = .identity
            self.dimmingView?.alpha = 0
        }, completion: { _ in
            self.removeWindow()
        })
    }

    /// 手势 pop 完成回调
    private func onGesturePopCompleted() {
        removeWindow()
        parentRouter?.windowPush = nil
    }

    private func removeWindow() {
        boundsObservation?.invalidate()
        boundsObservation = nil
        dimmingView?.removeFromSuperview()
        dimmingView = nil
        previousWindow?.transform = .identity
        window?.isHidden = true
        window = nil
        previousWindow = nil
        panHandler = nil
    }
}

// MARK: - WindowAlertCoordinator

/// 管理 WindowAlert 的 UIWindow 生命周期（支持多层嵌套）
@MainActor
final class WindowAlertCoordinator: ObservableObject {
    private var windows: [(UIWindow, PassthroughSubject<Void, Never>)] = []

    func present(destination: AppRoute, parentRouter: Router<AppRoute>) {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive })
        else { return }

        let dismissSubject = PassthroughSubject<Void, Never>()
        let index = windows.count

        let container = WindowAlertContainerView(
            dismissTrigger: dismissSubject.eraseToAnyPublisher(),
            onDismissCompleted: { [weak self, weak parentRouter] in
                self?.removeWindow(at: index)
                parentRouter?.windowAlert = nil
            }
        ) {
            NestedRouter(destination: destination, parentRouter: parentRouter)
        }

        let w = UIWindow(windowScene: scene)
        w.windowLevel = .alert + 200 + CGFloat(windows.count)
        w.backgroundColor = UIColor.clear

        let hostVC = ClearBackgroundHostingController(rootView: container)
        hostVC.view.backgroundColor = UIColor.clear
        w.rootViewController = hostVC
        w.makeKeyAndVisible()
        windows.append((w, dismissSubject))
    }

    func dismissIfNeeded() {
        guard let last = windows.last else { return }
        last.1.send()
    }

    private func removeWindow(at index: Int) {
        guard index < windows.count else { return }
        windows[index].0.isHidden = true
        windows.remove(at: index)
    }
}

// MARK: - WindowFadeCoordinator

/// 管理 WindowFade 的 UIWindow 生命周期，支持多层叠加
@MainActor
final class WindowFadeCoordinator: ObservableObject {
    private var windows: [(UIWindow, PassthroughSubject<Void, Never>)] = []

    func present(destination: AppRoute, parentRouter: Router<AppRoute>) {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive })
        else { return }

        let dismissSubject = PassthroughSubject<Void, Never>()
        let index = windows.count

        let container = WindowFadeContainerView(
            dismissTrigger: dismissSubject.eraseToAnyPublisher(),
            onDismissCompleted: { [weak self, weak parentRouter] in
                self?.removeWindow(at: index)
                parentRouter?.windowFade = nil
            }
        ) {
            NestedRouter(destination: destination, parentRouter: parentRouter)
        }

        let w = UIWindow(windowScene: scene)
        w.windowLevel = .normal + 100
        w.backgroundColor = UIColor.clear

        let hostVC = ClearBackgroundHostingController(rootView: container)
        hostVC.view.backgroundColor = UIColor.clear
        w.rootViewController = hostVC
        w.makeKeyAndVisible()
        windows.append((w, dismissSubject))
    }

    func dismissIfNeeded() {
        guard let last = windows.last else { return }
        last.1.send()
    }

    private func removeWindow(at index: Int) {
        guard index < windows.count else { return }
        windows[index].0.isHidden = true
        windows.remove(at: index)
    }
}

// MARK: - WindowFadeContainerView

/// WindowFade 容器视图：遮罩 + 全屏内容 + 淡入淡出动画
struct WindowFadeContainerView<Content: View>: View {
    let dismissTrigger: AnyPublisher<Void, Never>
    let onDismissCompleted: () -> Void
    @ViewBuilder let content: () -> Content

    @State private var isPresented = false

    var body: some View {
        ZStack {
            // 遮罩背景
            Color.black
                .opacity(isPresented ? 0.3 : 0)
                .ignoresSafeArea()

            // 全屏内容
            content()
                .opacity(isPresented ? 1.0 : 0)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.3)) {
                isPresented = true
            }
        }
        .onReceive(dismissTrigger) { _ in
            animateDismiss()
        }
    }

    private func animateDismiss() {
        guard isPresented else { return }
        withAnimation(.easeInOut(duration: 0.3)) {
            isPresented = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            onDismissCompleted()
        }
    }
}

// MARK: - WindowAlertContainerView

/// WindowAlert 容器视图：遮罩 + 居中内容 + 缩放/淡入淡出动画
struct WindowAlertContainerView<Content: View>: View {
    let dismissTrigger: AnyPublisher<Void, Never>
    let onDismissCompleted: () -> Void
    @ViewBuilder let content: () -> Content

    @State private var isPresented = false

    var body: some View {
        ZStack {
            // 遮罩背景
            Color.black
                .opacity(isPresented ? 0.3 : 0)
                .ignoresSafeArea()
                .onTapGesture { animateDismiss() }

            // 自定义内容
            content()
                .scaleEffect(isPresented ? 1.0 : 1.2)
                .opacity(isPresented ? 1.0 : 0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                isPresented = true
            }
        }
        .onReceive(dismissTrigger) { _ in
            animateDismiss()
        }
    }

    /// 执行关闭动画并回调
    private func animateDismiss() {
        guard isPresented else { return }
        withAnimation(.easeOut(duration: 0.2)) {
            isPresented = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            onDismissCompleted()
        }
    }
}

// MARK: - WindowToastCoordinator

/// 管理 WindowToast 的 UIWindow 生命周期，支持多层叠加
@MainActor
final class WindowToastCoordinator: ObservableObject {
    private var windows: [(UIWindow, PassthroughSubject<Void, Never>)] = []

    func present(destination: AppRoute, config: WindowToastConfig, parentRouter: Router<AppRoute>) {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive })
        else { return }

        let dismissSubject = PassthroughSubject<Void, Never>()
        let index = windows.count

        let w = ToastWindow(windowScene: scene)
        w.windowLevel = .alert + 300 + CGFloat(windows.count)
        w.backgroundColor = .clear
        w.passThroughEmptyArea = !config.showDimming
        w.interceptToastContent = config.dismissOnTap

        let container = WindowToastContainerView(
            config: config,
            dismissTrigger: dismissSubject.eraseToAnyPublisher(),
            onDismissCompleted: { [weak self, weak parentRouter] in
                self?.removeWindow(at: index)
                parentRouter?.windowToast = nil
            },
            onToastFrameChanged: { [weak w] frame in
                w?.toastFrame = frame
            }
        ) {
            destination.view
        }

        let hostVC = ClearBackgroundHostingController(rootView: container)
        hostVC.view.backgroundColor = .clear
        w.rootViewController = hostVC
        w.makeKeyAndVisible()
        windows.append((w, dismissSubject))
    }

    func dismissIfNeeded() {
        guard let last = windows.last else { return }
        last.1.send()
    }

    private func removeWindow(at index: Int) {
        guard index < windows.count else { return }
        windows[index].0.isHidden = true
        windows.remove(at: index)
    }
}

// MARK: - ToastWindow

/// Toast 专用窗口：支持在 Toast 区域外自动穿透触摸
private class ToastWindow: UIWindow {
    /// 是否对空白区域穿透（无遮罩模式）
    var passThroughEmptyArea = false
    /// 是否拦截 Toast 内容区域的触摸（点击关闭）
    var interceptToastContent = true
    /// Toast 内容区域（全局坐标，由 SwiftUI GeometryReader 更新）
    var toastFrame: CGRect = .zero

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard passThroughEmptyArea else {
            // 有遮罩模式：整个窗口响应
            return super.hitTest(point, with: event)
        }
        guard interceptToastContent else {
            // 不拦截 Toast 点击：整个窗口全部穿透
            return nil
        }
        // 触摸点在 Toast 区域内 → 拦截，否则穿透
        let pointInScreen = convert(point, to: nil)
        guard !toastFrame.isEmpty, toastFrame.contains(pointInScreen) else {
            return nil
        }
        return super.hitTest(point, with: event)
    }
}

// MARK: - WindowToastContainerView

/// WindowToast 容器视图：支持顶部/底部滑入滑出动画，自动消失
struct WindowToastContainerView<Content: View>: View {
    let config: WindowToastConfig
    let dismissTrigger: AnyPublisher<Void, Never>
    let onDismissCompleted: () -> Void
    let onToastFrameChanged: (CGRect) -> Void
    @ViewBuilder let content: () -> Content

    @State private var isPresented = false
    @State private var toastFrame: CGRect = .zero

    var body: some View {
        ZStack {
            // 背景遮罩：有 dimming 时显示半透明黑色并拦截点击，无 dimming 时不渲染
            if config.showDimming {
                Color.black
                    .opacity(isPresented ? config.backgroundOpacity : 0)
                    .ignoresSafeArea()
                    .onTapGesture { animateDismiss() }
            }

            // Toast 内容
            VStack {
                if config.position == .bottom {
                    Spacer()
                }

                if isPresented {
                    content()
                        .fixedSize(horizontal: false, vertical: true)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if config.dismissOnTap {
                                animateDismiss()
                            }
                        }
                        .transition(
                            .move(edge: config.position == .top ? .top : .bottom)
                            .combined(with: .opacity)
                        )
                        .overlay(
                            GeometryReader { geo in
                                Color.clear
                                    .onAppear { toastFrame = geo.frame(in: .global) }
                                    .onChange(of: geo.frame(in: .global)) { toastFrame = $0 }
                            }
                        )
                }

                if config.position == .top {
                    Spacer()
                }
            }
        }
        .onChange(of: toastFrame) { frame in
            onToastFrameChanged(frame)
        }
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                isPresented = true
            }
            // 自动消失
            if let duration = config.duration {
                DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                    animateDismiss()
                }
            }
        }
        .onReceive(dismissTrigger) { _ in
            animateDismiss()
        }
    }

    private func animateDismiss() {
        guard isPresented else { return }
        withAnimation(.easeOut(duration: 0.25)) {
            isPresented = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onDismissCompleted()
        }
    }
}

// MARK: - Other Helper Types

/// 自动清除子视图层级中 NavigationController 背景色的 HostingController
private class ClearBackgroundHostingController<V: View>: UIHostingController<V> {
    private var didClearBackground = false

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        guard !didClearBackground else { return }
        didClearBackground = true

        DispatchQueue.main.async {
            self.clearNavigationBackground(in: self)
        }
    }

    private func clearNavigationBackground(in viewController: UIViewController) {
        if let nav = viewController as? UINavigationController {
            nav.view.backgroundColor = .clear
            nav.view.isOpaque = false
            nav.viewControllers.forEach { vc in
                vc.view.backgroundColor = .clear
                vc.view.isOpaque = false
            }
            return
        }
        for child in viewController.children {
            clearNavigationBackground(in: child)
        }
    }
}

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
