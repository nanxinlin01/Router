//
//  Router.swift
//  Router
//
//  注意：此文件现在只包含 Window 组件和辅助类型
//  其他模块已拆分到独立文件：
//  - RoutableProtocols.swift: Routable协议、RouteParams等
//  - DeepLinkHandler.swift: 深连接处理
//  - RouteRegistry.swift: 路由注册中心
//  - RouteTransitions.swift: 转场配置
//  - RouterCore.swift: Router核心管理器
//  - RouterViews.swift: RootRouter、NestedRouter视图
//  - SheetInteraction.swift: Sheet交互处理

import SwiftUI
import Combine
import UIKit

// MARK: - WindowSheetCoordinator

/// 管理 WindowSheet 的 UIWindow 生命周期
@MainActor
final class WindowSheetCoordinator: ObservableObject {
    private var window: UIWindow?
    private let dismissSubject = PassthroughSubject<Void, Never>()
    private var pendingPresentation: (presentation: RoutePresentation, onDismiss: () -> Void)?
    private var retryTimer: Timer?
    
    deinit {
        // 清理 Timer，防止内存泄漏
        retryTimer?.invalidate()
        retryTimer = nil
    }

    /// 统一呈现方法（枚举路由和注册路由共用）
    func present(presentation: RoutePresentation, onDismiss: @escaping () -> Void) {
        print("[WindowSheetCoordinator] present 被调用")
        guard window == nil else { 
            print("[WindowSheetCoordinator] window 已存在，返回")
            return 
        }
        
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive })
        else { 
            print("[WindowSheetCoordinator] 未找到活跃场景，启动重试机制")
            // 保存 pending 状态，等待重试
            pendingPresentation = (presentation, onDismiss)
            // 启动重试定时器，每 0.1 秒重试一次，最多 2 秒（增强内存安全）
            retryTimer?.invalidate()
            var retryCount = 0
            // 使用 weak self 和 weak timer 确保在 self 释放时 timer 能被正确清理
            retryTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] timer in
                retryCount += 1
                print("[WindowSheetCoordinator] 重试 #\(retryCount) 查找活跃场景")
                
                DispatchQueue.main.async { [weak self] in
                    guard let self else { 
                        // self 已释放，清理 timer 防止泄漏
                        timer.invalidate()
                        return 
                    }
                    
                    if let scene = UIApplication.shared.connectedScenes
                        .compactMap({ $0 as? UIWindowScene })
                        .first(where: { $0.activationState == .foregroundActive }),
                       let pending = self.pendingPresentation {
                        print("[WindowSheetCoordinator] 重试成功，找到活跃场景")
                        timer.invalidate()
                        self.retryTimer = nil
                        self.pendingPresentation = nil
                        self.createWindow(for: scene, presentation: pending.presentation, onDismiss: pending.onDismiss)
                    } else if retryCount >= 20 { // 2 秒超时
                        print("[WindowSheetCoordinator] 重试超时，放弃呈现")
                        timer.invalidate()
                        self.retryTimer = nil
                        self.pendingPresentation = nil
                        onDismiss() // 清理状态
                    }
                }
            }
            return 
        }
        
        print("[WindowSheetCoordinator] 开始创建 windowSheet")
        createWindow(for: scene, presentation: presentation, onDismiss: onDismiss)
    }
    
    /// 创建窗口（内部方法）
    private func createWindow(for scene: UIWindowScene, presentation: RoutePresentation, onDismiss: @escaping () -> Void) {
        print("[WindowSheetCoordinator] createWindow 被调用")
        
        let config = presentation.windowSheetConfig
        let interaction = SheetInteraction()
        let panHandler = SheetPanHandler()
        panHandler.interaction = interaction
        panHandler.dismissOnDragDown = config.dismissOnDragDown
        interaction.detentCount = config.detents.count

        let hasFitContent = config.detents.contains(.fitContent)

        let container = WindowSheetContainerView(
            config: config,
            interaction: interaction,
            dismissTrigger: dismissSubject.eraseToAnyPublisher(),
            onDismissCompleted: { [weak self] in
                self?.removeWindow()
                onDismiss()
            },
            measurementView: hasFitContent ? presentation.rawView : nil
        ) {
            presentation.view
        }

        let w = UIWindow(windowScene: scene)
        w.windowLevel = .normal + 100
        w.backgroundColor = .clear

        let hostVC = NoSafeAreaHostingController(rootView: container)
        hostVC.sheetPanHandler = panHandler
        hostVC.view.backgroundColor = .clear
        panHandler.attach(to: hostVC.view)
        w.rootViewController = hostVC
        w.makeKeyAndVisible()
        self.window = w
        
        print("[WindowSheetCoordinator] windowSheet 创建成功")
    }

    func dismissIfNeeded() {
        guard window != nil else { return }
        dismissSubject.send()
    }

    private func removeWindow() {
        window?.isHidden = true
        window = nil
    }
}

