# oml_examples 场景说明

本用例演示"OML（Object Modeling Language）转换"的多种场景：通过丰富的 OML 示例展示数据转换、字段映射、条件匹配、知识库查询等高级特性。适用于学习 OML 语法与最佳实践。

## 目录结构
- `conf/`：配置目录
  - `conf/wparse.toml`：主配置
  - `conf/wpgen.toml`：数据生成器配置
- `models/`：规则与路由
  - `models/oml/`：OML 转换模型
    - `skyeye_stat.oml`：系统监控数据转换
    - `csv_example.oml`：CSV 数据处理与条件匹配
  - `models/wpl/`：WPL 解析规则
  - `models/knowledge/`：知识库数据
  - `models/sinks/business.d/`：业务路由
  - `models/sinks/infra.d/`：基础组
- `data/`：运行数据目录

## OML 示例详解

### 1. skyeye_stat.oml - 系统监控转换
```oml
name : skyeye_stat
rule : skyeye_stat/*
---
vendor      = chars(wparse) ;
v_ip        = ip(127.0.0.1) ;
recv_time   = Time::now() ;
cust_tag    = fmt("[{pos_sn}-{sip}]", @pos_sn, @sip ) ;

value  = object {
  process,memory_free : float =  take() ;
  cpu_free,cpu_used_by_one_min, cpu_used_by_fifty_min : float =  take() ;
  disk_free,disk_used,disk_used_by_one_min, disk_used_by_fify_min : float =  take() ;
} ;

time_all  = collect  take( keys : [ *time* ] ) ;
raw_msg  =  pipe take() | base64_en ;
```

特性演示：
- 常量赋值：`chars(wparse)`、`ip(127.0.0.1)`
- 内置函数：`Time::now()`
- 字符串格式化：`fmt()`
- 嵌套对象：`object { ... }`
- 字段收集：`collect take( keys : [ *time* ] )`
- 管道处理：`pipe ... | base64_en`

### 2. csv_example.oml - 条件匹配与知识库查询
```oml
name: csv_example
rule : csv_example/*
---
occur_time  =  Time::now() ;
year  = take();
sid   = digit(10);

quart   = match  read(month) {
    in ( digit(1) , digit(3) )    => chars(Q1);
    in ( digit(4) , digit(6) )    => chars(Q2);
    in ( digit(7) , digit(9) )    => chars(Q3);
    in ( digit(10) , digit(12) )  => chars(Q4);
    _ => chars(Q5);
};

level  = match  ( read(city) , read(count) ) {
   ( chars(cs) , in ( digit(81) ,  digit(200) ) )    => chars(GOOD);
   ( chars(cs) , in ( digit(0) ,   digit(80) )  )   => chars(BAD);
   ( chars(bj) , in ( digit(101) , digit(200) ) )   => chars(GOOD);
   ( chars(bj) , in ( digit(0) ,   digit(100) ) )   => chars(BAD);
    _ => chars(NOR);
};

vender = match  read(product)  {
    chars(warp)   =>   chars(warp-rd)
    !chars(warp)   =>  chars(other)
};

severity: chars =  match take(option:[severity]) {
    digit(0) => chars(未知);
    digit(1) => chars(信息);
    digit(2) => chars(低危);
    digit(3) => chars(高危(漏洞));
};

math_score = select math  from example_score where id = read(sid) ;
*  = take() ;
```

特性演示：
- `match` 条件匹配：单值匹配、范围匹配、元组匹配
- `in ( ... )` 范围表达式
- `!chars()` 否定匹配
- `take(option:[...])` 可选字段提取
- `select ... from ... where` 知识库查询
- `* = take()` 透传剩余字段

## 知识库配置
本用例包含多个知识库表：
- `address`：地址信息
- `example`：示例数据
- `example_score`：分数数据

## 快速使用

### 构建项目
```bash
cargo build --workspace --all-features
```

### 运行用例
```bash
cd core/oml_examples
./run.sh
```

### 手动执行
```bash
# 初始化配置
wproj check
wproj data clean
wpgen data clean

# 生成样本数据
wpgen sample -n 3000 --stat 3

# 运行批处理解析
wparse batch --stat 2 -p -n 3000

# 校验输出
wproj data stat
wproj data validate
```

## 可调参数
- `LINE_CNT`：生成行数（默认 3000）
- `STAT_SEC`：统计间隔秒数（默认 2）
- `GEN_STAT_SEC`：生成统计间隔（默认 3）

## OML 语法要点

### 字段提取
```oml
field_name = take() ;           # 从解析结果提取
field_name = read(other_field); # 读取已定义字段
```

### 类型转换
```oml
field : chars = ... ;   # 字符串类型
field : float = ... ;   # 浮点数类型
field : time  = ... ;   # 时间类型
field : obj   = ... ;   # 对象类型
field : array = ... ;   # 数组类型
```

### 条件匹配
```oml
result = match read(field) {
    chars(value1) => chars(result1);
    chars(value2) => chars(result2);
    _ => chars(default);
};
```

### 知识库查询
```oml
score = select column from table where key = read(field);
```

## 常见问题

### Q1: match 匹配失败
- 确认 `read()` 引用的字段已在 OML 中定义或由 WPL 解析产生
- 确认匹配条件的类型与值格式正确

### Q2: 知识库查询无结果
- 确认 `from` 后的表名与 `models/knowledge/` 下的目录名一致
- 确认 `where` 条件中的字段值在知识库中存在

### Q3: 透传字段丢失
- `* = take()` 应放在 OML 最后，确保其他字段优先提取

## 相关文档
- [OML 基础](../../wp-docs/10-user/07-oml/01-oml_basics.md)
- [OML 示例](../../wp-docs/10-user/07-oml/02-oml_examples.md)
- [OML 语法 EBNF](../../wp-docs/10-user/07-oml/03-oml_grammar_ebnf.md)
- [知识库配置](../../wp-docs/10-user/02-config/07-knowdb_config.md)
