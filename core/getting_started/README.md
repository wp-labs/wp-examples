# use_init 场景说明

本用例用于“快速初始化 + 基准验证”。包含最小的源文件、基础的 sinks v2 组（default/miss/residue/intercept/error/monitor）以及示例业务路由（如有）。可用于本地开发自检、CI 冒烟与文档演示。

## 目录结构
- `conf/`：配置目录
  - `conf/wparse.toml`：主配置（目录、日志、并行等）
- `models/sources/wpsrc.toml`：源配置（v2：`[[sources]] + connect/params`）
- `connectors/source.d/`：源连接器（file/syslog/kafka 等）
- `models/`：规则与路由
  - `models/wpl/`、`models/oml/`
  - `models/sinks/business.d` 与 `models/sinks/infra.d`：sinks v2 路由与基础组
  - `models/sinks/defaults.toml`：默认期望（组级）
- `data/`：运行数据目录（初始化后创建）
  - `data/in_dat/`：输入数据（`wpgen sample` 输出）
  - `data/out_dat/`：sink 输出
  - `rescue/`：救急目录
  - `logs/`：日志目录
- `usecase/core/getting_started/case_verify.sh`：用例校验脚本（端到端）

## 默认期望（defaults.expect）
在 `models/sinks/defaults.toml` 中设置全局默认组级期望：

```toml
[defaults.expect]
basis = "total_input"   # 以总输入作为分母校验比例
min_samples = 100        # 组级最小样本数
mode = "warn"            # 提示级别（warn/error/panic）
```

- 固定组（default/miss/residue/intercept/error/monitor）若未显式设置组级 expect，将继承 `defaults.expect`。
- 每个 sink 的单项约束在 `[group.sinks.expect]` 下配置（示例：`min/max/ratio±tol`）。
- 业务路由可在 `models/sinks/business.d/*.toml` 内按需声明组级 expect 覆盖默认。

## 快速使用
在仓库根目录构建：

```bash
cargo build --workspace --all-features
```

统计源与 sink（在用例目录）：

```bash
cd usecase/core/getting_started
../../../target/debug/wproj stat file          # 文本
../../../target/debug/wproj stat file --json   # JSON
```

仅统计其中一类：

```bash
# 文件源
../../../target/debug/wproj stat src-file --json
# 文件型 sink
../../../target/debug/wproj stat sink-file --json
```

离线校验（基于 expect）：

```bash
# 文本（打印 PASS/FAIL 与提示）
../../../target/debug/wproj validate sink-file
# JSON（pass + issues）
../../../target/debug/wproj validate sink-file --json
```

提示信息（WARN）：
- 当组级分母为 0（无样本）或小于 `min_samples` 时，校验会忽略该组，但打印 WARN 提示；仅 `ERROR/PANIC` 会导致 FAIL。

## 端到端脚本
如需端到端快速校验，可运行：

```bash
./case_verify.sh
```

脚本会执行构建、统计与校验，适合在 CI 中冒烟；若你不需要执行，可只参考上面的单条命令。

## 文档与常见问题
- 文档导航：`docs/README.md`
- 快速入门：`docs/getting-started/quickstart.md`
- sinks v2 最小骨架：`docs/sinks-v2-minimal.md`

- 常见问题
- 统计为空：确认 `models/sources/wpsrc.toml` 是否存在且有启用项，并与 `connectors/source.d` 中的连接器匹配；默认路径指向 `./data/in_dat/` 下的样本。
- 路径显示 `././...`：为兼容不同工作目录的解析，不影响统计与校验。
- 需要更严格/放宽的期望：
  - 组级：在对应组下添加/覆盖 `[group.expect]` 覆盖 defaults。
  - 单项：在 `[group.sinks.expect]` 设置 `min/max` 或 `ratio±tol`。

提示：为保证离线用例能够自动退出，`models/sources/wpsrc.toml` 中的 `demo_syslog` 默认 `enable = false`。若需要测试 UDP syslog，请启用后自行向 `127.0.0.1:1514` 发送样本；或在运行脚本时使用更小的停止检测周期 `-S 1`（脚本已内置），以避免长时间等待。
