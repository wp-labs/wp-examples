#  WarpParse、Vector、Logstash 性能基准测试报告

## 1. 技术概述与测试背景

### 1.1 测试背景

本报告记录在 Linux 平台完成的单机基准测试结果，覆盖从轻量级 Web 日志到复杂安全威胁日志的典型场景，用于形成阶段性 benchmark 基线，便于后续版本或方案之间的横向与纵向对比。本文仅描述测试方法与结果，不对生产环境性能上限作外推。

### 1.2 被测对象

*   **WarpParse**: 大禹安全公司研发的 ETL 核心引擎，采用 Rust 构建。
*   **Vector**: 开源可观测性数据管道工具，采用 Rust 构建。
    *   Vector-VRL：基于 VRL 的 `parse_regex` 进行正则解析。
    *   Vector-Fixed：尽量使用内置解析（如 nginx/aws 内置函数；sysmon 直接 JSON 解析；APT 无专用手段仍使用正则）。
*   **Logstash**: Elastic 生态的日志处理引擎，采用 JVM 运行时。

### 1.3 测试对象与版本说明

本次测试使用版本如下：

*   **WarpParse**：0.12.0
*   **Vector**：0.49.0
*   **Logstash**：9.2.3

构建与来源信息：

*   **WarpParse**：构建来源/commit/tag = GitHub tag v0.12.0-alpha (commit: 2ba6e55)；构建参数 = 官方 release 构建产物（zip/tar.gz），未修改构建选项
*   **Vector**：构建来源/commit/tag = v0.49.0 (commit: dc7e792)；构建参数 = 官方发布的 release 二进制，未修改构建选项
*   **Logstash**：构建来源/commit/tag = GitHub tag v9.2.3 (commit: 4eb0f3f)；构建参数 = 官方发行包（zip / tar.gz，bundled JDK），未进行源码级构建

本报告已记录版本与构建来源；复现时仍需确保引擎运行参数、系统配置与数据集参数一致。

### 1.4 报告定位

本文档定位为阶段性 benchmark 报告，侧重方法与数据的可复现性与长期可比性，不作为最终性能结论或生产容量承诺。


## 2. 测试环境与方法

### 2.1 测试环境（Test Environment）

#### 平台信息（Platform）
- **平台类型**：AWS EC2
- **实例规格（Instance Type）**：c5a.2xlarge
- **操作系统**：Ubuntu 24.04 LTS
- **系统架构**：x86_64
- 网络环境：本机回环（127.0.0.1，Loopback）

#### 计算资源（Compute）
- **CPU**：8 vCPU
- **CPU 型号**：AMD EPYC 7R32
- **内存**：16 GiB

#### 存储配置（Storage）
- **存储类型**：Amazon EBS
- **卷类型**：通用型 SSD（gp3）
- **卷大小**：128 GiB
- **IOPS**：30,000
- **吞吐量**：200 MiB/s

#### 说明（Notes）
- gp3 卷支持 IOPS 与吞吐量独立配置，用于避免容量与性能强绑定  
- 当前配置提供较高的随机 I/O 能力（IOPS），并具备中等顺序 I/O 吞吐能力  
- 网络带宽/网卡能力：
  - 本报告中的 TCP 场景均基于本机 loopback（127.0.0.1）进行数据发送与接收；
  - 测试流量不经过物理网卡或云实例网络链路，不受实例网络带宽或 ENI 性能限制；
  - TCP 场景主要反映内核 TCP 协议栈开销与引擎自身的解析、调度与 I/O 处理能力。

### 2.2 测试范畴 (Scope)

*   **日志类型**:
    *   **Nginx Access Log** (239B): 典型 Web 访问日志，高吞吐场景。
    *   **AWS ELB Log** (411B): 云设施负载均衡日志，中等复杂度。
    *   **Firewall Log** (1K): 终端安全监控日志，JSON 结构，字段较多。
    *   **APT Threat Log** (3K): 模拟的高级持续性威胁日志，大体积、长文本。
    *   **Mixed Log** (886B): 上述四类日志混合形成的日志类型。
*   **数据拓扑**:
    *   **File -> BlackHole**: 测算引擎极限 I/O 读取与处理能力 (基准)。
    *   **TCP -> BlackHole**: 测算网络接收与处理能力。
    *   **TCP -> File**: 测算端到端完整落地能力。
*   **测试能力**:
    *   **解析 (Parse)**: 仅进行正则提取/KV解析与字段标准化。
    *   **解析+转换 (Parse+Transform)**: 在解析基础上增加字段映射、富化、类型转换等逻辑。

### 2.3 评估指标

