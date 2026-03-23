# Syslog TCP Source Benchmarks

Performance benchmarks for Syslog over TCP data source scenarios.

## Purpose

Test Syslog TCP protocol reception and parsing performance with reliable transport.

## Test Scenarios

| Scenario | Description | Validated Features |
|----------|-------------|-------------------|
| parse_to_blackhole | Syslog TCP → Parse → Discard | Syslog TCP pure parsing throughput |
| trans_to_blackhole | Syslog TCP → Parse+Transform → Discard | Parsing + OML transformation performance |

## Quick Start

```bash
cd benchmark

# Parse to blackhole
./case_syslog_tcp/parse_to_blackhole/run.sh

# Medium dataset
./case_syslog_tcp/parse_to_blackhole/run.sh -m

# Custom configuration
./case_syslog_tcp/trans_to_blackhole/run.sh -w 4 nginx 100000
```

## Data Flow

```
wpgen → Syslog TCP (port 1514) → wparse daemon → sink (blackhole)
```

## Configuration

- **Default Port**: 1514
- **Default Workers**: 6
- **Protocol**: Syslog over TCP (reliable transport)

---

# Syslog TCP 源基准测试 (中文)

基于 Syslog TCP 数据源的性能基准测试。

## 用途

测试 Syslog TCP 协议接收和解析性能，使用可靠传输。

## 测试场景

| 场景 | 说明 | 验证特性 |
|------|------|----------|
| parse_to_blackhole | Syslog TCP → 解析 → 丢弃 | Syslog TCP 纯解析吞吐量 |
| trans_to_blackhole | Syslog TCP → 解析+转换 → 丢弃 | 解析 + OML 转换性能 |

## 快速开始

```bash
cd benchmark

# 解析到黑洞
./case_syslog_tcp/parse_to_blackhole/run.sh

# 中等规模数据集
./case_syslog_tcp/parse_to_blackhole/run.sh -m

# 自定义配置
./case_syslog_tcp/trans_to_blackhole/run.sh -w 4 nginx 100000
```

## 数据流向

```
wpgen → Syslog TCP (端口 1514) → wparse daemon → sink (黑洞)
```

## 配置说明

- **默认端口**: 1514
- **默认 Worker**: 6
- **协议**: Syslog over TCP（可靠传输）
