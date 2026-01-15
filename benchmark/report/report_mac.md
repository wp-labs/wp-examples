# WarpParse、Vector、Logstash 性能基准测试报告

## 1. 技术概述与测试背景

### 1.1 测试背景

本报告记录在 Mac 平台完成的单机基准测试结果，覆盖从轻量级 Web 日志到复杂安全威胁日志的典型场景，用于形成阶段性 benchmark 基线，便于后续版本或方案之间的横向与纵向对比。本文仅描述测试方法与结果，不对生产环境性能上限作外推。

### 1.2 被测对象

*   **WarpParse**: 大禹安全公司研发的 ETL 核心引擎，采用 Rust 构建。
*   **Vector**: 开源可观测性数据管道工具，采用 Rust 构建。
    *   Vector-VRL：基于 VRL 的 `parse_regex` 进行正则解析。
    *   Vector-Fixed：优先使用内置解析（如 nginx/aws 内置函数；sysmon 直接 JSON 解析；APT 仍使用正则解析）。 
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

### 1.4 报告定位

本文档定位为阶段性 benchmark 报告，侧重方法与数据的可复现性与长期可比性，不作为最终性能结论或生产容量承诺。

## 2. 测试环境与方法

### 2.1 测试环境

*   **平台**: Mac M4 Mini
*   **操作系统**: MacOS
*   **硬件规格**: 10C16G

### 2.2 测试范畴 (Scope)

*   **日志类型**:
    *   **Nginx Access Log** (239B): 典型 Web 访问日志，高吞吐场景。
    *   **AWS ELB Log** (411B): 云设施负载均衡日志，中等复杂度。
    *   **Sysmon JSON** (1K): 终端安全监控日志，JSON 结构，字段较多。
    *   **APT Threat Log** (3K): 模拟的高级持续性威胁日志，大体积、长文本。
    *   **Mixed Log**  (867B): 上述四类日志混合起来形成的日志类型。
*   **数据拓扑**:
    *   **File -> BlackHole**: 测算引擎极限 I/O 读取与处理能力 (基准)。
    *   **TCP -> BlackHole**: 测算网络接收与处理能力。
    *   **TCP -> File**: 测算端到端完整落地能力。
*   **测试能力**:
    *   **解析 (Parse)**: 仅进行正则提取/JSON解析与字段标准化。
    *   **解析+转换 (Parse+Transform)**: 在解析基础上增加字段映射、富化、类型转换等逻辑。

### 2.3 评估指标

*   **EPS (Events Per Second)**: 每秒处理事件数（核心吞吐指标）。
*   **MPS (MiB/s)**: 每秒处理数据量。
*   **CPU (Avg/Peak)**: 测试进程 CPU 使用率的平均值与峰值。
*   **MEM (Avg/Peak)**: 测试进程内存占用的平均值与峰值。
*   **Rule Size**: 规则配置文件体积，评估分发与维护成本。
*   **性能倍数**: 在同一日志类型 + 同一拓扑下，以 Vector-VRL 的 EPS 为 1.0x 进行归一化。

### 2.4 测试方法与执行方式

测试在单机环境中按日志类型与拓扑逐项执行。输入数据由本仓库提供的 benchmark 脚本生成或回放，
测试过程中各引擎独立运行，避免相互干扰。
输出目标根据测试拓扑配置为 BlackHole 或 File，以分别评估纯处理能力与包含 I/O 的端到端性能。

测试执行流程、脚本入口及通用参数说明见 benchmark/README.md。

### 2.5 默认配置与调优说明

除非表格或备注中明确说明，本报告结果基于各引擎默认配置，未开启专项性能调优或非默认参数。

## 3. 详细性能对比分析

### 3.0 测试结果汇总表

下表为结果索引，用于定位不同日志类型与测试能力的明细表格。

