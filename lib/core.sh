#!/data/data/com.termux/files/usr/bin/bash

# ============================================
# Yroe - 核心函数
# ============================================

# 颜色定义
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[0;33m'
export BLUE='\033[0;34m'
export NC='\033[0m'

# 彩虹文字效果
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

# 检测并安装依赖
check_dependencies() {
    local need_update=0
    local missing=()
    
    if ! command -v proot-distro &> /dev/null; then
        missing+=("proot-distro")
        need_update=1
    fi
    
    if ! command -v dialog &> /dev/null; then
        missing+=("dialog")
        need_update=1
    fi
    
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
                    "proot-distro") pkg install proot-distro -y ;;
                    "dialog") pkg install dialog -y ;;
                    "aria2") pkg install aria2 -y ;;
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