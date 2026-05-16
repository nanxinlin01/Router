//
//  TabViewRoutes.swift
//  Router
//
//  TabView 架构方案对比演示（注册路由方式）

import SwiftUI

// MARK: - TabView 架构方案对比入口

/// TabView 架构方案对比路由
class TabViewArchitectureDemoRoute: AutoRoute {
    override class var routePath: String { "demo/tabview/architecture" }
    
    override class func createInstance(from params: RouteParams) -> AutoRoute? {
        TabViewArchitectureDemoRoute()
    }
    
    override var routeView: AnyView {
        AnyView(TabViewArchitectureDemo())
    }
}

/// TabView 架构方案对比页面
struct TabViewArchitectureDemo: View {
    @EnvironmentObject private var router: Router
    
    var body: some View {
        List {
            Section("TabView 架构方案对比") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "rectangle.stack.fill")
                            .font(.title2)
                            .foregroundStyle(.orange)
                        VStack(alignment: .leading) {
                            Text("方案1：全局单导航栈")
                                .font(.headline)
                            Text("RootRouter 包裹 TabView，所有 Tab 共享导航栈")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Button("查看方案1演示") {
                        router.present(route: TabViewScheme1Route(), via: .windowPush)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                }
                .padding(.vertical, 8)
                
                Divider()
                
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "square.stack.3d.up.fill")
                            .font(.title2)
                            .foregroundStyle(.green)
                        VStack(alignment: .leading) {
                            Text("方案2：多导航栈隔离")
                                .font(.headline)
                            Text("每个 Tab 独立 RootRouter，导航栈互不干扰")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Button("查看方案2演示") {
                        router.present(route: TabViewScheme2Route(), via: .windowPush)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                }
                .padding(.vertical, 8)
            }
            
            Section("推荐场景") {
                Label("方案1适合：简单应用，Tab 间需要频繁跳转", systemImage: "checkmark.circle")
                    .font(.caption)
                Label("方案2适合：复杂应用，Tab 独立性要求高", systemImage: "checkmark.circle")
                    .font(.caption)
            }
        }
        .navigationTitle("TabView 架构方案")
    }
}

// MARK: - 方案1：全局单导航栈

/// 方案1注册路由
class TabViewScheme1Route: AutoRoute {
    override class var routePath: String { "demo/tabview/scheme1" }
    
    override class func createInstance(from params: RouteParams) -> AutoRoute? {
        TabViewScheme1Route()
    }
    
    override var routeView: AnyView {
        AnyView(TabViewScheme1Page())
    }
}

/// 方案1：RootRouter 包裹 TabView（全局单导航栈）
struct TabViewScheme1Page: View {
    @EnvironmentObject private var router: Router
    @State private var selectedTab = 0
    
    var body: some View {
        RootRouter {
            URLHandlerWrapper {
                TabViewScheme1Content()
            }
        }
    }
}

struct TabViewScheme1Content: View {
    @EnvironmentObject private var router: Router
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            Scheme1Tab1View()
                .tabItem {
                    Label("Tab1", systemImage: "1.circle.fill")
                }
                .tag(0)
            
            Scheme1Tab2View()
                .tabItem {
                    Label("Tab2", systemImage: "2.circle.fill")
                }
                .tag(1)
            
            Scheme1Tab3View()
                .tabItem {
                    Label("Tab3", systemImage: "3.circle.fill")
                }
                .tag(2)
        }
        .navigationTitle("方案1：全局单导航栈")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("dismiss") {
                    router.dismiss()
                }
            }
        }
    }
}

// 方案1 - Tab 1
struct Scheme1Tab1View: View {
    @EnvironmentObject private var router: Router
    
    var body: some View {
        List {
            Section("方案1 - Tab 1") {
                Text("所有 Tab 共享同一个 NavigationStack")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Section("导航测试") {
                Button("Push 详情（同栈）") {
                    router.present(route: RegisteredDemoRoute(title: "方案1-Tab1→详情"))
                }
                Button("Push 详情（隐藏TabBar）") {
                    router.present(
                        route: RegisteredDemoRoute(title: "方案1-隐藏TabBar"),
                        via: .push(PushConfig(hidesTabBar: true))
                    )
                }
            }
        }
        .navigationTitle("Tab 1")
    }
}

// 方案1 - Tab 2
struct Scheme1Tab2View: View {
    @EnvironmentObject private var router: Router
    
