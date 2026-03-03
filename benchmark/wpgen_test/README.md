# wpgen Performance Test

This case tests the `wpgen` data generator performance independently, without starting wparse.

## Purpose

Validate the ability to:
- Test wpgen generation capability in isolation
- Evaluate different WPL rule sets for generation speed
- Measure rate-limited vs unlimited generation performance
- Prepare data for other benchmark tests

## Features Validated

| Feature | Description |
|---------|-------------|
| Pure Generation | Testing wpgen without wparse overhead |
| Multi-Rule Sets | nginx and benchmark rule sets |
| Rate Limiting | Testing different speed limits |
| Large Scale | Default 8M lines + 6K lines samples |

## Quick Start

```bash
cd benchmark

# Default test (nginx + benchmark rules)
./wpgen_test/run.sh

# Specify profile (release/debug)
./wpgen_test/run.sh release
./wpgen_test/run.sh debug
```

## Test Configuration

```bash
# High-speed generation test
LINE_CNT=8000000
SPEED_MAX=2000000
wpgen sample -n $LINE_CNT -s $SPEED_MAX --stat 2 -p --wpl ./models/wpl/nginx
wpgen sample -n $LINE_CNT -s $SPEED_MAX --stat 2 -p --wpl ./models/wpl/benchmark

# Low-speed generation test
LINE_CNT=6000
SPEED_MAX=1000
wpgen sample -n $LINE_CNT -s $SPEED_MAX --stat 2 -p --wpl ./models/wpl/nginx
```

## Performance Factors

| Factor | Impact |
|--------|--------|
| CPU Performance | Rule complexity affects generation speed |
| Disk I/O | File writing bottleneck |
| Rule Complexity | Field count and types |

---

# wpgen 性能测试 (中文)

本用例专门用于测试 `wpgen` 数据生成器的性能：仅生成样本数据，不启动 wparse 解析。

## 用途

验证以下能力：
- 独立测试 wpgen 生成能力
- 评估不同 WPL 规则集的生成速度
- 测量限速与无限速生成性能
- 为其他基准测试准备数据

## 验证特性

| 特性 | 说明 |
|------|------|
| 纯生成测试 | 不含 wparse 开销的 wpgen 测试 |
| 多规则集 | nginx 和 benchmark 规则集 |
| 速率限制 | 测试不同限速配置 |
| 大规模数据 | 默认 800 万行 + 6000 行样本 |

## 快速开始

```bash
cd benchmark

# 默认测试（nginx + benchmark 两套规则）
./wpgen_test/run.sh

# 指定 profile（release/debug）
./wpgen_test/run.sh release
./wpgen_test/run.sh debug
```

## 测试配置

```bash
# 高速生成测试
LINE_CNT=8000000
SPEED_MAX=2000000
wpgen sample -n $LINE_CNT -s $SPEED_MAX --stat 2 -p --wpl ./models/wpl/nginx
wpgen sample -n $LINE_CNT -s $SPEED_MAX --stat 2 -p --wpl ./models/wpl/benchmark

# 低速生成测试
LINE_CNT=6000
SPEED_MAX=1000
wpgen sample -n $LINE_CNT -s $SPEED_MAX --stat 2 -p --wpl ./models/wpl/nginx
```

## 性能影响因素

| 因素 | 影响 |
|------|------|
| CPU 性能 | 规则复杂度影响生成速度 |
| 磁盘 I/O | 文件写入瓶颈 |
| 规则复杂度 | 字段数量和类型 |
