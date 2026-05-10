#!/data/data/com.termux/files/usr/bin/bash

# ============================================
# Yroe - Termux 容器管理器
# 一个比 tmoe 更好的选择
# ============================================

# 加载模块
SCRIPT_DIR="."
source "$SCRIPT_DIR/lib/core.sh"
source "$SCRIPT_DIR/lib/container.sh"
source "$SCRIPT_DIR/lib/launcher.sh"

# ============================================
# TUI 菜单
# ============================================

main_menu() {
    while true; do
        CHOICE=$(dialog --clear --title "Yroe 容器管理器" \
            --menu "选择一个操作:" 22 60 12 \
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
            11 "生成快捷启动脚本" \
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
                # 直接从目录读取容器列表
                local containers=()
                if [ -d "$PROOT_DISTRO_DIR" ]; then
                    for dir in "$PROOT_DISTRO_DIR"/*/; do
                        [ -d "$dir" ] && containers+=("$(basename "$dir")")
                    done
                fi
                
                if [ ${#containers[@]} -eq 0 ]; then
                    dialog --msgbox "暂无已安装的容器" 8 30
                else
                    local menu_items=()
                    local idx=1
                    for c in "${containers[@]}"; do
                        menu_items+=("$idx" "$c")
                        ((idx++))
                    done
                    
                    local choice
                    choice=$(dialog --clear --title "选择要启动的容器" \
                        --menu "请选择:" 15 40 5 "${menu_items[@]}" \
                        2>&1 >/dev/tty)
                    clear
                    
                    if [ -n "$choice" ] && [ "$choice" -ge 1 ] 2>/dev/null; then
                        local selected="${containers[$((choice-1))]}"
                        pkill -f dialog 2>/dev/null
                        clear
                        echo -e "${BLUE}正在启动 $selected...${NC}"
                        echo -e "${YELLOW}提示: 输入 exit 退出容器${NC}"
                        echo ""
                        proot-distro login "$selected"
                        clear
                        echo -e "${GREEN}✓ 已退出 $selected${NC}"
                        exit 0
                    fi
                fi
                ;;
            7)
                list_containers
                read -p "按回车键返回菜单..."
                ;;
            8)
                local containers=()
                if [ -d "$PROOT_DISTRO_DIR" ]; then
                    for dir in "$PROOT_DISTRO_DIR"/*/; do
                        [ -d "$dir" ] && containers+=("$(basename "$dir")")
                    done
                fi
                
                if [ ${#containers[@]} -eq 0 ]; then
                    dialog --msgbox "暂无已安装的容器" 8 30
                else
                    local menu_items=()
                    local idx=1
                    for c in "${containers[@]}"; do
                        menu_items+=("$idx" "$c")
                        ((idx++))
                    done
                    
                    local choice
                    choice=$(dialog --clear --title "选择要删除的容器" \
                        --menu "请选择:" 15 40 5 "${menu_items[@]}" \
                        2>&1 >/dev/tty)
                    clear
                    
                    if [ -n "$choice" ] && [ "$choice" -ge 1 ] 2>/dev/null; then
                        local selected="${containers[$((choice-1))]}"
                        remove_container "$selected"
                        read -p "按回车键返回菜单..."
                    fi
                fi
                ;;
            9)
                local containers=()
                if [ -d "$PROOT_DISTRO_DIR" ]; then
                    for dir in "$PROOT_DISTRO_DIR"/*/; do
                        [ -d "$dir" ] && containers+=("$(basename "$dir")")
                    done
                fi
                
                if [ ${#containers[@]} -eq 0 ]; then
                    dialog --msgbox "暂无已安装的容器" 8 30
                else
                    local menu_items=()
                    local idx=1
                    for c in "${containers[@]}"; do
                        menu_items+=("$idx" "$c")
                        ((idx++))
                    done
                    
                    local choice
                    choice=$(dialog --clear --title "选择要备份的容器" \
                        --menu "请选择:" 15 40 5 "${menu_items[@]}" \
                        2>&1 >/dev/tty)
                    clear
                    
                    if [ -n "$choice" ] && [ "$choice" -ge 1 ] 2>/dev/null; then
                        local selected="${containers[$((choice-1))]}"
                        backup_container "$selected"
                        read -p "按回车键返回菜单..."
                    fi
                fi
                ;;
            10)
                termux_change_repo
                read -p "按回车键返回菜单..."
                ;;
            11)
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