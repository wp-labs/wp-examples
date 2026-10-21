# WPL Late (`#[late]`)

This example demonstrates the `#[late]` rule annotation: a rule that still participates in
`parse_event` auto-matching, but is always tried **after** ordinary rules.

## Why this matters

WPL rules are matched in order and the **first success wins**. That order is not fixed:

- at assembly (`MultiParser::new`) rules follow declaration order, and
- after every `OPTIMIZE_TIMES` (10000) parsed events the engine re-sorts by hit count,
  descending.

A catch-all rule such as `(chars:raw\0)` matches literally everything. It therefore has the
broadest possible hit surface, and once hit-count ordering kicks in it climbs to the front —
after which it swallows the whole stream and every specific rule starves. Declaring the
catch-all first makes this happen immediately, from the very first event.

`#[late]` pins the rule into a lower tier. Hit-count ordering only reorders **within** a tier,
so a `#[late]` catch-all can never be promoted above ordinary rules.

## What this case validates

| Feature | Description |
|---------|-------------|
| `#[late]` at assembly time | A `#[late]` rule declared **first** is still tried last |
| Tier isolation | Hit-count ordering never promotes a `late` rule above a normal rule |
| Normal rules keep matching | Structured rules keep their share instead of being starved |
| Counterfactual | Removing `#[late]` makes the catch-all eat 100% of the stream |

## Rules

`models/wpl/late_demo/parse.wpl` — the catch-all is deliberately declared **first**:

```wpl
package /late_demo {
    #[late]
    rule fallback_other {
        (chars:raw\0)
    }

    rule metrics_csv {
        (digit:a,digit:b,digit:c)\,
    }

    rule kv_pairs {
        (kv)
    }

    rule json_obj {
        (json(digit@a, chars@b))
    }
}
```

## Input

`models/wpl/late_demo/sample.dat` is replayed by `wpgen` in a 5-line rotation:

```
1001,2002,3003                                        -> metrics_csv
k1=v1,k2=v2,k3=v3                                     -> kv_pairs
{"a": 1, "b": "x"}                                    -> json_obj
plain text that no structured rule can parse          -> fallback_other
another free-form line with words only                -> fallback_other
```

## Expected result

With `#[late]` (2000 lines = 400 rotations):

| Sink | Lines | Ratio |
|------|-------|-------|
| `metrics.dat` | 400 | 0.20 |
| `kv.dat` | 400 | 0.20 |
| `json.dat` | 400 | 0.20 |
| `fallback.dat` | 800 | 0.40 |

Without `#[late]` (counterfactual):

| Sink | Lines |
|------|-------|
| `metrics.dat` / `kv.dat` / `json.dat` | 0 |
| `fallback.dat` | 2000 |

## Quick start

```bash
cd core/wpl_late

# Recommended configuration: #[late] keeps the fallback in the last tier
./run.sh

# Counterfactual: strip #[late] in a temporary work-root and verify it swallows everything
./compare_naive.sh

# Keep the counterfactual outputs for inspection
KEEP_NAIVE_OUT=1 ./compare_naive.sh
```

## Semantics reference

- `#[late]` is a bare flag annotation (no arguments).
- It can be written on a rule or on a `package` (every rule in the package inherits it).
- Assembly order: `(late, index)` — `late` rules last, declaration order within a tier.
- Runtime order: `(late, hit_cnt desc, index)` — hit count only reorders within a tier.
- `#[no_match]` wins over `#[late]`: a rule marked both never auto-matches at all.
- `late` guarantees "tried last", not "normal rules must fail completely": if an ordinary rule
  already consumed ≥80% of the payload it returns `Partial` right away, and `late` rules are
  never consulted.

## Files

```
wpl_late/
├── conf/
│   ├── wparse.toml            # main config (models / topology / workers)
│   └── wpgen.toml             # sample replay config
├── models/wpl/late_demo/
│   ├── parse.wpl              # the four rules, catch-all declared first + #[late]
│   └── sample.dat             # 5-line replay template
├── topology/
│   ├── sources/file_1.toml    # text file source
│   └── sinks/
│       ├── defaults.toml      # global expectation basis
│       ├── business.d/        # one sink per rule, with ratio expectations
│       └── infra.d/           # default / error / miss / monitor / residue
├── run.sh
└── compare_naive.sh
```

## FAQ

**Is `#[late]` the same as `#[no_match]`?**
No. `#[no_match]` removes the rule from auto-matching entirely (it only serves as a
`copy_event_parse` target). `#[late]` keeps it matching, just at the lowest priority.

**Why is the catch-all declared first here?**
To make the difference visible with a handful of lines. In a real package a catch-all that is
normally reached last accumulates the largest hit count over time, which is exactly what would
promote it to the front without `#[late]`.

**Does `#[late]` hurt performance?**
It only changes the sort key. `late` rules are still skipped quickly by ordinary rules that
match first, and they are last in the candidate list.

---

# wpl_late (`#[late]` 规则分层)

本用例演示 `#[late]` 注解：该规则**仍然参与** `parse_event` 的自动匹配，但永远排在普通规则**之后**尝试。

