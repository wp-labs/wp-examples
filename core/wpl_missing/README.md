# wpl_missing

本用例演示"WPL 字段缺失容错"的场景：当输入数据中某些字段不存在或解析失败时，系统如何处理缺失字段并将数据路由到相应的基础组（miss）。适用于验证 WPL 规则的容错性与数据完整性校验。

## 目录结构
- `conf/`：配置目录
  - `conf/wparse.toml`：主配置
- `models/`：规则与路由
  - `models/wpl/benchmark/`：WPL 解析规则
    - `parse.wpl`：解析规则
    - `gen_rule.wpl`：生成规则（包含缺失字段的样本）
  - `models/sinks/business.d/`：业务路由
  - `models/sinks/infra.d/`：基础组（含 miss 组）
  - `models/sources/wpsrc.toml`：源配置
- `data/`：运行数据目录

## WPL 容错机制

### 可选字段语法
在 WPL 规则中，使用 `\|` 标记可选字段：
```wpl
package /benchmark {
    rule benchmark_1 {
        (digit:id, digit:len, time, sn, chars:dev_name\|, ...)
    }
}
```

### 缺失字段处理
- 必需字段缺失：整条记录路由到 `miss` 基础组
- 可选字段缺失：记录继续解析，缺失字段为空值
- 解析失败：记录路由到 `residue` 或 `error` 基础组

## 解析规则示例

### parse.wpl
```wpl
package /benchmark {
    rule benchmark_1 {
        (digit:id, digit:len, time, sn, chars:dev_name, time, kv, sn,
         chars:dev_name, time, time, ip, kv, chars, kv, kv, chars, kv, kv,
         chars, chars, ip, chars, http/request<[,]>, http/agent")\,
    }
    rule benchmark_2 {
        (ip:src_ip, digit:port, chars:dev_name, ip:dst_ip, digit:port,
         time", kv, kv, sn, kv, ip, kv, chars, kv, sn, kv, kv, time, chars,
         time, sn, kv, chars, chars, ip, chars, http/request", http/agent")\,
    }
}
```

## 快速使用

### 构建项目
```bash
cargo build --workspace --all-features
```

### 运行用例
```bash
cd core/wpl_missing
./run.sh
```

脚本执行流程：
1. 初始化环境与配置
2. 使用 wpgen 生成包含缺失字段的样本数据
3. 运行 wparse 批处理解析
4. 校验输出统计（验证 miss 组有数据）

### 手动执行
```bash
# 初始化配置
wproj check
wproj data clean
wpgen data clean

# 生成样本数据
wpgen sample -n 1000

# 运行批处理解析
wparse batch --stat 2 -p

# 校验输出
wproj data stat
wproj data validate
```

## 可调参数
- `LINE_CNT`：生成行数（默认 1000）
- `STAT_SEC`：统计间隔秒数（默认 2）

## 基础组说明

| 组名 | 用途 | 预期行为 |
|------|------|----------|
| default | 默认输出 | 未路由到业务组的数据 |
| miss | 缺失字段 | 必需字段缺失的数据 |
| residue | 残留数据 | 部分解析成功的数据 |
| error | 错误数据 | 处理出错的数据 |
| monitor | 监控指标 | 系统指标输出 |

## 期望配置

在 `models/sinks/defaults.toml` 中设置期望：
```toml
[defaults.expect]
basis = "total_input"
min_samples = 1
mode = "warn"
```

对于 miss 组，可以设置合理的上限：
```toml
# models/sinks/infra.d/miss.toml
[[sink_group]]
name = "/sink/infra/miss"

[sink_group.expect]
max = 0.1  # 缺失数据不超过 10%
```

## 常见问题

### Q1: miss 组数据过多
- 检查 WPL 规则是否与输入数据格式匹配
- 确认必需字段在输入数据中存在
- 考虑将某些字段改为可选（添加 `\|` 标记）

### Q2: 如何区分 miss 和 residue
- miss：必需字段缺失导致规则无法匹配
- residue：规则部分匹配但有残留内容

### Q3: 可选字段默认值
- 可选字段缺失时默认为空值
- 可在 OML 中使用 `take(option:[field])` 处理

## 相关文档
- [WPL 基础](../../wp-docs/10-user/06-wpl/01-wpl_basics.md)
- [WPL 语法](../../wp-docs/10-user/06-wpl/02-wpl_grammar.md)
- [Sinks 基础](../../wp-docs/10-user/03-sinks/01-sinks_basics.md)
