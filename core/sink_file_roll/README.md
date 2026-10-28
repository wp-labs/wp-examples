# sink_file_roll — 文件 Sink 容量滚动与归档压缩

验证 `file_json_sink` 的三个滚动相关参数：

| 参数 | 含义 |
|------|------|
| `max_size` | 单个活动文件的最大字节数；`0`（默认）表示不限容量、不滚动 |
| `max_rolls` | 保留的历史文件个数（不含当前文件），默认 `3`；`0` 表示滚动时直接丢弃旧文件 |
| `roll_compress` | 历史文件归档方式：`none`（默认）/ `gzip` / `zip`（`true` 等价 `gzip`） |

## 用例设计

同一份输入、同一个 sink group 下并排放三个 sink，一次解析验证三种行为：

| sink | 配置 | 断言 |
|------|------|------|
| `zip` | `max_size = "4KB"`, `max_rolls = 100`, `roll_compress = "zip"` | 生成多个 `.N.zip`；每个归档可解压且只含 1 个条目；**活动文件 + 全部归档的行数 = 输入行数**（不丢不重） |
| `gzip` | `max_size = "4KB"`, `max_rolls = 2`, `roll_compress = "gzip"` | 存在 `.1.gz` / `.2.gz`，不存在 `.3.gz`；`gunzip -c` 可解；保留总行数 **小于** 输入（最旧数据被删除） |
| `flat` | 不配 `max_size` | 只有一个文件、行数等于输入、没有任何 `.N` 归档 |

此外还验证：

- 归档命名：`roll_zip.dat` → `roll_zip.dat.1.zip`、`roll_gz.dat` → `roll_gz.dat.1.gz`；
- 每次滚动都会重建压缩流，因此每个归档都能**独立**解压（不依赖前一个文件）；
- `max_size` 是**单文件**上限，不限制总目录大小。

## 运行

```bash
cd core/sink_file_roll
./run.sh
```

可调环境变量：

- `LINE_CNT`（默认 300）：生成的输入行数，行数越多归档越多；
- `STAT_SEC`（默认 1）：统计输出间隔。

前置条件：`wparse` / `wpadm` / `wpgen` 在 PATH 中（建议 >= 0.35.2），并具备 `gunzip`、`unzip`。

## 连接器说明

本用例不单独维护连接器，直接复用仓库根目录的 `connectors/sink.d/`（引擎会从 sink root 逐级向上查找
`connectors/sink.d`）。根目录的文件型连接器已在 `allow_override` 里放开
`max_size` / `max_rolls` / `roll_compress`。

其它工程若用的是旧模板（只有 `base` / `file`），需要补上这三个键，否则会被判为非法覆盖；
同时**不要**给它们配默认值（覆盖值类型必须与默认值一致，默认成整数 `0` 会让 `max_size = "10MB"` 被拒绝）。

> 注意：`protocol = "arrow"` 的文件 sink 不支持滚动，配置 `max_size` / `max_rolls` / `roll_compress` 会报错。
