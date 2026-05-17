//
//  RouterCore.swift
//  Router
//

import SwiftUI
import Combine

// MARK: - Router

/// 泛型路由管理器，统一管理 Push/Sheet/FullScreenCover/Alert/Window系列
final class Router<Destination: Routable>: ObservableObject {

    // MARK: - Navigation State

    /// NavigationStack 路径
    @Published var path = NavigationPath()

    /// 路由栈记录（用于 dismiss(to:) 查找）
    private var pathStack: [Destination] = []
    
    /// Push 配置（用于控制是否隐藏 TabBar）
    @Published var pushConfig: PushConfig?

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
    /// 父级 dismiss(to:) 链（类型擦除，支持泛型）
    var parentDismissTo: ((Any) -> Void)?

    /// 由 RootRouter 配置：逐层关闭 windowAlert（支持多层嵌套）
    var windowAlertDismissAction: (() -> Void)?

    // MARK: - Navigate

    /// 显示 Alert（不需要路由目标）
    func showAlert(config: AlertConfig) {
        print("[Router] showAlert 被调用")
        alertConfig = config
    }

    /// 枚举路由导航（完全泛型化，不依赖具体业务类型）
    func present(to destination: Destination, via transition: RouteTransition = .push()) {
        switch transition {
        case .push(let config):
            pushConfig = config
            path.append(destination)
            pathStack.append(destination)
        case .sheet(let config):
            sheetPresentation = RoutePresentation(
                view: AnyView(NestedRouter(destination: destination, parentRouter: self)),
                sheetConfig: config)
        case .fullScreenCover:
            fullScreenCoverPresentation = RoutePresentation(
                view: AnyView(NestedRouter(destination: destination, parentRouter: self)))
        case .alert(let config):
            print("[Router] 枚举路由设置 alertConfig")
            alertConfig = config
        case .windowSheet(let config):
            windowSheetPresentation = RoutePresentation(
                view: AnyView(NestedRouter(destination: destination, parentRouter: self)),
                rawView: AnyView(destination.view),
                windowSheetConfig: config)
        case .windowPush:
            windowPushPresentation = RoutePresentation(
                view: AnyView(NestedRouter(destination: destination, parentRouter: self)))
        case .windowAlert:
            windowAlertPresentation = RoutePresentation(
                view: AnyView(NestedRouter(destination: destination, parentRouter: self)))
        case .windowToast(let config):
            windowToastPresentation = RoutePresentation(
                view: AnyView(destination.view),
                windowToastConfig: config)
        case .windowFade:
            windowFadePresentation = RoutePresentation(
                view: AnyView(NestedRouter(destination: destination, parentRouter: self)))
        }
    }

    // MARK: - Registered Route Navigate

    /// 直接用路由实例导航（AutoRoute）
    func present(route: AutoRoute, via transition: RouteTransition = .push()) {
        presentRegistered(view: route.routeView, via: transition)
    }

    /// 通过路径导航（从注册中心解析）
    func present(path: String, params: RouteParams = RouteParams(), via transition: RouteTransition = .push()) {
        guard let view = RouteRegistry.shared.resolve(path: path, params: params) else {
            print("[Router] 未找到注册路由: \(path)")
            return
        }
        presentRegistered(view: view, via: transition)
    }

    /// 内部统一处理注册路由呈现（泛型化版本）
    private func presentRegistered(view: AnyView, via transition: RouteTransition) {
        switch transition {
        case .push:
            let key = UUID().uuidString
            RouteRegistry.shared.cacheView(view, forKey: key)
            path.append(key)
        case .sheet(let config):
            sheetPresentation = RoutePresentation(
                view: AnyView(NestedRouter(view: view, parentRouter: self)),
                sheetConfig: config)
        case .fullScreenCover:
            fullScreenCoverPresentation = RoutePresentation(
                view: AnyView(NestedRouter(view: view, parentRouter: self)))
        case .windowSheet(let config):
            windowSheetPresentation = RoutePresentation(
                view: AnyView(NestedRouter(view: view, parentRouter: self)),
                rawView: view,
                windowSheetConfig: config)
        case .windowPush:
            windowPushPresentation = RoutePresentation(
                view: AnyView(NestedRouter(view: view, parentRouter: self)))
        case .windowAlert:
            windowAlertPresentation = RoutePresentation(
                view: AnyView(NestedRouter(view: view, parentRouter: self)))
        case .alert(let config):
            alertConfig = config
        case .windowToast(let config):
            windowToastPresentation = RoutePresentation(
                view: view,
                windowToastConfig: config)
        case .windowFade:
            windowFadePresentation = RoutePresentation(
                view: AnyView(NestedRouter(view: view, parentRouter: self)))
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
        // 3. pop 导航栈（增强边界检查，防止异步状态不一致导致的越界）
        let popCount = min(remaining, path.count)
        if popCount > 0 {
            // 使用 removeLast(_:) 的安全包装，确保即使在并发调用下也不会崩溃
            let safePopCount = min(popCount, path.count, pathStack.count)
            if safePopCount > 0 {
                path.removeLast(safePopCount)
                pathStack.removeLast(safePopCount)
                remaining -= safePopCount
            }
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
        // 安全清空路径
        if path.count > 0 {
            path.removeLast(path.count)
        }
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
            // 调用父级的 dismissTo（类型擦除）
            parentDismissTo?(destination as Any)
        }
    }
}