// MARK: - WindowSheetContainerView

/// WindowSheet 容器视图：处理遮罩、圆角、多档位拖拽吸附与弹出/收回动画
struct WindowSheetContainerView<Content: View>: View {
    let config: WindowSheetConfig
    @ObservedObject var interaction: SheetInteraction
    let dismissTrigger: AnyPublisher<Void, Never>
    let onDismissCompleted: () -> Void
    /// 仅用于 fitContent 测量的裸视图（不含 NavigationStack）
    let measurementView: AnyView?
    @ViewBuilder let content: () -> Content

    @State private var isPresented = false
    @State private var currentDetentIndex: Int = 0
    @State private var measuredContentHeight: CGFloat = 0
    @State private var cachedTopSafeArea: CGFloat = 0
    @State private var cachedScreenHeight: CGFloat = UIScreen.main.bounds.height

    /// 实时读取屏幕高度（支持旋转，带缓存优化）
    private var screenHeight: CGFloat {
        // 优先使用缓存值，减少每次布局时的场景遍历开销
        if let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }),
           let windowHeight = scene.windows.first?.bounds.height {
            cachedScreenHeight = windowHeight
        }
        return cachedScreenHeight
    }

    /// 当 sheet 接近顶部安全区时，动态增加顶部 padding；向下拖时逐渐收回
    private var dynamicTopPadding: CGFloat {
        guard config.respectsTopSafeArea else { return 0 }
        let gap = screenHeight - sheetFrameHeight + max(0, interaction.dragOffset)
        return max(0, cachedTopSafeArea - gap)
    }

    /// 是否包含 fitContent 模式
    private var hasFitContent: Bool {
        config.detents.contains(.fitContent)
    }

    /// 将 detent 解析为具体高度
    private func resolveHeight(_ detent: WindowSheetDetent) -> CGFloat {
        switch detent {
        case .fullScreen:        return screenHeight
        case .large:             return screenHeight * 0.92
        case .half:              return screenHeight * 0.5
        case .percentage(let p): return screenHeight * min(max(p, 0), 1)
        case .fixedHeight(let h): return min(h, screenHeight)
        case .fitContent:        return min(measuredContentHeight, screenHeight * 0.92)
        }
    }

    /// 所有 detent 高度（升序排列）
    private var sortedHeights: [CGFloat] {
        config.detents.map { resolveHeight($0) }.sorted()
    }

    /// 最大 detent 高度（Sheet frame 使用此值）
    private var maxHeight: CGFloat {
        sortedHeights.last ?? screenHeight * 0.92
    }

    /// 当前 detent 高度
    private var currentHeight: CGFloat {
        let heights = sortedHeights
        guard currentDetentIndex >= 0, currentDetentIndex < heights.count else {
            return heights.last ?? screenHeight * 0.92
        }
        return heights[currentDetentIndex]
    }

    /// 遮罩透明度系数（随当前可见高度变化）
    private var dimFraction: Double {
        let visibleHeight = sheetFrameHeight - max(0, interaction.dragOffset)
        let effective = max(0, visibleHeight)
        return maxHeight > 0 ? max(0, min(1, Double(effective / maxHeight))) : 1
    }

    /// Sheet frame 高度（向上拖时增大，向下拖时保持不变）
    private var sheetFrameHeight: CGFloat {
        let drag = interaction.dragOffset
        if drag >= 0 {
            // 向下拖 或 静止：保持当前档位高度
            return currentHeight
        }
        // 向上拖：frame 增大，不超过 maxHeight（超出部分橡皮筋）
        let extra = -drag
        let available = maxHeight - currentHeight
        if extra <= available {
            return currentHeight + extra
        }
        let excess = extra - available
        return maxHeight + pow(excess, 0.7) * 0.15
    }

    /// Sheet 相对底部的偏移（仅向下拖时产生）
    private var sheetOffset: CGFloat {
        if !isPresented { return screenHeight }
        return max(0, interaction.dragOffset)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            // 遮罩背景
            Color.black
                .opacity(isPresented ? config.backgroundOpacity * dimFraction : 0)
                .ignoresSafeArea()
                .onTapGesture { animateDismiss() }

            // Sheet 主体
            ZStack(alignment: .top) {
                // 填充顶部安全区间距，颜色与内容背景一致
                config.contentBackgroundColor
                content()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.top, dynamicTopPadding)
                if config.showDragIndicator && dynamicTopPadding <= 0
                    && (interaction.dragOffset > 0 || (screenHeight - sheetFrameHeight) > max(cachedTopSafeArea, 20)) {
                    dragIndicator
                }
            }
            .frame(height: sheetFrameHeight)
            .overlay(
                // fitContent 测量：用裸视图（无 NavigationStack）测量自然高度
                Group {
                    if let mv = measurementView {
                        VStack(spacing: 0) {
                            if config.showDragIndicator {
                                dragIndicator
                            }
                            mv
                        }
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity)
                        .hidden()
                        .background(
                            GeometryReader { geo in
                                Color.clear.preference(key: ContentHeightPrefKey.self, value: geo.size.height)
                            }
                        )
                    }
                }
                , alignment: .top
            )
            .onPreferenceChange(ContentHeightPrefKey.self) { h in
                if hasFitContent && h > 0 {
                    measuredContentHeight = h
                }
            }
            .background(.regularMaterial)
            .clipShape(RoundedCornerShape(radius: config.cornerRadius, corners: [.topLeft, .topRight]))
            .offset(y: sheetOffset)
        }
        .ignoresSafeArea()
        .onAppear {
            let count = sortedHeights.count
            if let idx = config.initialDetentIndex, idx >= 0, idx < count {
                currentDetentIndex = idx
            } else {
                // 单个 detent 默认最大；多个 detent 默认最小
                currentDetentIndex = count > 1 ? 0 : count - 1
            }
            interaction.currentSheetHeight = currentHeight
            interaction.currentDetentIndex = currentDetentIndex
            interaction.detentCount = sortedHeights.count
            updateTopSafeArea()
            withAnimation(.spring(response: 0.45, dampingFraction: 0.86)) {
                isPresented = true
            }
        }
        .onReceive(dismissTrigger) { _ in
            animateDismiss()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
            // 旋转后延迟一帧等待布局完成，再更新安全区
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                updateTopSafeArea()
            }
        }
        .onReceive(interaction.dragEnded) { (translation, velocity) in
            let predicted = translation + velocity * 0.2
            let targetHeight = currentHeight - predicted
            snapToDetent(targetHeight: targetHeight, isDraggingDown: translation > 0)
        }
    }

    // MARK: - Snap Logic

    /// 根据目标高度吸附到最近的 detent，或关闭
    private func snapToDetent(targetHeight: CGFloat, isDraggingDown: Bool) {
        let heights = sortedHeights
        let smallestHeight = heights.first ?? 0

        // 向下拖拽且目标低于最小 detent 的 60% → 关闭
        if config.dismissOnDragDown && isDraggingDown && targetHeight < smallestHeight * 0.6 {
            animateDismiss()
            return
        }

        // 找到距离目标最近的 detent
        var bestIndex = currentDetentIndex
        var bestDist: CGFloat = .infinity
        for (i, h) in heights.enumerated() {
            let dist = abs(targetHeight - h)
            if dist < bestDist {
                bestDist = dist
                bestIndex = i
            }
        }

        let newHeight = heights[bestIndex]
        // 档位切换和 dragOffset 归零必须在同一个动画块内，避免闪烁
        withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
            currentDetentIndex = bestIndex
            interaction.dragOffset = 0
        }
        // 非动画属性在动画块后更新
        interaction.currentDetentIndex = bestIndex
        interaction.currentSheetHeight = newHeight
    }

    // MARK: - Subviews

    /// 拖拽指示条
    private var dragIndicator: some View {
        Capsule()
            .fill(Color(.systemGray3))
            .frame(width: 36, height: 5)
            .padding(.top, 8)
            .padding(.bottom, 4)
    }

    /// 执行关闭动画并回调
    private func animateDismiss() {
        guard isPresented else { return }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
            isPresented = false
            interaction.dragOffset = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            onDismissCompleted()
        }
    }

    /// 更新顶部安全区缓存（旋转后安全区可能变化）
    private func updateTopSafeArea() {
        if let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }),
           let w = windowScene.windows.first {
            cachedTopSafeArea = w.safeAreaInsets.top
        }
    }
}

