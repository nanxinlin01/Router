//
//  TabViewRoutes.swift
//  Router
//
//  TabView 相关路由和页面

import SwiftUI

// MARK: - 可复用的嵌套 TabView 按钮组

/// 嵌套 TabView 导航按钮组（可复用组件）
struct NestedTabViewButtons: View {
    @EnvironmentObject private var router: EnumRouter
    
    var body: some View {
        Group {
            Text("嵌套 TabView 示例")
                .font(.headline)
                .padding(.top, 8)
            
            Button("WindowPush 新 TabView") {
                router.present(to: .tabViewDemo, via: .windowPush)
            }
            Button("WindowPush 方案1（嵌套）") {
                router.present(to: .tabViewScheme1, via: .windowPush)
            }
            Button("WindowPush 方案2（嵌套）") {
                router.present(to: .tabViewScheme2, via: .windowPush)
            }
        }
    }
}

// MARK: - TabView Demo

/// TabView 主页面（包含多个 Tab）
struct TabViewMainPage: View {
    @EnvironmentObject private var router: EnumRouter
    @State private var selectedTab = 0
    
    var body: some View {
        EnumRootRouter {
            URLHandlerWrapper {
                TabViewMainContent()
            }
        }
    }
}

/// TabView 主页面内容（实际的 TabView 结构）
struct TabViewMainContent: View {
    @EnvironmentObject private var router: EnumRouter
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            TabHomeView()
                .tabItem {
                    Label("首页", systemImage: "house.fill")
                }
                .tag(0)
            
            ExploreView()
                .tabItem {
                    Label("发现", systemImage: "safari.fill")
                }
                .tag(1)
            
            MessagesView()
                .tabItem {
                    Label("消息", systemImage: "message.fill")
                }
                .tag(2)
            
            SettingsTabView()
                .tabItem {
                    Label("设置", systemImage: "gearshape.fill")
                }
                .tag(3)
        }
        .navigationTitle("TabView 演示")
        .withLaunchModeSwitchInToolbar()
    }
}

// MARK: - Tab Home View

/// Tab 1: 首页
struct TabHomeView: View {
    @EnvironmentObject private var router: EnumRouter
    
    var body: some View {
        EnumRootRouter {
            URLHandlerWrapper {
                TabHomeContent()
            }
        }
    }
}

/// Tab 1 内容视图
struct TabHomeContent: View {
    @EnvironmentObject private var router: EnumRouter
    
    var body: some View {
        List {
            Section("首页内容") {
                HStack {
                    Image(systemName: "house.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.blue)
                    Text("这是 Tab 1: 首页")
                        .font(.title2.bold())
                }
            }
            
            Section("导航示例") {
                Button("Push 详情页") {
                    router.present(to: .detail(title: "Tab首页→详情"))
                }
                Button("Sheet 个人页") {
                    router.present(to: .profile(name: "Tab首页-Sheet"), via: .sheet())
                }
                Button("WindowPush 设置页") {
                    router.present(to: .settings, via: .windowPush)
                }
                
                NestedTabViewButtons()
            }
        }
        .navigationTitle("首页")
    }
}

// MARK: - Explore View

/// Tab 2: 发现
struct ExploreView: View {
    @EnvironmentObject private var router: EnumRouter
    
    var body: some View {
        EnumRootRouter {
            URLHandlerWrapper {
                ExploreContent()
            }
        }
    }
}

struct ExploreContent: View {
    @EnvironmentObject private var router: EnumRouter
    
