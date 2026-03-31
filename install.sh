#!/bin/bash

# Cordys CRM Skill 安装脚本
# 用途：自动安装 Cordys CRM Skill 并配置定时任务
# 使用：curl -fsSL https://raw.githubusercontent.com/hao65103940/CordysCRM-skills/v2.0-general/install.sh | bash

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 默认配置
DEFAULT_INSTALL_DIR="$HOME/.openclaw/skills/cordys-crm"
DEFAULT_BRANCH="v2.0-general"
REPO_URL="https://github.com/hao65103940/CordysCRM-skills.git"

echo -e "${BLUE}"
cat << 'EOF'
  ____                _          __  __                                                   _ 
 / ___|___  _   _ _ __(_) ___ _ __|  \/  | __ _ _ __   __ _  __ _  ___ _ __ ___   ___ _ __ | |
| |   / _ \| | | | '__| |/ _ \ '__| |\/| |/ _` | '_ \ / _` |/ _` |/ _ \ '_ ` _ \ / _ \ '_ \| |
| |__| (_) | |_| | |  | |  __/ |  | |  | | (_| | | | | (_| | (_| |  __/ | | | | |  __/ | | |_|
 \____\___/ \__,_|_|  |_|\___|_|  |_|  |_|\__,_|_| |_|\__,_|\__, |\___|_| |_| |_|\___|_| |_|(_)
                                                            |___/                               v2.0
EOF
echo -e "${NC}"
echo ""
echo -e "${GREEN}Cordys CRM Skill 安装脚本${NC}"
echo "======================================"
echo ""

# 检测操作系统
detect_os() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        echo "linux"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macos"
    else
        echo "unknown"
    fi
}

OS=$(detect_os)

# 检测 OpenClaw 是否安装
check_openclaw() {
    if command -v openclaw &> /dev/null; then
        return 0
    else
        return 1
    fi
}

# 检测 Cron 支持
check_cron_support() {
    if command -v crontab &> /dev/null; then
        echo "crontab"
    elif command -v systemctl &> /dev/null; then
        echo "systemd"
    elif check_openclaw; then
        echo "openclaw"
    else
        echo "none"
    fi
}

# 询问安装目录
ask_install_dir() {
    echo -e "${YELLOW}请选择安装目录：${NC}"
    echo -e "  默认：$DEFAULT_INSTALL_DIR"
    read -p "安装目录 [回车使用默认]: " INSTALL_DIR
    INSTALL_DIR="${INSTALL_DIR:-$DEFAULT_INSTALL_DIR}"
    echo ""
}

# 询问是否配置定时任务
ask_cron_config() {
    CRON_SUPPORT=$(check_cron_support)
    
    echo -e "${YELLOW}是否配置自动同步定时任务？${NC}"
    echo ""
    echo "Cordys CRM 字段定义可能会更新，建议配置定时任务定期同步。"
    echo ""
    
    if [ "$CRON_SUPPORT" == "none" ]; then
        echo -e "${RED}未检测到支持的定时任务系统${NC}"
        echo "您可以稍后手动配置 Crontab、systemd 或 OpenClaw Cron"
        CONFIG_CRON="n"
        return
    fi
    
    echo -e "检测到的定时任务系统：${GREEN}$CRON_SUPPORT${NC}"
    echo ""
    read -p "是否配置定时任务？[Y/n] " CONFIG_CRON
    CONFIG_CRON="${CONFIG_CRON:-Y}"
    echo ""
    
    if [[ "$CONFIG_CRON" =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}选择同步频率：${NC}"
        echo "  1) 每周同步一次（推荐，每周日凌晨 2 点）"
        echo "  2) 每天同步一次（每天凌晨 3 点）"
        echo "  3) 每月同步一次（每月 1 号凌晨 2 点）"
        echo ""
        read -p "请选择 [1-3] " SYNC_FREQ
        SYNC_FREQ="${SYNC_FREQ:-1}"
        
        case $SYNC_FREQ in
            1)
                CRON_EXPR="0 2 * * 0"
                FREQ_DESC="每周日凌晨 2 点"
                ;;
            2)
                CRON_EXPR="0 3 * * *"
                FREQ_DESC="每天凌晨 3 点"
                ;;
            3)
                CRON_EXPR="0 2 1 * *"
                FREQ_DESC="每月 1 号凌晨 2 点"
                ;;
            *)
                CRON_EXPR="0 2 * * 0"
                FREQ_DESC="每周日凌晨 2 点"
                ;;
        esac
        
        echo ""
        echo -e "${YELLOW}同步频率：${GREEN}$FREQ_DESC${NC}"
    fi
}

# 配置 Crontab
setup_crontab() {
    local script_path="$1"
    local log_file="$HOME/crm-fields-sync.log"
    
    # 创建临时 crontab 文件
    TEMP_CRON=$(mktemp)
    
    # 读取现有 crontab
    crontab -l 2>/dev/null > "$TEMP_CRON" || true
    
    # 添加新任务（先注释掉，让用户手动启用）
    echo "" >> "$TEMP_CRON"
    echo "# Cordys CRM 字段同步任务（由安装脚本创建）" >> "$TEMP_CRON"
    echo "# 取消注释以启用：删除行首的 # 号" >> "$TEMP_CRON"
    echo "# $CRON_EXPR $script_path >> $log_file 2>&1" >> "$TEMP_CRON"
    echo "$CRON_EXPR $script_path >> $log_file 2>&1" >> "$TEMP_CRON"
    
    # 安装 crontab
    crontab "$TEMP_CRON"
    rm -f "$TEMP_CRON"
    
    echo -e "${GREEN}✓ Crontab 配置完成${NC}"
    echo "  查看配置：crontab -l"
    echo "  日志文件：$log_file"
}