*   **EPS (Events Per Second)**: 每秒处理事件数（核心吞吐指标）。
*   **MPS (MiB/s)**: 每秒处理数据量。
*   **CPU (Avg/Peak)**: 测试进程 CPU 使用率的平均值与峰值。
*   **MEM (Avg/Peak)**: 测试进程内存占用的平均值与峰值。
*   **Rule Size**: 规则配置文件体积，评估分发与维护成本。
*   **性能倍数**: 在同一日志类型 + 同一拓扑下，以 Vector-VRL 的 EPS 为 1.0x 进行归一化。

说明：
*   CPU 为多核累计百分比（例如 800% ≈ 8 个逻辑核满载），统计对象为**测试进程本身**（非系统总 CPU），由外部监控脚本按固定采样周期采集并计算 Avg/Peak。
*   MPS 换算公式：**MPS = EPS × AvgLogSize(B) / 1024 / 1024**。

- 采样来源与采样口径说明：
  - EPS：统一基于各引擎原生可观测性或统计接口获取。
    - WarpParse / Vector：使用引擎内置的吞吐统计能力。
    - Logstash：通过自动化脚本定期采集其官方 Monitoring API / 运行时统计信息。
  - CPU / MEM：通过外部监控脚本采集测试进程的资源使用情况（基于 shell 的周期性采样），用于跨引擎对比。
  - MPS：基于测得的 EPS 与对应日志的平均大小进行换算计算，用于辅助衡量实际数据吞吐规模。
  - 规则大小统计前对配置进行了统一去注释/去空行处理，仅保留有效表达部分，降低格式差异影响。
  - 各指标在不同引擎中的采集实现方式可能不同，但统计口径保持一致，结果以各指标最权威来源为准。

### 2.4 测试方法与执行方式

测试在单机环境中按日志类型与拓扑逐项执行。输入数据由本仓库提供的 benchmark 脚本生成或回放，
测试过程中各引擎独立运行，避免相互干扰。
输出目标根据测试拓扑配置为 BlackHole 或 File，以分别评估纯处理能力与包含 I/O 的端到端性能。

测试执行流程、脚本入口及通用参数说明见 benchmark/README.md。

### 2.4.1 最小复现清单（Minimal Repro Checklist）

  - 引擎版本与来源：
    - WarpParse / Vector / Logstash 的版本、tag、commit 及构建方式见 1.3。

  - Benchmark 工具链版本：
    - benchmark 仓库以 wp-example 仓库的最新提交（repo HEAD）为准。
    - 复现实验时建议记录具体 commit hash 以保证结果可追溯。

  - 数据规模与事件数量：
    - 本报告中“数据集规模”与“事件数量”为同一概念，均以处理的事件总数作为规模定义。
    - 在 WarpParse 的 benchmark 执行脚本中，通过参数 `-c` 指定事件总数；
      该参数用于明确数据集规模，但并非要求所有引擎具备相同参数形式。
    - 对于 Vector 与 Logstash，测试数据集规模与 WarpParse 使用相同的事件数量，
      通过等量输入数据实现规模对齐，而非依赖统一的启动参数。
    - 因此，`-c` 可视为本 benchmark 中“统一事件规模定义”的符号化表示，
      而非跨引擎通用的命令行参数。

  - 结束条件：
    - 所有测试均以处理完成等量事件作为结束条件。
    - 不采用按固定运行时长结束的方式，
      以避免不同引擎在启动、预热与稳定阶段差异带来的统计偏差。

- Warmup 与采样窗口：
  - WarpParse 与 Vector：引擎启动后快速进入稳定状态，未单独区分 warmup 阶段。
  - Logstash：由于 JVM/JIT 与 pipeline 初始化特性，测试前先进行 warmup 运行；
    在确认吞吐进入稳定区间后，开始采集 EPS / 资源指标。

  - 重复次数与取值规则：
    - 默认单次运行。
    - 如需更严格统计，建议重复 N=3 次并取 median 作为最终结果。

### 2.5 默认配置与调优说明

除非表格或备注中明确说明，本报告结果基于各引擎默认配置，未开启专项性能调优或非默认参数。

## 3. 详细吞吐量性能对比分析

### 3.0 测试结果汇总表

下表为结果索引，用于定位不同日志类型与测试能力的明细表格。

| 日志类型 | 解析（Parse Only） | 解析 + 转换（Parse + Transform） |
| :-- | :-- | :-- |
| Nginx Access Log (239B) | 见 3.1.1 | 见 3.2.1 |
| AWS ELB Log (411B) | 见 3.1.2 | 见 3.2.2 |
| Firewall Log (1K) | 见 3.1.3 | 见 3.2.3 |
| APT Threat Log (3K) | 见 3.1.4 | 见 3.2.4 |
| Mixed Log (平均日志大小：867B) | 见 3.1.5 | 见 3.2.5 |

### 3.1 日志解析能力 (Parse Only)
本节给出纯解析场景的测试结果。

