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
    case fitContentDemo
    case customAlertDemo(title: String, message: String)
    case toastDemo(icon: String, message: String, isSuccess: Bool)

    var view: AnyView {
        switch self {
        case .detail(let title):
            AnyView(DetailView(title: title))
        case .settings:
            AnyView(SettingsView())
        case .profile(let name):
            AnyView(ProfileView(name: name))
        case .fitContentDemo:
            AnyView(FitContentDemoView())
        case .customAlertDemo(let title, let message):
            AnyView(CustomAlertDemoView(title: title, message: message))
        case .toastDemo(let icon, let message, let isSuccess):
            AnyView(ToastDemoView(icon: icon, message: message, isSuccess: isSuccess))
        }
    }
}

// MARK: - DetailView

struct DetailView: View {
    let title: String
    @EnvironmentObject private var router: Router<AppRoute>

    var body: some View {
        List {
            Section("当前") {
                Text(title)
                    .font(.headline)
            }

            Section("Present") {
                Button("Push 设置页") {
                    router.present(to: .settings)
                }
                Button("Push 详情页 2") {
                    router.present(to: .detail(title: "详情页 2"))
                }
                Button("Sheet 个人页") {
                    router.present(to: .profile(name: "Sheet-Jeremy"), via: .sheet())
                }
                Button("FullScreenCover 个人页") {
                    router.present(to: .profile(name: "Cover-Jeremy"), via: .fullScreenCover)
                }
                Button("Alert 提示") {
                    router.present(to: .detail(title: ""), via: .alert(AlertConfig {
                        Alert(title: Text("提示"), message: Text("来自详情页的 Alert"), dismissButton: .default(Text("确定")))
                    }))
                }
            }

            Section("全部路由嵌套") {
                Button("→ Push") { router.present(to: .settings) }
                Button("→ Sheet") { router.present(to: .profile(name: "详情-Sheet"), via: .sheet()) }
                Button("→ FullScreenCover") { router.present(to: .settings, via: .fullScreenCover) }
                Button("→ WindowSheet") { router.present(to: .profile(name: "详情-WS"), via: .windowSheet()) }
                Button("→ WindowPush") { router.present(to: .settings, via: .windowPush) }
                Button("→ WindowAlert") { router.present(to: .customAlertDemo(title: "详情", message: "详情页的 WindowAlert"), via: .windowAlert) }
                Button("→ WindowFade") { router.present(to: .settings, via: .windowFade) }
            }
            Section("WindowSheet 嵌套") {
                Button("WindowSheet Large") {
                    router.present(to: .profile(name: "详情-WS"), via: .windowSheet())
                }
                Button("WindowSheet 半屏") {
                    router.present(to: .settings, via: .windowSheet(WindowSheetConfig(detent: .half)))
                }
                Button("WindowSheet 多档位") {
                    router.present(
                        to: .profile(name: "详情-WS-多档"),
                        via: .windowSheet(WindowSheetConfig(detents: [.percentage(0.3), .half, .large]))
                    )
                }
                Button("WindowSheet 自适应高度") {
                    router.present(to: .fitContentDemo, via: .windowSheet(WindowSheetConfig(detent: .fitContent)))
                }
            }

            Section("WindowPush 嵌套") {
                Button("WindowPush 设置页") {
                    router.present(to: .settings, via: .windowPush)
                }
                Button("WindowPush 个人页") {
                    router.present(to: .profile(name: "详情-WP"), via: .windowPush)
                }
            }

            Section("WindowAlert") {
                Button("WindowAlert 提示") {
                    router.present(to: .customAlertDemo(title: "提示", message: "来自详情页的 WindowAlert"), via: .windowAlert)
                }
                Button("WindowAlert 嵌套") {
                    router.present(to: .customAlertDemo(title: "嵌套测试", message: "详情页弹出嵌套 WindowAlert"), via: .windowAlert)
                }
            }

            Section("Dismiss") {
                Button("dismiss() — 返回 1 层") {
                    router.dismiss()
                }
                Button("dismiss(2) — 返回 2 层") {
                    router.dismiss(2)
                }
                Button("dismiss(3) — 返回 3 层（跨模态）") {
                    router.dismiss(3)
                }
                Button("dismiss(4) — 返回 4 层（深度穿透）") {
                    router.dismiss(4)
                }
                Button("dismiss(to: 首个详情页)") {
                    router.dismiss(to: .detail(title: "Hello Router!"))
                }
                Button("dismissAll — 返回根页面") {
                    router.dismissAll()
                }
            }
        }
        .navigationTitle("详情")
    }
}