| 日志类型 | 解析（Parse Only） | 解析 + 转换（Parse + Transform） |
| :-- | :-- | :-- |
| Nginx Access Log (239B) | 见 3.1.1 | 见 3.2.1 |
| AWS ELB Log (411B) | 见 3.1.2 | 见 3.2.2 |
| Sysmon JSON Log (1K) | 见 3.1.3 | 见 3.2.3 |
| APT Threat Log (3K) | 见 3.1.4 | 见 3.2.4 |
| Mixed Log (平均日志大小：867B) | 见 3.1.5 | 见 3.2.5 |

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
> - WarpParse：174B
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
| **WarpParse** | TCP -> File       | **349,700** | 137.07 | 496% / 537% | 333 MB / 432 MB | 4.12x |
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

#### 3.1.3 Sysmon JSON Log (1K)

表 3.1.3-1：Sysmon JSON Log（Parse Only；File -> BlackHole / TCP -> BlackHole / TCP -> File）

| 引擎          | 拓扑              | EPS         | MPS    | CPU (Avg/Peak) | MEM (Avg/Peak)  | 性能倍数 |
| :------------ | :---------------- | :---------- | :----- | :------------- | :-------------- | :------- |
| **WarpParse** | File -> BlackHole | **542,200** | 509.86 | 899% / 944%    | 257 MB / 263 MB | **3.38x** |
| Vector-VRL    | File -> BlackHole | 160,400     | 150.83 | 474% / 524%    | 270 MB / 277 MB | 1.0x     |
| Vector-Fixed  | File -> BlackHole | 94,285      | 88.66  | 474% / 563%    | 202 MB / 209 MB | 0.59x    |
| Logstash | File -> BlackHole | 119,047 | 111.94 | 510% / 680% | 1026 MB / 1158 MB | 0.74x |
| **WarpParse** | TCP -> BlackHole  | **448,900** | 422.12 | 721% / 764%    | 352 MB / 362 MB | **1.93x** |
| Vector-VRL    | TCP -> BlackHole  | 232,900     | 219.00 | 645% / 733%    | 381 MB / 393 MB | 1.0x     |
| Vector-Fixed  | TCP -> BlackHole  | 134,400     | 126.39 | 689% / 757%    | 328 MB / 346 MB | 0.58x    |
| Logstash | TCP -> BlackHole | 183,486 | 172.54 | 876% / 937% | 1317 MB / 1356 MB | 0.79x |
| **WarpParse** | TCP -> File       | **279,800** | 263.11 | 664% / 688%    | 272 MB / 278 MB | **3.69x** |
| Vector-VRL    | TCP -> File       | 75,800      | 71.28  | 325% / 358%    | 350 MB / 365 MB | 1.0x     |
| Vector-Fixed  | TCP -> File       | 67,300      | 63.29  | 435% / 473%    | 312 MB / 323 MB | 0.89x    |
| Logstash | TCP -> File | 152,671 | 143.56 | 803% / 935% | 994 MB / 1280 MB | 2.01x |

> 解析规则大小：
>
> - WarpParse：1552B
> - Vector-VRL：1949B
> - Vector-Fixed：1852B
> - Logstash：2406B
>
> 在同一日志类型 + 同一拓扑下，以 Vector-VRL 的 EPS 作为统一基准（1.0x），对所有引擎进行归一化对比。

#### 3.1.4 APT Threat Log (3K)

表 3.1.4-1：APT Threat Log（Parse Only；File -> BlackHole / TCP -> BlackHole / TCP -> File）

