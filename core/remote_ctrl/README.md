# remote_ctrl (Dual-Repo Mode)

This case demonstrates dual-repo mode, where models and infra are updated independently through the admin API with version switching.

## Purpose

Validates the following capabilities:
- Dual-repo configuration (`[project_remote.models]` + `[project_remote.infra]`)
- Per-group initialization with `wproj conf update --group`
- Directory mapping: models group manages `models/`, infra group manages `conf/` + `topology/` + `connectors/`
- Per-group runtime reload with `wproj engine reload --update --group` and result verification

## Remote Repositories

| Group  | Repository                                        | init_version | target |
|--------|---------------------------------------------------|-------------|--------|
| models | `https://github.com/wp-labs/wp-rule.git`          | `0.1.0`     | `0.1.1` |
| infra  | `https://github.com/wp-labs/editor-monitor-conf.git` | `0.1.6`  | `0.1.7` |

## Directory Mapping

```
Project Layout              Source Repository
────────────                 ────────────────
models/                      models repo (wp-rule)
├── wpl/                     - parse rules
├── oml/                     - model definitions
└── knowledge/               - knowledge base

conf/       ┐
topology/   ├── infra repo (editor-monitor-conf)
connectors/ ┘                - main config, topology, connectors
```

## Quick Start

```bash
cd core/remote_ctrl
./run.sh
```

Optional overrides:

```bash
MODELS_REPO_URL=https://github.com/wp-labs/wp-rule.git \
INFRA_REPO_URL=https://github.com/wp-labs/editor-monitor-conf.git \
MODELS_INIT_VERSION=0.1.0 \
INFRA_INIT_VERSION=0.1.6 \
MODELS_TARGET_VERSION=0.1.1 \
INFRA_TARGET_VERSION=0.1.7 \
WORK_ROOT="$PWD/.tmp-work" \
./run.sh
```

## Script Flow

1. Create a clean work directory under `$WORK_ROOT` (default `.tmp-work`)
2. Write bootstrap config (only the `[project_remote]` section with repo URLs)
3. `wproj conf update --group infra --version 0.1.6` — initialize infra
   - Pulls `conf/`, `topology/`, `connectors/` from editor-monitor-conf
   - Verifies `conf/wparse.toml` is now a full config and directories are populated
4. `wproj conf update --group models --version 0.1.0` — initialize models
   - Pulls `models/` from wp-rule
   - Verifies `models/wpl/` contains `.wpl` files
5. Verify state file is dual-repo format (contains both `models` and `infra` keys)
6. Prepare admin token and sample data
7. Start `wparse daemon`
8. Poll until admin API reports `accepting_commands = true`
9. `wproj engine reload --update --group models --version 0.1.1`
   - Validates response: `accepted=true`, `group=models`, `requested_version=0.1.1`
10. Verify runtime status: `last_reload_request_id` recorded, `reload_done`
11. Verify state file models version updated to `0.1.1`
12. `wproj engine reload --update --group infra --version 0.1.7`
    - Validates response: `accepted=true`, `group=infra`, `requested_version=0.1.7`
13. Verify runtime status records infra reload completion
14. Verify state file infra version updated to `0.1.7`

## Notes

- The case directory contains only `run.sh` and `README.md`; all project files are provided by the two remote repositories via sync
- In dual-repo mode, infra must be synced first (to write the full `conf/wparse.toml`), then models
- The infra repo's own `conf/wparse.toml` already contains the dual-repo config (`[project_remote.models]` + `[project_remote.infra]`), so no manual config patching is needed after infra sync
- `--group` is required in dual-repo mode; models and infra are updated independently
- The work directory is preserved under `$WORK_ROOT` for post-mortem debugging
- Reload is triggered via `wproj engine reload`, which communicates with the local admin API
- The admin bind address defaults to `127.0.0.1:19090`; a port conflict will cause the case to fail
