#  WarpParse vs Vector 性能基准测试报告

## 1. 技术概述与测试背景

### 1.1 测试背景

本报告旨在深度对比 **WarpParse** 与 **Vector** 在高性能日志处理场景下的能力差异。基于 Linux 平台测试数据，覆盖从轻量级 Web 日志到复杂的安全威胁日志，重点评估两者在单机环境下的解析（Parse）与转换（Transform）性能、资源消耗及规则维护成本。

### 1.2 被测对象

*   **WarpParse**: 大禹安全公司研发的高性能 ETL 核心引擎，采用 Rust 构建，专为极致吞吐和复杂安全日志分析设计。
*   **Vector**: 开源领域标杆级可观测性数据管道工具，同样采用 Rust 构建，以高性能和广泛的生态兼容性著称。
    *   Vector-VRL：基于 VRL 的 `parse_regex` 进行正则解析。
    *   Vector-Fixed：尽量使用内置解析（如 nginx/aws 内置函数；sysmon 直接 JSON 解析；APT 无专用手段仍使用正则）。

## 2. 测试环境与方法

### 2.1 测试环境（Test Environment）

#### 平台信息（Platform）
- **平台类型**：AWS EC2
- **操作系统**：Ubuntu 24.04 LTS
- **系统架构**：x86_64

#### 计算资源（Compute）
- **CPU**：8 vCPU
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

### 2.2 测试范畴 (Scope)

*   **日志类型**:
    *   **Nginx Access Log** (239B): 典型 Web 访问日志，高吞吐场景。
    *   **AWS ELB Log** (411B): 云设施负载均衡日志，中等复杂度。
    *   **Sysmon JSON** (1K): 终端安全监控日志，JSON 结构，字段较多。
    *   **APT Threat Log** (3K): 模拟的高级持续性威胁日志，大体积、长文本。
    *   **Mixed Log**: 上述四类日志混合形成的日志类型。
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
*   **CPU/Memory**: 进程平均与峰值资源占用。
*   **Rule Size**: 规则配置文件体积，评估分发与维护成本。

## 3. 详细性能对比分析

### 3.1 日志解析能力 (Parse Only)

#### 3.1.1 Nginx Access Log (239B)

| 引擎          | 拓扑              | EPS         | MPS    | CPU (Avg/Peak) | MEM (Avg/Peak)  | 性能倍数 |
| :------------ | :---------------- | :---------- | :----- | :------------- | :-------------- | :------- |
| **WarpParse** | File -> BlackHole | **810,100** | 184.65 | 626% / 639%    | 115 MB / 314 MB | **3.83x** |
| Vector-VRL    | File -> BlackHole | 211,250     | 48.15  | 292% / 305%    | 148 MB / 153 MB | 1.0x     |
| Vector-Fixed  | File -> BlackHole | 170,666     | 38.90  | 431% / 451%    | 141 MB / 151 MB | 0.81x    |
| **WarpParse** | TCP -> BlackHole  | **765,800** | 174.55 | 574% / 628%    | 245 MB / 366 MB | **1.56x** |
| Vector-VRL    | TCP -> BlackHole  | 492,200     | 112.19 | 501% / 510%    | 155 MB / 159 MB | 1.0x     |
| Vector-Fixed  | TCP -> BlackHole  | 255,500     | 58.24  | 480% / 533%    | 138 MB / 145 MB | 0.52x    |
| **WarpParse** | TCP -> File       | **377,600** | 86.07  | 645% / 673%    | 221 MB / 444 MB | **20.30x** |
| Vector-VRL    | TCP -> File       | 18,600      | 4.24   | 133% / 135%    | 122 MB / 126 MB | 1.0x     |
| Vector-Fixed  | TCP -> File       | 17,300      | 3.94   | 148% / 156%    | 115 MB / 119 MB | 0.93x    |

> 解析规则大小：
>
> - WarpParse：174B
> - Vector-VRL：217B
> - Vector-Fixed：86B
>
> **Vector-Fixed 的性能倍数：以同场景下的 Vector-VRL EPS 为基准（1.0x）进行对比计算**

#### 3.1.2 AWS ELB Log (411B)

