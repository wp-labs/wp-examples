# WarpParse、Vector、Logstash 性能基准测试报告

## 1. 技术概述与测试背景

### 1.1 测试背景

本报告记录在 Mac 平台完成的单机基准测试结果，覆盖从轻量级 Web 日志到复杂安全威胁日志的典型场景，用于形成阶段性 benchmark 基线，便于后续版本或方案之间的横向与纵向对比。本文仅描述测试方法与结果，不对生产环境性能上限作外推。

### 1.2 被测对象

*   **WarpParse**: 大禹安全公司研发的 ETL 核心引擎，采用 Rust 构建。
*   **Vector**: 开源可观测性数据管道工具，采用 Rust 构建。
    *   Vector-VRL：基于 VRL 的 `parse_regex`(Firewall 使用 KV 解析；APT 仍使用正则解析) 进行正则解析。
    *   Vector-Fixed：优先使用内置解析（如 nginx/aws 内置函数）。 
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
- **平台类型**：Mac mini（Apple M4）
- **操作系统**：macOS 15.5
- **系统架构**：arm64
- **网络环境**：本机回环（127.0.0.1）

#### 计算资源（Compute）
- **CPU**：10-core
- **内存**：16 GiB
- **后台任务/性能模式**：测试期间关闭不必要后台任务；未做额外系统调优

#### 存储配置（Storage）
- **存储介质**：Internal SSD
- **文件系统**：APFS
- **卷大小**：256G

### 2.2 测试范畴 (Scope)

*   **日志类型**:
    *   **Nginx Access Log** (239B): 典型 Web 访问日志，高吞吐场景。
    *   **AWS ELB Log** (411B): 云设施负载均衡日志，中等复杂度。
    *   **Firewall Log** (1K): 终端安全监控日志，JSON 结构，字段较多。
    *   **APT Threat Log** (3K): 模拟的高级持续性威胁日志，大体积、长文本。
    *   **Mixed Log**  (867B): 上述四类日志混合起来形成的日志类型。
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
*   **Rule Size**: 规则配置文件体积，用于衡量在表达同等日志语义时所需的描述复杂度，同时辅助评估配置分发、可读性与长期维护成本。
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

## 3. 详细性能对比分析

### 3.0 测试结果汇总表

下表为结果索引，用于定位不同日志类型与测试能力的明细表格。

| 日志类型 | 解析（Parse Only） | 解析 + 转换（Parse + Transform） |
| :-- | :-- | :-- |
| Nginx Access Log (239B) | 见 3.1.1 | 见 3.2.1 |
| AWS ELB Log (411B) | 见 3.1.2 | 见 3.2.2 |
| Firewall Log (1K) | 见 3.1.3 | 见 3.2.3 |
| APT Threat Log (3K) | 见 3.1.4 | 见 3.2.4 |
| Mixed Log (平均日志大小：886B) | 见 3.1.5 | 见 3.2.5 |

### 3.1 日志解析能力 (Parse Only)
本节给出纯解析场景的测试结果。

#### 3.1.1 Nginx Access Log (239B)

表 3.1.1-1：Nginx Access Log（Parse Only；File -> BlackHole / TCP -> BlackHole / TCP -> File）

| 引擎          | 拓扑              | EPS           | MPS    | CPU (Avg/Peak) | MEM (Avg/Peak)  | 性能倍数 |
| :------------ | :---------------- | :------------ | :----- | :------------- | :-------------- | :------- |
| **WarpParse** | File -> BlackHole | **2,789,800** | 635.86 | 768% / 858%    | 126 MB / 130 MB | **4.88x** |
| Vector-VRL    | File -> BlackHole | 572,076       | 130.39 | 298% / 320%    | 222 MB / 241 MB | 1.0x     |
| Vector-Fixed  | File -> BlackHole | 513,181       | 116.97 | 466% / 538%    | 232 MB / 245 MB | 0.90x    |
| Logstash | File -> BlackHole | 270,270 | 61.60 | 308% / 418% | 1092 MB / 1115 MB | 0.47x |
| **WarpParse** | TCP -> BlackHole  | **1,657,500** | 377.80 | 530% / 580%    | 307 MB / 320 MB | **1.42x** |
| Vector-VRL    | TCP -> BlackHole  | 1,163,700     | 265.24 | 540% / 598%    | 218 MB / 224 MB | 1.0x     |
| Vector-Fixed  | TCP -> BlackHole  | 730,700       | 166.55 | 592% / 658%    | 212 MB / 220 MB | 0.63x    |
| Logstash | TCP -> BlackHole | 541,403 | 123.40 | 465% / 667% | 1161 MB / 1234 MB | 0.47x |
| **WarpParse** | TCP -> File       | **789,000**   | 179.84 | 445% / 470%    | 315 MB / 353 MB | **8.78x** |
| Vector-VRL    | TCP -> File       | 89,900        | 20.49  | 165% / 170%    | 213 MB / 221 MB | 1.0x     |
| Vector-Fixed  | TCP -> File       | 92,300        | 21.04  | 201% / 214%    | 195 MB / 208 MB | 1.03x    |
| Logstash | TCP -> File | 507,975 | 115.78 | 515% / 762% | 1153 MB / 1184 MB | 5.65x |

