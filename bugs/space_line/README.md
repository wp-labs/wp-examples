# space_line

本用例用于复现 OML 中包含空格文本的 `chars(...)` 匹配问题。输入为 Apache 日志样例，WPL 解析后进入 OML 转换，重点覆盖 `EventTemplate` 这种包含空格与占位符的模板匹配。

## 目录结构

```
bugs/space_line/
├── README.md
├── run.sh
├── conf/
│   ├── wparse.toml
│   └── wpgen.toml
├── models/
│   ├── oml/
│   │   └── apache.oml
│   └── wpl/
│       └── apache/
│           ├── parse.wpl
│           └── sample.dat
└── topology/
    ├── sources/
    │   └── wpsrc.toml
    └── sinks/
        └── defaults.toml
```

## 快速开始

```bash
cd bugs/space_line
./run.sh
```

## 运行参数

`run.sh` 支持以下参数（与 benchmark 公共脚本一致）：

- `-m`：中等规模数据集（200000 行）
- `-c <cnt>`：自定义行数
- `-f`：强制重新生成数据
- `-w <cnt>`：指定 worker 数
- `wpl_dir`：WPL 子目录名，默认 `apache`
- `speed`：生成限速（行/秒，默认 0）

示例：

```bash
./run.sh -m
./run.sh -c 10000 -f apache
```

## 执行流程

1. 初始化配置与数据目录（`wproj check` / `wproj data clean`）。
2. 使用 `wpgen sample` 基于 `models/wpl/apache/sample.dat` 生成输入数据。
3. 运行 `wparse batch`，加载 `models/wpl/apache/parse.wpl` 并应用 `models/oml/apache.oml`。
4. 输出统计结果到 `data/`。
