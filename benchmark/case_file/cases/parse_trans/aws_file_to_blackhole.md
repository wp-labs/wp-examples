# aws_file_to_blackhole

## Case Metadata
- **Case ID**: aws_file_to_blackhole
- **Category**: file
- **Capability**: parse_trans
- **Topology**: file -> blackhole
- **Platforms**: Mac M4 Mini / Linux (AWS EC2)

## Scenario Definition
- **日志类型**: AWS ELB Log (411B)
- **平均大小**: 411B
- **能力**: parse_trans
- **输入/输出**: File -> BlackHole
- **说明**: AWS ELB Log 场景，File 输入到 BlackHole 输出，执行 日志解析+转换 能力。

## Dataset Contract
- **输入数据**: benchmark/case_file/parse_to_blackhole/data/in_dat/gen.dat（数据文件） / benchmark/case_file/parse_to_blackhole/conf/wpgen.toml（生成器配置）
- **事件数**: 支持 `-m`（中等规模）与 `-c`（指定条数），事件含义与生成器配置保持一致
- **编码/分隔**: UTF-8 / LF
- **混合比例**: 不适用

## Configuration Binding
- **WarpParse**: benchmark/case_file/parse_to_blackhole/conf/wparse.toml（规则目录：benchmark/models/wpl/aws；解析+转换使用 benchmark/models/oml）
- **Vector-VRL**: benchmark/vector/vector-vrl_transform/aws_file_to_blackhole.toml
- **Vector-Fixed**: benchmark/vector/vector-fixed_transform/aws_file_to_blackhole.toml
- **Logstash**: benchmark/logstash/logstash_trans/aws_file_to_blackhole.conf

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
| WarpParse | 275,900 | 108.14 | 649% / 719% | 236 MB / 327 MB | 2.22x |
| Vector-VRL | 124,333 | 48.73 | 523% / 560% | 190 MB / 199 MB | 1.0x |
| Vector-Fixed | 141,818 | 55.59 | 514% / 529% | 179 MB / 191 MB | 1.14x |
| Logstash | 54,054 | 21.19 | 582% / 653% | 1155 MB / 1217 MB | 0.43x |

### macOS (Mac M4 Mini)
| 引擎 | EPS | MPS | CPU (Avg/Peak) | MEM (Avg/Peak) | 性能倍数 |
| :-- | :-- | :-- | :-- | :-- | :-- |
| WarpParse | 913,300 | 358.00 | 880% / 942% | 228 MB / 248 MB | 2.64x |
| Vector-VRL | 345,500 | 135.42 | 548% / 649% | 291 MB / 309 MB | 1.0x |
| Vector-Fixed | 446,111 | 174.86 | 506% / 597% | 276 MB / 295 MB | 1.29x |
| Logstash | 147,058 | 57.64 | 525% / 701% | 1121 MB / 1170 MB | 0.43x |

## Correctness Check
- **对齐说明**: 参见 `benchmark/report/test_sample.md`
- **抽样方式**: 运行 file 输出链路进行抽样对比，检查关键字段与 Golden 输出一致
- **输出路径约定**: `benchmark/case_file/parse_to_file/data/out_dat/`（如需校验可切换到 file 输出）

## Notes
- **实例规格**: 若为 TBD，不影响 file 场景口径，但建议补齐以便复现
- **限制**: 单机测试，未覆盖分布式/HA

## References
- **Mac 报告**: benchmark/report/report_mac.md#322-aws-elb-log-411b（章节 3.2.2）
- **Linux 报告**: benchmark/report/report_linux.md#322-aws-elb-log-411b（章节 3.2.2）
- **规则说明**: benchmark/report/test_rule.md
- **样本对齐**: benchmark/report/test_sample.md
