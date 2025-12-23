# getting_started 说明

本用例用于“快速初始化 + 基准验证”。包含最小的源文件、基础的 sinks 组（default/miss/residue/intercept/error/monitor）以及示例业务路由（如有）。

## 目录结构

```
core/getting_started/
├── README.md                    # 本说明文档
├── run.sh                       # 一键运行脚本
├── conf/                        # 配置文件目录
│   ├── wparse.toml             # WarpParse 主配置
│   └── wpgen.toml              # 数据生成器配置
├── models/                      # 模型定义目录
│   ├── wpl/                    # WPL（WarpParse Language）模型定义
│   ├── oml/                    # OML（Object Mapping Language）模型定义
│   │   └── benchmark.oml       # 基准测试规则
│   ├── sources/                # 数据源配置
│   │   └── wpsrc.toml          # 数据源定义（文件/系统日志）
│   └── sinks/                  # 数据汇配置
│       ├── defaults.toml       # 默认配置
│       ├── infra.d/            # 基础设施 sinks
│       │   ├── default.toml    # 默认数据汇
│       │   ├── miss.toml       # 缺失数据处理
│       │   ├── residue.toml    # 残留数据处理
│       │   ├── error.toml      # 错误数据处理
│       │   └── monitor.toml    # 监控数据处理
│       └── business.d/         # 业务 sinks
│           ├── business.toml   # 业务数据处理
│           └── example/        # 示例业务处理
│               └── simple.toml # 简单示例
├── data/                        # 数据目录
│   ├── in_dat/                  # 输入数据目录
│   │   └── gen.dat             # 生成的测试数据
│   ├── out_dat/                 # 输出数据目录
│   │   ├── default.dat         # 默认输出
│   │   ├── miss.dat            # 缺失数据输出
│   │   ├── residue.dat         # 残留数据输出
│   │   ├── error.dat           # 错误数据输出
│   │   ├── monitor.dat         # 监控数据输出
│   │   └── business.dat        # 业务数据输出
│   ├── logs/                    # 日志文件目录
│   │   ├── wparse.log          # WarpParse 运行日志
│   │   └── wpgen.log           # 数据生成器日志
│   └── rescue/                  # 救援数据目录
│       └── *.rescue            # 救援数据文件
├── .run/                        # 运行时数据目录
│   ├── authority.sqlite        # 权限数据库
│   └── rule_mapping.dat        # 规则映射数据
├── sink.d/                      # sinks 目录符号链接
└── source.d/                    # sources 目录符号链接
```

## 快速开始

### 运行环境要求

- WarpParse 引擎（需在系统 PATH 中）
- Bash shell 环境
- 基础系统工具（awk, grep, wc 等）

### 运行命令

```bash
# 进入用例目录
cd usecase/core/getting_started

# 运行完整流程（默认生成 3000 条测试数据）
./run.sh

# 或指定生成的数据条数
./run.sh 5000
```

### 运行选项

`run.sh` 脚本支持以下参数：

- **无参数**：使用默认值（生成 3000 条数据）
- **数字参数**：指定生成的数据条数（如 `./run.sh 5000`）

## 执行逻辑

### 流程概览

`run.sh` 脚本执行以下主要步骤：

1. **环境初始化**
   - 保留必要的配置文件（wparse.toml, wpgen.toml）
   - 清理历史运行数据
   - 创建必要的目录结构
   - 设置符号链接（sink.d, source.d）

2. **WarpParse 服务初始化**
   - 使用 `wparse init` 初始化服务
   - 创建权限数据库和规则映射

3. **配置与数据清理**
   - 清空输入输出数据目录
   - 重置日志文件
   - 清理救援数据目录

4. **生成测试数据**
   - 使用 `wpgen` 根据配置生成测试数据
   - 默认生成 3000 条基准测试日志
   - 数据保存到 `data/in_dat/gen.dat`

5. **验证输入数据**
   - 检查生成的数据条数
   - 确保数据格式正确

6. **执行数据处理**
   - 启动 WarpParse 引擎
   - 加载 WPL/OML 模型
   - 处理输入数据并分发到各 sinks

7. **验证输出结果**
   - 检查各个 sinks 的输出文件
   - 验证数据处理的完整性
   - 统计处理结果

### 数据流向

```
输入数据 (data/in_dat/gen.dat)
    ↓
WarpParse 引擎
    ↓
┌─────────────┬─────────────┬─────────────┐
│  default    │    miss     │   residue   │
│    sink     │    sink     │    sink     │
└─────────────┴─────────────┴─────────────┘
┌─────────────┬─────────────┬─────────────┐
│    error    │   monitor   │   business  │
│    sink     │    sink     │    sink     │
└─────────────┴─────────────┴─────────────┘
```

### 关键处理节点

1. **数据源处理**
   - 文件数据源：读取 `gen.dat` 中的日志数据
   - 系统日志源：实时接收系统日志（本例中未启用）

2. **OML 规则匹配**
   - `/benchmark*` 规则匹配特定格式的日志
   - 自动提取并处理数据

3. **Sinks 分发**
   - **default**：正常处理的数据
   - **miss**：未被规则匹配的数据
   - **residue**：处理后的剩余数据
   - **error**：处理过程中产生的错误
   - **monitor**：性能和状态监控数据
   - **business**：业务相关的处理结果

