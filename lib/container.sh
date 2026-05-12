#!/data/data/com.termux/files/usr/bin/bash

# ============================================
# Yroe - 容器管理函数
# ============================================

if [ -z "$MODULE_PATH" ]; then
    source "$HOME/.yroe/lib/core.sh"
else
    source "$MODULE_PATH/core.sh"
fi

PROOT_DISTRO_DIR="$PREFIX/var/lib/proot-distro/installed-rootfs"
YROE_BIN_DIR="$HOME/.yroe/bin"

# ============================================
# 智能检测 ASCII 预览图路径
# ============================================

get_ascii_preview_dir() {
    if [ -d "$HOME/.yroe/picture" ]; then
        echo "$HOME/.yroe/picture"
        return
    fi
    local script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)
    if [ -n "$script_dir" ] && [ -d "$script_dir/../picture" ]; then
        echo "$script_dir/../picture"
        return
    fi
    if [ -d "./picture" ]; then
        echo "$(pwd)/picture"
        return
    fi
    echo ""
}

ASCII_PREVIEW_DIR=$(get_ascii_preview_dir)

show_ascii_preview() {
    local preview_file="$1"
    if [ -z "$ASCII_PREVIEW_DIR" ] || ! command -v jp2a &> /dev/null; then
        return 0
    fi
    local full_path="$ASCII_PREVIEW_DIR/$preview_file"
    if [ -f "$full_path" ]; then
        echo ""
        jp2a --chars=" .:-=+*#%@" --colors --width=60 "$full_path" 2>/dev/null
        echo ""
    fi
}

# ============================================
# 基础检测函数
# ============================================

get_package_manager() {
    local alias="$1"
    if proot-distro login "$alias" -- command -v apk &> /dev/null 2>&1; then
        echo "apk"
    elif proot-distro login "$alias" -- command -v apt &> /dev/null 2>&1; then
        echo "apt"
    elif proot-distro login "$alias" -- command -v pacman &> /dev/null 2>&1; then
        echo "pacman"
    else
        echo "unknown"
    fi
}

get_distro_name() {
    local alias="$1"
    local name=$(proot-distro login "$alias" -- cat /etc/os-release 2>/dev/null | grep -E '^ID=' | cut -d= -f2 | tr -d '"' | tr -d '\n\r')
    echo "$name"
}

# ============================================
# 通用包安装函数
# ============================================

install_packages() {
    local alias="$1"
    local pkg_manager="$2"
    local packages="$3"
    
    case $pkg_manager in
        "apt")
            proot-distro login "$alias" -- bash -c "apt update && apt install -y $packages"
            ;;
        "pacman")
            proot-distro login "$alias" -- bash -c "pacman -Sy --noconfirm $packages"
            ;;
        "apk")
            proot-distro login "$alias" -- sh -c "apk update && apk add $packages"
            ;;
        *)
            echo -e "${RED}未知的包管理器: $pkg_manager${NC}"
            return 1
            ;;
    esac
}

# ============================================
# 配置容器镜像源
# ============================================

configure_mirror() {
    local alias="$1"
    local pkg_manager="$2"
    local distro_name="$3"
    
    echo -e "${BLUE}════════════════════════════════════════${NC}"
    echo -e "${BLUE}配置容器软件源${NC}"
    echo -e "${BLUE}════════════════════════════════════════${NC}"
    echo ""
    echo "请选择镜像源："
    echo "  1) 清华大学"
    echo "  2) 中国科学技术大学"
    echo "  3) 阿里云"
    echo "  4) 官方源"
    echo "  0) 跳过"
    read -p "请选择 [0-4]: " mirror_choice
    
    case $mirror_choice in
        1) MIRROR_URL="mirrors.tuna.tsinghua.edu.cn" ;;
        2) MIRROR_URL="mirrors.ustc.edu.cn" ;;
        3) MIRROR_URL="mirrors.aliyun.com" ;;
        4|0|*) return 0 ;;
    esac
    
    echo -e "${BLUE}配置 $distro_name 使用 $MIRROR_URL ...${NC}"
    
    case $pkg_manager in
        "apk")
            local version=$(proot-distro login "$alias" -- cat /etc/alpine-release 2>/dev/null | cut -d. -f1-2)
            [ -z "$version" ] && version="3.21"
            proot-distro login "$alias" -- sh -c "
                echo 'http://${MIRROR_URL}/alpine/v${version}/main' > /etc/apk/repositories
                echo 'http://${MIRROR_URL}/alpine/v${version}/community' >> /etc/apk/repositories
                apk update
            "
            ;;
        "apt")
            if [ "$distro_name" = "ubuntu" ]; then
                local codename=$(proot-distro login "$alias" -- bash -c ". /etc/os-release 2>/dev/null; echo \${UBUNTU_CODENAME:-\$VERSION_CODENAME}" | tr -d '\n\r')
                [ -z "$codename" ] && codename="noble"
                proot-distro login "$alias" -- bash -c "
                    cat > /etc/apt/sources.list.d/ubuntu.sources << EOF
