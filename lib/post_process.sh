#!/data/data/com.termux/files/usr/bin/bash
# Yroe - 容器后处理独立模块
# 依赖: core.sh, container.sh 已被调用方 source

# 使用全局变量 MODULE_PATH（由 main.sh 设置）来定位自身，但本模块不依赖自身路径，只依赖已加载的函数

# 全局变量
PP_ALIAS=""
PP_PKG_MANAGER=""
PP_DISTRO_NAME=""
DESKTOP_INSTALLED=""

# 检测容器环境
pp_detect_env() {
    PP_PKG_MANAGER=$(get_package_manager "$PP_ALIAS")
    PP_DISTRO_NAME=$(get_distro_name "$PP_ALIAS")
    echo -e "${GREEN}容器: $PP_ALIAS${NC}"
    echo -e "${GREEN}包管理器: $PP_PKG_MANAGER${NC}"
    echo -e "${GREEN}发行版: $PP_DISTRO_NAME${NC}"
}

# 阶段1：配置镜像源
pp_configure_mirror() {
    configure_mirror "$PP_ALIAS" "$PP_PKG_MANAGER" "$PP_DISTRO_NAME"
}

# 阶段2：创建普通用户
pp_create_user() {
    create_normal_user "$PP_ALIAS" "$PP_PKG_MANAGER"
}

# 阶段3：安装桌面环境
pp_install_desktop() {
    echo ""
    echo "请选择要安装的桌面/窗口环境："
    echo "  1) Openbox (极致轻量, 5-10分钟)"
    echo "  2) XFCE (轻量, 20-30分钟)"
    echo "  3) LXQt (中等, 1小时+)"
    echo "  4) KDE Plasma (重量, 数小时)"
    echo "  0) 取消"
    read -p "请选择 [0-4]: " desktop_choice
    
    case $desktop_choice in
        1) install_desktop_generic "$PP_ALIAS" "$PP_PKG_MANAGER" "openbox" "openbox obconf tint2 xterm pcmanfm feh"
           DESKTOP_INSTALLED="openbox" ;;
        2) install_desktop_generic "$PP_ALIAS" "$PP_PKG_MANAGER" "xfce" "xfce4 xfce4-terminal thunar gnome-icon-theme"
           DESKTOP_INSTALLED="xfce" ;;
        3) install_desktop_generic "$PP_ALIAS" "$PP_PKG_MANAGER" "lxqt" "lxqt"
           DESKTOP_INSTALLED="lxqt" ;;
        4) install_desktop_generic "$PP_ALIAS" "$PP_PKG_MANAGER" "plasma" "kde-plasma-desktop"
           DESKTOP_INSTALLED="plasma" ;;
        *) echo "跳过桌面安装" ;;
    esac
}

# 阶段4：配置VNC
pp_configure_vnc() {
    local desktop_type="$DESKTOP_INSTALLED"
    if [ -z "$desktop_type" ]; then
        echo -e "${YELLOW}未检测到已安装的桌面，请先安装桌面或手动指定${NC}"
        read -p "请输入桌面类型 (xfce/openbox/lxqt/plasma): " desktop_type
        [ -z "$desktop_type" ] && desktop_type="xfce"
    fi
    configure_vnc "$PP_ALIAS" "$PP_PKG_MANAGER" "$desktop_type"
}

# 交互式菜单
post_process_menu() {
    PP_ALIAS="$1"
    if [ -z "$PP_ALIAS" ]; then
        echo -e "${RED}用法: post_process_menu <容器别名>${NC}"
        return 1
    fi
    
    if [ ! -d "$PROOT_DISTRO_DIR/$PP_ALIAS" ]; then
        echo -e "${RED}容器 $PP_ALIAS 不存在${NC}"
        return 1
    fi
    
    pp_detect_env
    
    while true; do
        echo ""
        echo -e "${BLUE}════════════════ 容器后处理菜单 ════════════════${NC}"
        echo "  1) 配置软件源"
        echo "  2) 创建普通用户 (yroe)"
        echo "  3) 安装桌面环境"
        echo "  4) 配置 VNC 服务器"
        echo "  5) 执行全部 (1→2→3→4)"
        echo "  0) 返回上级菜单"
        echo -e "${BLUE}════════════════════════════════════════════════${NC}"
        read -p "请选择 [0-5]: " choice
        
        case $choice in
            1) pp_configure_mirror ;;
            2) pp_create_user ;;
            3) pp_install_desktop ;;
            4) pp_configure_vnc ;;
            5)
                pp_configure_mirror
                pp_create_user
                pp_install_desktop
                pp_configure_vnc
                ;;
            0) break ;;
            *) echo -e "${RED}无效选择${NC}" ;;
        esac
    done
}