#### 3.1.1 Nginx Access Log (239B)

表 3.1.1-1：Nginx Access Log（Parse Only；File -> BlackHole / TCP -> BlackHole / TCP -> File）

| 引擎          | 拓扑              | EPS         | MPS    | CPU (Avg/Peak) | MEM (Avg/Peak)  | 性能倍数 |
| :------------ | :---------------- | :---------- | :----- | :------------- | :-------------- | :------- |
| **WarpParse** | File -> BlackHole | **810,100** | 184.65 | 626% / 639%    | 115 MB / 314 MB | **3.83x** |
| Vector-VRL    | File -> BlackHole | 211,250     | 48.15  | 292% / 305%    | 148 MB / 153 MB | 1.0x     |
| Vector-Fixed  | File -> BlackHole | 170,666     | 38.90  | 431% / 451%    | 141 MB / 151 MB | 0.81x    |
| Logstash | File -> BlackHole | 106,382 | 24.25 | 436% / 461% | 1144 MB / 1175 MB | 0.50x |
| **WarpParse** | TCP -> BlackHole  | **765,800** | 174.55 | 574% / 628%    | 245 MB / 366 MB | **1.56x** |
| Vector-VRL    | TCP -> BlackHole  | 492,200     | 112.19 | 501% / 510%    | 155 MB / 159 MB | 1.0x     |
| Vector-Fixed  | TCP -> BlackHole  | 255,500     | 58.24  | 480% / 533%    | 138 MB / 145 MB | 0.52x    |
| Logstash | TCP -> BlackHole | 161,290 | 36.76 | 462% / 475% | 1174 MB / 1224 MB | 0.33x |
| **WarpParse** | TCP -> File       | **377,600** | 86.07  | 645% / 673%    | 221 MB / 444 MB | **20.30x** |
| Vector-VRL    | TCP -> File       | 18,600      | 4.24   | 133% / 135%    | 122 MB / 126 MB | 1.0x     |
| Vector-Fixed  | TCP -> File       | 17,300      | 3.94   | 148% / 156%    | 115 MB / 119 MB | 0.93x    |
| Logstash | TCP -> File | 147,058 | 33.52 | 465% / 476% | 1148 MB / 1186 MB | 7.91x |

> 解析规则大小：
>
> - WarpParse：174B
> - Vector-VRL：217B
> - Vector-Fixed：86B
> - Logstash：248B
>
> 在同一日志类型 + 同一拓扑下，以 Vector-VRL 的 EPS 作为统一基准（1.0x），对所有引擎进行归一化对比。

#### 3.1.2 AWS ELB Log (411B)

表 3.1.2-1：AWS ELB Log（Parse Only；File -> BlackHole / TCP -> BlackHole / TCP -> File）

| 引擎          | 拓扑              | EPS         | MPS    | CPU (Avg/Peak) | MEM (Avg/Peak)  | 性能倍数 |
| :------------ | :---------------- | :---------- | :----- | :------------- | :-------------- | :------- |
| **WarpParse** | File -> BlackHole | **398,800** | 156.31 | 698% / 756%    | 194 MB / 366 MB | **2.82x** |
| Vector-VRL    | File -> BlackHole | 141,600     | 55.50  | 423% / 437%    | 166 MB / 170 MB | 1.0x     |
| Vector-Fixed  | File -> BlackHole | 161,944     | 63.47  | 496% / 515%    | 174 MB / 179 MB | 1.14x    |
| Logstash | File -> BlackHole | 87,719 | 34.38 | 514% / 532% | 1145 MB / 1170 MB | 0.62x |
| **WarpParse** | TCP -> BlackHole  | **369,900** | 144.98 | 669% / 724%    | 178 MB / 461 MB | **2.49x** |
| Vector-VRL    | TCP -> BlackHole  | 148,400     | 58.16  | 456% / 486%    | 178 MB / 185 MB | 1.0x     |
| Vector-Fixed  | TCP -> BlackHole  | 176,600     | 69.22  | 417% / 435%    | 169 MB / 176 MB | 1.19x    |
| Logstash | TCP -> BlackHole | 125,000 | 49.00 | 557% / 625% | 1181 MB / 1217 MB | 0.84x |
| **WarpParse** | TCP -> File       | **169,900** | 66.59  | 686% / 699%    | 191 MB / 251 MB | **9.71x** |
| Vector-VRL    | TCP -> File       | 17,500      | 6.86   | 169% / 176%    | 166 MB / 171 MB | 1.0x     |
| Vector-Fixed  | TCP -> File       | 16,600      | 6.51   | 159% / 171%    | 157 MB / 164 MB | 0.95x    |
| Logstash | TCP -> File | 121,951 | 47.80 | 559% / 621% | 1283 MB / 1359 MB | 6.97x |

