# tcp_blackhole 说明

本用例演示"TCP 源 → Blackhole 汇"的性能基准测试场景：使用 wpgen 通过 TCP 协议发送数据，wparse 以 daemon 模式接收并处理，输出到 blackhole 以测试可靠传输与解析的综合性能。

## 目录结构

```
benchmark/tcp_blackhole/
├── README.md                    # 本说明文档
├── run.sh                       # 性能测试运行脚本
├── conf/                        # 配置文件目录
│   ├── wparse.toml             # WarpParse 主配置
│   ├── wpgen.toml              # 第一路 TCP 生成器配置
│   └── wpgen2.toml             # 第二路 TCP 生成器配置（可选）
├── models/                      # 模型配置目录
│   ├── sinks/                  # 数据汇配置
│   │   ├── defaults.toml       # 默认配置
│   │   ├── business.d/         # 业务组配置
│   │   │   └── sink.toml       # 业务汇组配置
│   │   └── infra.d/            # 基础设施组配置
│   │       ├── default.toml    # 默认数据汇
│   │       ├── error.toml      # 错误数据处理
│   │       ├── miss.toml       # 缺失数据处理
│   │       ├── monitor.toml    # 监控数据处理
│   │       └── residue.toml    # 残留数据处理
│   ├── sources/                # 数据源配置
│   │   └── wpsrc.toml          # TCP 源配置
│   ├── wpl/                    # WPL 解析规则目录
│   │   ├── nginx/              # Nginx 日志规则
│   │   ├── apache/             # Apache 日志规则
│   │   └── sysmon/             # 系统监控规则
│   ├── oml/                    # OML 转换规则目录（空）
│   └── knowledge/              # 知识库目录（空）
├── data/                        # 运行数据目录
│   ├── out_dat/                 # 输出数据目录
│   │   ├── error.dat           # 错误数据输出
│   │   ├── miss.dat            # 缺失数据输出
│   │   ├── monitor.dat         # 监控数据输出
│   │   └── residue.dat         # 残留数据输出
│   └── logs/                    # 日志文件目录
└── .run/                        # 运行时数据目录
    └── rule_mapping.dat        # 规则映射数据
```

## 快速开始

### 运行环境要求

- WarpParse 引擎（需在系统 PATH 中）
- Bash shell 环境
- 支持 TCP 网络连接的系统环境
- 推荐系统：
  - **Linux**：最佳性能，支持所有优化功能
  - **macOS**：良好性能，部分优化功能受限

### 运行命令

```bash
# 进入 benchmark 目录
cd benchmark

# 默认大规模性能测试（2000 万行数据）
./tcp_blackhole/run.sh

# 中等规模测试（20 万行数据）
./tcp_blackhole/run.sh -m

# 使用 sysmon 规则并限速 100 万行/秒
./tcp_blackhole/run.sh sysmon 1000000 

# 自定义测试参数
./tcp_blackhole/run.sh  -w 8 nginx 500000

./tcp_blackhole/run.sh  -w 8 sysmon 500000
```

### 运行参数

| 参数 | 说明 | 默认值 |
|------|------|--------|
| `-m` | 使用中等规模数据集 | 2000万 → 20万行 |
| `-w <cnt>` | 指定 worker 数量 | 6 |
| `wpl_dir` | WPL 规则目录名 | nginx |
| `speed` | 生成器限速（行/秒） | 0（不限速） |

### 性能测试选项

- **默认测试**：2000 万行 Nginx 日志，不限速，6 个 worker
- **中等测试**：20 万行数据，适合快速验证
- **自定义 WPL**：支持 nginx、apache、sysmon 等规则
- **速率限制**：可指定生成速率，测试流控性能

## 执行逻辑

### 流程概览

`run.sh` 脚本执行以下主要步骤：

1. **环境准备**
   - 加载 benchmark 公共函数库
   - 解析命令行参数
   - 设置默认值（大规模：2000万行，中等：20万行）

2. **初始化环境**
   - 初始化 release 模式环境
   - 验证指定的 WPL 规则路径
   - 清理历史数据和日志

3. **启动 Daemon 模式**
   - 启动 `wparse daemon` 监听 TCP 端口
   - 加载指定的 WPL 规则
   - 等待 TCP 连接

4. **数据生成与发送**
   - 启动 `wpgen` 生成测试数据
   - 通过 TCP 协议发送到 wparse daemon
   - 支持单路或双路并发发送

5. **性能监控**
   - 实时监控处理速度
   - 记录吞吐量、延迟等指标
   - 收集错误和异常统计

6. **结果统计**
   - 停止 daemon 进程
   - 输出性能报告
   - 验证数据完整性

### 数据流向

```
wpgen 生成器
    ↓ TCP 连接 (端口 19001)
┌────────────────────────────────┐
│        wparse daemon           │
│    - 接收 TCP 数据              │
│    - 应用 WPL 规则解析           │
│    - 分发到 sinks               │
└────────────────────────────────┘
    ↓
┌─────────────┬─────────────┐
│  blackhole  │   monitor   │
│    sink     │    sink     │
│ (丢弃数据)  │ (收集统计)     │
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

### 常见问题与解决方案

#### 1. TCP 连接被拒绝

**错误信息**：`Connection refused`

**解决方案**：
- 确认 wparse daemon 已成功启动
- 检查端口 19001 是否被占用
- 验证防火墙设置

```bash
# 检查端口占用
netstat -tlnp | grep 19001

# 或使用 ss 命令
ss -tlnp | grep 19001
```

#### 2. daemon 进程未正常退出

**解决方案**：
```bash
# 查找并终止 wparse 进程
ps aux | grep wparse
kill -9 <PID>

# 清理可能残留的端口占用
sudo lsof -i :19001
```

## 性能

### 优化
1. **系统级优化**

   **Linux 系统：**
   ```bash
   # CPU 亲和性设置
   taskset -c 0-5 ./run.sh -w 6

   # 实时优先级（需要 root）
   sudo chrt -f 99 ./run.sh

   # 调整 TCP 缓冲区（需要 root）
   sudo sysctl -w net.core.wmem_max=26214400
   sudo sysctl -w net.core.rmem_max=26214400
   ```

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
   - 磁盘 I/O（日志写入）


*本文档最后更新时间：2025-12-16*
