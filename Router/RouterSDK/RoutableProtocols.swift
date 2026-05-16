//
//  RoutableProtocols.swift
//  Router
//

import SwiftUI

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
