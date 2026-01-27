# 中断与恢复

本用例演示 sink 中断与恢复流程：当业务 sink 写入失败时，数据会落入 `rescue/` 目录；随后通过恢复流程（`wprescue daemon`）将救急文件回放到原目标 sink。

核心要点：
- 使用 `test_rescue` 作为业务 sink 的后端，周期性切换可用性（约每 2 秒一次）。
- 中断阶段产生的救急文件命名形如：`<sink_name>-YYYY-MM-DD_HH:MM:SS.dat.lock`；句柄释放时去掉 `.lock` 才可参与恢复。
- 恢复阶段扫描 `rescue/*.dat`（不含 `.lock`），按时间顺序取最新一个文件回放，并在成功后删除该文件。

## 目录结构（关键项）
- `usecase/core/sink_recovery/conf/wparse.toml`：工作目录、速率、日志、命令通道等基础配置（`rescue_root = "./data/rescue"`）。
- `usecase/core/sink_recovery/conf/wpsrc.toml`：文件源（v2）读取 `./data/in_dat/gen.dat`（默认）。
- `usecase/core/sink_recovery/sink/infra.d/`：基础组（default/miss/residue/intercept/error/monitor）。
- `usecase/core/sink_recovery/sink/business.d/benchmark.toml`：业务组 `benchmark`，目标 `test_rescue`，用于触发中断与救急文件。
- `usecase/core/sink_recovery/case_interrupt.sh`：中断阶段 e2e 脚本（生成数据 -> 启动解析 -> 观察 rescue）。
- `usecase/core/sink_recovery/case_recovery.sh`：恢复阶段 e2e 脚本（启动 `wprescue work` -> 回放 rescue -> 校验）。

## 快速开始

1) 中断阶段（生成救急文件）
- 进入用例目录并运行：
  ```bash
  usecase/core/sink_recovery/case_interrupt.sh
  ```
- 该脚本会：
  - 预构建并初始化配置；
  - 通过 `wpgen sample` 生成 10000 行样本到 `./data/in_dat/gen.dat`；
  - 启动 `wparse daemon`；`benchmark` 组使用 `test_rescue` 后端，周期性中断触发救急写入；
  - 结束时打印 `rescue/` 下的 `.dat` 文件及 `wproj stat file` 汇总。
- 期望：`rescue/` 目录出现至少一个 `benchmark_file_sink-*.dat` 文件。

2) 恢复阶段（回放救急文件）
- 在同一目录运行：
  ```bash
  usecase/core/sink_recovery/case_recovery.sh
  ```
- 该脚本会：
  - 启动 `wprescue daemon --stat 100` 进入恢复模式；
  - 等待片刻并发送 USR1 信号优雅结束；
  - 列出 `rescue/`、输出 `wproj stat file` 和一致性校验 `wproj validate sink-file -v`。
- 期望：
  - `rescue/` 中的 `.dat` 文件被消费并删除；
  - sinks v2 下对应文件计数增加（例如 `data/out_dat/benchmark.dat`、`data/out_dat/default.dat` 等）。

参考日志（`logs/wprescue.log`）：
```
recover begin
recover file: ./data/rescue/benchmark_file_sink-2025-10-04_01:59:24.dat
recover begin! file : ./data/rescue/benchmark_file_sink-2025-10-04_01:59:24.dat
recover end! clean file : ./data/rescue/benchmark_file_sink-2025-10-04_01:59:24.dat
recover end
```

## 运行原理
- 中断写入与救急文件
  - 业务 sink 后端为 `test_rescue`（见 `usecase/core/sink_recovery/sink/benchmark/sink.toml`），通过代理定时切换健康状态；
  - 写入失败时，`SinkRuntime` 切换到备份写出（rescue），创建 `rescue/<sink>-YYYY-MM-DD_HH:MM:SS.dat.lock`，释放句柄后重命名为 `.dat`；
  - 相关实现：
    - 备份切换：`src/sinks/runtime/manager.rs:120` 及 `use_back_sink/swap_back`；
    - 文件锁/解锁：`src/sinks/backends/file.rs`（`.lock` 后缀在 Drop/stop 时去除）。

- 恢复回放
  - `ActCovPicker` 周期扫描 `rescue/*.dat`，按名称中的时间排序取最新文件；
  - 由文件名前缀解析 sink 名称（`get_sink_name`），通过 `SinkRouteAgent.get_sink_agent` 找到对应 sink 通道；
  - 将每一行作为 `Raw` 数据发送到该 sink；数据库类后端（Mysql/ClickHouse/Elasticsearch）会走 `to_tdc`（当前为 TODO 示例）；
  - 成功读取完文件后删除 `.dat` 并更新检查点（断点记录 `rescue/recover.lock`）。
  - 相关实现：`src/services/collector/recovery/mod.rs`。