// MARK: - Helper Types

/// WindowPush 左侧边缘手势处理器：纯 UIKit 驱动窗口位移
final class PushEdgePanHandler: NSObject, UIGestureRecognizerDelegate {
    weak var edgeGesture: UIScreenEdgePanGestureRecognizer?
    weak var pushWindow: UIWindow?
    weak var previousWindow: UIWindow?
    weak var dimmingView: UIView?
    var onPopCompleted: (() -> Void)?

    /// 实时屏幕宽度（支持旋转）
    private var currentScreenWidth: CGFloat {
        pushWindow?.bounds.width ?? UIScreen.main.bounds.width
    }

    func attach(to view: UIView) {
        guard edgeGesture == nil else { return }
        let edge = UIScreenEdgePanGestureRecognizer(target: self, action: #selector(handleEdgePan(_:)))
        edge.edges = .left
        edge.delegate = self
        view.addGestureRecognizer(edge)
        self.edgeGesture = edge
    }

    @objc private func handleEdgePan(_ gesture: UIScreenEdgePanGestureRecognizer) {
        guard let view = gesture.view else { return }
        let screenWidth = currentScreenWidth
        switch gesture.state {
        case .began:
            // 手势开始时校正 previousWindow 位置，修复旋转后 frame 异常
            if let prev = previousWindow {
                prev.transform = .identity
                prev.frame = pushWindow?.frame ?? prev.frame
                prev.transform = CGAffineTransform(translationX: -screenWidth * 0.3, y: 0)
            }
        case .changed:
            let tx = max(0, gesture.translation(in: view).x)
            let fraction = min(1, tx / screenWidth)
            pushWindow?.transform = CGAffineTransform(translationX: tx, y: 0)
            previousWindow?.transform = CGAffineTransform(translationX: -screenWidth * 0.3 * (1 - fraction), y: 0)
            dimmingView?.alpha = 0.15 * (1 - fraction)
        case .ended, .cancelled:
            let tx = gesture.translation(in: view).x
            let vx = gesture.velocity(in: view).x
            let fraction = tx / screenWidth
            if vx > 500 || fraction > 0.4 {
                // 完成 pop
                let remaining = screenWidth - tx
                let duration = min(0.3, max(0.1, TimeInterval(remaining / max(vx, 500))))
                UIView.animate(withDuration: duration, delay: 0, options: .curveEaseOut, animations: {
                    self.pushWindow?.transform = CGAffineTransform(translationX: self.currentScreenWidth, y: 0)
                    self.previousWindow?.transform = .identity
                    self.dimmingView?.alpha = 0
                }, completion: { _ in
                    self.onPopCompleted?()
                })
            } else {
                // 回弹
                UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseOut, animations: {
                    self.pushWindow?.transform = .identity
                    self.previousWindow?.transform = CGAffineTransform(translationX: -self.currentScreenWidth * 0.3, y: 0)
                    self.dimmingView?.alpha = 0.15
                })
            }
        default:
            break
        }
    }

