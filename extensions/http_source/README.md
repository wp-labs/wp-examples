### 支持的参数
1. port：监听的端口。
2. path：监听的路径。
> 不同的source之间可以共用一个端口，只要保证path不同即可。

### 支持的功能
#### 格式选择
支持json格式和ndjson格式，通过请求参数 `fmt` 或者请求头`Content-Type`指定输入格式，`fmt` 参数优先级高于 Content-Type，且两者都不指定时默认使用 `json`。
Content-Type 映射规则：
    - `application/json` => `json`
    - `application/x-ndjson` => `ndjson`
    - `application/ndjson` => `ndjson`
#### 压缩选择
支持请求以gzip格式压缩或none(不压缩)，通过请求参数 `compression` 或者请求头`Content-Encoding`指定压缩方式。
```
curl -X POST "http://127.0.0.1:8000/ingest?fmt=json" \
  -H "Content-Type: application/x-ndjson" \
  --data '{"http/request":"GET /nginx-logo.png HTTP/1.1","http/status":500}'
```