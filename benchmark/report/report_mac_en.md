# WarpParse, Vector, Logstash Performance Benchmark Report

## 1. Technical Overview and Testing Background

### 1.1 Testing Background

This report documents the single-machine benchmark test results completed on the Mac platform, covering typical scenarios from lightweight Web logs to complex security threat logs. It is used to establish a phased benchmark baseline to facilitate horizontal and vertical comparisons between subsequent versions or solutions. This document only describes the test methods and results, and does not extrapolate performance limits for production environments.

### 1.2 Test Subjects

*   **WarpParse**: ETL core engine developed by DaYu Security, built with Rust.
*   **Vector**: Open-source observability data pipeline tool, built with Rust.
    *   Vector-VRL: Uses VRL's `parse_regex` for regex parsing.
    *   Vector-Fixed: Prioritizes built-in parsing (e.g., nginx/aws built-in functions; sysmon direct JSON parsing; APT still uses regex parsing).
*   **Logstash**: Log processing engine in the Elastic ecosystem, running on JVM.

### 1.3 Test Subjects and Version Information

The versions used in this test are as follows:

*   **WarpParse**: 0.12.0
*   **Vector**: 0.49.0
*   **Logstash**: 9.2.3

Build and source information:

*   **WarpParse**: Build source/commit/tag = GitHub tag v0.12.0-alpha (commit: 2ba6e55); Build parameters = Official release build artifact (zip/tar.gz), build options not modified
*   **Vector**: Build source/commit/tag = v0.49.0 (commit: dc7e792); Build parameters = Official release binary, build options not modified
*   **Logstash**: Build source/commit/tag = GitHub tag v9.2.3 (commit: 4eb0f3f); Build parameters = Official release package (zip/tar.gz, bundled JDK), no source-level build

This report has documented the version and build source; when reproducing, it is still necessary to ensure that the engine runtime parameters, system configuration, and dataset parameters are consistent.

### 1.4 Report Positioning

This document is positioned as a phased benchmark report, focusing on the reproducibility and long-term comparability of methods and data, and is not intended as a final performance conclusion or production capacity commitment.

## 2. Test Environment and Methods

### 2.1 Test Environment

#### Platform Information (Platform)
- **Platform Type**: Mac mini (Apple M4)
- **Operating System**: macOS 15.5
- **System Architecture**: arm64
- **Network Environment**: Local loopback (127.0.0.1)

#### Compute Resources (Compute)
- **CPU**: 10-core
- **Memory**: 16 GiB
- **Background Tasks/Performance Mode**: Unnecessary background tasks closed during testing; no additional system tuning

#### Storage Configuration (Storage)
- **Storage Medium**: Internal SSD
- **File System**: APFS
- **Volume Size**: 256G

### 2.2 Test Scope

*   **Log Types**:
    *   **Nginx Access Log** (239B): Typical web access log, high-throughput scenario.
    *   **AWS ELB Log** (411B): Cloud infrastructure load balancer log, medium complexity.
    *   **Sysmon JSON** (1K): Endpoint security monitoring log, JSON structure, many fields.
    *   **APT Threat Log** (3K): Simulated advanced persistent threat log, large volume, long text.
    *   **Mixed Log** (867B): Log type formed by mixing the above four log types.
*   **Data Topology**:
    *   **File -> BlackHole**: Measures engine's maximum I/O read and processing capability (baseline).
    *   **TCP -> BlackHole**: Measures network receiving and processing capability.
    *   **TCP -> File**: Measures end-to-end complete landing capability.
*   **Test Capabilities**:
    *   **Parse**: Only performs regex extraction/JSON parsing and field normalization.
    *   **Parse+Transform**: Adds field mapping, enrichment, type conversion and other logic on top of parsing.

### 2.3 Evaluation Metrics

