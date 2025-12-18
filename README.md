# WP-Examples 

WarpParse 日志解析引擎的示例项目，展示如何使用 WarpParse进行高性能日志解析和处理。

## 提纲

- **core**： 核心配置示例
- **benchmark**：性能测试
- **extensions**： 扩展示例
- **enterprise**：  企业版本示例


## 🛠️ 快速开始

当前只支持 Linux/macOS 
### 下载 wp-example
1. 下载压缩包 [wp-example.zip](https://github.com/wp-labs/wp-examples/archive/refs/heads/main.zip)

2. 通过git 
```
git clone https://github.com/wp-labs/wp-examples.git
```

### 下载 Wparse 

* 在此 [下载](https://github.com/wp-labs/warp-parse/releases) 选择最新的平台版本，
* 解压，并拷贝到 /usr/local/bin 目录

## 运行环境设置 
### mac 
* 许可wparse,wpgen,wproj 的运行

### 运行示例

1. **快速入门示例**
   ```bash
   cd core/getting_started
   ./run.sh
   ```

2. **性能基准测试**
   ```bash
   # TCP 到 Blackhole 测试
   cd benchmark/tcp_blackhole
   ./run.sh nginx 300000 
   ./run.sh aws 300000 
   ```
