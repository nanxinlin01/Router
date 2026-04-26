//
//  RouterApp.swift
//  Router
//
//  Created by 南鑫林 on 2026/4/24.
//

import SwiftUI

@main
struct RouterApp: App {
    // 注意：不能在 App 级别使用 @EnvironmentObject，因为 router 是在 RootRouter 中创建的
    // URL 处理将在 ContentView 中通过 onOpenURL 完成
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
