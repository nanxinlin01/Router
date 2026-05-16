//
//  ContentView.swift
//  Router
//
//  Created by 南鑫林 on 2026/4/24.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        // 使用注册路由方式
        RootRouter {
            // 在 RootRouter 内部使用 URLHandler，这样就能访问 environmentObject 中的 router
            URLHandlerWrapper {
                HomeView()
            }
        }
    }
}

/// URL 处理包装器（在 RootRouter 内部使用，可以访问 router）
struct URLHandlerWrapper<Content: View>: View {
    @EnvironmentObject private var router: Router
    let content: () -> Content
    
    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }
    
    var body: some View {
        content()
            .onOpenURL { url in
                // 业务层 URL 处理逻辑（完全由业务控制）
                print("[URL Scheme] ✅ 收到 URL: \(url.absoluteString)")
                print("[URL Scheme]    - Scheme: \(url.scheme ?? "无")")
                print("[URL Scheme]    - Host: \(url.host ?? "无")")
                print("[URL Scheme]    - Path: \(url.path)")
                print("[URL Scheme]    - Query: \(url.query ?? "无")")
                
                // 异步延迟处理，确保 UIWindowScene 已完全激活
                // 解决 URL Scheme 触发时场景未就绪导致 windowSheet 无法显示的问题
                // 使用多次延迟确保场景完全准备好
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    // 只处理注册路由
                    print("[URL Scheme] 延迟 0.1s 后处理深连接")
                    router.handleRegisteredDeepLink(url)
                }
            }
            .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { userActivity in
                // 业务层 Universal Link 处理逻辑
                guard let url = userActivity.webpageURL else { return }
                print("[Universal Link] 收到链接: \(url)")
                
                // 异步延迟处理，确保 UIWindowScene 已完全激活
                DispatchQueue.main.async {
                    router.handleRegisteredDeepLink(url)
                }
            }
    }
}

// MARK: - HomeView

struct HomeView: View {
    @EnvironmentObject private var router: Router

