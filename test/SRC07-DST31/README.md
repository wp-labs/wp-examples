## 介绍
![1768295030715](image/README/1768295030715.png)
SRC07-DST31 场景演示了 “多 Source 类型（Kafka + TCP + Syslog）→ 多 Sink 类型（Kafka + File + VictoriaLogs + MySQL + Doris）” 的端到端链路。示例中：

- `sender/` 目录下的 3 组 `wpgen`（nginx/json-nginx/sys）同时向 Kafka、TCP、Syslog 发出样例日志；
- `parse/` 目录的 `wparse` 解析后投递到 10+ 个 sink，覆盖 `DST31` 的 kafka+vlog+file+MYSQL+doris 组合；
- `docker-compose.yml` 提供 2×Kafka(KRaft)、2×Doris(FE/BE)、2×MySQL、2×VictoriaLogs 的依赖环境。

下文给出使用步骤及关键说明。

## 目录速览

| 路径 | 说明 |
| --- | --- |
| `docker-compose.yml` | 启动 Kafka、Doris（两套 FE/BE）、VictoriaLogs、MySQL。Kafka 对外监听 `127.0.0.1:9092/9093`，容器内部互通端口 `19092`。|
| `parse/` | `wparse` 运行目录：`conf/wparse.toml`、`topology/sources` 定义 2×Kafka + 2×TCP + 2×Syslog；`topology/sinks` 同步写入 Kafka/File/VictoriaLogs/Doris/MySQL。输出文件位于 `parse/data/out_dat`。|
| `sender/` | `json-nginx`、`nginx`、`sys` 三个目录内含 `wpgen-kafka/tcp/syslog.toml`。`run.sh` 会同时启动 9 个 `wpgen sample` 产生不同结构的 nginx、json-nginx、sys 日志。|
| `sql/` | 包含 `doris.sql`（需手动执行）与 `mysql.sql`（容器自动执行）来初始化目标表。|
| `run.sh` / `stop.sh` | 批量启动/停止 wparse 以及全部 wpgen，PID 位于 `pids/*.pid`。|

## 前置条件

- 已安装 Docker / Docker Compose (v2)。
- 本地可执行 `wparse`、`wpgen` CLI。
- 端口 `9092/9093/19002/19003/1514/1515/8030-9031/3306-3307/9428-9429` 未被占用。

## 快速开始

### 1. 启动依赖组件

```bash
cd SRC07-DST31
docker compose up -d
docker compose ps -a    # Kafka/Doris/MySQL/VictoriaLogs 均需 Up
```

> Kafka 默认通过 `127.0.0.1:9092,127.0.0.1:9093` 提供宿主访问；容器内部互联使用 `kafka-1:19092`,`kafka-2:19092`。

### 2. 初始化 Doris（必做）

`doris.sql` 不会被镜像自动导入，需要分别对两套 FE 执行一次：
- 登录到doris：http://localhost:8030/login
![1768293771113](image/README/1768293771113.png)
- 进入到操作页面执行SQL：`http://localhost:8030/Playground`，执行创建语句（需要选中mysql）
![1768293919942](image/README/1768293919942.png)

脚本会创建 `test_db`，并生成 `wp_nginx`、`wp_jnginx` 两张表。若修改库表名，请同步更新 `parse/topology/sinks/business.d/*.toml` 中的 `database/table`。

> MySQL 容器会自动执行 `sql/mysql.sql`，通常无需手动干预。

### 3. 启动解析与数据发生器

```bash
./run.sh
```

该脚本会：

1. 在 `parse/` 下启动 `wparse daemon --stat 2 -p`，读取 `conf/wparse.toml`、`topology/*`；
2. 在 `sender/json-nginx|nginx|sys` 中启动 9 个 `wpgen sample`（Kafka/TCP/Syslog），日志写入 `parse/data/logs/*.log`；
3. PID 写入 `pids/*.pid`，方便 `stop.sh` 清理。

### 4. 停止与清理

```bash
./stop.sh           # 终止 wparse / wpgen 并清空 parse/data
# 如需释放 docker 资源
docker compose down
```

> `stop.sh` 会删除 `parse/data`（包括输出文件），如需保存结果请提前备份。

## monitor监控
`http://localhost:25816/wp-monitor`

## Source / Sink 映射

- **Sources (`parse/topology/sources/wpsrc.toml`)**
  - Kafka：`wp.input.event`（双 broker）。
  - TCP：19002、19003，`prefer_newline=true`。
  - Syslog：1514、1515，`syslog_tcp_src` strip header。
- **Sinks (`parse/topology/sinks/business.d/*.toml`)**
  - Kafka：`wp.output.nginx`、`wp.output.jnginx`。
  - File：`parse/data/out_dat/<sink>/file-*.dat`。
  - VictoriaLogs：`http://localhost:9428`、`http://localhost:9429`。
  - Doris：`9030/9031` 上的 `test_db.wp_nginx / wp_jnginx`。
  - MySQL：`localhost:3306`、`localhost:3307` 中的同名表。

## 常见问题

1. **Kafka 客户端仍访问 `::1`**：请使用 `127.0.0.1` 或增加 `client.dns.lookup=use_all_dns_ips`，否则某些客户端会优先选择 IPv6。
2. **Doris FE 报 `CURRENT_FE_IP is null`**：保持 `FE_SERVERS=fe1:...` 与 `FE_ID=1` 不变，且在 `docker compose up -d` 后先执行 “初始化 Doris” 的步骤。
3. **端口冲突**：如宿主机已有 Kafka/MySQL，可在 `docker-compose.yml` 修改 `ports`，同时把 `sender/*/conf` 与 `parse/topology/sinks` 里的地址同步更新。

## 扩展建议

- 替换日志模型：更新 `parse/models/wpl/*` 与 `sender/*/models` 样本即可；
- 调整解析性能：编辑 `parse/conf/wparse.toml` → `[performance]`；
- 新增 sink：在 `parse/topology/sinks/business.d` 增加 `[[sink_group.sinks]]` 即可复用当前链路。

完成以上步骤即可复现 SRC07-DST31 重点用例，并在此基础上扩展更多源/目标组合。
