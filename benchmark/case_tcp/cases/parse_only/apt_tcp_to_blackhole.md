# apt_tcp_to_blackhole

## Case Metadata
- **Case ID**: apt_tcp_to_blackhole
- **Category**: tcp
- **Capability**: parse_only
- **Topology**: tcp -> blackhole
- **Platforms**: Mac M4 Mini / Linux (AWS EC2)

## Scenario Definition
- **日志类型**: APT Threat Log (3K)
- **平均大小**: 3K
- **能力**: parse_only
- **输入/输出**: TCP -> BlackHole
- **说明**: APT Threat Log 场景，TCP 输入到 BlackHole 输出，执行 日志解析 能力。

## Dataset Contract
- **输入数据**: benchmark/case_tcp/parse_to_blackhole/data/in_dat/gen.dat（数据文件） / benchmark/case_tcp/parse_to_blackhole/conf/wpgen.toml（生成器配置）
- **事件数**: 支持 `-m`（中等规模）与 `-c`（指定条数），事件含义与生成器配置保持一致
- **编码/分隔**: UTF-8 / LF
- **混合比例**: 不适用

## Configuration Binding
- **WarpParse**: benchmark/case_tcp/parse_to_blackhole/conf/wparse.toml（规则目录：benchmark/models/wpl/apt；解析场景不启用 OML）
- **Vector-VRL**: benchmark/vector/vector-vrl/apt_tcp_to_blackhole.toml
- **Vector-Fixed**: benchmark/vector/vector-fixed/apt_tcp_to_blackhole.toml
- **Logstash**: benchmark/logstash/logstash_parse/apt_tcp_to_blackhole.conf

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
| WarpParse | 129,600 | 438.37 | 499% / 558% | 265 MB / 389 MB | 6.86x |
| Vector | 18,900 | 63.93 | 774% / 794% | 229 MB / 243 MB | 1.0x |
| Logstash | 10,183 | 34.45 | 733% / 757% | 1294 MB / 1308 MB | 0.54x |

### macOS (Mac M4 Mini)
| 引擎 | EPS | MPS | CPU (Avg/Peak) | MEM (Avg/Peak) | 性能倍数 |
| :-- | :-- | :-- | :-- | :-- | :-- |
| WarpParse | 299,700 | 1013.80 | 718% / 743% | 335 MB / 351 MB | 5.88x |
| Vector-VRL | 51,000 | 172.52 | 834% / 887% | 385 MB / 413 MB | 1.0x |
| Logstash | 31,446 | 106.37 | 843% / 892% | 1218 MB / 1313 MB | 0.62x |

## Correctness Check
- **对齐说明**: 参见 `benchmark/report/test_sample.md`
- **抽样方式**: 运行 file 输出链路进行抽样对比，检查关键字段与 Golden 输出一致
- **输出路径约定**: `benchmark/case_tcp/parse_to_file/data/out_dat/`（如需校验可切换到 file 输出）

## Notes
- **Loopback TCP**: TCP 场景均使用 127.0.0.1 回环，不受物理网卡限制
- **实例规格**: 若为 TBD，loopback TCP 口径不受实例带宽/ENI 影响
- **限制**: 单机测试，未覆盖分布式/HA

## References
- **Mac 报告**: benchmark/report/report_mac.md#314-apt-threat-log-3K（章节 3.1.4）
- **Linux 报告**: benchmark/report/report_linux.md#314-apt-threat-log-3K（章节 3.1.4）
- **规则说明**: benchmark/report/test_rule.md
- **样本对齐**: benchmark/report/test_sample.md
