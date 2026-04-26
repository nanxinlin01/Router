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

// MARK: - DeepLinkHandler

/// 深连接信息结构体
struct DeepLinkInfo {
    /// 路由路径（如 "app/settings" 或 "demo/registered"）
    let path: String
    /// 查询参数（如 ["title": "Hello", "id": "123"]）
    let queryItems: [String: String]
    /// 转换后的路由参数（用于传递给路由系统）
    var routeParams: RouteParams {
        RouteParams(queryItems.mapValues { $0 as Any })
    }
    /// 转场方式（可选，如 "sheet", "windowPush" 等）
    let transition: String?
}

/// 通用深连接解析器：纯 URL 解析，与业务逻辑完全分离
class DeepLinkHandler {
    
    /// 支持的转场方式映射
    static let transitionMap: [String: RouteTransition] = [
        "push": .push,
        "sheet": .sheet(),
        "fullscreencover": .fullScreenCover,
        "windowsheet": .windowSheet(),
        "windowpush": .windowPush,
        "windowalert": .windowAlert,
        "windowtoast": .windowToast(),
        "windowfade": .windowFade
    ]
    
    /// 解析 URL 为深连接信息（支持标准 URL 格式）
    /// - Parameter url: 深连接 URL（如 "myapp://app/settings?transition=sheet"）
    /// - Returns: 解析后的深连接信息，如果解析失败返回 nil
    static func parse(_ url: URL) -> DeepLinkInfo? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
              let host = components.host else {
            return nil
        }
        
        // 构建路径（host + path）
        let path: String
        let pathComponent = components.path
        if !pathComponent.isEmpty {
            // 移除开头的斜杠，如 "/settings" -> "settings"
            let cleanPath = pathComponent.hasPrefix("/") ? String(pathComponent.dropFirst()) : pathComponent
            path = cleanPath.isEmpty ? host : "\(host)/\(cleanPath)"
        } else {
            path = host
        }
        
        // 解析查询参数
        let queryItems = (components.queryItems ?? []).reduce(into: [String: String]()) { result, item in
            result[item.name] = item.value
        }
        
        // 提取转场方式参数（如果存在）
        let transition = queryItems["transition"]?.lowercased()
        
        return DeepLinkInfo(path: path, queryItems: queryItems, transition: transition)
    }
    
    /// 解析 URL 并自动匹配转场方式
    /// - Parameter url: 深连接 URL
    /// - Returns: (深连接信息, 转场方式) 元组
    static func parseWithTransition(_ url: URL) -> (DeepLinkInfo, RouteTransition)? {
        guard let info = parse(url) else { return nil }
        
        let transition: RouteTransition
        if let transitionKey = info.transition, let matched = transitionMap[transitionKey] {
            transition = matched
        } else {
            transition = .push // 默认转场方式
        }
        
        return (info, transition)
    }
}

// MARK: - RouteParams

/// 路由参数
struct RouteParams {
    private let storage: [String: Any]

    init(_ dict: [String: Any] = [:]) {
        self.storage = dict
    }

    /// 取值：`params["title"]` / `params["title", default: ""]`
    subscript<T>(_ key: String) -> T? {
        storage[key] as? T
    }

    subscript<T>(_ key: String, default defaultValue: T) -> T {
        self[key] ?? defaultValue
    }
}

// MARK: - AutoRoute

/// 自动路由基类：子类 override routePath / createInstance / routeView，即可被 Runtime 自动发现并注册
class AutoRoute: NSObject {
    /// 路由路径标识（如 "demo/registered"）
    class var routePath: String { "" }
    /// 从参数创建实例
    class func createInstance(from params: RouteParams) -> AutoRoute? { nil }
    /// 构建视图
    var routeView: AnyView { AnyView(EmptyView()) }
}

// MARK: - RouteRegistry

/// 路由注册中心：自动扫描 AutoRoute 子类并注册
@MainActor
final class RouteRegistry {
    /// 懒初始化：首次访问时自动扫描并注册所有 AutoRoute 子类
    static let shared: RouteRegistry = {
        let registry = RouteRegistry()
        registry.autoRegisterAll()
        return registry
    }()
    private var factories: [String: (RouteParams) -> AnyView?] = [:]
    private var viewCache: [String: AnyView] = [:]