    // MARK: - UIGestureRecognizerDelegate

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let view = gestureRecognizer.view else { return false }
        return !SheetPanHandler.hasNavDepth(in: view)
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return false
    }
}

// MARK: - WindowPushCoordinator

/// 管理 WindowPush 的 UIWindow 生命周期，纯 UIKit 动画驱动
@MainActor
final class WindowPushCoordinator: ObservableObject {
    private var window: UIWindow?
    private var previousWindow: UIWindow?
    private var dimmingView: UIView?
    private var panHandler: PushEdgePanHandler?
    private var boundsObservation: NSKeyValueObservation?
    private var onDismissCallback: (() -> Void)?

    /// 统一呈现方法（枚举路由和注册路由共用）
    func present(presentation: RoutePresentation, onDismiss: @escaping () -> Void) {
        guard window == nil else { return }
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive })
        else { return }

        self.onDismissCallback = onDismiss
        let screenWidth = UIScreen.main.bounds.width

        let prevWindow = scene.windows.last(where: { !$0.isHidden && $0.windowLevel < .alert })
        self.previousWindow = prevWindow

        let dimView = UIView(frame: prevWindow?.bounds ?? UIScreen.main.bounds)
        dimView.backgroundColor = .black
        dimView.alpha = 0
        dimView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        prevWindow?.addSubview(dimView)
        self.dimmingView = dimView

        let w = UIWindow(windowScene: scene)
        w.windowLevel = .normal + 100
        w.backgroundColor = .systemBackground
        w.layer.shadowColor = UIColor.black.cgColor
        w.layer.shadowOpacity = 0.2
        w.layer.shadowRadius = 10
        w.layer.shadowOffset = CGSize(width: -5, height: 0)

        let hostVC = UIHostingController(rootView: presentation.view)
        hostVC.view.backgroundColor = .systemBackground
        w.rootViewController = hostVC
        w.makeKeyAndVisible()
        hostVC.view.setNeedsLayout()
        hostVC.view.layoutIfNeeded()
        w.transform = CGAffineTransform(translationX: screenWidth, y: 0)
        self.window = w

        let handler = PushEdgePanHandler()
        handler.pushWindow = w
        handler.previousWindow = prevWindow
        handler.dimmingView = dimView
        handler.onPopCompleted = { [weak self] in
            self?.onGesturePopCompleted()
        }
        handler.attach(to: hostVC.view)
        self.panHandler = handler

        DispatchQueue.main.async { [weak w, weak prevWindow, weak self] in
            guard let w = w else { return }
            let screenWidth = w.bounds.width
            UIView.animate(withDuration: 0.35, delay: 0, options: .curveEaseOut, animations: {
                w.transform = .identity
                prevWindow?.transform = CGAffineTransform(translationX: -screenWidth * 0.3, y: 0)
                self?.dimmingView?.alpha = 0.15
            })
        }

        boundsObservation = w.observe(\.bounds, options: [.new, .old]) { [weak self] _, change in
            guard let oldVal = change.oldValue, let newVal = change.newValue,
                  oldVal.size != newVal.size else { return }
            Task { @MainActor [weak self] in
                self?.updateLayoutAfterRotation()
            }
        }
    }

    /// 屏幕旋转后重新计算偏移量
    private func updateLayoutAfterRotation() {
        guard let w = window else { return }
        let newWidth = w.bounds.width
        // Push 窗口已完全展示（transform == .identity）时，重新设置底层偏移
        if w.transform == .identity, let prev = previousWindow {
            // 旋转时 UIKit 对带 transform 的 window 调整 frame 可能导致 center 异常
            // 先重置 transform→修正 frame→再应用偏移
            prev.transform = .identity
            prev.frame = w.frame
            prev.transform = CGAffineTransform(translationX: -newWidth * 0.3, y: 0)
        }
    }

    /// 程序化 dismiss（router.windowPush = nil 触发）
    func dismissIfNeeded() {
        guard let w = window else { return }
        let screenWidth = w.bounds.width
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseIn, animations: {
            w.transform = CGAffineTransform(translationX: screenWidth, y: 0)
            self.previousWindow?.transform = .identity
            self.dimmingView?.alpha = 0
        }, completion: { _ in
            self.removeWindow()
        })
    }

    /// 手势 pop 完成回调
    private func onGesturePopCompleted() {
        removeWindow()
        onDismissCallback?()
    }

    private func removeWindow() {
        boundsObservation?.invalidate()
        boundsObservation = nil
        dimmingView?.removeFromSuperview()
        dimmingView = nil
        previousWindow?.transform = .identity
        window?.isHidden = true
        window = nil
        previousWindow = nil
        panHandler = nil
        onDismissCallback = nil
    }
}

