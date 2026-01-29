# MySQL

This directory provides an end-to-end TCP-based MySQL ingestion case to verify the unified TCP Source and MySQL Sink connectors work as expected.

- Producer: `wpgen` sends sample data via TCP protocol to a specified port (default 19001)
- Engine: `wparse` listens on TCP port to receive data, parses and routes to MySQL Sink for database ingestion
- Verification: Verify data is correctly ingested by querying MySQL

## Data Flow

The diagram below shows the tcp_mysql data flow and key components.

```mermaid
flowchart LR
    subgraph Producer
      WPGEN["wpgen sample<br/>(sends TCP data per wpgen.toml)"]
    end
    subgraph TCP
      TCP_PORT[(TCP Port<br/>19001)]
    end
    subgraph Engine
      WPARSE["wparse daemon<br/>(listens on TCP port)"]
      SINKS{{"Sink Group<br/>(models/sink)"}}
      OML[OML Mapping]
    end
    subgraph Database
      MYSQL[(MySQL<br/>nginx_logs table)]
    end

    WPGEN -- produce --> TCP_PORT
    TCP_PORT -- consume --> WPARSE
    WPARSE -- route --> OML --> SINKS
    SINKS -- write --> MYSQL
```

If Mermaid is not supported, refer to the ASCII version:

```
wpgen(sample) --> TCP(TCP:19001) --> wparse(daemon) --> [OML/route] --> sinks{mysql}
    sinks --> MySQL: nginx_logs table
```

## Directory Structure

- `conf/`
  - `wparse.toml`: Engine main config (directories/concurrency/logging, etc.)
  - `wpgen.toml`: Data generator config (points to TCP sink, configured with port)
- `topology/sources/wpsrc.toml`: Source routing (contains `tcp_1` listening on port 19001)
- `topology/sinks/business.d/all.toml`: Business sink routing (contains MySQL sink with column configuration)
- `models/oml/nginx.oml`: OML model (result field mapping/masking)
- `models/wpl/nginx/`: WPL parsing rules and sample data
- `preparatory_work.sql`: MySQL table schema definition
- `run.sh`: One-click run script

Note: Source and Sink connector IDs reference definitions in the repository root `connectors/` directory:
- `connectors/source.d/20-tcp.toml`: id=`tcp_src` (allows overriding `port/prefer_newline`)
- `connectors/sink.d/20-mysql.toml`: id=`mysql_sink` (allows overriding `table/columns/dsn`, etc.)

## Prerequisites

- MySQL running locally, default address `127.0.0.1:3306` (or override via environment variables, see below)
- Ensure the `nginx_logs` table is created in the target database (execute `create_table.sql`)
- Note: Custom database tables require a mandatory `wp_event_id` field as primary key with BIGINT type

## Quick Start

Enter the case directory and run the script (default `debug`):

```bash
cd extensions/tcp_mysql
./run.sh            # or ./run.sh release
```

Main script steps:
1) `wproj check` for config self-check, clean data directory
2) Start `wparse daemon` in background (listening on TCP port 19001)
3) Run `wpgen sample` to generate sample data and send via TCP
4) Wait for data ingestion, stop `wparse`
5) Run `wproj data stat` and `wproj data validate` for verification

## Parameters

The script supports the following optional environment variables:

- `LINE_CNT`: Number of sample records to generate/process, default `100`
- `SPEED_MAX`: Maximum send rate (records/sec), default `5000`

Example:

```bash
LINE_CNT=1000 SPEED_MAX=10000 ./run.sh
```

## Configuration

### wpgen.toml (Data Generator Config)

```toml
[generator]
mode = "sample"
count = 1000        # Number of samples to generate
speed = 0           # Send rate limit, 0 means unlimited
parallel = 4        # Concurrency

[output]
name = "gen_out"
connect = "tcp_sink"
params = { port = 19001 }
```

### wparse.toml (Engine Config)

