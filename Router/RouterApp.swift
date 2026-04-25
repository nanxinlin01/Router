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
        // 自动扫描并注册所有 RouteAutoRegistrar（ObjC Runtime）
        RouteRegistry.shared.autoRegisterAll()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