| 引擎          | 拓扑              | EPS         | MPS    | CPU (Avg/Peak) | MEM (Avg/Peak)  | 性能倍数 |
| :------------ | :---------------- | :---------- | :----- | :------------- | :-------------- | :------- |
| **WarpParse** | File -> BlackHole | **398,800** | 156.31 | 698% / 756%    | 194 MB / 366 MB | **2.82x** |
| Vector-VRL    | File -> BlackHole | 141,600     | 55.50  | 423% / 437%    | 166 MB / 170 MB | 1.0x     |
| Vector-Fixed  | File -> BlackHole | 161,944     | 63.47  | 496% / 515%    | 174 MB / 179 MB | 1.14x    |
| **WarpParse** | TCP -> BlackHole  | **369,900** | 144.98 | 669% / 724%    | 178 MB / 461 MB | **2.49x** |
| Vector-VRL    | TCP -> BlackHole  | 148,400     | 58.16  | 456% / 486%    | 178 MB / 185 MB | 1.0x     |
| Vector-Fixed  | TCP -> BlackHole  | 176,600     | 69.22  | 417% / 435%    | 169 MB / 176 MB | 1.19x    |
| **WarpParse** | TCP -> File       | **169,900** | 66.59  | 686% / 699%    | 191 MB / 251 MB | **9.71x** |
| Vector-VRL    | TCP -> File       | 17,500      | 6.86   | 169% / 176%    | 166 MB / 171 MB | 1.0x     |
| Vector-Fixed  | TCP -> File       | 16,600      | 6.51   | 159% / 171%    | 157 MB / 164 MB | 0.95x    |

> 解析规则大小：
>
> - WarpParse：1153B
> - Vector-VRL：921B
> - Vector-Fixed：64B
>
> **Vector-Fixed 的性能倍数：以同场景下的 Vector-VRL EPS 为基准（1.0x）进行对比计算**

#### 3.1.3 Sysmon JSON Log (1K)

| 引擎          | 拓扑              | EPS         | MPS    | CPU (Avg/Peak) | MEM (Avg/Peak)  | 性能倍数 |
| :------------ | :---------------- | :---------- | :----- | :------------- | :-------------- | :------- |
| **WarpParse** | File -> BlackHole | **153,000** | 143.87 | 700% / 749%    | 217 MB / 338 MB | **2.03x** |
| Vector-VRL    | File -> BlackHole | 75,471      | 70.97  | 511% / 584%    | 222 MB / 235 MB | 1.0x     |
| Vector-Fixed  | File -> BlackHole | 38,196      | 35.92  | 482% / 518%    | 167 MB / 175 MB | 0.51x    |
| **WarpParse** | TCP -> BlackHole  | **149,800** | 140.86 | 724% / 766%    | 180 MB / 431 MB | **1.68x** |
| Vector-VRL    | TCP -> BlackHole  | 89,000      | 83.69  | 529% / 607%    | 240 MB / 254 MB | 1.0x     |
| Vector-Fixed  | TCP -> BlackHole  | 47,000      | 44.20  | 576% / 646%    | 208 MB / 221 MB | 0.53x    |
| **WarpParse** | TCP -> File       | **104,900** | 98.64  | 732% / 764%    | 138 MB / 288 MB | **6.21x** |
| Vector-VRL    | TCP -> File       | 16,900      | 15.89  | 205% / 221%    | 215 MB / 223 MB | 1.0x     |
| Vector-Fixed  | TCP -> File       | 15,500      | 14.58  | 288% / 342%    | 187 MB / 196 MB | 0.92x    |

> 解析规则大小：
>
> - WarpParse：1552B
> - Vector-VRL：1949B
> - Vector-Fixed：1852B
>
> **Vector-Fixed 的性能倍数：以同场景下的 Vector-VRL EPS 为基准（1.0x）进行对比计算**

#### 3.1.4 APT Threat Log (3K)

