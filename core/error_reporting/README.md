# error_reporting

本用例演示"错误数据报表与多格式输出"的场景：针对 skyeye_stat 类型的系统监控日志进行解析，通过 OML 进行数据转换，并支持多种输出格式（JSON、KV 等）。适用于错误数据的收集、分析与报表生成。

## 目录结构
- `conf/`：配置目录
  - `conf/wparse.toml`：主配置
  - `conf/wpgen.toml`：数据生成器配置
- `models/`：规则与路由
  - `models/wpl/skyeye_stat/`：skyeye_stat 解析规则
  - `models/wpl/example/simple/`：示例解析规则
  - `models/oml/skyeye_stat.oml`：OML 转换模型
  - `models/sinks/business.d/`：业务路由
  - `models/sinks/infra.d/`：基础组
  - `models/sources/wpsrc.toml`：源配置
- `data/`：运行数据目录

## WPL 解析规则

### skyeye_stat 规则 (models/wpl/skyeye_stat/parse.wpl)
解析 skyeye 系统监控日志，提取 CPU、内存、磁盘等系统指标：
```wpl
package skyeye_stat {
   #[copy_raw(name:"raw_msg")]
   rule case1 {
        (digit<<,>>, digit, symbol(skyeye), _,
         time:updatetime\|\!, ip:sip\|\!, chars:log_type\|\![),
         some_of (
             json( symbol(空闲CPU百分比)@name, @value:cpu_free),
             json( symbol(空闲内存kB)@name, @value:memory_free),
             json( symbol(1分钟平均CPU负载)@name, @value:cpu_used_by_one_min),
             // ... 更多指标
         )\,
    }
}
```

## OML 转换模型

### skyeye_stat.oml
对解析后的数据进行二次转换与增强：
```oml
name : skyeye_stat
rule : skyeye_stat/*
---
src_key     : chars =  take() ;
recv_time   : time  = Time::now() ;
pos_sn      : chars =  take() ;
updatetime  : time  =  take() ;
sip         : chars =  take() ;
log_type    : chars =  take() ;
cust_tag    : chars = fmt("[{pos_sn}-{sip}]", @pos_sn, @sip ) ;

value  : obj = object {
  process,memory_free : float =  take() ;
  cpu_free,cpu_used_by_one_min, cpu_used_by_fifty_min : float =  take() ;
  disk_free,disk_used,disk_used_by_one_min, disk_used_by_fify_min : float =  take() ;
} ;

time_all : array = collect  take( keys : [ *time* ] ) ;
raw_msg : chars =  pipe take() | base64_en ;
```

## 快速使用

### 构建项目
```bash
cargo build --workspace --all-features
```

### 运行用例
```bash
cd core/error_reporting
./run.sh
```

脚本执行流程：
1. 初始化环境与配置（保留 conf 以加载自定义配置）
2. 使用 wpgen 生成样本数据
3. 运行 wparse 批处理解析
4. 校验输出统计

### 手动执行
```bash
# 初始化配置
wproj check
wproj data clean
wpgen data clean

# 生成样本数据
wpgen sample -n 3000 --stat 3

# 运行批处理解析
wparse batch --stat 3 -p -n 3000

# 校验输出
wproj data stat
wproj data validate
```

## 可调参数
通过环境变量覆盖：
- `LINE_CNT`：生成行数（默认 3000）
- `STAT_SEC`：统计间隔秒数（默认 3）

## 业务组配置

### skyeye_stat 业务组 (models/sinks/business.d/skyeye_stat.toml)
支持多种输出格式：
- JSON 格式输出
- KV 格式输出

## OML 特性演示
本用例展示了以下 OML 特性：
- `take()`：从解析结果中提取字段
- `Time::now()`：获取当前时间
- `fmt()`：字符串格式化
- `object {}`：创建嵌套对象
- `collect`：收集匹配字段
- `pipe ... | base64_en`：管道处理与 Base64 编码

## 常见问题

### Q1: 解析失败
- 确认输入数据格式符合 WPL 规则定义
- 查看 `data/logs/wparse.log` 中的详细错误信息
- 检查 `some_of` 中的可选字段是否正确匹配

### Q2: OML 转换失败
- 确认 OML 中 `rule` 匹配的 WPL package 路径正确
- 确认字段名与 WPL 解析结果一致

## 相关文档
- [OML 基础](../../wp-docs/10-user/07-oml/01-oml_basics.md)
- [OML 示例](../../wp-docs/10-user/07-oml/02-oml_examples.md)
- [WPL 语法](../../wp-docs/10-user/06-wpl/02-wpl_grammar.md)
