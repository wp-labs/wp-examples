# Core用例

本目录收录核心端到端用例与场景化配置，便于快速验证解析、路由、过滤、度量与校验能力。

## 目录规范（V2）
- 每个用例的标准布局（已逐步迁移）：
  - `conf/`：引擎与工具配置（`wparse.toml` 等）
  - `connectors/source.d/`、`connectors/sink.d/`：源/汇连接器（file/syslog/kafka/DB 等）
  - `models/`：规则与路由（`models/wpl`、`models/oml`、`models/sources/wpsrc.toml`、`models/sinks/{business.d,infra.d,defaults.toml}`）
  - `data/`：运行数据目录（`data/in_dat`、`data/out_dat`、`data/rescue`、`logs/`）
  - 其它：脚本与 README 按各场景自述

## 常用命令（wproj / wparse）
- 初始化 & 校验
  - `wproj conf clean|init|check` 生成与校验 `conf/`、`connectors/`、`models/`（源配置默认写入 `models/sources/wpsrc.toml`）
  - `wproj data clean|check` 清理输出或校验/构建源（v2）
- 数据生成
  - `wpgen conf init` 生成生成器配置
  - `wpgen sample -n N --stat S` 生成样本到 `data/in_dat/`
- 解析运行
  - `wparse batch --stat S -p [-n N]` 批处理运行
- 统计与校验
  - `wproj stat file|src-file|sink-file [--json]`
  - `wproj validate sink-file [-v] [--input-cnt N] [--json]`

## 全局约定
- sink 命名
  - `name`：单个 sink 的名称，需在同一 `sink_group` 内唯一；未显式提供时按索引回退为 `[0]`、`[1]`…
  - `full_name = sink_group.name + "/" + name`，CLI 展示与运行期内部标识统一使用 `full_name`。
- filter 语义
  - `filter` 是“拦截条件”：表达式为 `true` 时该 sink 丢弃本条数据并转发至基础组 `intercept`；为 `false` 时才写入该 sink。
- 校验（validate）
  - 三层期望：`defaults.expect`（全局默认）→ `sink_group.expect`（组级）→ `sink.expect`（单项）
  - `ratio±tol` 或 `[min,max]` 二选一；`min_samples` 控制分母阈值。
- CLI 展示
  - `wproj stat file` 与 `wproj validate sink-file` 的 Sink 列统一显示 `full_name`。

## 快速开始（完整指南）
- 文档入口：`docs/README.md`
- 快速入门：`docs/getting-started/quickstart.md`

## 快速开始（命令摘要）
- 构建：`cargo build --workspace --all-features`
- 进入用例目录并运行：`./case_verify.sh`
- 单步：
  - 统计：`wproj stat file`
  - 校验：`wproj validate sink-file -v`

---

## 用例清单

### 1) getting_started（初始化示例）
- 目的：最小可运行工程模板，初始化 source/oml/sink 与基础组。
- 入口：`usecase/core/getting_started/case_verify.sh`
- 业务组：`sink/business.d/benchmark.toml` → `/sink/benchmark`
- 基础组：`sink/infra.d/*.toml`（default/miss/residue/intercept/error/monitor）

### 2) multi_sink（多汇与占比）
- 目的：同一 `sink_group` 下多种输出格式与占比校验。
- 入口：`usecase/core/multi_sink/case_verify.sh`
- 业务组：`sink/business.d/simple.toml`
  - 组名：`/sink/simple`
  - sinks：`dat/json/kv`（各 1/3 占比）

### 3) wpl_success / wpl_missing（规则成功/缺失场景）
- wpl_success：成功解析全链路
- wpl_missing：字段缺失容错；已统一 `sink_group` 为 `/sink/simple`，sinks 命名为 `dat/json/kv`
- 入口：`usecase/core/wpl_success|wpl_missing/case_verify.sh`

### 4) source_file（多文件源与对半分流）
- 目的：演示 `Benchmark1/Benchmark2` 两路对半分流（KV 输出）
- 业务组：`sink/business.d/benchmark1.toml` → `/sink/benchmark1`，`benchmark2.toml` → `/sink/benchmark2`
- 建议：如需更直观，可改为 `/sink/benchmark/kv1`、`/sink/benchmark/kv2`

### 5) sink_filter（按 sink 过滤/拦截）
- 目的：按规则将数据划分为全量与安全两路；命中过滤条件的样本进入 `intercept`
- 业务组：`sink/business.d/filter.toml` → `/sink/filter`
  - `all`：不设置 `filter`，收全量
  - `safe`：`filter = "./sink/business.d/filter.conf"`（请在文件中写“非安全”条件，命中则拦截）
- 入口：`usecase/core/sink_filter/case_verify.sh`

### 6) prometheus_metrics（Prometheus 指标导出）
- 目的：经 Prometheus sink 导出内部指标，curl `/metrics` 拉取
- 业务组：`sink/business.d/benchmark.toml`（样本）
- 基础组：`sink/infra.d/monitor.toml` → 建议改为 Prometheus 连接器
  - 添加连接器：`usecase/core/connectors/sink.d/10-prometheus.toml`
  - 修改 `monitor.toml`，`connect = "prometheus_sink"`（或覆盖 endpoint 为 `127.0.0.1:35666`）
- 验证：`curl -s http://127.0.0.1:35666/metrics`

### 7) sink_recovery（故障切换与救援）
- 目的：写入失败时使用 rescue；可在 `logs/wparse.log` 中观察 fallback/repair
- 业务组：`sink/business.d/benchmark.toml`、`example.toml`（可为 sinks 添加 `primary/backup` 等更语义化名称）

### 8) oml_examples（OML 转换示例）
- 目的：多种 OML 转换与输出格式
- 业务组：`sink/business.d/skyeye_stat.toml`、`work_case.toml`、`csv_example.toml`
- 建议：给 sinks 显式命名（如 `skyeye_adm/skyeye_pdm`），便于 `full_name` 识别

### 9) error_reporting（错误数据报表）
- 目的：针对错误数据路径输出多格式报表
- 业务组：`sink/business.d/skyeye_stat.toml`（json/kv 两路）

### 10) config_errors（配置错误场景）
- no_source/less_dvadm 两个子场景；用于校验 CLI 诊断输出与错误处理

---

## 命名建议（可按需逐步收敛）
- 业务组名：短小、语义明确，如 `/sink/simple`、`/sink/filter`、`/sink/benchmark`
- sink 名：描述输出内容或用途，如 `dat/json/kv`、`all/safe`、`primary/backup`、`adm/pdm`
- 已调整：`wpl_missing/sink/business.d/simple.toml` 统一为 `/sink/simple`，并为 sinks 增加 `dat/json/kv` 名称

## 常见问题
- filter 未生效：
  - 路径基于当前工作目录解析；确保 `filter.conf` 相对 `sink_root` 可访问
  - 表达式需能被 TCondParser 解析；可先用简单表达式烟囱测试
- Prometheus 未启动：
  - 未配置 Prometheus 连接器并将 `monitor` 组切换到该连接器时，不会有 `/metrics` 端点
- 覆盖参数失败：
  - `params` 的键必须在连接器 `allow_override` 白名单中

---

> 约定优于配置：尽量为每个 sink 显式给出 `name`，以获得稳定的 `full_name` 与更可读的校验报表；对过滤型用例，请把拦截条件放在 `filter.conf` 文件，便于复用与审阅。
