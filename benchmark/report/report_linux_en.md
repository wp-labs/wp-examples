# WarpParse, Vector, Logstash Performance Benchmark Report

## 1. Technical Overview and Testing Background

### 1.1 Testing Background

This report documents the single-machine benchmark test results completed on the Linux platform, covering typical scenarios from lightweight Web logs to complex security threat logs. It is used to establish a phased benchmark baseline to facilitate horizontal and vertical comparisons between subsequent versions or solutions. This document only describes the test methods and results, and does not extrapolate performance limits for production environments.

### 1.2 Test Subjects

*   **WarpParse**: ETL core engine developed by DaYu Security, built with Rust.
*   **Vector**: Open-source observability data pipeline tool, built with Rust.
    *   Vector-VRL: Uses VRL's `parse_regex` for regex parsing.
    *   Vector-Fixed: Prioritizes built-in parsing when possible (e.g., nginx/aws built-in functions; sysmon direct JSON parsing; APT still uses regex when no specialized method available).
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
- **Platform Type**: AWS EC2
- **Instance Type**: c5a.2xlarge
- **Operating System**: Ubuntu 24.04 LTS
- **System Architecture**: x86_64
- **Network Environment**: Local loopback (127.0.0.1, Loopback)

#### Compute Resources (Compute)
- **CPU**: 8 vCPU
- **CPU Model**: AMD EPYC 7R32
- **Memory**: 16 GiB

#### Storage Configuration (Storage)
- **Storage Type**: Amazon EBS
- **Volume Type**: General Purpose SSD (gp3)
- **Volume Size**: 128 GiB
- **IOPS**: 30,000
- **Throughput**: 200 MiB/s

#### Notes
- gp3 volume supports independent configuration of IOPS and throughput to avoid strong coupling between capacity and performance
- Current configuration provides high random I/O capability (IOPS) and moderate sequential I/O throughput capability
- Network bandwidth/network card capability:
  - All TCP scenarios in this report are based on local loopback (127.0.0.1) for data transmission and reception;
  - Test traffic does not go through physical network card or cloud instance network links, and is not limited by instance network bandwidth or ENI performance;
  - TCP scenarios mainly reflect kernel TCP protocol stack overhead and the engine's own parsing, scheduling and I/O processing capabilities.

### 2.2 Test Scope

*   **Log Types**:
    *   **Nginx Access Log** (239B): Typical web access log, high-throughput scenario.
    *   **AWS ELB Log** (411B): Cloud infrastructure load balancer log, medium complexity.
    *   **Sysmon JSON** (1K): Endpoint security monitoring log, JSON structure, many fields.
    *   **APT Threat Log** (3K): Simulated advanced persistent threat log, large volume, long text.
    *   **Mixed Log**: Log type formed by mixing the above four log types.
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
*   **Rule Size**: Size of rule configuration file, assessing distribution and maintenance costs.
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

## 3. Detailed Throughput Performance Comparison Analysis

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

| Engine          | Topology              | EPS         | MPS    | CPU (Avg/Peak) | MEM (Avg/Peak)  | Multiplier |
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

| Engine          | Topology              | EPS         | MPS    | CPU (Avg/Peak) | MEM (Avg/Peak)  | Multiplier |
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
| **WarpParse** | File -> BlackHole | **153,000** | 143.87 | 700% / 749%    | 217 MB / 338 MB | **4.01x** |
| Vector  | File -> BlackHole | 38,196      | 35.92  | 482% / 518%    | 167 MB / 175 MB | 1.0x |
| Logstash | File -> BlackHole | 48,076 | 45.21 | 612% / 709% | 1184 MB / 1197 MB | 1.26x |
| **WarpParse** | TCP -> BlackHole  | **149,800** | 140.86 | 724% / 766%    | 180 MB / 431 MB | **3.19x** |
| Vector  | TCP -> BlackHole  | 47,000      | 44.20  | 576% / 646%    | 208 MB / 221 MB | 1.0x |
| Logstash | TCP -> BlackHole | 54,347 | 51.10 | 661% / 722% | 1340 MB / 1390 MB | 1.16x |
| **WarpParse** | TCP -> File       | **104,900** | 98.64  | 732% / 764%    | 138 MB / 288 MB | **6.77x** |
| Vector  | TCP -> File       | 15,500      | 14.58  | 288% / 342%    | 187 MB / 196 MB | 1.0x |
| Logstash | TCP -> File | 52,083 | 48.98 | 654% / 709% | 1277 MB / 1315 MB | 3.36x |

