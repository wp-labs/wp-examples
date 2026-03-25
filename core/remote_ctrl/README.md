# Remote Ctrl

This example demonstrates a remote project bootstrap, then an admin-driven reload that updates the project from `0.1.2` to `0.1.3`.

## Purpose

Validate the ability to:
- Initialize a fresh work root from a remote project repository via `wproj init --repo`
- Start `wparse` from the remotely bootstrapped project
- Reach the local admin API through the `wproj engine` wrapper
- Trigger a runtime reload and verify the recorded reload result

## Remote Source

- Repo: `https://github.com/wp-labs/editor-monitor-conf.git`
- Default init version in this case: `0.1.2`
- Default reload target version in this case: `0.1.3`

## Quick Start

```bash
cd core/remote_ctrl
./run.sh
```

Optional overrides:

```bash
REPO_URL=https://github.com/wp-labs/editor-monitor-conf.git \
INIT_VERSION=0.1.2 \
TARGET_VERSION=0.1.3 \
WORK_ROOT="$PWD/.tmp-work" \
RELOAD_TIMEOUT_MS=1000 \
./run.sh
```

## What The Script Does

1. Creates a clean temporary work root under `.tmp-work`
2. Runs remote bootstrap with `wproj init --repo ... --version ...`
3. Creates `${HOME}/.warp_parse/admin_api.token` so the remote project's admin profile can be used as-is
4. Seeds a minimal `data/in_dat/gen.dat` file so the file source can start
5. Starts `wparse daemon` on the repo-provided `127.0.0.1:19090`
6. Waits until `wproj engine status --json` reports `accepting_commands=true`
7. Triggers `wproj engine reload --update --version 0.1.3 --json`
8. Verifies `project_version` has switched to `0.1.3` and `last_reload_result=reload_done`

## Notes

- This case requires network access because it bootstraps from a remote Git repository.
- The generated project files are written to `.tmp-work` and left in place after the run for inspection.
- The reload step is executed through `wproj engine reload`, which calls the local admin API.
- This case intentionally keeps the remote project's `${HOME}`-based admin token path and writes the expected token file under `${HOME}/.warp_parse/admin_api.token`.
- The admin API bind remains `127.0.0.1:19090`; if that port is occupied on the local machine, the case is expected to fail directly.

---

# remote_ctrl (中文)

本用例演示“从远端仓库初始化工程，然后通过管理面触发 reload，并在 reload 时切换到新版本”的场景。

## 目的

验证以下能力：
- 使用 `wproj init --repo` 从远端项目仓库完成首次初始化
- 使用远端初始化得到的工程启动 `wparse`
- 通过 `wproj engine` 本地管理面封装访问 admin API
- 触发一次 runtime reload，并校验 reload 结果已被运行时记录

## 远端仓库

- 仓库地址：`https://github.com/wp-labs/editor-monitor-conf.git`
- 本用例默认初始化版本：`0.1.2`
- 本用例默认 reload 目标版本：`0.1.3`

## 快速开始

```bash
cd core/remote_ctrl
./run.sh
```

可选覆盖参数：

```bash
REPO_URL=https://github.com/wp-labs/editor-monitor-conf.git \
INIT_VERSION=0.1.2 \
TARGET_VERSION=0.1.3 \
WORK_ROOT="$PWD/.tmp-work" \
RELOAD_TIMEOUT_MS=1000 \
./run.sh
```

## 脚本流程

1. 在 `.tmp-work` 下创建一个干净的工作目录
2. 执行 `wproj init --repo ... --version ...` 进行远端初始化
3. 在 `${HOME}/.warp_parse/admin_api.token` 下写入 token，直接复用远端项目原始 admin 配置
4. 预置一个最小 `data/in_dat/gen.dat` 文件，确保 file source 可以正常启动
5. 使用仓库中的固定地址 `127.0.0.1:19090` 启动 `wparse daemon`
6. 等待 `wproj engine status --json` 返回 `accepting_commands=true`
7. 执行 `wproj engine reload --update --version 0.1.3 --json`
8. 校验运行时 `project_version` 已切换到 `0.1.3`，且 `last_reload_result=reload_done`

## 说明

- 本用例依赖网络访问，因为初始化阶段会访问远端 Git 仓库。
- 初始化得到的工程会保留在 `.tmp-work` 下，便于失败后排查。
- 这里的 reload 是通过 `wproj engine reload` 触发的，本质上走的是本地 admin API。
- 本用例保留远端仓库原始的 `${HOME}` token 路径，并在 `${HOME}/.warp_parse/admin_api.token` 下准备对应 token 文件。
- 管理面地址保持仓库默认的 `127.0.0.1:19090`；如果本机该端口被占用，用例会直接失败报错。