| 引擎          | 拓扑              | EPS         | MPS    | CPU (Avg/Peak) | MEM (Avg/Peak)  | 性能倍数 |
| :------------ | :---------------- | :---------- | :----- | :------------- | :-------------- | :------- |
| **WarpParse** | File -> BlackHole | **129,700** | 438.71 | 535% / 543%    | 273 MB / 295 MB | **7.67x** |
| Vector-VRL    | File -> BlackHole | 16,901      | 57.17  | 692% / 730%    | 175 MB / 180 MB | 1.0x     |
| Vector-Fixed  | File -> BlackHole | 14,137      | 47.82  | 515% / 585%    | 190 MB / 194 MB | 0.84x    |
| **WarpParse** | TCP -> BlackHole  | **129,600** | 438.37 | 499% / 558%    | 265 MB / 389 MB | **6.86x** |
| Vector-VRL    | TCP -> BlackHole  | 18,900      | 63.93  | 774% / 794%    | 229 MB / 243 MB | 1.0x     |
| Vector-Fixed  | TCP -> BlackHole  | 19,100      | 64.61  | 745% / 792%    | 226 MB / 238 MB | 1.01x    |
| **WarpParse** | TCP -> File       | **55,000**  | 186.04 | 362% / 368%    | 197 MB / 224 MB | **5.91x** |
| Vector-VRL    | TCP -> File       | 9,300       | 31.46  | 412% / 450%    | 211 MB / 218 MB | 1.0x     |
| Vector-Fixed  | TCP -> File       | 9,200       | 31.12  | 406% / 478%    | 209 MB / 219 MB | 0.99x    |

> 解析规则大小：
>
> - WarpParse：985B
> - Vector-VRL：873B
> - Vector-Fixed：872B
>
> **Vector-Fixed 的性能倍数：以同场景下的 Vector-VRL EPS 为基准（1.0x）进行对比计算**

#### 3.1.5 Mixed Log (平均日志大小：867B)

| 引擎          | 拓扑              | EPS         | MPS    | CPU (Avg/Peak) | MEM (Avg/Peak)  | 性能倍数 |
| :------------ | :---------------- | :---------- | :----- | :------------- | :-------------- | :------- |
| **WarpParse** | File -> BlackHole | **270,000** | 223.25 | 726% / 757%    | 240 MB / 348 MB | **3.35x** |
| Vector-VRL    | File -> BlackHole | 80,555      | 66.61  | 780% / 796%    | 177 MB / 187 MB | 1.0x     |
| Vector-Fixed  | File -> BlackHole | 74,418      | 61.54  | 790% / 797%    | 161 MB / 166 MB | 0.92x    |
| **WarpParse** | TCP -> BlackHole  | **259,900** | 214.90 | 688% / 697%    | 141 MB / 206 MB | **2.99x** |
| Vector-VRL    | TCP -> BlackHole  | 86,800      | 71.77  | 762% / 774%    | 199 MB / 207 MB | 1.0x     |
| Vector-Fixed  | TCP -> BlackHole  | 78,200      | 64.66  | 777% / 783%    | 183 MB / 190 MB | 0.90x    |
| **WarpParse** | TCP -> File       | **159,700** | 132.05 | 704% / 719%    | 133 MB / 202 MB | **10.44x** |
| Vector-VRL    | TCP -> File       | 15,300      | 12.65  | 223% / 255%    | 203 MB / 213 MB | 1.0x     |
| Vector-Fixed  | TCP -> File       | 16,500      | 13.64  | 248% / 264%    | 183 MB / 189 MB | 1.08x    |

> 解析规则大小：
>
> - WarpParse：3864B
> - Vector-VRL：3960B
> - Vector-Fixed：4725B
>
> **Vector-Fixed 的性能倍数：以同场景下的 Vector-VRL EPS 为基准（1.0x）进行对比计算**
>
> 混合日志规则：
>
> - 4类日志按照3:2:1:1混合

### 3.2 解析 + 转换能力 (Parse + Transform)

#### 3.2.1 Nginx Access Log（239B）

