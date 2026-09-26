# TCP GM(国密 SM4) + 压缩 Source Benchmarks

国密对称加密（SM4-GCM）+ 压缩（zstd）的 TCP 数据源场景基准。与 `case_tcp_tls`（传输层 TLS）不同，这里在**应用层**对每条消息做「先压缩后加密」：`wpgen` 经 `tcp_sink` 开启 `compression` + `encryption`，`wparse` 经 `tcp_src` 以对称配置**解密 + 解压**后解析，完整回环。

## Test Scenarios

| Scenario | Description | Validated Features |
|----------|-------------|-------------------|
| parse_to_blackhole | TCP(SM4+zstd) → Parse → Discard | SM4-GCM 加密 + zstd 压缩 + TCP 传输 |
| parse_to_file | TCP(SM4+zstd) → Parse → File | SM4-GCM 加密 + zstd 压缩 + TCP 传输 + 文件落盘 |
| parse_to_file_gm4 | TCP(SM4+zstd) → Parse → File(SM4+zstd 落盘加密) | SM4-GCM 加密 + zstd 压缩 + TCP 传输 + 文件落盘加密 |

## Data Flow

```
wpgen ──(SM4-GCM + zstd, tcp_sink)──► TCP (port 19001) ──► wparse daemon → blackhole sink
```

## Configuration

- **Default Port**: 19001
- **Default Workers**: 6
- **Compression**: zstd, level 3（`compression = { enabled = true, algo = "zstd", level = 3 }`）
- **Encryption**: 国密 SM4-GCM（`encryption = { enabled = true, algo = "sm4-gcm", key = "<32 hex>" }`）
- **密钥**：`000102030405060708090a0b0c0d0e0f`（16 字节测试密钥，仅用于基准）
