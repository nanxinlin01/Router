//
//  RouterCore.swift
//  Router
//

import SwiftUI
import Combine

// MARK: - Router

/// 路由管理器（仅支持注册路由），统一管理 Push/Sheet/FullScreenCover/Alert/Window系列
final class Router: ObservableObject {

    // MARK: - Navigation State

    /// NavigationStack 路径（存储缓存的 UUID key）
    @Published var path = NavigationPath()
    
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

    /// 由 RootRouter 配置：逐层关闭 windowAlert（支持多层嵌套）
    var windowAlertDismissAction: (() -> Void)?

    // MARK: - Navigate

    /// 显示 Alert（不需要路由目标）
    func showAlert(config: AlertConfig) {
        print("[Router] showAlert 被调用")
        alertConfig = config
    }

    // MARK: - Registered Route Navigate

    /// 直接用路由实例导航（AutoRoute）
    func present(route: AutoRoute, via transition: RouteTransition = .push()) {
        presentRegistered(view: route.routeView, via: transition)
    }

    /// 通过路径导航（从注册中心解析）
    func present(path: String, params: RouteParams, via transition: RouteTransition) {
        guard let view = RouteRegistry.shared.resolve(path: path, params: params) else {
            print("[Router] 未找到注册路由: \(path)")
            return
        }
        presentRegistered(view: view, via: transition)
    }
    
    /// 通过路径导航（无参数重载）
    func present(path: String, via transition: RouteTransition = .push()) {
        present(path: path, params: RouteParams(), via: transition)
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
            // 注册路由也支持系统 Alert
            print("[Router] 注册路由设置 alertConfig")
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
            path.removeLast(popCount)
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
        // 安全清空路径
        if path.count > 0 {
            path.removeLast(path.count)
        }
        sheetPresentation = nil
        fullScreenCoverPresentation = nil
        windowSheetPresentation = nil
        windowPushPresentation = nil
        // 传递给父级，用足够大的数确保全部关闭
        parentDismiss?(Int.max)
    }
}