```toml
[models]
wpl = "./models/wpl"
oml = "./models/oml"

[topology]
sources = "./topology/sources"
sinks = "./topology/sinks"

[performance]
parse_workers = 2   # Parse concurrency
rate_limit_rps = 0  # Rate limit, 0 means unlimited
```

### topology/sinks/business.d/all.toml (MySQL Sink Config)

```toml
[sink_group]
name = "all"
rule = ["/*"]
parallel = 8

[[sink_group.sinks]]
name = "main"
connect = "mysql_sink"
params = {
    columns = ["sip", "timestamp", "http/request", "status", "size", "referer", "http/agent", "wp_event_id"]
}
```

## Database Setup

Execute the following SQL to create the target table:

```bash
mysql -h 127.0.0.1 -u root -p wparse < preparatory_work.sql
```

Or copy the contents of `preparatory_work.sql` directly into the MySQL client.

## Result Verification

- MySQL ingestion verification: Connect to the database and query the `nginx_logs` table to confirm record count and data

```bash
mysql -h 127.0.0.1 -u root -p your_database -e "SELECT COUNT(*) FROM nginx_logs; SELECT * FROM nginx_logs LIMIT 100;"
```

- Data statistics: `wproj data stat` outputs processing statistics for each stage
- Data validation: `wproj data validate` verifies input/output data consistency

## FAQ

- **Connection failed**: Confirm MySQL service is running, user has access to the target database, and the table has been created
- **Port conflict**: Ensure port 19001 is not in use, or modify the port in `topology/sources/wpsrc.toml`
- **No data ingested**: Check log files under `data/logs/` to confirm TCP connection and parsing are working
- **Field mismatch**: Verify that `columns` in `topology/sinks/business.d/all.toml` matches the `create_table.sql` table structure

---

# MySQL (中文)

本目录提供一套基于 TCP 传输的端到端 MySQL 入库用例，验证统一 TCP Source 与 MySQL Sink 连接器是否按预期工作。

- 发送端：`wpgen` 将样例数据通过 TCP 协议发送到指定端口（默认 19001）
- 引擎端：`wparse` 监听 TCP 端口接收数据，解析并路由到 MySQL Sink 完成入库
- 验证端：通过 MySQL 查询验证数据是否正确入库

## 数据流图

下图展示 tcp_mysql 的数据流与关键环节。

```mermaid
flowchart LR
    subgraph Producer
      WPGEN["wpgen sample<br/>(按 wpgen.toml 发送 TCP 数据)"]
    end
    subgraph TCP
      TCP_PORT[(TCP 端口<br/>19001)]
    end
    subgraph Engine
      WPARSE["wparse daemon<br/>(监听 TCP 端口)"]
      SINKS{{"Sink Group<br/>(models/sink)"}}
      OML[OML 映射/脱敏]
    end
    subgraph Database
      MYSQL[(MySQL<br/>nginx_logs 表)]
    end

    WPGEN -- produce --> TCP_PORT
    TCP_PORT -- consume --> WPARSE
    WPARSE -- route --> OML --> SINKS
    SINKS -- write --> MYSQL
```

如渲染不支持 Mermaid，可参考 ASCII 版：

```
wpgen(sample) --> TCP(TCP:19001) --> wparse(daemon) --> [OML/route] --> sinks{mysql}
    sinks --> MySQL: nginx_logs 表
```

## 目录结构

- `conf/`
  - `wparse.toml`：引擎主配置（目录/并发/日志等）
  - `wpgen.toml`：数据生成器配置（已指向 TCP sink，并配置端口）
- `topology/sources/wpsrc.toml`：Source 路由（包含 `tcp_1` 监听 19001 端口）
- `topology/sinks/business.d/all.toml`：业务 Sink 路由（包含 MySQL sink，配置入库字段）
- `models/oml/nginx.oml`：OML 模型（结果字段映射/脱敏）
- `models/wpl/nginx/`：WPL 解析规则与样例数据
- `preparatory_work.sql`：MySQL 表结构定义
- `run.sh`：一键运行脚本

