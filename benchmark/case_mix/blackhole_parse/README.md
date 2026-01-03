# wpls_test 场景说明

本用例专门用于测试 `wparse` 的多 worker 扩展性：生成固定规模的样本数据后，依次使用不同数量的 worker 运行批处理，观察并发扩展效果。适用于评估系统的水平扩展能力和最佳 worker 配置。

## 场景特点

- **多 Worker 测试**：依次测试 2/4/6 个 worker（可自定义）
- **批处理模式**：使用 batch 模式处理预生成的数据
- **扩展性评估**：对比不同并发度下的吞吐表现
- **中等规模数据**：默认 500 万行样本

## 目录结构

```
wpls_test/
├── conf/
│   ├── wparse.toml     # 主配置
│   └── wpgen.toml      # 生成器配置
├── models/
│   ├── oml/            # OML 转换模型
│   ├── knowledge/      # 知识库
│   ├── sinks/          # Sink 配置
│   ├── sources/        # 源配置
│   └── wpl/            # WPL 规则
│       ├── benchmark/  # benchmark 规则
│       └── example/    # example 规则
├── data/
│   ├── in_dat/         # 输入数据
│   ├── out_dat/        # 输出数据
│   └── logs/           # 日志目录
└── run.sh              # 运行脚本
```

## 快速使用

```bash
cd benchmark

# 依次运行 2/4/6 worker 测试
./wpls_test/run.sh

# 只测试指定 worker 数量
./wpls_test/run.sh -w 8

# 指定 profile
./wpls_test/run.sh release
```

## 参数说明

| 参数 | 说明 | 默认值 |
|------|------|--------|
| `-w <cnt>` | 指定 worker 数量 | 依次 2/4/6 |
| `profile` | 构建 profile | release |

## 执行流程

1. 初始化 release 环境
2. 清理旧数据
3. 生成 500 万行样本数据（30 万行/秒）
4. 依次使用 2/4/6 worker 运行批处理
5. 每轮之间清理输出数据（保留输入）

## 测试配置

```bash
# 数据生成
wpgen sample -n 5000000 -s 300000 --stat 10 --print_stat

# 多 worker 测试
WORKER_LIST=(2 4 6)  # 默认
# 或指定单个: WORKER_LIST=("$WORKER_ARG")

for cnt in "${WORKER_LIST[@]}"; do
  wparse batch --stat 20 -w "$cnt" --print_stat
  wproj data clean  # 清理输出，准备下一轮
done
```

## 性能指标

### 预期扩展效果
| Worker 数 | 预期吞吐倍数 | 说明 |
|-----------|-------------|------|
| 2 | 1.0x | 基准 |
| 4 | 1.8-2.0x | 近线性扩展 |
| 6 | 2.5-3.0x | 接近线性 |
| 8+ | 递减 | 受 I/O 瓶颈限制 |

### 影响因素
- **CPU 核心数**：worker 数不应超过核心数
- **磁盘 I/O**：多 worker 共享 I/O 带宽
- **内存带宽**：数据结构访问竞争
- **规则复杂度**：CPU 密集型规则扩展性更好

## 输出示例

```
1> gen 1KM sample data
[STAT] generated: 5000000, speed: 300000/s

2> start 2 thread work
[STAT] input: 5000000, output: 4900000, elapsed: 25s
throughput: 200000/s

2> start 4 thread work
[STAT] input: 5000000, output: 4900000, elapsed: 14s
throughput: 357000/s

2> start 6 thread work
[STAT] input: 5000000, output: 4900000, elapsed: 10s
throughput: 500000/s
```

## 扩展性分析

### 理想扩展
```
吞吐 ∝ worker 数量
```

### 实际扩展（Amdahl 定律）
```
加速比 = 1 / (S + P/N)
S = 串行部分比例
P = 并行部分比例
N = worker 数量
```

### 瓶颈识别
- **CPU 瓶颈**：所有核心利用率高
- **I/O 瓶颈**：磁盘利用率高，CPU 空闲
- **内存瓶颈**：频繁 GC 或 swap

## 调优建议

### 确定最佳 Worker 数
1. 从 CPU 核心数开始测试
2. 逐步减少，找到性价比最优点
3. 考虑其他服务的 CPU 需求

### 避免过度并发
- Worker 过多会增加上下文切换
- I/O 密集场景 worker 数可略少于核心数

## 与其他基准测试的区别

| 脚本 | 测试重点 | Worker 配置 |
|------|----------|-------------|
| wpls_test | 扩展性 | 多轮对比 |
| file_blackhole | 吞吐 | 固定 10 |
| tcp_blackhole | 网络+解析 | 固定 6 |

## 相关文档
- [Benchmark 总览](../README.md)
- [性能调优](../../wp-docs/10-user/08-performance/01-performance_overview.md)
