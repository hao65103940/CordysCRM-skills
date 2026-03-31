# Cordys CRM Skill 场景验证手册

> 本手册用于验证 Cordys CRM Skill 的各项功能是否正常工作  
> **注意：** 所有示例均使用通用格式，请替换为实际数据

---

## 📋 前置准备

### 1. 配置环境变量

```bash
cd ~/.openclaw/skills/cordys-crm
cp .env.example .env
vim .env
```

**填写内容：**
```ini
ACCESS_KEY=你的 AccessKey
SECRET_KEY=你的 SecretKey
CRM_DOMAIN=你的 CRM 域名
```

### 2. 验证连接

```bash
./bin/cordys crm page lead '{"current":1,"pageSize":1}'
```

**预期结果：** 返回 JSON 数据（包含 `code: 100200`）

---

## 🧪 场景验证

### 场景 1：查询线索列表

**命令：**
```bash
./bin/cordys crm page lead '{"current":1,"pageSize":5}'
```

**验证点：**
- ✅ 返回线索列表
- ✅ 包含字段：`id`, `name`, `ownerName`, `stage`, `createTime`

**预期输出示例：**
```json
{
  "code": 100200,
  "data": {
    "list": [
      {
        "id": "xxx",
        "name": "某某公司",
        "ownerName": "张三",
        "stage": "NEW"
      }
    ],
    "total": 100
  }
}
```

---

### 场景 2：全局搜索客户

**命令：**
```bash
./bin/cordys crm search account "科技"
```

**验证点：**
- ✅ 返回包含"科技"的客户列表
- ✅ 搜索的是系统配置的固定字段（名称、电话等）

**预期输出：**
```json
{
  "code": 100200,
  "data": {
    "list": [
      {"name": "某某科技有限公司"},
      {"name": "某某科技公司"}
    ],
    "total": 50
  }
}
```

---

### 场景 3：按区域过滤线索

**命令：**
```bash
./bin/cordys crm page lead '{
  "current":1,
  "pageSize":50,
  "filters":[{"name":"1751888184000015","operator":"IN","value":["东区"]}]
}'
```

**验证点：**
- ✅ 只返回东区线索
- ✅ `page` 命令支持权限内高级查询

**说明：** 区域字段 ID 需根据实际系统调整

---

### 场景 4：按时间范围查询

**命令：**
```bash
./bin/cordys crm page lead '{
  "current":1,
  "pageSize":50,
  "combineSearch":{
    "conditions":[{"name":"createTime","operator":"DYNAMICS","value":"WEEK"}]
  }
}'
```

**验证点：**
- ✅ 返回本周创建的线索
- ✅ 支持动态时间常量：`TODAY`, `WEEK`, `MONTH` 等

**常用时间常量：**
| 常量 | 说明 |
|------|------|
| `TODAY` | 今天 |
| `YESTERDAY` | 昨天 |
| `WEEK` | 本周 |
| `LAST_MONTH` | 上个月 |
| `LAST_THIRTY` | 过去 30 天 |

---

### 场景 5：查询已成交商机

**命令：**
```bash
./bin/cordys crm page opportunity '{
  "current":1,
  "pageSize":50,
  "filters":[
    {"name":"stage","operator":"IN","value":["SUCCESS"]}
  ]
}'
```

**验证点：**
- ✅ 只返回已成交（SUCCESS 阶段）的商机
- ✅ 包含金额、客户名称等信息

---

### 场景 6：按产品过滤商机

**命令：**
```bash
./bin/cordys crm page opportunity '{
  "current":1,
  "pageSize":50,
  "filters":[
    {"name":"products","operator":"IN","value":["1751888184000091"]}
  ]
}'
```

**验证点：**
- ✅ 只返回包含指定产品的商机
- ✅ 产品 ID 需从字段映射表查询

**查询产品 ID：**
```bash
./bin/cordys crm product '{"current":1,"pageSize":10}'
```

---

### 场景 7：组合条件查询

**命令：**
```bash
./bin/cordys crm page opportunity '{
  "current":1,
  "pageSize":50,
  "combineSearch":{
    "searchMode":"AND",
    "conditions":[
      {"name":"stage","operator":"IN","value":["SUCCESS"]},
      {"name":"createTime","operator":"DYNAMICS","value":"MONTH"}
    ]
  },
  "filters":[
    {"name":"products","operator":"IN","value":["1751888184000091"]}
  ]
}'
```

**验证点：**
- ✅ 返回本月成交的 JumpServer 商机
- ✅ 支持多条件组合（AND/OR）
- ✅ `combineSearch` + `filters` 可同时使用

---

### 场景 8：查询跟进记录

**命令：**
```bash
./bin/cordys crm follow record lead '{"sourceId":"线索 ID","current":1,"pageSize":5}'
```

**验证点：**
- ✅ 返回指定线索的跟进记录
- ✅ 包含跟进内容、跟进人、时间

**预期输出：**
```json
{
  "code": 100200,
  "data": {
    "list": [
      {
        "content": "客户表示有兴趣",
        "ownerName": "张三",
        "createTime": 1774953664712
      }
    ]
  }
}
```

---

### 场景 9：查询我的线索

**命令：**
```bash
# 步骤 1: 获取当前用户 ID
./bin/cordys raw GET /personal/center/info | jq '.data.userId'

# 步骤 2: 查询我的线索
./bin/cordys crm page lead '{"owner":"你的用户 ID"}'
```

