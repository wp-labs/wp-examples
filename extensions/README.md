# Extension Connectors

This directory contains extension connector examples demonstrating WarpParse integration with various external systems (databases, message queues, log storage, monitoring).

## Case List

| Case | Purpose | Validated Features |
|------|---------|-------------------|
| **doris** | File Source → Doris Stream Load pipeline | Doris sink, Stream Load, batch processing |
| **kafka** | Kafka Source/Sink integration | Kafka consumer/producer, topic routing |
| **practice** | Real-world multi-source monitoring scenario | Multi-source collection, Fluent-bit, Kafka, VictoriaLogs, Grafana |
| **tcp_mysql** | TCP Source → MySQL Sink pipeline | TCP source, MySQL sink, data persistence |
| **tcp_victorialogs** | TCP Source → VictoriaLogs Sink pipeline | TCP source, VictoriaLogs sink, log storage |
| **victoriametrics** | Internal metrics push to VictoriaMetrics | VictoriaMetrics sink, metrics export, monitoring |

## Common Structure

```
case_name/
├── conf/
│   ├── wparse.toml          # Engine configuration
│   └── wpgen.toml           # Data generator configuration
├── topology/
│   ├── sources/             # Source definitions
│   └── sinks/               # Sink definitions
├── models/
│   ├── wpl/                 # WPL parsing rules
│   └── oml/                 # OML transformation models
├── data/                    # Runtime data
├── docker-compose.yml       # Container orchestration
└── run.sh                   # Execution script
```

## Quick Start

```bash
# Enter case directory
cd extensions/<case_name>

# Start dependent services
docker compose up -d

# Run the case
./run.sh
```

---

# 扩展连接器 (中文)

本目录包含扩展连接器示例，演示 WarpParse 与各种外部系统（数据库、消息队列、日志存储、监控）的集成。

## 用例清单

| 用例 | 目的 | 验证特性 |
|------|------|----------|
| **doris** | 文件源 → Doris Stream Load 管道 | Doris sink、Stream Load、批处理 |
| **kafka** | Kafka 源/汇集成 | Kafka 消费者/生产者、topic 路由 |
| **practice** | 实战多源监控场景 | 多源采集、Fluent-bit、Kafka、VictoriaLogs、Grafana |
| **tcp_mysql** | TCP 源 → MySQL Sink 管道 | TCP 源、MySQL sink、数据持久化 |
| **tcp_victorialogs** | TCP 源 → VictoriaLogs Sink 管道 | TCP 源、VictoriaLogs sink、日志存储 |
| **victoriametrics** | 内部指标推送到 VictoriaMetrics | VictoriaMetrics sink、指标导出、监控 |

## 通用结构

```
case_name/
├── conf/
│   ├── wparse.toml          # 引擎配置
│   └── wpgen.toml           # 数据生成器配置
├── topology/
│   ├── sources/             # 源定义
│   └── sinks/               # 汇定义
├── models/
│   ├── wpl/                 # WPL 解析规则
│   └── oml/                 # OML 转换模型
├── data/                    # 运行时数据
├── docker-compose.yml       # 容器编排
└── run.sh                   # 执行脚本
```

## 快速开始

```bash
# 进入用例目录
cd extensions/<case_name>

# 启动依赖服务
docker compose up -d

# 运行用例
./run.sh
```
