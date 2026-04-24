//
//  Router.swift
//  Router
//

import SwiftUI
import Combine

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

// MARK: - Router

/// 泛型路由管理器,统一管理 Push/Sheet/FullScreenCover/Alert
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
        // 5. 还有剩余，传递给父级 Router
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
