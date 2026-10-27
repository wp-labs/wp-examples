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
| Global Tags | Instance-level `WP_GLOBAL_TAGS` survive the OML transform and win name conflicts |

## Quick Start

```bash
cd core/file_source
./run.sh
```

## Global Tags

`run.sh` exports an instance-level tag set before starting the engine:

```bash
export WP_GLOBAL_TAGS="tenant_id=1000000000000000001,from_zone=global_zone"
```

Both business sink groups use OML (`oml = ["example1"]` / `["example2"]`), which rebuilds each
record from the model output. Step 5 of `run.sh` asserts that:

- `tenant_id` appears exactly once on every output record (it is not part of the models);
- `from_zone` is `global_zone`, overriding the `work_zone` constant declared in both models;
- `benchmark2` also configures a colliding sink tag (`tenant_id: from-sink`); the final value is
  still the global one, with a single key and no duplicates;
- the non-conflicting sink tag `env: dev` is kept on `benchmark2` output only.

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

## 验证的全局 tag 行为

`run.sh` 在启动前导出实例级 tag：

```bash
export WP_GLOBAL_TAGS="tenant_id=1000000000000000001,from_zone=global_zone"
```

两个业务 sink 组都配置了 OML（`oml = ["example1"]` / `["example2"]`），OML 会用模型输出重建记录。
`run.sh` 第 5 步断言：

- `tenant_id` 在每条输出记录上恰好出现一次（模型里没有该字段）；
- `from_zone` 为 `global_zone`，覆盖两个模型里写死的 `work_zone`；
- `benchmark2` 额外配置了同名 sink tag（`tenant_id: from-sink`），最终仍取全局值，且只保留一个键；
- 不冲突的 sink tag `env: dev` 只出现在 `benchmark2` 的输出里。
