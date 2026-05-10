#!/data/data/com.termux/files/usr/bin/bash

# ============================================
# Yroe - Termux 容器管理器
# 一个比 tmoe 更好的选择
# ============================================

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 容器存放路径（proot-distro 默认路径）
PROOT_DISTRO_DIR="$PREFIX/var/lib/proot-distro/installed-rootfs"
CACHE_DIR="$PREFIX/var/lib/proot-distro/dlcache"

# ============================================
# 工具函数
# ============================================

# 彩虹文字效果（不依赖 lolcat）
rainbow_echo() {
    local text="$1"
    local len=${#text}
    for ((i=0;i<len;i++)); do
        printf "\e[38;2;$((255-55*i/len));$((105+75*i/len));$((180+75*i/len))m${text:$i:1}"
    done
    printf "\e[0m\n"
}

# 检测是否为 Termux 环境
is_termux() {
    [ -n "$PREFIX" ] && [ "$PREFIX" != "/usr" ]
}

# 检测是否为 ZeroTermux
is_zerotermux() {
    is_termux && {
        [ -f "$HOME/.zero-terminux" ] || \
        [ -d "$HOME/ZtInfo" ] || \
        command -v zt >/dev/null 2>&1
    }
}

# 获取 curl 命令的行号（动态，兼容不同版本）
get_curl_line_numbers() {
    local script="$1"
    local curl_line=$(grep -n 'if ! curl --disable --fail' "$script" 2>/dev/null | head -1 | cut -d: -f1)
    local output_line=$((curl_line + 1))
    echo "$curl_line $output_line"
}

# 检查容器是否已安装
is_container_installed() {
    local alias="$1"
    [ -d "$PROOT_DISTRO_DIR/$alias" ]
}

# 获取所有已安装容器的列表
get_installed_containers() {
    if [ -d "$PROOT_DISTRO_DIR" ]; then
        ls -1 "$PROOT_DISTRO_DIR" 2>/dev/null | tr '\n' ' '
    fi
}

# 检测并安装依赖
check_dependencies() {
    local need_update=0
    local missing=()
    
    # 检查 proot-distro
    if ! command -v proot-distro &> /dev/null; then
        missing+=("proot-distro")
        need_update=1
    fi
    
    # 检查 dialog
    if ! command -v dialog &> /dev/null; then
        missing+=("dialog")
        need_update=1
    fi
    
    # 检查 aria2c（用于加速下载）
    if ! command -v aria2c &> /dev/null; then
        missing+=("aria2")
        need_update=1
    fi
    
    if [ $need_update -eq 1 ]; then
        echo -e "${YELLOW}⚠ 缺少依赖: ${missing[*]}${NC}"
        read -p "是否安装？[y/N]: " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            rainbow_echo "少女祈祷中......"
            pkg update -y
            for dep in "${missing[@]}"; do
                case $dep in
                    "proot-distro")
                        pkg install proot-distro -y
                        ;;
                    "dialog")
                        pkg install dialog -y
                        ;;
                    "aria2")
                        pkg install aria2 -y
                        ;;
                esac
            done
            echo -e "${GREEN}✓ 依赖安装完成${NC}"
        else
            echo -e "${YELLOW}⚠ 跳过依赖安装，部分功能可能不可用${NC}"
        fi
    else
        echo -e "${GREEN}✓ 所有依赖已就绪${NC}"
    fi
}

# 检查存储权限
check_storage_permission() {
    if [ ! -d ~/storage/downloads ]; then
        echo -e "${YELLOW}⚠ 未检测到存储权限，正在请求...${NC}"
        termux-setup-storage
        echo -e "${YELLOW}请在弹窗中点击「允许」${NC}"
        echo -e "${YELLOW}按回车键继续...${NC}"
        read
        if [ ! -d ~/storage/downloads ]; then
            echo -e "${RED}✗ 存储权限未授予，部分功能将受限${NC}"
            return 1
        fi
    else
        echo -e "${GREEN}✓ 存储权限已就绪${NC}"
    fi
    return 0
}

# Termux 换源函数
termux_change_repo() {
    local MIRROR_URL="${1:-https://mirrors.ustc.edu.cn/termux/apt/termux-main}"
    local REPO_FILE="$PREFIX/etc/apt/sources.list"
    
    echo "========== 当前有效源 =========="
    grep -E '^deb\s' "$REPO_FILE" 2>/dev/null || echo "（未找到有效源）"
    echo "================================="
    
    if grep -q "^deb\s.*$MIRROR_URL" "$REPO_FILE" 2>/dev/null; then
        echo -e "${GREEN}✓ 当前源已是 $MIRROR_URL${NC}"
        return 0
    fi
    
    echo ""
    echo "即将更换 Termux 源为: $MIRROR_URL"
    read -p "是否继续？[y/N]: " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "[INFO] 已取消操作"
        return 0
    fi
    
    local BACKUP_FILE="${REPO_FILE}.bak.$(date +%s)"
    cp "$REPO_FILE" "$BACKUP_FILE"
    echo "[INFO] 已备份至: $BACKUP_FILE"
    
    > "$REPO_FILE"
    echo "deb $MIRROR_URL stable main" >> "$REPO_FILE"
    
    echo "[INFO] 正在更新软件包列表..."
    if pkg update; then
        echo -e "${GREEN}✓ 源更换成功${NC}"
        return 0
    else
        echo -e "${RED}✗ pkg update 失败，正在恢复备份...${NC}"
        mv "$BACKUP_FILE" "$REPO_FILE"
        pkg update
        return 1
    fi
}