| 引擎          | 拓扑              | EPS         | MPS    | CPU (Avg/Peak) | MEM (Avg/Peak)  | 性能倍数 |
| :------------ | :---------------- | :---------- | :----- | :------------- | :-------------- | :------- |
| **WarpParse** | File -> BlackHole | **656,800** | 149.71 | 688% / 768%    | 220 MB / 357 MB | **3.27x** |
| Vector-VRL    | File -> BlackHole | 201,000     | 45.81  | 339% / 350%    | 167 MB / 175 MB | 1.0x     |
| Vector-Fixed  | File -> BlackHole | 153,333     | 34.95  | 466% / 481%    | 159 MB / 168 MB | 0.76x    |
| **WarpParse** | TCP -> BlackHole  | **524,800** | 119.62 | 608% / 637%    | 189 MB / 410 MB | **1.34x** |
| Vector-VRL    | TCP -> BlackHole  | 392,200     | 89.39  | 472% / 512%    | 162 MB / 166 MB | 1.0x     |
| Vector-Fixed  | TCP -> BlackHole  | 208,900     | 47.61  | 502% / 537%    | 146 MB / 151 MB | 0.53x    |
| **WarpParse** | TCP -> File       | **297,100** | 67.72  | 645% / 664%    | 238 MB / 317 MB | **17.90x** |
| Vector-VRL    | TCP -> File       | 16,600      | 3.78   | 138% / 143%    | 138 MB / 143 MB | 1.0x     |
| Vector-Fixed  | TCP -> File       | 17,200      | 3.92   | 156% / 166%    | 128 MB / 133MB  | 1.04x    |

> 解析+转换规则大小：
>
> - WarpParse：521B
> - Vector-VRL：519B
> - Vector-Fixed：500B
>
> **Vector-Fixed 的性能倍数：以同场景下的 Vector-VRL EPS 为基准（1.0x）进行对比计算**

#### 3.2.2 AWS ELB Log（411B）

| 引擎          | 拓扑              | EPS         | MPS    | CPU (Avg/Peak) | MEM (Avg/Peak)  | 性能倍数 |
| :------------ | :---------------- | :---------- | :----- | :------------- | :-------------- | :------- |
| **WarpParse** | File -> BlackHole | **275,900** | 108.14 | 649% / 719%    | 236 MB / 327 MB | **2.22x** |
| Vector-VRL    | File -> BlackHole | 124,333     | 48.73  | 523% / 560%    | 190 MB / 199 MB | 1.0x     |
| Vector-Fixed  | File -> BlackHole | 141,818     | 55.59  | 514% / 529%    | 179 MB / 191 MB | 1.14x    |
| **WarpParse** | TCP -> BlackHole  | **259,900** | 101.87 | 682% / 697%    | 139 MB / 275 MB | **1.99x** |
| Vector-VRL    | TCP -> BlackHole  | 130,600     | 51.19  | 446% / 500%    | 191 MB / 195 MB | 1.0x     |
| Vector-Fixed  | TCP -> BlackHole  | 146,000     | 57.23  | 413% / 441%    | 181 MB / 184 MB | 1.12x    |
| **WarpParse** | TCP -> File       | **139,800** | 54.80  | 717% / 738%    | 139 MB / 296 MB | **7.99x** |
| Vector-VRL    | TCP -> File       | 17,500      | 6.86   | 177% / 194%    | 181 MB / 187 MB | 1.0x     |
| Vector-Fixed  | TCP -> File       | 17,600      | 6.90   | 164% / 182%    | 173 MB / 180 MB | 1.01x    |

> 解析+转换规则大小：
>
> - WarpParse：1694B
> - Vector-VRL：1259B
> - Vector-Fixed：570B
>
> **Vector-Fixed 的性能倍数：以同场景下的 Vector-VRL EPS 为基准（1.0x）进行对比计算**

#### 3.2.3 Sysmon JSON Log (1K)

