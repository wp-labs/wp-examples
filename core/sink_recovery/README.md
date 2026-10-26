# Sink Recovery

演示 sink 写入失败后的**救援文件（rescue）链路**：写失败的数据落到本地救援文件，
sink 恢复后自动切回目标，救援文件再通过 `wprescue` 回放到原目标。

## 目的 / Purpose

验证以下行为：

| 行为 | 说明 |
| --- | --- |
| 故障切换 | 业务 sink 写失败时切换到救援文件，不丢数据 |
| 文件生命周期 | 故障中为 `<sink>-<时间>-<序号>.dat.lock`，故障结束后回收成 `.dat` |
| 一次故障一个文件 | 同一段故障复用同一个救援文件，不按批次刷文件 |
| 自动切回 | 维护线程重连成功后切回原 sink，之后的记录直投目标 |
| 回放 | `wprescue` 扫描 `.dat`，逐条发回原 sink，成功后删除文件 |
| 记录守恒 | `输入 = 业务 sink 落盘 + 救援文件 + 丢弃`，任何环节都不允许凭空消失 |

> 需要 wp-motor `v1.37.0` 及以上：`test_rescue` 的阶段表（`WP_TEST_RESCUE_STAGES`）和
> 扩展后的回放行为都在该版本引入。

## 运行 / Quick Start

```bash
cd core/sink_recovery

./case_interrupt.sh   # 阶段 1：制造故障，抢救急文件
./case_recovery.sh    # 阶段 2：回放救援文件
```

也可以 `./run.sh` 顺序执行两个阶段。

## 故障注入 / Fault Injection

业务 sink `benchmark` 使用内置的 `test_rescue` 后端，它按**阶段表**切换自身可用性：

```toml
# topology/sinks/business.d/benchmark.toml
connect = "file_rescue_sink"
params = { file = "benchmark.dat" }
```

阶段表由环境变量给出（`case_interrupt.sh` 里设置）：

```bash
# 健康 2s -> 故障 3s -> 之后视为健康（默认）
RESCUE_STAGES="up:2,down:3" ./case_interrupt.sh

# 两次故障窗口
RESCUE_STAGES="up:2,down:2,up:4,down:2" ./case_interrupt.sh

# 持续抖动
RESCUE_STAGES="up:2,down:2" WP_TEST_RESCUE_REPEAT=1 ./case_interrupt.sh
```

- 语法：逗号分隔的 `状态:秒数`，状态取 `up` / `down`；首个阶段立即生效。
- 阶段表耗尽后 sink 视为健康，因此中断阶段一定在**健康状态**下结束，救援文件都已回收成 `.dat`。
- 这是测试夹具的进程级开关，仅在 `test_rescue` 后端生效。

**恢复阶段必须让 sink 健康**：`case_recovery.sh` 设置 `RECOVERY_STAGES="up:3600"`。
如果回放时目标 sink 仍在故障中，失败的是"恢复"本身，用例会给出误导性结论。

## 时序 / Timeline

默认参数下（`LINE_CNT=12000`、`rate_limit_rps=1000`，即解析约 12s）：

```
t=0      healthy   -> 记录直投 data/out_dat/benchmark.dat
t=2      down      -> 写失败，切换到救援文件 .dat.lock
t=5      up        -> sink 端已恢复，但运行时仍停在救援文件
t≈7      reconnect -> 维护线程(失败后退避 5s)重连成功，切回原 sink
         finalized -> 救援文件回收成 .dat，后续记录继续直投
t=12     batch 结束，目录里留下 1 个 .dat
```

救援窗口不是"故障时长"，而是"故障开始到重连成功"，所以它被维护线程的 5s 重连节奏主导。

## 断言 / Assertions

`case_interrupt.sh`：

1. `data/logs/wparse.log` 出现 `on rescue`（发生了切换）；
2. 出现 `rescue file finalized`（故障结束后回收了救援文件）；
3. 目录里没有 `.dat.lock` 残留（阶段在健康状态下结束）；
4. `输入 = benchmark + example + infra + 救援文件行数`。

