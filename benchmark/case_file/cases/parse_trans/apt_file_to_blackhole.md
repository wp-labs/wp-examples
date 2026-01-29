# apt_file_to_blackhole

## Case Metadata
- **Case ID**: apt_file_to_blackhole
- **Category**: file
- **Capability**: parse_trans
- **Topology**: file -> blackhole
- **Platforms**: Mac M4 Mini / Linux (AWS EC2)

## Scenario Definition
- **日志类型**: APT Threat Log (3K)
- **平均大小**: 3K
- **能力**: parse_trans
- **输入/输出**: File -> BlackHole
- **说明**: APT Threat Log 场景，File 输入到 BlackHole 输出，执行 日志解析+转换 能力。

## Dataset Contract
- **输入数据**: benchmark/case_file/parse_to_blackhole/data/in_dat/gen.dat（数据文件） / benchmark/case_file/parse_to_blackhole/conf/wpgen.toml（生成器配置）
- **事件数**: 支持 `-m`（中等规模）与 `-c`（指定条数），事件含义与生成器配置保持一致
- **编码/分隔**: UTF-8 / LF
- **混合比例**: 不适用

## Configuration Binding
- **WarpParse**: benchmark/case_file/parse_to_blackhole/conf/wparse.toml（规则目录：benchmark/models/wpl/apt；解析+转换使用 benchmark/models/oml）
- **Vector-VRL**: benchmark/vector/vector-vrl_transform/apt_file_to_blackhole.toml
- **Vector-Fixed**: benchmark/vector/vector-fixed_transform/apt_file_to_blackhole.toml
- **Logstash**: benchmark/logstash/logstash_trans/apt_file_to_blackhole.conf

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
| WarpParse | 123,100 | 416.38 | 599% / 607% | 199 MB / 265 MB | 7.65x |
| Vector | 16,093 | 54.43 | 674% / 742% | 188 MB / 199 MB | 1.0x |
| Logstash | 7,633 | 25.82 | 657% / 732% | 1174 MB / 1197 MB | 0.47x |

### macOS (Mac M4 Mini)
| 引擎 | EPS | MPS | CPU (Avg/Peak) | MEM (Avg/Peak) | 性能倍数 |
| :-- | :-- | :-- | :-- | :-- | :-- |
| WarpParse | 299,400 | 1012.79 | 763% / 855% | 155 MB / 162 MB | 8.12x |
| Vector-VRL | 36,857 | 124.68 | 567% / 654% | 268 MB / 286 MB | 1.0x |
| Logstash | 26,315 | 89.02 | 852% / 901% | 1256 MB / 1305 MB | 0.71x |

## Correctness Check
- **对齐说明**: 参见 `benchmark/report/test_sample.md`
- **抽样方式**: 运行 file 输出链路进行抽样对比，检查关键字段与 Golden 输出一致
- **输出路径约定**: `benchmark/case_file/parse_to_file/data/out_dat/`（如需校验可切换到 file 输出）

## Notes
- **实例规格**: 若为 TBD，不影响 file 场景口径，但建议补齐以便复现
- **限制**: 单机测试，未覆盖分布式/HA

## References
- **Mac 报告**: benchmark/report/report_mac.md#324-apt-threat-log-3K（章节 3.2.4）
- **Linux 报告**: benchmark/report/report_linux.md#324-apt-threat-log-3K（章节 3.2.4）
- **规则说明**: benchmark/report/test_rule.md
- **样本对齐**: benchmark/report/test_sample.md