    var body: some View {
        List {
            Section("发现内容") {
                HStack {
                    Image(systemName: "safari.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.green)
                    Text("这是 Tab 2: 发现")
                        .font(.title2.bold())
                }
            }
            
            Section("推荐内容") {
                ForEach(1...5, id: \.self) { index in
                    HStack {
                        Image(systemName: "star.fill")
                            .foregroundStyle(.yellow)
                        VStack(alignment: .leading) {
                            Text("推荐内容 \(index)")
                                .font(.headline)
                            Text("这是第 \(index) 个推荐内容")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            
            Section("导航示例") {
                Button("Push 商品详情") {
                    let product = Product(
                        name: "推荐商品",
                        price: 999,
                        icon: "gift.fill",
                        detailText: "来自发现页的推荐"
                    )
                    router.present(route: RegisteredProductRoute(product: product))
                }
                
                Text("嵌套 TabView 示例")
                    .font(.headline)
                    .padding(.top, 8)
                
                // 使用 WindowPush 避免 RootRouter 嵌套冲突
                Button("WindowPush 新 TabView") {
                    router.present(to: .tabViewDemo, via: .windowPush)
                }
                Button("WindowPush 方案1（嵌套）") {
                    router.present(to: .tabViewScheme1, via: .windowPush)
                }
                Button("WindowPush 方案2（嵌套）") {
                    router.present(to: .tabViewScheme2, via: .windowPush)
                }
            }
        }
        .navigationTitle("发现")
    }
}

// MARK: - Messages View

/// Tab 3: 消息
struct MessagesView: View {
    @EnvironmentObject private var router: EnumRouter
    
    var body: some View {
        EnumRootRouter {
            URLHandlerWrapper {
                MessagesContent()
            }
        }
    }
}

struct MessagesContent: View {
    @EnvironmentObject private var router: EnumRouter
    
    var body: some View {
        List {
            Section("消息列表") {
                HStack {
                    Image(systemName: "message.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.orange)
                    Text("这是 Tab 3: 消息")
                        .font(.title2.bold())
                }
            }
            
            Section("最近消息") {
                ForEach(1...4, id: \.self) { index in
                    HStack(spacing: 12) {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(.blue)
                        VStack(alignment: .leading) {
                            Text("用户 \(index)")
                                .font(.headline)
                            Text("这是一条消息内容...")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Spacer()
                        Text("\(index)分钟前")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            Section("操作") {
                Button("显示 Toast") {
                    router.present(
                        to: .toastDemo(icon: "bell.fill", message: "新消息通知", isSuccess: true),
                        via: .windowToast()
                    )
                }
                
                Text("嵌套 TabView 示例")
                    .font(.headline)
                    .padding(.top, 8)
                
                // 使用 WindowPush 避免 RootRouter 嵌套冲突
                Button("WindowPush 新 TabView") {
                    router.present(to: .tabViewDemo, via: .windowPush)
                }
                Button("WindowPush 方案1（嵌套）") {
                    router.present(to: .tabViewScheme1, via: .windowPush)
                }
                Button("WindowPush 方案2（嵌套）") {
                    router.present(to: .tabViewScheme2, via: .windowPush)
                }
            }
        }
        .navigationTitle("消息")
    }
}

// MARK: - Settings Tab View

/// Tab 4: 设置
struct SettingsTabView: View {
    @EnvironmentObject private var router: EnumRouter
    
    var body: some View {
        EnumRootRouter {
            URLHandlerWrapper {
                SettingsTabContent()
            }
        }
    }
}

struct SettingsTabContent: View {
    @EnvironmentObject private var router: EnumRouter
    
    var body: some View {
        List {
            Section("设置内容") {
                HStack {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.gray)
                    Text("这是 Tab 4: 设置")
                        .font(.title2.bold())
                }
            }
            
            Section("账户") {
                Button("查看个人资料") {
                    router.present(to: .profile(name: "设置-个人页"))
                }
            }
            
            Section("返回") {
                Button("返回根页面") {
                    router.dismissAll()
                }
                .foregroundColor(.red)
            }
        }
        .navigationTitle("设置")
    }
}

// MARK: - TabView 方案 1：RootRouter 包裹 TabView

/// 方案1：RootRouter 在最外层，所有 Tab 共享同一个导航栈
struct TabViewScheme1Page: View {
    @EnvironmentObject private var router: EnumRouter
    @State private var selectedTab = 0
    
    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $selectedTab) {
                Scheme1Tab1View()
                    .tabItem { Label("Tab1", systemImage: "1.circle.fill") }
                    .tag(0)
                
                Scheme1Tab2View()
                    .tabItem { Label("Tab2", systemImage: "2.circle.fill") }
                    .tag(1)
                
                Scheme1Tab3View()
                    .tabItem { Label("Tab3", systemImage: "3.circle.fill") }
                    .tag(2)
            }
        }
        .navigationTitle("共享导航栈")
        .withLaunchModeSwitchInToolbar()
    }
}

struct Scheme1Tab1View: View {
    @EnvironmentObject private var router: EnumRouter
    var body: some View {
        List {
            Section("特点") {
                Text("✅ 所有 Tab 共享一个 NavigationStack")
                Text("✅ 路由统一管理")
            }
            Section("测试") {
                Button("Push 详情") { router.present(to: .detail(title: "方案1-Tab1→详情")) }
                Button("Push 详情（隐藏TabBar）") { router.present(to: .detail(title: "方案1-隐藏TabBar"), via: .push(PushConfig(hidesTabBar: true))) }
                
                Text("嵌套 TabView 示例")
                    .font(.headline)
                    .padding(.top, 8)
                
                // 使用 WindowPush 避免 RootRouter 嵌套冲突
                Button("WindowPush 新 TabView") {
                    router.present(to: .tabViewDemo, via: .windowPush)
                }
                Button("WindowPush 方案1（嵌套）") {
                    router.present(to: .tabViewScheme1, via: .windowPush)
                }
                Button("WindowPush 方案2（嵌套）") {
                    router.present(to: .tabViewScheme2, via: .windowPush)
                }
            }
        }
        .navigationTitle("Tab 1")
    }
}

struct Scheme1Tab2View: View {
    @EnvironmentObject private var router: EnumRouter
    var body: some View {
        List {
            Section("特点") { Text("共享全局 Router 实例") }
            Section("测试") {
                Button("Push 商品") {
                    let product = Product(name: "方案1商品", price: 1299, icon: "cart.fill", detailText: "来自方案1-Tab2")
                    router.present(route: RegisteredProductRoute(product: product))
                }
            }
        }
        .navigationTitle("Tab 2")
    }
}

struct Scheme1Tab3View: View {
    @EnvironmentObject private var router: EnumRouter
    var body: some View {
        List {
            Section("特点") { Text("适合：简单应用") }
            Section("测试") {
                Button("Toast") {
                    router.present(to: .toastDemo(icon: "checkmark.circle.fill", message: "方案1-Tab3", isSuccess: true), via: .windowToast())
                }
            }
            Section("返回") {
                Button("dismissAll") { router.dismissAll() }.foregroundColor(.red)
            }
        }
        .navigationTitle("Tab 3")
    }
}

// MARK: - TabView 方案 2：每个 Tab 独立 RootRouter

/// 方案2：每个 Tab 内部有自己的 RootRouter，导航栈完全隔离
struct TabViewScheme2Page: View {
    @State private var selectedTab = 0
    
    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $selectedTab) {
                EnumRootRouter {
                    URLHandlerWrapper { Scheme2Tab1View() }
                }
                .tabItem { Label("Tab1", systemImage: "1.circle.fill") }
                .tag(0)
                
                EnumRootRouter {
                    URLHandlerWrapper { Scheme2Tab2View() }
                }
                .tabItem { Label("Tab2", systemImage: "2.circle.fill") }
                .tag(1)
                
                EnumRootRouter {
                    URLHandlerWrapper { Scheme2Tab3View() }
                }
                .tabItem { Label("Tab3", systemImage: "3.circle.fill") }
                .tag(2)
            }
        }
        .navigationTitle("独立导航栈")
    }
}

struct Scheme2Tab1View: View {
    @EnvironmentObject private var router: EnumRouter
    var body: some View {
        List {
            Section("特点") {
                Text("✅ 每个 Tab 有独立的 NavigationStack")
                Text("✅ Tab 之间的导航完全隔离")
            }
            Section("测试（仅影响Tab1）") {
                Button("Push 详情") { router.present(to: .detail(title: "方案2-Tab1→详情")) }
                Button("Push 详情（隐藏TabBar）") { router.present(to: .detail(title: "方案2-隐藏TabBar"), via: .push(PushConfig(hidesTabBar: true))) }
                
                Text("嵌套 TabView 示例")
                    .font(.headline)
                    .padding(.top, 8)
                
                // 使用 WindowPush 避免 RootRouter 嵌套冲突
                Button("WindowPush 新 TabView") {
                    router.present(to: .tabViewDemo, via: .windowPush)
                }
                Button("WindowPush 方案1（嵌套）") {
                    router.present(to: .tabViewScheme1, via: .windowPush)
                }
                Button("WindowPush 方案2（嵌套）") {
                    router.present(to: .tabViewScheme2, via: .windowPush)
                }
            }
            Section("返回") {
                Button("dismissAll") { router.dismissAll() }.foregroundColor(.red)
            }
        }
        .navigationTitle("独立导航栈")
        .withLaunchModeSwitchInToolbar()
    }
}

struct Scheme2Tab2View: View {
    @EnvironmentObject private var router: EnumRouter
    
    private func createProduct() -> Product {
        Product(name: "方案2商品", price: 2999, icon: "iphone", detailText: "来自方案2-Tab2")
    }
    
    private func createProductWP() -> Product {
        Product(name: "方案2商品-WP", price: 2999, icon: "iphone", detailText: "来自方案2-Tab2")
    }
    
    var body: some View {
        List {
            Section("特点") { Text("独立的 Router 实例") }
            Section("测试（仅影响Tab2）") {
                Button("Push 商品") {
                    let product = createProduct()
                    router.present(route: RegisteredProductRoute(product: product))
                }
                Button("WindowPush 商品") {
                    let product = createProductWP()
                    router.present(route: RegisteredProductRoute(product: product), via: .windowPush)
                }
            }
            Section("返回") {
                Button("dismissAll") { router.dismissAll() }.foregroundColor(.red)
            }
        }
        .navigationTitle("独立导航栈")
        .withLaunchModeSwitchInToolbar()
    }
}

struct Scheme2Tab3View: View {
    @EnvironmentObject private var router: EnumRouter
    var body: some View {
        List {
            Section("特点") { Text("类似微信、QQ 的Tab架构") }
            Section("测试（仅影响Tab3）") {
                Button("Push 消息") { router.present(to: .profile(name: "方案2-消息列表")) }
                Button("Toast") { router.present(to: .toastDemo(icon: "bell.fill", message: "方案2-Tab3", isSuccess: true), via: .windowToast()) }
            }
            Section("返回") {
                Button("dismissAll") { router.dismissAll() }.foregroundColor(.red)
            }
        }
        .navigationTitle("独立导航栈")
        .withLaunchModeSwitchInToolbar()
    }
}

// MARK: - 启动模式设置视图

/// 启动模式设置页面（用于切换启动方式）
struct LaunchModeSettingView: View {
    @EnvironmentObject private var router: EnumRouter
    @ObservedObject private var launchConfig = AppLaunchConfig.shared
    @State private var selectedMode: Int
    
    init() {
        _selectedMode = State(initialValue: AppLaunchConfig.shared.launchMode)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("选择启动模式")
                    .font(.headline)
                Spacer()
                Button("完成") {
                    launchConfig.launchMode = selectedMode
                    router.dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .background(Color(.systemGray6))
            
            Divider()
            
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(AppLaunchMode.allCases) { mode in
                        ModeCardView(
                            mode: mode,
                            isSelected: selectedMode == mode.rawValue,
                            action: { selectedMode = mode.rawValue }
                        )
                    }
                }
                .padding()
            }
            
            VStack(spacing: 8) {
                Divider()
                Text("💡 提示：选择后立即生效")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            }
            .background(Color(.systemGray6))
        }
        .frame(maxHeight: .infinity)
    }
}

/// 模式卡片视图
struct ModeCardView: View {
    let mode: AppLaunchMode
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: mode.icon)
                    .font(.system(size: 32))
                    .foregroundStyle(mode.color)
                    .frame(width: 50, height: 50)
                    .background(mode.color.opacity(0.1))
                    .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(mode.title)
                        .font(.headline)
                    Text(mode.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24))
                    .foregroundStyle(isSelected ? mode.color : .secondary)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? mode.color.opacity(0.1) : Color(.systemGray6).opacity(0.5))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? mode.color : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}
