# syslog_blackhole 说明

本用例演示"Syslog 源 → Blackhole 汇"的性能基准测试场景：使用 wpgen 通过 Syslog 协议发送数据，wparse 以 daemon 模式接收并处理，输出到 blackhole 以测试网络接收与解析的综合性能。

## 目录结构

```
benchmark/syslog_blackhole/
├── README.md                    # 本说明文档
├── run.sh                       # 性能测试运行脚本
├── record.md                    # 运行记录文档
├── conf/                        # 配置文件目录
│   ├── wparse.toml             # WarpParse 主配置
│   ├── wpgen.toml              # Syslog UDP 生成器配置
│   └── wpgen1.toml             # Syslog TCP 生成器配置（可选）
├── data/                        # 运行数据目录
│   ├── out_dat/                # 输出数据目录
│   │   ├── error.dat          # 错误数据输出
│   │   ├── miss.dat           # 缺失数据输出
│   │   ├── monitor.dat        # 监控数据输出
│   │   └── residue.dat        # 残留数据输出
│   ├── logs/                   # 日志文件目录
│   └── rescue/                 # 救援数据目录
├── logs/                       # 额外的日志目录
└── .run/                       # 运行时数据目录
    └── rule_mapping.dat        # 规则映射数据
```

## 快速开始

### 运行环境要求

- WarpParse 引擎（需在系统 PATH 中）
- Bash shell 环境
- 支持 UDP/TCP 网络连接的系统环境
- 推荐系统：
  - **Linux**：最佳性能，支持所有优化功能
  - **macOS**：良好性能，部分优化功能受限

### 运行命令

```bash
# 进入 benchmark 目录
cd benchmark

# 默认大规模性能测试（2000 万行数据）
./syslog_blackhole/run.sh

# 中等规模测试（20 万行数据）
./syslog_blackhole/run.sh -m

# 指定 worker 数量
./syslog_blackhole/run.sh -w 8

# 使用特定 WPL 规则
./syslog_blackhole/run.sh nginx

# 使用 sysmon 规则并限速 50 万行/秒
./syslog_blackhole/run.sh sysmon 500000

# 组合使用
./syslog_blackhole/run.sh -m -w 4 nginx 300000
```

### 运行参数

| 参数 | 说明 | 默认值 |
|------|------|--------|
| `-m` | 使用中等规模数据集 | 2000万 → 20万行 |
| `-w <cnt>` | 指定 worker 数量 | 2 |
| `wpl_dir` | WPL 规则目录名 | nginx |
| `speed` | 生成器限速（行/秒） | 0（不限速） |

### 性能测试选项

- **默认测试**：2000 万行数据，Syslog UDP，2 个 worker
- **中等测试**：20 万行数据，适合快速验证
- **自定义 WPL**：支持 nginx、apache、sysmon 等规则
- **速率限制**：可指定生成速率，测试流控性能
- **双协议支持**：可切换 UDP/TCP 模式

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
   - 启动 `wparse daemon` 监听 Syslog 端口
   - 加载指定的 WPL 规则
   - 等待 Syslog 连接

4. **数据生成与发送**
   - 启动 `wpgen` 生成测试数据
   - 通过 Syslog 协议发送到 wparse daemon
   - 支持高并发发送

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
    ↓ Syslog 协议 (UDP/TCP, 端口 1514/1515)
┌────────────────────────────────┐
│        wparse daemon           │
│    - 接收 Syslog 数据          │
│    - 应用 WPL 规则解析         │
│    - 分发到 sinks             │
└────────────────────────────────┘
    ↓
┌─────────────┬─────────────┐
│  blackhole  │   monitor   │
│    sink     │    sink     │
│ (丢弃数据)  │ (收集统计)  │
└─────────────┴─────────────┘
```
