#!/data/data/com.termux/files/usr/bin/bash

# ============================================
# Yroe - Termux 容器管理器
# 一个比 tmoe 更好的选择
# ============================================

# ============================================
# 智能路径检测
# ============================================

# 获取脚本所在目录（支持软链接）
get_script_dir() {
    local source="${BASH_SOURCE[0]}"
    while [ -L "$source" ]; do
        local dir=$(cd -P "$(dirname "$source")" >/dev/null 2>&1 && pwd)
        source=$(readlink "$source")
        [[ $source != /* ]] && source="$dir/$source"
    done
    cd -P "$(dirname "$source")" >/dev/null 2>&1 && pwd
}

SCRIPT_DIR=$(get_script_dir)
SCRIPT_NAME=$(basename "${BASH_SOURCE[0]}")

# 判断模块路径
if [ "$SCRIPT_NAME" = "main.sh" ] || [ "$SCRIPT_DIR" = "$PWD" ]; then
    # 从当前目录运行 ./main.sh
    MODULE_PATH="./lib"
    echo -e "\033[0;33m⚠ 开发模式: 使用本地模块 $MODULE_PATH\033[0m"
else
    # 从 PATH 运行 yroe（已安装）
    MODULE_PATH="$HOME/.yroe/lib"
fi

# 加载模块
if [ -f "$MODULE_PATH/core.sh" ]; then
    source "$MODULE_PATH/core.sh"
else
    echo -e "\033[0;31m✗ 错误: 找不到 core.sh 模块\033[0m"
    echo "查找路径: $MODULE_PATH/core.sh"
    exit 1
fi

if [ -f "$MODULE_PATH/container.sh" ]; then
    source "$MODULE_PATH/container.sh"
else
    echo -e "\033[0;31m✗ 错误: 找不到 container.sh 模块\033[0m"
    exit 1
fi

if [ -f "$MODULE_PATH/launcher.sh" ]; then
    source "$MODULE_PATH/launcher.sh"
else
    echo -e "\033[0;31m✗ 错误: 找不到 launcher.sh 模块\033[0m"
    exit 1
fi

# ============================================
# 安装容器的函数（带 aria2 询问）
# ============================================

install_with_choice() {
    local distro="$1"
    local alias="$2"
    local display_name="$3"
    
    dialog --clear --title "安装 $display_name" \
        --yesno "是否使用 aria2c 加速下载？\n\n\
aria2c 支持多线程和断点续传，下载更快。\n\
如果选「否」，将使用普通 curl 下载。\n\n\
是否使用 aria2c？" 12 50
    
    local choice=$?
    clear
    
    case $choice in
        0)
            yroe_install "$display_name" "$alias"
            ;;
        1)
            install_container "$display_name" "$alias"
            ;;
        255)
            echo -e "${YELLOW}已取消安装${NC}"
            ;;
    esac
    
    read -p "按回车键返回菜单..."
}

# ============================================
# 清理下载缓存
# ============================================

clear_download_cache() {
    local cache_dirs=(
        "$PREFIX/var/lib/proot-distro/dlcache"
        "$HOME/.cache/aria2"
        "$HOME/.aria2"
    )
    
    local total_freed=0
    
    dialog --clear --title "清理下载缓存" \
        --yesno "清理下载缓存将删除以下内容：\n\n\
• proot-distro 下载的 rootfs 压缩包\n\
• aria2 缓存文件\n\
• 残留的临时下载文件\n\n\
这些文件删除后可以重新下载，\n\
不会影响已安装的容器。\n\n\
确认清理吗？" 15 55
    
    local choice=$?
    clear
    
    if [ $choice -ne 0 ]; then
        echo -e "${YELLOW}已取消清理${NC}"
        read -p "按回车键返回菜单..."
        return
    fi
    
    echo -e "${BLUE}正在清理下载缓存...${NC}"
    
    for dir in "${cache_dirs[@]}"; do
        if [ -d "$dir" ]; then
            local size_before=$(du -sb "$dir" 2>/dev/null | cut -f1)
            rm -rf "${dir:?}"/* 2>/dev/null
            if [ $? -eq 0 ]; then
                echo -e "${GREEN}✓ 已清理: $dir${NC}"
                total_freed=$((total_freed + size_before))
            else
                echo -e "${YELLOW}⚠ 清理失败: $dir${NC}"
            fi
        else
            echo -e "${YELLOW}⚠ 目录不存在: $dir${NC}"
        fi
    done
    
    # 清理临时文件
    local tmp_files=(
        "$PREFIX/var/lib/proot-distro/dlcache"/*.tmp
        "$HOME/.yroe/tmp"/*.tmp
    )
    
    for pattern in "${tmp_files[@]}"; do
        for tmpfile in $pattern; do
            if [ -f "$tmpfile" ]; then
                rm -f "$tmpfile"
                echo -e "${GREEN}✓ 已删除临时文件: $(basename "$tmpfile")${NC}"
            fi
        done
    done
    
    mkdir -p "$PREFIX/var/lib/proot-distro/dlcache"
    mkdir -p "$HOME/.cache/aria2"
    
    echo ""
    if [ $total_freed -gt 0 ]; then
        local freed_mb=$((total_freed / 1048576))
        echo -e "${GREEN}✓ 清理完成！释放空间: ${freed_mb} MB${NC}"
    else
        echo -e "${GREEN}✓ 清理完成（无缓存文件）${NC}"
    fi
    
    read -p "按回车键返回菜单..."
}

# ============================================
# 查看缓存大小
# ============================================

view_cache_size() {
    local cache_dirs=(
        "$PREFIX/var/lib/proot-distro/dlcache"
        "$HOME/.cache/aria2"
        "$HOME/.aria2"
    )
    
    local total_size=0
    local info=""
    
    for dir in "${cache_dirs[@]}"; do
        if [ -d "$dir" ]; then
            local size=$(du -sb "$dir" 2>/dev/null | cut -f1)
            if [ -n "$size" ] && [ "$size" -gt 0 ]; then
                total_size=$((total_size + size))
                local size_mb=$((size / 1048576))
                info="${info}\n• $(basename "$dir"): ${size_mb} MB"
            fi
        fi
    done
    
    clear
    echo -e "${BLUE}========== 下载缓存大小 ==========${NC}"
    
    if [ -z "$info" ]; then
        echo -e "${YELLOW}暂无缓存文件${NC}"
    else
        echo -e "$info"
        local total_mb=$((total_size / 1048576))
        echo ""
        echo -e "${GREEN}总计: ${total_mb} MB${NC}"
    fi
    
    echo -e "${BLUE}==================================${NC}"
    read -p "按回车键返回菜单..."
}

# ============================================
# 安装容器子菜单
# ============================================

install_container_submenu() {
    while true; do
        CHOICE=$(dialog --clear --title "安装容器" \
            --menu "选择要安装的发行版:" 15 40 5 \
            1 "👨🏻 Ubuntu (以桌面用户体验为核心的发行版)" \
            2 "👨🏻‍🦳 Debian (以稳定为中心的发行版)" \
            3 "🧒🏻 Arch Linux (滚动更新，保持软件最新，挂自修)" \
            4 "👶🏻 Alpine (极致轻量化)" \
            0 "🌚 返回上级菜单" \
            2>&1 >/dev/tty)
        
        clear
        
        case $CHOICE in
            1)
                install_with_choice "Ubuntu" "ubuntu" "Ubuntu"
                ;;
            2)
                install_with_choice "Debian" "debian" "Debian"
                ;;
            3)
                install_with_choice "Arch Linux" "archlinux" "Arch Linux"
                ;;
            4)
                install_with_choice "Alpine" "alpine" "Alpine"
                ;;
            0|*)
                break
                ;;
        esac
    done
}

# ============================================
# 启动容器子菜单
# ============================================

start_container_submenu() {
    local containers=()
    if [ -d "$PROOT_DISTRO_DIR" ]; then
        for dir in "$PROOT_DISTRO_DIR"/*/; do
            [ -d "$dir" ] && containers+=("$(basename "$dir")")
        done
    fi
    
    if [ ${#containers[@]} -eq 0 ]; then
        dialog --msgbox "暂无已安装的容器" 8 30
        return
    fi
    
    local menu_items=()
    local idx=1
    for c in "${containers[@]}"; do
        menu_items+=("$idx" "$c")
        ((idx++))
    done
    
    local choice
    choice=$(dialog --clear --title "启动容器" \
        --menu "请选择要启动的容器:" 15 40 5 "${menu_items[@]}" \
        2>&1 >/dev/tty)
    clear
    
    if [ -n "$choice" ] && [ "$choice" -ge 1 ] 2>/dev/null; then
        local selected="${containers[$((choice-1))]}"
        pkill -f dialog 2>/dev/null
        clear
        echo -e "${BLUE}正在启动 $selected...${NC}"
        echo -e "${YELLOW}提示: 输入 exit 退出容器${NC}"
        echo ""
        proot-distro login "$selected" --shared-tmp
        clear
        echo -e "${GREEN}✓ 已退出 $selected${NC}"
        exit 0
    fi
}

# ============================================
# 删除容器子菜单
# ============================================

remove_container_submenu() {
    local containers=()
    if [ -d "$PROOT_DISTRO_DIR" ]; then
        for dir in "$PROOT_DISTRO_DIR"/*/; do
            [ -d "$dir" ] && containers+=("$(basename "$dir")")
        done
    fi
    
    if [ ${#containers[@]} -eq 0 ]; then
        dialog --msgbox "暂无已安装的容器" 8 30
        return
    fi
    
    local menu_items=()
    local idx=1
    for c in "${containers[@]}"; do
        menu_items+=("$idx" "$c")
        ((idx++))
    done
    
    local choice
    choice=$(dialog --clear --title "删除容器" \
        --menu "请选择要删除的容器:" 15 40 5 "${menu_items[@]}" \
        2>&1 >/dev/tty)
    clear
    
    if [ -n "$choice" ] && [ "$choice" -ge 1 ] 2>/dev/null; then
        local selected="${containers[$((choice-1))]}"
        remove_container "$selected"
        read -p "按回车键返回菜单..."
    fi
}

# ============================================
# 备份容器子菜单
# ============================================

backup_container_submenu() {
    local containers=()
    if [ -d "$PROOT_DISTRO_DIR" ]; then
        for dir in "$PROOT_DISTRO_DIR"/*/; do
            [ -d "$dir" ] && containers+=("$(basename "$dir")")
        done
    fi
    
    if [ ${#containers[@]} -eq 0 ]; then
        dialog --msgbox "暂无已安装的容器" 8 30
        return
    fi
    
    local menu_items=()
    local idx=1
    for c in "${containers[@]}"; do
        menu_items+=("$idx" "$c")
        ((idx++))
    done
    
    local choice
    choice=$(dialog --clear --title "备份容器" \
        --menu "请选择要备份的容器:" 15 40 5 "${menu_items[@]}" \
        2>&1 >/dev/tty)
    clear
    
    if [ -n "$choice" ] && [ "$choice" -ge 1 ] 2>/dev/null; then
        local selected="${containers[$((choice-1))]}"
        backup_container "$selected"
        read -p "按回车键返回菜单..."
    fi
}

# ============================================
# 容器管理主菜单
# ============================================

container_menu() {
    while true; do
        CHOICE=$(dialog --clear --title "容器管理" \
            --menu "选择一个操作:" 18 50 7 \
            1 "安装容器" \
            2 "启动容器" \
            3 "列出容器" \
            4 "删除容器" \
            5 "备份容器" \
            6 "后处理容器" \
            0 "返回上级菜单" \
            2>&1 >/dev/tty)
        
        clear
        
        case $CHOICE in
            1)
                install_container_submenu
                ;;
            2)
                start_container_submenu
                ;;
            3)
                list_containers
                read -p "按回车键返回菜单..."
                ;;
            4)
                remove_container_submenu
                ;;
            5)
                backup_container_submenu
                ;;
            6)
                # 后处理容器
                local containers=()
                if [ -d "$PROOT_DISTRO_DIR" ]; then
                    for dir in "$PROOT_DISTRO_DIR"/*/; do
                        [ -d "$dir" ] && containers+=("$(basename "$dir")")
                    done
                fi
                if [ ${#containers[@]} -eq 0 ]; then
                    dialog --msgbox "暂无已安装的容器" 8 30
                    continue
                fi
                local menu_items=()
                local idx=1
                for c in "${containers[@]}"; do
                    menu_items+=("$idx" "$c")
                    ((idx++))
                done
                local choice=$(dialog --clear --title "选择容器" \
                    --menu "请选择要后处理的容器:" 15 40 5 "${menu_items[@]}" \
                    2>&1 >/dev/tty)
                clear
                if [ -n "$choice" ] && [ "$choice" -ge 1 ] 2>/dev/null; then
                    local selected="${containers[$((choice-1))]}"
                    # 加载后处理模块（注意：使用 MODULE_PATH）
                    source "$MODULE_PATH/post_process.sh"
                    post_process_menu "$selected"
                fi
                ;;
            0|*)
                break
                ;;
        esac
    done
}
# ============================================
# 缓存管理子菜单
# ============================================

cache_menu() {
    while true; do
        CHOICE=$(dialog --clear --title "缓存管理" \
            --menu "选择一个操作:" 15 50 3 \
            1 "查看缓存大小" \
            2 "清理下载缓存" \
            0 "返回上级菜单" \
            2>&1 >/dev/tty)
        
        clear
        
        case $CHOICE in
            1)
                view_cache_size
                ;;
            2)
                clear_download_cache
                ;;
            0|*)
                break
                ;;
        esac
    done
}

# ============================================
# 主菜单
# ============================================

main_menu() {
    while true; do
        CHOICE=$(dialog --clear --title "Yroe 工具箱" \
            --menu "选择一个操作:" 16 50 5 \
            1 "☘️ PRoot 容器管理" \
            2 "🧹 缓存管理" \
            3 "🌏 换源（仅限 Termux）" \
            4 "🚀 生成快捷启动脚本" \
            0 "🌚 退出" \
            2>&1 >/dev/tty)
        
        clear
        
        case $CHOICE in
            1)
                container_menu
                ;;
            2)
                cache_menu
                ;;
            3)
                termux_change_repo
                read -p "按回车键返回菜单..."
                ;;
            4)
                generate_all_launchers
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
rainbow_echo "Yroe Tool - Termux 工具箱"
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