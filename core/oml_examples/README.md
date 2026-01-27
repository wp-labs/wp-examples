# oml_examples

本用例演示"OML（Object Modeling Language）转换"的多种场景：通过丰富的 OML 示例展示数据转换、字段映射、条件匹配、知识库查询等高级特性。适用于学习 OML 语法与最佳实践。

## 目录结构

```
core/oml_examples/
├── README.md                    # 本说明文档
├── run.sh                       # 一键运行脚本
├── conf/                        # 配置文件目录
│   ├── wparse.toml             # WarpParse 主配置
│   └── wpgen.toml              # 数据生成器配置
├── models/                      # 规则与模型目录
│   ├── oml/                    # OML 转换模型
│   │   ├── csv_example.oml     # CSV 数据处理与条件匹配
│   │   ├── skyeye_stat.oml     # 系统监控数据转换
│   │   └── work_case.oml       # 工作案例数据处理
│   ├── knowledge/              # 知识库数据
│   │   ├── knowdb.toml         # 知识库主配置
│   │   ├── address/            # 地址信息知识库
│   │   │   ├── create.sql      # 建表语句
│   │   │   ├── data.csv        # 地址数据
│   │   │   └── insert.sql      # 插入语句
│   │   ├── example/            # 示例数据知识库
│   │   │   ├── create.sql      # 建表语句
│   │   │   ├── data.csv        # 示例数据
│   │   │   └── insert.sql      # 插入语句
│   │   └── example_score/      # 分数数据知识库
│   │       ├── create.sql      # 建表语句
│   │       ├── data.csv        # 分数数据
│   │       └── insert.sql      # 插入语句
│   ├── sinks/                  # 数据汇配置
│   │   ├── defaults.toml       # 默认配置
│   │   ├── business.d/         # 业务路由配置
│   │   │   ├── csv_example.toml # CSV 示例输出
│   │   │   ├── skyeye_stat.toml # 系统监控输出
│   │   │   └── work_case.toml   # 工作案例输出
│   │   └── infra.d/            # 基础设施配置
│   │       ├── default.toml    # 默认数据汇
│   │       ├── error.toml      # 错误数据处理
│   │       ├── miss.toml       # 缺失数据处理
│   │       ├── monitor.toml    # 监控数据处理
│   │       └── residue.toml    # 残留数据处理
│   ├── sources/                # 数据源配置（空）
│   └── wpl/                    # WPL 解析规则（空）
├── data/                        # 运行数据目录
│   ├── in_dat/                  # 输入数据目录
│   ├── out_dat/                 # 输出数据目录
│   │   ├── csv_example.dat     # CSV 处理结果
│   │   ├── skyeye_adm.json     # SkyEye ADM 输出
│   │   ├── skyeye_pdm.json     # SkyEye PDM 输出
│   │   └── work_case.json      # 工作案例输出
│   └── logs/                    # 日志文件目录
│       ├── gen.dat             # 生成的样本数据
│       └── *.log               # 各类日志文件
└── .run/                        # 运行时数据目录
```

## 快速开始

### 运行环境要求

- WarpParse 引擎（需在系统 PATH 中）
- Bash shell 环境

### 运行命令

```bash
# 进入用例目录
cd core/oml_examples

# 运行完整流程（默认生成 3000 条测试数据）
./run.sh
```

## 执行逻辑

### 流程概览

`run.sh` 脚本执行以下主要步骤：

1. **环境初始化**
   - 保留必要的配置文件（wparse.toml, wpgen.toml）
   - 清理历史运行数据
   - 创建必要的目录结构
   - 初始化知识库数据

2. **服务检查**
   - 使用 `wproj check` 验证配置和模型
   - 确保所有依赖项正常

3. **数据清理**
   - 清空输入输出数据目录
   - 重置日志文件
   - 清理生成器缓存

4. **生成样本数据**
   - 使用 `wpgen sample` 生成测试数据
   - 数据包含 CSV、JSON 等多种格式
   - 模拟真实的业务场景数据

5. **执行数据解析**
   - 启动 WarpParse 批处理模式
   - 加载 OML 模型进行数据转换
   - 应用知识库查询增强数据

6. **验证输出结果**
   - 统计各输出文件的数据量
   - 验证数据转换的正确性
   - 检查知识库查询结果

### 数据流向

```
生成数据 (data/logs/gen.dat)
    ↓
WarpParse OML 引擎
    ↓
┌─────────────┬─────────────┬─────────────┐
│ csv_example │ skyeye_stat │ work_case   │
│    处理     │    转换     │    解析     │
└─────────────┴─────────────┴─────────────┘
    ↓             ↓             ↓
┌─────────────┬─────────────┬─────────────┐
│csv_example  │skyeye_adm   │work_case    │
│    .dat     │  .json      │   .json     │
└─────────────┴─────────────┴─────────────┘
              └─────────────┘
                skyeye_pdm
                  .json
```