| 引擎          | 拓扑              | EPS         | MPS     | CPU (Avg/Peak) | MEM (Avg/Peak)  | 性能倍数 |
| :------------ | :---------------- | :---------- | :------ | :------------- | :-------------- | :------- |
| **WarpParse** | File -> BlackHole | **328,000** | 1109.53 | 743% / 829%    | 183 MB / 184 MB | **8.68x** |
| Vector-VRL    | File -> BlackHole | 37,777      | 127.79  | 578% / 657%    | 255 MB / 265 MB | 1.0x     |
| Vector-Fixed  | File -> BlackHole | 37,857      | 128.06  | 570% / 670%    | 262 MB / 277 MB | 1.00x    |
| Logstash | File -> BlackHole | 29,940 | 101.28 | 847% / 915% | 944 MB / 1152 MB | 0.79x |
| **WarpParse** | TCP -> BlackHole  | **299,700** | 1013.80 | 718% / 743%    | 335 MB / 351 MB | **5.88x** |
| Vector-VRL    | TCP -> BlackHole  | 51,000      | 172.52  | 834% / 887%    | 385 MB / 413 MB | 1.0x     |
| Vector-Fixed  | TCP -> BlackHole  | 51,500      | 174.21  | 838% / 897%    | 409 MB / 427 MB | 1.01x    |
| Logstash | TCP -> BlackHole | 31,446 | 106.37 | 843% / 892% | 1218 MB / 1313 MB | 0.62x |
| **WarpParse** | TCP -> File       | **99,900**  | 337.94  | 336% / 352%    | 333 MB / 508 MB | **2.69x** |
| Vector-VRL    | TCP -> File       | 37,200      | 125.84  | 652% / 837%    | 411 MB / 424 MB | 1.0x     |
| Vector-Fixed  | TCP -> File       | 38,200      | 129.21  | 668% / 746%    | 351 MB / 368 MB | 1.03x    |
| Logstash | TCP -> File | 30,120 | 101.89 | 840% / 897% | 1060 MB / 1232 MB | 0.81x |

> 解析规则大小：
>
> - WarpParse：985B
> - Vector-VRL：873B
> - Vector-Fixed：872B
> - Logstash：1027B
>
> 在同一日志类型 + 同一拓扑下，以 Vector-VRL 的 EPS 作为统一基准（1.0x），对所有引擎进行归一化对比。

#### 3.1.5 Mixed Log (平均日志大小：867B)

表 3.1.5-1：Mixed Log（Parse Only；File -> BlackHole / TCP -> BlackHole / TCP -> File）

| 引擎          | 拓扑              | EPS         | MPS    | CPU (Avg/Peak) | MEM (Avg/Peak)  | 性能倍数 |
| :------------ | :---------------- | :---------- | :----- | :------------- | :-------------- | :------- |
| **WarpParse** | File -> BlackHole | **768,800** | 635.69 | 891% / 936%    | 166 MB / 180 MB | **4.01x** |
| Vector-VRL    | File -> BlackHole | 191,707     | 158.51 | 786% / 932%    | 263 MB / 286 MB | 1.0x     |
| Vector-Fixed  | File -> BlackHole | 200,000     | 165.37 | 820% / 904%    | 246 MB / 275 MB | 1.04x    |
| Logstash | File -> BlackHole | 119,047 | 98.43  | 636% / 892% | 1141 MB / 1207 MB | 0.62x |
| **WarpParse** | TCP -> BlackHole  | **623,200** | 515.30 | 672% / 701%    | 226 MB / 253 MB | **2.82x** |
| Vector-VRL    | TCP -> BlackHole  | 221,200     | 182.90 | 882% / 912%    | 332 MB / 345 MB | 1.0x     |
| Vector-Fixed  | TCP -> BlackHole  | 204,300     | 168.92 | 892% / 926%    | 291 MB / 307 MB | 0.92x    |
| Logstash | TCP -> BlackHole | 144,927 | 119.83 | 868% / 921% | 1401 MB / 1435 MB | 0.66x |
| **WarpParse** | TCP -> File       | **318,100** | 263.03 | 544% / 711%    | 315 MB / 432 MB | **4.21x** |
| Vector-VRL    | TCP -> File       | 75,600      | 62.51  | 372% / 408%    | 361 MB / 380 MB | 1.0x     |
| Vector-Fixed  | TCP -> File       | 75,000      | 62.01  | 389% / 414%    | 331 MB / 355 MB | 0.99x    |
| Logstash | TCP -> File | 136,986 | 113.27 | 839% / 913% | 1356 MB / 1394 MB | 1.81x |

