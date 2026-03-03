# 测试场景：firewall_file_to_blackhole

## Case Metadata
- **Case ID**: firewall_file_to_blackhole
- **Category**: file
- **Capability**: parse_only
- **Topology**: file -> blackhole
- **Platforms**: Mac M4 Mini / Linux (AWS EC2)

## Scenario Definition
- **日志类型**: Firewall Log (1K)
- **平均大小**: 1K
- **能力**: parse_only
- **输入/输出**: File -> BlackHole
- **说明**: Firewall Log 场景，File 输入到 BlackHole 输出，执行 日志解析 能力。

## Dataset Contract
- **输入数据**: benchmark/case_file/parse_to_blackhole/data/in_dat/gen.dat（数据文件） / benchmark/case_file/parse_to_blackhole/conf/wpgen.toml（生成器配置）
- **事件数**: 支持 `-m`（中等规模）与 `-c`（指定条数），事件含义与生成器配置保持一致
- **编码/分隔**: UTF-8 / LF
- **混合比例**: 不适用

## Configuration Binding
- **WarpParse**: benchmark/case_file/parse_to_blackhole/conf/wparse.toml（规则目录：benchmark/models/wpl/firewall；解析场景不启用 OML）
- **Vector-VRL**: benchmark/vector/vector-vrl/firewall_file_to_blackhole.toml
- **Vector-Fixed**: benchmark/vector/vector-fixed/firewall_file_to_blackhole.toml
- **Logstash**: benchmark/logstash/logstash_parse/firewall_file_to_blackhole.conf

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
| WarpParse | 163,700 | 175.16 | 672% / 761% | 272 MB / 441 MB | 2.88x |
| Vector | 56,760 | 60.73 | 513% / 693% | 176 MB / 204 MB | 1.00x |
| Logstash | 17,391 | 18.61 | 675% / 724% | 1201 MB / 1228 MB | 0.31x |

### macOS (Mac M4 Mini)
| 引擎 | EPS | MPS | CPU (Avg/Peak) | MEM (Avg/Peak) | 性能倍数 |
| :-- | :-- | :-- | :-- | :-- | :-- |
| WarpParse | 459,900 | 492.10 | 887% / 923% | 229 MB / 234 MB | 4.24x |
| Vector-VRL | 115,322 | 123.40 | 456% / 504% | 254 MB / 275 MB | 1.00x |
| Logstash | 50,505 | 54.04 | 881% / 929% | 1139 MB / 1192 MB | 0.47x |

## Correctness Check
- **对齐说明**: 参见 `benchmark/report/test_sample.md`
- **抽样方式**: 运行 file 输出链路进行抽样对比，检查关键字段与 Golden 输出一致
- **输出路径约定**: `benchmark/case_file/parse_to_file/data/out_dat/`（如需校验可切换到 file 输出）

## Notes
- **实例规格**: 若为 TBD，不影响 file 场景口径，但建议补齐以便复现
- **限制**: 单机测试，未覆盖分布式/HA

## References
- **Mac 报告**: benchmark/report/report_mac.md#313-firewall-log-1k（章节 3.1.3）
- **Linux 报告**: benchmark/report/report_linux.md#313-firewall-log-1k（章节 3.1.3）
- **规则说明**: benchmark/report/test_rule.md
- **样本对齐**: benchmark/report/test_sample.md
