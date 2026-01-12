# knowdb_case 

本用例演示"知识库（KnowDB）查询与数据关联"的场景：通过 WPL 规则解析日志后，使用 OML 中的 `select ... from ... where` 语句从知识库中查询关联数据，实现日志解析与业务数据的动态关联。

## 目录结构
- `conf/`：配置目录
  - `conf/wpgen.toml`：数据生成器配置（UDP syslog 输出）
- `models/`：规则与路由
  - `models/wpl/example/`：WPL 解析规则（nginx 日志解析）
  - `models/knowledge/example/`：知识库数据（CSV 格式）
  - `models/sinks/business.d/`：业务路由
  - `models/sinks/infra.d/`：基础组
  - `models/sources/wpsrc.toml`：源配置（UDP syslog）
- `data/`：运行数据目录
  - `data/in_dat/`：输入数据
  - `data/out_dat/`：sink 输出
  - `data/logs/`：日志目录

## 知识库配置

### 知识库表定义 (models/knowledge/example/)
```
models/knowledge/example/
├── create.sql     # 表结构定义
├── data.csv       # 数据文件
└── insert.sql     # 数据插入语句
```

示例数据 (data.csv)：
```csv
name,pinying
令狐冲,linghuchong
任盈盈,renyingying
```

### 知识库配置 (models/knowledge/knowdb.toml)
定义知识库的加载路径与表映射关系。

## WPL 解析规则

### 解析规则 (models/wpl/example/parse.wpl)
```wpl
package /example {
  #[tag(from_dc: "warplog/cs/nginx")]
  rule nginx {
    (ip:sip,_^2,time<[,]>,http/request",http/status,digit,chars",http/agent",_")
  }
}
```
