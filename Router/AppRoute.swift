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

// MARK: - RegisterableRoute 示例（AutoRoute 子类）

/// 注册路由示例：演示独立于 AppRoute 枚举的动态路由
class RegisteredDemoRoute: AutoRoute {
    override class var routePath: String { "demo/registered" }
    let title: String

    init(title: String) {
        self.title = title
        super.init()
    }

    override class func createInstance(from params: RouteParams) -> AutoRoute? {
        RegisteredDemoRoute(title: params["title", default: "Default"])
    }

    override var routeView: AnyView {
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
                    router.present(path: "demo/registered", params: RouteParams(["title": "Path-WP"]), via: .windowPush)
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
class RegisteredAlertRoute: AutoRoute {
    override class var routePath: String { "demo/alert" }
    let title: String
    let message: String

    init(title: String, message: String) {
        self.title = title
        self.message = message
        super.init()
    }

    override class func createInstance(from params: RouteParams) -> AutoRoute? {
        RegisteredAlertRoute(
            title: params["title", default: "提示"],
            message: params["message", default: ""]
        )
    }

    override var routeView: AnyView {
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

// MARK: - RegisteredUserCardRoute

/// 注册路由示例：用户卡片（适合 WindowSheet fitContent）
class RegisteredUserCardRoute: AutoRoute {
    override class var routePath: String { "user/card" }
    let userName: String
    let role: String

    init(userName: String, role: String = "成员") {
        self.userName = userName
        self.role = role
        super.init()
    }

    override class func createInstance(from params: RouteParams) -> AutoRoute? {
        RegisteredUserCardRoute(
            userName: params["name", default: "未知用户"],
            role: params["role", default: "成员"]
        )
    }

    override var routeView: AnyView {
        AnyView(RegisteredUserCardView(userName: userName, role: role))
    }
}

struct RegisteredUserCardView: View {
    let userName: String
    let role: String
    @EnvironmentObject private var router: Router<AppRoute>

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.blue)

            Text(userName)
                .font(.title2.bold())

            Text(role)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(.blue.opacity(0.1))
                .clipShape(Capsule())

            Divider()

            HStack(spacing: 24) {
                VStack {
                    Text("128")
                        .font(.headline)
                    Text("关注")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                VStack {
                    Text("1.2k")
                        .font(.headline)
                    Text("粉丝")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                VStack {
                    Text("56")
                        .font(.headline)
                    Text("作品")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Button {
                router.dismiss()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    router.present(to: .profile(name: userName))
                }
            } label: {
                Text("查看主页")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(.blue)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            Button("关闭") {
                router.dismiss()
            }
            .foregroundStyle(.secondary)
        }
        .padding(24)
    }
}

// MARK: - RegisteredNotificationRoute

/// 注册路由示例：通知 Toast
class RegisteredNotificationRoute: AutoRoute {
    override class var routePath: String { "notification/toast" }
    let title: String
    let message: String
    let icon: String

    init(title: String, body: String, icon: String = "bell.fill") {
        self.title = title
        self.message = body
        self.icon = icon
        super.init()
    }

    override class func createInstance(from params: RouteParams) -> AutoRoute? {
        RegisteredNotificationRoute(
            title: params["title", default: "通知"],
            body: params["body", default: ""],
            icon: params["icon", default: "bell.fill"]
        )
    }

    override var routeView: AnyView {
        AnyView(RegisteredNotificationView(title: title, message: message, icon: icon))
    }
}

struct RegisteredNotificationView: View {
    let title: String
    let message: String
    let icon: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(.blue)
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.bold())
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()
        }
        .padding(14)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: 4)
        .padding(.horizontal, 16)
    }
}

// MARK: - RegisteredAboutRoute

/// 注册路由示例：关于页面（完整列表页）
class RegisteredAboutRoute: AutoRoute {
    override class var routePath: String { "app/about" }

    override class func createInstance(from params: RouteParams) -> AutoRoute? {
        RegisteredAboutRoute()
    }

    override var routeView: AnyView {
        AnyView(RegisteredAboutView())
    }
}

struct RegisteredAboutView: View {
    @EnvironmentObject private var router: Router<AppRoute>

