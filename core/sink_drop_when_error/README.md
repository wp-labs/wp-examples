# Sink Drop When Error

演示 per-sink 的**丢弃策略**：`drop_when_error = true` 时，sink 写失败不走救援文件，
而是丢弃当前记录，并靠**熔断**避免在坏链路期间反复撞 sink。

## 目的 / Purpose

验证以下行为：

| 行为 | 说明 |
| --- | --- |
| 不产生救援文件 | `drop_when_error` 与 rescue 机制互斥，`data/rescue` 必须保持为空 |
| 熔断不重试 | 一次失败后熔断打开（冷却 5s，连续失败翻倍，上限 60s），期间只记账不下发 |
| 到期探测 | 冷却到期放行一个探测批次；成功就自动复位，失败则退避加倍 |
| 自动恢复 | 链路恢复后无需人工干预，后续记录继续投递 |
| 记录守恒 | `输入 = 业务 sink 落盘 + 丢弃数`，丢弃是显式记账而不是静默丢失 |

## 配置 / Configuration

`topology/sinks/business.d/benchmark.toml`：

```toml
[[sink_group.sinks]]
connect = "file_rescue_sink"
params = { file = "benchmark.dat" }
drop_when_error = true      # 默认 false：失败时切换救援文件
```

`drop_when_error` 是**布尔**开关，作用域是单个 sink 实例，同组其它 sink 不受影响。

> 需要 wp-motor `v1.37.0` 及以上：`test_rescue` 的阶段表（`WP_TEST_RESCUE_STAGES`）在该版本引入。

## 运行 / Quick Start

```bash
cd core/sink_drop_when_error
./run.sh
```

耗时约 8-10 秒（16000 行 / `rate_limit_rps=2000`）。

## 故障注入 / Fault Injection

业务 sink 使用内置的 `test_rescue` 后端，它按**阶段表**切换自身可用性。
阶段表通过环境变量传入，默认值见 `run.sh`：

```bash
# 健康 1s -> 故障 4s -> 之后视为健康
WP_TEST_RESCUE_STAGES="up:1,down:4" ./run.sh

# 反复抖动：up:2 与 down:2 循环
WP_TEST_RESCUE_STAGES="up:2,down:2" WP_TEST_RESCUE_REPEAT=1 ./run.sh
```

- 语法：逗号分隔的 `状态:秒数`，状态取 `up` / `down`；首个阶段立即生效。
- 阶段表耗尽后 sink 视为健康（避免最后一个阶段是故障导致永久不可用）。
- 这是**测试夹具**的进程级开关，仅在 `test_rescue` 后端生效。

## 期望输出 / Expected Result

`run.sh` 会校验：

1. `data/rescue` 下没有任何救援文件；
2. `data/logs/wparse.log` 中出现 `breaker open, skipped ...`（坏链路期间没有反复下发）；
3. `data/logs/wparse.log` 中出现 `recovered from send failures (drop_when_error): dropped N record(s)`；
4. `输入 = benchmark + example + 丢弃数`。

> 本用例刻意不配 `expect`、也不跑 `wpadm data validate`：既然要丢数据，固定比例必然不成立。
> “分到对的组”这一层由 `core/sink_recovery` 的 `validate: PASS` 负责。

典型日志（一次故障窗口三条）：

```
# 1) 第一次真实写失败
WARN  sink '/sink/benchmark/[0]' drop_when_error: dropped 256 record(s), total 256, last_error=stg ctrl error
# 2) 熔断打开：后续批次不再调用 connector，只记账（每个故障期一条）
WARN  sink '/sink/benchmark/[0]' drop_when_error: breaker open, skipped 256 record(s), total 512, last_error=stg ctrl error
# 3) 冷却到期、探测成功后自动复位，汇总本故障期丢弃总数
WARN  sink '/sink/benchmark/[0]' recovered from send failures (drop_when_error): dropped 6827 record(s) since 2026-10-26 22:46:15
```

统计侧另有每窗口一行（target `ctrl`）：`sink '...' dropped: window=4267 total=6827 ...`，
以及监控表里的 `sink_dropped_total`（`data/out_dat/monitor.dat`）。

## 与 rescue 模式的区别

| | `drop_when_error = false`（默认） | `drop_when_error = true` |
| --- | --- | --- |
| 失败时 | 切换到救援文件，数据落盘 | 丢弃当前记录 |
| 数据 | 可恢复（`wprescue` 回放） | 不恢复，但显式计数 |
| 坏链路成本 | 每批都要尝试连接/切换 | 熔断期间零尝试 |
| 适用场景 | 要求不丢数据 | 允许丢弃、但要求不拖垮整条链路 |

如果既要"不丢"又要"坏链路不空转"，用默认模式（失败即切救援文件，冻结的 sink 由维护线程按 5s 节奏重连）。

## 调参 / Tuning

| 参数 | 位置 | 说明 |
| --- | --- | --- |
| `LINE_CNT` | `run.sh` 环境变量 | 输入行数，默认 16000 |
| `rate_limit_rps` | `conf/wparse.toml` | 解析速率上限，默认 2000 |
| `RESCUE_STAGES` | `run.sh` 环境变量 | 故障阶段表 |
| 熔断冷却 | 编译期常量 | `HEALTH_BACKOFF_BASE=5s`，`HEALTH_BACKOFF_MAX=60s` |

> 注意：冷却起点固定 5s。如果故障周期也接近 5s，探测批次可能反复落在故障窗口里，
> 退避会按 5s → 10s → 20s → 40s → 60s 增长。构造用例时让故障窗口与 5s 错开更直观。