    /// 注册路由
    func register(path: String, factory: @escaping (RouteParams) -> AnyView?) {
        factories[path] = factory
    }

    /// 解析路径为视图
    func resolve(path: String, params: RouteParams = RouteParams()) -> AnyView? {
        if let cached = viewCache.removeValue(forKey: path) {
            return cached
        }
        return factories[path]?(params)
    }

    /// 检查路径是否已注册
    func isRegistered(path: String) -> Bool {
        factories[path] != nil
    }

    /// ObjC Runtime 扫描当前模块所有 AutoRoute 子类并注册
    private func autoRegisterAll() {
        guard let imageName = class_getImageName(AutoRoute.self) else { return }
        let imagePath = String(cString: imageName)

        var count: UInt32 = 0
        guard let classNames = objc_copyClassNamesForImage(imagePath, &count) else { return }
        defer { free(UnsafeMutableRawPointer(mutating: classNames)) }

        for i in 0..<Int(count) {
            guard let cls = NSClassFromString(String(cString: classNames[i])) else { continue }
            // 检查是否是 AutoRoute 的子类（排除 AutoRoute 自身）
            guard cls != AutoRoute.self, isSubclass(cls, of: AutoRoute.self) else { continue }
            let routeClass = cls as! AutoRoute.Type
            let path = routeClass.routePath
            guard !path.isEmpty else { continue }
            register(path: path) { params in
                routeClass.createInstance(from: params)?.routeView
            }
        }
    }

    /// 纯 C 函数判断继承链（Preview 安全）
    private func isSubclass(_ cls: AnyClass, of parent: AnyClass) -> Bool {
        var current: AnyClass? = cls
        while let c = current {
            if c === parent { return true }
            current = class_getSuperclass(c)
        }
        return false
    }

    /// 缓存视图（用于 push 的临时存储）
    func cacheView(_ view: AnyView, forKey key: String) {
        viewCache[key] = view
    }
}

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

/// 泛型路由管理器，统一管理 Push/Sheet/FullScreenCover/Alert/Window系列
final class Router<Destination: Routable>: ObservableObject {

    // MARK: - Navigation State

    /// NavigationStack 路径
    @Published var path = NavigationPath()

    /// 路由栈记录（用于 dismiss(to:) 查找）
    private var pathStack: [Destination] = []

    /// Alert 配置
    @Published var alertConfig: AlertConfig?

    // MARK: - Unified Presentation State

    @Published var sheetPresentation: RoutePresentation?
    @Published var fullScreenCoverPresentation: RoutePresentation?
    @Published var windowSheetPresentation: RoutePresentation?
    @Published var windowPushPresentation: RoutePresentation?
    @Published var windowAlertPresentation: RoutePresentation?
    @Published var windowToastPresentation: RoutePresentation?
    @Published var windowFadePresentation: RoutePresentation?

    /// 父级 dismiss 链（用于跨模态层级传递）
    var parentDismiss: ((Int) -> Void)?
    /// 父级 dismiss(to:) 链
    var parentDismissTo: ((Destination) -> Void)?

    /// 由 RootRouter 配置：逐层关闭 windowAlert（支持多层嵌套）
    var windowAlertDismissAction: (() -> Void)?

    // MARK: - Navigate

    /// 枚举路由导航
    func present(to destination: Destination, via transition: RouteTransition = .push) {
        let appRoute = destination as! AppRoute
        let router = self as! Router<AppRoute>
        switch transition {
        case .push:
            path.append(destination)
            pathStack.append(destination)
        case .sheet(let config):
            sheetPresentation = RoutePresentation(
                view: AnyView(NestedRouter(destination: appRoute, parentRouter: router)),
                sheetConfig: config)
        case .fullScreenCover:
            fullScreenCoverPresentation = RoutePresentation(
                view: AnyView(NestedRouter(destination: appRoute, parentRouter: router)))
        case .alert(let config):
            alertConfig = config
        case .windowSheet(let config):
            windowSheetPresentation = RoutePresentation(
                view: AnyView(NestedRouter(destination: appRoute, parentRouter: router)),
                rawView: AnyView(destination.view),
                windowSheetConfig: config)
        case .windowPush:
            windowPushPresentation = RoutePresentation(
                view: AnyView(NestedRouter(destination: appRoute, parentRouter: router)))
        case .windowAlert:
            windowAlertPresentation = RoutePresentation(
                view: AnyView(NestedRouter(destination: appRoute, parentRouter: router)))
        case .windowToast(let config):
            windowToastPresentation = RoutePresentation(
                view: AnyView(destination.view),
                windowToastConfig: config)
        case .windowFade:
            windowFadePresentation = RoutePresentation(
                view: AnyView(NestedRouter(destination: appRoute, parentRouter: router)))
        }
    }

