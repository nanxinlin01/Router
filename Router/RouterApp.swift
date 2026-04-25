//
//  RouterApp.swift
//  Router
//
//  Created by 南鑫林 on 2026/4/24.
//

import SwiftUI

@main
struct RouterApp: App {
    init() {
        // 注册路由（各模块可在自己的初始化中调用）
        RouteRegistry.shared.register(RegisteredDemoRoute.self)
        RouteRegistry.shared.register(RegisteredAlertRoute.self)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
