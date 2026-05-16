//
//  RouteRegistry.swift
//  Router
//

import SwiftUI
import ObjectiveC

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
    func resolve(path: String, params: RouteParams) -> AnyView? {
        // 先从缓存中查找（不删除，因为可能会被多次调用）
        if let cached = viewCache[path] {
            return cached
        }
        return factories[path]?(params)
    }
    
    /// 解析路径为视图（无参数重载）
    func resolve(path: String) -> AnyView? {
        resolve(path: path, params: RouteParams())
    }

    /// 检查路径是否已注册
    func isRegistered(path: String) -> Bool {
        factories[path] != nil
    }
    
    /// 获取所有已注册的路径（用于调试）
    var registeredPaths: [String] {
        Array(factories.keys)
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
            guard let routeClass = cls as? AutoRoute.Type else { continue }
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
