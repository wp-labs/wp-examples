# Benchmark 用例指南

benchmark 目录收录了倚赖 `benchmark/benchmark_common.sh` 的性能用例。每个子目录提供一个 `run.sh` 脚本，对应不同数据源/场景。本文档说明整体流程、通用参数与各脚本的用途。

## 前置准备
1. 注意：命令行工具 `wproj` 已更新为当前名称（旧版本若仍使用其它别名，可通过符号链接映射到 `wproj`）。
2. 请提前在 `warp-parse` 仓库执行 `cargo build-apps --release`，并将生成的二进制（如 `wparse`/`wpgen`/`wproj`）复制或链接到 `${HOME}/bin` 等 PATH 可访问的位置。
3. 所有脚本默认在 release profile 下运行，并依赖 `wparse`/`wpgen`/`wproj`，确保它们位于 PATH 中。
4. 从 `benchmark` 目录内运行脚本，示例命令：`cd usecase/benchmark && ./tcp_blackhole/run.sh`。

## 通用选项
多数用例共享下列参数（由 `benchmark_parse_args` 解析）：
- `-m`：使用中等规模（200k 行）；默认生成 2000 万行。
- `-f`：强制重建输入数据，即使 `./data/in_dat/*.dat` 已存在。
- `-w <cnt>`：指定 wparse worker 数。若未设置，batch/blackhole 默认 10 worker，daemon 默认 6 worker。
- `wpl_dir`：传入 `nginx` / `sysmon` 等子目录名，决定使用的规则集，默认 `nginx`。
- `speed`：样本生成限速（行/秒），0 表示不限速。

执行 `./xxx/run.sh -h` 可查看某脚本支持的选项组合。

## 用例清单
| 脚本 | 介绍 |
| --- | --- |
| `tcp_blackhole/run.sh` | tcp -> blackhole  组合场景，默认向 `benchmark_run_daemon` 传入两个配置（`wpgen.toml`/`wpgen2.toml`）模拟双路源；如需单路源仅保留一份配置即可。|
| `syslog_blackhole/run.sh` | 与 tcp_blackhole 类似，但专注 syslog 源。|
| `file_blackhole/run.sh` | 双 `wpgen` 配置（`wpgen.toml`/`wpgen1.toml`），验证 file→file pipeline 的 batch 模式。|
| `file_file/run.sh` | 单源 file→file batch，用于较大数据集压测。|
| `wpls_test/run.sh` | 主要用于 wparse 多 worker scaling；默认依序以 2/4/6 worker 运行，可通过 `-w` 固定为某个并发。|
| `wpgen_test/run.sh` | 压测 `wpgen` 的样本生成能力（仅生成数据，不启动 wparse）；仍接受 `-w` 以保持接口一致。|

## 快速示例
```bash
# 以 12 个 worker + sysmon 规则运行 TCP blackhole，限速 1M 行/秒
./tcp_blackhole/run.sh -w 12 sysmon 1000000

# 强制重建数据，使用 medium 模式，跑 file→file batch 基准
./file_file/run.sh -mf

# 只生成 nginx + benchmark 两套 8M 样本
./wpgen_test/run.sh

# 观察不同并发的 wparse 批处理表现
./wpls_test/run.sh -w 8   # 只跑 8 worker
./wpls_test/run.sh        # 依次跑 2/4/6 worker
```

## 输出与校验
每个脚本会自动调用 `wproj stat file` 与 `wproj validate sink-file`（仅限 wparse 路径）来打印吞吐与校验结果；若需要追加自定义参数，可直接在 `benchmark_run_batch` / `benchmark_run_daemon` 调用处添加。

若遇到数据残留导致统计不准，可手动执行 `wproj data clean` / `wpgen data clean`，或使用 `-f` 强制清理。
