//
//  AppRoute.swift
//  Router
//

import SwiftUI

// MARK: - AppRoute

/// 应用路由枚举：定义所有可导航页面
enum AppRoute: Routable {
    case detail(title: String)
    case settings
    case profile(name: String)

    @ViewBuilder
    var body: some View {
        switch self {
        case .detail(let title):
            DetailView(title: title)
        case .settings:
            SettingsView()
        case .profile(let name):
            ProfileView(name: name)
        }
    }
}

// MARK: - 示例页面

struct DetailView: View {
    let title: String
    @EnvironmentObject private var router: Router<AppRoute>

    var body: some View {
        VStack(spacing: 20) {
            Text(title)
                .font(.largeTitle)

            Button("Push 设置页") {
                router.navigate(to: .settings)
            }

            Button("Sheet 展示个人页") {
                router.navigate(to: .profile(name: "Jeremy"), via: .sheet)
            }

            Button("返回上一页") {
                router.pop()
            }

            Button("返回根页面") {
                router.popToRoot()
            }
        }
        .navigationTitle("详情")
    }
}

struct SettingsView: View {
    @EnvironmentObject private var router: Router<AppRoute>

    var body: some View {
        VStack(spacing: 20) {
            Text("⚙️ 设置")
                .font(.largeTitle)

            Button("显示 Alert") {
                router.showAlert(title: "提示", message: "这是一个 Alert 示例")
            }

            Button("FullScreenCover 展示个人页") {
                router.navigate(to: .profile(name: "Guest"), via: .fullScreenCover)
            }

            Button("返回根页面") {
                router.popToRoot()
            }
        }
        .navigationTitle("设置")
    }
}

struct ProfileView: View {
    let name: String
    @EnvironmentObject private var router: Router<AppRoute>

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(.blue)

            Text(name)
                .font(.title)

            Button("关闭") {
                router.dismissSheet()
                router.dismissFullScreenCover()
            }
        }
    }
}