> Parsing rule size:
>
> - WarpParse: 1552B
> - Vector-Fixed: 1852B
> - Logstash: 2406B
>
>For the same log type + same topology, all engines are normalized for comparison using Vector's EPS as the unified baseline (1.0x).

#### 3.1.4 APT Threat Log (3K)

Table 3.1.4-1: APT Threat Log (Parse Only; File -> BlackHole / TCP -> BlackHole / TCP -> File)

| Engine          | Topology              | EPS         | MPS    | CPU (Avg/Peak) | MEM (Avg/Peak)  | Multiplier |
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

> Parsing rule size:
>
> - WarpParse: 985B
> - Vector: 873B
> - Logstash: 1027B
>
>For the same log type + same topology, all engines are normalized for comparison using Vector's EPS as the unified baseline (1.0x).

#### 3.1.5 Mixed Log (Average log size: 867B)

Table 3.1.5-1: Mixed Log (Parse Only; File -> BlackHole / TCP -> BlackHole / TCP -> File)

| Engine          | Topology              | EPS         | MPS    | CPU (Avg/Peak) | MEM (Avg/Peak)  | Multiplier |
| :------------ | :---------------- | :---------- | :----- | :------------- | :-------------- | :------- |
| **WarpParse** | File -> BlackHole | **270,000** | 223.25 | 726% / 757%    | 240 MB / 348 MB | **3.35x** |
| Vector-VRL    | File -> BlackHole | 80,555      | 66.61  | 780% / 796%    | 177 MB / 187 MB | 1.0x     |
| Vector-Fixed  | File -> BlackHole | 74,418      | 61.54  | 790% / 797%    | 161 MB / 166 MB | 0.92x    |
| Logstash | File -> BlackHole | 34,482 | 28.51  | 573% / 652% | 1159 MB / 1209 MB | 0.43x |
| **WarpParse** | TCP -> BlackHole  | **259,900** | 214.90 | 688% / 697%    | 141 MB / 206 MB | **2.99x** |
| Vector-VRL    | TCP -> BlackHole  | 86,800      | 71.77  | 762% / 774%    | 199 MB / 207 MB | 1.0x     |
| Vector-Fixed  | TCP -> BlackHole  | 78,200      | 64.66  | 777% / 783%    | 183 MB / 190 MB | 0.90x    |
| Logstash | TCP -> BlackHole | 43,103 | 35.64 | 664% / 722% | 1306 MB / 1343 MB | 0.50x |
| **WarpParse** | TCP -> File       | **159,700** | 132.05 | 704% / 719%    | 133 MB / 202 MB | **10.44x** |
| Vector-VRL    | TCP -> File       | 15,300      | 12.65  | 223% / 255%    | 203 MB / 213 MB | 1.0x     |
| Vector-Fixed  | TCP -> File       | 16,500      | 13.64  | 248% / 264%    | 183 MB / 189 MB | 1.08x    |
| Logstash | TCP -> File | 40,000 | 33.07 | 612% / 676% | 1316 MB / 1377 MB | 2.61x |

> Parsing rule size:
>
> - WarpParse: 3864B
> - Vector-VRL: 3960B
> - Vector-Fixed: 4725B
> - Logstash: 5396B
>
> For the same log type + same topology, all engines are normalized for comparison using Vector-VRL's EPS as the unified baseline (1.0x).
>
> Rule size may be affected by format/line breaks/comments/paths, size difference does not affect performance scope; rule logic remains consistent.
>
> Mixed log rules:
>
> - 4 log types mixed in a 3:2:1:1 ratio


### 3.2 Parsing + Transform Capability (Parse + Transform)

This section presents test results for parsing + transform scenarios.

#### 3.2.1 Nginx Access Log (239B)

Table 3.2.1-1: Nginx Access Log (Parse + Transform; File -> BlackHole / TCP -> BlackHole / TCP -> File)