// MARK: - WindowAlertCoordinator

/// 管理 WindowAlert 的 UIWindow 生命周期（支持多层嵌套）
@MainActor
final class WindowAlertCoordinator: ObservableObject {
    private var windows: [(UIWindow, PassthroughSubject<Void, Never>)] = []
    /// 所有窗口关闭后的回调
    private var onAllDismissedCallback: (() -> Void)?

    /// 是否有活跃窗口
    var hasActiveWindows: Bool { !windows.isEmpty }

    /// 统一呈现方法（支持多层堆叠，只在最后一个窗口关闭时回调）
    func present(presentation: RoutePresentation, onAllDismissed: @escaping () -> Void) {
        self.onAllDismissedCallback = onAllDismissed
        presentInternal(contentView: presentation.view)
    }

    private func presentInternal(contentView: AnyView) {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive })
        else { return }

        let dismissSubject = PassthroughSubject<Void, Never>()
        let index = windows.count

        let container = WindowAlertContainerView(
            dismissTrigger: dismissSubject.eraseToAnyPublisher(),
            onDismissCompleted: { [weak self] in
                self?.removeWindow(at: index)
                if self?.windows.isEmpty == true {
                    self?.onAllDismissedCallback?()
                    self?.onAllDismissedCallback = nil
                }
            }
        ) {
            contentView
        }

        let w = UIWindow(windowScene: scene)
        w.windowLevel = .alert + 200 + CGFloat(windows.count)
        w.backgroundColor = UIColor.clear

        let hostVC = ClearBackgroundHostingController(rootView: container)
        hostVC.view.backgroundColor = UIColor.clear
        w.rootViewController = hostVC
        w.makeKeyAndVisible()
        windows.append((w, dismissSubject))
    }

    /// 关闭最顶层窗口（带动画）
    func dismissIfNeeded() {
        guard let last = windows.last else { return }
        last.1.send()
    }

    /// 立即关闭所有窗口（用于 dismissAll）
    func dismissAllWindows() {
        for (window, _) in windows {
            window.isHidden = true
        }
        windows.removeAll()
        onAllDismissedCallback?()
        onAllDismissedCallback = nil
    }

    private func removeWindow(at index: Int) {
        guard index < windows.count else { return }
        windows[index].0.isHidden = true
        windows.remove(at: index)
    }
}

// MARK: - WindowFadeCoordinator

