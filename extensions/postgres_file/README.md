# Postgres to File

本目录提供一套基于 PostgreSQL 的端到端数据采集与解析入库用例，验证统一 Postgres Source 与 File Sink 连接器是否按预期工作。

- 数据源：`wparse` 通过 Postgres Source 连接器从 PostgreSQL 数据库中增量拉取数据（基于游标 `cursor_column`）
- 引擎端：`wparse` 解析数据并路由到多个 Sink 完成入库
- 验证端：通过 `wproj data stat` 与 `wproj data validate` 校验数据一致性

## 数据流图

下图展示 postgres_file 的数据流与关键环节。

```mermaid
graph LR
    subgraph DB[Database]
        A[PostgreSQL<br/>nginx_logs]
    end
    subgraph E[Engine]
        B[wparse daemon]
        C[Sinks]
    end
    subgraph F[File Storage]
    end

    A -->|增量拉取| B
    B --> C
```

如渲染不支持 Mermaid，可参考 ASCII 版：

```
PostgreSQL(nginx_logs) --> wparse(daemon) --> Sinks
                                              ├──> demo.json (业务数据)
```

## 目录结构

- `conf/`
  - `wparse.toml`：引擎主配置（目录/并发/日志/统计等）
  - `wpgen.toml`：数据生成器配置（可选的离线数据生成，指向 `file_json_sink`）本示例由于是从数据库中增量读取，所以本配置暂时用不上
- `topology/sources/wpsrc.toml`：Source 路由（包含 `postgres_nginx_log_src`，连接 PostgreSQL 并配置游标增量拉取）
- `topology/sinks/business.d/demo.toml`：业务 Sink 路由（JSON 文件输出）
- `topology/sinks/defaults.toml`：默认 Sink 标签与期望配置
- `topology/sinks/infra.d/`：基础设施 Sink（默认/错误/未命中/监控/残留）
  - `default.toml`：全量数据输出
  - `error.toml`：解析错误数据
  - `miss.toml`：未命中规则数据
  - `monitor.toml`：监控指标数据
  - `residue.toml`：残留数据输出
- `models/oml/example.oml`：OML 模型（字段映射与自动提取）
- `models/wpl/parse.wpl`：WPL 解析规则
- `models/wpl/sample.dat`：样例数据（用于离线 `wpgen sample`）
- `models/knowledge/`：知识库配置与示例数据

说明：Source 连接器 id 引用仓库根目录 `connectors/` 下的定义：

- `connectors/source.d/60-postgres.toml`：id=`postgres_src`（允许覆写 `endpoint/username/password/database/table/schema/batch/cursor_column/cursor_type/start_from/start_from_format`）

字段解释如下：
  - `endpoint`：PostgreSQL 数据库地址，形如 `host:port`，默认 `localhost:5432`
  - `username`：数据库用户名，默认 `postgres`
  - `password`：数据库密码，默认 `123456`
  - `database`：数据库名，默认 `wparse`
  - `schema`：Schema 名称，默认 `public`
  - `table`：源表名，默认 `nginx_logs`
  - `batch`：每批次拉取行数，默认 `1000`
  - `cursor_column`：增量游标列名，用于记录已拉取位置，默认 `wp_event_id`
  - `cursor_type`：游标类型，支持 `int`（整数递增）和 `time`（时间戳递增），默认 `int`
  - `start_from`：首次启动且无 checkpoint 时的拉取起点（可选）
  - `start_from_format`：`start_from` 的输入格式，仅 `time` 游标使用，支持 `unix_s`（Unix 秒）等（可选）
  - `poll_interval_ms`：空轮询间隔（毫秒），默认 `1000`
  - `error_backoff_ms`：查询失败后的退避间隔（毫秒），默认 `2000`

## 增量拉取机制

Postgres Source 使用**游标（Cursor）**机制实现增量数据拉取：

1. **游标列**：指定一个单调递增列（如自增 ID 或时间戳）作为游标
2. **Checkpoint**：每次成功拉取后，将当前游标值持久化到 `.run/.checkpoints/` 目录下的 JSON 文件中
3. **断点续传**：重启后从上次 checkpoint 记录的游标值继续拉取，避免重复或遗漏
4. **空轮询**：当无新数据时，按 `poll_interval_ms` 间隔等待后继续轮询
5. **错误退避**：查询失败时，按 `error_backoff_ms` 间隔退避后重试

