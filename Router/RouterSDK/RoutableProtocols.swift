//
//  RoutableProtocols.swift
//  Router
//

import SwiftUI

// MARK: - Routable Protocol

/// 路由目标协议：所有可路由页面必须遵循此协议
protocol Routable: Hashable, Identifiable {
    /// 纯视图（不包含 RootRouter）
    var view: AnyView { get }
}

extension Routable {
    var id: Self { self }
}

// MARK: - EmptyRoute

/// 空路由枚举（用于仅使用注册路由的场景）
/// 当项目不使用枚举路由，只使用 AutoRoute 注册路由时，可使用此占位类型
enum EmptyRoute: Routable {
    var view: AnyView {
        AnyView(EmptyView())
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

// MARK: - 注册路由类型别名（组件提供）

/// 注册路由根路由器（仅使用 AutoRoute 注册路由的场景）
/// 使用此别名可以避免指定空的 Destination 类型
/// 注意：使用此类型时，只能通过 `router.present(path:)` 或 `router.present(route:)` 导航
typealias RegisteredRootRouter<Content: View> = RootRouter<EmptyRoute, Content>

/// 注册路由路由器（仅使用注册路由的场景）
/// 使用此别名可以避免在业务层重复写 `Router<EmptyRoute>`
typealias RegisteredRouter = Router<EmptyRoute>
