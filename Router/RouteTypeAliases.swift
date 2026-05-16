//
//  RouteTypeAliases.swift
//  Router
//
//  业务层类型别名：简化枚举路由的泛型参数书写

import SwiftUI

// MARK: - 枚举路由类型别名（业务层专用）

/// 枚举路由根路由器（自动绑定 AppRoute 类型）
/// 使用此别名可以避免在业务层重复写 `RootRouter<AppRoute, Content>`
typealias EnumRootRouter<Content: View> = RootRouter<AppRoute, Content>

/// 枚举路由路由器（自动绑定 AppRoute 类型）
/// 使用此别名可以避免在业务层重复写 `Router<AppRoute>`
typealias EnumRouter = Router<AppRoute>
