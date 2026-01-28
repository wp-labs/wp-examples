## VictoriaMetrics 场景说明

本用例演示"VictoriaMetrics 指标推送"的场景：通过 VictoriaMetrics sink 将 warp-flow 的内部运行指标推送到 VictoriaMetrics 时序数据库。VictoriaMetrics 是一个高性能、低成本的 Prometheus 兼容时序数据库，适用于大规模监控系统集成与性能观测。

## 目录结构

*   `conf/`：配置目录
    *   `conf/wparse.toml`：主配置
*   `models/`：规则与模型
    *   `models/wpl/`：WPL 解析规则
    *   `models/oml/`：OML 转换模型
*   `topology/`：拓扑配置
    *   `topology/sources/wpsrc.toml`：源配置（TCP syslog）
    *   `topology/sinks/business.d/`：业务路由
    *   `topology/sinks/infra.d/`：基础组（含 monitor 组）
*   `data/`：运行数据目录
*   `docker-compose.yml`：VictoriaMetrics 容器配置

## VictoriaMetrics 配置

### wparse.toml配置

```plaintext
[stat]

[[stat.pick]]
key = "pick_stat"
target = "*"
fields = ["wpl_tag","wp_src_key"]

[[stat.parse]]
key = "parse_stat"
target = "*"
fields = ["wpl_tag", "wp_src_key"]

[[stat.sink]]
key = "sink_stat"
target = "*"
fields = ["wpl_tag","wp_src_key", "sink_category"]
```

注意其中的`fields`p配置需要保持一致

### Monitor 组配置

在 `topology/sinks/infra.d/monitor.toml` 中配置 VictoriaMetrics sink：

```plaintext
version = "2.0"

[sink_group]
name = "monitor"

[[sink_group.sinks]]
name = "monitor"
connect = "file_proto_sink"
params = { file = "monitor.dat" }
[sink_group.sinks.expect]
min = 0.001

[[sink_group.sinks]]
name = "victoriametrics"
connect = "victoriametrics_sink"
```

### VictoriaMetrics 连接器

在 `connectors/sink.d/80-victoriametrics.toml` 中配置 VictoriaMetrics 连接器：

```plaintext
[[connectors]]
id = "victoriametrics_sink"
type = "victoriametrics"
allow_override = ["insert_url", "flush_interval_secs"]

[connectors.params]
insert_url = "http://127.0.0.1:8428/api/v1/import/prometheus"
flush_interval_secs = 1
```

### Docker 部署

使用 `docker-compose.yml` 快速启动 VictoriaMetrics：

```plaintext
services:
  victoriametrics:
    image: victoriametrics/victoria-metrics:v1.98.0
    container_name: victoriametrics
    restart: unless-stopped
    ports:
      - "8428:8428"
    volumes:
      - ./data:/storage
    command:
      - "-storageDataPath=/storage"
      - "-retentionPeriod=6"   # 数据保留 6 个月
```

## 快速使用

### 前置准备

构建项目：

启动 VictoriaMetrics：

验证 VictoriaMetrics 运行状态：

### 运行用例

```plaintext
cd extensions/victoriametrics
./run.sh
```

脚本执行流程：

1.  初始化环境与配置
2.  启动 wparse（syslog 接收 + VictoriaMetrics 推送）
3.  等待服务启动（约 3 秒）
4.  循环生成并发送样本数据（按 Ctrl+C 停止）
5.  停止服务并校验输出

### 手动执行

```plaintext
# 1. 启动 VictoriaMetrics
docker-compose up -d

# 2. 初始化配置
wproj data clean

# 3. 启动解析服务（后台）
wparse daemon --stat 2 -p &amp;

# 4. 等待服务启动
sleep 3

# 5. 生成并发送样本（循环执行，Ctrl+C 停止）
while true; do
    wpgen sample -n 1000 --stat 1 -p
    sleep 2
done

# 6. 查询 VictoriaMetrics 中的指标
curl -s 'http://localhost:8428/api/v1/query?query=wparse_input_total'

# 7. 停止服务
kill $(cat ./.run/wparse.pid)

# 8. 校验输出
wproj data stat
wproj data validate --input-cnt 1000
```

## 可调参数

*   `LINE_CNT`：生成行数（默认 1000）
*   `STAT_SEC`：统计间隔秒数（默认 2）

## 指标查询

### VictoriaMetrics API

VictoriaMetrics 兼容 Prometheus 查询 API，支持 PromQL 查询语法。

### 查询示例

```plaintext
# 查询输入总数
curl -s 'http://localhost:8428/api/v1/query?query=wparse_input_total'

# 查询输出分布
curl -s 'http://localhost:8428/api/v1/query?query=wparse_output_total'

# 查询时间范围数据
curl -s 'http://localhost:8428/api/v1/query_range?query=rate(wparse_input_total[1m])&amp;start=2024-01-01T00:00:00Z&amp;end=2024-01-01T01:00:00Z&amp;step=1m'

# 查询所有指标名称
curl -s 'http://localhost:8428/api/v1/label/__name__/values'
```

### 指标数据

wparse_source_types

*   pid：wparse的进程pid
*   source_type： 日志的来源

wparse_sink_types

*   pid： waprse的进程pid
*   sink_type：sink的类型（mysql，victorialogs等）

wparse_receive_data

*   pid：wparse的进程pid
*   key：source-key
*   source_type：日志的来源

wparse_parse_all

*   pid：wparse的进程pid
*   parse：

wparse_parse_success

*   rule_name: 匹配到的规则名称
*   log_business：具体的日志类型
*   pid：wparse的进程pid

wparse_send_to_sink

*   pid：waprse的进程pid
*   sink_type：sink的类型（mysql，victorialogs等）