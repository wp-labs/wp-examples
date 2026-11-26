# Privacy / Desensitization Examples

本用例演示 OML 内联脱敏算子：`mask`、`mask_text`、`hash`、`tokenize`、`remove`，以及 object 内部与批量目标的脱敏写法。

## 目的

验证：

- IP 映射脱敏后仍是合法 IP（可继续用于 join / group by）
- 手机号、身份证、邮箱、域名、姓名的模式掩码
- 混合文本扫描脱敏（`mask_text`）：只替换识别到的片段，其余原样保留
- HTTP 凭据头脱敏（`mask_text(http_auth)`，含单行文本里的 `Authorization`）
- 不可逆关联哈希（同盐同值同结果）
- 可逆令牌生成（还原由独立工具完成）
- 字段删除
- `object { ... }` 内部 pipe
- 批量目标 `*_mail` + pipe

## 快速开始

```bash
cd core/privacy_examples
./run.sh
```

默认生成 100 条样本。可调整：

```bash
LINE_CNT=1000 ./run.sh
```

脚本会在 `.warp_parse/sec_key.toml` 中生成**仅用于示例**的随机密钥（`sec_pii_salt` / `sec_pii_key`）。生产环境请通过 `SEC_XXX` 机制提供，不要复用示例密钥。

## 密钥从哪来（零配置）

一套部署只有一组密钥，OML 里**不写密钥名**：

| 算子 | 默认密钥 | `sec_key.toml` 键 |
|---|---|---|
| `mask(ip)` / `hash(...)` | `pii_salt` | `sec_pii_salt` |
| `tokenize()` | `pii_key` | `sec_pii_key` |

`conf/wparse.toml` **不需要** `[privacy]` 配置（该段已移除，出现会作为未知字段报错）。加载链路：

1. `warp-parse` 启动时由 `load_sec_dict()` 读取 `.warp_parse/sec_key.toml`；
2. `WpApp::try_from` 调用 `wp_oml::set_secrets_from_env_dict(&env_dict)`；
3. `wp-oml` 把 `SEC_PII_SALT` 归一化为 `PII_SALT` 注册；
4. `mask(ip)` / `hash` 固定查找 `PII_SALT`，`tokenize()` 固定查找 `PII_KEY`。

手动配置：

```bash
mkdir -p .warp_parse
cp sec_key.toml.example .warp_parse/sec_key.toml
openssl rand -base64 32   # sec_pii_salt
openssl rand -base64 32   # sec_pii_key
chmod 600 .warp_parse/sec_key.toml
```

> 密钥名固定为 `pii_salt` / `pii_key`，OML 不提供 `salt:` / `key:` 参数，写错会解析报错。

## 模型示例

```oml
name : privacy_mask
rule : privacy/*
---
s_ip : ip = read(src_ip) | mask(ip) ;
d_ip : ip = read(dst_ip) | mask(ip) ;

mobile   : chars = read(mobile)   | mask(mobile) ;
id_card  : chars = read(id_card)  | mask(id_card) ;
mail     : chars = read(mail)     | mask(mail) ;
domain   : chars = read(domain)   | mask(domain) ;
name     : chars = read(name)     | mask(name, style:head) ;

// 混合文本：只替换识别到的片段，其余原样保留（时间戳、模块名、内网 IP 不动）
raw_log  : chars = read(raw_log)  | mask_text(pii) ;
auth_hdr : chars = read(auth_hdr) | mask_text(http_auth) ;
contact  : chars = read(contact)  | mask_text(mobile) | mask_text(mail) ;

uid_hash  : chars = read(user_id) | hash(sha256) ;
uid_token : chars = read(user_id) | tokenize() ;

notes : chars = read(notes) | remove ;

summary : obj = object {
  s_ip : ip    = read(src_ip) | mask(ip) ;
  mail : chars = read(mail)   | mask(mail) ;
};

*_mail : chars = read() | mask(mail) ;
```

## 输入字段

WPL 规则 `models/wpl/privacy/parse.wpl` 解析 CSV 行：

```text
privacy,src_ip,dst_ip,mobile,id_card,mail,domain,name,user_id,notes,backup_mail,raw_log,auth_hdr,contact
```

示例：

```text
privacy,203.0.113.5,198.51.100.9,13800138000,110101199003071234,alice@example.com,api.example.com,张三,user-1001,secret-note,bob@example.org,2026-10-20 15:26:46 DEBUG MsgUserContext - login user=huangxingbo password=Dayu@1234 mobile=13800138000 email=zhangsan@example.com from 10.168.0.123,Authorization: Basic YWRtaW46aG9yaXpvbjM=,call 13800138000 or mail alice@example.com
```

## 输出

结果写入 `data/out_dat/privacy_mask.json`。预期形态：

- `s_ip` / `d_ip`：保留地址池中的合法 IP（默认 IPv4 `240.0.0.0/4`，IPv6 `2001:db8::/32`）
- `mobile`：`*******8000`
- `id_card`：`110101********1234`
- `mail`：`a***@example.com`
- `domain`：`***.example.com`
- `name`：`张*`
- `uid_hash`：64 位 hex（SHA-256）
- `uid_token`：`tok:v1:<base64url>`
- `notes`：字段不存在
- `summary.s_ip` / `summary.mail`：已脱敏
- `backup_mail`：由批量目标 `*_mail` 脱敏
- `raw_log`：`mask_text(pii)` 后的日志行（密码 / 手机号 / 邮箱被替换，时间戳、模块名、内网 IP 保留）
- `auth_hdr`：`mask_text(http_auth)` 后的凭据头（保留头名与 `Basic` scheme）
- `contact`：`mask_text(mobile) | mask_text(mail)` 串联结果

## 说明

- `mask(ip)` 使用 HMAC-SHA256 + 盐映射到保留地址池，输出不是原文，也不会落入真实地址空间。
- `hash` 不可逆；`tokenize` 可逆，但还原不在 OML 内执行。
- `remove` 是终结算子，且会删除已存在的同名目标。
- 密钥缺失或类型不匹配时 fail-closed：输出占位值或丢弃字段，不会原样透传。
- `mask(ip)` 未配置盐且未显式 `allow_unsalted:true` 时不会输出原值。
- `mask_text` 是文本扫描的最佳努力契约：只处理识别到的片段（手机号 / 邮箱 / 身份证 / 凭据 / HTTP 凭据头等），未匹配文本保持不变；`mask` 仍是整值 + fail-closed。