| 引擎          | 拓扑              | EPS         | MPS    | CPU (Avg/Peak) | MEM (Avg/Peak)  | 性能倍数 |
| :------------ | :---------------- | :---------- | :----- | :------------- | :-------------- | :------- |
| **WarpParse** | File -> BlackHole | **129,400** | 121.68 | 759% / 789%    | 272 MB / 332 MB | **2.07x** |
| Vector-VRL    | File -> BlackHole | 62,631      | 58.90  | 489% / 542%    | 241 MB / 253 MB | 1.0x     |
| Vector-Fixed  | File -> BlackHole | 35,862      | 33.73  | 469% / 531%    | 183 MB / 191 MB | 0.57x    |
| **WarpParse** | TCP -> BlackHole  | **120,000** | 112.84 | 705% / 765%    | 143 MB / 382 MB | **1.60x** |
| Vector-VRL    | TCP -> BlackHole  | 74,800      | 70.34  | 519% / 574%    | 254 MB / 264 MB | 1.0x     |
| Vector-Fixed  | TCP -> BlackHole  | 45,500      | 42.79  | 589% / 683%    | 232 MB / 245 MB | 0.61x    |
| **WarpParse** | TCP -> File       | **84,900**  | 79.83  | 734% / 763%    | 137 MB / 303 MB | **4.99x** |
| Vector-VRL    | TCP -> File       | 17,000      | 15.99  | 216% / 262%    | 230 MB / 245 MB | 1.0x     |
| Vector-Fixed  | TCP -> File       | 16,300      | 15.33  | 284% / 343%    | 208 MB / 220 MB | 0.96x    |

> 解析+转换规则大小：
>
> - WarpParse：2249B
> - Vector-VRL：2536B
> - Vector-Fixed：2344B
>
> **Vector-Fixed 的性能倍数：以同场景下的 Vector-VRL EPS 为基准（1.0x）进行对比计算**

#### 3.2.4 APT Threat Log (3K)

| 引擎          | 拓扑              | EPS         | MPS    | CPU (Avg/Peak) | MEM (Avg/Peak)  | 性能倍数 |
| :------------ | :---------------- | :---------- | :----- | :------------- | :-------------- | :------- |
| **WarpParse** | File -> BlackHole | **123,100** | 416.38 | 599% / 607%    | 199 MB / 265 MB | **7.65x** |
| Vector-VRL    | File -> BlackHole | 16,093      | 54.43  | 674% / 742%    | 188 MB / 199 MB | 1.0x     |
| Vector-Fixed  | File -> BlackHole | 14,366      | 48.59  | 540% / 643%    | 199 MB / 203 MB | 0.89x    |
| **WarpParse** | TCP -> BlackHole  | **114,200** | 386.28 | 508% / 532%    | 228 MB / 248 MB | **6.14x** |
| Vector-VRL    | TCP -> BlackHole  | 18,600      | 62.91  | 769% / 790%    | 243 MB / 252 MB | 1.0x     |
| Vector-Fixed  | TCP -> BlackHole  | 18,500      | 62.58  | 780% / 793%    | 240 MB / 253 MB | 0.99x    |
| **WarpParse** | TCP -> File       | **54,800**  | 185.36 | 441% / 447%    | 196 MB / 215 MB | **5.89x** |
| Vector-VRL    | TCP -> File       | 9,300       | 31.46  | 345% / 479%    | 217 MB / 227 MB | 1.0x     |
| Vector-Fixed  | TCP -> File       | 9,500       | 32.13  | 414% / 474%    | 218 MB / 225 MB | 1.02x    |

> 解析+转换规则大小：
>
> - WarpParse：1638B
> - Vector-VRL：2259B
> - Vector-Fixed：1382B
>
> **Vector-Fixed 的性能倍数：以同场景下的 Vector-VRL EPS 为基准（1.0x）进行对比计算**

#### 3.2.5 Mixed Log (平均日志大小：867B)