| Engine          | Topology              | EPS         | MPS    | CPU (Avg/Peak) | MEM (Avg/Peak)  | Multiplier |
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
| **WarpParse** | File -> BlackHole | **129,400** | 121.68 | 759% / 789%    | 272 MB / 332 MB | **3.61x** |
| Vector  | File -> BlackHole | 35,862      | 33.73  | 469% / 531%    | 183 MB / 191 MB | 1.00x |
| Logstash | File -> BlackHole | 34,883 | 32.80 | 570% / 685% | 1150 MB / 1170 MB | 0.99x |
| **WarpParse** | TCP -> BlackHole  | **120,000** | 112.84 | 705% / 765%    | 143 MB / 382 MB | **2.64x** |
| Vector  | TCP -> BlackHole  | 45,500      | 42.79  | 589% / 683%    | 232 MB / 245 MB | 1.00x |
| Logstash | TCP -> BlackHole | 38,961 | 36.64 | 646% / 713% | 1218 MB / 1251 MB | 0.86x |
| **WarpParse** | TCP -> File       | **84,900**  | 79.83  | 734% / 763%    | 137 MB / 303 MB | **5.21x** |
| Vector  | TCP -> File       | 16,300      | 15.33  | 284% / 343%    | 208 MB / 220 MB | 1.00x |
| Logstash | TCP -> File | 37,974 | 35.71 | 417% / 544% | 1323 MB / 1359 MB | 2.33x |

> Parse+Transform rule size:
>
> - WarpParse: 2249B
> - Vector: 2344B
> - Logstash: 3453B
>
>For the same log type + same topology, all engines are normalized for comparison using Vector-VRL's EPS as the unified baseline (1.0x).

#### 3.2.4 APT Threat Log (3K)

Table 3.2.4-1: APT Threat Log (Parse + Transform; File -> BlackHole / TCP -> BlackHole / TCP -> File)

| Engine          | Topology              | EPS         | MPS    | CPU (Avg/Peak) | MEM (Avg/Peak)  | Multiplier |
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

> Parse+Transform rule size:
>
> - WarpParse: 1638B
> - Vector: 1382B
> - Logstash: 2041B
>
>For the same log type + same topology, all engines are normalized for comparison using Vector-VRL's EPS as the unified baseline (1.0x).

#### 3.2.5 Mixed Log (Average log size: 867B)

Table 3.2.5-1: Mixed Log (Parse + Transform; File -> BlackHole / TCP -> BlackHole / TCP -> File)

| Engine          | Topology              | EPS         | MPS    | CPU (Avg/Peak) | MEM (Avg/Peak)  | Multiplier |
| :------------ | :---------------- | :---------- | :----- | :------------- | :-------------- | :------- |
| **WarpParse** | File -> BlackHole | **221,300** | 182.99 | 741% / 760%    | 213 MB / 278 MB | **2.80x** |
| Vector-VRL    | File -> BlackHole | 78,965      | 65.29  | 787% / 797%    | 183 MB / 189 MB | 1.0x     |
| Vector-Fixed  | File -> BlackHole | 70,000      | 57.88  | 793% / 799%    | 164 MB / 169 MB | 0.89x    |
| Logstash | File -> BlackHole | 32,967 | 27.26 | 573% / 685% | 1150 MB / 1172 MB | 0.42x |
| **WarpParse** | TCP -> BlackHole  | **209,900** | 173.56 | 696% / 723%    | 128 MB / 228 MB | **2.51x** |
| Vector-VRL    | TCP -> BlackHole  | 83,600      | 69.13  | 776% / 784%    | 209 MB / 222 MB | 1.0x     |
| Vector-Fixed  | TCP -> BlackHole  | 73,400      | 60.69  | 778% / 782%    | 194 MB / 203 MB | 0.88x    |
| Logstash | TCP -> BlackHole | 35,714 | 29.53 | 649% / 712% | 1342 MB / 1401MB | 0.43x |
| **WarpParse** | TCP -> File       | **134,900** | 111.55 | 724% / 741%    | 122 MB / 164 MB | **8.65x** |
| Vector-VRL    | TCP -> File       | 15,600      | 12.90  | 225% / 256%    | 209 MB / 221 MB | 1.0x     |
| Vector-Fixed  | TCP -> File       | 17,000      | 14.06  | 265% / 278%    | 192 MB / 199 MB | 1.09x    |
| Logstash | TCP -> File | 32,258 | 26.67 | 646% / 706% | 1337 MB / 1391MB | 2.07x |

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