*   **EPS (Events Per Second)**: Number of events processed per second (core throughput metric).
*   **MPS (MiB/s)**: Data volume processed per second.
*   **CPU (Avg/Peak)**: Average and peak CPU usage of the test process.
*   **MEM (Avg/Peak)**: Average and peak memory usage of the test process.
*   **Rule Size**: Size of rule configuration file, used to measure the description complexity required to express equivalent log semantics, while assisting in evaluating configuration distribution, readability and long-term maintenance costs.
*   **Performance Multiplier**: Normalized to 1.0x using Vector-VRL's EPS for the same log type + same topology.

Notes:
*   CPU is cumulative percentage across cores (e.g., 800% ≈ 8 logical cores fully loaded), the statistical object is **the test process itself** (not system total CPU), collected and calculated as Avg/Peak by external monitoring script at fixed sampling intervals.
*   MPS calculation formula: **MPS = EPS × AvgLogSize(B) / 1024 / 1024**.
- Sampling source and sampling scope description:
  - EPS: Uniformly obtained based on each engine's native observability or statistical interface.
    - WarpParse / Vector: Use the engine's built-in throughput statistics capability.
    - Logstash: Periodically collect its official Monitoring API / runtime statistics through automated scripts.
  - CPU / MEM: Collect resource usage of the test process through external monitoring scripts (based on periodic sampling in shell), for cross-engine comparison.
  - MPS: Calculated based on measured EPS and the average size of the corresponding log, used to assist in measuring actual data throughput scale.
  - Before counting rule size, the configuration was uniformly de-commented/de-blanked, retaining only the effective expression part to reduce the impact of format differences.
  - Different engines may have different collection implementation methods for each metric, but the statistical scope remains consistent, and results are based on the most authoritative source for each metric.

### 2.4 Test Method and Execution Approach

Tests are executed item by item in a single-machine environment by log type and topology. Input data is generated or replayed by the benchmark script provided in this repository,
and each engine runs independently during testing to avoid mutual interference.
The output target is configured as BlackHole or File according to the test topology to evaluate pure processing capability and end-to-end performance including I/O, respectively.

See benchmark/README.md for test execution flow, script entry points, and general parameter descriptions.

### 2.4.1 Minimal Reproduction Checklist

  - Engine version and source:
    - See 1.3 for WarpParse / Vector / Logstash version, tag, commit, and build method.

  - Benchmark toolchain version:
    - The benchmark repository is based on the latest commit (repo HEAD) of the wp-example repository.
    - It is recommended to record the specific commit hash when reproducing experiments to ensure traceability of results.

  - Dataset scale and event count:
    - In this report, "dataset scale" and "event count" are the same concept, both defined by the total number of events processed.
    - In WarpParse's benchmark execution script, the total number of events is specified through the parameter `-c`;
      This parameter is used to clarify the dataset scale, but does not require all engines to have the same parameter form.
    - For Vector and Logstash, the test dataset scale uses the same event count as WarpParse,
      aligning the scale through equal input data, rather than relying on unified startup parameters.
    - Therefore, `-c` can be regarded as a symbolic representation of the "unified event scale definition" in this benchmark,
      rather than a command-line parameter that is universal across engines.

  - Termination condition:
    - All tests use completion of processing equal events as the termination condition.
    - The method of ending after a fixed running time is not adopted,
      to avoid statistical bias caused by differences in startup, warm-up and stable phases among different engines.

- Warmup and sampling window:
    - WarpParse and Vector: Engines quickly enter a stable state after startup, with no separate warmup phase.
    - Logstash: Due to JVM/JIT and pipeline initialization characteristics, a warmup run is performed before testing;
      After confirming that throughput enters a stable range, EPS / resource metrics are collected.

  - Repetition count and value rules:
    - Default single run.
    - For more rigorous statistics, it is recommended to repeat N=3 times and take the median as the final result.

### 2.5 Default Configuration and Tuning Description

Unless explicitly stated in tables or notes, the results in this report are based on the default configuration of each engine, without enabling specialized performance tuning or non-default parameters.

