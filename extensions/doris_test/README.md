# Doris 流式写入测试（File/TCP -> Doris）

本目录提供一套 **Nginx Access Log** 的端到端测试用例，覆盖：

- 文件/网络输入
- 解析与字段转换
- Doris Stream Load 写入
- 性能指标采集与对比

适用于验证 Doris 写入链路正确性，以及评估不同引擎/配置的吞吐表现。

## 目录结构

- `conf/`：示例配置与基准测试配置
- `data/`：输入/输出数据与中间产物
- `models/`：解析/映射模型定义（如 OML/WPL 相关）
- `topology/`：拓扑编排示例（source/transform/sink 组合）
- `vector/`：Vector 示例配置（包含 file/tcp -> doris）
- `sql/`（如有）：建表或验证 SQL
- `docker-compose.yml`：Doris 本地单机启动示例
- `run.sh`：一键运行脚本（生成、解析、写入）
- `monitor.sh`：性能监控辅助脚本

## 快速开始（本地 Doris）

1. 启动 Doris（单机 FE/BE）  
   使用 `docker-compose.yml` 启动，或按内部文档启动已有集群。
2. 准备目标库表  
   建表 SQL 在 `sql/` 或 `models/` 中（以实际文件为准）。
3. 运行测试  
   直接执行 `run.sh`，或按需修改配置后启动。

> 具体命令请以脚本注释与配置为准。

## 配置说明

- Doris Stream Load 关键参数：endpoint、database、table、user、password
- 批量参数：batch_size、pool_size、timeout
- 字段映射：确保解析后的字段与 Doris 表字段类型一致

建议在变更解析规则/字段时，同步更新表结构或映射。

## 性能测试数据

性能测试数据说明见：`PERF_DATA.md`  
包含数据来源、目录位置、统计口径、复现建议。

## 性能指标示例

表 1-1：Nginx Access Log（Parse + Transform；File -> Doris / TCP -> Doris）

| 引擎          | 拓扑          | EPS     | CPU (Avg/Peak) | MEM (Avg/Peak)  |
| :------------ | :------------ | :------ | :------------- | :-------------- |
| **WarpParse** | File -> Doris | 2,000   | N/A*           | N/A*            |
| Vector-VRL    | File -> Doris | 250,000 | 244% / 281%    | 453 MB / 484 MB |
| **WarpParse** | TCP -> Doris  | 1,800   | N/A*           | N/A*            |
| Vector-VRL    | TCP -> Doris  | 330,500 | 256% / 333%    | 532 MB / 569 MB |

> * N/A：在该负载下 WarpParse 资源占用低于监控采样阈值，无法形成有效统计。
> * Doris单机容器部署

## 常见问题排查

- **写入 0 行**：确认 Stream Load 返回信息、JSON 格式（NDJSON/JSON 数组）与 Doris 参数一致
- **字段错位**：检查解析输出字段顺序与 Doris 表字段是否一致
- **连接失败**：确认 FE 地址、账号权限、端口可达

如需补充实际运行参数或结果，请在此 README 追加具体配置与日期说明。
