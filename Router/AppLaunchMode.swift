//
//  AppLaunchMode.swift
//  Router
//
//  Created by AI Assistant.
//

import SwiftUI
import Combine

/// App 启动方式枚举
enum AppLaunchMode: Int, CaseIterable, Identifiable {
    /// 单页模式：直接使用 HomeView
    case normal = 0
    /// 共享导航栈：RootRouter 包裹 TabView
    case scheme1 = 1
    /// 独立导航栈：每个 Tab 独立 RootRouter
    case scheme2 = 2
    
    var id: Int { rawValue }
    
    /// 显示名称
    var title: String {
        switch self {
        case .normal:
            return "单页模式"
        case .scheme1:
            return "共享导航栈"
        case .scheme2:
            return "独立导航栈"
        }
    }
    
    /// 详细描述
    var description: String {
        switch self {
        case .normal:
            return "单一页面，简单直接"
        case .scheme1:
            return "所有 Tab 共享同一个导航栈，路由统一管理"
        case .scheme2:
            return "每个 Tab 有独立的导航栈，互不干扰"
        }
    }
    
    /// 图标
    var icon: String {
        switch self {
        case .normal:
            return "house.fill"
        case .scheme1:
            return "rectangle.stack.fill"
        case .scheme2:
            return "square.stack.3d.up.fill"
        }
    }
    
    /// 颜色
    var color: Color {
        switch self {
        case .normal:
            return .blue
        case .scheme1:
            return .orange
        case .scheme2:
            return .green
        }
    }
}

/// App 启动配置（使用 UserDefaults 持久化）
@MainActor
class AppLaunchConfig: ObservableObject {
    static let shared = AppLaunchConfig()
    
    @AppStorage("appLaunchMode") var launchMode: Int = AppLaunchMode.normal.rawValue {
        didSet {
            objectWillChange.send()
        }
    }
    
    /// 当前启动模式
    var currentMode: AppLaunchMode {
        AppLaunchMode(rawValue: launchMode) ?? .normal
    }
    
    /// 切换启动模式
    func setMode(_ mode: AppLaunchMode) {
        launchMode = mode.rawValue
    }
    
    /// 切换到下一个模式（循环切换）
    func switchToNextMode() {
        let allModes = AppLaunchMode.allCases
        let currentIndex = allModes.firstIndex(where: { $0.rawValue == launchMode }) ?? 0
        let nextIndex = (currentIndex + 1) % allModes.count
        launchMode = allModes[nextIndex].rawValue
    }
}

// MARK: - 全局切换按钮视图

/// 全局启动模式切换按钮（可放在任何页面）
struct LaunchModeSwitchButton: View {
    @ObservedObject private var launchConfig = AppLaunchConfig.shared
    var size: CGFloat = 44
    
    var body: some View {
        Button(action: {
            launchConfig.switchToNextMode()
        }) {
            ZStack {
                Circle()
                    .fill(launchConfig.currentMode.color.opacity(0.15))
                    .frame(width: size, height: size)
                    .overlay(
                        Circle()
                            .stroke(launchConfig.currentMode.color, lineWidth: 2)
                    )
                
                Image(systemName: launchConfig.currentMode.icon)
                    .font(.system(size: size * 0.45))
                    .foregroundStyle(launchConfig.currentMode.color)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("当前模式：\(launchConfig.currentMode.title)。点击切换。")
    }
}

// MARK: - 视图扩展：快速添加切换按钮

extension View {
    /// 添加全局启动模式切换按钮（右上角）
    /// - Parameter cornerRadius: 圆角半径（默认 0）
    /// - Returns: 添加了切换按钮的视图
    func withLaunchModeSwitch(cornerRadius: CGFloat = 0) -> some View {
        self.overlay(
            LaunchModeSwitchButton()
                .padding(12),
            alignment: .topTrailing
        )
    }
    
    /// 添加全局启动模式切换按钮到 NavigationBar
    /// - Returns: 添加了切换按钮的视图
    func withLaunchModeSwitchInToolbar() -> some View {
        self.toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                LaunchModeSwitchButton(size: 32)
            }
        }
    }
}