说明：Source 与 Sink 连接器 id 引用仓库根目录 `connectors/` 下的定义：
- `connectors/source.d/20-tcp.toml`：id=`tcp_src`（允许覆写 `port/prefer_newline`）
- `connectors/sink.d/20-mysql.toml`：id=`mysql_sink`（允许覆写 `table/columns/dsn` 等）

## 前置要求

- 本机已启动 MySQL，默认地址 `127.0.0.1:3306`（或通过环境变量覆盖，见下文）
- 确保目标数据库中已创建 `nginx_logs` 表（执行 `create_table.sql`）
- 注意自定义数据库表需要其中必要的字段`wp_event_id`作为主键且为BIGINT类型

## 快速开始

进入用例目录并运行脚本（默认 `debug`）：

```bash
cd extensions/tcp_mysql
./run.sh            # 或 ./run.sh release
```

脚本主要步骤：
1) `wproj check` 进行配置自检，清理数据目录
2) 后台启动 `wparse daemon`（监听 TCP 19001 端口）
3) 执行 `wpgen sample` 生成样例数据并通过 TCP 发送
4) 等待数据入库，停止 `wparse`
5) 执行 `wproj data stat` 与 `wproj data validate` 进行校验

## 运行参数

脚本支持以下可选环境变量：

- `LINE_CNT`：生成/处理的样例条数，默认 `100`
- `SPEED_MAX`：最大发送速率（条/秒），默认 `5000`

示例：

```bash
LINE_CNT=1000 SPEED_MAX=10000 ./run.sh
```

## 配置说明

### wpgen.toml（数据生成器配置）

```toml
[generator]
mode = "sample"
count = 1000        # 生成样例数量
speed = 0           # 发送速率限制，0 表示不限速
parallel = 4        # 并发数

[output]
name = "gen_out"
connect = "tcp_sink"
params = { port = 19001 }
```

### wparse.toml（引擎配置）

```toml
[models]
wpl = "./models/wpl"
oml = "./models/oml"

[topology]
sources = "./topology/sources"
sinks = "./topology/sinks"

[performance]
parse_workers = 2   # 解析并发数
rate_limit_rps = 0  # 限速，0 表示不限速
```

### topology/sinks/business.d/all.toml（MySQL Sink 配置）

```toml
[sink_group]
name = "all"
rule = ["/*"]
parallel = 8

[[sink_group.sinks]]
name = "main"
connect = "mysql_sink"
params = {
    columns = ["sip", "timestamp", "http/request", "status", "size", "referer", "http/agent", "wp_event_id"]
}
```

## 数据库准备

执行以下 SQL 创建目标表：

```bash
mysql -h 127.0.0.1 -u root -p wparse < preparatory_work.sql
```

或直接复制 `preparatory_work.sql` 内容到 MySQL 客户端执行。

## 结果验证

- MySQL 入库验证：连接数据库查询 `nginx_logs` 表，确认记录数与数据内容

```bash
mysql -h 127.0.0.1 -u root -p your_database -e "SELECT COUNT(*) FROM nginx_logs; SELECT * FROM nginx_logs LIMIT 100;"
```

- 数据统计：`wproj data stat` 会输出各阶段处理统计
- 数据校验：`wproj data validate` 会校验输入输出数据一致性

## 常见问题排查

- **连接失败**：确认 MySQL 服务已启动，用户有目标数据库访问权限，表已创建
- **端口冲突**：确保 19001 端口未被占用，或修改 `topology/sources/wpsrc.toml` 中的端口配置
- **无数据入库**：检查 `data/logs/` 下的日志文件，确认 TCP 连接与解析是否正常
- **字段不匹配**：确认 `topology/sinks/business.d/all.toml` 中的 `columns` 与 `create_table.sql` 表结构一致
