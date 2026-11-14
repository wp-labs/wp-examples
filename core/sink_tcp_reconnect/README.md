# Sink TCP/TLS Reconnect

验证 **接收端重启后，发送端（wparse）不重启也能自动恢复投递**（回归 `warp-parse#374`）。

## 目的 / Purpose

| 行为 | 说明 |
| --- | --- |
| 断链自愈 | `tcp` sink 写失败后按退避自动重建连接（TLS 场景包含完整握手） |
| 发送端不重启 | 接收端恢复后，同一个 `wparse` 进程继续投递 |
| 修复前后对比 | 修复前：旧 socket 持续报错，`dropped` 增长，只能重启 `wparse`；修复后：熔断探测批次即可重连成功 |
| drop 语义不变 | `drop_when_error = true` 下故障窗口内仍丢弃并计数，不产生救援文件 |
| 记录守恒 | `输入 = 已投递 + 实际丢失`；`dropped` 是批级计数，可能略大于实际丢失 |

## 用例结构 / Layout

```text
sink_tcp_reconnect/
├── receiver.py                     # 可重启的 TCP/TLS 接收端（python3 标准库）
├── run.sh                          # 启动/杀停接收端、跑 wparse、做断言
├── conf/wparse.toml                # rate_limit_rps=2000，日志级别 info
├── topology/sink_profiles/
│   ├── tcp.toml                    # tcp_sink -> 127.0.0.1:19100
│   └── tls.toml                    # tcp_sink + tls(insecure) -> 127.0.0.1:19101
├── topology/sinks/business.d/benchmark.toml   # 默认使用 tcp profile（run.sh 会在两轮间切换）
└── ...                             # 直接复用 sink_drop_when_error 的模型与其它 sink
```

`/sink/benchmark` 组（`oml = ["sys"]`）走 TCP/TLS sink；`/sink/example` 仍写文件，用来验证**同组其它 sink 不受影响**。

## 运行 / Quick Start

```bash
cd core/sink_tcp_reconnect
./run.sh                    # 默认 tcp + tls 两轮
PROTOCOL=tcp ./run.sh       # 只跑明文 TCP
PROTOCOL=tls ./run.sh       # 只跑 TLS（需要 openssl）
```

依赖：`wparse` / `wpgen` / `wpadm`（已在 PATH）、`python3`、`openssl`（TLS 轮次）、`lsof`（可选，用于清理端口）。

## 流程 / How it works

1. `wpgen sample` 生成 40000 行输入（`rate_limit_rps=2000`，约 20s）。
2. 启动 `receiver.py` 监听端口，`wparse batch` 后台开始发送。
3. 3s 后 **SIGTERM 杀掉接收端**，旧连接进入 `tcp send error`；`drop_when_error` 打开熔断。
4. 停机 3s 后 **在同一端口重新拉起接收端**。
5. 断言：
   - 接收端第一阶段（故障前）有数据；
   - 接收端第二阶段（恢复后）有数据 —— 这是“无需重启发送端”的直接证据；
   - `wparse.log` 出现 `tcp sink reconnected`（connector 重建链路）与 `recovered from send failures`（熔断复位）；
   - `drop_when_error` 期间有丢弃计数，且 `data/rescue` 为空；
   - 记录守恒：`输入 = example.dat + 接收端两阶段 + infra + 实际丢失`；`dropped` 是批级计数，可能略大于实际丢失（失败批次里已写入的记录也会被计入）；
   - `wparse` 进程在停机窗口内保持存活（`kill -0` 检查）。

## 调参 / Tuning

| 参数 | 说明 |
| --- | --- |
| `LINE_CNT` | 输入行数，默认 40000（≈20s） |
| `OUTAGE_SECS` | 接收端停机时长，默认 3s |
| `TCP_PORT` / `TLS_PORT` | 接收端端口，默认 19100 / 19101 |
| `PROTOCOL` | `tcp` / `tls` / `both` |

> 停机时长需要覆盖一次真实写失败并小于熔断上限；3s 可在默认 `rate_limit_rps=2000` 下稳定复现"熔断跳过 → 探测重连成功"。

## 期望输出 / Expected

```text
check(tcp): input=40000 phase1=... phase2=... example=... infra=... dropped=... rescue=0
check(tls): input=40000 phase1=... phase2=... example=... infra=... dropped=... rescue=0
OK: TCP/TLS sink reconnects after receiver restart without restarting wparse (protocol=both)
```

需要 `wp-motor >= v1.39.1`（`wp-core-connectors >= 0.11.5`）：connector 自身具备退避重连能力。
