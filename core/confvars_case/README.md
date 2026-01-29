# Configuration Variables

This example demonstrates how to use configuration variables for dynamic configuration management.

## Purpose

Validate the ability to:
- Define and use configuration variables in TOML files
- Override variables via environment variables
- Apply variables across sources, sinks, and model configurations

## Features Validated

| Feature | Description |
|---------|-------------|
| Variable Substitution | Using `${VAR}` syntax in configuration files |
| Environment Overrides | Overriding config values via environment variables |
| Default Values | Setting fallback values for undefined variables |
| Cross-Config References | Using variables across multiple configuration files |

## Quick Start

```bash
cd core/confvars_case

# Run with default variables
./run.sh

# Run with custom environment variables
LINE_CNT=5000 STAT_SEC=5 ./run.sh
```

## Directory Structure

```
confvars_case/
├── conf/wparse.toml       # Main config with variable references
├── models/
│   ├── wpl/               # Parsing rules
│   ├── oml/               # Transformation models
│   └── sinks/             # Sink routing
└── data/                  # Runtime data
```

## Example Usage

```toml
# In wparse.toml
[performance]
rate_limit_rps = ${RATE_LIMIT:-500000}  # Default: 500000

[log_conf]
level = "${LOG_LEVEL:-info}"  # Default: info
```

---

# 配置使用变量 (中文)

本用例演示如何在配置中使用变量进行动态配置管理。