# ============================================
# 容器管理功能
# ============================================

# 增强安装（用 aria2c 加速）
yroe_install() {
    local distro="$1"
    local alias="$2"
    
    # 检查是否已安装
    if is_container_installed "$alias"; then
        echo -e "${YELLOW}⚠ 容器 $distro 已安装${NC}"
        read -p "是否重新安装？[y/N]: " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            return 0
        fi
        # 删除旧容器
        proot-distro remove "$alias" 2>/dev/null
    fi
    
    # 检查 aria2c
    if ! command -v aria2c &> /dev/null; then
        echo -e "${YELLOW}⚠ aria2 未安装，使用普通安装${NC}"
        proot-distro install "$alias"
        return $?
    fi
    
    rainbow_echo "少女祈祷中......"
    
    # 动态获取行号
    local lines=$(get_curl_line_numbers "$PREFIX/bin/proot-distro")
    local curl_line=$(echo "$lines" | awk '{print $1}')
    local output_line=$(echo "$lines" | awk '{print $2}')
    
    if [ -z "$curl_line" ] || [ -z "$output_line" ]; then
        echo -e "${YELLOW}⚠ 无法获取行号，使用普通安装${NC}"
        proot-distro install "$alias"
    else
        sed \
            "${curl_line}s/curl --disable --fail --retry 5 --retry-connrefused --retry-delay 5 --location \\\\/aria2c -x 16 -s 16 -k 1M --continue=true --summary-interval=0 \\\\/; \
             ${output_line}s/--output \"\${DOWNLOAD_CACHE_DIR}\\/\${archive_name}.tmp\" \"\${TARBALL_URL\[\"\$DISTRO_ARCH\"\]}\";/--out \"\${archive_name}.tmp\" --dir \"\${DOWNLOAD_CACHE_DIR}\" \"\${TARBALL_URL[\"\$DISTRO_ARCH\"]}\";/" \
            "$PREFIX/bin/proot-distro" | bash -s install "$alias"
    fi
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ $distro 安装成功${NC}"
    else
        echo -e "${RED}✗ $distro 安装失败${NC}"
    fi
}

# 普通安装（不用加速）
install_container() {
    local distro="$1"
    local alias="$2"
    
    if is_container_installed "$alias"; then
        echo -e "${YELLOW}⚠ 容器 $distro 已安装${NC}"
        read -p "是否重新安装？[y/N]: " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            return 0
        fi
        proot-distro remove "$alias" 2>/dev/null
    fi
    
    rainbow_echo "少女祈祷中......"
    proot-distro install "$alias"
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ $distro 安装成功${NC}"
    else
        echo -e "${RED}✗ $distro 安装失败${NC}"
    fi
}

# 启动容器
start_container() {
    local alias="$1"
    
    # 用 printf 配合 sed 去掉 ANSI 转义序列
    alias=$(printf "%s" "$alias" | sed -E 's/\x1b\[[0-9;]*[JK]//g' | tr -d "'\"" | xargs)
    
    echo "DEBUG: 清理后的 alias = [$alias]"
    echo "DEBUG: 清理后的长度 = ${#alias}"
    
    if ! is_container_installed "$alias"; then
        echo -e "${RED}✗ 容器 $alias 未安装${NC}"
        return 1
    fi
    
    pkill dialog
    reset
    stty sane
    clear
    
    echo -e "${BLUE}正在启动 $alias...${NC}"
    echo ""
    
    proot-distro login "$alias"
    exit 0
}

# 列出所有已安装的容器
list_containers() {
    echo -e "${BLUE}已安装的容器:${NC}"
    echo "================================"
    
    local installed=$(get_installed_containers)
    if [ -z "$installed" ]; then
        echo -e "${YELLOW}暂无已安装的容器${NC}"
    else
        for container in $installed; do
            echo "  $container"
        done
    fi
    
    echo "================================"
}

# 删除容器
remove_container() {
    local alias="$1"
    
    if ! is_container_installed "$alias"; then
        echo -e "${RED}✗ 容器 $alias 未安装${NC}"
        return 1
    fi
    
    echo -e "${RED}警告: 即将删除 $alias 容器${NC}"
    read -p "确认删除？[y/N]: " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        proot-distro remove "$alias"
        echo -e "${GREEN}✓ $alias 已删除${NC}"
    else
        echo -e "${YELLOW}已取消删除${NC}"
    fi
}

