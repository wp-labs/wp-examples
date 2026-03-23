# Syslog UDP Source Benchmarks

Performance benchmarks for Syslog over UDP data source scenarios.

## Purpose

Test Syslog UDP protocol reception and parsing performance with high-throughput transport.

## Test Scenarios

| Scenario | Description | Validated Features |
|----------|-------------|-------------------|
| parse_to_blackhole | Syslog UDP → Parse → Discard | Syslog UDP pure parsing throughput |
| trans_to_blackhole | Syslog UDP → Parse+Transform → Discard | Parsing + OML transformation performance |

## Quick Start

```bash
cd benchmark

# Parse to blackhole
./case_syslog_udp/parse_to_blackhole/run.sh

# Medium dataset
./case_syslog_udp/parse_to_blackhole/run.sh -m

# Custom configuration
./case_syslog_udp/trans_to_blackhole/run.sh -w 4 nginx 100000
```

## Data Flow

```
wpgen → Syslog UDP (port 1524) → wparse daemon → sink (blackhole)
```

## Configuration

- **Default Port**: 1524
- **Default Workers**: 6
- **Protocol**: Syslog over UDP (high-throughput, best-effort)

---

# Syslog UDP 源基准测试 (中文)

基于 Syslog UDP 数据源的性能基准测试。

## 用途

测试 Syslog UDP 协议接收和解析性能，使用高吞吐量传输。

## 测试场景

| 场景 | 说明 | 验证特性 |
|------|------|----------|
| parse_to_blackhole | Syslog UDP → 解析 → 丢弃 | Syslog UDP 纯解析吞吐量 |
| trans_to_blackhole | Syslog UDP → 解析+转换 → 丢弃 | 解析 + OML 转换性能 |

## 快速开始

```bash
cd benchmark

# 解析到黑洞
./case_syslog_udp/parse_to_blackhole/run.sh

# 中等规模数据集
./case_syslog_udp/parse_to_blackhole/run.sh -m

# 自定义配置
./case_syslog_udp/trans_to_blackhole/run.sh -w 4 nginx 100000
```

## 数据流向

```
wpgen → Syslog UDP (端口 1524) → wparse daemon → sink (黑洞)
```

## 配置说明

- **默认端口**: 1524
- **默认 Worker**: 6
- **协议**: Syslog over UDP（高吞吐量，尽力交付）