> 解析规则大小：
>
> - WarpParse：1153B
> - Vector-VRL：921B
> - Vector-Fixed：64B
> - Logstash：876B
>
> 在同一日志类型 + 同一拓扑下，以 Vector-VRL 的 EPS 作为统一基准（1.0x），对所有引擎进行归一化对比。

#### 3.1.3 Firewall Log (1K)

表 3.1.3-1： Firewall Log（Parse Only；File -> BlackHole / TCP -> BlackHole / TCP -> File）

| 引擎          | 拓扑              | EPS         | MPS    | CPU (Avg/Peak) | MEM (Avg/Peak)  | 性能倍数 |
| :------------ | :---------------- | :---------- | :----- | :------------- | :-------------- | :------- |
| **WarpParse** | File -> BlackHole | **163,700** | 175.16 | 672% / 761% | 272 MB / 441 MB | **2.88x** |
| Vector  | File -> BlackHole | 56,760 | 60.73 | 513% / 693% | 176 MB / 204 MB | 1.00x |
| Logstash | File -> BlackHole | 17,391 | 18.61 | 675% / 724% | 1201 MB / 1228 MB | 0.31x |
| **WarpParse** | TCP -> BlackHole  | **154,900** | 165.75 | 665% / 735% | 128 MB / 353 MB | **2.38x** |
| Vector  | TCP -> BlackHole  | 65,200 | 69.77 | 648% / 768% | 240 MB / 253 MB | 1.00x |
| Logstash | TCP -> BlackHole | 19,157 | 20.50 | 722% / 745% | 1283 MB / 1298 MB | 0.29x |
| **WarpParse** | TCP -> File       | **99,700** | 106.68 | 659% / 746% | 89 MB / 280 MB | **5.09x** |
| Vector  | TCP -> File       | 19,600 | 20.97 | 293% / 328% | 243 MB / 253 MB | 1.00x |
| Logstash | TCP -> File | 18,018 | 19.28 | 654% / 709% | 1292 MB / 1364 MB | 0.92x |

> 解析规则大小：
>
> - WarpParse：1552B
> - Vector-Fixed：1852B
> - Logstash：2406B
> 
>在同一日志类型 + 同一拓扑下，以 Vector 的 EPS 作为统一基准（1.0x），对所有引擎进行归一化对比。

#### 3.1.4 APT Threat Log (3K)

表 3.1.4-1：APT Threat Log（Parse Only；File -> BlackHole / TCP -> BlackHole / TCP -> File）

| 引擎          | 拓扑              | EPS         | MPS    | CPU (Avg/Peak) | MEM (Avg/Peak)  | 性能倍数 |
| :------------ | :---------------- | :---------- | :----- | :------------- | :-------------- | :------- |
| **WarpParse** | File -> BlackHole | **129,700** | 438.71 | 535% / 543%    | 273 MB / 295 MB | **7.67x** |
| Vector    | File -> BlackHole | 16,901      | 57.17  | 692% / 730%    | 175 MB / 180 MB | 1.0x     |
| Logstash | File -> BlackHole | 9,009 | 30.47 | 684% / 736% | 1211 MB / 1229 MB | 0.53x |
| **WarpParse** | TCP -> BlackHole  | **129,600** | 438.37 | 499% / 558%    | 265 MB / 389 MB | **6.86x** |
| Vector    | TCP -> BlackHole  | 18,900      | 63.93  | 774% / 794%    | 229 MB / 243 MB | 1.0x     |
| Logstash | TCP -> BlackHole | 10,183 | 34.45 | 733% / 757% | 1294 MB / 1308 MB | 0.54x |
| **WarpParse** | TCP -> File       | **55,000**  | 186.04 | 362% / 368%    | 197 MB / 224 MB | **5.91x** |
| Vector    | TCP -> File       | 9,300       | 31.46  | 412% / 450%    | 211 MB / 218 MB | 1.0x     |
| Logstash | TCP -> File | 8,928 | 30.20 | 672% / 726% | 1305 MB / 1369 MB | 0.96x |

> 解析规则大小：
>
> - WarpParse：985B
> - Vector：873B
> - Logstash：1027B
> 
>在同一日志类型 + 同一拓扑下，以 Vector 的 EPS 作为统一基准（1.0x），对所有引擎进行归一化对比。

#### 3.1.5 Mixed Log (平均日志大小：886B)

表 3.1.5-1：Mixed Log（Parse Only；File -> BlackHole / TCP -> BlackHole / TCP -> File）

