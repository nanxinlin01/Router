//
//  RouterViews.swift
//  Router
//

import SwiftUI

// MARK: - RootRouter

/// 根路由器视图（泛型化，支持任意 Routable 类型）
/// - Push: 在同一个 NavigationStack 内导航
/// - Sheet/FullScreenCover: 自动包装新的 RootRouter——无限嵌套
struct RootRouter<Destination: Routable, Content: View>: View {
    @StateObject private var router: Router<Destination>
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
        self._router = StateObject(wrappedValue: Router<Destination>())
        self.content = content
    }
    
    // MARK: - Helper Methods
    
    /// 构建枚举路由视图（拆分表达式以解决编译器类型检查超时）
    private static func makeEnumRouteView(destination: Destination, config: PushConfig?) -> AnyView {
        let view = destination.view
        if let config = config {
            return AnyView(view.toolbar(config.hidesTabBar ? .hidden : .visible, for: .tabBar))
        } else {
            return AnyView(view)
        }
    }
    
    /// 构建注册路由视图（拆分表达式以解决编译器类型检查超时）
    private static func makeRegisteredView(view: AnyView, config: PushConfig?) -> AnyView {
        if let config = config {
            return AnyView(view.toolbar(config.hidesTabBar ? .hidden : .visible, for: .tabBar))
        } else {
            return AnyView(view)
        }
    }
    
    /// 构建注册路由或错误提示（进一步拆分表达式）
    private static func makeRegisteredRouteView(key: String, config: PushConfig?) -> AnyView {
        guard let view = RouteRegistry.shared.resolve(path: key) else {
            return AnyView(Text("路由未注册: \(key)"))
        }
        
        if let config = config {
            return AnyView(view.toolbar(config.hidesTabBar ? .hidden : .visible, for: .tabBar))
        } else {
            return AnyView(view)
        }
    }
    
    var body: some View {
        NavigationStack(path: $router.path) {
            content()
                .navigationDestination(for: Destination.self) { destination in
                    // 枚举路由：应用 push 配置
                    Self.makeEnumRouteView(destination: destination, config: router.pushConfig)
                }
                .navigationDestination(for: String.self) { key in
                    Self.makeRegisteredRouteView(key: key, config: router.pushConfig)
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
            print("[RootRouter] windowSheetPresentation onChange 触发, presentation: \(router.windowSheetPresentation != nil ? "存在" : "nil")")
            if let presentation = router.windowSheetPresentation {
                print("[RootRouter] 调用 windowSheetCoordinator.present")
                windowSheetCoordinator.present(presentation: presentation) {
                    print("[RootRouter] windowSheetCoordinator dismiss 回调")
                    router.windowSheetPresentation = nil
                }
            } else {
                print("[RootRouter] 调用 windowSheetCoordinator.dismissIfNeeded")
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
            // 将 Environment 中的 dismissTo 闭包传递给 Router
            router.parentDismissTo = parentDismissTo
        }
    }
}

// MARK: - NestedRouter

/// 嵌套路由器：自动包装新的 RootRouter，支持枚举路由和注册路由（泛型化）
struct NestedRouter<Destination: Routable>: View {
    let content: AnyView
    let parentRouter: Router<Destination>

    /// 枚举路由便捷初始化
    init(destination: Destination, parentRouter: Router<Destination>) {
        self.content = destination.view
        self.parentRouter = parentRouter
    }

    /// 注册路由 / AnyView 初始化
    init(view: AnyView, parentRouter: Router<Destination>) {
        self.content = view
        self.parentRouter = parentRouter
    }

    var body: some View {
        RootRouter<Destination, AnyView> {
            content
        }
        .environment(\.parentRouterDismiss) { count in
            parentRouter.dismiss(count)
        }
        .environment(\.parentRouterDismissTo) { destination in
            // 将父级的 dismissTo 适配为当前类型
            if let typedDest = destination as? Destination {
                parentRouter.dismiss(to: typedDest)
            } else {
                // 类型不匹配时，直接传递给父级
                parentRouter.parentDismissTo?(destination)
            }
        }
    }
}
