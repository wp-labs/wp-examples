# Stat Test

This example provides statistical testing for validating output metrics and data distribution.

## Purpose

Validate the ability to:
- Collect and verify output statistics
- Test different statistical scenarios (default, miss, single)
- Validate data distribution across sinks
- Ensure statistical accuracy

## Features Validated

| Feature | Description |
|---------|-------------|
| Statistics Collection | Gathering output metrics |
| Scenario Testing | default_test, miss_test, single_test |
| Distribution Validation | Verifying data ratios |
| Metric Accuracy | Ensuring correct counts |

## Test Scenarios

| Scenario | Description |
|----------|-------------|
| default_test | Standard statistical validation |
| miss_test | Statistics with missing data |
| single_test | Single sink statistics |

## Quick Start

两个子用例都有 `run.sh`，会被 `core/run_all.sh` 直接执行（`stat_test/` 本身没有 run.sh，
只作为分组目录）：

```bash
# 全部用例
cd core && ./run_all.sh

# 单独执行
cd core/stat_test/default_test && ./run.sh
cd core/stat_test/miss_test && ./run.sh
```

`file_stat.sh` 只是把 `monitor.dat` 用 `jq` 汇总成 TSV 的小工具（本目录的 monitor sink
用的是 `file_json_sink`，所以 `monitor.dat` 是 JSON；其它用例多是 `file_proto_sink` 的
proto-text）：

```bash
cd core/stat_test/default_test
../file_stat.sh ./data/out_dat/monitor.dat
```

## 校验口径

| 用例 | 场景 | expect |
| --- | --- | --- |
| `default_test` | 加载 benchmark + nginx 两套规则 | `/example//proto` 0.50、`default` 0.50（benchmark 系没有对应 OML，落到 default 组） |
| `miss_test` | 只加载 nginx 规则，输入全是 benchmark 形状 | 业务 sink 0，`miss` 约 6 行/条（多行诊断块：`src_key` / data / `target wpl` / `Error` / `info` + 空行） |

`miss_test` 额外按**记录数**校验（`grep -c '^src_key:'` ≥ 90% 输入），因为行数比值不直观。

两个用例都在 kill daemon 前等输出文件稳定（`wait_drained`）：miss 处理要格式化多行诊断，
比生成慢，固定 `sleep` 会在积压没排空时把进程杀掉，抓到 60%~100% 的数据。

---

# stat_test (中文)

本用例提供统计测试，用于验证输出指标和数据分布。

## 用法

执行完run之后，通过执行