/// 管理 WindowFade 的 UIWindow 生命周期，支持多层叠加
@MainActor
final class WindowFadeCoordinator: ObservableObject {
    private var windows: [(UIWindow, PassthroughSubject<Void, Never>)] = []

    /// 统一呈现方法（枚举路由和注册路由共用）
    func present(presentation: RoutePresentation, onDismiss: @escaping () -> Void) {
        presentInternal(contentView: presentation.view, onDismiss: onDismiss)
    }

    private func presentInternal(contentView: AnyView, onDismiss: @escaping () -> Void) {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive })
        else { return }

        let dismissSubject = PassthroughSubject<Void, Never>()
        let index = windows.count

        let container = WindowFadeContainerView(
            dismissTrigger: dismissSubject.eraseToAnyPublisher(),
            onDismissCompleted: { [weak self] in
                self?.removeWindow(at: index)
                onDismiss()
            }
        ) {
            contentView
        }

        let w = UIWindow(windowScene: scene)
        w.windowLevel = .normal + 100
        w.backgroundColor = UIColor.clear

        let hostVC = ClearBackgroundHostingController(rootView: container)
        hostVC.view.backgroundColor = UIColor.clear
        w.rootViewController = hostVC
        w.makeKeyAndVisible()
        windows.append((w, dismissSubject))
    }

    func dismissIfNeeded() {
        guard let last = windows.last else { return }
        last.1.send()
    }

    private func removeWindow(at index: Int) {
        guard index < windows.count else { return }
        windows[index].0.isHidden = true
        windows.remove(at: index)
    }
}

// MARK: - WindowFadeContainerView

/// WindowFade 容器视图：遮罩 + 全屏内容 + 淡入淡出动画
struct WindowFadeContainerView<Content: View>: View {
    let dismissTrigger: AnyPublisher<Void, Never>
    let onDismissCompleted: () -> Void
    @ViewBuilder let content: () -> Content

    @State private var isPresented = false

    var body: some View {
        ZStack {
            // 遮罩背景
            Color.black
                .opacity(isPresented ? 0.3 : 0)
                .ignoresSafeArea()

            // 全屏内容
            content()
                .opacity(isPresented ? 1.0 : 0)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.3)) {
                isPresented = true
            }
        }
        .onReceive(dismissTrigger) { _ in
            animateDismiss()
        }
    }

    private func animateDismiss() {
        guard isPresented else { return }
        withAnimation(.easeInOut(duration: 0.3)) {
            isPresented = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            onDismissCompleted()
        }
    }
}

// MARK: - WindowAlertContainerView

/// WindowAlert 容器视图：遮罩 + 居中内容 + 缩放/淡入淡出动画
struct WindowAlertContainerView<Content: View>: View {
    let dismissTrigger: AnyPublisher<Void, Never>
    let onDismissCompleted: () -> Void
    @ViewBuilder let content: () -> Content

    @State private var isPresented = false

    var body: some View {
        ZStack {
            // 遮罩背景
            Color.black
                .opacity(isPresented ? 0.3 : 0)
                .ignoresSafeArea()
                .onTapGesture { animateDismiss() }

            // 自定义内容
            content()
                .scaleEffect(isPresented ? 1.0 : 1.2)
                .opacity(isPresented ? 1.0 : 0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                isPresented = true
            }
        }
        .onReceive(dismissTrigger) { _ in
            animateDismiss()
        }
    }

    /// 执行关闭动画并回调
    private func animateDismiss() {
        guard isPresented else { return }
        withAnimation(.easeOut(duration: 0.2)) {
            isPresented = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            onDismissCompleted()
        }
    }
}

// MARK: - WindowToastCoordinator

/// 管理 WindowToast 的 UIWindow 生命周期，支持多层叠加
@MainActor
final class WindowToastCoordinator: ObservableObject {
    private var windows: [(UIWindow, PassthroughSubject<Void, Never>)] = []

    /// 统一呈现方法（枚举路由和注册路由共用）
    func present(presentation: RoutePresentation, onDismiss: @escaping () -> Void) {
        presentInternal(contentView: presentation.view, config: presentation.windowToastConfig, onDismiss: onDismiss)
    }

