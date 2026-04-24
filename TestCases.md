# Router 功能测试用例

## API 概览

| API | 说明 |
|-----|------|
| `present(to:via:)` | 导航到目标页面，支持 push/sheet/fullScreenCover/alert/alertConfig |
| `dismiss()` | 返回 1 层 |
| `dismiss(_ count:)` | 返回指定层数，跨模态自动穿透 |
| `dismissAll()` | 返回根页面，穿透所有模态 |
| `dismiss(to:)` | 返回到指定路由，跨模态自动穿透 |

---

## 一、Present 测试

### 1.1 Push

| # | 操作路径 | 预期结果 |
|---|---------|---------|
| 1 | 首页 → Push 详情页 | 详情页 Push 进入，导航栏显示返回按钮 |
| 2 | 首页 → Push 详情页 → Push 设置页 | 设置页 Push 进入，多级导航栈 |
| 3 | 首页 → Push 详情页 → Push 详情页 2 | 同类型路由可重复 Push |

### 1.2 Sheet

| # | 操作路径 | 预期结果 |
|---|---------|---------|
| 4 | 首页 → Sheet 个人页 | 个人页以 Sheet 弹出，有独立导航栈 |
| 5 | 个人页(Sheet) → Push 详情页 | Sheet 内可以 Push，导航栏正常 |
| 6 | 个人页(Sheet) → 再开一个 Sheet | 嵌套 Sheet，第二层 Sheet 弹出 |

### 1.3 FullScreenCover

| # | 操作路径 | 预期结果 |
|---|---------|---------|
| 7 | 首页 → FullScreenCover 设置页 | 设置页以全屏 Cover 弹出 |
| 8 | 首页 → FullScreenCover 个人页 | 个人页以全屏 Cover 弹出，有独立导航栈 |
| 9 | FullScreenCover 内 → Push 详情页 | Cover 内可以 Push |

### 1.4 Alert

| # | 操作路径 | 预期结果 |
|---|---------|---------|
| 10 | 首页 → 简单 Alert | 弹出 Alert，只有"确定"按钮 |
| 11 | 首页 → 双按钮 Alert | 弹出 Alert，有"好的"和"取消"两个按钮 |
| 12 | 详情页 → Alert 提示 | Push 页面内也能弹 Alert |
| 13 | 设置页 → AlertConfig（双按钮） | 使用 AlertConfig 弹出自定义 Alert（重置/取消） |
| 14 | 个人页(Sheet) → Alert | 模态内也能弹 Alert |

---

## 二、Dismiss 测试

### 2.1 dismiss() — 返回 1 层

| # | 操作路径 | dismiss 操作 | 预期结果 |
|---|---------|-------------|---------|
| 15 | 首页 → Push 详情页 | dismiss() | 返回首页 |
| 16 | 首页 → Push 详情页 → Push 设置页 | dismiss() | 返回详情页 |
| 17 | 首页 → Sheet 个人页 | dismiss() | 关闭 Sheet，回到首页 |
| 18 | 首页 → FullScreenCover 设置页 | dismiss() | 关闭 Cover，回到首页 |
| 19 | 详情页弹 Alert → dismiss() | dismiss() | 关闭 Alert，停留在详情页 |

### 2.2 dismiss(_ count:) — 返回指定层数

| # | 操作路径 | dismiss 操作 | 预期结果 |
|---|---------|-------------|---------|
| 20 | 首页 → Push 详情 → Push 设置 | dismiss(2) | 返回首页（pop 2 层） |
| 21 | 首页 → Push 详情 → Push 设置 → 弹 Alert | dismiss(2) | 关 Alert + pop 设置页，停留在详情页 |
| 22 | 首页 → Sheet 个人页 → Push 详情 | dismiss(2) | pop 详情 + 关 Sheet，回到首页 |
| 23 | 首页 → Push 详情 → Sheet 个人页 → Push 设置 | dismiss(3) | pop 设置 + 关 Sheet + pop 详情，回到首页 |

### 2.3 dismiss(_ count:) — 跨模态穿透