## 为什么需要它

WPL 规则按顺序匹配，**第一条成功即返回**。而这个顺序并不是固定的：

- 装配期（`MultiParser::new`）按声明顺序排列；
- 每解析满 `OPTIMIZE_TIMES`（10000）条事件，引擎按命中次数降序重排一次。

像 `(chars:raw\0)` 这样的兜底规则能匹配任何内容，命中面最广；一旦命中率排序生效，它就会爬到
队首，之后整条流都被它吃掉，所有具体规则都被饿死。如果它恰好声明在最前面，这个问题从第一条
事件就开始。

`#[late]` 把它钉在更低的层级里。命中率排序只在**层内**生效，所以标了 `#[late]` 的兜底规则
永远不会被提升到普通规则之前。

## 验证的能力

| 能力 | 说明 |
|------|------|
| 装配期分层 | 声明在**最前面**的 `#[late]` 规则依然最后才被尝试 |
| 层级隔离 | 命中率排序不会把 `late` 规则提升到普通规则之前 |
| 具体规则不被饿死 | 结构化规则保持自己的份额 |
| 反事实对照 | 去掉 `#[late]` 后，兜底规则吃掉 100% 的数据 |

## 规则

`models/wpl/late_demo/parse.wpl` —— 兜底规则**故意声明在最前面**：

```wpl
package /late_demo {
    #[late]
    rule fallback_other {
        (chars:raw\0)
    }

    rule metrics_csv {
        (digit:a,digit:b,digit:c)\,
    }

    rule kv_pairs {
        (kv)
    }

    rule json_obj {
        (json(digit@a, chars@b))
    }
}
```

## 输入

`models/wpl/late_demo/sample.dat` 由 `wpgen` 按 5 行一轮回放：

```
1001,2002,3003                                        -> metrics_csv
k1=v1,k2=v2,k3=v3                                     -> kv_pairs
{"a": 1, "b": "x"}                                    -> json_obj
plain text that no structured rule can parse          -> fallback_other
another free-form line with words only                -> fallback_other
```

## 期望结果

带 `#[late]`（2000 行 = 400 轮）：

| Sink | 行数 | 占比 |
|------|------|------|
| `metrics.dat` | 400 | 0.20 |
| `kv.dat` | 400 | 0.20 |
| `json.dat` | 400 | 0.20 |
| `fallback.dat` | 800 | 0.40 |

去掉 `#[late]`（反事实）：

| Sink | 行数 |
|------|------|
| `metrics.dat` / `kv.dat` / `json.dat` | 0 |
| `fallback.dat` | 2000 |

## 快速开始

```bash
cd core/wpl_late

# 推荐配置：#[late] 让兜底规则留在最后一层
./run.sh

# 反事实：在临时 work-root 里去掉了 #[late] 后重跑，验证它会吃掉全部事件
./compare_naive.sh

# 保留反事实产物以便人工查看
KEEP_NAIVE_OUT=1 ./compare_naive.sh
```

## 语义速查

- `#[late]` 是无参数的 flag 注解。
- 可以写在 rule 上，也可以写在 `package` 上（整包规则继承）。
- 装配顺序：`(late, index)` —— `late` 规则排最后，层内保持声明序。
- 运行期顺序：`(late, hit_cnt desc, index)` —— 命中次数只在层内生效。
- `#[no_match]` 优先于 `#[late]`：两者都标时规则完全不参与自动匹配。
- `late` 保证的是「最后尝试」，不是「普通规则必须完全失败」：普通规则若已消费 ≥80% 的 payload
  会直接返回 `Partial`，此时不会再尝试 `late` 规则。

## 目录结构

```
wpl_late/
├── conf/
│   ├── wparse.toml            # 主配置（models / topology / workers）
│   └── wpgen.toml             # 样本回放配置
├── models/wpl/late_demo/
│   ├── parse.wpl              # 4 条规则，兜底声明在最前并标了 #[late]
│   └── sample.dat             # 5 行回放模板
├── topology/
│   ├── sources/file_1.toml    # 文本文件源
│   └── sinks/
│       ├── defaults.toml      # 全局期望基准
│       ├── business.d/        # 每条规则一个 sink，带比例期望
│       └── infra.d/           # default / error / miss / monitor / residue
├── run.sh
└── compare_naive.sh
```

## 常见问题

**`#[late]` 和 `#[no_match]` 是一回事吗？**
不是。`#[no_match]` 让规则完全退出自动匹配（只作为 `copy_event_parse` 的目标）；
`#[late]` 仍然参与匹配，只是优先级最低。

**为什么把兜底规则声明在最前面？**
为了让差异在几十条数据里就能看出来。在真实工程里，一个正常只在最后被触及的兜底规则，
随时间会累积出最高的命中次数 —— 那正是没有 `#[late]` 时把它推到队首的原因。

**`#[late]` 会影响性能吗？**
它只改排序键。具体规则先命中时 `late` 规则根本不会被尝试，而且在候选列表里始终排在最后。
