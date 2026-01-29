# TCP Source Benchmarks

Performance benchmarks for TCP-based data source scenarios using daemon mode.

## Purpose

Test TCP network reception and parsing performance with reliable transport.

## Test Scenarios

| Scenario | Description | Validated Features |
|----------|-------------|-------------------|
| parse_to_blackhole | TCP → Parse → Discard | TCP reception + pure parsing throughput |
| parse_to_file | TCP → Parse → File | Complete TCP-to-file parsing pipeline |
| trans_to_blackhole | TCP → Parse+Transform → Discard | Parsing + OML transformation throughput |
| trans_to_file | TCP → Parse+Transform → File | Complete transformation pipeline |

## Quick Start

```bash
cd benchmark

# Parse to blackhole (default: 20M lines, 6 workers)
./case_tcp/parse_to_blackhole/run.sh

# Medium dataset (200K lines)
./case_tcp/parse_to_blackhole/run.sh -m

# Custom configuration
./case_tcp/parse_to_file/run.sh -w 8 sysmon 500000
```

## Data Flow

```
wpgen → TCP (port 19001) → wparse daemon → sink (blackhole/file)
```

## Configuration

- **Default Port**: 19001
- **Default Workers**: 6
- **Protocol**: TCP (reliable transport)

---

# TCP 源基准测试 (中文)

基于 TCP 数据源的性能基准测试，使用 daemon 模式。

## 用途

测试 TCP 网络接收和解析性能，使用可靠传输。

## 测试场景

| 场景 | 说明 | 验证特性 |
|------|------|----------|
| parse_to_blackhole | TCP → 解析 → 丢弃 | TCP 接收 + 纯解析吞吐量 |
| parse_to_file | TCP → 解析 → 文件 | 完整 TCP 到文件解析管道 |
| trans_to_blackhole | TCP → 解析+转换 → 丢弃 | 解析 + OML 转换吞吐量 |
| trans_to_file | TCP → 解析+转换 → 文件 | 完整转换管道 |

## 快速开始

```bash
cd benchmark

# 解析到黑洞（默认：2000 万行，6 个 worker）
./case_tcp/parse_to_blackhole/run.sh

# 中等规模数据集（20 万行）
./case_tcp/parse_to_blackhole/run.sh -m

# 自定义配置
./case_tcp/parse_to_file/run.sh -w 8 sysmon 500000
```

## 数据流向

```
wpgen → TCP (端口 19001) → wparse daemon → sink (黑洞/文件)
```

## 配置说明

- **默认端口**: 19001
- **默认 Worker**: 6
- **协议**: TCP（可靠传输）