> 解析规则大小：
>
> - WarpParse：150B
> - Vector-VRL：217B
> - Vector-Fixed：86B
> - Logstash：248B
>
> 在同一日志类型 + 同一拓扑下，以 Vector-VRL 的 EPS 作为统一基准（1.0x），对所有引擎进行归一化对比。

#### 3.1.2 AWS ELB Log (411B)

表 3.1.2-1：AWS ELB Log（Parse Only；File -> BlackHole / TCP -> BlackHole / TCP -> File）

| 引擎          | 拓扑              | EPS           | MPS    | CPU (Avg/Peak) | MEM (Avg/Peak)  | 性能倍数 |
| :------------ | :---------------- | :------------ | :----- | :------------- | :-------------- | :------- |
| **WarpParse** | File -> BlackHole | **1,124,500** | 440.79 | 787% / 824%    | 314 MB / 320 MB | **2.89x** |
| Vector-VRL    | File -> BlackHole | 389,000       | 152.47 | 597% / 658%    | 280 MB / 297 MB | 1.0x     |
| Vector-Fixed  | File -> BlackHole | 491,739       | 192.74 | 514% / 537%    | 259 MB / 284 MB | 1.26x    |
| Logstash | File -> BlackHole | 208,333 | 81.66 | 394% / 506% | 983 MB / 1141 MB | 0.54x |
| **WarpParse** | TCP -> BlackHole  | **947,300**   | 371.33 | 625% / 664%    | 357 MB / 362 MB | **2.40x** |
| Vector-VRL    | TCP -> BlackHole  | 394,600       | 154.67 | 546% / 620%    | 275 MB / 286 MB | 1.0x     |
| Vector-Fixed  | TCP -> BlackHole  | 555,500       | 217.73 | 465% / 523%    | 250 MB / 255 MB | 1.41x    |
| Logstash | TCP -> BlackHole | 425,531 | 166.79 | 817% / 879% | 1257 MB / 1287 MB | 1.08x |
| **WarpParse** | TCP -> File       | **349,700** | 137.07 | 496% / 537% | 333 MB / 432 MB | **4.12x** |
| Vector-VRL    | TCP -> File       | 84,700        | 33.20  | 240% / 256%    | 268 MB / 275 MB | 1.0x     |
| Vector-Fixed  | TCP -> File       | 86,900        | 34.06  | 199% / 208%    | 252 MB / 264 MB | 1.03x    |
| Logstash | TCP -> File | 350,877 | 137.53 | 679% / 891% | 1288 MB / 1327 MB | 4.14x |

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
| **WarpParse** | File -> BlackHole | **459,900** | 492.10 | 887% / 923% | 229 MB / 234 MB | **4.24x** |
| Vector-VRL | File -> BlackHole | 115,322     | 123.40 | 456% / 504% | 254 MB / 275 MB | 1.00x   |
| Logstash | File -> BlackHole | 50,505 | 54.04 | 881% / 929% | 1139 MB / 1192 MB | 0.47x |
| **WarpParse** | TCP -> BlackHole  | **406,400** | 434.86 | 761% / 787% | 424 MB / 484 MB | **2.15x** |
| Vector-VRL | TCP -> BlackHole  | 188,800 | 186.50 | 691% / 790% | 373 MB / 393 MB | 1.00x   |
| Logstash | TCP -> BlackHole | 54,347 | 58.15 | 874% / 934% | 1223 MB / 1260 MB | 0.31x |
| **WarpParse** | TCP -> File | 251,100 | 268.68 | 677% / 712% | 237 MB / 247 MB | **3.45x** |
| Vector-VRL | TCP -> File | 72,700 | 77.79 | 368% / 413% | 403 MB / 407 MB | 1.00x |
| Logstash | TCP -> File | 54,945 | 58.79 | 894% / 950% | 1192 MB / 1223 MB | 0.76x |