## 4 Fixed-Rate Resource Usage Test

#### 4.1 Mixed Log (Average log size: 867B)

Table 4.1.1-1: Mixed Log (Parse Only; TCP -> BlackHole)

| Engine          | Topology             | CPU (Avg/Peak) | MEM (Avg/Peak)    |
| :------------ | :--------------- | :------------- | :---------------- |
| **WarpParse** | TCP -> BlackHole | 54% / 56%      | 60 MB / 66 MB     |
| Vector-VRL    | TCP -> BlackHole | 173% / 180%    | 162 MB / 166 MB   |
| Vector-Fixed  | TCP -> BlackHole | 171% / 177%    | 128 MB / 134 MB   |
| Logstash      | TCP -> BlackHole | 276% / 396%    | 1190 MB / 1223 MB |

> - Resource consumption at **20000EPS**
> - Logstash collected after warmup


## 5. Result Interpretation

### 5.1 Throughput and Resource Performance

**Summary**:

1.  In Linux platform testing, WarpParse's EPS multiplier relative to Vector-VRL ranges from: parse **1.56x - 20.30x**, parse+transform **1.34x - 17.90x**; multiplier range is higher in TCP -> File topology.
2.  CPU usage is generally higher in WarpParse scenarios than Vector/Logstash (see each table); throughput improvement and CPU usage occur simultaneously.
3.  In APT (3K) scenario, WarpParse maintains high MPS level; Vector's EPS/MPS is relatively lower in the same scenario (see 3.1.4/3.2.4).

* ### 5.2 Rule and Expression Capability Key Points

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

### 5.3 Stability

*   This report does not introduce dedicated metrics such as backpressure/queue depth, stability judgment is based only on throughput and resource observations during runtime.
*   **Note**: In TCP -> File large packet scenarios (such as APT), memory rises with throughput (about 224-389 MB), needs to be combined with capacity planning.

## 6. Phased Summary and Recommendations

The following are phased observations based on the scope of this report and do not constitute production selection conclusions; actual deployment needs to be evaluated in combination with business traffic, architectural constraints and operational capabilities.

| Decision Dimension           | Recommended Solution | Result Summary | Basis                                                                                                                         |
| :----------------- | :------- | :------- | :--------------------------------------------------------------------------------------------------------------------------- |
| **Pursue Throughput Capability**   | **WarpParse** | Focus on EPS multiplier range in this report | Parse scenario **1.56x-20.30x**, parse+transform **1.34x-17.90x**; TCP -> File topology range is higher.                                            |
| **Resource-Constrained Environment**   | **WarpParse** | Focus on CPU/memory trade-off relationship | Vector-VRL has lower CPU/MEM than WarpParse in most scenarios; Logstash memory usage is significantly higher (see each table).                                          |
| **Edge/Agent Deployment** | **WarpParse** | Focus on rule size and single-machine throughput | Rule size differs across log types; throughput metrics are higher in this report, see "Rule Size" and table data in each section for specific differences.                                  |
| **General Ecosystem Compatibility**   | **WarpParse** | Focus on ecosystem and extensibility | Ecosystem compatibility is not quantified in this report, it is recommended to evaluate based on existing ecosystem and plugin adaptation costs.                                                                |

**Phased Conclusion**:
Based on this report's data, WarpParse's EPS multiplier range relative to Vector-VRL is: pure parse **1.56x-20.30x**, parse+transform **1.34x-17.90x**, end-to-end (TCP -> File) multiplier is higher. The above results can serve as a phased baseline reference for similar scenarios; in large packet TCP -> File scenarios, need to pay attention to memory rising with throughput (about 224-389 MB).

## 7. Known Limitations and Precautions

*   This report is a single-machine test and does not cover multi-node, HA (High Availability), persistence optimization or production load fluctuation and other factors.
*   The test scope is limited to five log types and three topologies, and does not cover more complex input/output links.
*   Results depend on specific hardware, operating system and storage configuration, cross-environment comparisons need to be cautious.
