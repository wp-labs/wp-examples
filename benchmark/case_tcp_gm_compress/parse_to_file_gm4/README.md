# TCP GM(SM4) + 压缩 Parse to File (GM4 落盘)

`wpgen` 经 `tcp_sink` 以「先 zstd 压缩、再 SM4-GCM 加密」发送；`wparse` 经 `tcp_src` 接收后解密解压、解析，再经 `file_json_sink` **对落盘文件再次「先 zstd 压缩、再 SM4-GCM 加密」**写入磁盘。用于度量「TCP 传输加密 + 文件落盘加密」双层 SM4-GCM + zstd 的完整链路吞吐。

## Data Flow

```
wpgen ──(SM4-GCM + zstd, tcp_sink)──► TCP :19001 ──► wparse daemon ──► file sink (parse_to_file_gm4)
                                                                        │
                                                       SM4-GCM + zstd 落盘加密
                                                                        ▼
                                                              ./out/all-r*.gm4  (二进制帧流)
```

## 加密 / 压缩配置

| Side | Connector | 配置 |
|------|-----------|------|
| Generator | `tcp_sink` (client) | `compression = { zstd, level 3 }` + `encryption = { sm4-gcm }` |
| Receiver | `tcp_src` (server) | 对称解码：`compression` + `encryption` |
| Output | `file_json_sink` (file) | `compression = { zstd, level 3 }` + `encryption = { sm4-gcm }`（落盘加密） |

- 压缩：zstd，level 3。
- 加密：国密 SM4-GCM，16 字节密钥（hex 32 字符），纯测试值。
- **落盘输出为二进制帧流**（`magic "WP" | version | kind | length | payload`），不是可读 JSON；需用对称配置的 decoder 才能还原。

## Quick Start

```bash
cd benchmark/case_tcp_gm_compress/parse_to_file_gm4

# 默认（20M 行，2 workers）
./run.sh

# 中等数据集（200K 行）
./run.sh -m
```

## 输出位置

落盘加密文件在 `./out/all-r{0..N-1}.gm4`（N = worker 数，按副本分片）。

## Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `-m` | 中等数据集 | 20M → 200K 行 |
| `-w <cnt>` | worker 数 | 2 |
| `wpl_dir` | WPL 规则目录 | nginx |
| `speed` | 生成限速 | 0（不限速） |
