#!/data/data/com.termux/files/usr/bin/bash

# ============================================
# Yroe - 快捷启动脚本生成
# ============================================

# 获取模块路径（与 main.sh 逻辑一致）
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

# 智能判断模块路径
if [ "$SCRIPT_NAME" = "launcher.sh" ] && [ "$SCRIPT_DIR" != "$HOME/.yroe/lib" ]; then
    # 开发模式：从项目目录加载
    MODULE_PATH="${SCRIPT_DIR}/lib"
else
    # 安装模式：从用户目录加载
    MODULE_PATH="$HOME/.yroe/lib"
fi

# 使用 MODULE_PATH 加载
source "$MODULE_PATH/core.sh"
source "$MODULE_PATH/container.sh"

# 检测 shell 配置文件
detect_shell_rc() {
    case "$SHELL" in
        */zsh)  echo "$HOME/.zshrc" ;;
        */bash) echo "$HOME/.bashrc" ;;
        *)      echo "$HOME/.bashrc" ;;
    esac
}

SHELL_RC=$(detect_shell_rc)

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
    local script_path="$YROE_BIN_DIR/$alias"  # 使用全局变量
    
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
    echo -e "然后直接输入容器名即可启动，例如: ${GREEN}$(echo "$containers" | head -1)${NC}"
}