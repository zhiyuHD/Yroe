#!/data/data/com.termux/files/usr/bin/bash

# ============================================
# Yroe - 快捷启动脚本生成
# ============================================

source "$HOME/.yroe/lib/core.sh"
source "$HOME/.yroe/lib/container.sh"

YROE_BIN_DIR="$HOME/.yroe/bin"
SHELL_RC="$HOME/.bashrc"

if [ -n "$ZSH_VERSION" ]; then
    SHELL_RC="$HOME/.zshrc"
fi

# 检查 PATH 是否已添加
is_path_configured() {
    grep -q "YROE_BIN" "$SHELL_RC" 2>/dev/null
}

# 添加 PATH 到 shell 配置文件
add_path_to_rc() {
    if is_path_configured; then
        echo -e "${GREEN}✓ PATH 已配置${NC}"
        return 0
    fi
    
    echo "" >> "$SHELL_RC"
    echo "# Yroe 快捷启动脚本目录" >> "$SHELL_RC"
    echo "export PATH=\"\$HOME/.yroe/bin:\$PATH\"" >> "$SHELL_RC"
    
    echo -e "${GREEN}✓ 已添加 PATH 到 $SHELL_RC${NC}"
}

# 生成单个容器的启动脚本
generate_launcher() {
    local alias="$1"
    local script_path="$YROE_BIN_DIR/$alias"
    
    mkdir -p "$YROE_BIN_DIR"
    
    cat > "$script_path" << EOF
#!/data/data/com.termux/files/usr/bin/bash
# Yroe 生成的快捷启动脚本
# 用法: $alias

ALIAS="$alias"

clear
echo -e "\033[0;34m正在启动 \$ALIAS...\033[0m"
echo -e "\033[0;33m提示: 输入 exit 退出容器\033[0m"
echo ""

proot-distro login "\$ALIAS"

clear
echo -e "\033[0;32m✓ 已退出 \$ALIAS\033[0m"
EOF
    
    chmod +x "$script_path"
}

# 生成所有容器的快捷启动脚本
generate_all_launchers() {
    local containers=$(get_installed_containers)
    
    if [ -z "$containers" ]; then
        echo -e "${YELLOW}⚠ 暂无已安装的容器，请先安装一个${NC}"
        return 1
    fi
    
    echo -e "${BLUE}正在生成快捷启动脚本...${NC}"
    
    for container in $containers; do
        generate_launcher "$container"
        echo -e "${GREEN}✓${NC} 已生成: $YROE_BIN_DIR/$container"
    done
    
    echo ""
    add_path_to_rc
    
    echo ""
    echo -e "${GREEN}✓ 全部生成完成！${NC}"
    echo -e "请运行 ${YELLOW}source $SHELL_RC${NC} 或重新打开 Termux 生效"
    echo -e "然后直接输入容器名即可启动，例如: ${GREEN}alpine${NC}"
}