// MARK: - SettingsView

struct SettingsView: View {
    @EnvironmentObject private var router: Router<AppRoute>

    var body: some View {
        List {
            Section("Present") {
                Button("Push 详情页") {
                    router.present(to: .detail(title: "设置→详情"))
                }
                Button("Sheet 个人页") {
                    router.present(to: .profile(name: "Sheet-Guest"), via: .sheet())
                }
                Button("FullScreenCover 个人页") {
                    router.present(to: .profile(name: "Cover-Guest"), via: .fullScreenCover)
                }
                Button("Alert") {
                    router.present(to: .settings, via: .alert(AlertConfig {
                        Alert(title: Text("设置"), message: Text("这是设置页的 Alert"), dismissButton: .default(Text("确定")))
                    }))
                }
            }

            Section("全部路由嵌套") {
                Button("→ Push") { router.present(to: .detail(title: "设置→Push")) }
                Button("→ Sheet") { router.present(to: .profile(name: "设置-Sheet"), via: .sheet()) }
                Button("→ FullScreenCover") { router.present(to: .profile(name: "设置-Cover"), via: .fullScreenCover) }
                Button("→ WindowSheet") { router.present(to: .detail(title: "设置-WS"), via: .windowSheet()) }
                Button("→ WindowPush") { router.present(to: .profile(name: "设置-WP"), via: .windowPush) }
                Button("→ WindowAlert") { router.present(to: .customAlertDemo(title: "设置", message: "设置页的 WindowAlert"), via: .windowAlert) }
                Button("→ WindowFade") { router.present(to: .detail(title: "设置-Fade"), via: .windowFade) }
            }

            Section("WindowSheet 嵌套") {
                Button("WindowSheet Large") {
                    router.present(to: .profile(name: "设置-WS"), via: .windowSheet())
                }
                Button("WindowSheet 半屏") {
                    router.present(to: .detail(title: "设置-WS-半屏"), via: .windowSheet(WindowSheetConfig(detent: .half)))
                }
                Button("WindowSheet 多档位") {
                    router.present(
                        to: .profile(name: "设置-WS-多档"),
                        via: .windowSheet(WindowSheetConfig(detents: [.half, .large]))
                    )
                }
                Button("WindowSheet 自适应高度") {
                    router.present(to: .fitContentDemo, via: .windowSheet(WindowSheetConfig(detent: .fitContent)))
                }
            }

            Section("WindowPush 嵌套") {
                Button("WindowPush 详情页") {
                    router.present(to: .detail(title: "设置-WP"), via: .windowPush)
                }
                Button("WindowPush 个人页") {
                    router.present(to: .profile(name: "设置-WP"), via: .windowPush)
                }
            }

            Section("Dismiss") {
                Button("dismiss() — 返回 1 层") {
                    router.dismiss()
                }
                Button("dismiss(2) — 返回 2 层") {
                    router.dismiss(2)
                }
                Button("dismiss(3) — 返回 3 层（跨模态）") {
                    router.dismiss(3)
                }
                Button("dismiss(4) — 返回 4 层（深度穿透）") {
                    router.dismiss(4)
                }
                Button("dismissAll — 返回根页面") {
                    router.dismissAll()
                }
            }
        }
        .navigationTitle("设置")
    }
}

// MARK: - FitContentDemoView

/// 自适应高度演示视图（固定内容，不使用 List/ScrollView）
struct FitContentDemoView: View {
    @EnvironmentObject private var router: Router<AppRoute>

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 48))
                .foregroundStyle(.green)

            Text("操作成功")
                .font(.title2.bold())

            Text("您的请求已处理完成\n这是一个自适应高度的 WindowSheet 演示")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Divider()

            Button {
                router.dismiss()
            } label: {
                Text("知道了")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(.blue)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding(24)
    }
}

// MARK: - CustomAlertDemoView

