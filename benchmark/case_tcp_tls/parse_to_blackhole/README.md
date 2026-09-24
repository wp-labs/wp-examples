# TCP-TLS Parse to Blackhole

Benchmark for the "TCP-TLS Source → Blackhole Sink" daemon-mode scenario: `wpgen` sends data over a TLS-encrypted TCP connection (`tcp_sink` + `tls`), and `wparse` receives it over TLS (`tcp_src` + `tls`), parses, and discards to a blackhole sink. Measures combined TLS + TCP reception + parsing throughput.

## Data Flow

```
wpgen ──(TLS)──► TCP :19001 ──(TLS)──► wparse daemon ──► blackhole sink
```

## TLS Setup

| Side | Connector | `tls` config |
|------|-----------|--------------|
| Generator | `tcp_sink` (client) | `enabled = true`, `insecure = true` |
| Receiver | `tcp_src` (server) | `enabled = true`, `cert` + `key` |

- The server (`wparse`) presents `certs/server.pem` / `certs/server.key` (self-signed).
- The client (`wpgen`) skips cert verification via `insecure = true` (equivalent to `curl -k`); the handshake and encryption are still real TLS.
- To verify the server cert instead, replace the client `tls` block with `ca = "certs/server.pem"` and `server_name = "localhost"` (the cert carries `DNS:localhost` / `IP:127.0.0.1` SANs).
- In production with a **public CA** certificate, omit `ca` on the client entirely — it falls back to the system native trust store (`rustls-native-certs`); just set `server_name = "<your-domain>"`.

## Quick Start

```bash
cd benchmark/case_tcp_tls/parse_to_blackhole

# Default test (20M lines, 6 workers)
./run.sh

# Medium dataset (200K lines)
./run.sh -m

# Custom configuration
./run.sh -w 8 sysmon 500000
```

## Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `-m` | Medium dataset | 20M → 200K lines |
| `-w <cnt>` | Worker count | 6 |
| `wpl_dir` | WPL rule directory | nginx |
| `speed` | Generation rate limit | 0 (unlimited) |

## Regenerate Certificates

The committed cert is a long-lived (100-year) self-signed cert for benchmarking only. To regenerate:

```bash
cd benchmark/case_tcp_tls/parse_to_blackhole
openssl req -x509 -newkey rsa:2048 -sha256 -nodes -days 36500 \
  -keyout certs/server.key -out certs/server.pem \
  -subj "/CN=wp-benchmark-tcp-tls" \
  -addext "subjectAltName=DNS:localhost,IP:127.0.0.1"
```
