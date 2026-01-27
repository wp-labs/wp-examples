# sink_filter

本用例演示“按 sink 过滤/分流”的场景：依据业务规则将输入样本分发到不同的 sink 路径（all/safe/residue 等），并通过 defaults.expect 与单项 expect 对输出比例进行离线校验。适用于验证过滤逻辑正确性、残留/错误路径占比是否符合预期。

## 目录结构
- `conf/`：`wparse.toml`（主配置）、`wpsrc.toml`（v2 源配置）
- `connectors/source.d/`：文件源连接器（可按需添加更多）
- `sink/`（作为 `sink_root`）
  - `infra.d/`：基础组（default/miss/residue/intercept/error/monitor）
  - `business.d/`：过滤型业务组路由（示例：`filter/*.toml`）
  - `defaults.toml`：默认期望 `[defaults.expect]`
- `wpl/`、`oml/`：规则与对象模型
- `data/`：运行输出（`data/out_dat/`、`data/logs/` 等；初始化后生成）
- `case_verify.sh`：端到端校验脚本

## 默认期望（defaults.expect）
在 `sink/defaults.toml` 中设置默认组级期望（示例）：

```toml
[defaults.expect]
basis = "total_input"  # 以总输入作为分母校验比例
min_samples = 1
mode = "warn"
```

- 固定组（default/miss/residue/intercept/error）与 `monitor` 组若未显式设置 `[group.expect]`，会继承该默认值。
- 若某个组需要自定义期望，可在该组下声明 `[group.expect]` 覆盖默认。
- 每个 sink 的单项约束在 `[group.sinks.expect]` 下配置：
  - 目标区间：`ratio + tol`（表示 `ratio±tol`）
  - 上下限：`min/max`

## 过滤型业务组（示例）
- 业务组定义：`sink/filter/sink.toml`
- 过滤规则：`sink/filter/filter.conf`（命中条件）
- 常见做法：
  - 主路径 sink（例如 `all.dat`）不设置 ratio，仅设置其他路径的上限 `max` 或设置 `sum_tol` 控制多个 ratio 的和
  - 安全路径 sink（例如 `safe.dat`）设置较高的 `min`，确保大部分样本进入安全路径
  - 错误/残留路径设置 `max`，避免过高比例

## 快速使用
在仓库根目录构建：

```bash
cargo build --workspace --all-features
```

在用例目录统计/校验：

```bash
cd usecase/core/sink_filter
# 统计源与 sink（文本/JSON）
../../../target/debug/wproj stat file
../../../target/debug/wproj stat file --json

# 离线校验（文本/JSON）
../../../target/debug/wproj validate sink-file
../../../target/debug/wproj validate sink-file --json
```

## 校验提示策略（WARN）
- 当组级分母为 0（无样本）或小于 `min_samples` 时，校验会忽略该组，但打印 WARN 提示；仅 `ERROR/PANIC` 会导致 FAIL。


## 端到端脚本（可选）
如需完整跑一遍生成/过滤/校验流程，可执行：

```bash
./case_verify.sh
```

脚本会执行构建、生成样本、启动服务与校验。若你只需要离线校验与统计，可以直接使用 `wproj stat/validate`。

---
建议：新增业务组时，统一在 `sink/defaults.toml` 维护 `[defaults.expect]`，各组仅在确需与默认不同的场景下覆盖组级 expect；对单个 sink 的比例约束，请放在 `[group.sinks.expect]` 下设置。
