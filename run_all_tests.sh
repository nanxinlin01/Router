#!/bin/bash

# ============================================================================
# 一键运行：Xcode编译 + 启动App + 测试所有URL Scheme
# 用法: ./run_all_tests.sh
# ============================================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  一键完整测试：Xcode编译 + URL Scheme测试${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
echo ""

SIMULATOR_UDID="F45E15E0-B976-44CF-AFD3-C2399D369607"
BUNDLE_ID="com.jeremy.Router"
PROJECT_PATH="/Users/jeremy/Desktop/Router"

# 步骤1：编译项目
print_info "步骤 1/4: 编译项目..."
cd "$PROJECT_PATH"
if xcodebuild -scheme Router -destination "platform=iOS Simulator,id=$SIMULATOR_UDID" build >/dev/null 2>&1; then
    print_success "编译成功"
else
    print_error "编译失败！"
    exit 1
fi

# 步骤2：确保模拟器运行
print_info "步骤 2/4: 启动模拟器..."
xcrun simctl boot "$SIMULATOR_UDID" 2>/dev/null || true
sleep 3
print_success "模拟器已就绪"

# 步骤3：通过simctl launch启动App（模拟Xcode运行）
print_info "步骤 3/4: 启动App到前台..."
xcrun simctl terminate "$SIMULATOR_UDID" "$BUNDLE_ID" 2>/dev/null || true
sleep 1

# 启动App并等待
if xcrun simctl launch "$SIMULATOR_UDID" "$BUNDLE_ID" >/dev/null 2>&1; then
    print_info "App已启动，等待10秒让LaunchServices完全注册..."
    sleep 10
    print_success "App已就绪"
else
    print_error "App启动失败！"
    exit 1
fi

# 步骤4：运行所有测试
print_info "步骤 4/4: 开始URL Scheme测试..."
echo ""

# 测试用例
declare -a TESTS=(
    "1. 默认大尺寸|myapp://demo/registered?title=默认测试&transition=windowSheet"
    "2. 全屏|myapp://demo/registered?title=全屏测试&transition=windowSheet:fullscreen"
    "3. 半屏|myapp://demo/registered?title=半屏测试&transition=windowSheet:half"
    "4. 自适应内容|myapp://demo/registered?title=自适应测试&transition=windowSheet:fit"
    "5. 固定高度400pt|myapp://demo/registered?title=固定高度测试&transition=windowSheet:fixed,400"
    "6. 70%百分比|myapp://demo/registered?title=70%高度测试&transition=windowSheet:percent,0.7"
    "7. 多档位切换|myapp://demo/registered?title=多档位测试&transition=windowSheet:half,large,fullscreen"
    "8. 自定义外观|myapp://demo/registered?title=自定义外观&transition=windowSheet:large&cornerRadius=24&bgOpacity=0.4"
    "9. 禁用下滑关闭|myapp://demo/registered?title=不可关闭&transition=windowSheet:large&dismissOnDrag=false"
    "10. 隐藏拖拽条|myapp://demo/registered?title=隐藏拖拽条&transition=windowSheet:large&showDragIndicator=false"
)

SUCCESS_COUNT=0
FAIL_COUNT=0

for test_entry in "${TESTS[@]}"; do
    IFS='|' read -r test_name test_url <<< "$test_entry"
    
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}📱 测试: $test_name${NC}"
    echo -e "${YELLOW}🔗 URL: $test_url${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    # 先模拟返回主页（关闭可能存在的WindowSheet）
    print_info "关闭当前弹窗..."
    xcrun simctl terminate "$SIMULATOR_UDID" "$BUNDLE_ID" >/dev/null 2>&1
    sleep 1
    xcrun simctl launch "$SIMULATOR_UDID" "$BUNDLE_ID" >/dev/null 2>&1
    sleep 2
    
    # URL编码
    encoded_url=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$test_url', safe=':/?&='))")
    
    # 发送URL
    if xcrun simctl openurl "$SIMULATOR_UDID" "$encoded_url" 2>/dev/null; then
        print_success "URL已发送 ✅"
        ((SUCCESS_COUNT++))
    else
        print_error "URL发送失败 ❌"
        ((FAIL_COUNT++))
    fi
    
    echo ""
    print_info "观察模拟器效果，5秒后继续..."
    sleep 5
    echo ""
done

# 总结
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ 测试完成！${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
print_success "成功: $SUCCESS_COUNT / ${#TESTS[@]}"
if [ $FAIL_COUNT -gt 0 ]; then
    print_warning "失败: $FAIL_COUNT / ${#TESTS[@]}"
fi
echo ""
print_info "请在模拟器中确认："
echo "  ✓ 每个WindowSheet是否正常弹出"
echo "  ✓ 高度是否符合预期"
echo "  ✓ 标题是否正确显示"
echo "  ✓ 外观是否符合配置"