    private func presentInternal(contentView: AnyView, config: WindowToastConfig, onDismiss: @escaping () -> Void) {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive })
        else { return }

        let dismissSubject = PassthroughSubject<Void, Never>()
        let index = windows.count

        let w = ToastWindow(windowScene: scene)
        w.windowLevel = .alert + 300 + CGFloat(windows.count)
        w.backgroundColor = .clear
        w.passThroughEmptyArea = !config.showDimming
        w.interceptToastContent = config.dismissOnTap

        let container = WindowToastContainerView(
            config: config,
            dismissTrigger: dismissSubject.eraseToAnyPublisher(),
            onDismissCompleted: { [weak self] in
                self?.removeWindow(at: index)
                onDismiss()
            },
            onToastFrameChanged: { [weak w] frame in
                w?.toastFrame = frame
            }
        ) {
            contentView
        }

        let hostVC = ClearBackgroundHostingController(rootView: container)
        hostVC.view.backgroundColor = .clear
        w.rootViewController = hostVC
        w.makeKeyAndVisible()
        windows.append((w, dismissSubject))
    }

    func dismissIfNeeded() {
        guard let last = windows.last else { return }
        last.1.send()
    }

    private func removeWindow(at index: Int) {
        guard index < windows.count else { return }
        windows[index].0.isHidden = true
        windows.remove(at: index)
    }
}

// MARK: - ToastWindow

/// Toast 专用窗口：支持在 Toast 区域外自动穿透触摸
private class ToastWindow: UIWindow {
    /// 是否对空白区域穿透（无遮罩模式）
    var passThroughEmptyArea = false
    /// 是否拦截 Toast 内容区域的触摸（点击关闭）
    var interceptToastContent = true
    /// Toast 内容区域（全局坐标，由 SwiftUI GeometryReader 更新）
    var toastFrame: CGRect = .zero

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard passThroughEmptyArea else {
            // 有遮罩模式：整个窗口响应
            return super.hitTest(point, with: event)
        }
        guard interceptToastContent else {
            // 不拦截 Toast 点击：整个窗口全部穿透
            return nil
        }
        // 触摸点在 Toast 区域内 → 拦截，否则穿透
        let pointInScreen = convert(point, to: nil)
        guard !toastFrame.isEmpty, toastFrame.contains(pointInScreen) else {
            return nil
        }
        return super.hitTest(point, with: event)
    }
}

// MARK: - WindowToastContainerView

/// WindowToast 容器视图：支持顶部/底部滑入滑出动画，自动消失
struct WindowToastContainerView<Content: View>: View {
    let config: WindowToastConfig
    let dismissTrigger: AnyPublisher<Void, Never>
    let onDismissCompleted: () -> Void
    let onToastFrameChanged: (CGRect) -> Void
    @ViewBuilder let content: () -> Content

    @State private var isPresented = false
    @State private var toastFrame: CGRect = .zero

    var body: some View {
        ZStack {
            // 背景遮罩：有 dimming 时显示半透明黑色并拦截点击，无 dimming 时不渲染
            if config.showDimming {
                Color.black
                    .opacity(isPresented ? config.backgroundOpacity : 0)
                    .ignoresSafeArea()
                    .onTapGesture { animateDismiss() }
            }

            // Toast 内容
            VStack {
                if config.position == .bottom {
                    Spacer()
                }

                if isPresented {
                    content()
                        .fixedSize(horizontal: false, vertical: true)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if config.dismissOnTap {
                                animateDismiss()
                            }
                        }
                        .transition(
                            .move(edge: config.position == .top ? .top : .bottom)
                            .combined(with: .opacity)
                        )
                        .overlay(
                            GeometryReader { geo in
                                Color.clear
                                    .onAppear { toastFrame = geo.frame(in: .global) }
                                    .onChange(of: geo.frame(in: .global)) { toastFrame = $0 }
                            }
                        )
                }

                if config.position == .top {
                    Spacer()
                }
            }
        }
        .onChange(of: toastFrame) { frame in
            onToastFrameChanged(frame)
        }
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                isPresented = true
            }
            // 自动消失
            if let duration = config.duration {
                DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                    animateDismiss()
                }
            }
        }
        .onReceive(dismissTrigger) { _ in
            animateDismiss()
        }
    }

    private func animateDismiss() {
        guard isPresented else { return }
        withAnimation(.easeOut(duration: 0.25)) {
            isPresented = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onDismissCompleted()
        }
    }
}

// MARK: - Other Helper Types

/// 自动清除子视图层级中 NavigationController 背景色的 HostingController
private class ClearBackgroundHostingController<V: View>: UIHostingController<V> {
    private var didClearBackground = false

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        guard !didClearBackground else { return }
        didClearBackground = true

        DispatchQueue.main.async {
            self.clearNavigationBackground(in: self)
        }
    }

    private func clearNavigationBackground(in viewController: UIViewController) {
        if let nav = viewController as? UINavigationController {
            nav.view.backgroundColor = .clear
            nav.view.isOpaque = false
            nav.viewControllers.forEach { vc in
                vc.view.backgroundColor = .clear
                vc.view.isOpaque = false
            }
            return
        }
        for child in viewController.children {
            clearNavigationBackground(in: child)
        }
    }
}