| 引擎          | 拓扑              | EPS         | MPS    | CPU (Avg/Peak) | MEM (Avg/Peak)  | 性能倍数 |
| :------------ | :---------------- | :---------- | :----- | :------------- | :-------------- | :------- |
| **WarpParse** | File -> BlackHole | **286,000** | 241.66 | 632% / 736% | 271 MB / 374 MB | **5.56x** |
| Vector-VRL    | File -> BlackHole | 51,446 | 43.47 | 494% / 692% | 228 MB / 249 MB | 1.00x     |
| Vector-Fixed  | File -> BlackHole | 52,530 | 44.39 | 500% / 696% | 182 MB / 201 MB | 1.02x |
| Logstash | File -> BlackHole | 21,505 | 18.17 | 400% /444% | 1136 MB / 1163 MB | 0.42x |
| **WarpParse** | TCP -> BlackHole  | **258,600** | 218.51 | 532% / 709% | 189 MB / 483 MB | **3.10x** |
| Vector-VRL    | TCP -> BlackHole  | 83,300 | 70.38 | 516% / 781% | 208 MB / 222 MB | 1.00x     |
| Vector-Fixed  | TCP -> BlackHole  | 81,700 | 69.03 | 518% / 784% | 181 MB / 191 MB | 0.98x |
| Logstash | TCP -> BlackHole | 35,087 | 29.65 | 629% / 697% | 1222 MB / 1282 MB | 0.42x |
| **WarpParse** | TCP -> File       | **149,400** | 126.24 | 546% / 623% | 111 MB / 221 MB | **7.82x** |
| Vector-VRL    | TCP -> File       | 19,100 | 16.14 | 315% / 332% | 275 MB / 287 MB | 1.00x     |
| Vector-Fixed  | TCP -> File       | 19,200 | 16.22 | 276% / 293% | 190 MB / 195 MB | 1.01x |
| Logstash | TCP -> File | 32,786 | 27.70 | 593% / 670% | 1317 MB / 1428 MB | 1.72x |

> 解析规则大小：
>
> - WarpParse：3864B
> - Vector-VRL：3960B
> - Vector-Fixed：4725B
> - Logstash：5396B
>
> 在同一日志类型 + 同一拓扑下，以 Vector-VRL 的 EPS 作为统一基准（1.0x），对所有引擎进行归一化对比。
>
> 规则大小可能受格式/换行/注释/路径等影响，体积差异不影响性能口径；规则逻辑保持一致。
>
> 混合日志规则：
>
> - 4类日志按照3:2:1:1混合


### 3.2 解析 + 转换能力 (Parse + Transform)

本节给出解析 + 转换场景的测试结果。

#### 3.2.1 Nginx Access Log（239B）

表 3.2.1-1：Nginx Access Log（Parse + Transform；File -> BlackHole / TCP -> BlackHole / TCP -> File）

| 引擎          | 拓扑              | EPS         | MPS    | CPU (Avg/Peak) | MEM (Avg/Peak)  | 性能倍数 |
| :------------ | :---------------- | :---------- | :----- | :------------- | :-------------- | :------- |
| **WarpParse** | File -> BlackHole | **656,800** | 149.71 | 688% / 768%    | 220 MB / 357 MB | **3.27x** |
| Vector-VRL    | File -> BlackHole | 201,000     | 45.81  | 339% / 350%    | 167 MB / 175 MB | 1.0x     |
| Vector-Fixed  | File -> BlackHole | 153,333     | 34.95  | 466% / 481%    | 159 MB / 168 MB | 0.76x    |
| Logstash | File -> BlackHole | 76,923 | 17.53 | 470% / 483% | 1126 MB / 1160 MB | 0.38x |
| **WarpParse** | TCP -> BlackHole  | **524,800** | 119.62 | 608% / 637%    | 189 MB / 410 MB | **1.34x** |
| Vector-VRL    | TCP -> BlackHole  | 392,200     | 89.39  | 472% / 512%    | 162 MB / 166 MB | 1.0x     |
| Vector-Fixed  | TCP -> BlackHole  | 208,900     | 47.61  | 502% / 537%    | 146 MB / 151 MB | 0.53x    |
| Logstash | TCP -> BlackHole | 107,142 | 24.42 | 520% / 552% | 1163 MB / 1243 MB | 0.27x |
| **WarpParse** | TCP -> File       | **297,100** | 67.72  | 645% / 664%    | 238 MB / 317 MB | **17.90x** |
| Vector-VRL    | TCP -> File       | 16,600      | 3.78   | 138% / 143%    | 138 MB / 143 MB | 1.0x     |
| Vector-Fixed  | TCP -> File       | 17,200      | 3.92   | 156% / 166%    | 128 MB / 133MB  | 1.04x    |
| Logstash | TCP -> File | 95,238 | 21.71 | 510% / 551% | 1141 MB / 1217 MB | 5.74x |

> 解析+转换规则大小：
>
> - WarpParse：521B
> - Vector-VRL：519B
> - Vector-Fixed：500B
> - Logstash：712B
>
> 在同一日志类型 + 同一拓扑下，以 Vector-VRL 的 EPS 作为统一基准（1.0x），对所有引擎进行归一化对比。

