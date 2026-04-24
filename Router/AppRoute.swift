//
//  AppRoute.swift
//  Router
//

import SwiftUI

// MARK: - AppRoute

/// 应用路由枚举：定义所有可导航页面
enum AppRoute: Routable {
    case detail(title: String)
    case settings
    case profile(name: String)

    var view: AnyView {
        switch self {
        case .detail(let title):
            AnyView(DetailView(title: title))
        case .settings:
            AnyView(SettingsView())
        case .profile(let name):
            AnyView(ProfileView(name: name))
        }
    }
}

// MARK: - DetailView

struct DetailView: View {
    let title: String
    @EnvironmentObject private var router: Router<AppRoute>

    var body: some View {
        List {
            Section("当前") {
                Text(title)
                    .font(.headline)
            }

            Section("Present") {
                Button("Push 设置页") {
                    router.present(to: .settings)
                }
                Button("Push 详情页 2") {
                    router.present(to: .detail(title: "详情页 2"))
                }
                Button("Sheet 个人页") {
                    router.present(to: .profile(name: "Sheet-Jeremy"), via: .sheet)
                }
                Button("FullScreenCover 个人页") {
                    router.present(to: .profile(name: "Cover-Jeremy"), via: .fullScreenCover)
                }
                Button("Alert 提示") {
                    router.present(to: .detail(title: ""), via: .alert(AlertConfig {
                        Alert(title: Text("提示"), message: Text("来自详情页的 Alert"), dismissButton: .default(Text("确定")))
                    }))
                }
            }

            Section("Dismiss") {
                Button("dismiss() — 返回 1 层") {
                    router.dismiss()
                }
                Button("dismiss(2) — 返回 2 层") {
                    router.dismiss(2)
                }
                Button("dismiss(3) — 返回 3 层（跨模态）") {
                    router.dismiss(3)
                }
                Button("dismiss(4) — 返回 4 层（深度穿透）") {
                    router.dismiss(4)
                }
                Button("dismiss(to: 首个详情页)") {
                    router.dismiss(to: .detail(title: "Hello Router!"))
                }
                Button("dismissAll — 返回根页面") {
                    router.dismissAll()
                }
            }
        }
        .navigationTitle("详情")
    }
}

// MARK: - SettingsView

struct SettingsView: View {
    @EnvironmentObject private var router: Router<AppRoute>

    var body: some View {
        List {
            Section("Present") {
                Button("Push 详情页") {
                    router.present(to: .detail(title: "设置→详情"))
                }
                Button("Sheet 个人页") {
                    router.present(to: .profile(name: "Sheet-Guest"), via: .sheet)
                }
                Button("FullScreenCover 个人页") {
                    router.present(to: .profile(name: "Cover-Guest"), via: .fullScreenCover)
                }
                Button("Alert") {
                    router.present(to: .settings, via: .alert(AlertConfig {
                        Alert(title: Text("设置"), message: Text("这是设置页的 Alert"), dismissButton: .default(Text("确定")))
                    }))
                }
                Button("AlertConfig（双按钮）") {
                    router.present(
                        to: .settings,
                        via: .alert(AlertConfig {
                            Alert(
                                title: Text("确认"),
                                message: Text("是否重置设置？"),
                                primaryButton: .destructive(Text("重置")),
                                secondaryButton: .cancel(Text("取消"))
                            )
                        })
                    )
                }
            }

            Section("Dismiss") {
                Button("dismiss() — 返回 1 层") {
                    router.dismiss()
                }
                Button("dismiss(2) — 返回 2 层") {
                    router.dismiss(2)
                }
                Button("dismiss(3) — 返回 3 层（跨模态）") {
                    router.dismiss(3)
                }
                Button("dismiss(4) — 返回 4 层（深度穿透）") {
                    router.dismiss(4)
                }
                Button("dismissAll — 返回根页面") {
                    router.dismissAll()
                }
            }
        }
        .navigationTitle("设置")
    }
}

// MARK: - ProfileView

struct ProfileView: View {
    let name: String
    @EnvironmentObject private var router: Router<AppRoute>

    var body: some View {
        List {
            Section {
                HStack {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 50))
                        .foregroundStyle(.blue)
                    VStack(alignment: .leading) {
                        Text(name).font(.title2.bold())
                        Text("模态页面（独立导航栈）")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Section("Present（模态内导航）") {
                Button("Push 详情页") {
                    router.present(to: .detail(title: "模态内→详情"))
                }
                Button("Push 设置页") {
                    router.present(to: .settings)
                }
                Button("再开一个 Sheet（嵌套模态）") {
                    router.present(to: .profile(name: "嵌套-Sheet"), via: .sheet)
                }
                Button("Alert") {
                    router.present(to: .profile(name: ""), via: .alert(AlertConfig {
                        Alert(title: Text("个人页"), message: Text("来自个人页的 Alert"), dismissButton: .default(Text("确定")))
                    }))
                }
            }

            Section("Dismiss") {
                Button("dismiss() — 关闭 1 层") {
                    router.dismiss()
                }
                Button("dismiss(2) — 关闭 2 层（跨模态）") {
                    router.dismiss(2)
                }
                Button("dismiss(3) — 关闭 3 层（穿透多层）") {
                    router.dismiss(3)
                }
                Button("dismiss(4) — 关闭 4 层（深度穿透）") {
                    router.dismiss(4)
                }
                Button("dismiss(to: 首个详情页)（跨模态回退）") {
                    router.dismiss(to: .detail(title: "Hello Router!"))
                }
                Button("dismissAll — 返回根页面（穿透所有模态）") {
                    router.dismissAll()
                }
            }
        }
        .navigationTitle("个人")
    }
}