## 配置说明

### 主配置文件 (conf/wparse.toml)

```toml
version = "1.0"
robust = "normal"

[models]
wpl = "./models/wpl"      # WPL 模型目录
oml = "./models/oml"      # OML 模型目录
sources = "./models/sources"  # 数据源配置目录
sinks = "./models/sinks"      # 数据汇配置目录

[performance]
rate_limit_rps = 10000    # 速率限制（请求/秒）
parse_workers = 2         # 解析工作线程数

[rescue]
path = "./data/rescue"    # 救援数据存储路径

[log_conf]
level = "warn,ctrl=info"
output = "File"          # 日志输出方式

[stat]
window_sec = 60          # 统计窗口时间（秒）
```

### 数据生成器配置 (conf/wpgen.toml)

```toml
[generator]
mode = "rule"           # 生成模式：rule 或 random
count = 1000           # 生成数据条数
speed = 1000           # 生成速度（条/秒）
parallel = 1           # 并行数

[output]
connect = "file_raw_sink"  # 输出连接器

[output.params]
base = "data/in_dat"       # 输出基准路径
file = "gen.dat"          # 输出文件名
```

### OML 规则示例 (models/oml/benchmark.oml)

```oml
name : /oml/benchmark
rule : /benchmark*
---
* : auto = take() ;
```

该规则定义了：
- **name**：规则的唯一标识符
- **rule**：匹配以 `/benchmark` 开头的日志
- **动作**：`take()` 表示提取并处理匹配的数据

### Sinks 配置结构

每个 sink 配置文件包含：

```toml
version = "2.0"

[sink]
name = "default"              # sink 名称
type = "file_raw_sink"        # sink 类型
connect = "default_sink"      # 连接器名称

[sink.params]
base = "data/out_dat"         # 输出基准路径
file = "default.dat"          # 输出文件名
```

### 数据源配置 (models/sources/wpsrc.toml)

支持两种数据源：

1. **文件数据源**（默认启用）
   - 读取本地文件中的日志数据
   - 适合批量处理场景

2. **系统日志源**（默认禁用）
   - 实时接收系统日志
   - 适合实时流处理场景

## 验证与故障排除

### 运行成功验证

运行完成后，可以通过以下方式验证是否成功：

1. **输出文件统计**
```
wproj data stat 
```
```
== Sources ==
| Key       | Enabled | Lines | Path                  | Error |
|-----------|---------|-------|-----------------------|-------|
| demo_file |    Y    |  3000 | ./data/in_dat/gen.dat |   -   |
Total enabled lines: 3000

== Sinks ==
business   | business/out_kv           | ././data/out_dat/demo.kv                      | 2000
business   | /example//proto           | ././data/out_dat/simple.dat                   | 1000
business   | /example//kv              | ././data/out_dat/simple.kv                    | 1000
business   | /example//json            | ././data/out_dat/simple.json                  | 1000
infras     | default/[0]               | ././data/out_dat/default.dat                  | 0
infras     | error/[0]                 | ././data/out_dat/error.dat                    | 0
infras     | miss/[0]                  | ././data/out_dat/miss.dat                     | 0
infras     | monitor/[0]               | ././data/out_dat/monitor.dat                  | 0
infras     | residue/[0]               | ././data/out_dat/residue.dat                  | 0
```

2. **查看运行日志**
   ```bash
   # WarpParse 运行日志
   tail -f data/logs/wparse.log

   # 数据生成器日志
   tail -f data/logs/wpgen.log
   ```

3. **验证数据完整性**

```
wproj data  validate
```
```
wproj data validate
validate: PASS
Total input: 3000 (source=override)

| Sink            | Actual | Expected  | Lines/Denom | Verdict |
|-----------------|--------|-----------|-------------|---------|
| /example//proto |  0.333 | 0.33±0.02 |  1000/3000  |    OK   |
| /example//kv    |  0.333 | 0.33±0.02 |  1000/3000  |    OK   |
| /example//json  |  0.333 | 0.33±0.02 |  1000/3000  |    OK   |
| default/[0]     |    0   |   0±0.02  |    0/3000   |    OK   |
| error/[0]       |    0   | 0.01±0.02 |    0/3000   |    OK   |
| miss/[0]        |    0   | [0 ~ 0.1] |    0/3000   |    OK   |
| monitor/[0]     |    0   |  [0 ~ 1]  |    0/3000   |    OK   |
```

### 常见问题与解决方案

#### 1. WarpParse 命令未找到

**错误信息**：`wparse: command not found`

**解决方案**：
- 确保 WarpParse 已正确安装
- 将 WarpParse 添加到系统 PATH 中
- 或使用完整路径运行

#### 2. 权限不足

**错误信息**：`Permission denied`

**解决方案**：
```bash
chmod +x run.sh
chmod -R 755 data/
```

#### 3. 数据生成失败

**可能原因**：
- wpgen 配置错误
- 磁盘空间不足
- 并发数设置过高

**解决方案**：
- 检查 `conf/wpgen.toml` 配置
- 清理磁盘空间
- 降低 parallel 参数值