> 解析规则大小：
>
> - WarpParse：137B
> - Vector-VRL：317B
> - Logstash：527B
> 
>在同一日志类型 + 同一拓扑下，以 Vector-VRL的 EPS 作为统一基准（1.0x），对所有引擎进行归一化对比。

#### 3.1.4 APT Threat Log (3K)

表 3.1.4-1：APT Threat Log（Parse Only；File -> BlackHole / TCP -> BlackHole / TCP -> File）

| 引擎          | 拓扑              | EPS         | MPS     | CPU (Avg/Peak) | MEM (Avg/Peak)  | 性能倍数 |
| :------------ | :---------------- | :---------- | :------ | :------------- | :-------------- | :------- |
| **WarpParse** | File -> BlackHole | **328,000** | 1109.53 | 743% / 829%    | 183 MB / 184 MB | **8.68x** |
| Vector-VRL | File -> BlackHole | 37,777      | 127.79  | 578% / 657%    | 255 MB / 265 MB | 1.0x     |
| Logstash | File -> BlackHole | 29,940 | 101.28 | 847% / 915% | 944 MB / 1152 MB | 0.79x |
| **WarpParse** | TCP -> BlackHole  | **299,700** | 1013.80 | 718% / 743%    | 335 MB / 351 MB | **5.88x** |
| Vector-VRL | TCP -> BlackHole  | 51,000      | 172.52  | 834% / 887%    | 385 MB / 413 MB | 1.0x     |
| Logstash | TCP -> BlackHole | 31,446 | 106.37 | 843% / 892% | 1218 MB / 1313 MB | 0.62x |
| **WarpParse** | TCP -> File       | **99,900**  | 337.94  | 336% / 352%    | 333 MB / 508 MB | **2.69x** |
| Vector-VRL | TCP -> File       | 37,200      | 125.84  | 652% / 837%    | 411 MB / 424 MB | 1.0x     |
| Logstash | TCP -> File | 30,120 | 101.89 | 840% / 897% | 1060 MB / 1232 MB | 0.81x |

> 解析规则大小：
>
> - WarpParse：985B
> - Vector：873B
> - Logstash：1027B
> 
>在同一日志类型 + 同一拓扑下，以 Vector-VRL的 EPS 作为统一基准（1.0x），对所有引擎进行归一化对比。

#### 3.1.5 Mixed Log (平均日志大小：886B)

表 3.1.5-1：Mixed Log（Parse Only；File -> BlackHole / TCP -> BlackHole / TCP -> File）

| 引擎          | 拓扑              | EPS         | MPS    | CPU (Avg/Peak) | MEM (Avg/Peak)  | 性能倍数 |
| :------------ | :---------------- | :---------- | :----- | :------------- | :-------------- | :------- |
| **WarpParse** | File -> BlackHole | **715,000** | 604.14 | 860% / 868% | 246 MB / 254 MB | **3.76x** |
| Vector-VRL    | File -> BlackHole | 190,000 | 160.54 | 827% / 880% | 281 MB / 329 MB | 1.0x     |
| Vector-Fixed  | File -> BlackHole | 197,073 | 166.52 | 825% / 903% | 237 MB / 250 MB | 1.04x    |
| Logstash | File -> BlackHole | 109,890 | 86.43 | 746% / 955% | 1271 MB / 1292 MB | 0.62x |
| **WarpParse** | TCP -> BlackHole  | **586,900** | 495.90 | 697% / 706% | 299 MB / 322 MB | **2.69x** |
| Vector-VRL    | TCP -> BlackHole  | 218,600 | 184.71 | 891% / 930% | 351 MB / 369 MB | 1.0x     |
| Vector-Fixed  | TCP -> BlackHole  | 220,100 | 185.98 | 894% / 935% | 293 MB / 312 MB | 1.01x |
| Logstash | TCP -> BlackHole | 128,205 | 108.33 | 893% / 957% | 1258 MB / 1289 MB | 0.66x |
| **WarpParse** | TCP -> File       | **308,400** | 260.58 | 537% / 560% | 177 MB / 251 MB | **3.90x** |
| Vector-VRL    | TCP -> File       | 79,000 | 66.75 | 383% / 415% | 393 MB / 396 MB | 1.0x     |
| Vector-Fixed  | TCP -> File       | 79,500 | 67.17 | 384% / 407% | 331 MB / 355 MB | 1.01x |
| Logstash | TCP -> File | 126,582     | 106.96 | 879% / 972% | 1278 MB / 1296 MB | 1.60x |