    var body: some View {
        List {
            Section {
                VStack(spacing: 12) {
                    Image(systemName: "point.topleft.down.to.point.bottomright.curvepath.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.blue)
                    Text("SwiftUI Router")
                        .font(.title.bold())
                    Text("v1.0.0")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            }

            Section("功能") {
                Label("枚举路由 (AppRoute)", systemImage: "arrow.triangle.branch")
                Label("自动注册路由 (AutoRoute)", systemImage: "wand.and.stars")
                Label("路径导航", systemImage: "link")
                Label("9 种转场方式", systemImage: "rectangle.stack")
                Label("多层 dismiss 穿透", systemImage: "arrow.uturn.backward.circle")
                Label("ObjC Runtime 自动发现", systemImage: "cpu")
            }

            Section("导航") {
                Button("Push 详情页") {
                    router.present(to: .detail(title: "关于→详情"))
                }
                Button("Push 注册路由页") {
                    router.present(route: RegisteredDemoRoute(title: "关于→Demo"))
                }
                Button("用户卡片 WindowSheet") {
                    router.present(
                        route: RegisteredUserCardRoute(userName: "Router", role: "框架"),
                        via: .windowSheet(WindowSheetConfig(detent: .fitContent))
                    )
                }
            }

            Section {
                Button("dismiss()") { router.dismiss() }
                Button("dismissAll") { router.dismissAll() }
            }
        }
        .navigationTitle("关于")
    }
}

// MARK: - RegisteredProductRoute

/// 注册路由示例：商品详情页（传递对象参数）
class RegisteredProductRoute: AutoRoute {
    override class var routePath: String { "product/detail" }
    let product: Product

    init(product: Product) {
        self.product = product
        super.init()
    }

    override class func createInstance(from params: RouteParams) -> AutoRoute? {
        guard let product: Product = params["product"] else { return nil }
        return RegisteredProductRoute(product: product)
    }

    override var routeView: AnyView {
        AnyView(RegisteredProductView(product: product))
    }
}

/// 示例数据模型：商品
class Product: NSObject {
    let name: String
    let price: Double
    let icon: String
    let detailText: String

    init(name: String, price: Double, icon: String, detailText: String) {
        self.name = name
        self.price = price
        self.icon = icon
        self.detailText = detailText
        super.init()
    }
}

struct RegisteredProductView: View {
    let product: Product
    @EnvironmentObject private var router: Router<AppRoute>

    var body: some View {
        List {
            Section {
                VStack(spacing: 16) {
                    Image(systemName: product.icon)
                        .font(.system(size: 80))
                        .foregroundStyle(.orange)

                    Text(product.name)
                        .font(.title.bold())

                    Text("¥\(String(format: "%.2f", product.price))")
                        .font(.title2)
                        .foregroundStyle(.red)

                    Text(product.detailText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            }

            Section("操作") {
                Button("加入购物车") {
                    router.present(
                        to: .toastDemo(icon: "cart.badge.plus.fill", message: "已加入购物车", isSuccess: true),
                        via: .windowToast()
                    )
                }
                Button("立即购买") {
                    router.present(
                        to: .toastDemo(icon: "creditcard.fill", message: "订单已提交", isSuccess: true),
                        via: .windowToast()
                    )
                }
            }

            Section("路由参数测试") {
                Button("传对象 - WindowSheet") {
                    let newProduct = Product(
                        name: "MacBook Pro",
                        price: 19999,
                        icon: "laptopcomputer",
                        detailText: "强大的生产力工具"
                    )
                    router.present(
                        route: RegisteredProductRoute(product: newProduct),
                        via: .windowSheet()
                    )
                }
                Button("传对象 - Push") {
                    let newProduct = Product(
                        name: "iPhone 17",
                        price: 7999,
                        icon: "iphone",
                        detailText: "全新一代智能手机"
                    )
                    router.present(route: RegisteredProductRoute(product: newProduct))
                }
            }

            Section {
                Button("dismiss()") { router.dismiss() }
                Button("dismissAll") { router.dismissAll() }
            }
        }
        .navigationTitle("商品详情")
    }
}
