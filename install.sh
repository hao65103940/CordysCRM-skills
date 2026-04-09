#!/bin/bash

# CordysCRM-skills 安装脚本
# 将 skills 目录安装到 OpenClaw 技能目录

set -e

REPO_URL="https://github.com/hao65103940/CordysCRM-skills"
INSTALL_DIR="$HOME/.openclaw/skills/cordys-crm"
TEMP_DIR="/tmp/cordys-crm-install"

# 获取默认分支（main 或 v2.0-general）
BRANCH="${1:-main}"

echo "🚀 开始安装 CordysCRM-skills (分支：$BRANCH)"

# 清理临时目录
rm -rf "$TEMP_DIR"

# 克隆仓库
echo "📦 克隆仓库..."
git clone --depth 1 --branch "$BRANCH" "$REPO_URL" "$TEMP_DIR"

# 检查 skills 目录是否存在
if [ -d "$TEMP_DIR/skills" ]; then
    echo "📁 发现 skills 目录，使用标准结构"
    SOURCE_DIR="$TEMP_DIR/skills"
elif [ -d "$TEMP_DIR/bin" ]; then
    echo "📁 发现扁平结构，需要调整"
    SOURCE_DIR="$TEMP_DIR"
else
    echo "❌ 错误：未找到有效的技能目录结构"
    exit 1
fi

# 如果目标目录已存在，备份
if [ -d "$INSTALL_DIR" ]; then
    BACKUP_DIR="$INSTALL_DIR.backup.$(date +%Y%m%d%H%M%S)"
    echo "⚠️  目标目录已存在，备份到：$BACKUP_DIR"
    mv "$INSTALL_DIR" "$BACKUP_DIR"
fi

# 创建目标目录并复制
echo "📋 安装到 $INSTALL_DIR"
mkdir -p "$INSTALL_DIR"
cp -r "$SOURCE_DIR"/* "$INSTALL_DIR/"

# 设置执行权限
chmod +x "$INSTALL_DIR/bin/cordys" 2>/dev/null || true
chmod +x "$INSTALL_DIR/bin/cordys.sh" 2>/dev/null || true
chmod +x "$INSTALL_DIR/scripts/"*.sh 2>/dev/null || true

# 清理临时目录
rm -rf "$TEMP_DIR"

# 提示配置环境变量
echo ""
echo "✅ 安装完成！"
echo ""
echo "📝 下一步：配置环境变量"
echo "   cp $INSTALL_DIR/.env.example $INSTALL_DIR/.env"
echo "   vim $INSTALL_DIR/.env"
echo ""
echo "🔧 环境变量说明："
echo "   ACCESS_KEY=你的 AccessKey"
echo "   SECRET_KEY=你的 SecretKey"
echo "   CRM_DOMAIN=https://your-crm-domain.com"
echo ""
echo "🧪 测试连接："
echo "   cd $INSTALL_DIR && ./bin/cordys crm page lead"
echo ""
