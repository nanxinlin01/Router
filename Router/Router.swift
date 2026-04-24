//
//  Router.swift
//  Router
//

import SwiftUI
import Combine

// MARK: - Routable Protocol

/// 路由目标协议：所有可路由页面必须遵循此协议
protocol Routable: Hashable, Identifiable {
    associatedtype Body: View
    @ViewBuilder var body: Body { get }
}

extension Routable {
    var id: Self { self }
}

// MARK: - RouteTransition

/// 路由转场方式
enum RouteTransition {
    case push
    case sheet
    case fullScreenCover
}

// MARK: - AlertConfig

/// Alert 配置
struct AlertConfig: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let primaryButton: Alert.Button
    let secondaryButton: Alert.Button?

    init(
        title: String,
        message: String = "",
        primaryButton: Alert.Button = .default(Text("确定")),
        secondaryButton: Alert.Button? = nil
    ) {
        self.title = title
        self.message = message
        self.primaryButton = primaryButton
        self.secondaryButton = secondaryButton
    }
}

// MARK: - Router

/// 泛型路由管理器，统一管理 Push/Sheet/FullScreenCover/Alert
final class Router<Destination: Routable>: ObservableObject {

    // MARK: - Navigation State

    /// NavigationStack 路径
    @Published var path = NavigationPath()

    /// Sheet 展示的目标
    @Published var sheet: Destination?

    /// FullScreenCover 展示的目标
    @Published var fullScreenCover: Destination?

    /// Alert 配置
    @Published var alertConfig: AlertConfig?

    // MARK: - Navigate

    /// 导航到指定目标
    func navigate(to destination: Destination, via transition: RouteTransition = .push) {
        switch transition {
        case .push:
            path.append(destination)
        case .sheet:
            sheet = destination
        case .fullScreenCover:
            fullScreenCover = destination
        }
    }

    // MARK: - Pop / Dismiss

    /// Pop 栈顶一个页面
    func pop() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }

    /// Pop 到根页面
    func popToRoot() {
        path.removeLast(path.count)
    }

    /// Pop 指定层数
    func pop(_ count: Int) {
        let clamped = min(count, path.count)
        guard clamped > 0 else { return }
        path.removeLast(clamped)
    }

    /// 关闭当前 Sheet
    func dismissSheet() {
        sheet = nil
    }

    /// 关闭当前 FullScreenCover
    func dismissFullScreenCover() {
        fullScreenCover = nil
    }

    /// 关闭所有覆盖层（Sheet + FullScreenCover + Alert）
    func dismissAll() {
        sheet = nil
        fullScreenCover = nil
        alertConfig = nil
    }

    // MARK: - Alert

    /// 展示 Alert
    func showAlert(_ config: AlertConfig) {
        alertConfig = config
    }

    /// 展示简单 Alert
    func showAlert(title: String, message: String = "") {
        alertConfig = AlertConfig(title: title, message: message)
    }
}

// MARK: - RouterView

/// 路由视图包装器：自动绑定 NavigationStack + Sheet + FullScreenCover + Alert
struct RouterView<Destination: Routable, Content: View>: View {
    @ObservedObject var router: Router<Destination>
    let content: () -> Content

    init(router: Router<Destination>, @ViewBuilder content: @escaping () -> Content) {
        self.router = router
        self.content = content
    }

    var body: some View {
        NavigationStack(path: $router.path) {
            content()
                .navigationDestination(for: Destination.self) { destination in
                    destination.body
                }
        }
        .sheet(item: $router.sheet) { destination in
            destination.body
        }
        .fullScreenCover(item: $router.fullScreenCover) { destination in
            destination.body
        }
        .alert(item: $router.alertConfig) { config in
            if let secondary = config.secondaryButton {
                Alert(
                    title: Text(config.title),
                    message: Text(config.message),
                    primaryButton: config.primaryButton,
                    secondaryButton: secondary
                )
            } else {
                Alert(
                    title: Text(config.title),
                    message: Text(config.message),
                    dismissButton: config.primaryButton
                )
            }
        }
    }
}
