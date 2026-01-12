# wpl_success

本用例演示"WPL 成功解析全链路"的场景：验证 WPL 规则能够成功解析多种安全告警日志格式（webids_alert、webshell_alert、ips_alert、ioc_alert、system、audit 等），并正确路由到业务 sink。适用于验证解析规则的正确性与完整性。

## 目录结构
- `conf/`：配置目录
  - `conf/wparse.toml`：主配置
- `models/`：规则与路由
  - `models/wpl/qty_alert/`：安全告警解析规则
    - `parse.wpl`：多种告警类型的解析规则
  - `models/oml/`：OML 转换模型
  - `models/sinks/business.d/`：业务路由
  - `models/sinks/infra.d/`：基础组
  - `models/sources/wpsrc.toml`：源配置
- `data/`：运行数据目录
- `out/`：输出目录

## 支持的告警类型

### 解析规则 (models/wpl/qty_alert/parse.wpl)

本用例支持以下安全告警类型：

| 告警类型 | data_type 标签 | 说明 |
|----------|----------------|------|
| webids_alert | webids_alert | Web 入侵检测告警 |
| webshell_alert | webshell_alert | Webshell 检测告警 |
| ips_alert | ips_alert | 入侵防护系统告警 |
| ioc_alert | ioc_alert | 威胁情报告警 |
| system | system | 系统日志 |
| audit | audit | 审计日志 |

### 规则示例
```wpl
package /qty {
    #[tag(data_type: "webids_alert")]
    rule webids_alert {
        (symbol(webids_alert), chars:serialno, chars:rule_id, chars:rule_name,
         time_timestamp:write_date, chars:vuln_type, ip:sip, digit:sport,
         ip:dip, digit:dport, digit:severity, chars:host, chars:parameter,
         chars:uri, chars:filename, chars:referer, chars:method, chars:vuln_desc,
         time:public_date, chars:vuln_harm, chars:solution, chars:confidence,
         chars:victim_type, chars:attack_flag, chars:attacker, chars:victim,
         digit:attack_result, chars:kill_chain, chars:code_language,
         time:loop_public_date, chars:rule_version, chars:xff, chars:vlan_id,
         chars:vxlan_id)\|\!
    }

    #[tag(data_type: "audit")]
    rule audit {
        (kv(chars@username), kv(chars@serialno), kv(chars@submod),
         kv(chars@detail), kv(time@updatetime), kv(ip@ip), kv(chars@sub2),
         kv(chars@log_type), kv(chars@module), kv(digit@sub_type))\|\!
    }
    // ... 更多规则
}
```

### 规则注解
- `#[tag(data_type: "...")]`：为解析结果添加数据类型标签，用于后续路由分发

## 快速使用

### 构建项目
```bash
cargo build --workspace --all-features
```

### 运行用例
```bash
cd core/wpl_success
./run.sh
```

脚本执行流程：
1. 初始化环境与配置
2. 使用 wpgen 生成多种告警类型的样本数据
3. 验证输入文件存在
4. 运行 wparse 批处理解析
5. 校验输出统计与期望

### 手动执行
```bash
# 初始化配置
wproj check
wproj data clean
wpgen data clean

# 生成样本数据
wpgen sample -n 3000 --stat 3

# 验证输入文件
test -s "./data/in_dat/gen.dat" || echo "missing input file"

# 运行批处理解析
wparse batch --stat 3 -p -n 3000

# 校验输出
wproj data stat
wproj data validate
```

## 可调参数
- `LINE_CNT`：生成行数（默认 3000）
- `STAT_SEC`：统计间隔秒数（默认 3）

## 期望配置

### 成功解析期望
本用例的目标是验证解析成功率，期望配置示例：
```toml
[defaults.expect]
basis = "total_input"
min_samples = 100
mode = "warn"

# 业务组期望高成功率
[sink_group.expect]
ratio = 0.95    # 期望 95% 的数据成功解析
tol = 0.05      # 容差 ±5%
```

### 基础组期望
```toml
# miss 组期望较低
[sink_group.expect]
max = 0.05      # 缺失数据不超过 5%

# error 组期望为 0
[sink_group.expect]
max = 0.01      # 错误数据不超过 1%
```

## 字段提取说明

### 必需字段（无 `\|` 标记）
缺失时整条记录进入 miss 组

### 可选字段（带 `\|!` 标记）
缺失时记录继续解析，字段为空

### KV 格式解析
```wpl
kv(chars@username)  # 解析 key=value 格式，提取 username
kv(time@updatetime) # 解析 key=value 格式，提取时间类型的 updatetime
```

## 常见问题

### Q1: 解析成功率低
- 检查样本数据格式是否与 WPL 规则匹配
- 确认字段分隔符与规则定义一致
- 查看 `data/logs/wparse.log` 中的解析错误

### Q2: 某种告警类型未匹配
- 确认告警类型前缀正确（如 `symbol(webids_alert)`）
- 检查字段数量与顺序是否一致

### Q3: 数据标签未生效
- 确认规则注解格式正确：`#[tag(data_type: "...")]`
- 确认 OML/Sink 路由配置使用了对应标签

## 相关文档
- [WPL 基础](../../wp-docs/10-user/06-wpl/01-wpl_basics.md)
- [WPL 语法](../../wp-docs/10-user/06-wpl/02-wpl_grammar.md)
- [规则注解](../../wp-docs/10-user/06-wpl/README.md)
- [Sinks 路由](../../wp-docs/10-user/03-sinks/routing.md)
