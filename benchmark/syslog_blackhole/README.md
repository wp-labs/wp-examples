# syslog_blackhole 场景说明

本用例演示"Syslog UDP 源 → Blackhole 汇"的性能基准测试场景：使用 wpgen 通过 UDP syslog 协议发送数据，wparse 以 daemon 模式接收并处理，输出到 blackhole 以测试网络接收与解析的综合性能。

## 场景特点

- **Syslog UDP 源**：通过 UDP syslog 协议发送数据
- **Daemon 模式**：wparse 作为守护进程持续接收数据
- **Blackhole 输出**：数据解析后丢弃，专注测试吞吐性能
- **网络压测**：测试网络接收与解析的综合能力

## 目录结构

```
syslog_blackhole/
├── conf/
│   └── wpgen1.toml     # syslog 输出配置
├── models/
│   ├── sinks/
│   │   ├── defaults.toml
│   │   └── infra.d/    # 基础组配置
│   └── sources/
│       └── wpsrc.toml  # syslog 源配置
├── data/
│   └── logs/           # 日志目录
└── run.sh              # 运行脚本
```

## 快速使用

```bash
cd benchmark

# 默认大规模测试（2000 万行）
./syslog_blackhole/run.sh

# 中等规模测试（20 万行）
./syslog_blackhole/run.sh -m

# 指定 worker 数量
./syslog_blackhole/run.sh -w 8

# 使用 sysmon 规则 + 限速 50 万行/秒
./syslog_blackhole/run.sh sysmon 500000
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
5. 启动 `wparse daemon`（监听 UDP syslog）
6. 使用 `wpgen` 发送数据
7. 停止 daemon 并输出统计

## Syslog 配置

### 源配置 (models/sources/wpsrc.toml)
```toml
[[sources]]
key = "syslog_src"
enable = true
connect = "syslog_udp_src"

[sources.params]
addr = "127.0.0.1"
port = 1514
```

### 生成器配置 (conf/wpgen1.toml)
```toml
[output]
connect = "syslog_udp_sink"

[output.params]
addr = "127.0.0.1"
port = 1514
```

## 注意事项

### UDP 丢包
- 高速发送时可能出现 UDP 丢包
- 可通过 `speed` 参数限速降低丢包率
- 检查系统 UDP 缓冲区配置

### 系统调优
```bash
# 增加 UDP 缓冲区（Linux）
sudo sysctl -w net.core.rmem_max=26214400
sudo sysctl -w net.core.rmem_default=26214400
```

## 与 tcp_blackhole 的区别

| 特性 | syslog_blackhole | tcp_blackhole |
|------|------------------|---------------|
| 协议 | UDP syslog | TCP |
| 可靠性 | 不保证 | 保证 |
| 性能 | 更高（无连接开销） | 较低（连接管理） |
| 适用场景 | 日志采集 | 可靠传输 |

## 相关文档
- [Benchmark 总览](../README.md)
- [tcp_blackhole](../tcp_blackhole/README.md)
- [Syslog 源配置](../../wp-docs/80-reference/params/source_syslog.md)
