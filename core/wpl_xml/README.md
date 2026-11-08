# WPL XML (`xml(...)`)

This example demonstrates the `xml(...)` structured type: it parses an XML document into
fields **by element path**, so the result does not depend on element order and missing
elements are skipped silently.

> Requires `wparse >= 0.36.0` (wp-lang 0.9). Older binaries do not know the `xml` type.

## Why this matters

Vendor logs often embed an XML document inside a JSON field — for example the Sangfor probe
(`wp-labs/warp-parse#373`) puts all interesting fields in `result`:

```json
{"logtype":"ips","src_ip":"172.16.1.2","result":"<?xml version=\"1.0\"?>\n<root>\n  <url>...</url>\n  <status_code>302</status_code>\n</root>"}
```

Before `xml(...)` the only option was a positional chain of separator patterns
(`_{*<url>}, chars:u{</}, ...`), which breaks as soon as the device reorders or omits an
element. `xml(...)` matches by path instead, so vendor version differences no longer break the
rule.

## What this case validates

| Feature | Description |
|---------|-------------|
| Element-path matching | `chars@url`, `chars@packet/sip` — order independent |
| Missing elements | Absent elements simply produce no field (no parse failure) |
| Typed subfields | `digit@status_code` yields an integer field |
| Undeclared elements | Emitted as `chars` by default; `_@key` drops them |
| JSON-embedded XML | `chars@result \| json_unescape() \| (xml(...))` |
| Raw XML lines | `xml(...)` works on a whole-line XML document too |
| Entity decoding | `&lt;` / `&amp;` / `&#xNN;` are decoded |

## Rules

`models/wpl/xml_demo/parse.wpl`:

```wpl
package /xml_demo {
    #[tag(log_desc: "深信服探针-IPS 告警(result 内嵌 XML)", log_type: "sangfor_probe_ips")]
    rule sangfor_probe_ips {
        (
            json(
                chars@logtype,
                ip@src_ip,
                chars@result | json_unescape() | (
                    xml(
                        chars@url:res_url,
                        chars@user_agent:res_user_agent,
                        digit@status_code:res_status_code,
                        _@vxlan_vni_1,
                    )
                )
            ) | f_chars_has(logtype, ips)
        )
    }

    #[tag(log_desc: "原始 XML 告警文档", log_type: "xml_alert")]
    rule xml_alert {
        (
            xml(
                chars@alert_id:id,
                ip@src_ip:src,
                ip@dst_ip:dst,
                digit@severity,
                chars@rule:rule_name,
            )
        )
    }
}
```

Notes:

- `json` gives subfields the **JSON-escaped** text, so `json_unescape()` must run before
  `xml(...)`.
- Inner fields use a `res_` prefix so they do not collide with top-level JSON keys.
- `_@vxlan_vni_1` drops an element that the rule does not need; without it the element would
  be emitted as `chars`.

## Input

`models/wpl/xml_demo/sample.dat`, replayed by `wpgen` in a 4-line rotation:

```
JSON, elements in order        -> sangfor_probe_ips
JSON, elements reordered,
      status_code missing      -> sangfor_probe_ips
raw XML, elements in order     -> xml_alert
raw XML, elements reordered    -> xml_alert
```

## Expected result

2000 lines = 500 rotations:

| Sink | Lines | Ratio |
|------|-------|-------|
| `sangfor_ips.dat` | 1000 | 0.50 |
| `xml_alert.dat` | 1000 | 0.50 |
| `default` / `error` / `miss` / `residue` | 0 | — |

A sample record:

```
{ logtype: "ips" res_url: "172.16.8.248/****/aa.php?anp=***"
  res_user_agent: "Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.1)"
  res_status_code: 302 src_ip: "172.16.1.2" ... }
```

The reordered line produces the same fields with `status_code` absent instead of 0/error.

## Quick start

```bash
cd core/wpl_xml
./run.sh
```

`run.sh` also spot-checks the parsed values (`res_url`, integer `res_status_code`, reordered
documents, dropped `vxlan_vni_1`) in addition to `wpadm data validate`.

## Semantics reference

- Elements are matched by path; the document root element is transparent
  (`<root><url>x</url></root>` → `url`).
- Paths can nest: `chars@packet/sip`.
- Missing elements are skipped; empty elements are treated as missing for non-`chars` types.
- Undeclared elements are emitted as `chars`; `_@key` drops one.
- Repeated same-name siblings keep the path for the first one and use `path/[i]` afterwards.
- Entities are decoded; namespace prefixes are ignored; a leading BOM is skipped.
- Only the first root element is consumed — XML *fragments* (`<a/><b/>`) expose only the first.

## Files

```
wpl_xml/
├── conf/
│   ├── wparse.toml            # main config (models / topology / workers)
│   └── wpgen.toml             # sample replay config
├── models/wpl/xml_demo/
│   ├── parse.wpl              # JSON-embedded XML + raw XML rules
│   └── sample.dat             # 4-line replay template
├── topology/
│   ├── sources/file_1.toml    # text file source
│   └── sinks/
│       ├── defaults.toml      # global expectation basis
│       ├── business.d/        # one sink per rule, 50/50 expectations
│       └── infra.d/           # default / error / miss / monitor / residue
└── run.sh
```

## FAQ

**Why `json_unescape()` before `xml(...)`?**
`json` subfields carry the escaped text (`\n`, `\"`, …); unescaping restores the original XML so
tags and quotes are intact.