## OML 示例详解

### 1. csv_example.oml - CSV 数据处理与条件匹配

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

**特性演示**：
- **时间戳生成**：`Time::now()` 获取当前时间
- **范围匹配**：`in (digit(1), digit(3))` 匹配数值范围
- **元组匹配**：`(read(city), read(count))` 多字段联合匹配
- **否定匹配**：`!chars(warp)` 排除特定值
- **可选字段**：`take(option:[severity])` 处理可选字段
- **知识库查询**：`select ... from ... where` 动态查询数据
- **透传字段**：`* = take()` 保留所有未处理字段

### 2. skyeye_stat.oml - 系统监控数据转换

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

**特性演示**：
- **常量赋值**：`chars(wparse)`、`ip(127.0.0.1)` 固定值
- **格式化字符串**：`fmt()` 模板字符串
- **嵌套对象**：`object { ... }` 创建结构化数据
- **字段收集**：`collect take(keys: [*time*])` 动态收集字段
- **管道处理**：`pipe ... | base64_en` 数据流处理

### 3. work_case.oml - 工作案例数据处理

```oml
name : work_case
rule : work_case/*
---
agent_id   = take() ;
symbol     = take() ;
botnet     = take() ;

# 条件分支处理
symbol: chars = match read(symbol) {
    chars(web_cve) => chars(Web漏洞);
    chars(os_cve)  => chars(系统漏洞);
    _              => read(symbol);
};

# 动态路径收集
path_list = collect read(keys: [details*path]) ;

# 透传剩余字段
* = take() ;
```

**特性演示**：
- **简单字段提取**：基础的数据提取
- **条件替换**：基于值的字段映射
- **通配符收集**：`[details*path]` 模糊匹配收集
- **剩余字段处理**：保留所有未定义字段

## 配置说明

### 主配置文件 (conf/wparse.toml)

```toml
version = "1.0"
robust = "normal"

[models]
wpl = "./models/wpl"
oml = "./models/oml"
sources = "./models/sources"
sinks = "./models/sinks"

[performance]
rate_limit_rps = 500000   # 高速率限制，适合批处理
parse_workers = 2         # 解析工作线程数

[rescue]
path = "./data/rescue"

[log_conf]
level = "warn,ctrl=info,launch=info,source=info,sink=info,stat=info,runtime=warn,oml=warn,wpl=warn,klib=warn,orion_error=error,orion_sens=warn"
output = "File"

[stat]
window_sec = 60
```

### 数据生成器配置 (conf/wpgen.toml)

```toml
[generator]
mode = "sample"          # 使用预定义样本
count = 1000            # 生成数据条数
speed = 1000            # 生成速度（条/秒）
parallel = 1            # 并发数

[output]
connect = "file_raw_sink"

[output.params]
base = "data/in_dat"
file = "gen.dat"

[log_conf]
level = "info"
output = "File"
```

### 知识库配置 (models/knowledge/knowdb.toml)

```toml
version = "2.0"

[default]
transaction = true       # 启用事务
batch_size = 2000       # 批处理大小

[csv]
has_header = true       # CSV 包含表头
delimiter = ","         # 分隔符
encoding = "utf-8"      # 编码

[table.example_score]
mapping = "header"      # 按表头映射
range = "5,110"         # 数据行范围

[table.address]
mapping = "index"       # 按索引映射
range = "5,110"         # 数据行范围
```

### 业务 Sink 配置示例 (models/sinks/business.d/csv_example.toml)

```toml
version = "2.0"

[sink]
name = "csv_example"
type = "file_csv_sink"
connect = "csv_sink"

[sink.params]
base = "data/out_dat"
file = "csv_example.dat"

[sink.expect]
basis = "total_input"
ratio = 0.7              # 期望 70% 的数据进入此 sink
deviation = 0.01         # 允许 1% 的偏差
```

## 验证

### 运行成功验证

1. **输出文件统计**
   ```bash
   wproj data stat
   ```

2. **验证数据完整性**
   ```bash
   wproj data validate
   ```

3. **查看输出样例**
   ```bash
   # CSV 输出
   head -20 data/out_dat/csv_example.dat

   # JSON 输出
   jq . data/out_dat/skyeye_adm.json | head -40
   ```


### 使用不同的输出格式

配置不同的 Sink 类型：

- **JSON 输出**：`type = "file_json_sink"`
- **CSV 输出**：`type = "file_csv_sink"`
- **KV 输出**：`type = "file_kv_sink"`
- **原始输出**：`type = "file_raw_sink"`

*本文档最后更新时间：2025-12-16*
