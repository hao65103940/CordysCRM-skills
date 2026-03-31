#!/bin/bash

# Cordys CRM 字段同步脚本
# 用途：从 CRM 系统同步字段定义到 Markdown 文件
# 使用：./scripts/sync-fields.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
OUTPUT_FILE="$ROOT_DIR/rules/platform/fields.md"
ENV_FILE="$ROOT_DIR/.env"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}  Cordys CRM 字段同步脚本${NC}"
echo -e "${GREEN}================================${NC}"

# 检查 .env 文件
if [ ! -f "$ENV_FILE" ]; then
    echo -e "${RED}错误：.env 文件不存在${NC}"
    echo "请复制 .env.example 并配置 ACCESS_KEY 和 SECRET_KEY"
    exit 1
fi

# 加载环境变量
source "$ENV_FILE"

# 检查环境变量
if [ -z "$ACCESS_KEY" ] || [ -z "$SECRET_KEY" ]; then
    echo -e "${RED}错误：ACCESS_KEY 或 SECRET_KEY 未配置${NC}"
    exit 1
fi

CRM_DOMAIN="${CRM_DOMAIN:-https://crm.fit2cloud.com}"

echo ""
echo -e "${YELLOW}CRM 域名：${NC}$CRM_DOMAIN"
echo -e "${YELLOW}输出文件：${NC}$OUTPUT_FILE"
echo ""

# 备份现有文件
if [ -f "$OUTPUT_FILE" ]; then
    BACKUP_FILE="$OUTPUT_FILE.backup.$(date +%Y%m%d%H%M%S)"
    cp "$OUTPUT_FILE" "$BACKUP_FILE"
    echo -e "${YELLOW}已备份现有文件：${NC}$BACKUP_FILE"
fi

# 创建临时文件
TEMP_FILE=$(mktemp)

# 写入 Markdown 头部
cat > "$TEMP_FILE" << 'EOF'
# Cordys CRM 字段映射表

> 最后更新：
EOF
echo "$(date +%Y-%m-%d)" >> "$TEMP_FILE"
cat >> "$TEMP_FILE" << 'EOF'
> 用途：将字段 ID 转换为可读的字段名和选项值

---

## 📌 说明

本文件由同步脚本自动生成，包含 CRM 系统各模块的字段定义和选项值映射。

**同步命令：**
```bash
./scripts/sync-fields.sh
```

---

## 🔄 同步各模块字段

EOF

# 同步各模块字段
MODULES=("lead" "account" "opportunity" "contract")

for module in "${MODULES[@]}"; do
    echo -e "${YELLOW}正在同步 ${module} 模块...${NC}"
    
    RESPONSE=$(curl -s -X GET "$CRM_DOMAIN/settings/fields?module=$module" \
        -H "X-Access-Key: $ACCESS_KEY" \
        -H "X-Secret-Key: $SECRET_KEY" \
        -H "Content-Type: application/json")
    
    # 检查响应是否有效
    if echo "$RESPONSE" | jq -e '.code == 100200' > /dev/null 2>&1; then
        echo -e "${GREEN}  ✓ ${module} 模块同步成功${NC}"
        
        # 提取字段信息并写入 Markdown
        echo "## ${module^} ($(echo $module | sed 's/.*/\U&/'))" >> "$TEMP_FILE"
        echo "" >> "$TEMP_FILE"
        echo "| 字段 ID | 字段名 | 类型 | 说明 |" >> "$TEMP_FILE"
        echo "|--------|--------|------|------|" >> "$TEMP_FILE"
        
        # 解析字段列表（简化版）
        FIELDS=$(echo "$RESPONSE" | jq -r '.data.fields // [] | .[] | "| \(.id) | \(.name) | \(.type) | \(.description // "") |"' 2>/dev/null)
        
        if [ -n "$FIELDS" ]; then
            echo "$FIELDS" >> "$TEMP_FILE"
        else
            echo "| - | - | - | 无字段数据 |" >> "$TEMP_FILE"
        fi
        
        echo "" >> "$TEMP_FILE"
        echo "---" >> "$TEMP_FILE"
        echo "" >> "$TEMP_FILE"
    else
        echo -e "${RED}  ✗ ${module} 模块同步失败${NC}"
        echo "响应：$RESPONSE" | head -c 200
        echo ""
    fi
done

# 写入尾部说明
cat >> "$TEMP_FILE" << 'EOF'
## 📝 注意事项

1. **时间戳格式**：所有时间字段都是毫秒级时间戳 (JavaScript 格式)
2. **字段 ID**：自定义字段必须使用字段 ID，不能用字段名
3. **选项值**：下拉框字段存储的是选项 ID，不是显示名称
4. **金额单位**：所有金额字段单位是**元**（不是万元）

---

## 🔧 手动获取字段

```bash
# 获取线索字段
cordys raw GET /settings/fields?module=lead

# 获取客户字段
cordys raw GET /settings/fields?module=account

# 获取商机字段
cordys raw GET /settings/fields?module=opportunity
```
EOF

# 移动临时文件到目标位置
mv "$TEMP_FILE" "$OUTPUT_FILE"

echo ""
echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}  同步完成！${NC}"
echo -e "${GREEN}================================${NC}"
echo ""
echo -e "${YELLOW}输出文件：${NC}$OUTPUT_FILE"
echo -e "${YELLOW}更新时间：${NC}$(date +%Y-%m-%d)"
echo ""

# 提示检查变更
if command -v git &> /dev/null && git rev-parse --git-dir > /dev/null 2>&1; then
    echo -e "${YELLOW}Git 变更检查：${NC}"
    git diff --stat "$OUTPUT_FILE" 2>/dev/null || echo "无变更"
fi

echo ""
echo -e "${GREEN}✅ 字段同步完成！${NC}"
