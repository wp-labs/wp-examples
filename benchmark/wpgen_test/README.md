# wpgen_test 场景说明

本用例专门用于测试 `wpgen` 数据生成器的性能：仅生成样本数据，不启动 wparse 解析。适用于评估数据生成能力、验证生成规则正确性，以及为其他基准测试准备数据。

## 场景特点

- **纯生成测试**：仅测试 wpgen 生成能力，不启动 wparse
- **多规则集**：支持 nginx 和 benchmark 两套规则
- **多速度档位**：测试不同限速下的生成性能
- **大规模数据**：默认生成 800 万行 + 600 行样本

## 目录结构

```
wpgen_test/
├── conf/
│   ├── wparse.toml     # 主配置（本用例不使用）
│   └── wpgen.toml      # 生成器配置
├── models/
│   ├── oml/            # OML 转换模型
│   ├── sinks/          # Sink 配置
│   ├── sources/        # 源配置
│   └── wpl/            # WPL 规则
│       ├── nginx/      # nginx 规则
│       └── benchmark/  # benchmark 规则
├── data/
│   └── logs/           # 日志目录
└── run.sh              # 运行脚本
```

## 快速使用

```bash
cd benchmark

# 默认测试（nginx + benchmark 两套规则）
./wpgen_test/run.sh

# 指定 profile（release/debug）
./wpgen_test/run.sh release
./wpgen_test/run.sh debug
```

## 参数说明

| 参数 | 说明 | 默认值 |
|------|------|--------|
| `-w <cnt>` | worker 参数（本脚本会忽略） | - |
| `profile` | 构建 profile | release |

> 注意：`-w` 参数仅为保持与其他 benchmark 脚本接口一致，本脚本不使用。

## 执行流程

1. 初始化 release 环境
2. 清理旧数据
3. 生成高速 nginx 样本（800 万行，200 万行/秒）
4. 生成高速 benchmark 样本（800 万行，200 万行/秒）
5. 生成低速 nginx 样本（6000 行，1000 行/秒）

## 测试配置

脚本中的测试配置：
```bash
# 高速生成测试
LINE_CNT=8000000
SPEED_MAX=2000000
wpgen sample -n $LINE_CNT -s $SPEED_MAX --stat 2 -p --wpl ./models/wpl/nginx
wpgen sample -n $LINE_CNT -s $SPEED_MAX --stat 2 -p --wpl ./models/wpl/benchmark

# 低速生成测试
LINE_CNT=6000
SPEED_MAX=1000
wpgen sample -n $LINE_CNT -s $SPEED_MAX --stat 2 -p --wpl ./models/wpl/nginx
```

## 性能指标

### 预期吞吐
- **无限速**：取决于 CPU 和磁盘 I/O
- **限速 200 万/秒**：稳定达到目标速率
- **限速 1000/秒**：精确控制生成速率

### 影响因素
- CPU 性能：规则复杂度影响生成速度
- 磁盘 I/O：文件写入瓶颈
- 规则复杂度：字段数量和类型

## 输出示例

```
gen 2000000
[STAT] generated: 8000000, speed: 2000000/s, elapsed: 4.0s
[STAT] generated: 8000000, speed: 2000000/s, elapsed: 4.0s
gen 1000
[STAT] generated: 6000, speed: 1000/s, elapsed: 6.0s
```

## 常见问题

### Q1: 生成速度未达到限速值
- 检查 CPU 使用率是否已满
- 检查磁盘 I/O 是否瓶颈
- 考虑降低规则复杂度

### Q2: 内存占用过高
- 减少并行度（`parallel` 参数）
- 分批生成数据

### Q3: 生成数据格式错误
- 检查 WPL gen_rule.wpl 规则
- 使用 `wpkit` 验证规则语法

## 与其他基准测试的关系

| 脚本 | wpgen 使用 | wparse 使用 |
|------|------------|-------------|
| wpgen_test | 专门测试 | 不使用 |
| wpls_test | 生成数据 | 多 worker 测试 |
| file_blackhole | 生成数据 | batch 测试 |
| tcp_blackhole | 生成+发送 | daemon 测试 |

## 相关文档
- [Benchmark 总览](../README.md)
- [wpgen 使用指南](../../wp-docs/10-user/02-config/06-wpgen.md)
