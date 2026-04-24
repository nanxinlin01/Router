//
//  ContentView.swift
//  Router
//
//  Created by 南鑫林 on 2026/4/24.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var router = Router<AppRoute>()

    var body: some View {
        RouterView(router: router) {
            HomeView()
        }
        .environmentObject(router)
    }
}

// MARK: - HomeView

struct HomeView: View {
    @EnvironmentObject private var router: Router<AppRoute>

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "point.topleft.down.to.point.bottomright.curvepath.fill")
                .font(.system(size: 60))
                .foregroundStyle(.blue)

            Text("SwiftUI Router")
                .font(.largeTitle.bold())

            VStack(spacing: 12) {
                Button("Push 详情页") {
                    router.navigate(to: .detail(title: "Hello Router!"))
                }
                .buttonStyle(.borderedProminent)

                Button("Sheet 个人页") {
                    router.navigate(to: .profile(name: "Jeremy"), via: .sheet)
                }
                .buttonStyle(.bordered)

                Button("FullScreenCover 设置页") {
                    router.navigate(to: .settings, via: .fullScreenCover)
                }
                .buttonStyle(.bordered)

                Button("显示 Alert") {
                    router.showAlert(
                        AlertConfig(
                            title: "欢迎",
                            message: "这是路由器 Alert 演示",
                            primaryButton: .default(Text("好的")),
                            secondaryButton: .cancel(Text("取消"))
                        )
                    )
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .navigationTitle("首页")
    }
}

#Preview {
    ContentView()
}
