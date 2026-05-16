//
//  TabViewRegisteredRoutes.swift
//  Router
//
//  TabView 相关的注册路由

import SwiftUI

// MARK: - TabView Demo Routes

/// TabView 演示注册路由
class TabViewDemoRoute: AutoRoute {
    override class var routePath: String { "demo/tabview" }
    
    override class func createInstance(from params: RouteParams) -> AutoRoute? {
        TabViewDemoRoute()
    }
    
    override var routeView: AnyView {
        AnyView(TabViewRegisteredPage())
    }
}

// MARK: - TabView Registered Page

/// TabView 注册路由页面
struct TabViewRegisteredPage: View {
    @EnvironmentObject private var router: Router
    @State private var selectedTab = 0
    
    var body: some View {
        RootRouter {
            URLHandlerWrapper {
                TabViewRegisteredContent()
            }
        }
    }
}

/// TabView 内容
struct TabViewRegisteredContent: View {
    @EnvironmentObject private var router: Router
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            TabHomeRegisteredView()
                .tabItem {
                    Label("首页", systemImage: "house.fill")
                }
                .tag(0)
            
            TabExploreRegisteredView()
                .tabItem {
                    Label("发现", systemImage: "safari.fill")
                }
                .tag(1)
            
            TabMessagesRegisteredView()
                .tabItem {
                    Label("消息", systemImage: "message.fill")
                }
                .tag(2)
            
            TabSettingsRegisteredView()
                .tabItem {
                    Label("设置", systemImage: "gearshape.fill")
                }
                .tag(3)
        }
        .navigationTitle("TabView 演示（注册路由）")
    }
}

// MARK: - Tab Views

/// Tab 1: 首页
struct TabHomeRegisteredView: View {
    @EnvironmentObject private var router: Router
    
    var body: some View {
        RootRouter {
            URLHandlerWrapper {
                TabHomeRegisteredContent()
            }
        }
    }
}

struct TabHomeRegisteredContent: View {
    @EnvironmentObject private var router: Router
    
    var body: some View {
        List {
            Section("首页内容") {
                HStack {
                    Image(systemName: "house.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.blue)
                    Text("这是 Tab 1: 首页（注册路由）")
                        .font(.title2.bold())
                }
            }
            
            Section("导航示例") {
                Button("Push 详情页") {
                    router.present(route: RegisteredDemoRoute(title: "Tab首页→详情"))
                }
                Button("Sheet 用户卡片") {
                    router.present(
                        route: RegisteredUserCardRoute(userName: "Tab首页用户", role: "VIP"),
                        via: .sheet()
                    )
                }
                Button("WindowPush 关于页") {
                    router.present(route: RegisteredAboutRoute(), via: .windowPush)
                }
            }
        }
        .navigationTitle("首页")
    }
}

/// Tab 2: 发现
struct TabExploreRegisteredView: View {
    @EnvironmentObject private var router: Router
    
    var body: some View {
        RootRouter {
            URLHandlerWrapper {
                TabExploreRegisteredContent()
            }
        }
    }
}

struct TabExploreRegisteredContent: View {
    @EnvironmentObject private var router: Router
    
    var body: some View {
        List {
            Section("发现内容") {
                HStack {
                    Image(systemName: "safari.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.green)
                    Text("这是 Tab 2: 发现（注册路由）")
                        .font(.title2.bold())
                }
            }
            
            Section("导航示例") {
                Button("Push 商品详情") {
                    let product = Product(
                        name: "AirPods Pro",
                        price: 1999,
                        icon: "airpodspro",
                        detailText: "主动降噪"
                    )
                    router.present(route: RegisteredProductRoute(product: product))
                }
                Button("WindowSheet 用户卡片") {
                    router.present(
                        route: RegisteredUserCardRoute(userName: "发现页用户", role: "探索者"),
                        via: .windowSheet(WindowSheetConfig(detent: .fitContent))
                    )
                }
            }
        }
        .navigationTitle("发现")
    }
}

/// Tab 3: 消息
struct TabMessagesRegisteredView: View {
    @EnvironmentObject private var router: Router
    
    var body: some View {
        RootRouter {
            URLHandlerWrapper {
                TabMessagesRegisteredContent()
            }
        }
    }
}

struct TabMessagesRegisteredContent: View {
    @EnvironmentObject private var router: Router
    
    var body: some View {
        List {
            Section("消息内容") {
                HStack {
                    Image(systemName: "message.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.orange)
                    Text("这是 Tab 3: 消息（注册路由）")
                        .font(.title2.bold())
                }
            }
            
            Section("导航示例") {
                Button("通知 Toast") {
                    router.present(
                        route: RegisteredNotificationRoute(
                            title: "新消息",
                            body: "您有一条未读消息",
                            icon: "bell.fill"
                        ),
                        via: .windowToast()
                    )
                }
                Button("WindowAlert") {
                    router.present(
                        route: RegisteredAlertRoute(title: "消息提示", message: "您有新的消息"),
                        via: .windowAlert
                    )
                }
            }
        }
        .navigationTitle("消息")
    }
}

/// Tab 4: 设置
struct TabSettingsRegisteredView: View {
    @EnvironmentObject private var router: Router
    
    var body: some View {
        RootRouter {
            URLHandlerWrapper {
                TabSettingsRegisteredContent()
            }
        }
    }
}

struct TabSettingsRegisteredContent: View {
    @EnvironmentObject private var router: Router
    
    var body: some View {
        List {
            Section("设置内容") {
                HStack {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.gray)
                    Text("这是 Tab 4: 设置（注册路由）")
                        .font(.title2.bold())
                }
            }
            
            Section("导航示例") {
                Button("Push 关于页") {
                    router.present(route: RegisteredAboutRoute())
                }
                Button("WindowFade 注册路由页") {
                    router.present(
                        route: RegisteredDemoRoute(title: "设置页-Fade"),
                        via: .windowFade
                    )
                }
            }
            
            Section("操作") {
                Button("dismiss()") {
                    router.dismiss()
                }
                Button("dismissAll") {
                    router.dismissAll()
                }
            }
        }
        .navigationTitle("设置")
    }
}
