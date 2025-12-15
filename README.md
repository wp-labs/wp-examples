# WP-Example - WarpParse 示例项目

[![Rust](https://img.shields.io/badge/rust-1.70+-orange.svg)](https://www.rust-lang.org)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

WarpParse 日志解析引擎的示例项目，展示如何使用 WPL（WarpParse Programming Language）进行高性能日志解析和处理。

## 🚀 项目概述

WP-Example 是一个基于 WarpParse 引擎的日志解析示例项目，提供了完整的日志生成、解析、转换和输出功能。项目支持多种数据源和输出目标，适用于日志处理、数据流转换和实时监控场景。

### 核心特性

- **高性能日志解析**：基于 WPL 语法的结构化日志解析
- **多数据源支持**：文件、TCP/UDP、Kafka 等多种输入源
- **灵活输出**：支持 JSON、KV、Raw、Protobuf 等多种输出格式
- **实时处理**：支持流式数据处理和批量处理模式
- **可扩展架构**：模块化设计，支持自定义扩展

## 📁 项目结构

```
wp-example/
├── benchmark/                 # 性能测试和基准测试
│   ├── models/               # 测试模型和规则
│   │   └── wpl/             # WPL 解析规则文件
│   ├── syslog_blackhole/    # Syslog 到 Blackhole 测试
│   ├── file_file/          # 文件到文件测试
│   ├── tcp_blackhole/      # TCP 到 Blackhole 测试
│   └── wpls_test/          # WPL 测试套件
├── core/                     # 核心配置和示例
│   ├── getting_started/     # 入门示例
│   ├── oml_examples/        # OML 配置示例
│   └── wpl_missing/         # WPL 缺失场景测试
├── connectors/               # 连接器配置
│   └── sink.d/             # 输出连接器配置
├── extensions/              # 扩展插件
├── script/                  # 通用脚本
│   └── common.sh           # 通用函数库
└── report/                  # 测试报告
    └── benchmark.md        # 性能基准报告
```

## 🛠️ 快速开始

### 环境要求

- Rust 1.70+
- Cargo
- Linux/macOS



### 运行示例

1. **快速入门示例**
   ```bash
   cd core/getting_started
   ./run.sh
   ```

2. **性能基准测试**
   ```bash
   # 文件到文件测试
   cd benchmark/file_file
   ./run.sh  nginx 100000

   # TCP 到 Blackhole 测试
   cd benchmark/tcp_blackhole
   ./run.sh nginx 300000 
   ```

3. **自定义 WPL 规则测试**
   ```bash
   cd benchmark/wpls_test
   ./run.sh -m 100000 -s 5000
   ```

## 📖 使用指南

### WPL 规则语法

WPL（Warp  Parse  Language）是用于定义日志解析规则的 DSL：

```wpl
package /nginx {
    rule access_log {
        (ip:client_ip, timestamp, chars:method, chars:uri,
         int:status, int:body_size, chars:user_agent, chars:referer)
    }

    rule error_log {
        (timestamp, level, chars:pid, chars:tid, chars:message)
    }
}
```

### 配置文件说明

#### 解析器配置 (wparse.toml)

```toml
version = "1.0"
robust = "normal"

[models]
wpl = "./models/wpl"        # WPL 规则目录
oml = "./models/oml"        # OML 配置目录
sources = "./models/sources"  # 输入源配置
sinks = "./models/sinks"     # 输出目标配置

[performance]
rate_limit_rps = 10000      # 每秒处理限制
parse_workers = 2           # 解析工作线程数

[log_conf]
level = "info"              # 日志级别
output = "File"             # 日志输出方式
```

#### 数据生成配置 (wpgen.toml)

```toml
[generator]
mode = "rule"               # 生成模式：rule/random
count = 1000               # 生成数据行数
speed = 1000               # 生成速度（行/秒）

[output]
connect = "file_raw_sink"   # 输出连接器

[output.params]
base = "data/in_dat"        # 输出目录
file = "gen.dat"           # 输出文件名
```

### 连接器配置

支持多种输入输出连接器：

- **文件连接器**：`file_raw_sink`, `file_json_sink`, `file_kv_sink`
- **网络连接器**：`tcp_sink`, `udp_sink`, `syslog_tcp`, `syslog_udp`
- **消息队列**：`kafka_sink`
- **监控**：`prometheus_sink`
- **测试**：`blackhole_sink`

示例连接器配置：

```toml
[[connectors]]
id = "file_output"
type = "file"
format = "json"

[connectors.params]
path = "./data/output"
file_pattern = "output-%Y%m%d-%H%M%S.log"
```

## 📊 性能基准

基于项目内置的性能测试结果：

| 测试场景 | 日志大小 | 平台 | EPS | MPS | CPU | 内存 |
|---------|---------|------|-----|-----|-----|------|
| File → File | 259B | Mac M4 | - | - | - | - |
| TCP → Blackhole | 259B | Mac M4 | - | - | - | - |

详细的性能报告请参考 [`report/benchmark.md`](report/benchmark.md)

## 🔧 开发指南

### 添加新的测试用例

1. **创建测试目录**
   ```bash
   mkdir benchmark/new_test
   cd benchmark/new_test
   ```

2. **准备 WPL 规则**
   ```bash
   mkdir -p models/wpl
   # 添加 .wpl 规则文件
   ```

3. **创建运行脚本**
   ```bash
   # 复制现有测试的 run.sh 作为模板
   cp ../file_file/run.sh .
   # 修改配置参数
   ```

4. **运行测试**
   ```bash
   ./run.sh -m 100000 -s 10000
   ```

### 调试和监控

1. **日志级别调整**
   ```bash
   # 在 wparse.toml 中调整日志级别
   [log_conf]
   level = "debug,ctrl=info,launch=info"
   ```

2. **性能监控**
   ```bash
   # 启用统计信息
   [stat]
   window_sec = 60

   [[stat.parse]]
   key = "parse_stat"
   target = "*"
   ```


---

**注意**：这是一个示例项目，主要用于演示 WarpParse 引擎的使用方法。生产环境使用请参考 WarpParse 主项目文档。
