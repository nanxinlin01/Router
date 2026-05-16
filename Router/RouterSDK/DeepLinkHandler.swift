//
//  DeepLinkHandler.swift
//  Router
//

import SwiftUI

// MARK: - DeepLinkInfo

/// 深连接信息结构体
struct DeepLinkInfo {
    /// URL Scheme 名称（如 "myapp"）
    let scheme: String?
    /// 路由路径（如 "app/settings" 或 "demo/registered"）
    let path: String
    /// 查询参数（如 ["title": "Hello", "id": "123"]）
    let queryItems: [String: String]
    /// 转换后的路由参数（用于传递给路由系统）
    var routeParams: RouteParams {
        RouteParams(queryItems.mapValues { $0 as Any })
    }
    /// 转场方式（可选，如 "sheet", "windowPush" 等）
    let transition: String?
}

/// 通用深连接解析器：纯 URL 解析，与业务逻辑完全分离
class DeepLinkHandler {
    
    /// 支持的转场方式映射
    static let transitionMap: [String: RouteTransition] = [
        "push": .push(),
        "sheet": .sheet(),
        "fullscreencover": .fullScreenCover,
        "windowsheet": .windowSheet(),
        "windowpush": .windowPush,
        "windowalert": .windowAlert,
        "windowtoast": .windowToast(),
        "windowfade": .windowFade
    ]
    
    /// 解析 URL 为深连接信息（支持标准 URL 格式，包含 scheme）
    /// - Parameter url: 深连接 URL（如 "myapp://app/settings?transition=sheet"）
    /// - Returns: 解析后的深连接信息，如果解析失败返回 nil
    static func parse(_ url: URL) -> DeepLinkInfo? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
              let host = components.host else {
            return nil
        }
        
        // 提取 scheme（如果存在）
        let scheme = components.scheme
        
        // 构建路径（host + path）
        let path: String
        let pathComponent = components.path
        if !pathComponent.isEmpty {
            // 移除开头的斜杠，如 "/settings" -> "settings"
            let cleanPath = pathComponent.hasPrefix("/") ? String(pathComponent.dropFirst()) : pathComponent
            path = cleanPath.isEmpty ? host : "\(host)/\(cleanPath)"
        } else {
            path = host
        }
        
        // 解析查询参数
        let queryItems = (components.queryItems ?? []).reduce(into: [String: String]()) { result, item in
            result[item.name] = item.value
        }
        
        // 提取转场方式参数（如果存在）
        let transition = queryItems["transition"]?.lowercased()
        