## 3. Detailed Performance Comparison Analysis

### 3.0 Test Results Summary Table

The table below is a result index for locating detail tables of different log types and test capabilities.

| Log Type | Parse Only | Parse + Transform |
| :-- | :-- | :-- |
| Nginx Access Log (239B) | See 3.1.1 | See 3.2.1 |
| AWS ELB Log (411B) | See 3.1.2 | See 3.2.2 |
| Sysmon JSON Log (1K) | See 3.1.3 | See 3.2.3 |
| APT Threat Log (3K) | See 3.1.4 | See 3.2.4 |
| Mixed Log (Avg log size: 867B) | See 3.1.5 | See 3.2.5 |

### 3.1 Log Parsing Capability (Parse Only)
This section presents test results for pure parsing scenarios.

#### 3.1.1 Nginx Access Log (239B)

Table 3.1.1-1: Nginx Access Log (Parse Only; File -> BlackHole / TCP -> BlackHole / TCP -> File)

| Engine          | Topology              | EPS           | MPS    | CPU (Avg/Peak) | MEM (Avg/Peak)  | Multiplier |
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

> Parsing rule size:
>
> - WarpParse: 174B
> - Vector-VRL: 217B
> - Vector-Fixed: 86B
> - Logstash: 248B
>
> For the same log type + same topology, all engines are normalized for comparison using Vector-VRL's EPS as the unified baseline (1.0x).

#### 3.1.2 AWS ELB Log (411B)

Table 3.1.2-1: AWS ELB Log (Parse Only; File -> BlackHole / TCP -> BlackHole / TCP -> File)

| Engine          | Topology              | EPS           | MPS    | CPU (Avg/Peak) | MEM (Avg/Peak)  | Multiplier |
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

> Parsing rule size:
>
> - WarpParse: 1153B
> - Vector-VRL: 921B
> - Vector-Fixed: 64B
> - Logstash: 876B
>
> For the same log type + same topology, all engines are normalized for comparison using Vector-VRL's EPS as the unified baseline (1.0x).

#### 3.1.3 Sysmon JSON Log (1K)

Table 3.1.3-1: Sysmon JSON Log (Parse Only; File -> BlackHole / TCP -> BlackHole / TCP -> File)

| Engine          | Topology              | EPS         | MPS    | CPU (Avg/Peak) | MEM (Avg/Peak)  | Multiplier |
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

> Parsing rule size:
>
> - WarpParse: 1552B
> - Vector-VRL: 1949B
> - Vector-Fixed: 1852B
> - Logstash: 2406B
>
> For the same log type + same topology, all engines are normalized for comparison using Vector-VRL's EPS as the unified baseline (1.0x).

#### 3.1.4 APT Threat Log (3K)

Table 3.1.4-1: APT Threat Log (Parse Only; File -> BlackHole / TCP -> BlackHole / TCP -> File)

| Engine          | Topology              | EPS         | MPS     | CPU (Avg/Peak) | MEM (Avg/Peak)  | Multiplier |
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

> Parsing rule size:
>
> - WarpParse: 985B
> - Vector-VRL: 873B
> - Vector-Fixed: 872B
> - Logstash: 1027B
>
> For the same log type + same topology, all engines are normalized for comparison using Vector-VRL's EPS as the unified baseline (1.0x).

#### 3.1.5 Mixed Log (Average log size: 867B)

Table 3.1.5-1: Mixed Log (Parse Only; File -> BlackHole / TCP -> BlackHole / TCP -> File)

| Engine          | Topology              | EPS         | MPS    | CPU (Avg/Peak) | MEM (Avg/Peak)  | Multiplier |
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

> Parsing rule size:
>
> - WarpParse: 3864B
> - Vector-VRL: 4240B
> - Vector-Fixed: 3154B
> - Logstash: 5396B
>
> For the same log type + same topology, all engines are normalized for comparison using Vector-VRL's EPS as the unified baseline (1.0x).
>
> Mixed log rules:
>
> - 4 log types mixed in a 3:2:1:1 ratio

