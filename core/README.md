# Core Examples

This directory contains core end-to-end examples and scenario-based configurations for quickly validating parsing, routing, filtering, metrics, and verification capabilities.

## Case List

| Case | Purpose | Validated Features |
|------|---------|-------------------|
| **confvars_case** | Configuration variables usage | Variable substitution, environment overrides |
| **error_reporting** | Error data reporting with multi-format output | Error routing, JSON/KV output, OML transformation |
| **file_source** | File-based data source ingestion | File source, batch processing |
| **knowdb_case** | Knowledge database queries and data association | SQL-like OML queries, CSV knowledge bases, dynamic lookup |
| **oml_examples** | Comprehensive OML transformation | Conditional matching, range matching, tuple matching, knowledge base queries |
| **prometheus_metrics** | Prometheus metrics export | HTTP `/metrics` endpoint, counters, gauges, histograms |
| **sink_filter** | Sink-level filtering and data splitting | Filter rules, multi-path routing, expectation validation |
| **sink_recovery** | Sink failure handling and data recovery | Rescue files, interruption/recovery cycle, replay pipeline |
| **syslog_udp** | UDP Syslog source integration | UDP syslog reception, parsing, routing |
| **tcp_roundtrip** | TCP input/output end-to-end link | TCP source/sink, data flow validation |
| **wpl_missing** | WPL field missing and fault tolerance | Optional fields, miss group handling, data completeness |
| **wpl_pipe** | WPL pipeline preprocessing | Base64 decoding, unquote/unescape, trim operations |
| **wpl_success** | Successful full-chain WPL parsing | Multi-rule parsing, data_type tags, routing validation |
| **stat_test** | Statistical testing | Statistics validation, test scenarios |

## Common Directory Structure

Each case typically follows this structure:
```
case_name/
├── README.md                 # Documentation
├── run.sh                    # Execution script
├── conf/
│   ├── wparse.toml          # Main WarpParse configuration
│   └── wpgen.toml           # Data generator configuration (optional)
├── models/
│   ├── wpl/                 # WPL parsing rules
│   ├── oml/                 # OML transformation models
│   ├── knowledge/           # Knowledge base data (CSV/SQL)
│   └── sinks/               # Sink routing configuration
├── data/
│   ├── in_dat/              # Input data
│   ├── out_dat/             # Output data
│   └── logs/                # Processing logs
└── topology/                # Alternative structure for some cases
```

## Quick Start

```bash
# Enter case directory
cd core/<case_name>

# Run the case
./run.sh

# Check statistics
wproj data stat

# Validate output
wproj data validate
```

## FAQ

- **Filter not working**:
  - Paths are resolved relative to current working directory; ensure `filter.conf` is accessible from `sink_root`
  - Expressions must be parseable by TCondParser; test with simple expressions first
- **Prometheus not started**:
  - Without configuring Prometheus connector and switching `monitor` group to it, no `/metrics` endpoint will be available
- **Parameter override failed**:
  - `params` keys must be in the connector's `allow_override` whitelist

> **Convention over configuration**: Always explicitly set `name` for each sink to get stable `full_name` and more readable validation reports; for filter-based cases, put filter conditions in `filter.conf` for reuse and review.

---

# Core用例 (中文)

本目录收录核心端到端用例与场景化配置，便于快速验证解析、路由、过滤、度量与校验能力。

## 用例清单

| 用例 | 目的 | 验证特性 |
|------|------|----------|
| **confvars_case** | 配置变量使用 | 变量替换、环境变量覆盖 |
| **error_reporting** | 错误数据报表与多格式输出 | 错误路由、JSON/KV 输出、OML 转换 |
| **file_source** | 基于文件的数据源输入 | 文件源、批处理 |
| **knowdb_case** | 知识库查询与数据关联 | SQL 风格 OML 查询、CSV 知识库、动态查找 |
| **oml_examples** | 综合 OML 转换示例 | 条件匹配、范围匹配、元组匹配、知识库查询 |
| **prometheus_metrics** | Prometheus 指标导出 | HTTP `/metrics` 端点、计数器、仪表、直方图 |
| **sink_filter** | Sink 级过滤与数据分流 | 过滤规则、多路径路由、期望值校验 |
| **sink_recovery** | Sink 故障处理与数据恢复 | 救急文件、中断/恢复流程、回放管道 |
| **syslog_udp** | UDP Syslog 源集成 | UDP syslog 接收、解析、路由 |
| **tcp_roundtrip** | TCP 输入/输出端到端链路 | TCP 源/汇、数据流验证 |
| **wpl_missing** | WPL 字段缺失与容错 | 可选字段、miss 组处理、数据完整性 |
| **wpl_pipe** | WPL 管道预处理 | Base64 解码、unquote/unescape、trim 操作 |
| **wpl_success** | WPL 成功解析全链路 | 多规则解析、data_type 标签、路由验证 |
| **stat_test** | 统计测试 | 统计验证、测试场景 |

## 通用目录结构

每个用例通常遵循以下结构：
```
case_name/
├── README.md                 # 文档说明
├── run.sh                    # 执行脚本
├── conf/
│   ├── wparse.toml          # WarpParse 主配置
│   └── wpgen.toml           # 数据生成器配置（可选）
├── models/
│   ├── wpl/                 # WPL 解析规则
│   ├── oml/                 # OML 转换模型
│   ├── knowledge/           # 知识库数据（CSV/SQL）
│   └── sinks/               # Sink 路由配置
├── data/
│   ├── in_dat/              # 输入数据
│   ├── out_dat/             # 输出数据
│   └── logs/                # 处理日志
└── topology/                # 部分用例的替代结构
```

## 快速开始

```bash
# 进入用例目录
cd core/<case_name>

# 运行用例
./run.sh

# 查看统计
wproj data stat

# 校验输出
wproj data validate
```

## 常见问题

- **filter 未生效**：
  - 路径基于当前工作目录解析；确保 `filter.conf` 相对 `sink_root` 可访问
  - 表达式需能被 TCondParser 解析；可先用简单表达式测试
- **Prometheus 未启动**：
  - 未配置 Prometheus 连接器并将 `monitor` 组切换到该连接器时，不会有 `/metrics` 端点
- **覆盖参数失败**：
  - `params` 的键必须在连接器 `allow_override` 白名单中

> **约定优于配置**：尽量为每个 sink 显式给出 `name`，以获得稳定的 `full_name` 与更可读的校验报表；对过滤型用例，请把拦截条件放在 `filter.conf` 文件，便于复用与审阅。
