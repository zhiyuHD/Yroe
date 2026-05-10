#!/data/data/com.termux/files/usr/bin/bash

# ============================================
# Yroe 一键安装脚本
# ============================================

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 路径定义
YROE_DIR="$HOME/.yroe"
REPO_URL="https://github.com/zhiyuHD/Yroe.git"

# 清屏
clear

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Yroe 一键安装脚本${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# ============================================
# 1. 检查 Termux 环境
# ============================================
if [ -z "$PREFIX" ] || [ "$PREFIX" = "/usr" ]; then
    echo -e "${RED}✗ 错误: Yroe 只能在 Termux/ZeroTermux 中运行${NC}"
    exit 1
fi

echo -e "${GREEN}✓${NC} Termux 环境检测通过"

# ============================================
# 2. 检查并安装必要工具
# ============================================

# 检查 pkg 是否可用
if ! command -v pkg &> /dev/null; then
    echo -e "${RED}✗ 错误: 未找到 pkg 命令${NC}"
    exit 1
fi

# 更新源
echo -e "${BLUE}正在更新软件源...${NC}"
pkg update -y

# 检查并安装 git
if ! command -v git &> /dev/null; then
    echo -e "${YELLOW}⚠ git 未安装，正在安装...${NC}"
    pkg install git -y
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ git 安装成功${NC}"
    else
        echo -e "${RED}✗ git 安装失败${NC}"
        exit 1
    fi
else
    echo -e "${GREEN}✓ git 已安装${NC}"
fi

# 检查并安装 proot-distro（Yroe 依赖）
if ! command -v proot-distro &> /dev/null; then
    echo -e "${YELLOW}⚠ proot-distro 未安装，正在安装...${NC}"
    pkg install proot-distro -y
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ proot-distro 安装成功${NC}"
    else
        echo -e "${RED}✗ proot-distro 安装失败${NC}"
        exit 1
    fi
else
    echo -e "${GREEN}✓ proot-distro 已安装${NC}"
fi

# 检查并安装 dialog（Yroe 依赖）
if ! command -v dialog &> /dev/null; then
    echo -e "${YELLOW}⚠ dialog 未安装，正在安装...${NC}"
    pkg install dialog -y
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ dialog 安装成功${NC}"
    else
        echo -e "${RED}✗ dialog 安装失败${NC}"
        exit 1
    fi
else
    echo -e "${GREEN}✓ dialog 已安装${NC}"
fi

# 检查并安装 aria2（可选，用于加速下载）
if ! command -v aria2c &> /dev/null; then
    echo -e "${YELLOW}⚠ aria2 未安装，正在安装...${NC}"
    pkg install aria2 -y
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ aria2 安装成功${NC}"
    else
        echo -e "${YELLOW}⚠ aria2 安装失败，将使用普通下载${NC}"
    fi
else
    echo -e "${GREEN}✓ aria2 已安装${NC}"
fi

# ============================================
# 3. Clone 仓库
# ============================================

echo ""
echo -e "${BLUE}正在克隆 Yroe 仓库...${NC}"

# 如果目录已存在，先备份删除
if [ -d "$YROE_DIR" ]; then
    echo -e "${YELLOW}⚠ 目录 $YROE_DIR 已存在，正在备份...${NC}"
    mv "$YROE_DIR" "$YROE_DIR.bak.$(date +%s)"
fi

git clone "$REPO_URL" "$YROE_DIR"

if [ $? -ne 0 ]; then
    echo -e "${RED}✗ Clone 失败${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Clone 成功${NC}"

# ============================================
# 4. 删除 .git 目录
# ============================================
if [ -d "$YROE_DIR/.git" ]; then
    rm -rf "$YROE_DIR/.git"
    echo -e "${GREEN}✓ 已删除 .git 目录${NC}"
fi

# ============================================
# 5. 重命名 main.sh 为 yroe.sh
# ============================================
if [ -f "$YROE_DIR/main.sh" ]; then
    mv "$YROE_DIR/main.sh" "$YROE_DIR/yroe.sh"
    echo -e "${GREEN}✓ 已重命名 main.sh -> yroe.sh${NC}"
else
    echo -e "${YELLOW}⚠ 未找到 main.sh，请检查仓库结构${NC}"
fi

# ============================================
# 6. 给 yroe.sh 加执行权限
# ============================================
if [ -f "$YROE_DIR/yroe.sh" ]; then
    chmod +x "$YROE_DIR/yroe.sh"
    echo -e "${GREEN}✓ 已添加执行权限${NC}"
else
    echo -e "${RED}✗ 未找到 yroe.sh${NC}"
    exit 1
fi

# ============================================
# 7. 创建软链接到 PATH
# ============================================
if [ -f "$PREFIX/bin/yroe" ]; then
    rm -f "$PREFIX/bin/yroe"
fi
ln -s "$YROE_DIR/yroe.sh" "$PREFIX/bin/yroe"
echo -e "${GREEN}✓ 已创建软链接: yroe -> $YROE_DIR/yroe.sh${NC}"

# ============================================
# 8. 添加 PATH 到 bashrc 和 zshrc
# ============================================

YROE_BIN_DIR="$HOME/.yroe/bin"

# 创建 bin 目录
mkdir -p "$YROE_BIN_DIR"

# 添加到 ~/.bashrc
if [ -f "$HOME/.bashrc" ]; then
    if ! grep -q "YROE_BIN" "$HOME/.bashrc" 2>/dev/null; then
        echo "" >> "$HOME/.bashrc"
        echo "# Yroe 快捷启动脚本目录" >> "$HOME/.bashrc"
        echo "export PATH=\"\$HOME/.yroe/bin:\$PATH\"" >> "$HOME/.bashrc"
        echo -e "${GREEN}✓ 已添加 PATH 到 ~/.bashrc${NC}"
    else
        echo -e "${GREEN}✓ PATH 已存在于 ~/.bashrc${NC}"
    fi
else
    echo "" > "$HOME/.bashrc"
    echo "# Yroe 快捷启动脚本目录" >> "$HOME/.bashrc"
    echo "export PATH=\"\$HOME/.yroe/bin:\$PATH\"" >> "$HOME/.bashrc"
    echo -e "${GREEN}✓ 已创建 ~/.bashrc 并添加 PATH${NC}"
fi

# 添加到 ~/.zshrc
if [ -f "$HOME/.zshrc" ]; then
    if ! grep -q "YROE_BIN" "$HOME/.zshrc" 2>/dev/null; then
        echo "" >> "$HOME/.zshrc"
        echo "# Yroe 快捷启动脚本目录" >> "$HOME/.zshrc"
        echo "export PATH=\"\$HOME/.yroe/bin:\$PATH\"" >> "$HOME/.zshrc"
        echo -e "${GREEN}✓ 已添加 PATH 到 ~/.zshrc${NC}"
    else
        echo -e "${GREEN}✓ PATH 已存在于 ~/.zshrc${NC}"
    fi
else
    # 如果 .zshrc 不存在，也创建（有些用户可能用 zsh）
    echo "" > "$HOME/.zshrc"
    echo "# Yroe 快捷启动脚本目录" >> "$HOME/.zshrc"
    echo "export PATH=\"\$HOME/.yroe/bin:\$PATH\"" >> "$HOME/.zshrc"
    echo -e "${GREEN}✓ 已创建 ~/.zshrc 并添加 PATH${NC}"
fi

# ============================================
# 9. 生成快捷启动脚本（如果有已安装的容器）
# ============================================
if command -v proot-distro &> /dev/null; then
    if [ -d "$PREFIX/var/lib/proot-distro/installed-rootfs" ]; then
        CONTAINER_COUNT=$(ls -1 "$PREFIX/var/lib/proot-distro/installed-rootfs" 2>/dev/null | wc -l)
        if [ "$CONTAINER_COUNT" -gt 0 ]; then
            echo ""
            echo -e "${BLUE}检测到已安装的容器，正在生成快捷启动脚本...${NC}"
            
            # 临时 source Yroe 的函数（如果 yroe.sh 存在）
            if [ -f "$YROE_DIR/yroe.sh" ]; then
                # 提取 generate_all_launchers 函数并执行
                # 更简单的方法：直接执行 yroe --generate-launchers（如果支持）
                # 这里暂时只提示用户手动操作
                echo -e "${YELLOW}请稍后运行 'yroe' 并选择「生成快捷启动脚本」${NC}"
            fi
        fi
    fi
fi

# ============================================
# 10. 安装完成
# ============================================

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Yroe 安装完成！${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "请执行以下命令重新加载配置："
echo -e "  ${YELLOW}source ~/.bashrc${NC}  (如果使用 bash)"
echo -e "  ${YELLOW}source ~/.zshrc${NC}   (如果使用 zsh)"
echo ""
echo -e "或者直接打开新的 Termux 窗口"
echo ""
echo -e "然后输入 ${GREEN}yroe${NC} 启动 Yroe 容器管理器"
echo ""
echo -e "${BLUE}今天喝水了吗？记得喝水！💧${NC}"