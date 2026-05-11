#!/data/data/com.termux/files/usr/bin/bash

# ============================================
# Yroe - 容器管理函数
# ============================================

source "$HOME/.yroe/lib/core.sh"

# 容器存放路径
PROOT_DISTRO_DIR="$PREFIX/var/lib/proot-distro/installed-rootfs"

# ASCII 预览图存放路径
ASCII_PREVIEW_DIR="$HOME/.yroe/picture"

# ============================================
# 显示 ASCII 预览图
# ============================================

show_ascii_preview() {
    local preview_file="$1"
    
    if [ -f "$preview_file" ] && command -v jp2a &> /dev/null; then
        echo ""
        jp2a --chars=" .:-=+*#%@" --colors --width=60 "$preview_file" 2>/dev/null
        echo ""
    fi
}

# ============================================
# 根据发行版获取包管理器
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

# ============================================
# 获取发行版名称
# ============================================

get_distro_name() {
    local alias="$1"
    
    local name=$(proot-distro login "$alias" -- cat /etc/os-release 2>/dev/null | grep -E '^ID=' | cut -d= -f2 | tr -d '"' | tr -d '\n\r')
    echo "$name"
}

# ============================================
# 配置容器镜像源（完整修复版）
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
    echo "  1) 清华大学 (mirrors.tuna.tsinghua.edu.cn)"
    echo "  2) 中国科学技术大学 (mirrors.ustc.edu.cn)"
    echo "  3) 阿里云 (mirrors.aliyun.com)"
    echo "  4) 官方源 (不更换)"
    echo "  0) 跳过"
    echo ""
    read -p "请选择 [0-4]: " mirror_choice
    
    case $mirror_choice in
        1) MIRROR_URL="mirrors.tuna.tsinghua.edu.cn" ;;
        2) MIRROR_URL="mirrors.ustc.edu.cn" ;;
        3) MIRROR_URL="mirrors.aliyun.com" ;;
        4) MIRROR_URL="official" ;;
        0|*) 
            echo -e "${YELLOW}跳过镜像源配置${NC}"
            return 0
            ;;
    esac
    
    if [ "$MIRROR_URL" != "official" ]; then
        echo -e "${BLUE}正在配置 $distro_name 使用 $MIRROR_URL ...${NC}"
        
        case $pkg_manager in
            "apk")
                local version=$(proot-distro login "$alias" -- cat /etc/alpine-release 2>/dev/null | cut -d. -f1-2)
                [ -z "$version" ] && version="3.21"
                echo -e "${GREEN}✓ Alpine 版本: $version${NC}"
                
                proot-distro login "$alias" -- sh -c "
                    echo 'http://${MIRROR_URL}/alpine/v${version}/main' > /etc/apk/repositories
                    echo 'http://${MIRROR_URL}/alpine/v${version}/community' >> /etc/apk/repositories
                    apk update
                "
                ;;
            "apt")
                case $distro_name in
                    "ubuntu")
                        local codename=$(proot-distro login "$alias" -- bash -c "
                            . /etc/os-release 2>/dev/null
                            echo \${UBUNTU_CODENAME:-\$VERSION_CODENAME}
                        " 2>/dev/null | tr -d '\n\r' | xargs)
                        [ -z "$codename" ] && codename="noble"
                        echo -e "${GREEN}✓ Ubuntu 代号: $codename${NC}"
                        
                        proot-distro login "$alias" -- bash -c "
                            rm -f /etc/apt/sources.list.d/*.sources 2>/dev/null
                            cat > /etc/apt/sources.list.d/ubuntu.sources << EOF
Types: deb
URIs: http://${MIRROR_URL}/ubuntu
Suites: ${codename}
Components: main restricted universe multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg

Types: deb
URIs: http://${MIRROR_URL}/ubuntu
Suites: ${codename}-updates
Components: main restricted universe multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg

Types: deb
URIs: http://${MIRROR_URL}/ubuntu
Suites: ${codename}-backports
Components: main restricted universe multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg

Types: deb
URIs: http://${MIRROR_URL}/ubuntu
Suites: ${codename}-security
Components: main restricted universe multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg
EOF
                            apt update
                        "
                        ;;
                    "debian")
                        local version=$(proot-distro login "$alias" -- cat /etc/debian_version 2>/dev/null | cut -d. -f1)
                        case $version in
                            12) codename="bookworm" ;;
                            13) codename="trixie" ;;
                            *) codename="trixie" ;;
                        esac
                        echo -e "${GREEN}✓ Debian 代号: $codename${NC}"
                        
                        proot-distro login "$alias" -- bash -c "
                            cat > /etc/apt/sources.list << EOF
deb http://${MIRROR_URL}/debian ${codename} main
deb http://${MIRROR_URL}/debian ${codename}-updates main
deb http://${MIRROR_URL}/debian-security ${codename}-security main
EOF
                            apt update
                        "
                        ;;
                    *)
                        echo -e "${YELLOW}⚠ 未知的 Debian 系发行版，跳过${NC}"
                        ;;
                esac
                ;;
            "pacman")
                proot-distro login "$alias" -- bash -c "
                    echo 'Server = https://${MIRROR_URL}/archlinux/\$repo/os/\$arch' > /etc/pacman.d/mirrorlist
                    pacman -Sy
                "
                ;;
            *)
                echo -e "${YELLOW}⚠ 未知的包管理器: $pkg_manager，跳过镜像配置${NC}"
                ;;
        esac
        
        echo -e "${GREEN}✓ 镜像源配置完成${NC}"
    fi
    
    read -p "按回车键继续..."
}

# ============================================
# 创建普通用户 yroe（带 sudo 权限）
# ============================================

create_normal_user() {
    local alias="$1"
    local pkg_manager="$2"
    
    echo -e "${BLUE}━━━ 创建普通用户 yroe ━━━${NC}"
    echo -e "${YELLOW}桌面环境不能以 root 用户运行，正在创建用户 yroe...${NC}"
    
    # 安装 sudo（如果还没装）
    case $pkg_manager in
        "apt")
            proot-distro login "$alias" -- bash -c "apt install sudo -y 2>/dev/null"
            ;;
        "apk")
            proot-distro login "$alias" -- sh -c "apk add sudo 2>/dev/null"
            ;;
        "pacman")
            proot-distro login "$alias" -- bash -c "pacman -S sudo --noconfirm 2>/dev/null"
            ;;
    esac
    
    # 创建用户 yroe（无密码）
    proot-distro login "$alias" -- bash -c "
        # 检查用户是否已存在
        if ! id yroe &>/dev/null; then
            useradd -m -G wheel -s /bin/bash yroe 2>/dev/null || \
            useradd -m -G sudo -s /bin/bash yroe 2>/dev/null || \
            adduser -D yroe 2>/dev/null
        fi
        
        # 设置无密码 sudo 权限
        echo 'yroe ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers 2>/dev/null
        echo 'yroe ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers.d/yroe 2>/dev/null
        
        # 设置默认 shell（Alpine 用 /bin/sh）
        if [ -f /etc/alpine-release ]; then
            chsh -s /bin/sh yroe 2>/dev/null
        fi
    "
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ 用户 yroe 创建成功（无密码，可 sudo）${NC}"
    else
        echo -e "${YELLOW}⚠ 用户创建可能失败，请手动检查${NC}"
    fi
    
    read -p "按回车键继续..."
}

# ============================================
# 安装桌面环境
# ============================================

install_desktop() {
    local alias="$1"
    local desktop="$2"
    local pkg_manager="$3"
    
    case $desktop in
        "plasma")
            echo -e "${BLUE}正在准备安装 KDE Plasma...${NC}"
            show_ascii_preview "$ASCII_PREVIEW_DIR/plasma.txt"
            echo -e "${YELLOW}正在安装，这可能需要较长时间...${NC}"
            
            case $pkg_manager in
                "apt")
                    proot-distro login "$alias" -- bash -c "
                        apt update
                        apt install kde-plasma-desktop -y
                    "
                    ;;
                "pacman")
                    proot-distro login "$alias" -- bash -c "
                        pacman -Sy
                        pacman -S plasma-meta --noconfirm
                    "
                    ;;
                "apk")
                    proot-distro login "$alias" -- sh -c "
                        apk update
                        apk add plasma-desktop-meta
                    "
                    ;;
                *)
                    echo -e "${RED}未知的包管理器，请手动安装${NC}"
                    return 1
                    ;;
            esac
            ;;
        "lxqt")
            echo -e "${BLUE}正在准备安装 LXQt...${NC}"
            show_ascii_preview "$ASCII_PREVIEW_DIR/lxqt.txt"
            echo -e "${YELLOW}正在安装，这可能需要较长时间...${NC}"
            
            case $pkg_manager in
                "apt")
                    proot-distro login "$alias" -- bash -c "
                        apt update
                        apt install lxqt -y
                    "
                    ;;
                "pacman")
                    proot-distro login "$alias" -- bash -c "
                        pacman -Sy
                        pacman -S lxqt --noconfirm
                    "
                    ;;
                "apk")
                    proot-distro login "$alias" -- sh -c "
                        apk update
                        apk add lxqt-desktop lxqt-config lxqt-panel lxqt-session \
                                lxqt-runner pcmanfm-qt openbox
                    "
                    ;;
                *)
                    echo -e "${RED}未知的包管理器，请手动安装${NC}"
                    return 1
                    ;;
            esac
            ;;
        *)
            echo -e "${RED}未知的桌面环境: $desktop${NC}"
            return 1
            ;;
    esac
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ $desktop 安装成功${NC}"
    else
        echo -e "${RED}✗ $desktop 安装失败${NC}"
    fi
    
    echo ""
    read -p "按回车键继续..."
}

# ============================================
# 配置 Termux:X11
# ============================================

setup_termux_x11() {
    echo -e "${BLUE}════════════════════════════════════════${NC}"
    echo -e "${BLUE}配置 Termux:X11 支持${NC}"
    echo -e "${BLUE}════════════════════════════════════════${NC}"
    echo ""
    
    echo -e "${YELLOW}检查 Termux 本体 X11 依赖...${NC}"
    
    local missing_x11=()
    
    if ! command -v termux-x11 &> /dev/null; then
        missing_x11+=("termux-x11")
    fi
    
    if ! command -v dbus-launch &> /dev/null; then
        missing_x11+=("dbus")
    fi
    
    if [ ${#missing_x11[@]} -gt 0 ]; then
        echo -e "${YELLOW}⚠ 缺少 X11 依赖: ${missing_x11[*]}${NC}"
        read -p "是否安装？[y/N]: " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            pkg install x11-repo -y
            for dep in "${missing_x11[@]}"; do
                case $dep in
                    "termux-x11") pkg install termux-x11-nightly -y ;;
                    "dbus") pkg install dbus -y ;;
                esac
            done
            echo -e "${GREEN}✓ X11 依赖安装完成${NC}"
        else
            echo -e "${YELLOW}⚠ 跳过 X11 依赖安装，后续可能无法显示图形界面${NC}"
        fi
    else
        echo -e "${GREEN}✓ X11 依赖已就绪${NC}"
    fi
    
    echo ""
    echo -e "${BLUE}Termux:X11 使用步骤：${NC}"
    echo -e "  1. 安装桌面环境后，切换用户: ${YELLOW}su - yroe${NC}"
    echo -e "  2. 在容器内执行: ${YELLOW}export DISPLAY=:1${NC}"
    echo -e "  3. 启动桌面: ${YELLOW}startplasma-x11${NC} 或 ${YELLOW}startlxqt${NC}"
    echo -e "  4. 在 Termux 本体（容器外）执行: ${YELLOW}termux-x11 :1 &${NC}"
    echo -e "  5. 打开 Termux:X11 App 即可看到图形界面"
    echo ""
    read -p "按回车键继续..."
}

# ============================================
# Post-install hook
# ============================================

post_install_hook() {
    local alias="$1"
    local distro_display="$2"
    
    echo ""
    echo -e "${BLUE}════════════════════════════════════════${NC}"
    echo -e "${GREEN}✓ $distro_display 安装完成！${NC}"
    echo -e "${BLUE}════════════════════════════════════════${NC}"
    echo ""
    
    echo -e "${YELLOW}检测容器环境...${NC}"
    local pkg_manager=$(get_package_manager "$alias")
    local distro_name=$(get_distro_name "$alias")
    echo -e "${GREEN}✓ 包管理器: $pkg_manager${NC}"
    echo -e "${GREEN}✓ 发行版: $distro_name${NC}"
    echo ""
    
    # 阶段1：配置镜像源
    echo -e "${BLUE}━━━ 阶段1/4: 配置软件源 ━━━${NC}"
    configure_mirror "$alias" "$pkg_manager" "$distro_name"
    
    # 阶段2：创建普通用户
    create_normal_user "$alias" "$pkg_manager"
    
    # 阶段3：安装桌面环境
    echo -e "${BLUE}━━━ 阶段3/4: 桌面环境 ━━━${NC}"
    echo ""
    echo -n "是否安装桌面环境？[y/N]: "
    read -n 1 -r install_desktop_choice
    echo ""
    
    if [[ $install_desktop_choice =~ ^[Yy]$ ]]; then
        echo ""
        echo "请选择桌面环境："
        echo "  1) KDE Plasma (功能丰富)"
        echo "  2) LXQt (轻量级)"
        echo ""
        read -p "请选择 [1-2]: " desktop_choice
        
        case $desktop_choice in
            1) install_desktop "$alias" "plasma" "$pkg_manager" ;;
            2) install_desktop "$alias" "lxqt" "$pkg_manager" ;;
            *) echo -e "${YELLOW}无效选择，跳过桌面环境安装${NC}" ;;
        esac
    else
        echo -e "${YELLOW}跳过桌面环境安装${NC}"
    fi
    
    # 阶段4：配置 Termux:X11
    echo -e "${BLUE}━━━ 阶段4/4: Termux:X11 配置 ━━━${NC}"
    setup_termux_x11
    
    echo -e "${BLUE}════════════════════════════════════════${NC}"
    echo -e "${GREEN}✓ 收尾配置完成！${NC}"
    echo -e "${BLUE}════════════════════════════════════════${NC}"
    echo ""
    read -p "按回车键返回菜单..."
}

# ============================================
# 获取所有已安装容器
# ============================================

get_installed_containers() {
    if [ -d "$PROOT_DISTRO_DIR" ]; then
        ls -1 "$PROOT_DISTRO_DIR" 2>/dev/null
    fi
}

# ============================================
# 获取 curl 命令的行号
# ============================================

get_curl_line_numbers() {
    local script="$1"
    local curl_line=$(grep -n 'if ! curl --disable --fail' "$script" 2>/dev/null | head -1 | cut -d: -f1)
    local output_line=$((curl_line + 1))
    echo "$curl_line $output_line"
}

# ============================================
# 增强安装（用 aria2c 加速）
# ============================================

yroe_install() {
    local distro="$1"
    local alias="$2"
    
    if ! command -v aria2c &> /dev/null; then
        echo -e "${YELLOW}⚠ aria2 未安装，使用普通安装${NC}"
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

# ============================================
# 普通安装
# ============================================

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

# ============================================
# 列出所有已安装的容器
# ============================================

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

# ============================================
# 删除容器
# ============================================

remove_container() {
    local alias="$1"
    
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

# ============================================
# 备份容器
# ============================================

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