> 解析规则大小：
>
> - WarpParse：3864B
> - Vector-VRL：4240B
> - Vector-Fixed：3154B
> - Logstash：5396B
>
> 在同一日志类型 + 同一拓扑下，以 Vector-VRL 的 EPS 作为统一基准（1.0x），对所有引擎进行归一化对比。
>
> 混合日志规则：
>
> - 4类日志按照3:2:1:1混合

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

#### 3.2.3 Sysmon JSON Log (1K)

表 3.2.3-1：Sysmon JSON Log（Parse + Transform；File -> BlackHole / TCP -> BlackHole / TCP -> File）

| 引擎          | 拓扑              | EPS         | MPS    | CPU (Avg/Peak) | MEM (Avg/Peak)  | 性能倍数 |
| :------------ | :---------------- | :---------- | :----- | :------------- | :-------------- | :------- |
| **WarpParse** | File -> BlackHole | **432,200** | 406.42 | 907% / 964%    | 167 MB / 185 MB | **3.03x** |
| Vector-VRL    | File -> BlackHole | 142,857     | 134.33 | 445% / 531%    | 312 MB / 320 MB | 1.0x     |
| Vector-Fixed  | File -> BlackHole | 86,600      | 81.43  | 428% / 507% | 224 MB / 240 MB | 0.61x    |
| Logstash | File -> BlackHole | 97,087 | 91.29 | 695% / 943% | 1198 MB / 1214 MB | 0.68x |
| **WarpParse** | TCP -> BlackHole  | **386,800** | 363.72 | 795% / 813%    | 396 MB / 419 MB | **1.79x** |
| Vector-VRL    | TCP -> BlackHole  | 216,100     | 203.20 | 560% / 672%    | 368 MB / 375 MB | 1.0x     |
| Vector-Fixed  | TCP -> BlackHole  | 130,800     | 123.00 | 707% / 806%    | 347 MB / 366 MB | 0.61x    |
| Logstash | TCP -> BlackHole | 113,636 | 106.85 | 883% / 943% | 1312 MB / 1350 MB | 0.53x |
| **WarpParse** | TCP -> File       | **239,000** | 224.74 | 716% / 792%    | 346 MB / 399 MB | **3.12x** |
| Vector-VRL    | TCP -> File       | 76,600      | 72.03  | 320% / 380%    | 364 MB / 380 MB | 1.0x     |
| Vector-Fixed  | TCP -> File       | 68,100      | 64.04  | 439% / 475%    | 345 MB / 362 MB | 0.89x    |
| Logstash | TCP -> File | 109,890 | 103.33 | 820% / 889% | 1311 MB / 1347 MB | 1.43x |

> 解析+转换规则大小：
>
> - WarpParse：2249B
> - Vector-VRL：2536B
> - Vector-Fixed：2344B
> - Logstash：3453B
>
> 在同一日志类型 + 同一拓扑下，以 Vector-VRL 的 EPS 作为统一基准（1.0x），对所有引擎进行归一化对比。

#### 3.2.4 APT Threat Log (3K)

表 3.2.4-1：APT Threat Log（Parse + Transform；File -> BlackHole / TCP -> BlackHole / TCP -> File）

| 引擎          | 拓扑              | EPS         | MPS     | CPU (Avg/Peak) | MEM (Avg/Peak)  | 性能倍数 |
| :------------ | :---------------- | :---------- | :------ | :------------- | :-------------- | :------- |
| **WarpParse** | File -> BlackHole | **299,400** | 1012.79 | 763% / 855%    | 155 MB / 162 MB | **8.12x** |
| Vector-VRL    | File -> BlackHole | 36,857      | 124.68  | 567% / 654%    | 268 MB / 286 MB | 1.0x     |
| Vector-Fixed  | File -> BlackHole | 37,222      | 125.91  | 574% / 660%    | 255 MB / 270 MB | 1.01x    |
| Logstash | File -> BlackHole | 26,315 | 89.02 | 852% / 901% | 1256 MB / 1305 MB | 0.71x |
| **WarpParse** | TCP -> BlackHole  | **279,700** | 946.14  | 762% / 784%    | 335 MB / 345 MB | **5.38x** |
| Vector-VRL    | TCP -> BlackHole  | 52,000      | 175.90  | 862% / 907%    | 400 MB / 416 MB | 1.0x     |
| Vector-Fixed  | TCP -> BlackHole  | 51,000      | 172.52  | 848% / 911%    | 394 MB / 419 MB | 0.98x    |
| Logstash | TCP -> BlackHole | 27,027 | 91.42 | 846% / 926% | 1379 MB / 1413 MB | 0.52x |
| **WarpParse** | TCP -> File       | **89,900**  | 304.11  | 355% / 377%    | 300 MB / 324 MB | **2.41x** |
| Vector-VRL    | TCP -> File       | 37,300      | 126.18  | 664% / 750%    | 392 MB / 411 MB | 1.0x     |
| Vector-Fixed  | TCP -> File       | 37,000      | 125.16  | 659% / 721%    | 385 MB / 409 MB | 0.99x    |
| Logstash | TCP -> File | 25,641 | 86.74 | 819% / 936% | 1300 MB / 1356 MB | 0.69x |

