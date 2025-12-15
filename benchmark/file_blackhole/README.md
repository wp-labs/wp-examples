# file_blackhole 场景说明

本用例演示"文件源 → Blackhole 汇"的性能基准测试场景：使用双路文件源（wpgen.toml 和 wpgen1.toml）生成测试数据，通过 wparse batch 模式处理，输出到 blackhole（丢弃）以测试纯解析吞吐性能。

## 场景特点

- **双路文件源**：同时生成 `gen.dat` 和 `gen1.dat` 两个数据文件
- **Batch 处理**：使用批处理模式（而非 daemon 模式）
- **Blackhole 输出**：数据解析后丢弃，专注测试解析性能
- **大规模数据**：默认 2000 万行，中等模式 20 万行

## 目录结构

```
file_blackhole/
├── conf/
│   ├── wpgen.toml      # 第一路数据生成配置 → gen.dat
│   └── wpgen1.toml     # 第二路数据生成配置 → gen1.dat
├── models/
│   ├── knowledge/      # 知识库（如有）
│   └── sinks/
│       ├── defaults.toml
│       └── infra.d/    # 基础组（blackhole 输出）
├── data/
│   ├── in_dat/         # 输入数据目录
│   │   ├── gen.dat     # 第一路生成数据
│   │   └── gen1.dat    # 第二路生成数据
│   └── logs/           # 日志目录
├── out/                # 输出目录（blackhole 场景通常为空）
└── run.sh              # 运行脚本
```

## 快速使用

### 前置准备

确保 `wparse`、`wpgen`、`wproj` 在 PATH 中：
```bash
# 构建 release 版本
cargo build-apps --release
# 将二进制添加到 PATH 或复制到 ~/bin
```

### 运行测试

```bash
cd benchmark

# 默认大规模测试（2000 万行）
./file_blackhole/run.sh

# 中等规模测试（20 万行）
./file_blackhole/run.sh -m

# 指定 worker 数量
./file_blackhole/run.sh -w 12

# 强制重新生成数据
./file_blackhole/run.sh -f

# 使用 sysmon 规则
./file_blackhole/run.sh sysmon

# 组合选项：中等规模 + 8 worker + nginx 规则 + 限速 100 万行/秒
./file_blackhole/run.sh -m -w 8 nginx 1000000
```

### 参数说明

| 参数 | 说明 | 默认值 |
|------|------|--------|
| `-m` | 使用中等规模数据集 | 2000 万行 → 20 万行 |
| `-f` | 强制重新生成数据 | 跳过已存在的数据 |
| `-c <cnt>` | 指定数据条数 | 与 `-m` 互斥 |
| `-w <cnt>` | 指定 worker 数量 | batch 默认 10 |
| `wpl_dir` | WPL 规则目录 | nginx |
| `speed` | 生成限速（行/秒） | 0（不限速） |

## 配置文件

### wpgen.toml（第一路）
```toml
[generator]
mode = "sample"
count = 1000
speed = 0
parallel = 1

[output]
connect = "file_raw_sink"
name = "gen_out"
params = { base = "./data/in_dat", file = "gen.dat" }
```

### wpgen1.toml（第二路）
```toml
[generator]
mode = "sample"
count = 1000
speed = 0
parallel = 1

[output]
connect = "file_raw_sink"
name = "gen_out"
params = { base = "./data/in_dat", file = "gen1.dat" }
```

## 执行流程

1. **初始化环境**：加载 benchmark 公共函数库，设置 release profile
2. **验证 WPL 路径**：确认规则目录存在
3. **检查数据文件**：判断 `gen.dat` 和 `gen1.dat` 是否已存在
4. **条件生成数据**：若数据不存在或指定 `-f`，则生成新数据
5. **执行 batch 测试**：运行 `wparse batch` 处理数据
6. **输出统计**：调用 `wproj data stat` 显示结果

## 输出示例

```
Using WPL path: ../models/wpl/nginx
Using large dataset: LINE_CNT=20000000
Checking existing data files...
Found existing data file: ./data/in_dat/gen.dat (20000000 lines)
Found existing data file: ./data/in_dat/gen1.dat (20000000 lines)
Data files already exist and -f flag not specified. Skipping data generation.
2> Running batch processing
[STAT] input: 40000000, output: 39500000, miss: 300000, error: 200000
...
```

## 性能调优建议

### Worker 数量
- CPU 密集型解析：worker 数 ≈ CPU 核心数
- I/O 密集型场景：可适当增加 worker

### 数据规模
- 快速验证：`-m`（20 万行）
- 完整压测：默认（2000 万行）
- 自定义：`-c 5000000`（500 万行）

### 限速控制
- 不限速测试纯解析性能
- 限速模拟真实场景

## 常见问题

### Q1: 数据生成太慢
- 使用 `-m` 减少数据量
- 检查磁盘 I/O 性能

### Q2: 内存不足
- 减少 worker 数量
- 使用较小的数据集

### Q3: 如何查看详细日志
```bash
tail -f ./data/logs/wparse.log
```

## 相关文档
- [Benchmark 总览](../README.md)
- [benchmark_common.sh](../benchmark_common.sh)