/// 自定义 Alert 演示视图（用于 windowAlert）
struct CustomAlertDemoView: View {
    let title: String
    let message: String
    @EnvironmentObject private var router: Router<AppRoute>

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 4) {
                Text(title)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 20)
            .padding(.horizontal, 16)
            .padding(.bottom, 16)

            Divider()

            HStack(spacing: 0) {
                Button {
                    router.dismiss()
                } label: {
                    Text("取消")
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                }
                Divider().frame(height: 44)
                Button {
                    router.present(to: .customAlertDemo(title: "嵌套 Alert", message: "这是第二层 WindowAlert"), via: .windowAlert)
                } label: {
                    Text("确定")
                        .bold()
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                }
            }

            Divider()

            Button {
                router.present(to: .customAlertDemo(title: "嵌套 Alert", message: "这是第二层 WindowAlert"), via: .windowAlert)
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("再弹一个 WindowAlert")
                }
                .font(.subheadline)
                .foregroundColor(.blue)
            }
            .padding(.top, 8)

            Divider()
                .padding(.top, 8)

            Button {
                router.present(to: .settings)
            } label: {
                HStack {
                    Image(systemName: "arrow.right.circle.fill")
                    Text("Push 设置页")
                }
                .font(.subheadline)
                .foregroundColor(.orange)
            }
            .padding(.vertical, 8)
        }
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .frame(width: 270)
    }
}

// MARK: - ProfileView

struct ProfileView: View {
    let name: String
    @EnvironmentObject private var router: Router<AppRoute>

    var body: some View {
        List {
            Section {
                HStack {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 50))
                        .foregroundStyle(.blue)
                    VStack(alignment: .leading) {
                        Text(name).font(.title2.bold())
                        Text("模态页面（独立导航栈）")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Section("Present（模态内导航）") {
                Button("Push 详情页") {
                    router.present(to: .detail(title: "模态内→详情"))
                }
                Button("Push 设置页") {
                    router.present(to: .settings)
                }
                Button("Sheet（嵌套模态）") {
                    router.present(to: .profile(name: "嵌套-Sheet"), via: .sheet())
                }
                Button("FullScreenCover（嵌套模态）") {
                    router.present(to: .profile(name: "嵌套-Cover"), via: .fullScreenCover)
                }
                Button("Alert") {
                    router.present(to: .profile(name: ""), via: .alert(AlertConfig {
                        Alert(title: Text("个人页"), message: Text("来自个人页的 Alert"), dismissButton: .default(Text("确定")))
                    }))
                }
            }

            Section("全部路由嵌套") {
                Button("→ Push") { router.present(to: .detail(title: "个人→Push")) }
                Button("→ Sheet") { router.present(to: .profile(name: "个人-Sheet"), via: .sheet()) }
                Button("→ FullScreenCover") { router.present(to: .settings, via: .fullScreenCover) }
                Button("→ WindowSheet") { router.present(to: .detail(title: "个人-WS"), via: .windowSheet()) }
                Button("→ WindowPush") { router.present(to: .settings, via: .windowPush) }
                Button("→ WindowAlert") { router.present(to: .customAlertDemo(title: "个人", message: "个人页的 WindowAlert"), via: .windowAlert) }
                Button("→ WindowFade") { router.present(to: .settings, via: .windowFade) }
            }

            Section("WindowSheet 嵌套") {
                Button("WindowSheet Large") {
                    router.present(to: .profile(name: "嵌套-WS"), via: .windowSheet())
                }
                Button("WindowSheet 半屏") {
                    router.present(to: .settings, via: .windowSheet(WindowSheetConfig(detent: .half)))
                }
                Button("WindowSheet 多档位") {
                    router.present(
                        to: .profile(name: "嵌套-WS-多档"),
                        via: .windowSheet(WindowSheetConfig(detents: [.percentage(0.3), .half, .large]))
                    )
                }
                Button("WindowSheet 自适应高度") {
                    router.present(to: .fitContentDemo, via: .windowSheet(WindowSheetConfig(detent: .fitContent)))
                }
            }

            Section("WindowPush 嵌套") {
                Button("WindowPush 详情页") {
                    router.present(to: .detail(title: "嵌套-WP"), via: .windowPush)
                }
                Button("WindowPush 设置页") {
                    router.present(to: .settings, via: .windowPush)
                }
            }

            Section("WindowAlert") {
                Button("WindowAlert 提示") {
                    router.present(to: .customAlertDemo(title: "个人页", message: "来自个人页的 WindowAlert"), via: .windowAlert)
                }
                Button("WindowAlert 嵌套") {
                    router.present(to: .customAlertDemo(title: "个人-嵌套", message: "个人页弹出嵌套 WindowAlert"), via: .windowAlert)
                }
            }

            Section("Dismiss") {
                Button("dismiss() — 关闭 1 层") {
                    router.dismiss()
                }
                Button("dismiss(2) — 关闭 2 层（跨模态）") {
                    router.dismiss(2)
                }
                Button("dismiss(3) — 关闭 3 层（穿透多层）") {
                    router.dismiss(3)
                }
                Button("dismiss(4) — 关闭 4 层（深度穿透）") {
                    router.dismiss(4)
                }
                Button("dismiss(to: 首个详情页)（跨模态回退）") {
                    router.dismiss(to: .detail(title: "Hello Router!"))
                }
                Button("dismissAll — 返回根页面（穿透所有模态）") {
                    router.dismissAll()
                }
            }
        }
        .navigationTitle("个人")
    }
}

// MARK: - ToastDemoView

struct ToastDemoView: View {
    let icon: String
    let message: String
    let isSuccess: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(isSuccess ? .green : .red)