#### 3.2.2 AWS ELB Log（411B）

表 3.2.2-1：AWS ELB Log（Parse + Transform；File -> BlackHole / TCP -> BlackHole / TCP -> File）

| 引擎          | 拓扑              | EPS         | MPS    | CPU (Avg/Peak) | MEM (Avg/Peak)  | 性能倍数 |
| :------------ | :---------------- | :---------- | :----- | :------------- | :-------------- | :------- |
| **WarpParse** | File -> BlackHole | **275,900** | 108.14 | 649% / 719%    | 236 MB / 327 MB | **2.22x** |
| Vector-VRL    | File -> BlackHole | 124,333     | 48.73  | 523% / 560%    | 190 MB / 199 MB | 1.0x     |
| Vector-Fixed  | File -> BlackHole | 141,818     | 55.59  | 514% / 529%    | 179 MB / 191 MB | 1.14x    |
| Logstash | File -> BlackHole | 54,054 | 21.19 | 582% / 653% | 1155 MB / 1217 MB | 0.43x |
| **WarpParse** | TCP -> BlackHole  | **259,900** | 101.87 | 682% / 697%    | 139 MB / 275 MB | **1.99x** |
| Vector-VRL    | TCP -> BlackHole  | 130,600     | 51.19  | 446% / 500%    | 191 MB / 195 MB | 1.0x     |
| Vector-Fixed  | TCP -> BlackHole  | 146,000     | 57.23  | 413% / 441%    | 181 MB / 184 MB | 1.12x    |
| Logstash | TCP -> BlackHole | 78,125 | 30.62 | 624% / 696% | 1212 MB / 1272 MB | 0.60x |
| **WarpParse** | TCP -> File       | **139,800** | 54.80  | 717% / 738%    | 139 MB / 296 MB | **7.99x** |
| Vector-VRL    | TCP -> File       | 17,500      | 6.86   | 177% / 194%    | 181 MB / 187 MB | 1.0x     |
| Vector-Fixed  | TCP -> File       | 17,600      | 6.90   | 164% / 182%    | 173 MB / 180 MB | 1.01x    |
| Logstash | TCP -> File | 69,444 | 27.22 | 636% / 690% | 1192 MB / 1232 MB | 3.97x |

> 解析+转换规则大小：
>
> - WarpParse：1694B
> - Vector-VRL：1259B
> - Vector-Fixed：570B
> - Logstash：2019B
>
> 在同一日志类型 + 同一拓扑下，以 Vector-VRL 的 EPS 作为统一基准（1.0x），对所有引擎进行归一化对比。

#### 3.2.3 Firewall Log (1K)

表 3.2.3-1：Firewall Log（Parse Only；File -> BlackHole / TCP -> BlackHole / TCP -> File）

| 引擎          | 拓扑              | EPS         | MPS    | CPU (Avg/Peak) | MEM (Avg/Peak)  | 性能倍数 |
| :------------ | :---------------- | :---------- | :----- | :------------- | :-------------- | :------- |
| **WarpParse** | File -> BlackHole | **132,500** | 141.78 | 693% / 786% | 348 MB / 430 MB | **2.49x** |
| Vector  | File -> BlackHole | 53,258 | 56.99 | 482% / 692% | 198 MB / 225 MB | 1.00x |
| Logstash | File -> BlackHole | 15,873 | 16.98 | 579% / 680% | 1111 MB / 1127 MB | 0.30x |
| **WarpParse** | TCP -> BlackHole  | **125,500** | 134.29 | 614% / 747% | 130 MB / 304 MB | **2.22x** |
| Vector  | TCP -> BlackHole  | 56,600 | 60.56 | 630% / 702% | 257 MB / 272 MB | 1.00x |
| Logstash | TCP -> BlackHole | 16,528 | 17.69 | 664% / 720% | 1228 MB / 1262 MB | 0.29x |
| **WarpParse** | TCP -> File       | **69,800** | 74.69 | 620% / 760% | 129 MB / 175 MB | **3.31x** |
| Vector  | TCP -> File       | 21,100 | 22.58 | 315% / 332% | 275 MB / 287 MB | 1.00x |
| Logstash | TCP -> File | 16,393 | 17.54 | 660% / 716% | 1210 MB / 1236 MB | 0.78x |

> 解析+转换规则大小：
>
> - WarpParse：2249B
> - Vector：2344B
> - Logstash：3453B
> 
>在同一日志类型 + 同一拓扑下，以 Vector-VRL 的 EPS 作为统一基准（1.0x），对所有引擎进行归一化对比。

#### 3.2.4 APT Threat Log (3K)

