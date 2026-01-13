# Benchmark 用例指南

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
│   ├── sources/           # TCP 源配置
│   ├── parse_to_blackhole/
│   ├── parse_to_file/
│   ├── trans_to_blackhole/
│   └── trans_to_file/
├── case_file/             # File 数据源测试场景
│   ├── sources/           # File 源配置
│   ├── parse_to_blackhole/
│   ├── parse_to_file/
│   ├── trans_to_blackhole/
│   └── trans_to_file/
├── case_syslog/           # Syslog 数据源测试场景
│   ├── sources/           # Syslog 源配置
│   ├── parse_to_blackhole/
│   └── trans_to_blackhole/
└── wpgen_test/            # wpgen 性能测试
```

### 测试场景说明

**处理模式：**
- `parse`: 解析模式 - 使用 WPL 规则对日志进行解析和转换
- `trans`: 透传模式 - 不进行解析，直接转发原始数据

**输出目标：**
- `blackhole`: 黑洞输出 - 丢弃数据，用于测试纯解析/转发性能
- `file`: 文件输出 - 输出到文件，测试完整的处理链路

**示例：**
- `parse_to_blackhole`: 解析后丢弃，测试解析性能
- `parse_to_file`: 解析后写入文件，测试完整解析链路
- `trans_to_blackhole`: 透传后丢弃，测试转发性能
- `trans_to_file`: 透传后写入文件，测试完整转发链路

## 通用选项

所有测试脚本共享以下参数（由 `benchmark_common.sh` 中的 `benchmark_parse_args` 解析）：

- **`-m`**: 使用中等规模数据集（LINE_CNT=200,000 行）；默认使用大规模数据集（20,000,000 行）
- **`-f`**: 强制重新生成输入数据，即使 `./data/in_dat/*.dat` 已存在（部分脚本支持）
- **`-c <cnt>`**: 指定数据条数，与 `-m` 互斥，优先级更高
- **`-w <cnt>`**: 指定 wparse worker 数量
  - daemon 模式默认 6 worker
  - batch/blackhole 模式默认 10 worker
- **`wpl_dir`**: 指定 WPL 规则集目录（位置参数）
  - 可选值：`nginx`、`sysmon`、`apt`、`aws` 等
  - 默认值：`nginx`
  - 路径相对于 `benchmark/models/wpl/`
- **`speed`**: 样本生成限速（行/秒），0 表示不限速（位置参数，默认 0）

执行 `./run.sh -h` 可查看某个测试脚本支持的选项组合。

## 快速开始

### 1. 运行单个测试

```bash
cd benchmark

# 使用默认配置（nginx 规则，大规模数据集）
./case_tcp/parse_to_blackhole/run.sh

# 使用中等规模数据集
./case_tcp/parse_to_blackhole/run.sh -m

# 使用 sysmon 规则，12 个 worker，限速 1M 行/秒
./case_tcp/parse_to_blackhole/run.sh -w 12 sysmon 1000000

# 自定义数据量和 worker 数
./case_file/parse_to_file/run.sh -c 500000 -w 8
```

### 2. 批量测试所有场景

使用 `check_run.sh` 脚本自动运行所有测试用例（使用 `-m` 参数进行小数据测试）：

```bash
cd benchmark
./check_run.sh
```

**输出示例：**
```
========================================
Benchmark Check - Small Data Test
========================================

检查 case_tcp ...
  → 运行 case_tcp/parse_to_blackhole ...
    ✓ case_tcp/parse_to_blackhole 通过

  → 运行 case_tcp/parse_to_file ...
    ✓ case_tcp/parse_to_file 通过
  ...

========================================
测试总结
========================================
总测试数: 10
通过: 10
失败: 0

所有测试通过！
```

## 测试场景清单

### TCP 数据源测试（case_tcp）

| 测试场景 | 说明 | 配置文件 |
| --- | --- | --- |
| `parse_to_blackhole` | TCP 数据解析后丢弃，测试 TCP 接收 + 解析性能 | wpgen.toml, wparse.toml |
| `parse_to_file` | TCP 数据解析后写入文件 | wpgen.toml, wparse.toml |
| `trans_to_blackhole` | TCP 数据透传后丢弃，测试 TCP 接收 + 转发性能 | wpgen.toml, wparse.toml |
| `trans_to_file` | TCP 数据透传后写入文件 | wpgen.toml, wparse.toml |

**数据源：** wpgen 通过 TCP 连接（默认端口 19001）发送样本数据

### File 数据源测试（case_file）

| 测试场景 | 说明 | 配置文件 |
| --- | --- | --- |
| `parse_to_blackhole` | 文件数据解析后丢弃，测试文件读取 + 解析性能 | wpgen.toml, wparse.toml |
| `parse_to_file` | 文件数据解析后写入文件，测试完整 file-to-file 链路 | wpgen.toml, wparse.toml |
| `trans_to_blackhole` | 文件数据透传后丢弃 | wpgen.toml, wparse.toml |
| `trans_to_file` | 文件数据透传后写入文件 | wpgen.toml, wparse.toml |

**数据源：** wpgen 预先生成数据文件到 `./data/in_dat/`

### Syslog 数据源测试（case_syslog）

| 测试场景 | 说明 | 配置文件 |
| --- | --- | --- |
| `parse_to_blackhole` | Syslog UDP 数据解析后丢弃 | wpgen.toml, wparse.toml |
| `trans_to_blackhole` | Syslog UDP 数据透传后丢弃 | wpgen.toml, wparse.toml |

**数据源：** wpgen 通过 Syslog UDP 协议发送样本数据

### wpgen 性能测试（wpgen_test）

专门测试 wpgen 的样本数据生成能力，不启动 wparse。

## 配置文件说明

每个测试场景目录下通常包含：

```
<test_scenario>/
├── conf/
│   ├── wparse.toml    # wparse 引擎配置
│   └── wpgen.toml     # wpgen 数据生成配置
├── data/              # 运行时数据目录（自动创建）
│   ├── in_dat/        # 输入数据
│   ├── out_dat/       # 输出数据
│   ├── logs/          # 日志文件
│   └── rescue/        # 异常数据
├── .run/              # 运行时文件（PID 等）
└── run.sh             # 测试脚本
```

### wparse.toml 配置要点

```toml
[models]
wpl = "../../models/wpl"    # WPL 规则路径（相对于测试目录）
oml = "../../models/oml"    # OML 模型路径

[topology]
sources = "../sources"      # 数据源配置路径
sinks = "../../sinks/xxx"   # Sink 配置路径

[performance]
parse_workers = 6           # 解析 worker 数量
rate_limit_rps = 0          # 速率限制（0 表示不限制）
```

### wpgen.toml 配置要点

```toml
[generator]
mode = "sample"             # 生成模式
count = 1000                # 每批次数量
speed = 0                   # 生成速度限制
parallel = 4                # 并行度

[output]
connect = "tcp_sink"        # 连接器类型（tcp_sink/file_raw_sink 等）
params = { port = 19001 }   # 连接器参数
```

## 性能调优建议

### 确定最佳 Worker 数

1. 从 CPU 核心数开始测试
2. 使用不同 worker 数运行同一测试：
   ```bash
   ./case_tcp/parse_to_blackhole/run.sh -m -w 2
   ./case_tcp/parse_to_blackhole/run.sh -m -w 4
   ./case_tcp/parse_to_blackhole/run.sh -m -w 6
   ./case_tcp/parse_to_blackhole/run.sh -m -w 8
   ```
3. 对比吞吐量，找到性价比最优点

### 数据规模选择

- **开发/调试**：使用 `-m` 参数（20 万行），快速验证
- **性能测试**：使用默认规模（2000 万行）或自定义 `-c` 参数
- **压力测试**：使用 `-c` 指定更大数据量

### 避免 I/O 瓶颈

- `blackhole` 测试：测试纯计算性能，无 I/O 影响
- `file` 测试：注意磁盘 I/O 可能成为瓶颈
- 使用 SSD 或 RAM disk 可提升 I/O 性能

## 输出与校验

每个脚本会自动调用以下命令显示结果：

- `wproj data stat`: 打印数据统计信息（输入/输出条数、耗时等）
- `wproj validate sink-file`: 校验输出文件（仅限 file 输出场景）

若遇到数据残留导致统计不准，可手动执行：
```bash
wproj data clean   # 清理 wparse 数据
wpgen data clean   # 清理 wpgen 数据
```

或使用 `-f` 参数强制重新生成数据（部分脚本支持）。

## 常见问题

###  WPL 模型加载失败

检查 wparse.toml 中的 `wpl` 路径是否正确，应相对于测试目录：
```toml
[models]
wpl = "../../models/wpl"  # 正确
# wpl = "../../../models/wpl"  # 错误（旧配置）
```

###  数据生成失败

- 检查磁盘空间是否充足
- 确认 wpgen.toml 配置正确
- 查看 `./data/logs/` 下的日志文件

###  测试运行缓慢

- 使用 `-m` 参数减小数据规模
- 调整 `-w` 参数优化 worker 数
- 检查系统资源使用情况（CPU、内存、磁盘 I/O）

## 试题

|      |        | 原文   | wpl                                             | OML      |             |
| ---- | ------ | ------ | ----------------------------------------------- | -------- | ----------- |
| T1   | 二进制 | nginx  | 基础类型解析<br/>时间格式解析                   | 无       | 文件->文件  |
| T2   | 二进制 | Aws    | 基础类型解析<br/>时间格式解析<br/>字段管道解析  | 简单映射 | TCP->文件   |
| T3   | docker | 自定义 | JSON 数据解析<br/>字段管道解析<br/>复杂组合解析 | 复杂映射 | TCP->文件   |
| T4   | docker | 自定义 | 全种类解析                                      | 全 func  | KAFKA->VLOG |

T1

要求：

1、通过二进制执行 wparse命令，输入是文件，输出是文件

2、要求输出结果包括字段名和字段类型都完全一致

原文：

```cmd
[20/Feb/2018:12:12:14 +0800] 112.195.209.90 - -  "GET / HTTP/1.1" 200 190 "-" "Mozilla/5.0 (Linux; Android 6.0; Nexus 5 Build/MRA58N) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/63.0.3239.132 Mobile Safari/537.36" "-"
```

结果：

```
{
  "remote_addr": "112.195.209.90",
  "time_local": "2018-02-20 12:12:14",
  "request": "GET / HTTP/1.1",
  "status": "200",
  "body_bytes_sent": 190,
  "http_referer": "-",
  "http_user_agent": "Mozilla/5.0 (Linux; Android 6.0; Nexus 5 Build/MRA58N) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/63.0.3239.132 Mobile Safari/537.36",
  "http_x_forwarded_for": "-"
}
```



T2

1、通过二进制执行命令，输入是 TCP，输出是文件

2、TCP通过 wpgen 命令 发送

3、要求输出结果包括字段名和字段类型都完全一致

原文：

```cmd
http 2018-11-30T22:23:00.186641Z app/my-lb 192.168.1.10:2000 10.0.0.15:8080 0.01 0.02 0.01 200 200 100 200 "POST https://api.example.com/u?p=1&sid=2&t=3 HTTP/1.1" "Mozilla/5.0 (Win) Chrome/90" "ECDHE" "TLSv1.3" arn:aws:elb:us:123:tg "Root=1-test" "api.example.com" "arn:aws:acm:us:123:cert/short" 1 2018-11-30T22:22:48.364000Z "forward" "https://auth.example.com/r" "err" "10.0.0.1:80" "200" "cls" "rsn" TID_x1
```

结果:

```json
{
  "log_type": "http",
  "timestamp": 1543616580186,
  "elb": "app/my-lb",
  "client_host": "192.168.1.10:2000",
  "target_host": "10.0.0.15:8080",
  "request_processing_time": 0.01,
  "target_processing_time": 0.02,
  "response_processing_time": 0.01,
  "elb_status_code": "200",
  "target_status_code": "200",
  "received_bytes": 100,
  "sent_bytes": 200,
  "request_method": "POST",
  "request_url": "https://api.example.com/u?p=1&sid=2&t=3",
  "request_protocol": "HTTP/1.1",
  "user_agent": "Mozilla/5.0 (Win) Chrome/90",
  "ssl_cipher": "ECDHE",
  "ssl_protocol": "TLSv1.3",
  "target_group_arn": "arn:aws:elb:us:123:tg",
  "trace_id": "Root=1-test",
  "domain": "api.example.com",
  "chosen_cert_arn": "arn:aws:acm:us:123:cert/short",
  "matched_rule_priority": "1",
  "request_creation_time": "2018-11-30 22:22:48.364",
  "actions_executed": "forward",
  "redirect_url": "https://auth.example.com/r",
  "error_reason": "err",
  "target_port_list": "10.0.0.1:80",
  "target_status_code_list": "200",
  "classification": "cls",
  "classification_reason": "rsn",
  "traceability_id": "TID_x1"
}
```

T3

1、通过 docker 启动 wparse，输入是 TCP，输出是文件

2、TCP通过 wpgen 命令 发送

3、要求输出结果包括字段名和字段类型都完全一致

4、需要根据 sip 和 dip 判断内外网

原文：

```
{"update_time":"2024-12-03 10:23:22","access_ip":"0.0.0.0","packet_data":"dXNlcjphZG1pbiBwYXNzd29yZDoxMjM0NTY=","ip":"1.1.1.1:1111->10.0.0.1:2222","attack_result": "1","log_type":"flow_ty_attack"}
```

结果:

```json
{
  "log_type": "flow_ty_attack",
  "access_ip": "0.0.0.0",
  "sip": "1.1.1.1",
  "sport": 1111,
  "dip": "10.0.0.1",
  "dport": 2222,
  "user_name": "admin",
  "password": "123456",
  "update_time": "2024-12-03 10:23:22",
  "attack_result": "成功",
  "src_zone": "External",
  "dst_zone": "Internal"
}
```

T4

1、通过 docker 启动 wparse，输入是 KAFKA，输出是 MYSQL

2、KAFKA通过 wpgen 命令 发送

3、要求输出结果包括字段名和字段类型都完全一致

4、按提示完成 oml 转化

原文：

```
222.133.52.20 simple_chars 80 192.168.1.10 select_one left 2025-12-29 12:00:00 {"msg":"hello"} "" aGVsbG8gd29ybGQ= ["val1","val2","val3"] /home/user/file.txt  http://example.com/path/to/resource?foo=1&bar=2  [{"one":{"two":"nested"}}] foo bar baz qux 500 ext_value_1 ext_value_2  &lt;script&gt;  hello"world 12345
```

结果：

```json
{
	"direct_chars": "13", //直接赋值
	"direct_digit": 13,
	"simple_chars": "simple_chars",
	"simple_port": "simple_chars",
	"simple_ip": "192.168.1.10",
	"ip_ip4_to_int": 3232235786, //ip转int
	"html_unescape": "<script>", //html转码
	"html_escape": "&lt;script&gt;",
	"str_escape": "hello\\\"world",//转义
	"select_chars": "select_one",
	"match_chars": "1",
	"time": "2026-01-12 19:38:43.452811", //标准时间
	"date": 20260112, //日期
	"hour": 2026011219, //小时
	"timestamp": 1767009600000, //北京时间
	"timestamp1": 1766980800, //秒
	"timestamp2": 1766980800000, //毫秒
	"timestamp3": 1766980800000000, //微秒
	"timestamp4": 1768246851, //UTC+8秒
	"timestamp5": 1768246851009, //UTC+8毫秒
	"timestamp6": 1768246851009507, //UTC+8微秒
	"base64_en": "aGVsbG8=", //base64
	"base64_de": "hello",
	"array_get": "val1", //数组取值
	"array_str": "[\"val1\",\"val2\",\"val3\"]", //数组字符
	"name": "file.txt", //文件路径取值
	"path": "/path/to/resource",
	"domain": "example.com", //http取值
	"host": "example.com",
	"uri": "/path/to/resource?foo=1&bar=2",
	"params": "foo=1&bar=2",
	"obj": "nested", //多层取值
	"splice": "foo:bar|baz:qux", //字符拼接
	"num_range": "大于 0 小于 1000", //范围判断
	"extends": { //扩展字段
		"extend1": "ext_value_1",
		"extend2": "ext_value_2"
	}
}
```





