# TCP Roundtrip

目标：演示通用 TCP 输入/输出的端到端链路。

- wpgen：通过 `connect = "tcp_sink"` 将样本数据推送到本机端口
- wparse：启用 `tcp_src` 源监听同一端口，落地到文件 sink

步骤
1) 启动解析器
```
wparse deamon --stat 5
```
2) 生成数据（推送到 TCP）
```
wpgen sample -n 10000 --stat 5
```
3) 停止解析器并校验
```
wproj stat sink-file
wproj validate sink-file -v --input-cnt 10000
```

关键文件
- conf/wparse.toml：主配置（sources/sinks/model 路径）
- models/sources/wpsrc.toml：source 列表（包含 `tcp_src`）
- conf/wpgen.toml：生成器配置（输出 `tcp_sink` 到本机端口）
