# TCP-TLS Source Benchmarks

Performance benchmarks for the TLS-encrypted TCP data source scenario in daemon mode. Unlike `case_tcp` (plaintext), the generator (`wpgen`) sends over `tcp_sink` with `tls` enabled, and the receiver (`wparse`) listens over `tcp_src` with `tls` enabled.

## Test Scenarios

| Scenario | Description | Validated Features |
|----------|-------------|-------------------|
| parse_to_blackhole | TCP-TLS → Parse → Discard | TLS + TCP reception + pure parsing throughput |

## Quick Start

```bash
cd benchmark/case_tcp_tls/parse_to_blackhole

# Parse to blackhole (default: 20M lines, 6 workers)
./run.sh

# Medium dataset (200K lines)
./run.sh -m
```

## Data Flow

```
wpgen ──(TLS)──► TCP (port 19001) ──(TLS)──► wparse daemon → blackhole sink
```

## Configuration

- **Default Port**: 19001
- **Default Workers**: 6
- **Protocol**: TCP over TLS
- **Server cert/key**: `parse_to_blackhole/certs/` (self-signed, 100-year, benchmark only)