Types: deb
URIs: http://${MIRROR_URL}/ubuntu
Suites: ${codename}
Components: main restricted universe multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg
EOF
                    apt update
                "
            elif [ "$distro_name" = "debian" ]; then
                local version=$(proot-distro login "$alias" -- cat /etc/debian_version 2>/dev/null | cut -d. -f1)
                case $version in
                    12) codename="bookworm" ;;
                    *) codename="trixie" ;;
                esac
                proot-distro login "$alias" -- bash -c "
                    cat > /etc/apt/sources.list << EOF
deb http://${MIRROR_URL}/debian ${codename} main
deb http://${MIRROR_URL}/debian ${codename}-updates main
deb http://${MIRROR_URL}/debian-security ${codename}-security main
EOF
                    apt update
                "
            fi
            ;;
        "pacman")
            proot-distro login "$alias" -- bash -c "
                echo 'Server = https://${MIRROR_URL}/archlinux/\$repo/os/\$arch' > /etc/pacman.d/mirrorlist
                pacman -Sy
            "
            ;;
    esac
    
    echo -e "${GREEN}✓ 镜像源配置完成${NC}"
    read -p "按回车键继续..."
}

# ============================================
# 创建普通用户
# ============================================

create_normal_user() {
    local alias="$1"
    local pkg_manager="$2"
    
    echo -e "${BLUE}━━━ 创建普通用户 yroe ━━━${NC}"
    
    case $pkg_manager in
        "apt") proot-distro login "$alias" -- bash -c "apt install sudo -y 2>/dev/null" ;;
        "apk") proot-distro login "$alias" -- sh -c "apk add sudo 2>/dev/null" ;;
        "pacman") proot-distro login "$alias" -- bash -c "pacman -S sudo --noconfirm 2>/dev/null" ;;
    esac
    
    proot-distro login "$alias" -- bash -c "
        if ! id yroe &>/dev/null; then
            useradd -m -G wheel -s /bin/bash yroe 2>/dev/null || \
            useradd -m -G sudo -s /bin/bash yroe 2>/dev/null || \
            adduser -D yroe 2>/dev/null
        fi
        echo 'yroe ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers.d/yroe 2>/dev/null
    "
    
    echo -e "${GREEN}✓ 用户 yroe 创建成功${NC}"
    read -p "按回车键继续..."
}

# ============================================
# 桌面环境安装
# ============================================

install_desktop_generic() {
    local alias="$1"
    local pkg_manager="$2"
    local desktop_name="$3"
    local packages="$4"
    
    echo -e "${BLUE}正在安装 $desktop_name ...${NC}"
    show_ascii_preview "${desktop_name}.txt"
    
    install_packages "$alias" "$pkg_manager" "$packages"
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ $desktop_name 安装成功${NC}"
    else
        echo -e "${RED}✗ 安装失败${NC}"
    fi
    read -p "按回车键继续..."
}

