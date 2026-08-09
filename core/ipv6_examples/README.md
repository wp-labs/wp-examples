# ipv6_examples

演示 WPL / OML 对 **IPv6 地址**的解析与富化能力。

## 场景

| case | 日志类型 | 说明 |
|------|---------|------|
| `nginx_ipv6` | Nginx 访问日志（CLF） | `ip` 类型解析 IPv6 客户端地址（`2001:db8:...`、`::1`、`::ffff:192.168.1.10` 等） |
| `fw_ipv6` | 防火墙日志（空格分隔） | `ip` 类型解析源/目的 IPv6 地址 |

## 数据结构

```
conf/
├── wparse.toml          # 引擎配置（[models] 指向 wpl/oml 目录）
└── wpgen.toml           # 生成器配置（输出到 data/in_dat/gen.dat）
models/
├── wpl/
│   ├── nginx_ipv6/      # parse.wpl + sample.dat（手动 IPv6 样本）
│   └── fw_ipv6/         # parse.wpl + sample.dat（手动 IPv6 样本）
└── oml/
    ├── nginx_ipv6.oml   # intranet_ip / ip_to_biguint / access_direct
    └── fw_ipv6.oml      # 同上 + ip4_to_int 对 IPv6 返回 Null 的说明
topology/
├── sources/file_1.toml  # 文件源
└── sinks/               # business + infra
```

## 关键点

- **样本数据是手写的**：`wpgen sample` 的 `ip` 生成器只产出 IPv4，因此 IPv6 样本直接写在 `models/wpl/*/sample.dat`，由 `wpgen sample` 逐行读取发送。
- **`ip` 类型完整支持 IPv6**（`::1`、`ff00::`、`2001:db8::1`、`::ffff:192.168.1.10` 等），基于 Rust `std::net::IpAddr` 解析。
- **OML 管道**：
  - `intranet_ip` — 内网/公网判断，支持 IPv6 ULA（`fd00::/8`）
  - `ip_to_biguint` — IPv6 转大整数（压缩/全形式结果一致）
  - `access_direct` — 访问方向（L2L/L2W/W2L/W2W），支持 IPv6
  - `ip4_to_int` — **仅支持 IPv4**，对 IPv6 返回 Null

## 运行

```bash
bash run.sh
```

## 验证

`wpadm data validate` 检查各 sink 输出比例（两个 business sink 预期 100% 命中）。
