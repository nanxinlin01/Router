//
//  URLSchemeExamples.swift
//  Router
//
//  URL Scheme 使用示例

import SwiftUI

// MARK: - 使用示例

/// 示例 1: 在 App 入口区分不同 scheme
struct AppEntryExamples {
    
    /// 示例 1.1: 只处理特定的 app scheme
    static func handleOnlyAppScheme(router: EnumRouter, url: URL) {
        // 方式 A: 使用 Router 的 scheme 过滤方法
        router.handleDeepLinkIfSchemeMatches(
            url,
            allowedScheme: "myapp",
            matcher: AppRouteDeepLinkMapper.self
        )
        
        // 方式 B: 手动检查后处理
        if DeepLinkHandler.matchesScheme(url, "myapp") {
            router.handleDeepLink(url, matcher: AppRouteDeepLinkMapper.self)
        }
    }
    
    /// 示例 1.2: 处理多个 scheme
    static func handleMultipleSchemes(router: EnumRouter, url: URL) {
        // 允许 myapp 和 router 两个 scheme
        router.handleDeepLinkIfSchemeMatches(
            url,
            allowedSchemes: ["myapp", "router"],
            matcher: AppRouteDeepLinkMapper.self
        )
    }
    
    /// 示例 1.3: 根据 scheme 使用不同的匹配器
    static func handleDifferentSchemes(router: EnumRouter, url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
              let scheme = components.scheme else {
            return
        }
        
        switch scheme.lowercased() {
        case "myapp":
            // 主 app scheme，使用标准匹配器
            router.handleDeepLink(url, matcher: AppRouteDeepLinkMapper.self)
            
        case "promo":
            // 促销活动 scheme，使用特殊匹配器
            router.handleDeepLink(url, matcher: PromoRouteMapper.self)
            
        case "admin":
            // 管理后台 scheme，使用管理员匹配器
            router.handleDeepLink(url, matcher: AdminRouteMapper.self)
            
        default:
            // 其他 scheme，不处理
            print("[App] 忽略未知 scheme: \(scheme)")
        }
    }
}

// MARK: - 业务层使用示例

/// 示例 2: 在业务逻辑中使用 scheme 信息
struct BusinessLogicExamples {
    
    /// 示例 2.1: 记录 scheme 来源用于统计
    static func logSchemeSource(url: URL) {
        guard let deepLinkInfo = DeepLinkHandler.parse(url) else { return }
        
        if let scheme = deepLinkInfo.scheme {
            // 记录不同 scheme 的打开次数
            Analytics.track(event: "deep_link_opened", properties: [
                "scheme": scheme,
                "path": deepLinkInfo.path,
                "source": getSourceName(for: scheme)
            ])
        }
    }
    
    /// 示例 2.2: 根据 scheme 应用不同的配置
    static func applySchemeConfig(url: URL) -> DeepLinkConfig {
        guard let deepLinkInfo = DeepLinkHandler.parse(url) else {
            return DeepLinkConfig.default
        }
        
        switch deepLinkInfo.scheme {
        case "myapp":
            return DeepLinkConfig(shouldShowWelcome: false, trackAnalytics: true)
        case "promo":
            return DeepLinkConfig(shouldShowWelcome: true, trackAnalytics: true)
        case "test":
            return DeepLinkConfig(shouldShowWelcome: false, trackAnalytics: false)
        default:
            return DeepLinkConfig.default
        }
    }
    
    /// 示例 2.3: 过滤特定 scheme 的链接
    static func shouldHandleURL(_ url: URL) -> Bool {
        // 只处理 myapp scheme，忽略其他所有链接
        DeepLinkHandler.matchesScheme(url, "myapp")
    }
    
    private static func getSourceName(for scheme: String) -> String {
        switch scheme {
        case "myapp": return "App Deep Link"
        case "promo": return "Promotion Campaign"
        case "admin": return "Admin Panel"
        default: return "Unknown"
        }
    }
}

// MARK: - 辅助类型

/// 深连接配置
struct DeepLinkConfig {
    let shouldShowWelcome: Bool
    let trackAnalytics: Bool
    
    static let `default` = DeepLinkConfig(shouldShowWelcome: false, trackAnalytics: true)
}

/// 模拟分析追踪
struct Analytics {
    static func track(event: String, properties: [String: Any]) {
        print("[Analytics] Event: \(event), Properties: \(properties)")
    }
}

// MARK: - 示例匹配器（实际项目中在 AppRoute.swift 中定义）

/// 促销活动路由匹配器
enum PromoRouteMapper: RouteMatcher {
    static func match(path: String, params: [String: String]) -> AppRoute? {
        // 促销活动专用的路由映射
        switch path {
        case "sale", "promotion":
            return .detail(title: "促销活动: \(params["name"] ?? "未知")")
        default:
            return nil
        }
    }
}

/// 管理员路由匹配器
enum AdminRouteMapper: RouteMatcher {
    static func match(path: String, params: [String: String]) -> AppRoute? {
        // 管理员专用的路由映射
        switch path {
        case "dashboard":
            return .settings
        case "users":
            return .profile(name: "Admin")
        default:
            return nil
        }
    }
}

// MARK: - SwiftUI View 中的使用示例

/// 示例 3: 在 View 中测试不同的 scheme
struct URLSchemeTestView: View {
    @EnvironmentObject private var router: EnumRouter
    
    var body: some View {
        List {
            Section("Scheme 过滤测试") {
                Button("处理 myapp:// 链接") {
                    guard let url = URL(string: "myapp://app/settings") else { return }
                    // 只处理 myapp scheme
                    router.handleDeepLinkIfSchemeMatches(url, allowedScheme: "myapp", matcher: AppRouteDeepLinkMapper.self)
                }
                
                Button("忽略 other:// 链接") {
                    guard let url = URL(string: "other://app/settings") else { return }
                    // 不会处理，因为 scheme 不匹配
                    let handled = router.handleDeepLinkIfSchemeMatches(url, allowedScheme: "myapp", matcher: AppRouteDeepLinkMapper.self)
                    print("是否处理: \(handled)") // 输出: false
                }
                
                Button("处理多个 scheme") {
                    guard let url = URL(string: "router://app/detail?title=Test") else { return }
                    // 允许 myapp 和 router 两个 scheme
                    router.handleDeepLinkIfSchemeMatches(
                        url,
                        allowedSchemes: ["myapp", "router"],
                        matcher: AppRouteDeepLinkMapper.self
                    )
                }
            }
            
            Section("手动检查 Scheme") {
                Button("检查 URL 的 scheme") {
                    guard let url = URL(string: "myapp://app/settings?transition=sheet") else { return }
                    
                    if DeepLinkHandler.matchesScheme(url, "myapp") {
                        print("✅ 这是 myapp scheme")
                    }
                    
                    if DeepLinkHandler.matchesAnyScheme(url, ["myapp", "router", "promo"]) {
                        print("✅ 匹配允许的 scheme 列表")
                    }
                }
                
                Button("解析 URL 获取 scheme") {
                    guard let url = URL(string: "promo://sale?name=双十一&transition=windowSheet") else { return }
                    
                    if let info = DeepLinkHandler.parse(url) {
                        print("Scheme: \(info.scheme ?? "无")")
                        print("Path: \(info.path)")
                        print("Params: \(info.queryItems)")
                        
                        // 根据 scheme 做不同处理
                        if info.scheme == "promo" {
                            print("这是促销活动链接")
                        }
                    }
                }
            }
        }
        .navigationTitle("URL Scheme 测试")
    }
}
