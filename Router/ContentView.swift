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

            Section("Sheet") {
                Button("Sheet 个人页") {
                    router.present(to: .profile(name: "Sheet-Jeremy"), via: .sheet)
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
        }
        .navigationTitle("首页")
    }
}

#Preview {
    ContentView()
}