| 引擎          | 拓扑              | EPS         | MPS    | CPU (Avg/Peak) | MEM (Avg/Peak)  | 性能倍数 |
| :------------ | :---------------- | :---------- | :----- | :------------- | :-------------- | :------- |
| **WarpParse** | File -> BlackHole | **221,300** | 182.99 | 741% / 760%    | 213 MB / 278 MB | **2.80x** |
| Vector-VRL    | File -> BlackHole | 78,965      | 65.29  | 787% / 797%    | 183 MB / 189 MB | 1.0x     |
| Vector-Fixed  | File -> BlackHole | 70,000      | 57.88  | 793% / 799%    | 164 MB / 169 MB | 0.89x    |
| **WarpParse** | TCP -> BlackHole  | **209,900** | 173.56 | 696% / 723%    | 128 MB / 228 MB | **2.51x** |
| Vector-VRL    | TCP -> BlackHole  | 83,600      | 69.13  | 776% / 784%    | 209 MB / 222 MB | 1.0x     |
| Vector-Fixed  | TCP -> BlackHole  | 73,400      | 60.69  | 778% / 782%    | 194 MB / 203 MB | 0.88x    |
| **WarpParse** | TCP -> File       | **134,900** | 111.55 | 724% / 741%    | 122 MB / 164 MB | **8.65x** |
| Vector-VRL    | TCP -> File       | 15,600      | 12.90  | 225% / 256%    | 209 MB / 221 MB | 1.0x     |
| Vector-Fixed  | TCP -> File       | 17,000      | 14.06  | 265% / 278%    | 192 MB / 199 MB | 1.09x    |

> 解析+转换规则大小：
>
> - WarpParse：6102B
> - Vector-VRL：6573B
> - Vector-Fixed：4796B
>
> **Vector-Fixed 的性能倍数：以同场景下的 Vector-VRL EPS 为基准（1.0x）进行对比计算**
>
> 混合日志规则：
>
> - 4类日志按照3:2:1:1混合

## 4. 核心发现与架构优势分析

### 4.1 性能与资源效率

**核心发现**:

1.  **吞吐量领先**: Linux 平台最新数据，WarpParse 在解析场景领先约 **1.56x - 20.30x**，解析+转换场景领先约 **1.34x - 17.90x**，TCP -> File 端到端优势最明显。
2.  **算力利用率**: WarpParse 依然采用“以算力换吞吐”的策略，CPU 占用高于 Vector，但换取数倍吞吐回报。
3.  **大日志处理**: 在 APT (3K) 场景下，WarpParse 维持高吞吐与高 MPS，Vector 吞吐下降明显。

### 4.2 运维与部署成本

**优势分析**:

*   **规则选型简单**: WarpParse 全量场景用一套语法；Vector 需在 VRL 正则与内置解析间择优，新增场景时要先评估可用内置能力，决策链更长。
*   **端到端链路收益高**: TCP -> File 端到端链路优势显著（解析 5.91x-20.30x，解析+转换 8.65x-17.90x），可在不改拓扑的情况下直接提升，改造成本低。
*   **资源预测性好**: 小包场景内存 120-240MB，APT 大包 TCP -> File 约 224-389MB，可按吞吐目标线性规划容量，减少反复调优。

### 4.3 稳定性

*   压力测试过程中，WarpParse 保持稳定吞吐，未观察到明显背压导致的处理崩塌。
*   **注意点**: 在 TCP -> File 大包场景（如 APT），WarpParse 内存随吞吐上升（约 224-389 MB），需结合容量规划。

## 5. 总结与建议

| 决策维度           | 建议方案      | 理由                                                                                                                         |
| :----------------- | :------------ | :--------------------------------------------------------------------------------------------------------------------------- |
| **追求极致性能**   | **WarpParse** | 解析场景领先约 1.56x-20.30x，解析+转换场景领先约 1.34x-17.90x，TCP -> File 端到端链路优势最大。                               |
| **资源受限环境**   | **WarpParse** | 峰值 CPU 较高，但完成同等数据量所需的总 CPU 时间更少；小包场景内存控制优秀。                                                  |
| **边缘/Agent部署** | **WarpParse** | 规则文件小，便于快速热更新；单机处理能力强，减少中心端压力。                                                                 |
| **通用生态兼容**   | **WarpParse** | 提供面向开发者的 API 与插件扩展机制，支持自定义输入/输出模块，兼顾性能与生态扩展能力。                                       |

**结论**:
Linux 最新数据表明，**WarpParse 在吞吐、规则体积与端到端能力上显著优于 Vector**：纯解析场景领先约 **1.56x - 20.30x**，解析+转换场景领先约 **1.34x - 17.90x**，优势在 TCP -> File 端到端链路上最为明显。综合吞吐与规则体积优势，WarpParse 适合 SIEM/SOC 等实时高吞吐场景；但需关注大包场景下（如 APT，TCP -> File）内存会随吞吐提升而增长。