            Text(message)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: 4)
        .padding(.horizontal, 16)
    }
}

// MARK: - RegisterableRoute 示例

/// 注册路由示例：演示独立于 AppRoute 枚举的动态路由
struct RegisteredDemoRoute: RegisterableRoute {
    static var routePath = "demo/registered"
    var title: String

    static func create(from params: [String: String]) -> Self? {
        RegisteredDemoRoute(title: params["title"] ?? "Default")
    }

    var routeView: AnyView {
        AnyView(RegisteredDemoView(title: title))
    }
}

// MARK: - RegisteredDemoView

struct RegisteredDemoView: View {
    let title: String
    @EnvironmentObject private var router: Router<AppRoute>

    var body: some View {
        List {
            Section {
                HStack {
                    Image(systemName: "puzzlepiece.extension.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.orange)
                    VStack(alignment: .leading) {
                        Text("注册路由页面")
                            .font(.title2.bold())
                        Text(title)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Section("信息") {
                Text("这是一个通过 RegisterableRoute 协议注册的路由页面")
                Text("不需要修改 AppRoute 枚举")
                Text("支持所有转场方式")
            }

            Section("Present") {
                Button("Push 设置页") {
                    router.present(to: .settings)
                }
                Button("注册路由 Push 自己") {
                    router.present(route: RegisteredDemoRoute(title: "嵌套-\(title)"))
                }
                Button("注册路由 Sheet") {
                    router.present(route: RegisteredDemoRoute(title: "Sheet-\(title)"), via: .sheet())
                }
                Button("路径导航 WindowPush") {
                    router.present(path: "demo/registered", params: ["title": "Path-WP"], via: .windowPush)
                }
            }

            Section("Dismiss") {
                Button("dismiss()") {
                    router.dismiss()
                }
                Button("dismissAll") {
                    router.dismissAll()
                }
            }
        }
        .navigationTitle("注册路由")
    }
}

// MARK: - RegisteredAlertRoute

/// 注册路由示例：Alert 弹窗风格
struct RegisteredAlertRoute: RegisterableRoute {
    static var routePath = "demo/alert"
    var title: String
    var message: String

    static func create(from params: [String: String]) -> Self? {
        RegisteredAlertRoute(
            title: params["title"] ?? "提示",
            message: params["message"] ?? ""
        )
    }

    var routeView: AnyView {
        AnyView(RegisteredAlertDemoView(title: title, message: message))
    }
}

// MARK: - RegisteredAlertDemoView

struct RegisteredAlertDemoView: View {
    let title: String
    let message: String
    @EnvironmentObject private var router: Router<AppRoute>

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 4) {
                Text(title)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 20)
            .padding(.horizontal, 16)
            .padding(.bottom, 16)

            Divider()

            HStack(spacing: 0) {
                Button {
                    router.dismiss()
                } label: {
                    Text("取消")
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                }
                Divider().frame(height: 44)
                Button {
                    router.present(
                        route: RegisteredAlertRoute(title: "嵌套 Alert", message: "这是注册路由的嵌套 WindowAlert"),
                        via: .windowAlert
                    )
                } label: {
                    Text("确定")
                        .bold()
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                }
            }

            Divider()

            Button {
                router.present(to: .detail(title: "Alert内→详情"))
            } label: {
                HStack {
                    Image(systemName: "arrow.right.circle.fill")
                    Text("Push 详情页")
                }
                .font(.subheadline)
                .foregroundColor(.orange)
            }
            .padding(.top, 8)

            Divider()
                .padding(.top, 8)

            Button {
                router.present(route: RegisteredDemoRoute(title: "Alert内→注册路由"))
            } label: {
                HStack {
                    Image(systemName: "puzzlepiece.extension.fill")
                    Text("Push 注册路由页")
                }
                .font(.subheadline)
                .foregroundColor(.purple)
            }
            .padding(.bottom, 8)
        }
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .frame(width: 270)
    }
}
