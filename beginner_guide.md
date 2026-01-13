# Beginner Guide

我们来开启 WarpParse 的使用学习。

## 准备工作
### 安装

```bash
curl  -sSf https://get.warpparse.ai/setup.sh | sh
```

[最新发布页](https://github.com/wp-labs/warp-parse/releases)


**MacOS 提示**：
* 打开安装限制

### 下载学习示例

```
git clone https://github.com/wp-labs/wp-examples.git

```

## 目标1: 让WarpParse 运行起来

### 初始化项目
#### wproj init
```
mkdir ${HOME}/wp-space ;
cd  ${HOME}/wp-space;

wproj init -m full
```

* 项目的结构
```
tree -L 2
.
├── conf
│   ├── wparse.toml
│   └── wpgen.toml
├── connectors
│   ├── sink.d
│   └── source.d
├── data
│   ├── in_dat
│   ├── logs
│   ├── out_dat
│   └── rescue
├── models
│   ├── knowledge
│   ├── oml
│   └── wpl
└── topology
    ├── sinks
    └── sources
```

### 生成测试数据
第一个例子，是最为简单的从文件解析到文件

```
wpgen sample -n 3000 
```

### 引擎解析数据

```
wparse batch --stat 2 -p 
```
运行结果：
```
============================ total stat ==============================

+-------+------------+-----------------+---------+-------+---------+----------+--------+
| stage | name       | target          | collect | total | success | suc-rate | speed  |
+======================================================================================+
| Parse | parse_stat | /nginx//example |         | 3000  | 3000    | 100.0%   | 3.12   |
|-------+------------+-----------------+---------+-------+---------+----------+--------|
| Pick  | pick_stat  | file_1          |         | 3000  | 3000    | 100.0%   | 150.00 |
|-------+------------+-----------------+---------+-------+---------+----------+--------|
| Sink  | sink_stat  | demo/json       |         | 1280  | 1280    | 100.0%   | 3.56   |
+-------+------------+-----------------+---------+-------+---------+----------+--------+
```

### 数据统计

```
wproj data stat
```
* 输出
```
== Sources ==
| Key    | Enabled | Lines | Path                    | Error |
|--------|---------|-------|-------------------------|-------|
| file_1 |    Y    |  3000 | .../data/in_dat/gen.dat | -     |
Total enabled lines: 3000

== Sinks ==
| Scope    | Sink        | Path                         | Lines |
|----------|-------------|------------------------------|-------|
| business | demo/json   | .../data/out_dat/demo.json   |  3000 |
| infra    | default/[0] | .../data/out_dat/default.dat |     0 |
| infra    | error/[0]   | .../data/out_dat/error.dat   |     0 |
| infra    | miss/[0]    | .../data/out_dat/miss.dat    |     0 |
| infra    | monitor/[0] | .../data/out_dat/monitor.dat |     0 |
| infra    | residue/[0] | .../data/out_dat/residue.dat |     0 |
```
只能基于文件才可以通过wproj统计


## 目标2: 解析自己的日志

### 学习 WPL 解析日志
样本： linux 系统日志
```
Oct 10 08:30:15 server systemd[1]: Started Apache HTTP Server.
```

* 打开 [editor](https://editor.warpparse.ai)工具
* 看看 editor的几个例子
* 学习下[WPL](https://docs.warpparse.ai/zh/10-user/03-wpl/01-wpl_basics.html)

### 纳入WP工程

```
mkdir ./models/wpl/my_sys
```
样本放置:
```
./models/wpl/my_sys/sample.dat
```
WPL放置：
```
./models/wpl/my_sys/parse.wpl
```

### 生成数据

[使用 wpgen ](https://docs.warpparse.ai/zh/10-user/01-cli/04-wpgen.html)
### 批量解析
[使用 wparse](https://docs.warpparse.ai/zh/10-user/01-cli/03-wparse.html)

## Docker


下载最新版本
```bash
docker pull ghcr.io/wp-labs/warp-parse:latest
```


```bash
sudo docker run -it --rm --user root --entrypoint /bin/bash <image-id>
```
