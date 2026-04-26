//
//  RouterApp.swift
//  Router
//
//  Created by 南鑫林 on 2026/4/24.
//

import SwiftUI

@main
struct RouterApp: App {
    @EnvironmentObject private var router: Router<AppRoute>
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in
                    // 处理 URL Scheme 深连接（智能模式：自动尝试枚举路由和注册路由）
                    // DeepLinkInfo 已包含 scheme 字段，可识别不同 scheme
                    router.handleDeepLink(url, matcher: AppRouteDeepLinkMapper.self)
                }
                .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { userActivity in
                    // 处理 Universal Links（https://example.com/...）
                    guard let url = userActivity.webpageURL else { return }
                    print("[Universal Link] 收到链接: \(url)")
                    
                    // Universal Links 通常是 https/https scheme，可以与 app scheme 区分处理
                    router.handleDeepLink(url, matcher: AppRouteDeepLinkMapper.self)
                }
        }
    }
}