### 3.2 Parsing + Transform Capability (Parse + Transform)

This section presents test results for parsing + transform scenarios.

#### 3.2.1 Nginx Access Log (239B)

Table 3.2.1-1: Nginx Access Log (Parse + Transform; File -> BlackHole / TCP -> BlackHole / TCP -> File)

| Engine          | Topology              | EPS           | MPS    | CPU (Avg/Peak) | MEM (Avg/Peak)  | Multiplier |
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

> Parse+Transform rule size:
>
> - WarpParse: 521B
> - Vector-VRL: 519B
> - Vector-Fixed: 500B
> - Logstash: 712B
>
> For the same log type + same topology, all engines are normalized for comparison using Vector-VRL's EPS as the unified baseline (1.0x).

#### 3.2.2 AWS ELB Log (411B)

Table 3.2.2-1: AWS ELB Log (Parse + Transform; File -> BlackHole / TCP -> BlackHole / TCP -> File)

| Engine          | Topology              | EPS         | MPS    | CPU (Avg/Peak) | MEM (Avg/Peak)  | Multiplier |
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

> Parse+Transform rule size:
>
> - WarpParse: 1694B
> - Vector-VRL: 1259B
> - Vector-Fixed: 570B
> - Logstash: 2019B
>
> For the same log type + same topology, all engines are normalized for comparison using Vector-VRL's EPS as the unified baseline (1.0x).

#### 3.2.3 Sysmon JSON Log (1K)

Table 3.2.3-1: Sysmon JSON Log (Parse + Transform; File -> BlackHole / TCP -> BlackHole / TCP -> File)

| Engine          | Topology              | EPS         | MPS    | CPU (Avg/Peak) | MEM (Avg/Peak)  | Multiplier |
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

> Parse+Transform rule size:
>
> - WarpParse: 2249B
> - Vector-VRL: 2536B
> - Vector-Fixed: 2344B
> - Logstash: 3453B
>
> For the same log type + same topology, all engines are normalized for comparison using Vector-VRL's EPS as the unified baseline (1.0x).

#### 3.2.4 APT Threat Log (3K)

Table 3.2.4-1: APT Threat Log (Parse + Transform; File -> BlackHole / TCP -> BlackHole / TCP -> File)

| Engine          | Topology              | EPS         | MPS     | CPU (Avg/Peak) | MEM (Avg/Peak)  | Multiplier |
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

> Parse+Transform rule size:
>
> - WarpParse: 1638B
> - Vector-VRL: 2259B
> - Vector-Fixed: 1382B
> - Logstash: 2041B
>
> For the same log type + same topology, all engines are normalized for comparison using Vector-VRL's EPS as the unified baseline (1.0x).

#### 3.2.5 Mixed Log (Average log size: 867B)

Table 3.2.5-1: Mixed Log (Parse + Transform; File -> BlackHole / TCP -> BlackHole / TCP -> File)

| Engine          | Topology              | EPS         | MPS    | CPU (Avg/Peak) | MEM (Avg/Peak)  | Multiplier |
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

> Parse+Transform rule size:
>
> - WarpParse: 6102B
> - Vector-VRL: 6573B
> - Vector-Fixed: 4796B
> - Logstash: 8391B
>
> For the same log type + same topology, all engines are normalized for comparison using Vector-VRL's EPS as the unified baseline (1.0x).
>
> Rule size may be affected by format/line breaks/comments/paths, size difference does not affect performance scope; rule logic remains consistent.
>
> Mixed log rules:
>
> - 4 log types mixed in a 3:2:1:1 ratio


## 4. Result Interpretation

### 4.1 Throughput and Resource Performance

**Summary**:

