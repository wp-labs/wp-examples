# DMDB Sink 使用配置说明

## 1. 使用前准备

在使用 `dmdb` sink 之前，请先完成 ODBC 驱动安装。之后再根据实际接入方式，分别执行 `connection_string`/`endpoint` 或 `dsn` 对应的配置与验证步骤。

### 1.1 通用准备：安装 ODBC 环境与达梦驱动

#### 安装系统依赖（Ubuntu 示例）

```bash
apt-get update
apt-get install -y unixodbc unixodbc-dev odbcinst
```

执行以下命令验证安装结果：

```bash
root@ent-rdd-WarpParse-01:~/wp/dameng_odbc_linux# which isql
/usr/bin/isql
root@ent-rdd-WarpParse-01:~/wp/dameng_odbc_linux# isql --version
unixODBC 2.3.12
root@ent-rdd-WarpParse-01:~/wp/dameng_odbc_linux# odbcinst -j
unixODBC 2.3.12
DRIVERS............: /etc/odbcinst.ini
SYSTEM DATA SOURCES: /etc/odbc.ini
FILE DATA SOURCES..: /etc/ODBCDataSources
USER DATA SOURCES..: /root/.odbc.ini
SQLULEN Size.......: 8
SQLLEN Size........: 8
SQLSETPOSIROW Size.: 8
```

#### 安装达梦 ODBC 驱动

- Windows 版：<https://dn.navicat.com/drivers/dameng_odbc_win.zip>
- Linux 版：<https://dn.navicat.com/drivers/dameng_odbc_linux.tar.gz>

以下示例假设压缩包下载到 `/root/wp` 目录：

#### 配置动态库路径

```bash
echo "/root/wp/dameng_odbc_linux/libdodbc.so" > /etc/ld.so.conf.d/dameng.conf
ldconfig
```

执行以下命令验证动态库是否加载成功：

```bash
root@ent-rdd-WarpParse-01:~/wp/dameng_odbc_linux# ldconfig -p | grep libdodbc
        libdodbc.so (libc6,x86-64) => /root/wp/dameng_odbc_linux/libdodbc.so
```

### 1.2 通用准备：注册 ODBC 驱动

编辑 `/etc/odbcinst.ini`。如果文件已存在，直接追加下面内容即可；如果文件不存在，可以直接创建后写入：

```ini
[DM8 ODBC DRIVER]
Description = DM8 ODBC DRIVER for DM8
Driver = /root/wp/dameng_odbc_linux/libdodbc.so
FileUsage = 1
```

配置完成后，执行以下命令验证驱动对比输出是否注册成功：

```bash
root@ent-rdd-WarpParse-01:~/wp/dameng_odbc_linux# odbcinst -q -d -n "DM8 ODBC DRIVER"
[DM8 ODBC DRIVER]
Description=ODBC DRIVER FOR DM8
Driver=/root/wp/dameng_odbc_linux/libdodbc.so
Setup=/root/wp/dameng_odbc_linux/libdodbc.so
```

完成以上步骤后，表示宿主机已经具备达梦 ODBC 驱动能力。接下来请根据实际连接方式，选择下面两条路径之一继续配置。

### 1.3 `connection_string` / `endpoint` 模式配置过程

这两种模式都不依赖 `/etc/odbc.ini` 中的 DSN 名称，只要求前面的 ODBC 驱动已经安装并注册成功。

- `connection_string` 模式：直接提供完整 ODBC 连接串。
- `endpoint` 模式：由 `endpoint + driver + username + password` 自动拼接连接串。

可以直接在 `wparse` 运行机器上执行以下命令验证驱动与直连参数是否可用，并将其中的地址、端口、用户名和密码替换为实际值：

```bash
root@ent-rdd-WarpParse-01:~/wp/dameng_odbc_linux# isql -v -k "Driver={DM8 ODBC DRIVER};Server=127.0.0.1;Port=5236;UID=SYSDBA;PWD=SYSDBA"
+---------------------------------------+
| Connected!                            |
|                                       |
| sql-statement                         |
| help [tablename]                      |
| echo [string]                         |
| quit                                  |
|                                       |
+---------------------------------------+
SQL>
```

如果上述命令可以正常连接，说明 `connection_string` 或 `endpoint` 方式所需的宿主机准备已完成。

### 1.4 `dsn` 模式配置过程

`dsn` 模式除了要求 ODBC 驱动已经安装并注册外，还需要在 `/etc/odbc.ini` 中额外配置一个数据源名称，且该名称必须与 sink 配置中的 `dsn` 参数保持一致。

例如，可以在 `/etc/odbc.ini` 中补充一个达梦数据源：

```ini
[DM_DSN]
Description = DM8 Database
Driver = /root/wp/dameng_odbc_linux/libdodbc.so
Server = 159.75.175.212
Port = 5236
User = SYSDBA
Password = <请替换为实际密码>
```

配置完成后，可执行以下命令验证 DSN 是否可用（其中的地址、用户名、密码需要替换为实际值）：

```bash
root@ent-rdd-WarpParse-01:~/wp/dameng_odbc_linux# cat /etc/odbc.ini
[DM_DSN]                          ; DSN 名称
Description = DM8 Database
Driver = /root/wp/dameng_odbc_linux/libdodbc.so
Server = 127.0.0.1
Port = 5236
User = SYSDBA
Password = Dayu@1234
root@ent-rdd-WarpParse-01:~/wp/dameng_odbc_linux# isql DM_DSN SYSDBA SYSDBA
+---------------------------------------+
| Connected!                            |
|                                       |
| sql-statement                         |
| help [tablename]                      |
| echo [string]                         |
| quit                                  |
|                                       |
+---------------------------------------+
SQL> 
```

