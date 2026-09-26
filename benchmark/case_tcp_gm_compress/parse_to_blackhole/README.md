# TCP GM(SM4) + 压缩 Parse to Blackhole

`wpgen` 经 `tcp_sink` 以「先 zstd 压缩、再 SM4-GCM 加密」发送，`wparse` 经 `tcp_src` 接收后解析并丢弃。用于度量 SM4-GCM + zstd + TCP 传输的组合吞吐。

## Data Flow

```
wpgen ──(SM4-GCM + zstd, tcp_sink)──► TCP :19001 ──► wparse daemon ──► blackhole sink
```

## 加密 / 压缩配置

| Side | Connector | 配置 |
|------|-----------|------|
| Generator | `tcp_sink` (client) | `compression = { enabled = true, algo = "zstd", level = 3 }` + `encryption = { enabled = true, algo = "sm4-gcm", key = "<32 hex>" }` |
| Receiver | `tcp_src` (server) | 对称解码：`compression` + `encryption`（与 Generator 相同） |

- 压缩：zstd，level 3（日志文本甜点位，参考 `wp-connector-utils/BENCHMARKS.md`）。
- 加密：国密 SM4-GCM，16 字节密钥（hex 32 字符）。密钥为纯测试值。
- 注意 SM4-GCM 是纯软件实现（无硬件加速），吞吐上限约 ~75 MiB/s（见基准），高吞吐链路会是瓶颈。

## Quick Start

```bash
cd benchmark/case_tcp_gm_compress/parse_to_blackhole

# 默认（20M 行，6 workers）
./run.sh

# 中等数据集（200K 行）
./run.sh -m
```

## Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `-m` | 中等数据集 | 20M → 200K 行 |
| `-w <cnt>` | worker 数 | 6 |
| `wpl_dir` | WPL 规则目录 | nginx |
| `speed` | 生成限速 | 0（不限速） |