# ============================================
# VNC 配置（核心修复：脚本生成在容器内）
# ============================================
configure_vnc() {
    local alias="$1"
    local pkg_manager="$2"
    local desktop_type="$3"

    echo -e "${BLUE}━━━ 配置 VNC 服务器 ━━━${NC}"

    read -p "显示编号 (默认 1): " vnc_display
    vnc_display=${vnc_display:-1}
    read -p "分辨率 (默认 1080x2400): " vnc_resolution
    vnc_resolution=${vnc_resolution:-1080x2400}
    read -p "DPI (默认 160): " vnc_dpi
    vnc_dpi=${vnc_dpi:-160}
    read -p "允许外部连接？(y/N): " allow
    local localhost_flag=""
    [[ $allow =~ ^[Yy] ]] && localhost_flag="-localhost no" || localhost_flag="-localhost"

    echo -e "${BLUE}正在容器内配置 VNC...${NC}"
    proot-distro login "$alias" -- bash -c "
        # 安装 VNC 服务器
        case '$pkg_manager' in
            apt) apt update && apt install -y tigervnc-standalone-server dbus-x11 ;;
            pacman) pacman -Sy --noconfirm tigervnc ;;
            apk) apk update && apk add tigervnc ;;
        esac
        
        # 清理旧服务
        vncserver -kill :$vnc_display 2>/dev/null
        mkdir -p ~/.vnc ~/.config/tigervnc
        
        # 让用户交互设置密码
        echo '请设置 VNC 密码（至少6位）：'
        vncpasswd
        
        # 创建 xstartup
        cat > ~/.vnc/xstartup << 'VNC_EOF'
#!/bin/bash
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
export DISPLAY=:\${DISPLAY_NUM}
xsetroot -solid black
VNC_EOF
        case '$desktop_type' in
            xfce)   echo 'startxfce4 &' >> ~/.vnc/xstartup ;;
            openbox) echo 'openbox-session &' >> ~/.vnc/xstartup ;;
            lxqt)   echo 'startlxqt &' >> ~/.vnc/xstartup ;;
            plasma) echo 'startplasma-x11 &' >> ~/.vnc/xstartup ;;
            *)      echo 'startxfce4 &' >> ~/.vnc/xstartup ;;
        esac
        chmod +x ~/.vnc/xstartup
        
        # 生成默认配置
        cat > ~/.config/tigervnc/vncserver-config-defaults << CONF
geometry=$vnc_resolution
dpi=$vnc_dpi
alwaysshared=1
CONF
        
        # 在容器内生成启动脚本
        cat > /usr/local/bin/vnc-start << 'START_SCRIPT'
