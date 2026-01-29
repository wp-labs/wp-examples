# Benchmark Guide

The benchmark directory contains performance test cases based on `benchmark/benchmark_common.sh`. Test cases are organized by data source type, with each case containing different processing scenarios. This document explains the overall structure, common parameters, and the purpose of each test scenario.

## Prerequisites

1. All scripts run in release profile by default and depend on `wparse`/`wpgen`/`wproj` being in PATH.
2. Run scripts from the benchmark directory or specific test directory.

## Directory Structure

```
benchmark/
├── benchmark_common.sh      # Common function library (parameter parsing, environment initialization)
├── check_run.sh            # Batch test script (runs all tests with -m parameter)
├── models/                 # Shared model files
│   ├── wpl/               # WPL rule sets (nginx, sysmon, apt, aws, etc.)
│   └── oml/               # OML transformation models
├── sinks/                 # Shared sink configurations
│   ├── parse_to_blackhole/
│   ├── parse_to_file/
│   ├── trans_to_blackhole/
│   └── trans_to_file/
├── case_tcp/              # TCP data source test scenarios
├── case_file/             # File data source test scenarios
├── case_syslog_tcp/       # Syslog TCP test scenarios
├── case_syslog_udp/       # Syslog UDP test scenarios
└── wpgen_test/            # wpgen performance test
```

## Test Scenarios

**Processing Modes:**
- `parse`: Parse mode - pure WPL parsing only
- `trans`: Transform mode - WPL parsing + OML transformation

**Output Targets:**
- `blackhole`: Discards data, tests pure parsing/forwarding performance
- `file`: Outputs to files, tests complete processing pipeline

## Test Case Matrix

| Case | Mode | Input | Output | Purpose |
|------|------|-------|--------|---------|
| case_tcp/parse_to_blackhole | Parse | TCP (daemon) | Blackhole | TCP reception + pure parsing performance |
| case_tcp/parse_to_file | Parse | TCP (daemon) | File | Full TCP-to-file parsing pipeline |
| case_tcp/trans_to_blackhole | Trans | TCP (daemon) | Blackhole | Parsing + OML transformation performance |
| case_tcp/trans_to_file | Trans | TCP (daemon) | File | Full transformation pipeline |
| case_file/parse_to_blackhole | Parse | File (batch) | Blackhole | Pure parsing throughput |
| case_file/parse_to_file | Parse | File (batch) | File | File-to-file parsing |
| case_file/trans_to_blackhole | Trans | File (batch) | Blackhole | Parsing + OML transformation throughput |
| case_file/trans_to_file | Trans | File (batch) | File | Full transformation pipeline |
| case_syslog_tcp/parse_to_blackhole | Parse | Syslog TCP | Blackhole | Syslog TCP pure parsing |
| case_syslog_tcp/trans_to_blackhole | Trans | Syslog TCP | Blackhole | Syslog TCP parsing + transformation |
| case_syslog_udp/parse_to_blackhole | Parse | Syslog UDP | Blackhole | Syslog UDP pure parsing |
| case_syslog_udp/trans_to_blackhole | Trans | Syslog UDP | Blackhole | Syslog UDP parsing + transformation |

## Common Options

All test scripts share the following parameters (parsed by `benchmark_parse_args` in `benchmark_common.sh`):

| Parameter | Description | Default |
|-----------|-------------|---------|
| `-m` | Use medium dataset (200K lines) | 20M lines |
| `-f` | Force regenerate input data | Smart detection |
| `-c <cnt>` | Specify line count (overrides -m) | - |
| `-w <cnt>` | Specify wparse worker count | 6 (daemon) / 10 (batch) |
| `wpl_dir` | WPL rule set directory (positional) | nginx |
| `speed` | Generation rate limit (lines/sec, 0=unlimited) | 0 |

Run `./run.sh -h` to see supported options for a specific test script.

## Quick Start

### Run Single Test

```bash
cd benchmark

# Default config (nginx rules, large dataset)
./case_tcp/parse_to_blackhole/run.sh

# Medium dataset
./case_tcp/parse_to_blackhole/run.sh -m

# Use sysmon rules, 12 workers, 1M lines/sec rate limit
./case_tcp/parse_to_blackhole/run.sh -w 12 sysmon 1000000
```

### Run All Tests

```bash
cd benchmark
./check_run.sh
```

## FAQ

- **WPL model load failure**: Check `wpl` path in wparse.toml is correct relative to test directory
- **Data generation failure**: Check disk space and wpgen.toml configuration
- **Slow test execution**: Use `-m` parameter to reduce data size, adjust `-w` for worker count

---

# Benchmark 用例指南 (中文)

benchmark 目录收录了基于 `benchmark/benchmark_common.sh` 的性能测试用例。测试用例按数据源类型组织为多个 case 目录，每个 case 下包含不同的处理场景。本文档说明整体结构、通用参数与各测试场景的用途。