> 解析规则大小：
>
> - WarpParse：3864B
> - Vector-VRL：4723B
> - Vector-Fixed：1733B
> - Logstash：3984B
>
> 在同一日志类型 + 同一拓扑下，以 Vector-VRL 的 EPS 作为统一基准（1.0x），对所有引擎进行归一化对比。
>
> 混合日志规则：
>
> - 4类日志按照3:2:1:1混合
> 

#### 3.1.6 Mixed Log (平均日志大小：867B)

表 3.1.6-1：Mixed Log（Parse Only； TCP -> BlackHole ）

| 引擎          | 拓扑              | CPU (Avg/Peak) | MEM (Avg/Peak)  |
| :------------ | :---------------- | :------------- | :-------------- |
| **WarpParse** | TCP -> BlackHole  | 44% / 57% | 97 MB / 100 MB |
| Vector-VRL    | TCP -> BlackHole  | 116% / 143% | 191 MB / 194 MB |
| Vector-Fixed  | TCP -> BlackHole  | 125% / 146% | 153 MB / 156 MB |
| Logstash | TCP -> BlackHole | 159% / 192% | 1119 MB / 1191 MB |

> - **20000EPS**下的资源消耗情况
> - logstash在warmup后采集

### 3.2 解析 + 转换能力 (Parse + Transform)

本节给出解析 + 转换场景的测试结果。

#### 3.2.1 Nginx Access Log（239B）

表 3.2.1-1：Nginx Access Log（Parse + Transform；File -> BlackHole / TCP -> BlackHole / TCP -> File）