## 前置要求

- 本机已启动 PostgreSQL 服务，默认地址 `127.0.0.1:5432`
- 确保 PostgreSQL 数据库可访问，且数据库`wparse`以及源表 `nginx_logs` 已存在
- 源表需包含游标列（如 `wp_event_id`），用于增量拉取
- 可以使用 `POSTGRES_URL` 环境变量覆盖数据库连接串，格式：`postgres://user:pass@host:port/database`

## 快速开始

进入用例目录并启动引擎：

```bash
cd extensions/postgres_file
wparse daemon
```

主要步骤：

1) `wproj check` 进行配置自检，清理数据目录
2) 启动 `wparse daemon`（连接 PostgreSQL 并开始增量拉取）
3) 引擎按批次拉取数据、解析并路由到各 Sink 输出
4) 停止 `wparse`（Ctrl+C）
5) 查看输出文件`data/out_dat/demo.json`中数据条数是否与数据库表中数据条数一致

## 配置说明

### wparse.toml（引擎配置）

```toml
[models]
wpl = "./models/wpl"
oml = "./models/oml"
knowledge = "./models/knowledge"

[topology]
sources = "./topology/sources"
sinks = "./topology/sinks"

[performance]
rate_limit_rps = 10000
parse_workers = 2
reload_timeout_ms = 10000
fetch_timeout_ms = 300

[rescue]
path = "./data/rescue"

[log_conf]
level = "warn,ctrl=info,data=error,matrc=error,dfx=warn,kdb=warn"
output = "File"

[log_conf.file]
path = "./data/logs/"
```

### topology/sources/wpsrc.toml（Source 配置）

```toml
[[sources]]
enable = true
key = "postgres_nginx_log_src"
connect = "postgres_src"
params = {
    endpoint = "127.0.0.1:5432",
    username = "postgres",
    password = "123456",
    database = "wparse",
    schema = "public",
    table = "nginx_logs",
    cursor_column = "wp_event_id",
    cursor_type = "int",
    batch = 100
}
```

### topology/sinks/business.d/demo.toml（业务 Sink 配置）

```toml
[sink_group]
name = "demo"
oml = ["*"]
tags = ["biz:demo"]
batch_size = 1024
batch_timeout_ms = 300

[[sink_group.sinks]]
name = "json"
connect = "file_json_sink"
tags = ["sink:json"]

[sink_group.sinks.params]
file = "demo.json"
```

### topology/sinks/infra.d/default.toml（全量数据 Sink）

```toml
[sink_group]
name = "default"
batch_size = 128
batch_timeout_ms = 300

[[sink_group.sinks]]
connect = "file_proto_sink"

[sink_group.sinks.params]
file = "default.dat"

[sink_group.sinks.expect]
ratio = 0.0
tol = 0.02
```

## 结果验证
- 文件输出：各 Sink 输出文件位于 `data/out` 目录下
  - `demo.json`：业务解析后的 JSON 数据

## 常见问题排查

- **连接失败**：确认 PostgreSQL 服务已启动，端口（默认 5432）可访问，用户名密码正确
- **表不存在**：确认源数据库中 `nginx_logs` 表已创建，且 `schema` 配置正确
- **游标列错误**：确认源表中存在 `cursor_column` 指定的列，且类型与 `cursor_type` 匹配
- **无数据拉取**：检查 `data/logs/` 下的日志文件，确认数据库连接与查询是否正常；确认源表中存在新数据且游标值大于上次 checkpoint
- **断点续传**：checkpoint 文件位于 `.run/.checkpoints/` 目录，删除后可从头开始拉取
- **环境变量覆盖**：可通过 `POSTGRES_URL` 环境变量覆盖数据库连接串，格式：`postgres://user:pass@host:port/database`
- **端口冲突**：admin API 默认绑定 `127.0.0.1:19090`，如端口被占用可修改 `conf/wparse.toml` 中的 `admin_api.bind` 配置