# 备份容器
backup_container() {
    local alias="$1"
    local container_path="$PROOT_DISTRO_DIR/$alias"
    local backup_path="$HOME/storage/downloads/yroe_backup_${alias}_$(date +%Y%m%d).tar.gz"
    
    if [ ! -d "$container_path" ]; then
        echo -e "${RED}✗ 容器 $alias 未安装${NC}"
        return 1
    fi
    
    echo -e "${BLUE}正在备份 $alias...${NC}"
    tar -czf "$backup_path" -C "$container_path" . 2>/dev/null
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ 备份完成: $backup_path${NC}"
    else
        echo -e "${RED}✗ 备份失败${NC}"
    fi
}

# ============================================
# TUI 菜单
# ============================================

# 选择已安装容器的通用函数
select_installed_container() {
    local title="$1"
    local installed=$(get_installed_containers)
    
    if [ -z "$installed" ]; then
        dialog --msgbox "暂无已安装的容器" 8 30
        echo ""
        return 1
    fi
    
    local menu_items=()
    for container in $installed; do
        menu_items+=("$container" "$container")
    done
    
    local SELECT
    SELECT=$(dialog --clear --title "$title" \
        --menu "请选择:" 15 40 5 "${menu_items[@]}" \
        2>&1 >/dev/tty)
    clear
    
    # 关键：去掉所有 ANSI 转义序列
    SELECT=$(echo "$SELECT" | sed -E 's/\x1b\[[0-9;]*[a-zA-Z]//g' | tr -d "'\"" | xargs)
    echo "$SELECT"
}

main_menu() {
    while true; do
        CHOICE=$(dialog --clear --title "Yroe 容器管理器" \
            --menu "选择一个操作:" 20 55 11 \
            1 "安装 Ubuntu (aria2加速)" \
            2 "安装 Debian (aria2加速)" \
            3 "安装 Arch Linux (aria2加速)" \
            4 "安装 Alpine (aria2加速)" \
            5 "普通安装 (无加速)" \
            6 "启动容器" \
            7 "列出容器" \
            8 "删除容器" \
            9 "备份容器" \
            10 "换源（仅限 Termux）" \
            0 "退出" \
            2>&1 >/dev/tty)
        
        clear
        
        case $CHOICE in
            1)
                yroe_install "Ubuntu" "ubuntu"
                read -p "按回车键返回菜单..."
                ;;
            2)
                yroe_install "Debian" "debian"
                read -p "按回车键返回菜单..."
                ;;
            3)
                yroe_install "Arch Linux" "archlinux"
                read -p "按回车键返回菜单..."
                ;;
            4)
                yroe_install "Alpine" "alpine"
                read -p "按回车键返回菜单..."
                ;;
            5)
                local distro_choice=$(dialog --clear --title "普通安装" \
                    --menu "选择发行版:" 15 40 4 \
                    1 "Ubuntu" \
                    2 "Debian" \
                    3 "Arch Linux" \
                    4 "Alpine" \
                    2>&1 >/dev/tty)
                clear
                case $distro_choice in
                    1) install_container "Ubuntu" "ubuntu" ;;
                    2) install_container "Debian" "debian" ;;
                    3) install_container "Arch Linux" "archlinux" ;;
                    4) install_container "Alpine" "alpine" ;;
                esac
                read -p "按回车键返回菜单..."
                ;;
            6)
                local selected=$(select_installed_container "选择要启动的容器")
                if [ -n "$selected" ]; then
                    start_container "$selected"
                fi
                ;;
            7)
                list_containers
                read -p "按回车键返回菜单..."
                ;;
            8)
                local selected=$(select_installed_container "选择要删除的容器")
                if [ -n "$selected" ]; then
                    remove_container "$selected"
                    read -p "按回车键返回菜单..."
                fi
                ;;
            9)
                local selected=$(select_installed_container "选择要备份的容器")
                if [ -n "$selected" ]; then
                    backup_container "$selected"
                    read -p "按回车键返回菜单..."
                fi
                ;;
            10)
                termux_change_repo
                read -p "按回车键返回菜单..."
                ;;
            0)
                clear
                rainbow_echo "Yroe Tool"
                echo -e "今天喝水了吗？记得喝水！"
                echo "再见！"
                exit 0
                ;;
            *)
                clear
                exit 0
                ;;
        esac
    done
}

# ============================================
# 主程序入口
# ============================================

clear

rainbow_echo "========================================"
rainbow_echo "Yroe Tool - Termux 容器管理器"
rainbow_echo "========================================"
echo -e "你今天喝水了吗？💧"
echo ""

if ! is_termux; then
    echo -e "${RED}✗ 错误: Yroe 只能在 Termux/ZeroTermux 中运行${NC}"
    exit 1
fi

echo -e "${GREEN}✓${NC} 运行在 $(is_zerotermux && echo "ZeroTermux" || echo "Termux") 环境中"

check_storage_permission
check_dependencies

echo ""
echo -e "${GREEN}✓ 环境准备就绪${NC}"
echo ""
read -p "按回车键进入主菜单..."

main_menu