| 引擎          | 拓扑              | EPS           | MPS    | CPU (Avg/Peak) | MEM (Avg/Peak)  | 性能倍数 |
| :------------ | :---------------- | :------------ | :----- | :------------- | :-------------- | :------- |
| **WarpParse** | File -> BlackHole | **2,162,500** | 492.91 | 821% / 911%    | 209 MB / 222 MB | **3.77x** |
| Vector-VRL    | File -> BlackHole | 572,941       | 130.59 | 344% / 378%    | 274 MB / 286 MB | 1.0x     |
| Vector-Fixed  | File -> BlackHole | 482,000       | 109.86 | 554% / 612%    | 252 MB / 261 MB | 0.84x    |
| Logstash | File -> BlackHole | 227,272 | 51.80 | 359% / 548% | 1109 MB / 1143 MB | 0.40x |
| **WarpParse** | TCP -> BlackHole  | **1,382,800** | 315.19 | 602% / 656%    | 279 MB / 369 MB | **1.35x** |
| Vector-VRL    | TCP -> BlackHole  | 1,024,300     | 233.47 | 534% / 618%    | 232 MB / 235 MB | 1.0x     |
| Vector-Fixed  | TCP -> BlackHole  | 595,800       | 135.80 | 543% / 651%    | 214 MB / 219 MB | 0.58x    |
| Logstash | TCP -> BlackHole | 357,142 | 81.40 | 685% / 861% | 1219 MB / 1258 MB | 0.35x |
| **WarpParse** | TCP -> File       | **788,900**   | 179.82 | 574% / 587%    | 249 MB / 253 MB | **8.44x** |
| Vector-VRL    | TCP -> File       | 93,500        | 21.31  | 171% / 184%    | 203 MB / 211 MB | 1.0x     |
| Vector-Fixed  | TCP -> File       | 87,500        | 19.94  | 208% / 223%    | 197 MB / 212 MB | 0.94x    |
| Logstash | TCP -> File | 344,827 | 78.60 | 661% / 883% | 1202 MB / 1230 MB | 3.69x |

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
| **WarpParse** | File -> BlackHole | **913,300** | 358.00 | 880% / 942%    | 228 MB / 248 MB | **2.64x** |
| Vector-VRL    | File -> BlackHole | 345,500     | 135.42 | 548% / 649%    | 291 MB / 309 MB | 1.0x     |
| Vector-Fixed  | File -> BlackHole | 446,111     | 174.86 | 506% / 597%    | 276 MB / 295 MB | 1.29x    |
| Logstash | File -> BlackHole | 147,058 | 57.64 | 525% / 701% | 1121 MB / 1170 MB | 0.43x |
| **WarpParse** | TCP -> BlackHole  | **757,600** | 296.97 | 714% / 758%    | 270 MB / 360 MB | **2.04x** |
| Vector-VRL    | TCP -> BlackHole  | 370,900     | 145.38 | 561% / 607%    | 284 MB / 293 MB | 1.0x     |
| Vector-Fixed  | TCP -> BlackHole  | 481,700     | 188.81 | 466% / 536%    | 265 MB / 272 MB | 1.30x    |
| Logstash | TCP -> BlackHole | 222,222 | 87.10 | 795% / 889% | 1336 MB / 1377 MB | 0.60x |
| **WarpParse** | TCP -> File       | **319,900** | 125.39 | 540% / 600%    | 321 MB / 432 MB | **3.87x** |
| Vector-VRL    | TCP -> File       | 82,700      | 32.42  | 242% / 257%    | 272 MB / 288 MB | 1.0x     |
| Vector-Fixed  | TCP -> File       | 83,600      | 32.77  | 211% / 220%    | 260 MB / 274 MB | 1.01x    |
| Logstash | TCP -> File | 200,000 | 78.39 | 750% / 881% | 1289 MB / 1325 MB | 2.42x |

> 解析+转换规则大小：
>
> - WarpParse：1694B
> - Vector-VRL：1259B
> - Vector-Fixed：570B
> - Logstash：2019B
>
> 在同一日志类型 + 同一拓扑下，以 Vector-VRL 的 EPS 作为统一基准（1.0x），对所有引擎进行归一化对比。

#### 3.2.3 Firewall Log (1K)

表 3.2.3-1： Firewall Log（Parse Only；File -> BlackHole / TCP -> BlackHole / TCP -> File）

| 引擎          | 拓扑              | EPS         | MPS    | CPU (Avg/Peak) | MEM (Avg/Peak)    | 性能倍数  |
| :------------ | :---------------- | :---------- | :----- | :------------- | :---------------- | :-------- |
| **WarpParse** | File -> BlackHole | **382,500** | 409.28 | 912% / 960%    | 181 MB / 194 MB   | **3.44x** |
| Vector-VRL    | File -> BlackHole | 111,081     | 118.86 | 450% / 530%    | 295 MB / 320 MB   | 1.0x      |
| Logstash      | File -> BlackHole | 49,019      | 52.45  | 894% / 927%    | 1180 MB / 1219 MB | 0.37x     |
| **WarpParse** | TCP -> BlackHole  | **288,300** | 308.49 | 679% / 696%    | 238 MB / 242 MB   | **1.77x** |
| Vector-VRL    | TCP -> BlackHole  | 163,300     | 174.73 | 683% / 757%    | 416 MB / 432 MB   | 1.0x      |
| Logstash      | TCP -> BlackHole  | 51,546      | 55.16  | 879% / 922%    | 1253 MB / 1281 MB | 0.32x     |
| **WarpParse** | TCP -> File       | **224,500** | 240.22 | 798% / 818%    | 481 MB / 488 MB   | **3.04x** |
| Vector-VRL    | TCP -> File       | 73,900      | 79.07  | 378% / 442%    | 412 MB / 426 MB   | 1.00x     |
| Logstash      | TCP -> File       | 50,000      | 53.50  | 884% / 934%    | 1256 MB / 1289 MB | 0.68x     |

解析规则大小：

- WarpParse：2249B
- Vector-VRL：2344B
- Logstash：3453B