**验证点：**
- ✅ 只返回当前用户负责的线索
- ✅ `page` 命令带权限过滤

---

### 场景 10：查询二级模块（回款计划）

**命令：**
```bash
./bin/cordys crm page contract/payment-plan '{
  "current":1,
  "pageSize":10
}'
```

**验证点：**
- ✅ 支持二级模块查询
- ✅ 返回回款计划列表

**支持的二级模块：**
- `contract/payment-plan` - 回款计划
- `contract/payment-record` - 回款记录
- `contract/business-title` - 工商抬头
- `invoice` - 发票
- `opportunity/quotation` - 报价单

---

### 场景 11：查询全局搜索字段配置

**命令：**
```bash
./scripts/get-search-fields.sh
```

**验证点：**
- ✅ 返回各模块支持全局搜索的字段 ID
- ✅ `search` 命令只能搜索这些字段

**预期输出：**
```
### clue (线索)
字段 ID: 1751888184000013, 1751888184000021

### customer (客户)
字段 ID: 1751888184000002

### opportunity (商机)
字段 ID: 1751888184000029, 1751888184000037
```

---

### 场景 12：字段同步

**命令：**
```bash
./scripts/sync-fields.sh
```

**验证点：**
- ✅ 同步 4 个模块：lead/account/opportunity/contract
- ✅ 生成 `rules/platform/fields.md` 文件
- ✅ 自动备份旧文件

**预期输出：**
```
✓ lead 模块同步成功
✓ account 模块同步成功
✓ opportunity 模块同步成功
✓ contract 模块同步成功

✅ 字段同步完成！
```

---

### 场景 13：配置定时任务

**命令：**
```bash
./scripts/setup-cron.sh
```

**验证点：**
- ✅ 交互式选择配置方式（Crontab/OpenClaw）
- ✅ 选择同步频率（每周/每天/每月）
- ✅ 自动添加到定时任务

**预期输出：**
```
选择配置方式：

  1) Crontab（推荐，简单通用）
  2) OpenClaw Cron（需要 OpenClaw 支持）
  3) 取消配置

请选择 [1-3] 1

✓ Crontab 配置完成
同步频率：每周日凌晨 2 点
```

---

## 🔍 search vs page 区别验证

### 测试 1：search 命令（全局搜索）

```bash
./bin/cordys crm search account "江苏"
```

**特点：**
- ✅ 只能搜索固定字段（名称、电话）
- ✅ 无权限限制，全局搜索
- ❌ 不能按产品/区域/阶段过滤

---

### 测试 2：page 命令（权限内查询）

```bash
./bin/cordys crm page account '{
  "filters":[{"name":"1751888184000009","operator":"IN","value":["东区"]}]
}'
```

**特点：**
- ✅ 支持任意字段过滤
- ✅ 带权限过滤（只能查权限内数据）
- ✅ 支持复杂条件组合

---

## 📊 验证清单

| 场景 | 命令 | 状态 |
|------|------|------|
| 查询线索列表 | `crm page lead` | ⬜ 未验证 |
| 全局搜索客户 | `crm search account` | ⬜ 未验证 |
| 按区域过滤 | `crm page lead` + filters | ⬜ 未验证 |
| 按时间范围 | `crm page` + DYNAMICS | ⬜ 未验证 |
| 查询已成交商机 | `crm page opportunity` + stage | ⬜ 未验证 |
| 按产品过滤 | `crm page` + products | ⬜ 未验证 |
| 组合条件查询 | `crm page` + combineSearch | ⬜ 未验证 |
| 查询跟进记录 | `crm follow record` | ⬜ 未验证 |
| 查询我的线索 | `crm page lead` + owner | ⬜ 未验证 |
| 二级模块查询 | `crm page contract/payment-plan` | ⬜ 未验证 |
| 搜索字段配置 | `get-search-fields.sh` | ⬜ 未验证 |
| 字段同步 | `sync-fields.sh` | ⬜ 未验证 |
| 定时任务配置 | `setup-cron.sh` | ⬜ 未验证 |

---

## ⚠️ 常见问题

### 1. 返回 `code: 100500` 错误

**原因：** API 密钥配置错误

**解决：**
```bash
vim .env
# 检查 ACCESS_KEY 和 SECRET_KEY 是否正确
```

---

### 2. search 命令搜索不到数据

**原因：** `search` 只能搜索配置好的固定字段

**解决：** 使用 `page` 命令 + `filters` 进行高级查询

---

### 3. page 查询返回空数据

**可能原因：**
- 当前用户权限内无数据
- 字段 ID 错误
- 过滤条件过于严格

**排查：**
```bash
# 1. 先查询不带过滤条件的数据
./bin/cordys crm page lead '{"current":1,"pageSize":1}'

# 2. 检查字段 ID 是否正确
./bin/cordys raw GET /settings/fields?module=lead
```

---

### 4. 中文字符编码错误

**原因：** 直接传递中文字符串给 curl

**解决：** 使用 JSON 格式传递参数

```bash
# ✅ 正确
./bin/cordys crm search lead '{"keyword":"测试"}'

# ❌ 错误（可能编码问题）
./bin/cordys crm search lead "测试"
```

---

## 📞 技术支持

- **GitHub Issues:** https://github.com/hao65103940/CordysCRM-skills/issues
- **文档：** `references/api.md`
- **字段映射：** `rules/platform/fields.md`

---

*最后更新：2026-03-31*
