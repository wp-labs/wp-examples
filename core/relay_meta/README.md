# relay_meta — 接力链路（A → B）的 wp_* meta 语义

验证两个 wparse 实例接力时，上游已经写进数据的 `wp_*` 机制字段会被**保留**还是被**覆盖**。

## 链路

```text
A: file_src → WPL 解析 → file_json_sink         输出 JSON Lines
                              │  (含 wp_event_id / wp_src_key / wp_event_md5)
                              ▼  复制到 stage_b/data/in_dat/relay.json
B: file_src → WPL(json(...)) → file_proto_sink   再次解析，规则显式提取上游 wp_*
```

B 的规则是关键：

```wpl
rule b_rec {
    (json(@wp_event_id,@wp_src_key,@wp_event_md5,@data_type))
}
```

只有把上游字段**显式提取出来**，引擎才会发现「记录里已有该 meta」，进而按开关决定保留还是覆盖；规则不提就自然走本阶段逻辑（生成新 ID、写本实例 source）。

## 四个开关

| 开关 | 默认 | 范围 | `false` 时 |
| --- | --- | --- | --- |
| `UPSTREAM_EVENT_ID_KEEP` | `true` | `wp_event_id` | 本实例重新发号（用自己的 lane） |
| `UPSTREAM_SRC_KEEP` | `true` | `wp_src_key` / `wp_src_ip` | 用本实例的 source key / 对端 IP 覆盖 |
| `UPSTREAM_EVENT_MD5_KEEP` | `true` | `wp_event_md5` | 用本实例收到的 payload 重算 |
| `UPSTREAM_OML_NAME_KEEP` | `false` | `wp_oml_name` | —（见下） |

## 断言

| 步骤 | 验证内容 |
| --- | --- |
| 1 | 阶段 A 正常产出 JSON Lines |
| 2 | 默认配置下 B **沿用**上游的 `wp_event_id` / `wp_src_key`(=`file_1`) / `wp_event_md5`，且每条记录里每个字段**只有一个**（无重复追加） |
| 3 | `UPSTREAM_EVENT_ID_KEEP=false` → B 的 ID 与 A **完全不相交**，且 lane = `WP_INS_ID - 100` |
| 4 | `UPSTREAM_SRC_KEEP=false` → `wp_src_key` 变成本实例的 `file_b`，但 ID 仍沿用 |
| 5 | `UPSTREAM_EVENT_MD5_KEEP=false` → md5 与上游不同（B 重算了 A 那一行 JSON 的 md5） |

## 运行

```bash
./run.sh
# 调大记录数
LINE_CNT=200 ./run.sh
```

## 为什么没覆盖 `wp_oml_name`

`wp_oml_name` 由 sink 层注入，只有 sink 组配置了 OML 模型（`oml = [...]`）时才出现；本用例两个阶段都用 `oml = []`，所以看不到它。它由 `wp-connector-utils` 的单元测试覆盖（`inject_replaces_upstream_when_keep_disabled` / `inject_preserves_upstream_when_keep_enabled`）。

## 一个预期内的现象

B 的输出里 `data_type` 会出现两次：一次来自 A 的 JSON（规则提取），一次来自 B 规则的 `#[tag(data_type: "relay")]`。`#[tag]` 是无条件追加的规则标签，与 `wp_*` meta 的 upsert 语义不同，属于预期行为。