## 排错建议
- 统计为 0 或无数据写入：
  - 确认 `rescue/` 存在 `.dat`（非 `.lock`）文件；
  - 确认 `wprescue daemon` 的工作目录与用例一致（`conf/wparse.toml` 的 `rescue_root` 为 `./data/rescue`）;
  - 确认业务 sink 名称与救急文件前缀一致（`benchmark_file_sink-*.dat` 对应 `[[sink_group.sinks]].name = "benchmark_file_sink"`）;
  - 如需查看恢复流程细节，查看 `logs/wprescue.log` 中的 `recover` 关键字。

## 可调参数
- `conf/wparse.toml`：
  - `speed_limit` 控制恢复读取速率（每秒行数上限）。
  - `rescue_root` 控制救急目录。
- 脚本环境变量：
  - `LINE_CNT`、`STAT_SEC` 可通过导出覆盖（详见脚本中默认值）。

## 相关文件与命令
- 运行脚本：
  - `usecase/core/sink_recovery/case_interrupt.sh`
  - `usecase/core/sink_recovery/case_recovery.sh`
- 核心日志：`usecase/core/sink_recovery/logs/wprescue.log`
- 校验工具：
  - `wproj stat file` 统计 sinks 输出行数
  - `wproj validate sink-file -v` 校验期望配置/占比

## 测试完整性与健壮性建议

为保证恢复链路在不同环境、边界条件下稳定可用，建议补充如下用例与核验点：

- 场景覆盖
  - 多救急文件顺序回放：在 `rescue/` 下造多个 `<sink>-YYYY-MM-DD_HH:MM:SS.dat`，确认按时间排序仅回放最新一个，且文件成功删除。
  - `.lock` 与 `.dat` 共存：确认 `.lock` 被忽略，仅 `.dat` 参与恢复；强杀写入进程后残留 `.lock` 不影响恢复。
  - 空文件/空行：当前恢复读取逐行发送，建议保证救急文件无空行（与代码注释一致），并在工具侧对空行做显式跳过或报警。
  - 名称不匹配：当文件前缀与 sink 名称不一致时（`get_sink_name` 解析），应记录错误日志并跳过；建议添加该负例用例。

- 断点续传与幂等
  - 中途中止 `wprescue work`（如 `kill -USR1` 或 `SIGINT`），再次启动后应从 `rescue/recover.lock` 记录点续传，且已处理文件不重复回放。
  - 连续执行 `case_recovery.sh` 多次，目标 sink 的行数不应无限增长（不存在重复消费）。

- 性能与压力
  - 调整 `conf/wparse.toml` 的 `speed_limit`：分别测试低速（如 10）、高速（如 1e6）和默认值，观察吞吐、CPU、I/O。
  - 大文件恢复：准备 10^5～10^6 行救急文件，验证内存占用、指标发送与最终文件删除的及时性。

- 故障注入与恢复
  - `test_rescue` 阶段错位：拉长或缩短切换周期，观察备份切换与 `ActMaintainer` 重连行为是否符合预期（`warn_sink! reconnect` 日志）。
  - 目标 sink 短暂不可用：在恢复过程中手动切断写入（如文件权限只读/目录不可写），确认：失败记账、重试、最终回退策略符合鲁棒性策略（Throw/Tolerant/FixRetry 等）。

- 期望校验（expect）
- 在 `sink/defaults.toml` 的 `[defaults.expect]` 设置 `min_samples/sum_tol/others_max` 等参数，`wproj validate sink-file -v` 观察是否给出清晰证据（denom/ratio/lines）。
  - 在业务 `sink.toml` 对单个 sink 配置 `[[sinks]].expect`（如 `ratio/tol`），校验实际占比是否在容差内。

- 观测与日志
  - 将 `log_conf.level` 临时提升至 `debug`，grep 关键字 `recover begin|recover file|recover end|reconnect success`，形成问题定位基线。
  - 校验 monitor 指标是否随恢复进度变化（`SinkStat`/`pick_stat`）。

- 兼容性与路径
  - 确认 `rescue_root`、`sink_root`、`out/` 等目录在不同平台（Linux/macOS）下权限与路径分隔符无差异问题。
  - 业务 sink 名称与救急文件前缀严格一致（例如 `benchmark_file_sink`），避免路由失败。

- 后续改进点（建议）
  - `to_tdc`（数据库类后端的 TDC 转换）当前为 TODO，补齐实现后应新增单元/集成测试验证 SQL/批量写入逻辑。
  - 将 `test_rescue` 的阶段时长暴露为环境变量，便于在 CI 中构造确定性时序。
  - 在 CI 中串行执行 `case_interrupt.sh` → `case_recovery.sh`，并收集 `wprescue.log`、`wproj validate` 结果作为工件。