# 配置 systemd
setup_systemd() {
    local script_path="$1"
    local service_name="crm-fields-sync"
    
    # 创建 service 文件
    sudo tee /etc/systemd/system/${service_name}.service > /dev/null << EOF
[Unit]
Description=Cordys CRM Fields Sync
After=network.target

[Service]
Type=oneshot
User=$USER
WorkingDirectory=$(dirname $(dirname $script_path))
ExecStart=$script_path

[Install]
WantedBy=multi-user.target
EOF

    # 创建 timer 文件
    sudo tee /etc/systemd/system/${service_name}.timer > /dev/null << EOF
[Unit]
Description=Cordys CRM Fields Sync Timer

[Timer]
OnCalendar=$SYNC_FREQ
Persistent=true
Unit=${service_name}.service

[Install]
WantedBy=timers.target
EOF

    # 启用并启动
    sudo systemctl daemon-reload
    sudo systemctl enable ${service_name}.timer
    sudo systemctl start ${service_name}.timer
    
    echo -e "${GREEN}✓ systemd 配置完成${NC}"
    echo "  查看状态：systemctl status ${service_name}.timer"
    echo "  查看日志：journalctl -u ${service_name}.service"
}

# 配置 OpenClaw Cron
setup_openclaw_cron() {
    local cron_file="$1"
    
    if check_openclaw; then
        openclaw cron add --file "$cron_file" 2>/dev/null || true
        echo -e "${GREEN}✓ OpenClaw Cron 配置完成${NC}"
    else
        echo -e "${RED}✗ OpenClaw 未安装${NC}"
    fi
}

# 主安装流程
main() {
    # 询问安装目录
    ask_install_dir
    
    # 检查目录是否存在
    if [ -d "$INSTALL_DIR" ]; then
        echo -e "${YELLOW}目录已存在：$INSTALL_DIR${NC}"
        read -p "是否覆盖？[y/N] " OVERWRITE
        if [[ "$OVERWRITE" =~ ^[Yy]$ ]]; then
            rm -rf "$INSTALL_DIR"
        else
            echo -e "${RED}安装取消${NC}"
            exit 1
        fi
    fi
    
    # 克隆仓库
    echo -e "${YELLOW}正在克隆仓库...${NC}"
    git clone --branch $DEFAULT_BRANCH --depth 1 $REPO_URL "$INSTALL_DIR"
    echo -e "${GREEN}✓ 克隆完成${NC}"
    echo ""
    
    # 询问定时任务配置
    ask_cron_config
    
    # 配置定时任务
    if [[ "$CONFIG_CRON" =~ ^[Yy]$ ]]; then
        echo ""
        echo -e "${YELLOW}配置定时任务...${NC}"
        
        SYNC_SCRIPT="$INSTALL_DIR/scripts/sync-fields.sh"
        CRON_FILE="$INSTALL_DIR/scripts/openclaw-cron.json"
        
        case $CRON_SUPPORT in
            crontab)
                setup_crontab "$SYNC_SCRIPT"
                ;;
            systemd)
                setup_systemd "$SYNC_SCRIPT"
                ;;
            openclaw)
                setup_openclaw_cron "$CRON_FILE"
                ;;
        esac
        
        echo ""
        echo -e "${GREEN}同步频率：$FREQ_DESC${NC}"
    fi
    
    # 创建 .env 文件
    echo ""
    echo -e "${YELLOW}创建环境变量配置文件...${NC}"
    if [ ! -f "$INSTALL_DIR/.env" ]; then
        cp "$INSTALL_DIR/.env.example" "$INSTALL_DIR/.env"
        echo -e "${GREEN}✓ 已创建：$INSTALL_DIR/.env${NC}"
        echo ""
        echo -e "${YELLOW}请编辑 .env 文件配置 API 密钥：${NC}"
        echo "  vim $INSTALL_DIR/.env"
    else
        echo -e "${GREEN}✓ .env 文件已存在${NC}"
    fi
    
    # 验证安装
    echo ""
    echo -e "${YELLOW}验证安装...${NC}"
    cd "$INSTALL_DIR"
    if [ -f "scripts/sync-fields.sh" ]; then
        chmod +x scripts/sync-fields.sh
        echo -e "${GREEN}✓ 安装验证通过${NC}"
    fi
    
    # 完成提示
    echo ""
    echo -e "${GREEN}================================${NC}"
    echo -e "${GREEN}  安装完成！${NC}"
    echo -e "${GREEN}================================${NC}"
    echo ""
    echo -e "${BLUE}下一步：${NC}"
    echo ""
    echo "1. 配置 API 密钥"
    echo -e "   ${YELLOW}vim $INSTALL_DIR/.env${NC}"
    echo ""
    echo "2. 测试连接"
    echo -e "   ${YELLOW}cd $INSTALL_DIR && cordys crm page lead${NC}"
    echo ""
    echo "3. 手动同步字段（可选）"
    echo -e "   ${YELLOW}./scripts/sync-fields.sh${NC}"
    echo ""
    
    if [[ "$CONFIG_CRON" =~ ^[Yy]$ ]]; then
        echo -e "${GREEN}✓ 定时任务已配置：$FREQ_DESC${NC}"
        echo "  字段将自动同步，无需手动操作"
        echo ""
    fi
    
    echo -e "${BLUE}文档：${NC}https://github.com/hao65103940/CordysCRM-skills"
    echo ""
}

# 运行安装
main
