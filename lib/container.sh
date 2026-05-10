#!/data/data/com.termux/files/usr/bin/bash

# ============================================
# Yroe - 容器管理函数
# ============================================

source "$HOME/.yroe/lib/core.sh"

# 容器存放路径
PROOT_DISTRO_DIR="$PREFIX/var/lib/proot-distro/installed-rootfs"

# 获取所有已安装容器
get_installed_containers() {
    if [ -d "$PROOT_DISTRO_DIR" ]; then
        ls -1 "$PROOT_DISTRO_DIR" 2>/dev/null
    fi
}

# 获取 curl 命令的行号
get_curl_line_numbers() {
    local script="$1"
    local curl_line=$(grep -n 'if ! curl --disable --fail' "$script" 2>/dev/null | head -1 | cut -d: -f1)
    local output_line=$((curl_line + 1))
    echo "$curl_line $output_line"
}

# 增强安装（用 aria2c 加速）
yroe_install() {
    local distro="$1"
    local alias="$2"
    
    if ! command -v aria2c &> /dev/null; then
        echo -e "${YELLOW}⚠ aria2 未安装，使用普通安装${NC}"
        proot-distro install "$alias"
        return $?
    fi
    
    rainbow_echo "少女祈祷中......"
    
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

# 普通安装
install_container() {
    local distro="$1"
    local alias="$2"
    
    rainbow_echo "少女祈祷中......"
    proot-distro install "$alias"
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ $distro 安装成功${NC}"
    else
        echo -e "${RED}✗ $distro 安装失败${NC}"
    fi
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