表 3.2.4-1：APT Threat Log（Parse + Transform；File -> BlackHole / TCP -> BlackHole / TCP -> File）

| 引擎          | 拓扑              | EPS         | MPS    | CPU (Avg/Peak) | MEM (Avg/Peak)  | 性能倍数 |
| :------------ | :---------------- | :---------- | :----- | :------------- | :-------------- | :------- |
| **WarpParse** | File -> BlackHole | **123,100** | 416.38 | 599% / 607%    | 199 MB / 265 MB | **7.65x** |
| Vector    | File -> BlackHole | 16,093      | 54.43  | 674% / 742%    | 188 MB / 199 MB | 1.0x     |
| Logstash | File -> BlackHole | 7,633 | 25.82 | 657% / 732% | 1174 MB / 1197 MB | 0.47x |
| **WarpParse** | TCP -> BlackHole  | **114,200** | 386.28 | 508% / 532%    | 228 MB / 248 MB | **6.14x** |
| Vector    | TCP -> BlackHole  | 18,600      | 62.91  | 769% / 790%    | 243 MB / 252 MB | 1.0x     |
| Logstash | TCP -> BlackHole | 9,852 | 33.33 | 704% / 748% | 1283 MB / 1304 MB | 0.53x |
| **WarpParse** | TCP -> File       | **54,800**  | 185.36 | 441% / 447%    | 196 MB / 215 MB | **5.89x** |
| Vector-VRL    | TCP -> File       | 9,300       | 31.46  | 345% / 479%    | 217 MB / 227 MB | 1.0x     |
| Logstash | TCP -> File | 8,620 | 29.16 | 671% / 729% | 1229 MB / 1251 MB | 0.93x |

> 解析+转换规则大小：
>
> - WarpParse：1638B
> - Vector：1382B
> - Logstash：2041B
> 
>在同一日志类型 + 同一拓扑下，以 Vector-VRL 的 EPS 作为统一基准（1.0x），对所有引擎进行归一化对比。

#### 3.2.5 Mixed Log (平均日志大小：886B)

表 3.2.5-1：Mixed Log（Parse + Transform；File -> BlackHole / TCP -> BlackHole / TCP -> File）

| 引擎          | 拓扑              | EPS         | MPS    | CPU (Avg/Peak) | MEM (Avg/Peak)  | 性能倍数 |
| :------------ | :---------------- | :---------- | :----- | :------------- | :-------------- | :------- |
| **WarpParse** | File -> BlackHole | **204,400** | 172.71 | 566% / 663% | 196 MB / 265 MB | **4.45x** |
| Vector-VRL    | File -> BlackHole | 45,909 | 38.79 | 469% / 683% | 204 MB / 225 MB | 1.00x     |
| Vector-Fixed  | File -> BlackHole | 48,484      | 40.97 | 541% / 714%    | 178 MB / 209 MB   | 1.06x |
| Logstash | File -> BlackHole | 32,967 | 27.86 | 573% / 685% | 1150 MB / 1172 MB | 0.72x |
| **WarpParse** | TCP -> BlackHole  | **190,300** | 160.80 | 603% / 623% | 119 MB / 190 MB | **2.40x** |
| Vector-VRL    | TCP -> BlackHole  | 79,400 | 67.09 | 776% / 782% | 204 MB / 211 MB | 1.00x     |
| Vector-Fixed  | TCP -> BlackHole  | 76,500 | 64.64 | 776% / 781% | 190 MB / 203 MB | 0.96x |
| Logstash | TCP -> BlackHole | 30,303 | 25.60 | 656% / 719% | 1258 MB / 1287MB | 0.38x |
| **WarpParse** | TCP -> File       | **120,100** | 101.48 | 648% / 727% | 121 MB / 183 MB | **6.19x** |
| Vector-VRL    | TCP -> File       | 19,400 | 16.39 | 268% / 300% | 201 MB / 216 MB | 1.00x     |
| Vector-Fixed  | TCP -> File       | 20,000 | 16.90 | 273% / 303% | 195 MB / 207 MB | 1.03x |
| Logstash | TCP -> File | 26,666 | 22.53 | 612% / 689% | 1218 MB / 1253 MB | 1.37x |

> 解析+转换规则大小：
>
> - WarpParse：3864B
> - Vector-VRL：4723B
> - Vector-Fixed：1733B
> - Logstash：3984B
>
> 在同一日志类型 + 同一拓扑下，以 Vector-VRL 的 EPS 作为统一基准（1.0x），对所有引擎进行归一化对比。
>
> 规则大小可能受格式/换行/注释/路径等影响，体积差异不影响性能口径；规则逻辑保持一致。
>
> 混合日志规则：
>
> - 4类日志按照3:2:1:1混合

## 4 固定速率资源占用测试

#### 4.1 Mixed Log (平均日志大小：867B)