## 前置准备

1. 所有脚本默认在 release profile 下运行，并依赖 `wparse`/`wpgen`/`wproj`，确保它们位于 PATH 中。
2. 从 benchmark 目录或具体测试目录运行脚本。

## 目录结构

```
benchmark/
├── benchmark_common.sh      # 公共函数库（参数解析、环境初始化等）
├── check_run.sh            # 批量测试脚本（使用 -m 参数运行所有测试）
├── models/                 # 共享的模型文件
│   ├── wpl/               # WPL 规则集（nginx、sysmon、apt、aws 等）
│   └── oml/               # OML 转换模型
├── sinks/                 # 共享的 sink 配置
│   ├── parse_to_blackhole/
│   ├── parse_to_file/
│   ├── trans_to_blackhole/
│   └── trans_to_file/
├── case_tcp/              # TCP 数据源测试场景
├── case_file/             # File 数据源测试场景
├── case_syslog_tcp/       # Syslog TCP 测试场景
├── case_syslog_udp/       # Syslog UDP 测试场景
└── wpgen_test/            # wpgen 性能测试
```

## 测试场景说明

**处理模式：**
- `parse`: 解析模式 - 纯 WPL 解析
- `trans`: 转换模式 - WPL 解析 + OML 转换

**输出目标：**
- `blackhole`: 黑洞输出 - 丢弃数据，用于测试纯解析/转发性能
- `file`: 文件输出 - 输出到文件，测试完整的处理链路

## 测试用例矩阵

| 用例 | 模式 | 输入 | 输出 | 用途 |
|------|------|------|------|------|
| case_tcp/parse_to_blackhole | 解析 | TCP (daemon) | 黑洞 | TCP 接收 + 纯解析性能 |
| case_tcp/parse_to_file | 解析 | TCP (daemon) | 文件 | 完整 TCP 到文件解析管道 |
| case_tcp/trans_to_blackhole | 转换 | TCP (daemon) | 黑洞 | 解析 + OML 转换性能 |
| case_tcp/trans_to_file | 转换 | TCP (daemon) | 文件 | 完整转换管道 |
| case_file/parse_to_blackhole | 解析 | 文件 (batch) | 黑洞 | 纯解析吞吐量 |
| case_file/parse_to_file | 解析 | 文件 (batch) | 文件 | 文件到文件解析 |
| case_file/trans_to_blackhole | 转换 | 文件 (batch) | 黑洞 | 解析 + OML 转换吞吐量 |
| case_file/trans_to_file | 转换 | 文件 (batch) | 文件 | 完整转换管道 |
| case_syslog_tcp/parse_to_blackhole | 解析 | Syslog TCP | 黑洞 | Syslog TCP 纯解析 |
| case_syslog_tcp/trans_to_blackhole | 转换 | Syslog TCP | 黑洞 | Syslog TCP 解析 + 转换 |
| case_syslog_udp/parse_to_blackhole | 解析 | Syslog UDP | 黑洞 | Syslog UDP 纯解析 |
| case_syslog_udp/trans_to_blackhole | 转换 | Syslog UDP | 黑洞 | Syslog UDP 解析 + 转换 |

## 通用选项

所有测试脚本共享以下参数（由 `benchmark_common.sh` 中的 `benchmark_parse_args` 解析）：

| 参数 | 说明 | 默认值 |
|------|------|--------|
| `-m` | 使用中等规模数据集（20 万行） | 2000 万行 |
| `-f` | 强制重新生成输入数据 | 智能检测 |
| `-c <cnt>` | 指定数据条数（与 -m 互斥，优先级更高） | - |
| `-w <cnt>` | 指定 wparse worker 数量 | 6 (daemon) / 10 (batch) |
| `wpl_dir` | WPL 规则集目录（位置参数） | nginx |
| `speed` | 样本生成限速（行/秒，0 表示不限速） | 0 |

执行 `./run.sh -h` 可查看某个测试脚本支持的选项组合。

## 快速开始

### 运行单个测试

```bash
cd benchmark

# 使用默认配置（nginx 规则，大规模数据集）
./case_tcp/parse_to_blackhole/run.sh

# 使用中等规模数据集
./case_tcp/parse_to_blackhole/run.sh -m

# 使用 sysmon 规则，12 个 worker，限速 1M 行/秒
./case_tcp/parse_to_blackhole/run.sh -w 12 sysmon 1000000
```

### 批量测试所有场景

```bash
cd benchmark
./check_run.sh
```

## 常见问题

- **WPL 模型加载失败**：检查 wparse.toml 中的 `wpl` 路径是否相对于测试目录正确
- **数据生成失败**：检查磁盘空间是否充足，确认 wpgen.toml 配置正确
- **测试运行缓慢**：使用 `-m` 参数减小数据规模，调整 `-w` 参数优化 worker 数
