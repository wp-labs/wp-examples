# file_file 场景说明

本用例演示"文件源 → 文件汇"的性能基准测试场景：使用单路文件源生成测试数据，通过 wparse batch 模式处理，输出到文件。适用于测试完整的文件处理管道性能。

## 场景特点

- **单路文件源**：生成单个 `gen.dat` 数据文件
- **Batch 处理**：使用批处理模式（非 daemon 模式）
- **文件输出**：数据解析后输出到文件
- **大规模数据**：默认 2000 万行，中等模式 20 万行

## 目录结构

```
file_file/
├── models/
│   └── sinks/
│       ├── defaults.toml
│       └── infra.d/    # 基础组配置
├── data/
│   ├── in_dat/         # 输入数据目录
│   └── logs/           # 日志目录
└── run.sh              # 运行脚本
```

## 快速使用

```bash
cd benchmark

# 默认大规模测试（2000 万行）
./file_file/run.sh

# 中等规模测试（20 万行）
./file_file/run.sh -m

# 强制重新生成数据
./file_file/run.sh -f

# 指定 worker 数量
./file_file/run.sh -w 12

# 使用 sysmon 规则
./file_file/run.sh sysmon

# 组合选项
./file_file/run.sh -m -w 8 nginx 1000000
```

## 参数说明

| 参数 | 说明 | 默认值 |
|------|------|--------|
| `-m` | 使用中等规模数据集 | 2000 万行 → 20 万行 |
| `-f` | 强制重新生成数据 | 跳过已存在的数据 |
| `-c <cnt>` | 指定数据条数 | 与 `-m` 互斥 |
| `-w <cnt>` | 指定 worker 数量 | batch 默认 10 |
| `wpl_dir` | WPL 规则目录 | nginx |
| `speed` | 生成限速（行/秒） | 0（不限速） |

## 执行流程

1. 解析命令行参数
2. 初始化 release 环境
3. 验证 WPL 路径
4. 清理旧数据（`wproj data clean`）
5. 检查/生成输入数据
6. 执行 `wparse batch` 处理
7. 输出统计结果

## 与 file_blackhole 的区别

| 特性 | file_file | file_blackhole |
|------|-----------|----------------|
| 数据源 | 单路 | 双路 |
| 输出 | 文件 | Blackhole |
| 用途 | 完整管道测试 | 纯解析性能测试 |

## 相关文档
- [Benchmark 总览](../README.md)
- [file_blackhole](../file_blackhole/README.md)
