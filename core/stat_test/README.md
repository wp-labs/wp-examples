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

```bash
cd core/stat_test
./file_stat.sh
```

---

# stat_test (中文)

本用例提供统计测试，用于验证输出指标和数据分布。

## 用法

执行完run之后，通过执行