如果上述命令可以正常连接，说明 `dsn = "DM_DSN"` 对应的系统级数据源已经配置完成。

### 1.5 准备目标表

- 目标表需要预先存在。
- `table` 和 `columns` 必须与目标表实际结构匹配，包括列名、列类型等。

## 2. 连接方式

### 2.1 `connection_string` 模式

适合已经有完整 ODBC 连接串的场景。

- 必填参数：`connection_string`、`table`、`columns`
- 可选参数：`schema`、`batch_size`、`connect_timeout_secs`、`query_timeout_secs`
- 不要求额外提供：`dsn`、`endpoint`、`driver`、`username`、`password`

示例：

```toml
[sink_group]
name = "database"
rule = ["/*"]
parallel = 8
[[sink_group.sinks]]
name = "dmdb_sink"
connect = "dmdb_connect_string"
[sink_group.sinks.params]
connection_string = "Driver={DM8 ODBC DRIVER};SERVER=127.0.0.1;TCP_PORT=5236;UID=SYSDBA;PWD=Dayu@1234;"
table = "nginx_logs"
columns = ["sip", "timestamp", "http/request", "status", "size", "referer", "http/agent"]
batch_size = 2000
query_timeout_secs = 15
```

### 2.2 `endpoint` 模式

适合不想预先配置 DSN，而是直接通过地址建连的场景。

- 必填参数：`endpoint`、`driver`、`username`、`password`、`table`、`columns`
- 可选参数：`schema`、`batch_size`、`connect_timeout_secs`、`query_timeout_secs`
- `endpoint` 必须是 `host:port` 格式，且 `port` 必须能解析为合法 `u16`

示例：

```toml
[sink_group]
name = "database"
rule = ["/*"]
parallel = 8
[[sink_group.sinks]]
name = "dmdb_sink"
connect = "dmdb_endpoint"
[sink_group.sinks.params]
endpoint = "127.0.0.1:5236"
driver = "DM8 ODBC DRIVER"
username = "SYSDBA"
password = "SYSDBA"
schema = "WP_DATA"
table = "EVENTS"
columns = ["event_id", "event_time", "source", "payload"]
batch_size = 2000
connect_timeout_secs = 8
query_timeout_secs = 15
```

### 2.3 `dsn` 模式

适合宿主机已经配置好 ODBC DSN，且没有传入 `connection_string` 或 `endpoint` 的场景。

- 必填参数：`dsn`、`username`、`password`、`table`、`columns`
- 可选参数：`schema`、`batch_size`、`connect_timeout_secs`、`query_timeout_secs`
- 不要求额外提供：`endpoint`、`driver`

示例：

```toml
[sink_group]
name = "database"
rule = ["/*"]
parallel = 8
[[sink_group.sinks]]
name = "dmdb_sink"
connect = "dmdb_dsn"
[sink_group.sinks.params]
dsn = "DM_DSN"
username = "SYSDBA"
password = "SYSDBA"
schema = "WP_DATA"
table = "EVENTS"
columns = ["event_id", "event_time", "source", "payload"]
batch_size = 2000
connect_timeout_secs = 8
query_timeout_secs = 15
```

## 3. 参数说明

| 参数                     | 类型         | 是否必填                     | 适用模式 | 说明                                                                           |
| ---------------------- | ---------- | ------------------------ | ---- | ---------------------------------------------------------------------------- |
| `connection_string`    | `string`   | `connection_string` 模式必填 | 全部   | 完整 ODBC 连接串，优先级最高。                                                           |
| `endpoint`             | `string`   | `endpoint` 模式必填          | 全部   | 达梦地址，格式必须为 `host:port`；优先级高于 `dsn`。                                          |
| `dsn`                  | `string`   | `dsn` 模式必填               | 全部   | ODBC 数据源名称；仅在未配置 `connection_string` 和 `endpoint` 时使用。                       |
| `driver`               | `string`   | `endpoint` 模式必填          | 全部   | 达梦 ODBC 驱动名称，例如 `DM8 ODBC DRIVER`。                                           |
| `username`             | `string`   | `dsn`、`endpoint` 模式必填    | 全部   | 达梦用户名。`connection_string` 模式不要求单独传入。                                         |
| `password`             | `string`   | `dsn`、`endpoint` 模式必填    | 全部   | 达梦密码。`connection_string` 模式不要求单独传入。                                          |
| `schema`               | `string`   | 否                        | 全部   | 用于拼接目标表的限定名；在 `endpoint` 模式下还会被附加进生成的连接串。                                    |
| `table`                | `string`   | 是                        | 全部   | 目标表名，不能为空。                                                                   |
| `columns`              | `string[]` | 是                        | 全部   | 目标列名列表。必须是字符串数组，且每一项都不能为空字符串。                                                |
| `batch_size`           | `integer`  | 否                        | 全部   | 单次 SQL 最多写入的记录数，必须大于 `0`。未配置时 sink 内部回落为 `1024`。                             |
| `connect_timeout_secs` | `integer`  | 否                        | 全部   | ODBC 登录超时秒数，必须大于 `0`。配置后会传给 `ConnectionOptions.login_timeout_sec`；未配置时不显式设置。 |
| `query_timeout_secs`   | `integer`  | 否                        | 全部   | 每批 SQL 的执行超时秒数，必须大于 `0`。未配置时不显式设置。                                           |