在同一日志类型 + 同一拓扑下，以 Vector-VRL的 EPS 作为统一基准（1.0x），对所有引擎进行归一化对比。

#### 3.2.4 APT Threat Log (3K)

表 3.2.4-1：APT Threat Log（Parse + Transform；File -> BlackHole / TCP -> BlackHole / TCP -> File）

| 引擎          | 拓扑              | EPS         | MPS     | CPU (Avg/Peak) | MEM (Avg/Peak)  | 性能倍数 |
| :------------ | :---------------- | :---------- | :------ | :------------- | :-------------- | :------- |
| **WarpParse** | File -> BlackHole | **299,400** | 1012.79 | 763% / 855%    | 155 MB / 162 MB | **8.12x** |
| Vector-VRL | File -> BlackHole | 36,857      | 124.68  | 567% / 654%    | 268 MB / 286 MB | 1.0x     |
| Logstash | File -> BlackHole | 26,315 | 89.02 | 852% / 901% | 1256 MB / 1305 MB | 0.71x |
| **WarpParse** | TCP -> BlackHole  | **279,700** | 946.14  | 762% / 784%    | 335 MB / 345 MB | **5.38x** |
| Vector-VRL | TCP -> BlackHole  | 52,000      | 175.90  | 862% / 907%    | 400 MB / 416 MB | 1.0x     |
| Logstash | TCP -> BlackHole | 27,027 | 91.42 | 846% / 926% | 1379 MB / 1413 MB | 0.52x |
| **WarpParse** | TCP -> File       | **89,900**  | 304.11  | 355% / 377%    | 300 MB / 324 MB | **2.41x** |
| Vector-VRL | TCP -> File       | 37,300      | 126.18  | 664% / 750%    | 392 MB / 411 MB | 1.0x     |
| Logstash | TCP -> File | 25,641 | 86.74 | 819% / 936% | 1300 MB / 1356 MB | 0.69x |

> 解析+转换规则大小：
>
> - WarpParse：1638B
> - Vector-VRL：1382B
> - Logstash：2041B
> 
>在同一日志类型 + 同一拓扑下，以 Vector-VRL的 EPS 作为统一基准（1.0x），对所有引擎进行归一化对比。

#### 3.2.5 Mixed Log (平均日志大小：886B)

表 3.2.5-1：Mixed Log（Parse + Transform；File -> BlackHole / TCP -> BlackHole / TCP -> File）

| 引擎          | 拓扑              | EPS         | MPS    | CPU (Avg/Peak) | MEM (Avg/Peak)  | 性能倍数 |
| :------------ | :---------------- | :---------- | :----- | :------------- | :-------------- | :------- |
| **WarpParse** | File -> BlackHole | **659,700** | 557.42 | 889% / 940%    | 170 MB / 184 MB | **3.80x** |
| Vector-VRL    | File -> BlackHole | 173,750 | 146.81 | 784% / 860% | 278 MB / 299 MB | 1.0x     |
| Vector-Fixed  | File -> BlackHole | 178,261     | 150.62 | 772% / 836%    | 273 MB / 298 MB   | 1.03x |
| Logstash | File -> BlackHole | 50,505 | 42.67 | 911% / 939% | 1249 MB / 1276 MB | 0.29x |
| **WarpParse** | TCP -> BlackHole  | **543,100** | 458.90 | 799% / 824% | 394 MB / 479 MB | **2.61x** |
| Vector-VRL    | TCP -> BlackHole  | 208,200 | 175.92 | 878% / 925% | 319 MB / 334 MB | 1.0x     |
| Vector-Fixed  | TCP -> BlackHole  | 206,600 | 174.57 | 919% / 936% | 296 MB / 321 MB | 0.99x |
| Logstash | TCP -> BlackHole | 94,339 | 79.71 | 878% / 941% | 1285 MB / 1318 MB | 0.45x |
| **WarpParse** | TCP -> File       | **299,900** | 253.40 | 616% / 754%    | 332 MB / 493 MB | **3.86x** |
| Vector-VRL    | TCP -> File       | 77,600 | 65.57  | 397% / 421% | 363 MB / 374 MB | 1.0x     |
| Vector-Fixed  | TCP -> File       | 78,100 | 65.99  | 400% / 421% | 337 MB / 358 MB | 1.01x |
| Logstash | TCP -> File | 93,153 | 78.71 | 859% / 957% | 1274 MB / 1308 MB | 1.20x |

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
> 

