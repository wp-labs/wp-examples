# PG Knowledge Enrichment Demo（双 PostgreSQL 数据库）

这个示例演示 `wparse` 如何通过**两个 PostgreSQL 数据库**做日志富化，并提供一键可运行的 `run.sh`。输入数据由 `wpgen sample` 通过 TCP 实时发送给 `wparse`，更适合做压测和吞吐验证。

两个库共用同一地址、不同 database：

| provider 名 | 数据库 | 表 | 富化字段 |
| --- | --- | --- | --- |
| `asset` | `knowdb_demo` | `asset_inventory` | `asset_name` / `asset_env` / `asset_owner` |
| `geo` | `ip_geo_db` | `ip_geo_city` | `country` / `city` |

OML 查询通过表名首段 `<provider>.` 前缀指定数据库：

```oml
asset_name, asset_env, asset_owner = select ... from asset.public.asset_inventory where ip = read(sip) ;
country, city = select ... from geo.public.ip_geo_city where ip = read(sip) ;
```

## 目录说明

- `docker-compose.yml`: 启动本地 PostgreSQL；`docker/initdb/01_*.sql` 建 `knowdb_demo` 资产表，`02_*.sql` 建 `ip_geo_db` 归属地表
- `models/knowledge/knowdb.toml`: 通过 `[[provider.sqldb]]` 配置两个 PostgreSQL provider
- `models/oml/pg_asset_enrich.oml`: 通过前缀路由 SQL 查询两个库并写回输出字段
- `models/wpl/sample.dat`: 用于 `wpgen sample` 扩展生成的大规模 Nginx 样本
- `topology/sources/wpsrc.toml`: 配置 TCP source，默认监听 `19001`
- `conf/wpgen.toml`: `wpgen` 数据生成配置，默认通过单 TCP 连接向 `127.0.0.1:19001` 发送 100000 条原始日志
- `.warp_parse/sec_key.toml`: 本地演示密钥，提供 `SEC_PWD = "demo"` 供 `${SEC_PWD}` 展开
- `run.sh`: 自动启动 PostgreSQL、拉起 `wparse deamon`、通过 TCP 打流，并校验富化结果

## 自动运行

```bash
./run.sh
```

脚本会自动：

- 启动本地 PostgreSQL（自动建两个库并灌入演示数据）
- 等待数据库健康检查通过
- 清理旧输出并执行 `wpadm check`
- 启动 `wparse deamon`
- 使用 `wpgen sample` 通过 TCP 发送原始 nginx 输入数据
- 校验 `asset_*` 与 `country` / `city` 富化字段与输出总行数
- 结束后自动停止并清理容器

为避免占用本机默认 PostgreSQL 端口，示例固定监听 `127.0.0.1:55433`，两个库分别为 `knowdb_demo` 与 `ip_geo_db`。

可通过环境变量覆盖生成规模，例如：

```bash
LINE_CNT=500000 GEN_SPEED=50000 ./run.sh
```

默认 TCP 入口端口是 `19001`。

## 手动执行

先启动 PostgreSQL：

```bash
docker compose up -d
```

然后检查并运行：

```bash
wpadm check --work-root "$(pwd)"
wparse deamon --work-root "$(pwd)" --stat 5 &
wpgen sample --work-root "$(pwd)" -n 100000 -s 20000
```

处理完成后，输出文件在：

```bash
data/out_dat/pg_enriched.json
```

## 预期富化字段

命中两个 PostgreSQL 库后，输出中会新增：

- `asset_name`
- `asset_env`
- `asset_owner`
- `country`
- `city`

## 示例逻辑

输入日志里的 `sip` 会作为查询键，分别执行两条富化 SQL（前缀路由到对应 provider，发往 PG 时前缀被剥离）：

```sql
select asset_name, asset_env, asset_owner from asset_inventory where ip = read(sip)
select country, city from ip_geo_city where ip = read(sip)
```
