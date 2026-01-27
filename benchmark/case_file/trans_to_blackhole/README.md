# file_blackhole

本用例演示"文件源 → Blackhole 汇"的批处理性能基准测试场景：使用 wpgen 生成测试数据文件，wparse 通过批处理模式读取并解析，输出到 blackhole 以测试纯解析吞吐性能。

## 目录结构

```
benchmark/file_blackhole/
├── README.md                    # 本说明文档
├── run.sh                       # 性能测试运行脚本
├── conf/                        # 配置文件目录
│   ├── wparse.toml             # WarpParse 主配置
│   ├── wpgen.toml              # 第一路文件生成器配置
│   └── wpgen1.toml             # 第二路文件生成器配置
├── models/                      # 模型配置目录
│   ├── sinks/                  # 数据汇配置
│   │   ├── defaults.toml       # 默认配置
│   │   ├── business.d/         # 业务组配置
│   │   │   └── all.toml        # Blackhole 汇组配置
│   │   └── infra.d/            # 基础设施组配置
│   │       ├── default.toml    # 默认数据汇
│   │       ├── error.toml      # 错误数据处理
│   │       ├── miss.toml       # 缺失数据处理
│   │       ├── monitor.toml    # 监控数据处理
│   │       └── residue.toml    # 残留数据处理
│   ├── sources/                # 数据源配置
│   │   └── wpsrc.toml          # 文件源配置
│   ├── wpl/                    # WPL 解析规则目录
│   │   ├── nginx/              # Nginx 日志规则
│   │   ├── apache/             # Apache 日志规则
│   │   └── sysmon/             # 系统监控规则
│   ├── oml/                    # OML 转换规则目录（空）
│   └── knowledge/              # 知识库目录（空）
├── data/                        # 运行数据目录
│   ├── in_dat/                 # 输入数据目录
│   │   ├── gen.dat            # 第一路生成数据
│   │   └── gen1.dat           # 第二路生成数据
│   ├── out_dat/                # 输出数据目录
│   │   ├── error.dat          # 错误数据输出
│   │   ├── miss.dat           # 缺失数据输出
│   │   ├── monitor.dat        # 监控数据输出
│   │   └── residue.dat        # 残留数据输出
│   ├── logs/                   # 日志文件目录
│   └── rescue/                 # 救援数据目录
├── out/                         # 输出目录
└── .run/                        # 运行时数据目录
    └── rule_mapping.dat        # 规则映射数据
```

## 快速开始

### 运行环境要求

- WarpParse 引擎（需在系统 PATH 中）
- Bash shell 环境
- 推荐系统：
  - **Linux**：最佳性能，支持所有优化功能
  - **macOS**：良好性能，部分优化功能受限

### 运行命令

```bash
# 进入 benchmark 目录
cd benchmark/file_blackhole

# 默认大规模性能测试（2000 万行数据）
./run.sh

# 中等规模测试（20 万行数据）
./run.sh -m

# 强制重新生成数据（即使已存在）
./run.sh -f

# 指定 worker 数量
./run.sh -w 8

# 使用特定 WPL 规则
./run.sh nginx

# 组合使用
./run.sh -m -w 8 -f nginx
```

### 运行参数

| 参数 | 说明 | 默认值 |
|------|------|--------|
| `-m` | 使用中等规模数据集 | 2000万 → 20万行 |
| `-f` | 强制重新生成数据 | 智能检测 |
| `-w <cnt>` | 指定 worker 数量 | 6 |
| `wpl_dir` | WPL 规则目录名 | nginx |
| `speed` | 生成器限速（行/秒） | 0（不限速） |

### 性能测试选项

- **默认测试**：2000 万行数据，双路文件源，6 个 worker
- **中等测试**：20 万行数据，适合快速验证
- **强制生成**：`-f` 参数强制重新生成测试数据
- **自定义 WPL**：支持 nginx、apache、sysmon 等规则