/// 移除安全区域的 UIHostingController（兼容 iOS 16+）
private class NoSafeAreaHostingController<V: View>: UIHostingController<V> {
    var sheetPanHandler: SheetPanHandler?

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        guard let windowInsets = view.window?.safeAreaInsets else { return }
        let target = UIEdgeInsets(
            top: -windowInsets.top,
            left: -windowInsets.left,
            bottom: -windowInsets.bottom,
            right: -windowInsets.right
        )
        if additionalSafeAreaInsets != target {
            additionalSafeAreaInsets = target
        }
    }
}

private struct ContentHeightPrefKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

/// 仅顶部圆角的自定义 Shape
struct RoundedCornerShape: Shape {
    var radius: CGFloat
    var corners: UIRectCorner

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

// MARK: - ParentRouterDismiss Environment Key

private struct ParentRouterDismissKey: EnvironmentKey {
    static let defaultValue: (Int) -> Void = { _ in }
}

private struct ParentRouterDismissToKey: EnvironmentKey {
    static let defaultValue: (Any) -> Void = { _ in }
}

extension EnvironmentValues {
    var parentRouterDismiss: (Int) -> Void {
        get { self[ParentRouterDismissKey.self] }
        set { self[ParentRouterDismissKey.self] = newValue }
    }
    var parentRouterDismissTo: (Any) -> Void {
        get { self[ParentRouterDismissToKey.self] }
        set { self[ParentRouterDismissToKey.self] = newValue }
    }
}

// MARK: - Router DeepLink Extension

/// Router 深连接扩展：支持注册路由的深连接处理（包括 URL Scheme）
extension Router {
    
    // MARK: - 按 Scheme 过滤的深连接处理
    
    /// 处理指定 scheme 的深连接（忽略其他 scheme）
    /// - Parameters:
    ///   - url: URL
    ///   - allowedSchemes: 允许的 scheme 列表（如 ["myapp", "router"]）
    ///   - transition: 转场方式（可选）
    /// - Returns: 是否成功处理
    @discardableResult
    func handleDeepLinkIfSchemeMatches(
        _ url: URL,
        allowedSchemes: [String],
        transition: RouteTransition? = nil
    ) -> Bool {
        // 检查 scheme 是否匹配
        guard DeepLinkHandler.matchesAnyScheme(url, allowedSchemes) else {
            print("[DeepLink] Scheme 不匹配，忽略: \(url)")
            return false
        }
        
        // scheme 匹配，继续处理深连接
        return handleRegisteredDeepLink(url, transition: transition)
    }
    
    /// 处理指定 scheme 的深连接（单个 scheme）
    /// - Parameters:
    ///   - url: URL
    ///   - allowedScheme: 允许的 scheme（如 "myapp"）
    ///   - transition: 转场方式（可选）
    /// - Returns: 是否成功处理
    @discardableResult
    func handleDeepLinkIfSchemeMatches(
        _ url: URL,
        allowedScheme: String,
        transition: RouteTransition? = nil
    ) -> Bool {
        handleDeepLinkIfSchemeMatches(url, allowedSchemes: [allowedScheme], transition: transition)
    }
    
    // MARK: - 深连接处理
    
    /// 处理注册路由深连接（URL -> AutoRoute 路径）
    /// - Parameters:
    ///   - url: 深连接 URL
    ///   - transition: 转场方式（可选）
    /// - Returns: 是否成功处理
    @discardableResult
    func handleRegisteredDeepLink(_ url: URL, transition: RouteTransition? = nil) -> Bool {
        // 1. 解析 URL
        guard let (deepLinkInfo, parsedTransition) = DeepLinkHandler.parseWithTransition(url) else {
            print("[DeepLink] 注册路由解析失败: \(url)")
            return false
        }
        
        print("[DeepLink] 解析结果 - path: \(deepLinkInfo.path), queryItems: \(deepLinkInfo.queryItems), transition: \(deepLinkInfo.transition ?? "nil")")
        
        // 2. 检查路径是否已注册
        guard RouteRegistry.shared.isRegistered(path: deepLinkInfo.path) else {
            print("[DeepLink] 注册路由未找到: \(deepLinkInfo.path)")
            print("[DeepLink] 已注册的路由: \(RouteRegistry.shared.registeredPaths)")
            return false
        }
        
        // 3. 执行导航（优先使用传入的 transition，其次使用 URL 中的 transition）
        let finalTransition = transition ?? parsedTransition
        print("[DeepLink] 注册路由导航: \(deepLinkInfo.path), transition: \(finalTransition)")
        present(path: deepLinkInfo.path, params: deepLinkInfo.routeParams, via: finalTransition)
        return true
    }
}
