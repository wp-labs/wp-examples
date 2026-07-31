# WPL Pipe

This example demonstrates WPL pipeline preprocessing for handling encoded or escaped data before parsing.

## Purpose

Validate the ability to:
- Preprocess input data with pipeline operations before parsing
- Decode Base64 encoded content
- Handle quoted and escaped strings
- Chain multiple preprocessing operations

## Features Validated

| Feature | Description |
|---------|-------------|
| Pipeline Syntax | `\|操作\|` prefix for preprocessing |
| Base64 Decoding | `decode/base64` operation |
| Unquote/Unescape | `unquote/unescape` for quoted strings |
| Trim | `trim` for whitespace removal |
| Operation Chaining | Left-to-right operation execution |

## Pipeline Operations

| Operation | Input | Output |
|-----------|-------|--------|
| `decode/base64` | `eyJhIjogMX0=` | `{"a": 1}` |
| `unquote/unescape` | `"{ \"a\": 1 }"` | `{ "a": 1 }` |
| `trim` | `  data  ` | `data` |

## WPL Syntax Example

```wpl
package /pipe_demo {
    rule fmt_from_base64 {
        // 1) Base64 decode
        // 2) Unquote and unescape
        // 3) Parse JSON
        |decode/base64|unquote/unescape|(json(_@_origin))
    }
}
```

## Quick Start

```bash
cd core/wpl_pipe
./run.sh
```

---

# wpl_pipe (中文)

本用例演示"WPL 管道预处理"的场景：在正式解析前，通过管道操作对输入数据进行预处理（如 Base64 解码、引号转义还原等），然后再进行 JSON 或其他格式的解析。适用于处理编码、转义等复杂格式的日志数据。

## 目录结构
- `conf/`：配置目录
  - `conf/wparse.toml`：主配置
- `models/`：规则与路由
  - `models/wpl/pipe_demo/`：管道处理规则
    - `parse.wpl`：解析规则（含管道预处理）
  - `models/sinks/business.d/`：业务路由
  - `models/sinks/infra.d/`：基础组
  - `models/sources/wpsrc.toml`：源配置
- `data/`：运行数据目录

## WPL 管道语法

### 管道操作符
在规则开头使用 `|操作|` 定义预处理管道：
```wpl
rule example {
    |操作1|操作2|...|( 解析规则 )
}
```

### 常用管道操作
- `decode/base64`：Base64 解码
- `unquote/unescape`：去除外层引号并还原转义字符
- `trim`：去除首尾空白

## 解析规则示例

### parse.wpl
```wpl
package /pipe_demo {
   #[copy_raw(name : "_origin")]
   rule fmt_from_quote {
        // 输入: "{ \"a\": 1, \"b\": \"foo\" }"
        // 1) 去除外层引号并还原内部转义引号
        // 2) 解析根级 JSON 为字段
        |unquote/unescape|(json(_@_origin))
   }

   #[copy_raw(name : "_origin")]
    rule fmt_from_base64 {
        // 输入: base64("{ \"a\": 2, \"b\": \"bar\" }")
        // 1) Base64 解码
        // 2) 去除外层引号并还原转义
        // 3) 解析 JSON 为字段
        |decode/base64|unquote/unescape|(json(_@_origin))
    }
}
```

### copy_event_parse 场景（跨包引用）

演示跨规则、跨包注解 `#[copy_event_parse(rule:"pkg/rule")]` 与 `#[no_match]` 的配合。本例中 `/pipe_demo` 包的 `fmt_from_base64` 解析完 base64+quoted JSON 后，把同一 payload 交给 `/fun` 包的 `raw_event` 再解析，产出字段并入同一条 record。

涉及两个文件（均为 `parse*.wpl`，才会被加载器扫到）：

**`models/wpl/pipe_demo/parse.wpl`**（`/pipe_demo` 包）：

```wpl
package /pipe_demo {
   #[copy_raw(name : "_origin"), copy_event_parse(rule:"/fun/raw_event")]
    rule fmt_from_base64 {
        |decode/base64| strip/bom | unquote/unescape|(json(_@_origin))
    }
}
```

**`models/wpl/pipe_demo/parse_fun.wpl`**（`/fun` 包）：

```wpl
package /fun {
    #[no_match]
    rule raw_event {
        (chars\0)
    }
}
```