## 执行逻辑

### 流程概览

`run.sh` 脚本执行以下主要步骤：

1. **环境准备**
   - 加载 benchmark 公共函数库
   - 解析命令行参数
   - 设置默认值（大规模：2000万行，中等：20万行）

2. **数据生成检查**
   - 检查 `data/in_dat/gen.dat` 和 `data/in_dat/gen1.dat` 是否存在
   - 如果不存在或使用 `-f` 参数，则生成新数据

3. **数据生成**（如需要）
   - 启动 `wpgen` 生成第一路数据到 `gen.dat`
   - 启动 `wpgen` 生成第二路数据到 `gen1.dat`
   - 支持并发生成提高效率

4. **批处理执行**
   - 使用 `wparse batch` 读取文件数据
   - 应用 WPL 规则进行解析
   - 数据输出到 blackhole（丢弃）

5. **性能统计**
   - 实时显示处理进度
   - 记录吞吐量、处理时间等指标
   - 输出最终性能报告

### 数据流向

```
wpgen 生成器 1        wpgen 生成器 2
       ↓                    ↓
   gen.dat              gen1.dat
       ↓                    ↓
┌────────────────────────────────┐
│      wparse batch             │
│   - 读取文件数据               │
│   - 应用 WPL 规则解析          │
│   - 分发到 sinks              │
└────────────────────────────────┘
    ↓
┌─────────────┬─────────────┐
│  blackhole  │   monitor   │
│    sink     │    sink     │
│ (丢弃数据)  │ (收集统计)  │
└─────────────┴─────────────┘
```


## 验证与故障排除

### 运行成功验证

1. **检查性能输出**
   - 查看 terminal 输出的实时统计信息
   - 关注 "Throughput"（吞吐量）指标
   - 确认无错误或异常

2. **验证输出文件**
   ```bash
   # 检查监控数据
   ls -la data/out_dat/monitor.dat

   # 确认其他文件为空（无错误）
   ls -la data/out_dat/{error,miss,residue}.dat
   ```




## 性能

### 优化

1. **系统级优化**

   **Linux 系统：**
   ```bash
   # CPU 亲和性设置
   taskset -c 0-5 ./run.sh -w 6

   # I/O 调度器优化（SSD）
   echo noop | sudo tee /sys/block/sdX/queue/scheduler

   # 增大文件描述符限制
   ulimit -n 65536
   ```

   **macOS 系统：**
   ```bash
   # 调整文件描述符限制
   ulimit -n 65536

   # 调整系统参数（需要管理员权限）
   sudo sysctl -w kern.maxfiles=65536
   sudo sysctl -w kern.maxfilesperproc=65536
   ```

2. **应用级优化**
   - 增加 worker 数量：`-w 12`（不超过 CPU 核心数）
   - 使用更快的 WPL 规则（如 nginx）
   - 启用数据预生成并缓存

3. **存储优化**
   - 使用 SSD 存储
   - 使用 RAID 0 提高读写性能
   - 考虑使用内存文件系统

### 影响因素

1. **WPL 规则复杂度**
   - nginx：简单正则，性能最佳
   - apache：中等复杂度
   - sysmon：复杂规则，性能较低

2. **数据特征**
   - 日志行长度
   - 正则匹配复杂度
   - 字段提取数量

3. **系统配置**
   - CPU 核心数和频率
   - 内存大小和速度
   - 磁盘 I/O 性能（关键因素）


### 使用建议

- **选择 file_blackhole**：
  - 需要测试纯解析性能
  - 批量数据处理场景
  - 追求最高吞吐量

- **选择 tcp_blackhole**：
  - 需要可靠的网络传输
  - 实时数据处理
  - 模拟 TCP 数据源

- **选择 syslog_blackhole**：
  - 传统 syslog 集成
  - 极限性能测试
  - 日志收集场景

---

*本文档最后更新时间：2025-12-16*