1.  In Mac platform testing, WarpParse's EPS multiplier relative to Vector-VRL ranges from: parse **1.42x - 8.78x**, parse+transform **1.35x - 8.44x**; peaks occur in Nginx/Mixed TCP -> File topology.
2.  Under **the same event volume**, WarpParse scenarios generally have higher CPU usage than Vector/Logstash (see each table); throughput improvement and CPU usage occur simultaneously.
3.  In APT (3K) scenario, WarpParse's MPS peak is **1109.53 MiB/s** (File -> BlackHole); Vector's EPS/MPS is relatively lower in the same scenario (see 3.1.4/3.2.4).

### 4.2 Rule and Expression Capability Key Points

  - Rule size not only reflects configuration distribution and maintenance costs,
    but can also serve as a reference metric for measuring the complexity required by the engine to express equivalent log semantics.
    Under the same parsing and transformation semantics, smaller rule size typically means the engine has higher-level built-in capabilities or stronger expression abstraction.

  - See the "Rule Size" notes in the corresponding tables for rule size differences across log types and topologies,
    used to assist in evaluating differences in expression capabilities, rule readability and maintenance complexity among different engines.

  - Vector testing includes both VRL and Fixed strategies:
    - VRL is more oriented towards general expression capability, with stronger flexibility for complex semantics;
    - Fixed prioritizes built-in parsing capabilities, with more advantages in rule size and maintenance complexity.
    Trade-offs between expression capability and performance are subject to table data.

  - For most log types, the TCP → File topology presents a higher performance multiplier range (see corresponding tables in 3.1 / 3.2),
    this conclusion remains consistent across different rule complexity levels.

### 4.3 Stability

*   This report does not introduce dedicated metrics such as backpressure/queue depth, stability judgment is based only on throughput and resource observations during runtime.
*   **Note**: In TCP -> File large packet scenarios, memory rises with throughput (APT scenario peak about 508 MB; Mixed about 432 MB), needs to be combined with capacity planning.

## 5. Phased Summary and Recommendations

The following are phased observations based on the scope of this report and do not constitute production selection conclusions; actual deployment needs to be evaluated in combination with business traffic, architectural constraints and operational capabilities.

| Decision Dimension           | Recommended Solution | Result Summary | Basis                                                                                                                         |
| :----------------- | :------- | :------- | :--------------------------------------------------------------------------------------------------------------------------- |
| **Pursue Throughput Capability**   | **WarpParse** | Focus on EPS multiplier range in this report | Parse scenario **1.42x-8.78x**, parse+transform **1.35x-8.44x**; TCP -> File topology range is higher.                                              |
| **Resource-Constrained Environment**   | **WarpParse** | Focus on CPU/memory trade-off relationship | Although peak CPU is higher, total CPU time required to complete the same data volume is less; excellent memory control in small packet scenarios. |
| **Edge/Agent Deployment** | **WarpParse** | Focus on rule size and single-machine throughput | Rule size differs across log types; throughput metrics are higher in this report, see "Rule Size" and table data in each section for specific differences.                                  |
| **General Ecosystem Compatibility**   | **WarpParse** | Focus on ecosystem and extensibility | Provides developer-oriented API and plugin extension mechanisms, supports users to quickly develop custom input/output modules; while meeting performance requirements, also has good ecosystem extensibility. |

**Phased Conclusion**:
Based on this report's data, WarpParse's EPS multiplier range relative to Vector-VRL is: pure parse **1.42x-8.78x**, parse+transform **1.35x-8.44x**, end-to-end (TCP -> File) multiplier is higher. The above results can serve as a phased baseline reference for similar scenarios; in large packet TCP -> File scenarios, need to pay attention to memory rising with throughput (about 400-500MB).

## 6. Known Limitations and Precautions

*   This report is a single-machine test and does not cover multi-node, HA (High Availability), persistence optimization or production load fluctuation and other factors.
*   The test scope is limited to five log types and three topologies, and does not cover more complex input/output links.
*   Results depend on specific hardware, operating system and storage configuration, cross-environment comparisons need to be cautious.