| 规则 | 注解 | 作用 |
|------|------|------|
| `fmt_from_base64` (`/pipe_demo`) | `#[copy_event_parse(rule:"/fun/raw_event")]` | base64 解码 + 去引号 + 解析 JSON；同时把同一 payload 交给 `/fun/raw_event` 再解析，产出字段并入同一条 record |
| `raw_event` (`/fun`) | `#[no_match]` | 仅作 `copy_event_parse` 的显式调用目标，不参与 `parse_event` 自动匹配 |

处理流程：

1. 事件进入 `parse_event`，`fmt_from_base64` 命中（`raw_event` 标了 `#[no_match]`，不在自动匹配集合里）。
2. `fmt_from_base64` 按管道解码并解析 JSON → 字段 `_origin`。
3. `copy_event_parse` 把同一 payload 喂给 `/fun/raw_event` 的 parser → 解析 `chars\0` → 产出字段，并入当前 record。
4. 最终 record 含 `fmt_from_base64` 与 `raw_event` 两边产出的字段。

> **跨包引用约定**：`copy_event_parse` 的 `rule` 用 `pkg/rule` 全路径（如 `/fun/raw_event`）。同包裸名（如 `raw_event`）也可用，引擎会按 `当前包/裸名` 回退解析。引用不存在的 rule 是逻辑错误，引擎拒绝启动。
>
> **文件加载约定**：加载器只扫 `parse*.wpl`（见 `WPARSE_RULE_FILE`），一个 `.wpl` 文件声明一个 package。`/fun` 包因此单独放在 `parse_fun.wpl`，而不是和 `/pipe_demo` 挤在 `parse.wpl` 里。
>
> `#[no_match]` 是显式声明：标了它的 rule 不会被 `parse_event` 直接匹配，避免它抢在引用方 rule 之前产出残缺 record。其 parser 仍由引擎保留，供 `copy_event_parse` 注入调用。

### 处理流程
1. **输入**：`"eyJhIjogMX0="` (Base64 编码的 `{"a": 1}`)
2. **decode/base64**：`{"a": 1}`
3. **unquote/unescape**：`{"a": 1}` (如有引号包裹则去除)
4. **json解析**：提取 `a=1`

## 快速使用

### 构建项目
```bash
cargo build --workspace --all-features
```

### 运行用例
```bash
cd core/wpl_pipe
./run.sh
```

脚本执行流程：
1. 初始化环境与配置
2. 生成 Base64/转义格式的样本数据
3. 运行 wparse 批处理解析
4. 校验输出统计

### 手动执行
```bash
# 初始化配置
wpadm check
wpadm data clean
wpgen data clean

# 生成样本数据（Base64+引号转义 JSON）
wpgen sample -n 1000 --stat 2

# 运行批处理解析
wparse batch --stat 2 -S 1 -p -n 1000

# 校验输出
wpadm data stat
wpadm data validate
```

## 可调参数
- `LINE_CNT`：生成行数（默认 1000）
- `STAT_SEC`：统计间隔秒数（默认 2）

## 管道操作详解

### decode/base64
将 Base64 编码的字符串解码为原始内容：
```
输入: eyJhIjogMX0=
输出: {"a": 1}
```

### unquote/unescape
处理带引号和转义的字符串：
```
输入: "{ \"a\": 1, \"b\": \"hello\" }"
输出: { "a": 1, "b": "hello" }
```

转义字符处理：
- `\"` → `"`
- `\\` → `\`
- `\n` → 换行
- `\t` → 制表符

### 组合使用
多个管道操作从左到右依次执行：
```wpl
|decode/base64|unquote/unescape|(...)
```

## 注解说明

### copy_raw
`#[copy_raw(name : "_origin")]` 注解用于保留原始输入：
- 将原始输入复制到 `_origin` 字段
- 便于后续审计或调试

## 常见问题

### Q1: Base64 解码失败
- 确认输入是有效的 Base64 编码
- 检查是否有 URL 安全 Base64（需要不同的解码器）
- 查看 `data/logs/wparse.log` 中的错误信息

### Q2: 转义还原不完整
- 确认转义格式与 `unquote/unescape` 支持的格式一致
- 某些特殊转义可能需要自定义处理

### Q3: 管道顺序错误
- 管道从左到右执行
- 先解码（decode）再去引号（unquote）

## 相关文档
- [WPL 管道](../../wp-docs/10-user/06-wpl/README.md)
- [WPL 语法](../../wp-docs/10-user/06-wpl/02-wpl_grammar.md)
- [前置处理](../../wp-docs/10-user/06-wpl/README.md)
