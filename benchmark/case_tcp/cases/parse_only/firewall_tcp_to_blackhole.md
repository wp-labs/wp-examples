# 测试场景：firewall_tcp_to_blackhole

## Case Metadata
- **Case ID**: firewall_tcp_to_blackhole
- **Category**: tcp
- **Capability**: parse_only
- **Topology**: tcp -> blackhole
- **Platforms**: Mac M4 Mini / Linux (AWS EC2)

## Scenario Definition
- **日志类型**: Firewall Log (1K)
- **平均大小**: 1K
- **能力**: parse_only
- **输入/输出**: TCP -> BlackHole
- **说明**: Firewall Log 场景，TCP 输入到 BlackHole 输出，执行 日志解析 能力。

## Dataset Contract
- **输入数据**: benchmark/case_tcp/parse_to_blackhole/data/in_dat/gen.dat（数据文件） / benchmark/case_tcp/parse_to_blackhole/conf/wpgen.toml（生成器配置）
- **事件数**: 支持 `-m`（中等规模）与 `-c`（指定条数），事件含义与生成器配置保持一致
- **编码/分隔**: UTF-8 / LF
- **混合比例**: 不适用

## Configuration Binding
- **WarpParse**: benchmark/case_tcp/parse_to_blackhole/conf/wparse.toml（规则目录：benchmark/models/wpl/firewall；解析场景不启用 OML）
- **Vector-VRL**: benchmark/vector/vector-vrl/firewall_tcp_to_blackhole.toml
- **Vector-Fixed**: benchmark/vector/vector-fixed/firewall_tcp_to_blackhole.toml
- **Logstash**: benchmark/logstash/logstash_parse/firewall_tcp_to_blackhole.conf

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
| WarpParse | 154,900 | 165.75 | 665% / 735% | 128 MB / 353 MB | 2.38x |
| Vector | 65,200 | 69.77 | 648% / 768% | 240 MB / 253 MB | 1.00x |
| Logstash | 19,157 | 20.50 | 722% / 745% | 1283 MB / 1298 MB | 0.29x |

### macOS (Mac M4 Mini)
| 引擎 | EPS | MPS | CPU (Avg/Peak) | MEM (Avg/Peak) | 性能倍数 |
| :-- | :-- | :-- | :-- | :-- | :-- |
| WarpParse | 406,400 | 434.86 | 761% / 787% | 424 MB / 484 MB | 2.15x |
| Vector-VRL | 188,800 | 186.50 | 691% / 790% | 373 MB / 393 MB | 1.00x |
| Logstash | 54,347 | 58.15 | 874% / 934% | 1223 MB / 1260 MB | 0.31x |

## Correctness Check
- **对齐说明**: 参见 `benchmark/report/test_sample.md`
- **抽样方式**: 运行 file 输出链路进行抽样对比，检查关键字段与 Golden 输出一致
- **输出路径约定**: `benchmark/case_tcp/parse_to_file/data/out_dat/`（如需校验可切换到 file 输出）

## Notes
- **Loopback TCP**: TCP 场景均使用 127.0.0.1 回环，不受物理网卡限制
- **实例规格**: 若为 TBD，loopback TCP 口径不受实例带宽/ENI 影响
- **限制**: 单机测试，未覆盖分布式/HA

## References
- **Mac 报告**: benchmark/report/report_mac.md#313-firewall-log-1k（章节 3.1.3）
- **Linux 报告**: benchmark/report/report_linux.md#313-firewall-log-1k（章节 3.1.3）
- **规则说明**: benchmark/report/test_rule.md
- **样本对齐**: benchmark/report/test_sample.md
