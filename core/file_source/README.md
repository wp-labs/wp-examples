# File Source

This example demonstrates file-based data source ingestion for batch processing scenarios.

## Purpose

Validate the ability to:
- Read input data from local files
- Process data through WPL parsing rules
- Route parsed data to configured sinks
- Handle file-based batch processing workflows

## Features Validated

| Feature | Description |
|---------|-------------|
| File Source | Reading data from local file system |
| Batch Processing | Processing files in batch mode |
| Data Routing | Routing parsed data to business/infra sinks |

## Quick Start

```bash
cd core/file_source
./run.sh
```

## Directory Structure

```
file_source/
├── conf/wparse.toml       # Main configuration
├── models/
│   ├── wpl/               # Parsing rules
│   ├── sinks/             # Sink routing
│   └── sources/           # File source config
└── data/
    ├── in_dat/            # Input files
    └── out_dat/           # Output files
```

---

# FileSource (中文)

本用例演示基于文件的数据源输入场景，适用于批处理工作流。
