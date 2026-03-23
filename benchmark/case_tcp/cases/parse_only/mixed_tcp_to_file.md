# mixed_tcp_to_file

## Case Metadata
- **Case ID**: mixed_tcp_to_file
- **Category**: tcp
- **Capability**: parse_only
- **Topology**: tcp -> file
- **Platforms**: Mac M4 Mini / Linux (AWS EC2)

## Scenario Definition
- **日志类型**: Mixed Log (平均日志大小：886B)
- **平均大小**: 平均日志大小：886B
- **能力**: parse_only
- **输入/输出**: TCP -> File
- **说明**: Mixed Log 场景，TCP 输入到 File 输出，执行 日志解析 能力。

## Dataset Contract
- **输入数据**: benchmark/case_tcp/parse_to_blackhole/data/in_dat/gen.dat（数据文件） / benchmark/case_tcp/parse_to_file/conf/wpgen.toml（生成器配置）
- **事件数**: 支持 `-m`（中等规模）与 `-c`（指定条数），事件含义与生成器配置保持一致
- **编码/分隔**: UTF-8 / LF
- **混合比例**: 3:2:1:1（nginx:aws:firewall:apt）

## Configuration Binding
- **WarpParse**: benchmark/case_tcp/parse_to_file/conf/wparse.toml（规则目录：benchmark/models/wpl/mixed；解析场景不启用 OML）
- **Vector-VRL**: benchmark/vector/vector-vrl/mixed_tcp_to_file.toml
- **Vector-Fixed**: benchmark/vector/vector-fixed/mixed_tcp_to_file.toml
- **Logstash**: benchmark/logstash/logstash_parse/mixed_tcp_to_file.conf

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
| WarpParse | 149,400 | 126.24 | 546% / 623% | 111 MB / 221 MB | 7.82x |
| Vector-VRL | 19,100 | 16.14 | 315% / 332% | 275 MB / 287 MB | 1.00x |
| Vector-Fixed | 19,200 | 16.22 | 276% / 293% | 190 MB / 195 MB | 1.01x |
| Logstash | 32,786 | 27.70 | 593% / 670% | 1317 MB / 1428 MB | 1.72x |

### macOS (Mac M4 Mini)
| 引擎 | EPS | MPS | CPU (Avg/Peak) | MEM (Avg/Peak) | 性能倍数 |
| :-- | :-- | :-- | :-- | :-- | :-- |
| WarpParse | 308,400 | 260.58 | 537% / 560% | 177 MB / 251 MB | 3.90x |
| Vector-VRL | 79,000 | 66.75 | 383% / 415% | 393 MB / 396 MB | 1.0x |
| Vector-Fixed | 79,500 | 67.17 | 384% / 407% | 331 MB / 355 MB | 1.01x |
| Logstash | 126,582 | 106.96 | 879% / 972% | 1278 MB / 1296 MB | 1.60x |

## Correctness Check
- **对齐说明**: 参见 `benchmark/report/test_sample.md`
- **抽样方式**: 运行 file 输出链路进行抽样对比，检查关键字段与 Golden 输出一致
- **输出路径约定**: `benchmark/case_tcp/parse_to_file/data/out_dat/`（如需校验可切换到 file 输出）

## Notes
- **Loopback TCP**: TCP 场景均使用 127.0.0.1 回环，不受物理网卡限制
- **实例规格**: 若为 TBD，loopback TCP 口径不受实例带宽/ENI 影响
- **限制**: 单机测试，未覆盖分布式/HA

## References
- **Mac 报告**: benchmark/report/report_mac.md#315-mixed-log-平均日志大小886b（章节 3.1.5）
- **Linux 报告**: benchmark/report/report_linux.md#315-mixed-log-平均日志大小886b（章节 3.1.5）
- **规则说明**: benchmark/report/test_rule.md
- **样本对齐**: benchmark/report/test_sample.md
