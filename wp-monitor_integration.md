# 如何在 wp-example 中接入 wp-monitor

## 前置条件

- 有 `wp-compose` 仓库访问权限
- 知道本次使用的 `tag`
- 已有可运行的 `wp-example`

## 关键步骤

### 1. 下载制品

仓库会通过 GitHub Release 提供离线镜像包。

当前 release 产物包含两种架构：

- `wp-console-0.1.0-alpha-x86_64-unknown-linux-gnu-images.tar.gz`
- `wp-console-0.1.0-alpha-aarch64-unknown-linux-gnu-images.tar.gz`

下载时按运行环境选择：

- `x86_64-unknown-linux-gnu`：适用于常见 Intel / AMD Linux 环境
- `aarch64-unknown-linux-gnu`：适用于 ARM64 Linux 环境

仓库地址：

- `https://github.com/wp-labs/wp-compose`

### 2. 导入 Docker 镜像

从 Release 下载 `*.tar.gz` 后，可以直接导入本地 Docker：

```bash
gunzip -c wp-console-0.1.0-alpha-x86_64-unknown-linux-gnu-images.tar.gz | docker load
```

或者先解压，再通过 `-i` 参数导入：

```bash
gunzip wp-console-0.1.0-alpha-x86_64-unknown-linux-gnu-images.tar.gz
docker load -i wp-console-0.1.0-alpha-x86_64-unknown-linux-gnu-images.tar
```

### 3. 在 `warp-observing` 目录启动监控环境

`warp-observing` 提供一套观测 `wparse` 的 Docker Compose 本地运行环境，用来快速启动以下 3 个服务：

- `victoria-metrics`：指标存储服务，默认暴露 `8428`
- `victoria-logs`：日志存储服务，默认暴露 `9428`
- `wp-monitor`：`wparse` 监控面板，默认端口 `18080`

当前使用 `warp-observing/.env` 管理配置：

```bash
RETENTION_PERIOD=15d
```

其中：

- `RETENTION_PERIOD`：指标和日志数据保留时间

最后进入对应目录启动：

```bash
cd warp-observing
docker compose up -d
# 老版本
docker-compose up -d
```

### 4. 在 wp-example 增加 monitor sink

在 `wparse` 的 `topology/sinks/infra.d/monitor.toml` 中添加如下配置：

```toml
[[sink_group.sinks]]
name = "metrics_vmetrics_sink"
connect = "victoriametrics_sink"
params = { insert_url = "http://localhost:8428/api/v1/import/prometheus", flush_interval_secs = 1}
```

参考：

- [monitor.toml](/Users/dy_xuyuhao/wp/wp-example_bak/wp-examples/extensions/practice/parse-work/topology/sinks/infra.d/monitor.toml)

### 5. 启动 wparse

`wparse` 需要带 `--stat` 启动：

```bash
cd <case>/parse-work
wparse daemon --stat 2 -p
```

## 验证

### 1. 看容器

```bash
docker compose ps
```

确认 `victoria-metrics`、`victoria-logs` 和 `wp-monitor` 已启动。

### 2. 看页面

打开：

```text
http://<host>:18080
```

### 3. 无数据时优先检查

- `wparse` 是否带 `--stat`
- `monitor.toml` 是否已生效
- `warp-observing` 是否正常启动
- `insert_url` 是否指向 `http://localhost:8428/api/v1/import/prometheus`