`case_recovery.sh`：

1. `data/logs/wprescue.log` 出现 `recover file:` 与 `recover end! clean file`（真的回放了）；
2. 没有 `recover send failed`（回放期间目标 sink 健康）；
3. `.dat` 全部被消费；
4. `输入 = benchmark + example + infra`，且 `benchmark` 拿到了自己那份的全部记录。

回放的两个约束：

- **回放到原 sink 组**：救援文件路径里带着 sink 全名（`<root>/sink/benchmark/[0]-...dat`），
  恢复器按「组 + 名」匹配目标；只按 sink 名匹配会把其它组的同名 sink（自动命名时都是 `[0]`）当成候选。
- **背压不算故障**：回放写入的是分发通道，通道满只代表消费端一时跟不上，
  恢复器会在同一个候选上等待重试，而不是切换候选把数据投到别的 sink。

## 目录结构与产物

```
conf/wparse.toml                     工作目录、限速、日志级别（data=info / dfx=info 才能看到救援生命周期日志）
topology/sources/file_1.toml         文件源：data/in_dat/gen.dat
topology/sinks/business.d/benchmark.toml   业务组，test_rescue 后端
models/wpl/benchmark/                解析规则
data/in_dat/gen.dat                  wpgen 生成的输入
data/out_dat/benchmark.dat           业务 sink 输出
data/rescue/sink/benchmark/*.dat     救援文件（恢复成功后删除）
data/logs/wparse.log, wprescue.log   关键证据都在这里
```

`rescue/recover.lock` 是 `wprescue` 的检查点文件，路径相对**当前工作目录**而不是
`[rescue] path`，中断阶段开始时会被清掉。

## 排错 / Troubleshooting

| 现象 | 排查方向 |
| --- | --- |
| 没有救援文件 | `RESCUE_STAGES` 是否真的包含 `down`；解析耗时是否覆盖了故障窗口（`LINE_CNT/rate_limit_rps`） |
| 救援文件还是 `.lock` | 中断阶段结束时 sink 仍在故障中：把阶段表末尾改成 `up:N`，或调大 `LINE_CNT` |
| `wprescue` 什么都没做 | 目录里没有 `.dat`；或文件名前缀与 sink 名不一致 |
| `recover send failed ... stg ctrl error` | 回放时目标 sink 处于故障窗口：恢复阶段要设置 `RECOVERY_STAGES="up:3600"` |
| 统计对不上 | 先看 `wpadm data stat`，再用脚本里的守恒断言定位是哪一段丢失 |
| `parse [admin_api] in ./wparse.local.toml failed` | 旧版本留下的本地覆盖层，脚本会在开始时删除；手工运行时自行 `rm ./wparse.local.toml` |

## 相关文件与命令

- 中断写入与救援切换：`wp-motor/src/sinks/runtime/manager.rs`（`swap_backsink` / `recover_sink` / `record_send_success`）
- 故障夹具：`wp-motor/src/sinks/decorators/test_proxy.rs`、`wp-motor/src/sinks/backends/test_rescue.rs`
- 回放：`wp-motor/src/runtime/collector/recovery/mod.rs`
- 人工校验：`wpadm data stat`（行数）、`wpadm data validate`（按 `expect` 配置给 `validate: PASS/FAIL`）
  - expect 口径：`/sink/benchmark` 收 `/sys/*` 两类记录（2/3），`/sink/example` 收一类（1/3，两个 sink 各拿全量）

## 已知限制

- 恢复器**不做断点续传**：每个文件都从头读取，`rescue/recover.lock` 只记录进度不用于 seek，
  因此中途失败后重跑会重复投递已发送的部分。
- 回放失败（目标 sink 持续不可用）会让整轮读取返回错误、文件保留，需要人工介入或等下一轮重试。
- 数据库类后端的 `to_tdc` 转换仍是 TODO，本用例只覆盖文件类 sink。
