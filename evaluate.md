# 评估


## Task 1

### 要求：

* 1、通过二进制执行命令，输入是文件，输出是文件
* 2、要求输出结果包括字段名和字段类型都完全一致

### 样本：

```cmd
[20/Feb/2018:12:12:14 +0800] 112.195.209.90 - -  "GET / HTTP/1.1" 200 190 "-" "Mozilla/5.0 (Linux; Android 6.0; Nexus 5 Build/MRA58N) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/63.0.3239.132 Mobile Safari/537.36" "-"
```

### 结果：

```json
{
  "remote_addr": "112.195.209.90",
  "time_local": "2018-02-20 12:12:14",
  "request": "GET / HTTP/1.1",
  "status": "200",
  "body_bytes_sent": 190,
  "http_referer": "-",
  "http_user_agent": "Mozilla/5.0 (Linux; Android 6.0; Nexus 5 Build/MRA58N) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/63.0.3239.132 Mobile Safari/537.36",
  "http_x_forwarded_for": "-"
}
```


## T2
### 要求
* 通过二进制执行命令，输入是 TCP，输出是文件
* 通过 wpgen 命令实现发送数据
* 要求输出结果包括字段名和字段类型都完全一致

### 样本：

```cmd
http 2018-11-30T22:23:00.186641Z app/my-lb 192.168.1.10:2000 10.0.0.15:8080 0.01 0.02 0.01 200 200 100 200 "POST https://api.example.com/u?p=1&sid=2&t=3 HTTP/1.1" "Mozilla/5.0 (Win) Chrome/90" "ECDHE" "TLSv1.3" arn:aws:elb:us:123:tg "Root=1-test" "api.example.com" "arn:aws:acm:us:123:cert/short" 1 2018-11-30T22:22:48.364000Z "forward" "https://auth.example.com/r" "err" "10.0.0.1:80" "200" "cls" "rsn" TID_x1
```

### 结果:

```json
{
  "log_type": "http",
  "timestamp": 1543616580186,
  "elb": "app/my-lb",
  "client_host": "192.168.1.10:2000",
  "target_host": "10.0.0.15:8080",
  "request_processing_time": 0.01,
  "target_processing_time": 0.02,
  "response_processing_time": 0.01,
  "elb_status_code": "200",
  "target_status_code": "200",
  "received_bytes": 100,
  "sent_bytes": 200,
  "request_method": "POST",
  "request_url": "https://api.example.com/u?p=1&sid=2&t=3",
  "request_protocol": "HTTP/1.1",
  "user_agent": "Mozilla/5.0 (Win) Chrome/90",
  "ssl_cipher": "ECDHE",
  "ssl_protocol": "TLSv1.3",
  "target_group_arn": "arn:aws:elb:us:123:tg",
  "trace_id": "Root=1-test",
  "domain": "api.example.com",
  "chosen_cert_arn": "arn:aws:acm:us:123:cert/short",
  "matched_rule_priority": "1",
  "request_creation_time": "2018-11-30 22:22:48.364",
  "actions_executed": "forward",
  "redirect_url": "https://auth.example.com/r",
  "error_reason": "err",
  "target_port_list": "10.0.0.1:80",
  "target_status_code_list": "200",
  "classification": "cls",
  "classification_reason": "rsn",
  "traceability_id": "TID_x1"
}
```


## T3

### 要求
* 通过 docker 启动 wparse，输入是 TCP，输出是文件
* TCP通过 wpgen 命令 发送
* 要求输出结果包括字段名和字段类型都完全一致
* 需要根据 sip 和 dip 判断内外网

### 原文：

```
{"update_time":"2024-12-03 10:23:22","access_ip":"0.0.0.0","packet_data":"dXNlcjphZG1pbiBwYXNzd29yZDoxMjM0NTY=","ip":"1.1.1.1:1111->10.0.0.1:2222","attack_result": "1","log_type":"flow_ty_attack"}
```

### 结果:

```json
{
  "log_type": "flow_ty_attack",
  "access_ip": "0.0.0.0",
  "sip": "1.1.1.1",
  "sport": 1111,
  "dip": "10.0.0.1",
  "dport": 2222,
  "user_name": "admin",
  "password": "123456",
  "update_time": "2024-12-03 10:23:22",
  "attack_result": "成功",
  "src_zone": "External",
  "dst_zone": "Internal"
}
```



## T4

### 要求
* 通过 docker 启动 wparse，输入是 KAFKA，输出是 MYSQL
* KAFKA通过 wpgen 命令 发送
* 要求输出结果包括字段名和字段类型都完全一致
* 按提示完成 oml 转化

### 原文：

```
222.133.52.20 simple_chars 80 192.168.1.10 select_one left 2025-12-29 12:00:00 {"msg":"hello"} "" aGVsbG8gd29ybGQ= ["val1","val2","val3"] /home/user/file.txt  http://example.com/path/to/resource?foo=1&bar=2  [{"one":{"two":"nested"}}] foo bar baz qux 500 ext_value_1 ext_value_2  &lt;script&gt;  hello"world 12345
```

### 结果：

```json
{
    "direct_chars": "13", //直接赋值
    "direct_digit": 13,
    "simple_chars": "simple_chars",//直接赋值
    "simple_port": 80,
    "simple_ip": "192.168.1.10",
    "ip_ip4_to_int": 3232235786, //ip转int(192.168.1.10)
    "html_unescape": "<script>", //html转码
    "html_escape": "&lt;script&gt;",//html转码
    "str_escape": "hello\\\"world",//转义
    "select_chars": "select_one", //使用option
    "match_chars": "1",			// left为1，right为2
    "time": "2026-01-12 19:38:43.452811", //当前标准时间
    "date": 20260112, //当前时间(YYYYMMDD格式)
    "hour": 2026011219, //当前时间（YYYYMMDDHH格式）
    "timestamp": 1766980800000, //北京时间毫秒级时间戳（使用日志中的时间2025-12-29 12:00:00）
    "timestamp1": 1766980800, //秒（使用日志中的时间2025-12-29 12:00:00）
    "timestamp2": 1766980800000, //毫秒（使用日志中的时间2025-12-29 12:00:00）
    "timestamp3": 1766980800000000, //微秒（使用日志中的时间2025-12-29 12:00:00）
    "timestamp4": 1768246851, //UTC+8秒（使用当前时间）
    "timestamp5": 1768246851009, //UTC+8 毫秒（使用当前时间）
    "timestamp6": 1768246851009507, //UTC+8 微秒（使用当前时间0）
    "base64_en": "aGVsbG8=", //base64
    "base64_de": "hello word",
    "array_get": "val1", //数组取值
    "array_str": "[\"val1\",\"val2\",\"val3\"]", //数组转json
    "name": "file.txt", //文件路径取值
    "path": "/path/to/resource", // 从全路径中获取目录路径
    "domain": "example.com", //http取值
    "host": "example.com",
    "uri": "/path/to/resource?foo=1&bar=2",
    "params": "foo=1&bar=2",
    "obj": "nested", //多层取值
    "splice": "foo:bar|baz:qux", //字符拼接
    "num_range": "大于 0 小于 1000", //范围判断
    "extends": { //扩展字段
        "extend1": "ext_value_1",
        "extend2": "ext_value_2"
    }
}
```
