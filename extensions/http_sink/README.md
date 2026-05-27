# HTTP Sink Test Server v2.0

用于测试 wp-connectors HTTP sink 的测试服务器,支持多种数据格式的接收、解析和统计。

## 快速开始

### 启动服务器
本用例有两个服务器，任选其一即可
- `test_server.py`: 用来做功能测试的服务器。
- `nginx`:nginx服务器，推荐用来做性能测试。

#### test_server.py服务器
``` bash
python3 test_server.py
```
---
服务器接口介绍：
- POST /ingest/{format}        - 接收指定格式的数据,如果实际格式不匹配会返回报错
- POST /auth/ingest/{format}   - 需要认证的数据接收接口 (用户名/密码: root/root)
- POST /gzip/ingest/{format}   - 接收压缩的接口
- GET  /count                  - 查看所有格式的统计
- GET  /details/{format}       - 查看指定格式的最后3条数据
- GET  /                       - 健康检查
 
#### nginx服务器
``` bash
cd nginx
docker compose up -d
```


## 配置 wp-connectors

### HTTP Sink 配置

编辑 `topology/sinks/business.d/example.toml`:

```toml
version = "2.0"

[sink_group]
name = "http"
rule = ["*"]
batch_timeout_ms = 5000
parallel = 4

[[sink_group.sinks]]
name = "http_sink_demo"
connect = "http_sink"

[sink_group.sinks.params]
endpoint= "http://localhost:8080/auth/ingest/ndjson"
username = "root"     # HTTP Basic 认证用户名（可选） 
password = "root"
fmt = "ndjson"  # 支持`json`、`ndjson`、`csv`、`kv`、`raw`、`proto-text`（默认 `json`），并且会设置请求头
compression = "none"    # 数据压缩：`none`、`gzip`（默认 `none`）
timeout_secs = 30
max_retries = 3
batch_size = 1024

[sink_group.sinks.params.headers]
```

**参数说明：**

| 参数 | 类型 | 说明 |
|------|------|------|
| `endpoint` | string | HTTP(S) 端点 URL（必填） |
| `method` | string | HTTP 方法：GET、POST、PUT、PATCH、DELETE（默认 `POST`） |
| `username` | string | HTTP Basic 认证用户名（可选） |
| `password` | string | HTTP Basic 认证密码（可选） |
| `headers` | object | 自定义 HTTP 头，JSON 对象格式（可选） |
| `fmt` | string | 输出格式：`json`、`ndjson`、`csv`、`kv`、`raw`、`proto-text`（默认 `json`） |
| `batch_size` | int | 批量大小：1 表示单条发送，>1 表示批量发送（默认 `1`） |
| `timeout_secs` | int | 请求超时时间（秒，默认 `60`） |
| `max_retries` | int | 请求失败重试次数：-1 表示无限重试，0 表示不重试（默认 `3`） |
| `compression` | string | 数据压缩：`none`、`gzip`（默认 `none`） |