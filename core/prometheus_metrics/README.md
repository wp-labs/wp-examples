# prometheus_metrics

本用例演示"Prometheus 指标导出"的场景：通过 Prometheus sink 导出 warp-flow 的内部运行指标，支持通过 HTTP `/metrics` 端点拉取指标数据。适用于监控系统集成与性能观测。

## 目录结构
- `conf/`：配置目录
  - `conf/wparse.toml`：主配置（含 Prometheus 导出配置）
- `models/`：规则与路由
  - `models/wpl/`：WPL 解析规则
  - `models/oml/`：OML 转换模型
  - `models/sinks/business.d/`：业务路由
  - `models/sinks/infra.d/`：基础组（含 monitor 组）
  - `models/sources/wpsrc.toml`：源配置（UDP syslog）
- `data/`：运行数据目录

## Prometheus 配置

### Monitor 组配置
在 `models/sinks/infra.d/monitor.toml` 中配置 Prometheus sink：
```toml
[[sink_group]]
name = "/sink/infra/monitor"
connect = "prometheus_sink"

[[sink_group.sinks]]
name = "prometheus_exporter"
```

### Prometheus 连接器
在 `connectors/sink.d/` 中添加 Prometheus 连接器：
```toml
[connector]
id = "prometheus_sink"
type = "prometheus"

[connector.params]
endpoint = "127.0.0.1:35666"
```

## 快速使用

### 构建项目
```bash
cargo build --workspace --all-features
```

### 运行用例
```bash
cd core/prometheus_metrics
./run.sh
```

脚本执行流程：
1. 初始化环境与配置
2. 启动 wparse（syslog 接收 + Prometheus 导出）
3. 等待服务启动（约 3 秒）
4. 使用 wpgen 生成并发送样本数据
5. 停止服务并校验输出

### 手动执行
```bash
# 初始化配置
wproj data clean

# 启动解析服务（后台）
wparse daemon --stat 2 -p &

# 等待服务启动
sleep 3

# 生成并发送样本
wpgen sample -n 1000 --stat 1 -p

# 拉取 Prometheus 指标
curl -s http://localhost:35666/metrics

# 停止服务
kill $(cat ./.run/wparse.pid)

# 校验输出
wproj data stat
wproj data validate --input-cnt 1000
```

## 可调参数
- `LINE_CNT`：生成行数（默认 1000）
- `STAT_SEC`：统计间隔秒数（默认 2）

## Prometheus 指标

### 示例指标
```
# HELP wparse_input_total Total number of input records
# TYPE wparse_input_total counter
wparse_input_total 1000

# HELP wparse_output_total Total number of output records by sink
# TYPE wparse_output_total counter
wparse_output_total{sink="benchmark"} 950
wparse_output_total{sink="default"} 50

# HELP wparse_parse_duration_seconds Parse duration histogram
# TYPE wparse_parse_duration_seconds histogram
wparse_parse_duration_seconds_bucket{le="0.001"} 800
wparse_parse_duration_seconds_bucket{le="0.01"} 990
wparse_parse_duration_seconds_bucket{le="+Inf"} 1000
```

### 指标类型
- **Counter**：输入/输出计数、错误计数
- **Gauge**：队列深度、活跃连接数
- **Histogram**：解析延迟、处理时长

## Grafana 集成

### 添加数据源
1. 在 Grafana 中添加 Prometheus 数据源
2. URL: `http://localhost:35666`

### 示例查询
```promql
# 输入速率
rate(wparse_input_total[1m])

# 输出分布
sum by (sink) (wparse_output_total)

# P99 延迟
histogram_quantile(0.99, wparse_parse_duration_seconds_bucket)
```

## 常见问题

### Q1: Prometheus 端点无响应
- 确认 `conf/wparse.toml` 中启用了 Prometheus 导出
- 确认 `monitor` 组连接器配置为 `prometheus_sink`
- 检查端口是否被占用：`lsof -i :35666`

### Q2: 指标为空
- 确认 wparse 已接收到数据
- 检查 `data/logs/wparse.log` 中的错误信息
- 确认 sinks 路由配置正确

### Q3: 指标延迟
- Prometheus 指标通常有几秒的采集延迟
- 确认 scrape_interval 配置合理

## 相关文档
- [Prometheus Sink](../../wp-docs/80-reference/params/sink_prometheus.md)
- [监控配置](../../wp-docs/10-user/03-sinks/04-prometheus_sink.md)
- [运行统计](../../wp-docs/10-user/08-performance/01-performance_overview.md)
