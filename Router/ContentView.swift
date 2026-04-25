//
//  ContentView.swift
//  Router
//
//  Created by 南鑫林 on 2026/4/24.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        RootRouter {
            HomeView()
        }
    }
}

// MARK: - HomeView

struct HomeView: View {
    @EnvironmentObject private var router: Router<AppRoute>

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
                Button("Push 详情页") {
                    router.present(to: .detail(title: "Hello Router!"))
                }
                Button("Push 设置页") {
                    router.present(to: .settings)
                }
            }

            Section("全部路由嵌套") {
                Button("→ Push") { router.present(to: .detail(title: "首页→Push")) }
                Button("→ Sheet") { router.present(to: .profile(name: "首页-Sheet"), via: .sheet()) }
                Button("→ FullScreenCover") { router.present(to: .settings, via: .fullScreenCover) }
                Button("→ WindowSheet") { router.present(to: .profile(name: "首页-WS"), via: .windowSheet()) }
                Button("→ WindowPush") { router.present(to: .settings, via: .windowPush) }
                Button("→ WindowAlert") { router.present(to: .customAlertDemo(title: "首页", message: "首页的 WindowAlert"), via: .windowAlert) }
                Button("→ WindowFade") { router.present(to: .detail(title: "首页-Fade"), via: .windowFade) }
            }

            Section("Sheet") {
                Button("Sheet 个人页") {
                    router.present(to: .profile(name: "Sheet-Jeremy"), via: .sheet())
                }
                Button("Sheet 设置页") {
                    router.present(to: .settings, via: .sheet())
                }
                Button("Sheet 半屏") {
                    router.present(to: .profile(name: "Sheet-半屏"), via: .sheet(SheetConfig(detent: .medium, showDragIndicator: true)))
                }
                Button("Sheet 半屏 ↔ Large") {
                    router.present(to: .settings, via: .sheet(SheetConfig(detents: [.medium, .large], showDragIndicator: true)))
                }
                Button("Sheet 固定高度 300pt") {
                    router.present(to: .profile(name: "Sheet-300"), via: .sheet(SheetConfig(detent: .height(300), showDragIndicator: true)))
                }
                Button("Sheet 40%") {
                    router.present(to: .settings, via: .sheet(SheetConfig(detent: .fraction(0.4), showDragIndicator: true)))
                }
            }

            Section("FullScreenCover") {
                Button("FullScreenCover 设置页") {
                    router.present(to: .settings, via: .fullScreenCover)
                }
                Button("FullScreenCover 个人页") {
                    router.present(to: .profile(name: "Cover-Jeremy"), via: .fullScreenCover)
                }
            }

            Section("WindowSheet") {
                Button("WindowSheet 全屏") {
                    router.present(to: .profile(name: "WS-FullScreen"), via: .windowSheet(WindowSheetConfig(detent: .fullScreen)))
                }
                Button("WindowSheet Large") {
                    router.present(to: .profile(name: "WS-Large"), via: .windowSheet())
                }
                Button("WindowSheet 半屏") {
                    router.present(to: .profile(name: "WS-Half"), via: .windowSheet(WindowSheetConfig(detent: .half)))
                }
                Button("WindowSheet 70%") {
                    router.present(to: .settings, via: .windowSheet(WindowSheetConfig(detent: .percentage(0.7))))
                }
                Button("WindowSheet 固定高度 400pt") {
                    router.present(to: .settings, via: .windowSheet(WindowSheetConfig(detent: .fixedHeight(400))))
                }
                Button("WindowSheet 自适应高度") {
                    router.present(to: .fitContentDemo, via: .windowSheet(WindowSheetConfig(detent: .fitContent)))
                }
            }

            Section("WindowSheet 多档位") {
                Button("半屏 ↔ Large") {
                    router.present(
                        to: .profile(name: "WS-多档位"),
                        via: .windowSheet(WindowSheetConfig(detents: [.half, .large]))
                    )
                }
                Button("30% ↔ 半屏 ↔ Large") {
                    router.present(
                        to: .profile(name: "WS-三档"),
                        via: .windowSheet(WindowSheetConfig(detents: [.percentage(0.3), .half, .large]))
                    )
                }
                Button("半屏 ↔ Large（起始 Large）") {
                    router.present(
                        to: .profile(name: "WS-起始Large"),
                        via: .windowSheet(WindowSheetConfig(detents: [.half, .large], initialDetentIndex: 1))
                    )
                }
                Button("200pt ↔ 半屏 ↔ 全屏") {
                    router.present(
                        to: .settings,
                        via: .windowSheet(WindowSheetConfig(detents: [.fixedHeight(200), .half, .fullScreen]))
                    )
                }
            }

            Section("Alert") {
                Button("简单 Alert") {
                    router.present(to: .detail(title: ""), via: .alert(AlertConfig {
                        Alert(title: Text("提示"), message: Text("这是一个简单 Alert"), dismissButton: .default(Text("确定")))
                    }))
                }
                Button("双按钮 Alert") {
                    router.present(
                        to: .detail(title: ""),
                        via: .alert(AlertConfig {
                            Alert(
                                title: Text("欢迎"),
                                message: Text("这是路由器 Alert 演示"),
                                primaryButton: .default(Text("好的")),
                                secondaryButton: .cancel(Text("取消"))
                            )
                        })
                    )
                }
            }

            Section("WindowPush") {
                Button("WindowPush 详情页") {
                    router.present(to: .detail(title: "WP-详情"), via: .windowPush)
                }
                Button("WindowPush 设置页") {
                    router.present(to: .settings, via: .windowPush)
                }
                Button("WindowPush 个人页") {
                    router.present(to: .profile(name: "WP-Jeremy"), via: .windowPush)
                }
            }

            Section("WindowAlert") {
                Button("简单 WindowAlert") {
                    router.present(
                        to: .customAlertDemo(title: "提示", message: "这是一个 Window 级别的 Alert"),
                        via: .windowAlert
                    )
                }
                Button("WindowAlert 嵌套") {
                    router.present(
                        to: .customAlertDemo(title: "首页-嵌套", message: "首页弹出嵌套 WindowAlert"),
                        via: .windowAlert
                    )
                }
            }

            Section("WindowToast") {
                Button("顶部 Toast（成功）") {
                    router.present(
                        to: .toastDemo(icon: "checkmark.circle.fill", message: "操作成功", isSuccess: true),
                        via: .windowToast()
                    )
                }
                Button("顶部 Toast（失败）") {
                    router.present(
                        to: .toastDemo(icon: "xmark.circle.fill", message: "操作失败，请重试", isSuccess: false),
                        via: .windowToast()
                    )
                }
                Button("底部 Toast") {
                    router.present(
                        to: .toastDemo(icon: "info.circle.fill", message: "已复制到剪贴板", isSuccess: true),
                        via: .windowToast(WindowToastConfig(position: .bottom))
                    )
                }
                Button("长时间 Toast（5秒）") {
                    router.present(
                        to: .toastDemo(icon: "arrow.down.circle.fill", message: "正在下载...", isSuccess: true),
                        via: .windowToast(WindowToastConfig(duration: 5.0))
                    )
                }
                Button("带遮罩 Toast") {
                    router.present(
                        to: .toastDemo(icon: "exclamationmark.triangle.fill", message: "网络连接已断开", isSuccess: false),
                        via: .windowToast(WindowToastConfig(showDimming: true))
                    )
                }
            }

            Section("WindowFade") {
                Button("WindowFade 详情页") {
                    router.present(to: .detail(title: "Fade-详情"), via: .windowFade)
                }
                Button("WindowFade 设置页") {
                    router.present(to: .settings, via: .windowFade)
                }
                Button("WindowFade 个人页") {
                    router.present(to: .profile(name: "Fade-Jeremy"), via: .windowFade)
                }
            }

            Section("注册路由") {
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
                    router.present(path: "demo/registered", params: ["title": "Path-Push"])
                }
                Button("路径导航 - WindowAlert") {
                    router.present(route: RegisteredAlertRoute(title: "注册路由 Alert", message: "这是通过注册路由显示的 Alert"), via: .windowAlert)
                }
            }
        }
        .navigationTitle("首页")
    }
}

#Preview {
    ContentView()
}