    var body: some View {
        List {
            Section("方案1 - Tab 2") {
                Text("在 Tab2 Push 后，切换 Tab1 也能看到")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Section("导航测试") {
                Button("Push 详情") {
                    router.present(route: RegisteredDemoRoute(title: "方案1-Tab2→详情"))
                }
            }
        }
        .navigationTitle("Tab 2")
    }
}

// 方案1 - Tab 3
struct Scheme1Tab3View: View {
    @EnvironmentObject private var router: Router
    
    var body: some View {
        List {
            Section("方案1 - Tab 3") {
                Text("Toast 演示")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Section("导航测试") {
                Button("成功 Toast") {
                    router.present(
                        route: RegisteredNotificationRoute(
                            title: "方案1-Tab3",
                            body: "操作成功",
                            icon: "checkmark.circle.fill"
                        ),
                        via: .windowToast()
                    )
                }
            }
        }
        .navigationTitle("Tab 3")
    }
}

// MARK: - 方案2：多导航栈隔离

/// 方案2注册路由
class TabViewScheme2Route: AutoRoute {
    override class var routePath: String { "demo/tabview/scheme2" }
    
    override class func createInstance(from params: RouteParams) -> AutoRoute? {
        TabViewScheme2Route()
    }
    
    override var routeView: AnyView {
        AnyView(TabViewScheme2Page())
    }
}

/// 方案2：每个 Tab 独立 RootRouter（多导航栈隔离）
struct TabViewScheme2Page: View {
    @EnvironmentObject private var router: Router
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            Scheme2Tab1View()
                .tabItem {
                    Label("Tab1", systemImage: "1.circle.fill")
                }
                .tag(0)
            
            Scheme2Tab2View()
                .tabItem {
                    Label("Tab2", systemImage: "2.circle.fill")
                }
                .tag(1)
            
            Scheme2Tab3View()
                .tabItem {
                    Label("Tab3", systemImage: "3.circle.fill")
                }
                .tag(2)
        }
        .navigationTitle("方案2：多导航栈隔离")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("dismiss") {
                    router.dismiss()
                }
            }
        }
    }
}

// 方案2 - Tab 1（独立 RootRouter）
struct Scheme2Tab1View: View {
    @EnvironmentObject private var router: Router
    
    var body: some View {
        RootRouter {
            URLHandlerWrapper {
                Scheme2Tab1Content()
            }
        }
    }
}

struct Scheme2Tab1Content: View {
    @EnvironmentObject private var router: Router
    
    var body: some View {
        List {
            Section("方案2 - Tab 1") {
                Text("每个 Tab 有独立的 NavigationStack")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Section("导航测试") {
                Button("Push 详情（独立栈）") {
                    router.present(route: RegisteredDemoRoute(title: "方案2-Tab1→详情"))
                }
            }
        }
        .navigationTitle("Tab 1")
    }
}

// 方案2 - Tab 2（独立 RootRouter）
struct Scheme2Tab2View: View {
    @EnvironmentObject private var router: Router
    
    var body: some View {
        RootRouter {
            URLHandlerWrapper {
                Scheme2Tab2Content()
            }
        }
    }
}

struct Scheme2Tab2Content: View {
    @EnvironmentObject private var router: Router
    
    var body: some View {
        List {
            Section("方案2 - Tab 2") {
                Text("Tab2 的导航不会影响 Tab1")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Section("导航测试") {
                Button("Push 详情") {
                    router.present(route: RegisteredDemoRoute(title: "方案2-Tab2→详情"))
                }
            }
        }
        .navigationTitle("Tab 2")
    }
}

// 方案2 - Tab 3（独立 RootRouter）
struct Scheme2Tab3View: View {
    @EnvironmentObject private var router: Router
    
    var body: some View {
        RootRouter {
            URLHandlerWrapper {
                Scheme2Tab3Content()
            }
        }
    }
}

struct Scheme2Tab3Content: View {
    @EnvironmentObject private var router: Router
    
    var body: some View {
        List {
            Section("方案2 - Tab 3") {
                Text("完全隔离，互不干扰")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Section("导航测试") {
                Button("WindowSheet 用户卡片") {
                    router.present(
                        route: RegisteredUserCardRoute(userName: "方案2用户", role: "测试"),
                        via: .windowSheet(WindowSheetConfig(detent: .fitContent))
                    )
                }
            }
        }
        .navigationTitle("Tab 3")
    }
}