#!/bin/bash
if [ -z \"\$1\" ]; then
    echo \"用法: vnc-start <显示编号> [分辨率] [DPI] [localhost参数]\"
    echo \"示例: vnc-start 1 1080x2400 160 '-localhost no'\"
    exit 1
fi
DISPLAY_NUM=\$1
GEOMETRY=\${2:-$vnc_resolution}
DPI_VAL=\${3:-$vnc_dpi}
LOCALHOST=\${4:-$localhost_flag}
vncserver :\${DISPLAY_NUM} -geometry \${GEOMETRY} -dpi \${DPI_VAL} \${LOCALHOST}
START_SCRIPT
        chmod +x /usr/local/bin/vnc-start
        
        cat > /usr/local/bin/vnc-stop << 'STOP_SCRIPT'
#!/bin/bash
if [ -z \"\$1\" ]; then
    echo \"用法: vnc-stop <显示编号>\"
    exit 1
fi
vncserver -kill :\$1
STOP_SCRIPT
        chmod +x /usr/local/bin/vnc-stop
        
        echo 'VNC 配置完成。'
        echo '使用方法：'
        echo '  进入容器后执行: vnc-start 1'
        echo '  停止: vnc-stop 1'
    "
    
    echo -e "${GREEN}✓ VNC 配置完成！${NC}"
    echo -e "${YELLOW}使用方法：${NC}"
    echo "  1. 进入容器: proot-distro login $alias"
    echo "  2. 启动 VNC: vnc-start $vnc_display"
    echo "  3. 停止 VNC: vnc-stop $vnc_display"
    echo "  4. 连接地址: 127.0.0.1:$((5900+vnc_display))，密码为你刚才设置的密码"
}
# ============================================
# Post-install hook
# ============================================
# 新的 post_install_hook 调用独立后处理模块
post_install_hook() {
    local alias="$1"
    local distro_display="$2"
    
    echo ""
    echo -e "${BLUE}════════════════════════════════════════${NC}"
    echo -e "${GREEN}✓ $distro_display 安装完成${NC}"
    echo -e "${BLUE}════════════════════════════════════════${NC}"
    
    # 使用 MODULE_PATH（如果未定义，尝试默认路径）
    local pp_path=""
    if [ -n "$MODULE_PATH" ] && [ -f "$MODULE_PATH/post_process.sh" ]; then
        pp_path="$MODULE_PATH/post_process.sh"
    elif [ -f "$HOME/.yroe/lib/post_process.sh" ]; then
        pp_path="$HOME/.yroe/lib/post_process.sh"
    else
        echo -e "${RED}找不到 post_process.sh 模块${NC}"
        return 1
    fi
    source "$pp_path"
    post_process_menu "$alias"
}
# ============================================
# 其他函数
# ============================================

get_installed_containers() {
    if [ -d "$PROOT_DISTRO_DIR" ]; then
        ls -1 "$PROOT_DISTRO_DIR" 2>/dev/null
    fi
}

get_curl_line_numbers() {
    local script="$1"
    local curl_line=$(grep -n 'if ! curl --disable --fail' "$script" 2>/dev/null | head -1 | cut -d: -f1)
    local output_line=$((curl_line + 1))
    echo "$curl_line $output_line"
}

yroe_install() {
    local distro="$1"
    local alias="$2"
    
    if ! command -v aria2c &> /dev/null; then
        proot-distro install "$alias"
        local result=$?
        if [ $result -eq 0 ]; then
            post_install_hook "$alias" "$distro"
        fi
        return $result
    fi
    
    rainbow_echo "少女祈祷中......"
    
    local lines=$(get_curl_line_numbers "$PREFIX/bin/proot-distro")
    local curl_line=$(echo "$lines" | awk '{print $1}')
    local output_line=$(echo "$lines" | awk '{print $2}')
    
    if [ -z "$curl_line" ] || [ -z "$output_line" ]; then
        echo -e "${YELLOW}⚠ 无法获取行号，使用普通安装${NC}"
        proot-distro install "$alias"
        local result=$?
        if [ $result -eq 0 ]; then
            post_install_hook "$alias" "$distro"
        fi
        return $result
    else
        sed \
            "${curl_line}s/curl --disable --fail --retry 5 --retry-connrefused --retry-delay 5 --location \\\\/aria2c -x 16 -s 16 -k 1M --continue=true --summary-interval=0 \\\\/; \
             ${output_line}s/--output \"\${DOWNLOAD_CACHE_DIR}\\/\${archive_name}.tmp\" \"\${TARBALL_URL\[\"\$DISTRO_ARCH\"\]}\";/--out \"\${archive_name}.tmp\" --dir \"\${DOWNLOAD_CACHE_DIR}\" \"\${TARBALL_URL[\"\$DISTRO_ARCH\"]}\";/" \
            "$PREFIX/bin/proot-distro" | bash -s install "$alias"
        
        local result=$?
        if [ $result -eq 0 ]; then
            post_install_hook "$alias" "$distro"
        fi
        return $result
    fi
}

install_container() {
    local distro="$1"
    local alias="$2"
    
    rainbow_echo "少女祈祷中......"
    proot-distro install "$alias"
    
    if [ $? -eq 0 ]; then
        post_install_hook "$alias" "$distro"
    else
        echo -e "${RED}✗ $distro 安装失败${NC}"
    fi
}

list_containers() {
    echo -e "${BLUE}已安装的容器:${NC}"
    echo "================================"
    local containers=$(get_installed_containers)
    if [ -z "$containers" ]; then
        echo -e "${YELLOW}暂无已安装的容器${NC}"
    else
        for container in $containers; do
            echo "  $container"
        done
    fi
    echo "================================"
}

remove_container() {
    local alias="$1"
    
    echo -e "${RED}警告: 即将删除 $alias 容器${NC}"
    read -p "确认删除？[y/N]: " confirm
    echo
    if [[ $confirm =~ ^[Yy]$ ]]; then
        proot-distro remove "$alias"
        echo -e "${GREEN}✓ $alias 已删除${NC}"
    else
        echo -e "${YELLOW}已取消删除${NC}"
    fi
}

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