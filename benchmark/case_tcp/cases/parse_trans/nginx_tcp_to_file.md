# nginx_tcp_to_file

## Case Metadata
- **Case ID**: nginx_tcp_to_file
- **Category**: tcp
- **Capability**: parse_trans
- **Topology**: tcp -> file
- **Platforms**: Mac M4 Mini / Linux (AWS EC2)

## Scenario Definition
- **日志类型**: Nginx Access Log (239B)
- **平均大小**: 239B
- **能力**: parse_trans
- **输入/输出**: TCP -> File
- **说明**: Nginx Access Log 场景，TCP 输入到 File 输出，执行 日志解析+转换 能力。

## Dataset Contract
- **输入数据**: benchmark/case_tcp/parse_to_blackhole/data/in_dat/gen.dat（数据文件） / benchmark/case_tcp/parse_to_file/conf/wpgen.toml（生成器配置）
- **事件数**: 支持 `-m`（中等规模）与 `-c`（指定条数），事件含义与生成器配置保持一致
- **编码/分隔**: UTF-8 / LF
- **混合比例**: 不适用

## Configuration Binding
- **WarpParse**: benchmark/case_tcp/parse_to_file/conf/wparse.toml（规则目录：benchmark/models/wpl/nginx；解析+转换使用 benchmark/models/oml）
- **Vector-VRL**: benchmark/vector/vector-vrl_transform/nginx_tcp_to_file.toml
- **Vector-Fixed**: benchmark/vector/vector-fixed_transform/nginx_tcp_to_file.toml
- **Logstash**: benchmark/logstash/logstash_trans/nginx_tcp_to_file.conf

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
| WarpParse | 297,100 | 67.72 | 645% / 664% | 238 MB / 317 MB | 17.90x |
| Vector-VRL | 16,600 | 3.78 | 138% / 143% | 138 MB / 143 MB | 1.0x |
| Vector-Fixed | 17,200 | 3.92 | 156% / 166% | 128 MB / 133MB | 1.04x |
| Logstash | 95,238 | 21.71 | 510% / 551% | 1141 MB / 1217 MB | 5.74x |

### macOS (Mac M4 Mini)
| 引擎 | EPS | MPS | CPU (Avg/Peak) | MEM (Avg/Peak) | 性能倍数 |
| :-- | :-- | :-- | :-- | :-- | :-- |
| WarpParse | 788,900 | 179.82 | 574% / 587% | 249 MB / 253 MB | 8.44x |
| Vector-VRL | 93,500 | 21.31 | 171% / 184% | 203 MB / 211 MB | 1.0x |
| Vector-Fixed | 87,500 | 19.94 | 208% / 223% | 197 MB / 212 MB | 0.94x |
| Logstash | 344,827 | 78.60 | 661% / 883% | 1202 MB / 1230 MB | 3.69x |

## Correctness Check
- **对齐说明**: 参见 `benchmark/report/test_sample.md`
- **抽样方式**: 运行 file 输出链路进行抽样对比，检查关键字段与 Golden 输出一致
- **输出路径约定**: `benchmark/case_tcp/parse_to_file/data/out_dat/`（如需校验可切换到 file 输出）

## Notes
- **Loopback TCP**: TCP 场景均使用 127.0.0.1 回环，不受物理网卡限制
- **实例规格**: 若为 TBD，loopback TCP 口径不受实例带宽/ENI 影响
- **限制**: 单机测试，未覆盖分布式/HA

## References
- **Mac 报告**: benchmark/report/report_mac.md#321-nginx-access-log-239b（章节 3.2.1）
- **Linux 报告**: benchmark/report/report_linux.md#321-nginx-access-log-239b（章节 3.2.1）
- **规则说明**: benchmark/report/test_rule.md
- **样本对齐**: benchmark/report/test_sample.md
