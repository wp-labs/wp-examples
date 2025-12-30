# Doris 文件 Source → Stream Load 用例

该目录演示如何利用 WarpParse 将文件样例解析后写入 Doris。整体链路：

1. `wpgen rule` 生成样例日志并写入 `data/in_dat/gen.dat`
2. `wparse batch` 读取文件 Source，按照 `models/wpl`/`models/oml` 解析
3. 结果同时落地到文件型 Sink（便于比对）与 Doris Stream Load

## 目录概览

- `conf/`：`wparse.toml`、`wpgen.toml` 等基础配置
- `models/`：`wpl` 规则与 `oml` 映射（`example1/2`、`benchmark*`）
- `topology/`：Source/Sink 拓扑，`business.d/example.toml` 中启用 Doris Sink
- `data/`：输入样例、运行日志、sink 输出等（脚本可自动清理）
- `run.sh`：一键脚本，负责数据生成、wparse 运行、结果校验与 Doris 查询

## 前置条件

1. 安装并配置 WarpParse CLI：`wproj`、`wpgen`、`wparse`
2. 准备 Doris 集群，可通过 `facilities/doris/start-doris.sh` 启动单机 FE/BE
3. 在 Doris 中创建目标库表（可按实际字段调整）。示例：

```sql
CREATE DATABASE IF NOT EXISTS wp_test;
USE wp_test;

CREATE TABLE IF NOT EXISTS events_parsed (
    sn           VARCHAR(64) COMMENT '设备序列号',
    dev_name     VARCHAR(128) COMMENT '设备名称',
    sip          VARCHAR(45) COMMENT '源 IP',
    from_zone    VARCHAR(32) COMMENT '来源区域',
    from_ip      VARCHAR(45) COMMENT '来源 IP',
    requ_uri     VARCHAR(512) COMMENT '请求 URI',
    requ_status  SMALLINT COMMENT '请求状态码',
    resp_len     INT COMMENT '响应长度',
    src_city     VARCHAR(32) COMMENT '源城市'
) ENGINE=OLAP
DUPLICATE KEY(sn)
COMMENT '设备请求事件解析表'
DISTRIBUTED BY HASH(sn) BUCKETS 8
PROPERTIES ("replication_num" = "1");
```

> `connectors/sink.d/50-doris.toml` 与 `topology/sinks/business.d/example.toml` 中的 `endpoint/database/table` 应与实际 Doris 环境保持一致。

## 快速开始

```bash
cd extensions/doris
./run.sh
```

脚本执行流程：

1. `wproj check` → `wproj data clean` → `wpgen data clean`，准备目录
2. 用 `wpgen rule` 生成 `LINE_CNT` 条样例到 `data/in_dat/gen.dat`
3. 执行 `wparse batch --stat STAT_SEC -S 1 -p -n LINE_CNT`
4. `wproj data stat` + `wproj data validate --input-cnt LINE_CNT` 校验 sink 输出
5. 若安装 `mysql`，自动查询 Doris：`SELECT COUNT(*) FROM ${DORIS_DB}.${DORIS_TABLE}`

### 可调环境变量

| 变量 | 默认值 | 说明 |
| --- | --- | --- |
| `LINE_CNT` | `5000` | 每次生成/解析的样本数 |
| `STAT_SEC` | `3` | `wpgen`/`wparse` 统计输出周期 |
| `DATA_FILE` | `./data/in_dat/gen.dat` | 文件 Source 的输入路径 |
| `DORIS_HOST` / `DORIS_PORT` | `127.0.0.1` / `9030` | Doris MySQL 访问地址（仅脚本最后一步使用） |
| `DORIS_DB` / `DORIS_TABLE` | `wp_test` / `events_parsed` | Doris 库表名 |
| `DORIS_USER` / `DORIS_PASSWORD` | `root` / 空 | Doris 认证信息 |

示例：

```bash
LINE_CNT=20000 STAT_SEC=5 DORIS_DB=doris_demo \
  DORIS_TABLE=log_events DORIS_HOST=docker.for.mac.localhost ./run.sh
```

## 结果验证

- **文件 Sink**：`data/out_dat/events.parsed.prototext`、`benchmark_kv*.dat` 等文件可使用 `wpkit stat file`、`wpkit validate sink-file` 自行校验
- **Doris**：脚本会输出 `SELECT COUNT(*) ...` 结果，也可手动执行：

```bash
mysql -h127.0.0.1 -P9030 -uroot -e "SELECT * FROM wp_test.events_parsed LIMIT 5;"
```

如需调整写入格式/映射，可在 `connectors/sink.d/50-doris.toml` 中修改 `create_table`/`endpoint`，或在 `topology/sinks/business.d/example.toml` 中覆写参数，然后重新运行 `./run.sh`。
