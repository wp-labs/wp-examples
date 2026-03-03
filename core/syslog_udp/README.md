# Syslog UDP

This example demonstrates UDP Syslog source integration for receiving and processing syslog messages.

## Purpose

Validate the ability to:
- Receive syslog messages via UDP protocol
- Parse syslog format data with WPL rules
- Route parsed data to configured sinks

## Features Validated

| Feature | Description |
|---------|-------------|
| UDP Source | Receiving data via UDP syslog protocol |
| Syslog Parsing | Parsing RFC-compliant syslog messages |
| Real-time Processing | Daemon mode for continuous reception |
| Data Routing | Routing to business and infrastructure sinks |

## Quick Start

```bash
cd core/syslog_udp
./run.sh
```

## Steps

1. Start the parser (daemon mode)
```bash
wparse daemon --stat 5
```

2. Generate and send syslog data
```bash
wpgen sample -n 10000 --stat 5
```

3. Stop and validate
```bash
wproj data stat
wproj validate sink-file -v --input-cnt 10000
```

## Key Files

- `conf/wparse.toml`: Main configuration
- `models/sources/wpsrc.toml`: UDP syslog source configuration
- `conf/wpgen.toml`: Generator config (UDP syslog output)

---

# Syslog UDP (中文)

本用例演示 UDP Syslog 源集成场景，用于接收和处理 syslog 消息。

## 目标

验证以下能力：
- 通过 UDP 协议接收 syslog 消息
- 使用 WPL 规则解析 syslog 格式数据
- 将解析后的数据路由到配置的 sink