> 解析+转换规则大小：
>
> - WarpParse：1638B
> - Vector-VRL：2259B
> - Vector-Fixed：1382B
> - Logstash：2041B
>
> 在同一日志类型 + 同一拓扑下，以 Vector-VRL 的 EPS 作为统一基准（1.0x），对所有引擎进行归一化对比。

#### 3.2.5 Mixed Log (平均日志大小：867B)

表 3.2.5-1：Mixed Log（Parse + Transform；File -> BlackHole / TCP -> BlackHole / TCP -> File）

| 引擎          | 拓扑              | EPS         | MPS    | CPU (Avg/Peak) | MEM (Avg/Peak)  | 性能倍数 |
| :------------ | :---------------- | :---------- | :----- | :------------- | :-------------- | :------- |
| **WarpParse** | File -> BlackHole | **659,700** | 545.48 | 889% / 940%    | 170 MB / 184 MB | **3.53x** |
| Vector-VRL    | File -> BlackHole | 186,857     | 154.50 | 780% / 863%    | 266 MB / 296 MB | 1.0x     |
| Vector-Fixed  | File -> BlackHole | 175,769     | 145.33 | 811% / 906%    | 226 MB / 245 MB | 0.94x    |
| Logstash | File -> BlackHole | 103,092 | 85.24 | 840% / 941% | 1253 MB / 1345 MB | 0.55x |
| **WarpParse** | TCP -> BlackHole  | **574,500** | 475.03 | 777% / 813%    | 303 MB / 312 MB | **2.67x** |
| Vector-VRL    | TCP -> BlackHole  | 215,000     | 177.77 | 892% / 922%    | 329 MB / 346 MB | 1.0x     |
| Vector-Fixed  | TCP -> BlackHole  | 199,300     | 164.79 | 893% / 936%    | 301 MB / 312 MB | 0.93x    |
| Logstash | TCP -> BlackHole | 114,942 | 95.04 | 877% / 939% | 1316 MB / 1350 MB | 0.53x |
| **WarpParse** | TCP -> File       | **299,900** | 247.98 | 616% / 754%    | 332 MB / 493 MB | **4.01x** |
| Vector-VRL    | TCP -> File       | 74,800      | 61.85  | 378% / 404%    | 362 MB / 384 MB | 1.0x     |
| Vector-Fixed  | TCP -> File       | 70,900      | 58.62  | 382% / 433%    | 304 MB / 323 MB | 0.95x    |
| Logstash | TCP -> File | 107,526 | 88.91 | 833% / 934% | 1325 MB / 1355 MB | 1.44x |

> 解析+转换规则大小：
>
> - WarpParse：6102B
> - Vector-VRL：6573B
> - Vector-Fixed：4796B
> - Logstash：8391B
>
> 在同一日志类型 + 同一拓扑下，以 Vector-VRL 的 EPS 作为统一基准（1.0x），对所有引擎进行归一化对比。
>
> 混合日志规则：
>
> - 4类日志按照3:2:1:1混合


## 4. 结果解读

### 4.1 吞吐与资源表现

