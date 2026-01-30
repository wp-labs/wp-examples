# aws_tcp_to_file

## Case Metadata
- **Case ID**: aws_tcp_to_file
- **Category**: tcp
- **Capability**: parse_only
- **Topology**: tcp -> file
- **Platforms**: Mac M4 Mini / Linux (AWS EC2)

## Scenario Definition
- **日志类型**: AWS ELB Log (411B)
- **平均大小**: 411B
- **能力**: parse_only
- **输入/输出**: TCP -> File
- **说明**: AWS ELB Log 场景，TCP 输入到 File 输出，执行 日志解析 能力。

## Dataset Contract
- **输入数据**: benchmark/case_tcp/parse_to_blackhole/data/in_dat/gen.dat（数据文件） / benchmark/case_tcp/parse_to_file/conf/wpgen.toml（生成器配置）
- **事件数**: 支持 `-m`（中等规模）与 `-c`（指定条数），事件含义与生成器配置保持一致
- **编码/分隔**: UTF-8 / LF
- **混合比例**: 不适用

## Configuration Binding
- **WarpParse**: benchmark/case_tcp/parse_to_file/conf/wparse.toml（规则目录：benchmark/models/wpl/aws；解析场景不启用 OML）
- **Vector-VRL**: benchmark/vector/vector-vrl/aws_tcp_to_file.toml
- **Vector-Fixed**: benchmark/vector/vector-fixed/aws_tcp_to_file.toml
- **Logstash**: benchmark/logstash/logstash_parse/aws_tcp_to_file.conf

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
| WarpParse | 169,900 | 66.59 | 686% / 699% | 191 MB / 251 MB | 9.71x |
| Vector-VRL | 17,500 | 6.86 | 169% / 176% | 166 MB / 171 MB | 1.0x |
| Vector-Fixed | 16,600 | 6.51 | 159% / 171% | 157 MB / 164 MB | 0.95x |
| Logstash | 121,951 | 47.80 | 559% / 621% | 1283 MB / 1359 MB | 6.97x |

### macOS (Mac M4 Mini)
| 引擎 | EPS | MPS | CPU (Avg/Peak) | MEM (Avg/Peak) | 性能倍数 |
| :-- | :-- | :-- | :-- | :-- | :-- |
| WarpParse | 349,700 | 137.07 | 496% / 537% | 333 MB / 432 MB | 4.12x |
| Vector-VRL | 84,700 | 33.20 | 240% / 256% | 268 MB / 275 MB | 1.0x |
| Vector-Fixed | 86,900 | 34.06 | 199% / 208% | 252 MB / 264 MB | 1.03x |
| Logstash | 350,877 | 137.53 | 679% / 891% | 1288 MB / 1327 MB | 4.14x |

## Correctness Check
- **对齐说明**: 参见 `benchmark/report/test_sample.md`
- **抽样方式**: 运行 file 输出链路进行抽样对比，检查关键字段与 Golden 输出一致
- **输出路径约定**: `benchmark/case_tcp/parse_to_file/data/out_dat/`（如需校验可切换到 file 输出）

## Notes
- **Loopback TCP**: TCP 场景均使用 127.0.0.1 回环，不受物理网卡限制
- **实例规格**: 若为 TBD，loopback TCP 口径不受实例带宽/ENI 影响
- **限制**: 单机测试，未覆盖分布式/HA

## References
- **Mac 报告**: benchmark/report/report_mac.md#312-aws-elb-log-411b（章节 3.1.2）
- **Linux 报告**: benchmark/report/report_linux.md#312-aws-elb-log-411b（章节 3.1.2）
- **规则说明**: benchmark/report/test_rule.md
- **样本对齐**: benchmark/report/test_sample.md
