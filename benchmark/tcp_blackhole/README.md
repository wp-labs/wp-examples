# tcp_blackhole 场景说明

本用例演示"TCP 源 → Blackhole 汇"的性能基准测试场景：使用 wpgen 通过 TCP 协议发送数据，wparse 以 daemon 模式接收并处理，输出到 blackhole 以测试可靠传输与解析的综合性能。

## 场景特点

- **TCP 源**：通过 TCP 协议发送数据，保证可靠传输
- **Daemon 模式**：wparse 作为守护进程持续接收数据
- **Blackhole 输出**：数据解析后丢弃，专注测试吞吐性能
- **双路源支持**：可配置双路 wpgen 模拟多源场景

## 目录结构

```
tcp_blackhole/
├── conf/
│   ├── wparse.toml     # 主配置
│   ├── wpgen.toml      # 第一路 TCP 输出配置
│   └── wpgen2.toml     # 第二路 TCP 输出配置（可选）
├── models/
│   ├── sinks/
│   │   ├── defaults.toml
│   │   ├── business.d/ # 业务组配置
│   │   └── infra.d/    # 基础组配置
│   └── sources/
│       └── wpsrc.toml  # TCP 源配置
├── data/
│   ├── out_dat/        # 输出目录
│   └── logs/           # 日志目录
└── run.sh              # 运行脚本
```

## 快速使用

```bash
cd benchmark

# 默认大规模测试（2000 万行）
./tcp_blackhole/run.sh

# 中等规模测试（20 万行）
./tcp_blackhole/run.sh -m

# 指定 worker 数量
./tcp_blackhole/run.sh -w 12

# 使用 sysmon 规则 + 限速 100 万行/秒
./tcp_blackhole/run.sh sysmon 1000000
```

## 参数说明

| 参数 | 说明 | 默认值 |
|------|------|--------|
| `-m` | 使用中等规模数据集 | 2000 万行 → 20 万行 |
| `-w <cnt>` | 指定 worker 数量 | daemon 默认 6 |
| `wpl_dir` | WPL 规则目录 | nginx |
| `speed` | 生成限速（行/秒） | 0（不限速） |

## 执行流程

1. 解析命令行参数
2. 初始化 release 环境
3. 验证 WPL 路径
4. 清理旧数据
5. 启动 `wparse daemon`（监听 TCP 端口）
6. 使用 `wpgen` 发送数据（可选双路）
7. 停止 daemon 并输出统计

## TCP 配置

### 源配置 (models/sources/wpsrc.toml)
```toml
[[sources]]
key = "tcp_src"
enable = true
connect = "tcp_src"

[sources.params]
addr = "127.0.0.1"
port = 9514
```

### 生成器配置 (conf/wpgen.toml)
```toml
[output]
connect = "tcp_sink"

[output.params]
addr = "127.0.0.1"
port = 9514
```

## 双路源模式

取消注释 run.sh 中的双路配置可启用双源测试：
```bash
# 单路（默认）
benchmark_run_daemon "$WPL_PATH" "$SPEED_MAX" "$LINE_CNT" "wpgen.toml"

# 双路
benchmark_run_daemon "$WPL_PATH" "$SPEED_MAX" "$LINE_CNT" "wpgen.toml" "wpgen2.toml"
```

## 与 syslog_blackhole 的区别

| 特性 | tcp_blackhole | syslog_blackhole |
|------|---------------|------------------|
| 协议 | TCP | UDP syslog |
| 可靠性 | 保证 | 不保证 |
| 性能 | 较低（连接管理） | 更高（无连接开销） |
| 流控 | 支持 | 不支持 |
| 适用场景 | 可靠传输 | 日志采集 |

## 性能调优

### TCP 缓冲区
```bash
# 增加 TCP 缓冲区（Linux）
sudo sysctl -w net.core.wmem_max=26214400
sudo sysctl -w net.core.rmem_max=26214400
```

### 连接复用
- TCP 支持连接复用，减少连接建立开销
- 适合长连接场景

## 相关文档
- [Benchmark 总览](../README.md)
- [syslog_blackhole](../syslog_blackhole/README.md)
- [TCP 源配置](../../wp-docs/80-reference/params/source_tcp.md)