**结果摘要**:

1.  在 Mac 平台测试中，WarpParse 相对 Vector-VRL 的 EPS 倍数范围为：解析 **1.42x - 8.78x**，解析+转换 **1.35x - 8.44x**；峰值出现在 Nginx/Mixed 的 TCP -> File 拓扑。
2.  CPU 使用率在 WarpParse 场景中整体高于 Vector/Logstash（见各表）；吞吐提升与 CPU 占用同时出现。
3.  APT (3K) 场景下，WarpParse 的 MPS 最高为 **1109.53 MiB/s**（File -> BlackHole）；Vector 在同场景的 EPS/MPS 相对更低（见 3.1.4/3.2.4）。

### 4.2 规则与运维要点

*   规则体积差异见各节“规则大小”备注，便于评估配置分发与维护成本。
*   Vector 测试包含 VRL 与 Fixed 两种策略，性能与规则体积差异以表格数据为准。
*   TCP -> File 拓扑在多数组合下呈现更高的性能倍数范围（见 3.1/3.2 的对应表格）。

### 4.3 稳定性

*   压力测试过程中未观察到明显背压导致的吞吐崩塌。
*   **注意点**: TCP -> File 大包场景下内存随吞吐上升（APT 场景峰值约 508 MB；Mixed 约 432 MB），需结合容量规划。

## 5. 阶段性总结与建议

| 决策维度           | 建议方案 | 结果要点 | 依据                                                                                                                         |
| :----------------- | :------- | :------- | :--------------------------------------------------------------------------------------------------------------------------- |
| **追求吞吐能力**   | **WarpParse** | 关注本报告中的 EPS 倍数区间 | 解析场景 **1.42x-8.78x**，解析+转换 **1.35x-8.44x**；TCP -> File 拓扑区间更高。                                              |
| **资源受限环境**   | **WarpParse** | 关注 CPU/内存的权衡关系 | 虽然峰值 CPU 较高，但完成同等数据量所需的总 CPU 时间更少；小包场景内存控制优异。 |
| **边缘/Agent部署** | **WarpParse** | 关注规则体积与单机吞吐 | 规则体积在不同日志类型间存在差异；吞吐指标在本报告中更高，具体差异见各节“规则大小”和表格数据。                                  |
| **通用生态兼容**   | **WarpParse** | 关注生态与可扩展性 | 提供面向开发者的 API 与插件扩展机制，支持用户快速开发自定义输入 / 输出模块；在满足性能要求的同时，也具备良好的生态扩展能力。 |

**阶段性结论**:
基于本报告数据，WarpParse 与 Vector-VRL 的 EPS 倍数区间为：纯解析 **1.42x-8.78x**，解析+转换 **1.35x-8.44x**，端到端（TCP -> File）倍数更高。上述结果可作为同类场景的阶段性基线参考；在大包 TCP -> File 场景需关注内存随吞吐上升（约 400-500MB）。

## 6. 可复现性说明

最小复现路径基于本仓库 benchmark 脚本，入口与参数说明见 `benchmark/README.md`。示例命令如下：

```bash
cd benchmark

# TCP -> BlackHole（解析）
./case_tcp/parse_to_blackhole/run.sh

# TCP -> File（解析）
./case_tcp/parse_to_file/run.sh

# File -> BlackHole（解析）
./case_file/parse_to_blackhole/run.sh
```

通用参数包括 `-m`（中等规模数据集）、`-c`（指定条数）、`-w`（worker 数）、`wpl_dir`（规则目录）、`speed`（限速）。Vector 与 Logstash 的配置文件与启动方式需与本报告对应的规则与拓扑保持一致。

## 7. 已知限制与注意事项

*   本报告为单机测试，未覆盖多节点、HA、持久化优化或生产负载波动等因素。
*   测试范围限定为五类日志与三种拓扑，未覆盖更复杂的输入/输出链路。
*   结果依赖具体硬件、操作系统与存储配置，跨环境对比需谨慎。
*   本报告未记录版本号与构建参数，复现时建议补充完整版本信息。