| # | 操作路径 | dismiss 操作 | 预期结果 |
|---|---------|-------------|---------|
| 24 | 首页 → Sheet 个人页 → 再开 Sheet → Push 详情 | dismiss(3) | pop 详情 + 关内层 Sheet + 关外层 Sheet，回到首页 |
| 25 | 首页 → Push 详情 → Sheet 个人页 → Push 设置 → Push 详情2 | dismiss(4) | pop 详情2 + pop 设置 + 关 Sheet + pop 详情，回到首页 |
| 26 | 首页 → FullScreenCover 设置页 → Push 详情 → Sheet 个人页 | dismiss(3) | 关 Sheet + pop 详情 + 关 Cover，回到首页 |

### 2.4 dismissAll() — 返回根页面

| # | 操作路径 | dismiss 操作 | 预期结果 |
|---|---------|-------------|---------|
| 27 | 首页 → Push 详情 → Push 设置 | dismissAll | 回到首页 |
| 28 | 首页 → Sheet 个人页 → Push 详情 → Push 设置 | dismissAll | 关闭所有，回到首页 |
| 29 | 首页 → Push 详情 → Sheet 个人页 → 再开 Sheet → Push 设置 | dismissAll | 穿透所有模态和导航栈，回到首页 |
| 30 | 首页 → FullScreenCover → Push → Sheet → Push | dismissAll | 无论嵌套多深，全部关闭回到首页 |

### 2.5 dismiss(to:) — 返回到指定路由

| # | 操作路径 | dismiss 操作 | 预期结果 |
|---|---------|-------------|---------|
| 31 | 首页 → Push 详情("A") → Push 设置 → Push 详情("B") | dismiss(to: .detail("A")) | pop 详情B + pop 设置，停留在详情A |
| 32 | 首页 → Push 详情("A") → Push 详情("B") → Push 详情("C") | dismiss(to: .detail("A")) | pop C + pop B，停留在 A |

### 2.6 dismiss(to:) — 跨模态穿透

| # | 操作路径 | dismiss 操作 | 预期结果 |
|---|---------|-------------|---------|
| 33 | 首页 → Push 详情("A") → Sheet 个人页 → Push 设置 | dismiss(to: .detail("A")) | pop 设置 + 关 Sheet，停留在详情A |
| 34 | 首页 → Push 详情("A") → Sheet → Push → 再开 Sheet → Push | dismiss(to: .detail("A")) | 穿透多层模态，回到详情A |

---

## 三、嵌套路由测试

### 3.1 NestedRouter 独立导航栈

| # | 操作路径 | 预期结果 |
|---|---------|---------|
| 35 | Sheet 个人页 → Push 详情 → Push 设置 | 模态内有独立的导航栈，Push 正常工作 |
| 36 | FullScreenCover 设置页 → Push 详情 | Cover 内有独立的导航栈 |
| 37 | Sheet 内 dismiss() | 模态内 pop 导航栈（如有），否则关闭模态 |

### 3.2 多层嵌套

| # | 操作路径 | 预期结果 |
|---|---------|---------|
| 38 | Sheet A → 再开 Sheet B → 再开 Sheet C | 三层模态嵌套，每层独立导航栈 |
| 39 | Sheet A → Sheet B → Sheet C，在 C 中 dismissAll | 穿透所有模态，回到首页 |
| 40 | Sheet A → Push → Sheet B → Push，在最内层 dismiss(4) | 逐层关闭：pop + Sheet B + pop + Sheet A |

---

## 四、边界测试

| # | 场景 | dismiss 操作 | 预期结果 |
|---|------|-------------|---------|
| 41 | 首页（无任何导航） | dismiss() | 无操作，不崩溃 |
| 42 | 首页 | dismiss(100) | 无操作，不崩溃 |
| 43 | 首页 | dismissAll | 无操作，不崩溃 |
| 44 | 首页 | dismiss(to: .settings) | 找不到目标，无操作，不崩溃 |
| 45 | Push 1 层 | dismiss(10) | pop 1 层后停止，不崩溃 |
| 46 | 弹 Alert 后 dismiss() | dismiss() | 只关 Alert，不影响导航栈 |
| 47 | 弹 Alert 后 dismiss(2) | dismiss(2) | 关 Alert + pop 1 层 |
