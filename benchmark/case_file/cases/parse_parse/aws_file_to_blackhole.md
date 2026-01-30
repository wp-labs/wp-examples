# aws_file_to_blackhole

## Case Metadata
- **Case ID**: aws_file_to_blackhole
- **Category**: file
- **Capability**: parse_only
- **Topology**: file -> blackhole
- **Platforms**: Mac M4 Mini / Linux (AWS EC2)

## Scenario Definition
- **日志类型**: AWS ELB Log (411B)
- **平均大小**: 411B
- **能力**: parse_only
- **输入/输出**: File -> BlackHole
- **说明**: AWS ELB Log 场景，File 输入到 BlackHole 输出，执行 日志解析 能力。

## Dataset Contract
- **输入数据**: benchmark/case_file/parse_to_blackhole/data/in_dat/gen.dat（数据文件） / benchmark/case_file/parse_to_blackhole/conf/wpgen.toml（生成器配置）
- **事件数**: 支持 `-m`（中等规模）与 `-c`（指定条数），事件含义与生成器配置保持一致
- **编码/分隔**: UTF-8 / LF
- **混合比例**: 不适用

## Configuration Binding
- **WarpParse**: benchmark/case_file/parse_to_blackhole/conf/wparse.toml（规则目录：benchmark/models/wpl/aws；解析场景不启用 OML）
- **Vector-VRL**: benchmark/vector/vector-vrl/aws_file_to_blackhole.toml
- **Vector-Fixed**: benchmark/vector/vector-fixed/aws_file_to_blackhole.toml
- **Logstash**: benchmark/logstash/logstash_parse/aws_file_to_blackhole.conf

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
| WarpParse | 398,800 | 156.31 | 698% / 756% | 194 MB / 366 MB | 2.82x |
| Vector-VRL | 141,600 | 55.50 | 423% / 437% | 166 MB / 170 MB | 1.0x |
| Vector-Fixed | 161,944 | 63.47 | 496% / 515% | 174 MB / 179 MB | 1.14x |
| Logstash | 87,719 | 34.38 | 514% / 532% | 1145 MB / 1170 MB | 0.62x |

### macOS (Mac M4 Mini)
| 引擎 | EPS | MPS | CPU (Avg/Peak) | MEM (Avg/Peak) | 性能倍数 |
| :-- | :-- | :-- | :-- | :-- | :-- |
| WarpParse | 1,124,500 | 440.79 | 787% / 824% | 314 MB / 320 MB | 2.89x |
| Vector-VRL | 389,000 | 152.47 | 597% / 658% | 280 MB / 297 MB | 1.0x |
| Vector-Fixed | 491,739 | 192.74 | 514% / 537% | 259 MB / 284 MB | 1.26x |
| Logstash | 208,333 | 81.66 | 394% / 506% | 983 MB / 1141 MB | 0.54x |

## Correctness Check
- **对齐说明**: 参见 `benchmark/report/test_sample.md`
- **抽样方式**: 运行 file 输出链路进行抽样对比，检查关键字段与 Golden 输出一致
- **输出路径约定**: `benchmark/case_file/parse_to_file/data/out_dat/`（如需校验可切换到 file 输出）

## Notes
- **实例规格**: 若为 TBD，不影响 file 场景口径，但建议补齐以便复现
- **限制**: 单机测试，未覆盖分布式/HA

## References
- **Mac 报告**: benchmark/report/report_mac.md#312-aws-elb-log-411b（章节 3.1.2）
- **Linux 报告**: benchmark/report/report_linux.md#312-aws-elb-log-411b（章节 3.1.2）
- **规则说明**: benchmark/report/test_rule.md
- **样本对齐**: benchmark/report/test_sample.md
