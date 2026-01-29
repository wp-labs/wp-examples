# mixed_file_to_blackhole

## Case Metadata
- **Case ID**: mixed_file_to_blackhole
- **Category**: file
- **Capability**: parse_only
- **Topology**: file -> blackhole
- **Platforms**: Mac M4 Mini / Linux (AWS EC2)

## Scenario Definition
- **日志类型**: Mixed Log (平均日志大小：886B)
- **平均大小**: 平均日志大小：886B
- **能力**: parse_only
- **输入/输出**: File -> BlackHole
- **说明**: Mixed Log 场景，File 输入到 BlackHole 输出，执行 日志解析 能力。

## Dataset Contract
- **输入数据**: benchmark/case_file/parse_to_blackhole/data/in_dat/gen.dat（数据文件） / benchmark/case_file/parse_to_blackhole/conf/wpgen.toml（生成器配置）
- **事件数**: 支持 `-m`（中等规模）与 `-c`（指定条数），事件含义与生成器配置保持一致
- **编码/分隔**: UTF-8 / LF
- **混合比例**: 3:2:1:1（nginx:aws:firewall:apt）

## Configuration Binding
- **WarpParse**: benchmark/case_file/parse_to_blackhole/conf/wparse.toml（规则目录：benchmark/models/wpl/mixed；解析场景不启用 OML）
- **Vector-VRL**: benchmark/vector/vector-vrl/mixed_file_to_blackhole.toml
- **Vector-Fixed**: benchmark/vector/vector-fixed/mixed_file_to_blackhole.toml
- **Logstash**: benchmark/logstash/logstash_parse/mixed_file_to_blackhole.conf

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
| WarpParse | 286,000 | 241.66 | 632% / 736% | 271 MB / 374 MB | 5.56x |
| Vector-VRL | 51,446 | 43.47 | 494% / 692% | 228 MB / 249 MB | 1.00x |
| Vector-Fixed | 52,530 | 44.39 | 500% / 696% | 182 MB / 201 MB | 1.02x |
| Logstash | 21,505 | 18.17 | 400% /444% | 1136 MB / 1163 MB | 0.42x |

### macOS (Mac M4 Mini)
| 引擎 | EPS | MPS | CPU (Avg/Peak) | MEM (Avg/Peak) | 性能倍数 |
| :-- | :-- | :-- | :-- | :-- | :-- |
| WarpParse | 715,000 | 604.14 | 860% / 868% | 246 MB / 254 MB | 3.76x |
| Vector-VRL | 190,000 | 160.54 | 827% / 880% | 281 MB / 329 MB | 1.0x |
| Vector-Fixed | 197,073 | 166.52 | 825% / 903% | 237 MB / 250 MB | 1.04x |
| Logstash | 109,890 | 86.43 | 746% / 955% | 1271 MB / 1292 MB | 0.62x |

## Correctness Check
- **对齐说明**: 参见 `benchmark/report/test_sample.md`
- **抽样方式**: 运行 file 输出链路进行抽样对比，检查关键字段与 Golden 输出一致
- **输出路径约定**: `benchmark/case_file/parse_to_file/data/out_dat/`（如需校验可切换到 file 输出）

## Notes
- **实例规格**: 若为 TBD，不影响 file 场景口径，但建议补齐以便复现
- **限制**: 单机测试，未覆盖分布式/HA

## References
- **Mac 报告**: benchmark/report/report_mac.md#315-mixed-log-平均日志大小886b（章节 3.1.5）
- **Linux 报告**: benchmark/report/report_linux.md#315-mixed-log-平均日志大小886b（章节 3.1.5）
- **规则说明**: benchmark/report/test_rule.md
- **样本对齐**: benchmark/report/test_sample.md
