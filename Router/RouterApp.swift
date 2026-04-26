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
                    // 处理深连接（智能模式：自动尝试枚举路由和注册路由）
                    // 使用 AppRouteDeepLinkMapper 作为枚举路由匹配器
                    router.handleDeepLink(url, matcher: AppRouteDeepLinkMapper.self)
                }
        }
    }
}
