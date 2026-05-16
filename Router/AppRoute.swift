//
//  AppRoute.swift
//  Router
//

import SwiftUI

//// MARK: - RegisterableRoute 示例（AutoRoute 子类）

///// 注册路由示例：演示独立于 AppRoute 枚举的动态路由
class RegisteredDemoRoute: AutoRoute {
    override class var routePath: String { "demo/registered" }
    let title: String

    init(title: String) {
        self.title = title
        super.init()
    }

    override class func createInstance(from params: RouteParams) -> AutoRoute? {
        let title = params["title", default: "Default"]
        print("[RegisteredDemoRoute] createInstance - params: title=\(title)")
        return RegisteredDemoRoute(title: title)
    }

    override var routeView: AnyView {
        AnyView(RegisteredDemoView(title: title))
    }
}

// MARK: - RegisteredDemoView

struct RegisteredDemoView: View {
    let title: String
    @EnvironmentObject private var router: Router

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
    @EnvironmentObject private var router: Router

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
                router.present(route: RegisteredDemoRoute(title: "Alert内→注册路由"))
            } label: {
                HStack {
                    Image(systemName: "puzzlepiece.extension.fill")
                    Text("Push 注册路由页")
                }
                .font(.subheadline)
                .foregroundColor(.purple)
            }
            .padding(.top, 8)
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
    @EnvironmentObject private var router: Router

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
                    router.present(route: RegisteredUserCardRoute(userName: userName, role: role))
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
    @EnvironmentObject private var router: Router

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
                Label("自动注册路由 (AutoRoute)", systemImage: "wand.and.stars")
                Label("路径导航", systemImage: "link")
                Label("9 种转场方式", systemImage: "rectangle.stack")
                Label("多层 dismiss 穿透", systemImage: "arrow.uturn.backward.circle")
                Label("ObjC Runtime 自动发现", systemImage: "cpu")
            }

            Section("导航") {
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
    @EnvironmentObject private var router: Router

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
                        route: RegisteredNotificationRoute(title: "通知", body: "已加入购物车", icon: "cart.badge.plus.fill"),
                        via: .windowToast()
                    )
                }
                Button("立即购买") {
                    router.present(
                        route: RegisteredNotificationRoute(title: "通知", body: "订单已提交", icon: "creditcard.fill"),
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