        return DeepLinkInfo(scheme: scheme, path: path, queryItems: queryItems, transition: transition)
    }
    
    /// 解析 URL 并自动匹配转场方式
    /// - Parameter url: 深连接 URL
    /// - Returns: (深连接信息, 转场方式) 元组
    static func parseWithTransition(_ url: URL) -> (DeepLinkInfo, RouteTransition)? {
        guard let info = parse(url) else { return nil }
        
        let transition: RouteTransition
        if let transitionKey = info.transition {
            transition = parseTransition(from: transitionKey, queryItems: info.queryItems)
        } else {
            transition = .push() // 默认转场方式
        }
        
        return (info, transition)
    }
    
    /// 解析转场方式（支持主类型:子类型格式）
    /// - Parameters:
    ///   - transitionStr: 转场字符串（如 "windowSheet:fit" 或 "sheet"）
    ///   - queryItems: URL查询参数（用于额外配置）
    /// - Returns: RouteTransition
    private static func parseTransition(from transitionStr: String, queryItems: [String: String]) -> RouteTransition {
        let lowercased = transitionStr.lowercased()
        
        // 检查是否包含子类型（格式：主类型:子类型）
        let components = lowercased.split(separator: ":", maxSplits: 1)
        let mainType = String(components[0])
        let subType = components.count > 1 ? String(components[1]) : nil
        
        switch mainType {
        case "push":
            return .push()
            
        case "sheet":
            return parseSheetConfig(subType: subType, queryItems: queryItems)
            
        case "fullscreencover", "fullscreen":
            return .fullScreenCover
            
        case "alert":
            return .alert(AlertConfig { Alert(title: Text("提示"), message: Text("")) })
            
        case "windowsheet", "wsheet":
            return parseWindowSheetConfig(subType: subType, queryItems: queryItems)
            
        case "windowpush", "wpush":
            return .windowPush
            
        case "windowalert", "walert":
            return .windowAlert
            
        case "windowtoast", "wtoast":
            return parseWindowToastConfig(subType: subType, queryItems: queryItems)
            
        case "windowfade", "wfade":
            return .windowFade
            
        default:
            // 尝试在transitionMap中查找
            if let matched = transitionMap[lowercased] {
                return matched
            }
            return .push() // 默认回退
        }
    }
    
    /// 解析 Sheet 配置
    private static func parseSheetConfig(subType: String?, queryItems: [String: String]) -> RouteTransition {
        var config = SheetConfig()
        
        // 解析子类型（如 sheet:large, sheet:medium, sheet:large,medium）
        if let subType = subType {
            let detentNames = subType.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }
            var detents: Set<PresentationDetent> = []
            
            for name in detentNames {
                switch name {
                case "large":
                    detents.insert(.large)
                case "medium", "half":
                    detents.insert(.medium)
                default:
                    break
                }
            }
            
            if !detents.isEmpty {
                config.detents = detents
            }
        }
        
        return .sheet(config)
    }
    
    /// 解析 windowSheet 配置（从 URL 参数）
    /// - Parameters:
    ///   - subType: 子类型（如 "fit", "half,large", "fixed,400"）
    ///   - queryItems: URL 查询参数
    /// - Returns: 配置好的 RouteTransition
    private static func parseWindowSheetConfig(subType: String?, queryItems: [String: String]) -> RouteTransition {
        var config = WindowSheetConfig()
        
        // 解析子类型（优先）
        if let subType = subType {
            parseWindowSheetSubType(subType, into: &config, queryItems: queryItems)
        }
        // 如果没有子类型或子类型未设置detents，再解析detent(s)参数
        else if config.detents == [.large], let detentsStr = queryItems["detents"] ?? queryItems["detent"] {
            let detentNames = detentsStr.split(separator: ",").map { String($0).lowercased() }
            let detents = detentNames.compactMap { parseDetent(from: $0, queryItems: queryItems) }
            if !detents.isEmpty {
                config.detents = detents
            }
        }
        
        // 解析其他配置参数
        parseWindowSheetAppearance(into: &config, queryItems: queryItems)
        
        return .windowSheet(config)
    }
    
    /// 解析 windowSheet 子类型（如 "fit", "half,large", "fixed,400"）
    private static func parseWindowSheetSubType(_ subType: String, into config: inout WindowSheetConfig, queryItems: [String: String]) {
        let parts = subType.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces).lowercased() }
        
        if parts.isEmpty { return }
        
        // 判断是否为带参数的子类型（如 "fixed,400" 或 "percent,0.7"）
        if parts.count >= 2, let firstPart = parts.first {
            switch firstPart {
            case "fixed", "fixedheight", "height":
                if let height = Double(parts[1]) {
                    config.detents = [.fixedHeight(CGFloat(height))]
                    return
                }
            case "percentage", "percent", "pct":
                if let percentage = Double(parts[1]) {
                    config.detents = [.percentage(CGFloat(percentage))]
                    return
                }
            default:
                break
            }
        }
        
        // 多个detents（如 "half,large,fullscreen"）
        let detents = parts.compactMap { parseDetent(from: $0, queryItems: queryItems) }
        if !detents.isEmpty {
            config.detents = detents
        }
    }
    
    /// 解析 windowSheet 外观配置
    private static func parseWindowSheetAppearance(into config: inout WindowSheetConfig, queryItems: [String: String]) {
        // 解析初始位置索引
        if let indexStr = queryItems["initialDetentIndex"], let index = Int(indexStr) {
            config.initialDetentIndex = index
        }
        
        // 解析圆角
        if let radiusStr = queryItems["cornerRadius"], let radius = Double(radiusStr) {
            config.cornerRadius = CGFloat(radius)
        }
        
        // 解析背景透明度
        if let opacityStr = queryItems["bgOpacity"], let opacity = Double(opacityStr) {
            config.backgroundOpacity = CGFloat(opacity)
        }
        
        // 解析拖拽指示条
        if let indicatorStr = queryItems["showDragIndicator"] {
            config.showDragIndicator = (indicatorStr.lowercased() == "true" || indicatorStr == "1")
        }
        
        // 解析下滑关闭
        if let dismissStr = queryItems["dismissOnDrag"] ?? queryItems["dismissOnDragDown"] {
            config.dismissOnDragDown = (dismissStr.lowercased() == "true" || dismissStr == "1")
        }
    }
    
    /// 解析单个 detent
    /// - Parameters:
    ///   - name: detent 名称
    ///   - queryItems: 查询参数（用于获取 height/percentage 值）
    /// - Returns: WindowSheetDetent
    private static func parseDetent(from name: String, queryItems: [String: String]) -> WindowSheetDetent? {
        switch name {
        case "fullscreen", "full":
            return .fullScreen
        case "large":
            return .large
        case "half", "medium":
            return .half
        case "fitcontent", "fit", "auto":
            return .fitContent
        case "percentage", "percent":
            if let valueStr = queryItems["percentage"], let value = Double(valueStr) {
                return .percentage(CGFloat(value))
            }
            return .percentage(0.5) // 默认 50%
        case "fixed", "fixedheight", "height":
            if let valueStr = queryItems["height"], let value = Double(valueStr) {
                return .fixedHeight(CGFloat(value))
            }
            return .fixedHeight(300) // 默认 300pt
        default:
            return nil
        }
    }
    
    /// 解析 WindowToast 配置
    private static func parseWindowToastConfig(subType: String?, queryItems: [String: String]) -> RouteTransition {
        var config = WindowToastConfig()
        
        // 解析子类型（位置）
        if let subType = subType {
            switch subType.lowercased() {
            case "top":
                config.position = .top
            case "bottom":
                config.position = .bottom
            default:
                break
            }
        }
        
        // 解析持续时间
        if let durationStr = queryItems["duration"], let duration = Double(durationStr) {
            config.duration = duration
        }
        
        return .windowToast(config)
    }
    
    /// 检查 URL 是否匹配指定的 scheme
    /// - Parameters:
    ///   - url: URL
    ///   - expectedScheme: 期望的 scheme（如 "myapp"）
    /// - Returns: 是否匹配
    static func matchesScheme(_ url: URL, _ expectedScheme: String) -> Bool {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true) else {
            return false
        }
        return components.scheme?.lowercased() == expectedScheme.lowercased()
    }
    
    /// 批量检查 URL 是否匹配任意一个 scheme
    /// - Parameters:
    ///   - url: URL
    ///   - expectedSchemes: 期望的 scheme 列表（如 ["myapp", "router"]）
    /// - Returns: 是否匹配其中一个
    static func matchesAnyScheme(_ url: URL, _ expectedSchemes: [String]) -> Bool {
        expectedSchemes.contains { matchesScheme(url, $0) }
    }
}
