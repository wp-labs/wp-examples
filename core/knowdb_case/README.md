# knowdb_case 场景说明

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

### 生成规则 (models/wpl/example/gen_rule.wpl)
用于 wpgen 生成测试样本数据的规则。

## 快速使用

### 构建项目
在仓库根目录：
```bash
cargo build --workspace --all-features
```

### 运行用例
```bash
cd core/knowdb_case
./run.sh
```

脚本执行流程：
1. 初始化环境与配置
2. 启动 wparse（UDP syslog 接收）
3. 使用 wpgen 生成样本数据并发送
4. 停止服务并校验输出

### 手动执行
```bash
# 初始化配置
wproj check

# 清理数据
wproj data clean
wpgen data clean

# 启动解析服务（后台）
wparse daemon --stat 2 --print_stat &

# 生成并发送样本（UDP syslog）
wpgen rule -n 1000 -s 200

# 停止服务
kill $(cat ./.run/wparse.pid)

# 校验输出
wproj data stat
wproj data validate --input-cnt 1000
```

## 可调参数
通过环境变量覆盖：
- `LINE_CNT`：生成行数（默认 1000）
- `STAT_SEC`：统计间隔秒数（默认 2）
- `GEN_SPEED`：生成速率（默认 200，降低 UDP 丢包）

## 常见问题

### Q1: 知识库加载失败
- 确认 `models/knowledge/knowdb.toml` 配置正确
- 确认 CSV 数据格式与 `create.sql` 表结构一致
- 查看 `data/logs/wparse.log` 中的错误信息

### Q2: UDP 丢包
- 适当降低 `GEN_SPEED` 参数
- 增加预热时间（脚本中的 `sleep 1`）
- 检查系统 UDP 缓冲区配置

### Q3: 数据关联失败
- 确认 OML 中的 `select` 语句字段与知识库表字段一致
- 确认 `where` 条件中的字段在 WPL 解析结果中存在

## 相关文档
- [知识库配置](../../wp-docs/10-user/02-config/07-knowdb_config.md)
- [WPL 语法](../../wp-docs/10-user/06-wpl/02-wpl_grammar.md)
- [OML 基础](../../wp-docs/10-user/07-oml/01-oml_basics.md)
