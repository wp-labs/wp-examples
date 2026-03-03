# File Source Benchmarks

Performance benchmarks for file-based data source scenarios using batch processing mode.

## Purpose

Test file I/O and parsing performance with pre-generated data files.

## Test Scenarios

| Scenario | Description | Validated Features |
|----------|-------------|-------------------|
| parse_to_blackhole | File → Parse → Discard | File reading + pure parsing throughput |
| parse_to_file | File → Parse → File | Complete file-to-file parsing pipeline |
| trans_to_blackhole | File → Parse+Transform → Discard | Parsing + OML transformation throughput |
| trans_to_file | File → Parse+Transform → File | Complete transformation pipeline |

## Quick Start

```bash
cd benchmark

# Parse to blackhole (default: 20M lines, 6 workers)
./case_file/parse_to_blackhole/run.sh

# Medium dataset (200K lines)
./case_file/parse_to_blackhole/run.sh -m

# Custom configuration
./case_file/parse_to_file/run.sh -w 8 nginx
```

## Data Flow

```
wpgen → gen.dat → wparse batch → sink (blackhole/file)
```

---

# 文件源基准测试 (中文)

基于文件数据源的性能基准测试，使用批处理模式。

## 用途

测试文件 I/O 和解析性能，使用预生成的数据文件。

## 测试场景

| 场景 | 说明 | 验证特性 |
|------|------|----------|
| parse_to_blackhole | 文件 → 解析 → 丢弃 | 文件读取 + 纯解析吞吐量 |
| parse_to_file | 文件 → 解析 → 文件 | 完整文件到文件解析管道 |
| trans_to_blackhole | 文件 → 解析+转换 → 丢弃 | 解析 + OML 转换吞吐量 |
| trans_to_file | 文件 → 解析+转换 → 文件 | 完整转换管道 |

## 快速开始

```bash
cd benchmark

# 解析到黑洞（默认：2000 万行，6 个 worker）
./case_file/parse_to_blackhole/run.sh

# 中等规模数据集（20 万行）
./case_file/parse_to_blackhole/run.sh -m

# 自定义配置
./case_file/parse_to_file/run.sh -w 8 nginx
```

## 数据流向

```
wpgen → gen.dat → wparse batch → sink (黑洞/文件)
```
