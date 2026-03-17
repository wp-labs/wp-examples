## 前提

1. 启动 Docker Compose：
```bash
docker compose up -d
```

2. 等待 Elasticsearch 启动，查看是否启动成功:
```bash
curl -u elastic:zgVClXP2 http://localhost:9200
```

## Elasticsearch Sink 配置介绍

### Connector 配置 (connectors/sink.d/90-elasticsearch.toml)

```toml
[[connectors]]
id = "elasticsearch_sink"
type = "elasticsearch"
allow_override = [
  "protocol",
  "host",
  "port",
  "username",
  "password",
  "index",
  "timeout_secs",
  "max_retries",
  "batch_size"
]

[connectors.params]
protocol = "http"           # 协议: http 或 https
host = "localhost"          # Elasticsearch 主机地址
port = "9200"               # Elasticsearch 端口
username = "elastic"        # 用户名
password = "zgVClXP2"       # 密码
index = "wp_nginx"          # 索引名称
timeout_secs = 30           # 请求超时时间（秒）
max_retries = 3             # 最大重试次数
batch_size = 100_0000       # 批量写入大小
```

### 2. 查看索引数据

```bash
# 查看索引统计
curl -u elastic:zgVClXP2 "http://localhost:9200/wp_nginx/_count?pretty"

# 查看最新5条数据
curl -u elastic:zgVClXP2 'http://localhost:9200/wp_nginx/_search?pretty&size=5'
```

### 3. 删除索引

```bash
curl -X DELETE -u elastic:zgVClXP2 "http://localhost:9200/wp_nginx"
```

