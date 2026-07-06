# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [2026-07-05]

### Changed
- **CLI**: 所有脚本和文档中的 `wproj` 重命名为 `wpadm`（`verify_commands`、`run.sh`、`benchmark_common.sh` 等）
- **Sources**: `getting_started` 和 `core/` 下全部示例从 `wpsrc.toml` 单文件格式迁移为目录式 source 格式（每个 source 一个 `.toml` 文件）
  - `getting_started`: `file_1.toml` + `syslog_1.toml`
  - `core/`: 18 个目录从 `wpsrc.toml` 转换为独立 `.toml` 文件

### Fixed
- **benchmark_common.sh**: 修复 `wparse deamon` → `wparse daemon` 拼写错误

## [2026-06-19]

### Fixed

- **core/syslog_udp/run.sh**: 修复脚本多个问题
  - `wparse deamon` 拼写错误 → `wparse daemon`
  - 固定 `sleep 3` 改为 `lsof` 轮询 UDP 端口（1524+1525），解决 wparse 端口未就绪时 wpgen 的 `udp send error`
  - 两个 wpgen 后台运行，使用 PID 特指 `wait $WP1 $WP2`，避免 `wait` 无参时卡在 wparse 守护进程上导致脚本不退出
  - `kill` 改为 `kill -9` + `kill -0` 循环确认进程死透
  - `cat | xargs kill` 简化为 `kill $(cat ...)`

## [2026-01-12]

### Added

- **评估文档**: 重组 SUMMARY.md 并添加评估相关文档
- **稳定性测试**: 新增 SRC04-DST09 稳定性测试功能
- **vlog 示例**: 提供 vlog 使用示例实现
- **mdBook 支持**:
  - 添加 mdBook 文档框架
  - 配置自动化 CI 工作流
  - 使用容器镜像简化 CI 流程
- **初学者指南**: 新增和完善 beginner_guide.md 文档
- **confvars_case 示例项目**: 新增完整的配置变量使用案例
  - 添加配置文件 `conf/wparse.toml` 和 `conf/wpgen.toml`
  - 添加安全密钥配置 `.warp_parse/sec_key.toml`
  - 添加知识库模型:
    - `address` 表 (create.sql, data.csv, insert.sql)
    - `example` 表 (create.sql, data.csv, insert.sql)
    - 知识库配置 `knowdb.toml`
  - 添加 OML 模型:
    - `benchmark1/adm.oml`
    - `benchmark2/adm.oml`
  - 添加 WPL 规则:
    - `benchmark/parse.wpl` - 解析规则
    - `benchmark/gen_rule.wpl` - 生成规则
    - `benchmark/sample.dat` - 示例数据
  - 添加拓扑配置:
    - Sources: `wpsrc.toml`
    - Sinks:
      - Business sinks: `benchmark1.toml`, `benchmark2.toml`
      - Infra sinks: `default.toml`, `error.toml`, `miss.toml`, `monitor.toml`, `residue.toml`
      - 默认配置: `defaults.toml`
  - 添加运行脚本 `run.sh`
  - 添加项目说明文档 `README.md`

### Changed

- **文档结构重组**: 重新组织文档结构并重命名相关文件
- **README 重构**: 改进 README 结构，增强初学者引导内容
- **MySQL 连接器安全性增强**: 更新 `connectors/sink.d/50-mysql.toml`
  - 将硬编码的用户名和密码改为使用环境变量
  - `username`: 使用 `${SEC_MYSQL_USER}`
  - `password`: 使用 `${SEC_MYSQL_PWD}`

## [2026-01-09]

### Fixed

- **demo-parseql**: 修复 demo-parseql 相关问题
- **日志异常**: 解决普通日志异常问题

### Changed

- 合并分支更新
- 生产环境 nginx 配置调整
