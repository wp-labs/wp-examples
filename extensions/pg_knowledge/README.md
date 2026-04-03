# PG Knowledge Enrichment Demo

这个示例演示 `wparse` 如何通过 PostgreSQL 知识库做日志富化，并提供一键可运行的 `run.sh`。输入数据由 `wpgen sample` 通过 TCP 实时发送给 `wparse`，更适合做压测和吞吐验证。

## 目录说明

- `docker-compose.yml`: 启动本地 PostgreSQL，并自动导入演示表
- `models/knowledge/knowdb.toml`: 启用 PostgreSQL provider
- `models/oml/pg_asset_enrich.oml`: 通过 SQL 查询资产信息并写回输出字段
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

- 启动本地 PostgreSQL
- 等待数据库健康检查通过
- 清理旧输出并执行 `wproj check`
- 启动 `wparse deamon`
- 使用 `wpgen sample` 通过 TCP 发送原始 nginx 输入数据
- 校验 `asset_name` / `asset_env` / `asset_owner` 富化字段与输出总行数
- 结束后自动停止并清理容器

为避免占用本机默认 PostgreSQL 端口，示例固定监听 `127.0.0.1:55432`，数据库为 `knowdb_demo`。

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
wproj check --work-root "$(pwd)"
wparse deamon --work-root "$(pwd)" --stat 5 &
wpgen sample --work-root "$(pwd)" -n 100000 -s 20000
```

处理完成后，输出文件在：

```bash
data/out_dat/pg_enriched.json
```

## 预期富化字段

命中 PostgreSQL 资产表后，输出中会新增：

- `asset_name`
- `asset_env`
- `asset_owner`

## 示例逻辑

输入日志里的 `sip` 会作为查询键，执行如下富化 SQL：

```sql
select asset_name, asset_env, asset_owner
from asset_inventory
where ip = read(sip)
```
