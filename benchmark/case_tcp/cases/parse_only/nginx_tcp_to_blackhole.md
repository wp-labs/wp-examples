# nginx_tcp_to_blackhole

## Case Metadata
- **Case ID**: nginx_tcp_to_blackhole
- **Category**: tcp
- **Capability**: parse_only
- **Topology**: tcp -> blackhole
- **Platforms**: Mac M4 Mini / Linux (AWS EC2)

## Scenario Definition
- **日志类型**: Nginx Access Log (239B)
- **平均大小**: 239B
- **能力**: parse_only
- **输入/输出**: TCP -> BlackHole
- **说明**: Nginx Access Log 场景，TCP 输入到 BlackHole 输出，执行 日志解析 能力。

## Dataset Contract
- **输入数据**: benchmark/case_tcp/parse_to_blackhole/data/in_dat/gen.dat（数据文件） / benchmark/case_tcp/parse_to_blackhole/conf/wpgen.toml（生成器配置）
- **事件数**: 支持 `-m`（中等规模）与 `-c`（指定条数），事件含义与生成器配置保持一致
- **编码/分隔**: UTF-8 / LF
- **混合比例**: 不适用

## Configuration Binding
- **WarpParse**: benchmark/case_tcp/parse_to_blackhole/conf/wparse.toml（规则目录：benchmark/models/wpl/nginx；解析场景不启用 OML）
- **Vector-VRL**: benchmark/vector/vector-vrl/nginx_tcp_to_blackhole.toml
- **Vector-Fixed**: benchmark/vector/vector-fixed/nginx_tcp_to_blackhole.toml
- **Logstash**: benchmark/logstash/logstash_parse/nginx_tcp_to_blackhole.conf

## Execution Contract
- **结束条件**: 消费完等量事件（或按数据集规模），如需按时间结束请补充
- **并发/Worker**: 默认配置（wparse 的 parse_workers 以配置为准）
- **重复次数**: 默认单次；建议 N=3 取 median

## Metrics
- **EPS**: Events Per Second
- **MPS**: MiB/s，公式：`MPS = EPS * AvgEventSize / 1024 / 1024`
- **CPU**: 多核累计百分比（例如 800% ≈ 8 个逻辑核满载）
- **MEM**: 进程内存占用（Avg/Peak）
- **Rule Size**: 规则配置体积

## Performance Data

### Linux (AWS EC2)
| 引擎 | EPS | MPS | CPU (Avg/Peak) | MEM (Avg/Peak) | 性能倍数 |
| :-- | :-- | :-- | :-- | :-- | :-- |
| WarpParse | 765,800 | 174.55 | 574% / 628% | 245 MB / 366 MB | 1.56x |
| Vector-VRL | 492,200 | 112.19 | 501% / 510% | 155 MB / 159 MB | 1.0x |
| Vector-Fixed | 255,500 | 58.24 | 480% / 533% | 138 MB / 145 MB | 0.52x |
| Logstash | 161,290 | 36.76 | 462% / 475% | 1174 MB / 1224 MB | 0.33x |

### macOS (Mac M4 Mini)
| 引擎 | EPS | MPS | CPU (Avg/Peak) | MEM (Avg/Peak) | 性能倍数 |
| :-- | :-- | :-- | :-- | :-- | :-- |
| WarpParse | 1,657,500 | 377.80 | 530% / 580% | 307 MB / 320 MB | 1.42x |
| Vector-VRL | 1,163,700 | 265.24 | 540% / 598% | 218 MB / 224 MB | 1.0x |
| Vector-Fixed | 730,700 | 166.55 | 592% / 658% | 212 MB / 220 MB | 0.63x |
| Logstash | 541,403 | 123.40 | 465% / 667% | 1161 MB / 1234 MB | 0.47x |

## Correctness Check
- **对齐说明**: 参见 `benchmark/report/test_sample.md`
- **抽样方式**: 运行 file 输出链路进行抽样对比，检查关键字段与 Golden 输出一致
- **输出路径约定**: `benchmark/case_tcp/parse_to_file/data/out_dat/`（如需校验可切换到 file 输出）

## Notes
- **Loopback TCP**: TCP 场景均使用 127.0.0.1 回环，不受物理网卡限制
- **实例规格**: 若为 TBD，loopback TCP 口径不受实例带宽/ENI 影响
- **限制**: 单机测试，未覆盖分布式/HA

## References
- **Mac 报告**: benchmark/report/report_mac.md#311-nginx-access-log-239b（章节 3.1.1）
- **Linux 报告**: benchmark/report/report_linux.md#311-nginx-access-log-239b（章节 3.1.1）
- **规则说明**: benchmark/report/test_rule.md
- **样本对齐**: benchmark/report/test_sample.md
