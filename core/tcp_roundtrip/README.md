# TCP Roundtrip

This example demonstrates TCP input/output end-to-end data flow.

## Purpose

Validate the ability to:
- Push data via TCP sink from generator
- Receive data via TCP source in parser
- Process and output to file sinks
- Verify data integrity through the TCP pipeline

## Features Validated

| Feature | Description |
|---------|-------------|
| TCP Sink | Pushing data to TCP endpoint |
| TCP Source | Receiving data from TCP port |
| End-to-End Flow | Complete data path validation |
| Data Integrity | Input/output count verification |

## Quick Start

```bash
cd core/tcp_roundtrip
./run.sh
```

## Steps

1. Start the parser
```bash
wparse daemon --stat 5
```

2. Generate data (push to TCP)
```bash
wpgen sample -n 10000 --stat 5
```

3. Stop and validate
```bash
wproj stat sink-file
wproj validate sink-file -v --input-cnt 10000
```

---

# TCP Roundtrip (中文)

目标：演示通用 TCP 输入/输出的端到端链路。

- wpgen：通过 `connect = "tcp_sink"` 将样本数据推送到本机端口
- wparse：启用 `tcp_src` 源监听同一端口，落地到文件 sink

步骤
1) 启动解析器
```
wparse deamon --stat 5
```
2) 生成数据（推送到 TCP）
```
wpgen sample -n 10000 --stat 5
```
3) 停止解析器并校验
```
wproj stat sink-file
wproj validate sink-file -v --input-cnt 10000
```

关键文件
- conf/wparse.toml：主配置（sources/sinks/model 路径）
- models/sources/wpsrc.toml：source 列表（包含 `tcp_src`）
- conf/wpgen.toml：生成器配置（输出 `tcp_sink` 到本机端口）