**What if the vendor adds new elements?**
Nothing breaks: undeclared elements are emitted as `chars`. Drop the noisy ones with `_@key`.

**Does it handle `depict`-style escaped XML (`&lt;req_head&gt;…`)?**
Entities are decoded in place, so the field carries `<req_head>…`. Nested *documents* can be
parsed by declaring an `xml(...)` subfield; fragments expose only their first root element.

---

# WPL XML (`xml(...)`)

本用例演示 `xml(...)` 结构化类型：按**元素路径**把 XML 文档解析成字段 —— 与元素顺序无关，
缺失元素静默跳过。

> 需要 `wparse >= 0.36.0`（wp-lang 0.9）；更早的二进制不认识 `xml` 类型。

## 为什么需要它

厂商日志常把 XML 塞在 JSON 字段里，例如深信服探针（`wp-labs/warp-parse#373`）把关键信息全放在
`result`：

```json
{"logtype":"ips","src_ip":"172.16.1.2","result":"<?xml version=\"1.0\"?>\n<root>\n  <url>...</url>\n  <status_code>302</status_code>\n</root>"}
```

在 `xml(...)` 之前只能用一串位置相关的分隔符模式（`_{*<url>}, chars:u{</}, ...`），设备一旦调整
元素顺序或省掉某个元素，规则就失效。`xml(...)` 改为按路径匹配，厂商版本差异不再破坏规则。

## 验证的能力

| 能力 | 说明 |
|------|------|
| 元素路径匹配 | `chars@url`、`chars@packet/sip`，与先后顺序无关 |
| 缺失元素 | 没有的元素就不产出字段，不会导致解析失败 |
| 子字段类型 | `digit@status_code` 产出整数 |
| 未声明元素 | 默认按 `chars` 输出，`_@key` 可丢弃 |
| JSON 内嵌 XML | `chars@result \| json_unescape() \| (xml(...))` |
| 整行 XML | `xml(...)` 也直接解析整行 XML 文档 |
| 实体解码 | `&lt;` / `&amp;` / `&#xNN;` 自动还原 |

## 规则

`models/wpl/xml_demo/parse.wpl`（完整内容见文件）：

- `sangfor_probe_ips`：JSON 的 `result` 先 `json_unescape()` 还原，再交给 `xml(...)`；
  `res_` 前缀避免和外层 JSON 字段冲突，`_@vxlan_vni_1` 丢弃用不到的元素。
- `xml_alert`：整行就是 `<alert>...</alert>`，直接按路径取 `alert_id` / `src_ip` /
  `dst_ip` / `severity` / `rule`。

## 输入

`models/wpl/xml_demo/sample.dat` 由 `wpgen` 按 4 行一轮回放：

```
JSON，元素顺序正常            -> sangfor_probe_ips
JSON，元素乱序且缺 status_code -> sangfor_probe_ips
原始 XML，元素顺序正常         -> xml_alert
原始 XML，元素乱序            -> xml_alert
```

## 期望结果

2000 行 = 500 轮：

| Sink | 行数 | 占比 |
|------|------|------|
| `sangfor_ips.dat` | 1000 | 0.50 |
| `xml_alert.dat` | 1000 | 0.50 |
| `default` / `error` / `miss` / `residue` | 0 | — |

单条输出示例：

```
{ logtype: "ips" res_url: "172.16.8.248/****/aa.php?anp=***"
  res_user_agent: "Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.1)"
  res_status_code: 302 src_ip: "172.16.1.2" ... }
```

乱序那条产出的字段相同，只是没有 `status_code`（缺失即不产出，不会报错或变成 0）。

## 快速开始

```bash
cd core/wpl_xml
./run.sh
```

`run.sh` 除了 `wpadm data validate`，还会 spot-check 解析结果（`res_url`、整数
`res_status_code`、乱序文档、被丢弃的 `vxlan_vni_1`）。

## 语义速查

- 元素按路径匹配；文档根元素透明（`<root><url>x</url></root>` → `url`）。
- 支持嵌套路径：`chars@packet/sip`。
- 缺失元素跳过；空元素对非 `chars` 类型按缺失处理。
- 未声明元素按 `chars` 输出；`_@key` 丢弃。
- 重复同名兄弟元素：首个保留原路径，后续命名为 `path/[i]`。
- 实体自动解码；忽略命名空间前缀；跳过 BOM。
- 只消费第一个根元素 —— XML 片段（`<a/><b/>`）只暴露第一个。

## 目录结构

```
wpl_xml/
├── conf/                      # wparse.toml / wpgen.toml
├── models/wpl/xml_demo/       # parse.wpl + sample.dat
├── topology/                  # sources + sinks（business.d / infra.d）
└── run.sh
```

## 常见问题

**为什么 `xml(...)` 前面要 `json_unescape()`？**
`json` 子字段拿到的是转义文本（`\n`、`\"` 等），不还原会把转义序列带进 XML，导致标签/引号解析异常。

**厂商新增元素会怎样？**
不会失败：未声明元素按 `chars` 输出；不需要的用 `_@key` 丢掉。

**`depict` 那种实体转义的 XML 能解析吗？**
实体已在字段内解码（`&lt;req_head&gt;` → `<req_head>`）。嵌套文档可以声明 `xml(...)` 子字段继续解析，
但片段形式（多个并列根元素）只暴露第一个。