#### 3.2.6 Mixed Log (平均日志大小：867B)

表 3.2.6-1：Mixed Log（Parse Only； TCP -> BlackHole ）

| 引擎          | 拓扑             | CPU (Avg/Peak) | MEM (Avg/Peak)    |
| :------------ | :--------------- | :------------- | :---------------- |
| **WarpParse** | TCP -> BlackHole | 61% / 82%      | 101 MB / 106 MB   |
| Vector-VRL    | TCP -> BlackHole | 116% / 143%    | 191 MB / 194 MB   |
| Vector-Fixed  | TCP -> BlackHole | 125% / 146%    | 153 MB / 156 MB   |
| Logstash      | TCP -> BlackHole | 159% / 192%    | 1119 MB / 1191 MB |

> - **20000EPS**下的资源消耗情况
> - logstash在warmup后采集


## 4. 结果解读

### 4.1 吞吐与资源表现

**结果摘要**:

1.  在 Mac 平台测试中，WarpParse 相对 Vector-VRL 的 EPS 倍数范围为：解析 **1.42x - 8.78x**，解析+转换 **1.35x - 8.44x**；峰值出现在 Nginx/Mixed 的 TCP -> File 拓扑。
2.  在**同等事件量**下，WarpParse 场景的 CPU 使用率整体高于 Vector/Logstash（见各表）；吞吐提升与 CPU 占用同时出现。
3.  APT (3K) 场景下，WarpParse 的 MPS 最高为 **1109.53 MiB/s**（File -> BlackHole）；Vector 在同场景的 EPS/MPS 相对更低（见 3.1.4/3.2.4）。

### 4.2 规则与表达能力要点

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

### 4.3 稳定性

*   本报告未引入背压/队列深度等专用指标，稳定性判断仅基于运行期间吞吐与资源观测。
*   **注意点**: TCP -> File 大包场景下内存随吞吐上升（APT 场景峰值约 508 MB；Mixed 约 432 MB），需结合容量规划。

## 5. 阶段性总结与建议

以下为基于本报告范围的阶段性观察，不构成生产选型结论；实际落地需结合业务流量、架构约束与运维能力评估。

| 决策维度           | 建议方案 | 结果要点 | 依据                                                                                                                         |
| :----------------- | :------- | :------- | :--------------------------------------------------------------------------------------------------------------------------- |
| **追求吞吐能力**   | **WarpParse** | 关注本报告中的 EPS 倍数区间 | 解析场景 **1.42x-8.78x**，解析+转换 **1.35x-8.44x**；TCP -> File 拓扑区间更高。                                              |
| **资源受限环境**   | **WarpParse** | 关注 CPU/内存的权衡关系 | 虽然峰值 CPU 较高，但完成同等数据量所需的总 CPU 时间更少；小包场景内存控制优异。 |
| **边缘/Agent部署** | **WarpParse** | 关注规则体积与单机吞吐 | 规则体积在不同日志类型间存在差异；吞吐指标在本报告中更高，具体差异见各节“规则大小”和表格数据。                                  |
| **通用生态兼容**   | **WarpParse** | 关注生态与可扩展性 | 提供面向开发者的 API 与插件扩展机制，支持用户快速开发自定义输入 / 输出模块；在满足性能要求的同时，也具备良好的生态扩展能力。 |

**阶段性结论**:
基于本报告数据，WarpParse 与 Vector-VRL 的 EPS 倍数区间为：纯解析 **1.42x-8.78x**，解析+转换 **1.35x-8.44x**，端到端（TCP -> File）倍数更高。上述结果可作为同类场景的阶段性基线参考；在大包 TCP -> File 场景需关注内存随吞吐上升（约 400-500MB）。

## 6. 已知限制与注意事项

*   本报告为单机测试，未覆盖多节点、HA（High Availability，高可用）、持久化优化或生产负载波动等因素。
*   测试范围限定为五类日志与三种拓扑，未覆盖更复杂的输入/输出链路。
*   结果依赖具体硬件、操作系统与存储配置，跨环境对比需谨慎。