    // MARK: - Registered Route Navigate

    /// 直接用路由实例导航（AutoRoute）
    func present(route: AutoRoute, via transition: RouteTransition = .push) {
        presentRegistered(view: route.routeView, via: transition)
    }

    /// 通过路径导航（从注册中心解析）
    func present(path: String, params: RouteParams = RouteParams(), via transition: RouteTransition = .push) {
        guard let view = RouteRegistry.shared.resolve(path: path, params: params) else {
            print("[Router] 未找到注册路由: \(path)")
            return
        }
        presentRegistered(view: view, via: transition)
    }

    /// 内部统一处理注册路由呈现
    private func presentRegistered(view: AnyView, via transition: RouteTransition) {
        let router = self as! Router<AppRoute>
        switch transition {
        case .push:
            let key = UUID().uuidString
            RouteRegistry.shared.cacheView(view, forKey: key)
            path.append(key)
        case .sheet(let config):
            sheetPresentation = RoutePresentation(
                view: AnyView(NestedRouter(view: view, parentRouter: router)),
                sheetConfig: config)
        case .fullScreenCover:
            fullScreenCoverPresentation = RoutePresentation(
                view: AnyView(NestedRouter(view: view, parentRouter: router)))
        case .windowSheet(let config):
            windowSheetPresentation = RoutePresentation(
                view: AnyView(NestedRouter(view: view, parentRouter: router)),
                rawView: view,
                windowSheetConfig: config)
        case .windowPush:
            windowPushPresentation = RoutePresentation(
                view: AnyView(NestedRouter(view: view, parentRouter: router)))
        case .windowAlert:
            // 用居中包装 + 隐藏导航栏，保持 alert 弹窗样式，同时支持 push 导航
            let alertContent = AnyView(
                ZStack {
                    view
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .navigationBarHidden(true)
            )
            windowAlertPresentation = RoutePresentation(
                view: AnyView(NestedRouter(view: alertContent, parentRouter: router)))
        case .windowToast(let config):
            windowToastPresentation = RoutePresentation(
                view: view,
                windowToastConfig: config)
        case .windowFade:
            windowFadePresentation = RoutePresentation(
                view: AnyView(NestedRouter(view: view, parentRouter: router)))
        case .alert:
            print("[Router] 注册路由不支持 .alert 转场，请使用 .windowAlert")
        }
    }

    // MARK: - Dismiss

    /// 返回指定层数（每个 transition 计 1 层）
    func dismiss(_ count: Int = 1) {
        var remaining = count
        // 1. 关 windowAlert（最高优先级，支持多层嵌套）
        if remaining > 0, windowAlertPresentation != nil || windowAlertDismissAction != nil {
            if let action = windowAlertDismissAction {
                action()
            } else {
                windowAlertPresentation = nil
            }
            remaining -= 1
        }
        // 2. 关 alert
        if remaining > 0, alertConfig != nil {
            alertConfig = nil
            remaining -= 1
        }
        // 3. pop 导航栈
        let popCount = min(remaining, path.count)
        if popCount > 0 {
            path.removeLast(popCount)
            pathStack.removeLast(min(popCount, pathStack.count))
            remaining -= popCount
        }
        // 4. 关 sheet
        if remaining > 0, sheetPresentation != nil {
            sheetPresentation = nil
            remaining -= 1
        }
        // 5. 关 fullScreenCover
        if remaining > 0, fullScreenCoverPresentation != nil {
            fullScreenCoverPresentation = nil
            remaining -= 1
        }
        // 6. 关 windowSheet
        if remaining > 0, windowSheetPresentation != nil {
            windowSheetPresentation = nil
            remaining -= 1
        }
        // 7. 关 windowPush
        if remaining > 0, windowPushPresentation != nil {
            windowPushPresentation = nil
            remaining -= 1
        }
        // 8. 关 windowFade
        if remaining > 0, windowFadePresentation != nil {
            windowFadePresentation = nil
            remaining -= 1
        }
        // 9. 还有剩余，传递给父级 Router
        if remaining > 0 {
            parentDismiss?(remaining)
        }
    }

    /// 返回根页面并关闭所有模态（包括父级）
    func dismissAll() {
        windowToastPresentation = nil
        windowFadePresentation = nil
        windowAlertPresentation = nil
        windowAlertDismissAction = nil
        alertConfig = nil
        path.removeLast(path.count)
        pathStack.removeAll()
        sheetPresentation = nil
        fullScreenCoverPresentation = nil
        windowSheetPresentation = nil
        windowPushPresentation = nil
        // 传递给父级，用足够大的数确保全部关闭
        parentDismiss?(Int.max)
    }

    /// 返回到指定路由（保留该路由及其之前的栈，支持跨模态穿透）
    func dismiss(to destination: Destination) {
        if let index = pathStack.lastIndex(of: destination) {
            let pathRemoveCount = pathStack.count - index - 1
            let extra = (windowAlertPresentation != nil || windowAlertDismissAction != nil ? 1 : 0)
                      + (alertConfig != nil ? 1 : 0)
                      + (sheetPresentation != nil ? 1 : 0)
                      + (fullScreenCoverPresentation != nil ? 1 : 0)
                      + (windowSheetPresentation != nil ? 1 : 0)
                      + (windowPushPresentation != nil ? 1 : 0)
                      + (windowFadePresentation != nil ? 1 : 0)
            dismiss(extra + pathRemoveCount)
        } else {
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
                .navigationDestination(for: String.self) { key in
                    if let view = RouteRegistry.shared.resolve(path: key) {
                        view
                    } else {
                        Text("路由未注册: \(key)")
                    }
                }
        }
        .sheet(item: $router.sheetPresentation) { presentation in
            presentation.view
                .presentationDetents(presentation.sheetConfig.detents)
                .presentationDragIndicator(presentation.sheetConfig.showDragIndicator ? .visible : .hidden)
        }
        .fullScreenCover(item: $router.fullScreenCoverPresentation) { presentation in
            presentation.view
        }
        .alert(item: $router.alertConfig) { config in
            config.alert()
        }
        .onChange(of: router.windowSheetPresentation?.id) { _ in
            if let presentation = router.windowSheetPresentation {
                windowSheetCoordinator.present(presentation: presentation) {
                    router.windowSheetPresentation = nil
                }
            } else {
                windowSheetCoordinator.dismissIfNeeded()
            }
        }
        .onChange(of: router.windowPushPresentation?.id) { _ in
            if let presentation = router.windowPushPresentation {
                windowPushCoordinator.present(presentation: presentation) {
                    router.windowPushPresentation = nil
                }
            } else {
                windowPushCoordinator.dismissIfNeeded()
            }
        }
        .onChange(of: router.windowAlertPresentation?.id) { _ in
            if let presentation = router.windowAlertPresentation {
                windowAlertCoordinator.present(presentation: presentation) {
                    // 所有窗口关闭后才清理 Router 状态
                    router.windowAlertPresentation = nil
                    router.windowAlertDismissAction = nil
                }
                // 配置逐层 dismiss 动作（dismiss() 调用时走这里）
                router.windowAlertDismissAction = { [weak windowAlertCoordinator] in
                    windowAlertCoordinator?.dismissIfNeeded()
                }
            } else {
                // 属性被置 nil（dismissAll 等），强制关闭所有窗口
                windowAlertCoordinator.dismissAllWindows()
                router.windowAlertDismissAction = nil
            }
        }
        .onChange(of: router.windowToastPresentation?.id) { _ in
            if let presentation = router.windowToastPresentation {
                windowToastCoordinator.present(presentation: presentation) {
                    router.windowToastPresentation = nil
                }
            } else {
                windowToastCoordinator.dismissIfNeeded()
            }
        }
        .onChange(of: router.windowFadePresentation?.id) { _ in
            if let presentation = router.windowFadePresentation {
                windowFadeCoordinator.present(presentation: presentation) {
                    router.windowFadePresentation = nil
                }
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

/// 嵌套路由器：自动包装新的 RootRouter，支持枚举路由和注册路由
struct NestedRouter: View {
    let content: AnyView
    let parentRouter: Router<AppRoute>

    /// 枚举路由便捷初始化
    init(destination: AppRoute, parentRouter: Router<AppRoute>) {
        self.content = destination.view
        self.parentRouter = parentRouter
    }

    /// 注册路由 / AnyView 初始化
    init(view: AnyView, parentRouter: Router<AppRoute>) {
        self.content = view
        self.parentRouter = parentRouter
    }

    var body: some View {
        RootRouter {
            content
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

    /// 统一呈现方法（枚举路由和注册路由共用）
    func present(presentation: RoutePresentation, onDismiss: @escaping () -> Void) {
        guard window == nil else { return }
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive })
        else { return }

        let config = presentation.windowSheetConfig
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
            onDismissCompleted: { [weak self] in
                self?.removeWindow()
                onDismiss()
            },
            measurementView: hasFitContent ? presentation.rawView : nil
        ) {
            presentation.view
        }

        let w = UIWindow(windowScene: scene)
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
    private var boundsObservation: NSKeyValueObservation?
    private var onDismissCallback: (() -> Void)?

    /// 统一呈现方法（枚举路由和注册路由共用）
    func present(presentation: RoutePresentation, onDismiss: @escaping () -> Void) {
        guard window == nil else { return }
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive })
        else { return }

        self.onDismissCallback = onDismiss
        let screenWidth = UIScreen.main.bounds.width

        let prevWindow = scene.windows.last(where: { !$0.isHidden && $0.windowLevel < .alert })
        self.previousWindow = prevWindow

        let dimView = UIView(frame: prevWindow?.bounds ?? UIScreen.main.bounds)
        dimView.backgroundColor = .black
        dimView.alpha = 0
        dimView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        prevWindow?.addSubview(dimView)
        self.dimmingView = dimView

        let w = UIWindow(windowScene: scene)
        w.windowLevel = .normal + 100
        w.backgroundColor = .systemBackground
        w.layer.shadowColor = UIColor.black.cgColor
        w.layer.shadowOpacity = 0.2
        w.layer.shadowRadius = 10
        w.layer.shadowOffset = CGSize(width: -5, height: 0)

        let hostVC = UIHostingController(rootView: presentation.view)
        hostVC.view.backgroundColor = .systemBackground
        w.rootViewController = hostVC
        w.makeKeyAndVisible()
        hostVC.view.setNeedsLayout()
        hostVC.view.layoutIfNeeded()
        w.transform = CGAffineTransform(translationX: screenWidth, y: 0)
        self.window = w

        let handler = PushEdgePanHandler()
        handler.pushWindow = w
        handler.previousWindow = prevWindow
        handler.dimmingView = dimView
        handler.onPopCompleted = { [weak self] in
            self?.onGesturePopCompleted()
        }
        handler.attach(to: hostVC.view)
        self.panHandler = handler

        DispatchQueue.main.async { [weak w, weak prevWindow, weak self] in
            guard let w = w else { return }
            let screenWidth = w.bounds.width
            UIView.animate(withDuration: 0.35, delay: 0, options: .curveEaseOut, animations: {
                w.transform = .identity
                prevWindow?.transform = CGAffineTransform(translationX: -screenWidth * 0.3, y: 0)
                self?.dimmingView?.alpha = 0.15
            })
        }

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
        onDismissCallback?()
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
        onDismissCallback = nil
    }
}

// MARK: - WindowAlertCoordinator

/// 管理 WindowAlert 的 UIWindow 生命周期（支持多层嵌套）
@MainActor
final class WindowAlertCoordinator: ObservableObject {
    private var windows: [(UIWindow, PassthroughSubject<Void, Never>)] = []
    /// 所有窗口关闭后的回调
    private var onAllDismissedCallback: (() -> Void)?

    /// 是否有活跃窗口
    var hasActiveWindows: Bool { !windows.isEmpty }

    /// 统一呈现方法（支持多层堆叠，只在最后一个窗口关闭时回调）
    func present(presentation: RoutePresentation, onAllDismissed: @escaping () -> Void) {
        self.onAllDismissedCallback = onAllDismissed
        presentInternal(contentView: presentation.view)
    }

    private func presentInternal(contentView: AnyView) {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive })
        else { return }

        let dismissSubject = PassthroughSubject<Void, Never>()
        let index = windows.count

        let container = WindowAlertContainerView(
            dismissTrigger: dismissSubject.eraseToAnyPublisher(),
            onDismissCompleted: { [weak self] in
                self?.removeWindow(at: index)
                if self?.windows.isEmpty == true {
                    self?.onAllDismissedCallback?()
                    self?.onAllDismissedCallback = nil
                }
            }
        ) {
            contentView
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

    /// 关闭最顶层窗口（带动画）
    func dismissIfNeeded() {
        guard let last = windows.last else { return }
        last.1.send()
    }

    /// 立即关闭所有窗口（用于 dismissAll）
    func dismissAllWindows() {
        for (window, _) in windows {
            window.isHidden = true
        }
        windows.removeAll()
        onAllDismissedCallback?()
        onAllDismissedCallback = nil
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

    /// 统一呈现方法（枚举路由和注册路由共用）
    func present(presentation: RoutePresentation, onDismiss: @escaping () -> Void) {
        presentInternal(contentView: presentation.view, onDismiss: onDismiss)
    }

    private func presentInternal(contentView: AnyView, onDismiss: @escaping () -> Void) {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive })
        else { return }

        let dismissSubject = PassthroughSubject<Void, Never>()
        let index = windows.count

        let container = WindowFadeContainerView(
            dismissTrigger: dismissSubject.eraseToAnyPublisher(),
            onDismissCompleted: { [weak self] in
                self?.removeWindow(at: index)
                onDismiss()
            }
        ) {
            contentView
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

    /// 统一呈现方法（枚举路由和注册路由共用）
    func present(presentation: RoutePresentation, onDismiss: @escaping () -> Void) {
        presentInternal(contentView: presentation.view, config: presentation.windowToastConfig, onDismiss: onDismiss)
    }

    private func presentInternal(contentView: AnyView, config: WindowToastConfig, onDismiss: @escaping () -> Void) {
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
            onDismissCompleted: { [weak self] in
                self?.removeWindow(at: index)
                onDismiss()
            },
            onToastFrameChanged: { [weak w] frame in
                w?.toastFrame = frame
            }
        ) {
            contentView
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

// MARK: - RouteMatcher Protocol

/// 路由匹配器协议：业务层实现此协议以提供 URL 到路由的映射能力
/// 通过协议解耦，使 Router 组件不依赖任何业务类型
protocol RouteMatcher {
    /// 将深连接路径和参数映射为具体路由
    /// - Parameters:
    ///   - path: 路由路径（如 "app/settings"）
    ///   - params: 查询参数
    /// - Returns: 对应的路由，如果无法映射返回 nil
    static func match(path: String, params: [String: String]) -> AppRoute?
}

// MARK: - Router DeepLink Extension

/// Router 深连接扩展：支持枚举路由和注册路由的深连接处理
/// 通过 RouteMatcher 协议实现业务解耦，Router 组件不依赖任何业务类型
extension Router where Destination == AppRoute {
    
    /// 处理枚举路由深连接（URL -> AppRoute 枚举）
    /// - Parameters:
    ///   - url: 深连接 URL
    ///   - transition: 转场方式（可选，如果 URL 中包含 transition 参数则优先使用）
    ///   - matcher: 路由匹配器（业务层实现，如果为 nil 则跳过枚举路由处理）
    /// - Returns: 是否成功处理
    @discardableResult
    func handleEnumDeepLink<M: RouteMatcher>(
        _ url: URL,
        transition: RouteTransition? = nil,
        matcher: M.Type? = nil
    ) -> Bool {
        // 如果没有提供 matcher，跳过枚举路由处理
        guard let matcher = matcher else {
            print("[DeepLink] 未提供枚举路由匹配器，跳过枚举路由处理")
            return false
        }
        
        // 1. 解析 URL
        guard let (deepLinkInfo, parsedTransition) = DeepLinkHandler.parseWithTransition(url) else {
            print("[DeepLink] 枚举路由解析失败: \(url)")
            return false
        }
        
        // 2. 使用业务匹配器转换为 AppRoute 枚举（通过协议解耦）
        guard let route = matcher.match(
            path: deepLinkInfo.path,
            params: deepLinkInfo.queryItems
        ) else {
            print("[DeepLink] 枚举路由映射失败: \(deepLinkInfo.path)")
            return false
        }
        
        // 3. 执行导航（优先使用传入的 transition，其次使用 URL 中的 transition）
        let finalTransition = transition ?? parsedTransition
        print("[DeepLink] 枚举路由导航: \(deepLinkInfo.path) -> \(route)")
        present(to: route, via: finalTransition)
        return true
    }
    
    /// 处理注册路由深连接（URL -> AutoRoute 路径）
    /// - Parameters:
    ///   - url: 深连接 URL
    ///   - transition: 转场方式（可选）
    /// - Returns: 是否成功处理
    @discardableResult
    func handleRegisteredDeepLink(_ url: URL, transition: RouteTransition? = nil) -> Bool {
        // 1. 解析 URL
        guard let (deepLinkInfo, parsedTransition) = DeepLinkHandler.parseWithTransition(url) else {
            print("[DeepLink] 注册路由解析失败: \(url)")
            return false
        }
        
        // 2. 检查路径是否已注册
        guard RouteRegistry.shared.isRegistered(path: deepLinkInfo.path) else {
            print("[DeepLink] 注册路由未找到: \(deepLinkInfo.path)")
            return false
        }
        
        // 3. 执行导航（优先使用传入的 transition，其次使用 URL 中的 transition）
        let finalTransition = transition ?? parsedTransition
        print("[DeepLink] 注册路由导航: \(deepLinkInfo.path)")
        present(path: deepLinkInfo.path, params: deepLinkInfo.routeParams, via: finalTransition)
        return true
    }
    
    /// 智能深连接处理：自动尝试枚举路由和注册路由（泛型版本）
    /// - Parameters:
    ///   - url: 深连接 URL
    ///   - transition: 转场方式（可选）
    ///   - matcher: 路由匹配器（业务层实现，如果为 nil 则只处理注册路由）
    /// - Returns: 是否成功处理
    /// - Parameters:
    ///   - url: 深连接 URL
    ///   - transition: 转场方式（可选）
    ///   - matcher: 路由匹配器（业务层实现，如果为 nil 则只处理注册路由）
    /// - Returns: 是否成功处理
    @discardableResult
    func handleDeepLink<M: RouteMatcher>(
        _ url: URL,
        transition: RouteTransition? = nil,
        matcher: M.Type? = nil
    ) -> Bool {
        print("[DeepLink] 开始处理深连接: \(url)")
        
        // 1. 优先尝试枚举路由
        if handleEnumDeepLink(url, transition: transition, matcher: matcher) {
            return true
        }
        
        // 2. 尝试注册路由
        if handleRegisteredDeepLink(url, transition: transition) {
            return true
        }
        
        // 3. 均未匹配
        print("[DeepLink] 深连接处理失败，未匹配的路由: \(url)")
        return false
    }
    
    /// 智能深连接处理（简化版本，支持可选 matcher）
    /// - Parameters:
    ///   - url: 深连接 URL
    ///   - transition: 转场方式（可选）
    ///   - matcher: 路由匹配器（如果为 nil 则只处理注册路由）
    /// - Returns: 是否成功处理
    @discardableResult
    func handleDeepLink(
        _ url: URL,
        transition: RouteTransition? = nil,
        matcher: ((String, [String: String]) -> AppRoute?)? = nil
    ) -> Bool {
        print("[DeepLink] 开始处理深连接: \(url)")
        
        // 1. 优先尝试枚举路由（如果提供了 matcher）
        if let matcher = matcher {
            // 解析 URL
            if let (deepLinkInfo, parsedTransition) = DeepLinkHandler.parseWithTransition(url) {
                // 使用 matcher 转换为 AppRoute 枚举
                if let route = matcher(deepLinkInfo.path, deepLinkInfo.queryItems) {
                    let finalTransition = transition ?? parsedTransition
                    print("[DeepLink] 枚举路由导航: \(deepLinkInfo.path) -> \(route)")
                    present(to: route, via: finalTransition)
                    return true
                }
            }
        }
        
        // 2. 尝试注册路由
        if handleRegisteredDeepLink(url, transition: transition) {
            return true
        }
        
        // 3. 均未匹配
        print("[DeepLink] 深连接处理失败，未匹配的路由: \(url)")
        return false
    }
}