表 4.1.1-1：Mixed Log（Parse Only； TCP -> BlackHole ）

| 引擎          | 拓扑             | CPU (Avg/Peak) | MEM (Avg/Peak)    |
| :------------ | :--------------- | :------------- | :---------------- |
| **WarpParse** | TCP -> BlackHole | 54% / 56%      | 60 MB / 66 MB     |
| Vector-VRL    | TCP -> BlackHole | 173% / 180%    | 162 MB / 166 MB   |
| Vector-Fixed  | TCP -> BlackHole | 171% / 177%    | 128 MB / 134 MB   |
| Logstash      | TCP -> BlackHole | 276% / 396%    | 1190 MB / 1223 MB |

> - **20000EPS**下的资源消耗情况
> - logstash在warmup后采集


## 5. 结果解读

### 5.1 吞吐与资源表现

**结果摘要**:

1.  在 Linux 平台测试中，WarpParse 相对 Vector-VRL 的 EPS 倍数范围为：解析 **1.56x - 20.30x**，解析+转换 **1.34x - 17.90x**；TCP -> File 拓扑下的倍数区间更高。
2.  CPU 使用率在 WarpParse 场景中整体高于 Vector/Logstash（见各表）；吞吐提升与 CPU 占用同时出现。
3.  APT (3K) 场景下，WarpParse 的 MPS 保持较高水平；Vector 在同场景的 EPS/MPS 相对更低（见 3.1.4/3.2.4）。

* ### 5.2 规则与表达能力要点

    - 规则体积不仅反映配置分发与维护成本，
      也可作为衡量引擎在表达同等日志语义时所需复杂度的参考指标。
      在相同解析与转换语义下，规则体积越小，通常意味着引擎具备更高层级的内置能力或更强的表达抽象。

    - 各日志类型与拓扑下的规则体积差异见对应表格“规则大小”备注，
      用于辅助评估不同引擎在表达能力、规则可读性与维护复杂度方面的差异。

    - Vector 测试同时包含 VRL 与 Fixed 两种策略：
      - VRL 更偏向通用表达能力，对复杂语义具备更强灵活性；
      - Fixed 优先使用内置解析能力，在规则体积与维护复杂度上更具优势。
        两者在表达能力与性能上的权衡以表格数据为准。

    - 在多数日志类型下，TCP → File 拓扑呈现更高的性能倍数区间（见 3.1 / 3.2 对应表格），
      该结论在不同规则复杂度水平下均保持一致。

### 5.3 稳定性

*   本报告未引入背压/队列深度等专用指标，稳定性判断仅基于运行期间吞吐与资源观测。
*   **注意点**: TCP -> File 大包场景（如 APT）下内存随吞吐上升（约 224-389 MB），需结合容量规划。

## 6. 阶段性总结与建议

以下为基于本报告范围的阶段性观察，不构成生产选型结论；实际落地需结合业务流量、架构约束与运维能力评估。

| 决策维度           | 建议方案 | 结果要点 | 依据                                                                                                                         |
| :----------------- | :------- | :------- | :--------------------------------------------------------------------------------------------------------------------------- |
| **追求吞吐能力**   | **WarpParse** | 关注本报告中的 EPS 倍数区间 | 解析场景 **1.56x-20.30x**，解析+转换 **1.34x-17.90x**；TCP -> File 拓扑区间更高。                                            |
| **资源受限环境**   | **WarpParse** | 关注 CPU/内存的权衡关系 | Vector-VRL 在多数场景下 CPU/MEM 低于 WarpParse；Logstash 内存占用显著更高（见各表）。                                          |
| **边缘/Agent部署** | **WarpParse** | 关注规则体积与单机吞吐 | 规则体积在不同日志类型间存在差异；吞吐指标在本报告中更高，具体差异见各节“规则大小”和表格数据。                                  |
| **通用生态兼容**   | **WarpParse** | 关注生态与可扩展性 | 生态兼容性未在本报告中量化，建议结合现有生态与插件适配成本评估。                                                                |

**阶段性结论**:
基于本报告数据，WarpParse 与 Vector-VRL 的 EPS 倍数区间为：纯解析 **1.56x-20.30x**，解析+转换 **1.34x-17.90x**，端到端（TCP -> File）倍数更高。上述结果可作为同类场景的阶段性基线参考；在大包 TCP -> File 场景下需关注内存随吞吐上升（约 224-389 MB）。

## 7. 已知限制与注意事项

*   本报告为单机测试，未覆盖多节点、HA（High Availability，高可用）、持久化优化或生产负载波动等因素。
*   测试范围限定为五类日志与三种拓扑，未覆盖更复杂的输入/输出链路。
*   结果依赖具体硬件、操作系统与存储配置，跨环境对比需谨慎。
