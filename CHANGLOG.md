# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

### Added

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

- **MySQL 连接器安全性增强**: 更新 `connectors/sink.d/50-mysql.toml`
  - 将硬编码的用户名和密码改为使用环境变量
  - `username`: 使用 `${SEC_MYSQL_USER}`
  - `password`: 使用 `${SEC_MYSQL_PWD}`

## Previous Changes

详见 git commit 历史:
- 10eb55a - Merge branch 'main'
- d40c3fc - fix:demo-parseql
- eb5e699 - demo
- b9cfdb7 - 普通日志异常解决