    var body: some View {
        List {
            Section {
                HStack {
                    Image(systemName: "point.topleft.down.to.point.bottomright.curvepath.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.blue)
                    Text("SwiftUI Router")
                        .font(.title2.bold())
                }
            }

            Section("Push") {
                Button("Push 注册路由页") {
                    router.present(route: RegisteredDemoRoute(title: "Hello Router!"))
                }
                Button("Push 关于页") {
                    router.present(route: RegisteredAboutRoute())
                }
            }

            Section("全部路由嵌套") {
                Button("→ Push") { router.present(route: RegisteredDemoRoute(title: "首页→Push")) }
                Button("→ Sheet") { router.present(route: RegisteredDemoRoute(title: "首页-Sheet"), via: .sheet()) }
                Button("→ FullScreenCover") { router.present(route: RegisteredAboutRoute(), via: .fullScreenCover) }
                Button("→ WindowSheet") { router.present(route: RegisteredDemoRoute(title: "首页-WS"), via: .windowSheet()) }
                Button("→ WindowPush") { router.present(route: RegisteredAboutRoute(), via: .windowPush) }
                Button("→ WindowAlert") { router.present(route: RegisteredAlertRoute(title: "首页", message: "首页的 WindowAlert"), via: .windowAlert) }
                Button("→ WindowFade") { router.present(route: RegisteredDemoRoute(title: "首页-Fade"), via: .windowFade) }
            }

            Section("Sheet") {
                Button("Sheet 注册路由页") {
                    router.present(route: RegisteredDemoRoute(title: "Sheet-Jeremy"), via: .sheet())
                }
                Button("Sheet 关于页") {
                    router.present(route: RegisteredAboutRoute(), via: .sheet())
                }
                Button("Sheet 半屏") {
                    router.present(route: RegisteredDemoRoute(title: "Sheet-半屏"), via: .sheet(SheetConfig(detent: .medium, showDragIndicator: true)))
                }
                Button("Sheet 半屏 ↔ Large") {
                    router.present(route: RegisteredAboutRoute(), via: .sheet(SheetConfig(detents: [.medium, .large], showDragIndicator: true)))
                }
                Button("Sheet 固定高度 300pt") {
                    router.present(route: RegisteredDemoRoute(title: "Sheet-300"), via: .sheet(SheetConfig(detent: .height(300), showDragIndicator: true)))
                }
                Button("Sheet 40%") {
                    router.present(route: RegisteredAboutRoute(), via: .sheet(SheetConfig(detent: .fraction(0.4), showDragIndicator: true)))
                }
            }

            Section("FullScreenCover") {
                Button("FullScreenCover 关于页") {
                    router.present(route: RegisteredAboutRoute(), via: .fullScreenCover)
                }
                Button("FullScreenCover 注册路由页") {
                    router.present(route: RegisteredDemoRoute(title: "Cover-Jeremy"), via: .fullScreenCover)
                }
            }

            Section("WindowSheet") {
                Button("WindowSheet 全屏") {
                    router.present(route: RegisteredDemoRoute(title: "WS-FullScreen"), via: .windowSheet(WindowSheetConfig(detent: .fullScreen)))
                }
                Button("WindowSheet Large") {
                    router.present(route: RegisteredDemoRoute(title: "WS-Large"), via: .windowSheet())
                }
                Button("WindowSheet 半屏") {
                    router.present(route: RegisteredDemoRoute(title: "WS-Half"), via: .windowSheet(WindowSheetConfig(detent: .half)))
                }
                Button("WindowSheet 70%") {
                    router.present(route: RegisteredAboutRoute(), via: .windowSheet(WindowSheetConfig(detent: .percentage(0.7))))
                }
                Button("WindowSheet 固定高度 400pt") {
                    router.present(route: RegisteredAboutRoute(), via: .windowSheet(WindowSheetConfig(detent: .fixedHeight(400))))
                }
                Button("WindowSheet 自适应高度") {
                    router.present(route: RegisteredUserCardRoute(userName: " Jeremy", role: "用户"), via: .windowSheet(WindowSheetConfig(detent: .fitContent)))
                }
            }

            Section("WindowSheet 多档位") {
                Button("半屏 ↔ Large") {
                    router.present(
                        route: RegisteredDemoRoute(title: "WS-多档位"),
                        via: .windowSheet(WindowSheetConfig(detents: [.half, .large]))
                    )
                }
                Button("30% ↔ 半屏 ↔ Large") {
                    router.present(
                        route: RegisteredDemoRoute(title: "WS-三档"),
                        via: .windowSheet(WindowSheetConfig(detents: [.percentage(0.3), .half, .large]))
                    )
                }
                Button("半屏 ↔ Large（起始 Large）") {
                    router.present(
                        route: RegisteredDemoRoute(title: "WS-起始Large"),
                        via: .windowSheet(WindowSheetConfig(detents: [.half, .large], initialDetentIndex: 1))
                    )
                }
                Button("200pt ↔ 半屏 ↔ 全屏") {
                    router.present(
                        route: RegisteredAboutRoute(),
                        via: .windowSheet(WindowSheetConfig(detents: [.fixedHeight(200), .half, .fullScreen]))
                    )
                }
            }

            Section("Alert") {
                Button("简单 Alert") {
                    router.showAlert(config: AlertConfig {
                        Alert(title: Text("提示"), message: Text("这是一个简单 Alert"), dismissButton: .default(Text("确定")))
                    })
                }
                Button("双按钮 Alert") {
                    router.showAlert(config: AlertConfig {
                        Alert(
                            title: Text("欢迎"),
                            message: Text("这是路由器 Alert 演示"),
                            primaryButton: .default(Text("好的")),
                            secondaryButton: .cancel(Text("取消"))
                        )
                    })
                }
                Button("注册路由 Alert") {
                    router.showAlert(config: AlertConfig {
                        Alert(
                            title: Text("注册路由"),
                            message: Text("这是通过注册路由路径显示的 Alert"),
                            primaryButton: .default(Text("确定")),
                            secondaryButton: .cancel(Text("取消"))
                        )
                    })
                }
            }

            Section("WindowPush") {
                Button("WindowPush 注册路由页") {
                    router.present(route: RegisteredDemoRoute(title: "WP-详情"), via: .windowPush)
                }
                Button("WindowPush 关于页") {
                    router.present(route: RegisteredAboutRoute(), via: .windowPush)
                }
                Button("WindowPush 用户卡片") {
                    router.present(route: RegisteredUserCardRoute(userName: "WP-Jeremy", role: "VIP"), via: .windowPush)
                }
            }

            Section("WindowAlert") {
                Button("简单 WindowAlert") {
                    router.present(
                        route: RegisteredAlertRoute(title: "提示", message: "这是一个 Window 级别的 Alert"),
                        via: .windowAlert
                    )
                }
                Button("WindowAlert 嵌套") {
                    router.present(
                        route: RegisteredAlertRoute(title: "首页-嵌套", message: "首页弹出嵌套 WindowAlert"),
                        via: .windowAlert
                    )
                }
            }

            Section("WindowToast") {
                Button("顶部 Toast（成功）") {
                    router.present(
                        route: RegisteredNotificationRoute(title: "成功", body: "操作成功", icon: "checkmark.circle.fill"),
                        via: .windowToast()
                    )
                }
                Button("顶部 Toast（失败）") {
                    router.present(
                        route: RegisteredNotificationRoute(title: "失败", body: "操作失败，请重试", icon: "xmark.circle.fill"),
                        via: .windowToast()
                    )
                }
                Button("底部 Toast") {
                    router.present(
                        route: RegisteredNotificationRoute(title: "提示", body: "已复制到剪贴板", icon: "info.circle.fill"),
                        via: .windowToast(WindowToastConfig(position: .bottom))
                    )
                }
                Button("长时间 Toast（5秒）") {
                    router.present(
                        route: RegisteredNotificationRoute(title: "下载", body: "正在下载...", icon: "arrow.down.circle.fill"),
                        via: .windowToast(WindowToastConfig(duration: 5.0))
                    )
                }
                Button("带遮罩 Toast") {
                    router.present(
                        route: RegisteredNotificationRoute(title: "警告", body: "网络连接已断开", icon: "exclamationmark.triangle.fill"),
                        via: .windowToast(WindowToastConfig(showDimming: true))
                    )
                }
            }

            Section("WindowFade") {
                Button("WindowFade 注册路由页") {
                    router.present(route: RegisteredDemoRoute(title: "Fade-详情"), via: .windowFade)
                }
                Button("WindowFade 关于页") {
                    router.present(route: RegisteredAboutRoute(), via: .windowFade)
                }
                Button("WindowFade 用户卡片") {
                    router.present(route: RegisteredUserCardRoute(userName: "Fade-Jeremy", role: "用户"), via: .windowFade)
                }
            }
            
            Section("TabView 架构方案对比") {
                Button("📊 查看方案对比") {
                    router.present(route: TabViewArchitectureDemoRoute(), via: .windowPush)
                }
            }

            Section("注册路由 (AutoRoute)") {
                Button("实例导航 - Push") {
                    router.present(route: RegisteredDemoRoute(title: "Push-Demo"))
                }
                Button("实例导航 - Sheet") {
                    router.present(route: RegisteredDemoRoute(title: "Sheet-Demo"), via: .sheet())
                }
                Button("实例导航 - WindowSheet") {
                    router.present(route: RegisteredDemoRoute(title: "WS-Demo"), via: .windowSheet())
                }
                Button("实例导航 - WindowPush") {
                    router.present(route: RegisteredDemoRoute(title: "WP-Demo"), via: .windowPush)
                }
                Button("实例导航 - WindowFade") {
                    router.present(route: RegisteredDemoRoute(title: "Fade-Demo"), via: .windowFade)
                }
                Button("路径导航 - Push") {
                    router.present(path: "demo/registered", params: RouteParams(["title": "Path-Push"]), via: .push())
                }
                Button("路径导航 - WindowAlert") {
                    router.present(route: RegisteredAlertRoute(title: "注册路由 Alert", message: "这是通过注册路由显示的 Alert"), via: .windowAlert)
                }
            }

            Section("注册路由 - 更多案例") {
                Button("用户卡片 - WindowSheet 自适应") {
                    router.present(
                        route: RegisteredUserCardRoute(userName: "Jeremy", role: "管理员"),
                        via: .windowSheet(WindowSheetConfig(detent: .fitContent))
                    )
                }
                Button("用户卡片 - WindowSheet 半屏") {
                    router.present(
                        route: RegisteredUserCardRoute(userName: "Guest", role: "访客"),
                        via: .windowSheet(WindowSheetConfig(detent: .half))
                    )
                }
                Button("用户卡片 - 路径导航") {
                    router.present(path: "user/card", params: RouteParams(["name": "Path-User", "role": "VIP"]), via: .windowSheet(WindowSheetConfig(detent: .fitContent)))
                }
                Button("通知 Toast - 顶部") {
                    router.present(
                        route: RegisteredNotificationRoute(title: "新消息", body: "您有一条未读消息"),
                        via: .windowToast()
                    )
                }
                Button("通知 Toast - 底部") {
                    router.present(
                        route: RegisteredNotificationRoute(title: "下载完成", body: "文件已保存到相册", icon: "arrow.down.circle.fill"),
                        via: .windowToast(WindowToastConfig(position: .bottom))
                    )
                }
                Button("关于页 - Push") {
                    router.present(route: RegisteredAboutRoute())
                }
                Button("关于页 - 路径导航 WindowPush") {
                    router.present(path: "app/about", via: .windowPush)
                }
                Button("商品详情 - 实例导航 Push") {
                    let product = Product(
                        name: "AirPods Pro",
                        price: 1999,
                        icon: "airpodspro",
                        detailText: "主动降噪，沉浸音质"
                    )
                    router.present(route: RegisteredProductRoute(product: product))
                }
                Button("商品详情 - 实例导航 WindowSheet") {
                    let product = Product(
                        name: "Apple Watch",
                        price: 2999,
                        icon: "applewatch",
                        detailText: "你的健康生活伙伴"
                    )
                    router.present(
                        route: RegisteredProductRoute(product: product),
                        via: .windowSheet()
                    )
                }
                Button("商品详情 - 路径导航") {
                    let product = Product(
                        name: "iPad Pro",
                        price: 6999,
                        icon: "ipadgen",
                        detailText: "轻薄强大，随你而行"
                    )
                    router.present(path: "product/detail", params: RouteParams(["product": product]), via: .windowPush)
                }
            }
            

            Section("深连接测试 - 注册路由") {
                Button("深连接 - 注册路由 (Push)") {
                    guard let url = URL(string: "myapp://demo/registered?title=深连接注册路由") else { return }
                    router.handleRegisteredDeepLink(url)
                }
                Button("深连接 - 用户卡片 (WindowSheet)") {
                    guard let url = URL(string: "myapp://user/card?name=深连接用户&role=VIP&transition=windowSheet") else { return }
                    router.handleRegisteredDeepLink(url)
                }
                Button("深连接 - 关于页 (WindowFade)") {
                    guard let url = URL(string: "myapp://app/about?transition=windowFade") else { return }
                    router.handleRegisteredDeepLink(url)
                }
            }
            


        }
        .navigationTitle("单页模式")
        .withLaunchModeSwitchInToolbar()
    }
}

#Preview {
    ContentView()
}
