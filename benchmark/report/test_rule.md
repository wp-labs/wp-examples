# Rule Definitions

本文档汇总了测试中使用的解析与解析+转换规则，按日志类型与引擎归档。

## 1. Nginx Access Log (239B)

### WarpParse
- **解析配置（WPL）**

```bash
package /nginx/ {
   rule nginx {
        (ip:sip,_^2,chars:timestamp<[,]>,http/request:http_request",chars:status,chars:size,chars:referer",http/agent:http_agent",_")
   }
}
```

- **解析+转换配置（WPL + OML）**

```bash
package /nginx/ {
   rule nginx {
        (ip:sip,_^2,chars:timestamp<[,]>,http/request:http_request",chars:status,chars:size,chars:referer",http/agent:http_agent",_")
   }
}
```

```bash
name : nginx
rule : /nginx/*
---
size : digit = take(size);
status : digit = take(status);
str_status = match read(option:[status]) {
    digit(500) => chars(Internal Server Error);
    digit(404) => chars(Not Found); 
};
match_chars = match read(option:[wp_src_ip]) {
    ip(127.0.0.1) => chars(localhost); 
    !ip(127.0.0.1) => chars(attack_ip); 
};
* : auto = read();
```

### Vector-VRL
- **解析配置**

```bash
source = '''
  . |= parse_regex!(.message, r'^(?P<sip>\S+) \S+ \S+ \[(?P<timestamp>[^\]]+)\] "(?P<http_request>[^"]*)" (?P<status>\d{3}) (?P<size>\d+) "(?P<referer>[^"]*)" "(?P<http_agent>[^"]*)"')
  del(.message)
'''
```

- **解析+转换配置**

```toml
source = '''
  . |= parse_regex!(.message, r'^(?P<sip>\S+) \S+ \S+ \[(?P<timestamp>[^\]]+)\] "(?P<http_request>[^"]*)" (?P<status>\d{3}) (?P<size>\d+) "(?P<referer>[^"]*)" "(?P<http_agent>[^"]*)"')
  del(.message)
  .status = to_int!(.status)
  .size = to_int!(.size)
if .host == "127.0.0.1" {
    .match_chars = "localhost"
} else if .host != "127.0.0.1" {
    .match_chars = "attack_ip"
}  
if .status == 500 {
    .str_status = "Internal Server Error"
} else if .status == 404 {
    .str_status = "Not Found"
}  
'''
```

### Vector-Fixed
- **解析配置**

```toml
source = '''
  . |= parse_nginx_log!(.message, format: "combined")
  del(.message)
'''
```

- **解析+转换配置**

```toml
source = '''
  . |= parse_nginx_log!(.message, format: "combined")
  .http_agent = .agent
  del(.agent)
  .http_request = .request
  del(.request)
  .sip = .client
  del(.client)
  .status = to_int!(.status)
  .size = to_int!(.size)
if .host == "127.0.0.1" {
    .match_chars = "localhost"
} else if .host != "127.0.0.1" {
    .match_chars = "attack_ip"
}  
if .status == 500 {
    .str_status = "Internal Server Error"
} else if .status == 404 {
    .str_status = "Not Found"
}  
  del(.message)
'''
```

### Logstash
- **解析配置**

```conf
input {
  file {
    path => ["in_data/simple_nginx_239B"]
    start_position => "beginning"
    sincedb_path => "/dev/null"
  }
}

filter {
  dissect {
  mapping => {
    "message" => '%{sip} - - [%{timestamp}] "%{http_request}" %{status} %{size} "%{referer}" "%{http_agent}"'
  }
}
  mutate {
  remove_field => ["message","@timestamp","@version","event","[event][original]"]
}
}

output {
  file { path => "/dev/null" codec => "json_lines" }
}
```

- **解析+转换配置**

```conf
input {
  file {
    path => ["in_data/simple_nginx_239B"]
    start_position => "beginning"
    sincedb_path => "/dev/null"
    add_field => {
      "src_ip"      => "127.0.0.1"
    }
  }
}

filter {
  # 1) 解析：对齐你当前的 nginx dissect 字段
  dissect {
    mapping => {
      "message" => '%{sip} - - [%{timestamp}] "%{http_request}" %{status} %{size} "%{referer}" "%{http_agent}"'
    }
  }

  # 2) 类型转换：对齐 Vector 的 to_int
  mutate {
    convert => {
      "status" => "integer"
      "size"   => "integer"
    }
  }

  # 3) 派生字段：对齐 Vector 示例里的 match_chars / str_status
  # match_chars：根据 tcp 对端 host 判断
  if [src_ip] == "127.0.0.1" {
    mutate { add_field => { "match_chars" => "localhost" } }
  } else {
    mutate { add_field => { "match_chars" => "attack_ip" } }
  }

  # str_status：按 status 映射（你 Vector 里出现了 500 / 404，我补了常见的 200）
  if [status] == 200 {
    mutate { add_field => { "str_status" => "OK" } }
  } else if [status] == 500 {
    mutate { add_field => { "str_status" => "Internal Server Error" } }
  } 

  # 4) 清理无关字段：保持你的压测输出干净
  mutate {
    remove_field => ["message", "@timestamp", "@version", "event", "[event][original]"]
  }
}

output {
  file { path => "/dev/null" codec => "json_lines" }
}
```

- **解析+转换配置（VRL）**

```toml
source = '''
  parsed = parse_regex!(.message, r'^(?P<client>\S+) \S+ \S+ \[(?P<time>[^\]]+)\] "(?P<request>[^"]*)" (?P<status>\d{3}) (?P<size>\d+) "(?P<referer>[^"]*)" "(?P<agent>[^"]*)" "(?P<extra>[^"]*)"')
  .sip = parsed.client
  .http_request = parsed.request
  .referer = parsed.referer
  .http_agent = parsed.agent
  .timestamp = parsed.time
  del(.message)
  .status = to_int!(parsed.status)
  .size = to_int!(parsed.size)
if .host == "127.0.0.1" {
    .match_chars = "localhost"
} else if .host != "127.0.0.1" {
    .match_chars = "attack_ip"
}  
if .status == 500 {
    .str_status = "Internal Server Error"
} else if .status == 404 {
    .str_status = "Not Found"
}  
'''
```

### Vector-Fixed
- **解析配置**

```toml
source = '''
  . |= parse_nginx_log!(.message, format: "combined")
  del(.message)
'''
```

- **解析+转换配置**

```toml
source = '''
  . |= parse_nginx_log!(.message, format: "combined")
  .http_agent = .agent
  del(.agent)
  .http_request = .request
  del(.request)
  .sip = .client
  del(.client)
  .status = to_int!(.status)
  .size = to_int!(.size)
if .host == "127.0.0.1" {
    .match_chars = "localhost"
} else if .host != "127.0.0.1" {
    .match_chars = "attack_ip"
}  
if .status == 500 {
    .str_status = "Internal Server Error"
} else if .status == 404 {
    .str_status = "Not Found"
}  
  del(.message)
'''
```

### Logstash
- **解析配置**

```conf
input {
  file {
    path => ["in_data/simple_nginx_239B"]
    start_position => "beginning"
    sincedb_path => "/dev/null"
  }
}

filter {
  dissect {
  mapping => {
    "message" => '%{sip} - - [%{timestamp}] "%{http_request}" %{status} %{size} "%{referer}" "%{http_agent}"'
  }
}
  mutate {
  remove_field => ["message","@timestamp","@version","event","[event][original]"]
}
}

output {
  file { path => "/dev/null" codec => "json_lines" }
}
```

- **解析+转换配置**

```conf
input {
  file {
    path => ["in_data/simple_nginx_239B"]
    start_position => "beginning"
    sincedb_path => "/dev/null"
    add_field => {
      "src_ip"      => "127.0.0.1"
    }
  }
}

filter {
  # 1) 解析：对齐你当前的 nginx dissect 字段
  dissect {
    mapping => {
      "message" => '%{sip} - - [%{timestamp}] "%{http_request}" %{status} %{size} "%{referer}" "%{http_agent}"'
    }
  }

  # 2) 类型转换：对齐 Vector 的 to_int
  mutate {
    convert => {
      "status" => "integer"
      "size"   => "integer"
    }
  }

  # 3) 派生字段：对齐 Vector 示例里的 match_chars / str_status
  # match_chars：根据 tcp 对端 host 判断
  if [src_ip] == "127.0.0.1" {
    mutate { add_field => { "match_chars" => "localhost" } }
  } else {
    mutate { add_field => { "match_chars" => "attack_ip" } }
  }

  # str_status：按 status 映射（你 Vector 里出现了 500 / 404，我补了常见的 200）
  if [status] == 200 {
    mutate { add_field => { "str_status" => "OK" } }
  } else if [status] == 500 {
    mutate { add_field => { "str_status" => "Internal Server Error" } }
  } 

  # 4) 清理无关字段：保持你的压测输出干净
  mutate {
    remove_field => ["message", "@timestamp", "@version", "event", "[event][original]"]
  }
}

output {
  file { path => "/dev/null" codec => "json_lines" }
}
```

## 2. AWS ELB Log (411B)

### WarpParse
- **解析配置（WPL）**

```bash
package /aws/ {
   rule aws {
        (
            symbol(http),
            chars:timestamp,
            chars:elb,
            chars:client_host,
            chars:target_host,
            chars:request_processing_time,
            chars:target_processing_time,
            chars:response_processing_time,
            chars:elb_status_code,
            chars:target_status_code,
            chars:received_bytes,
            chars:sent_bytes,
            chars:request | (chars:request_method, chars:request_url, chars:request_protocol),
            chars:user_agent,
            chars:ssl_cipher,
            chars:ssl_protocol,
            chars:target_group_arn,
            chars:trace_id,
            chars:domain_name,
            chars:chosen_cert_arn,
            chars:matched_rule_priority,
            chars:request_creation_time,
            chars:actions_executed,
            chars:redirect_url,
            chars:error_reason,
            chars:target_port_list,
            chars:target_status_code_list,
            chars:classification,
            chars:classification_reason,
            chars:traceability_id,
        )
   }
   }
```

- **解析+转换配置（WPL + OML）**

```bash
package /aws/ {
   rule aws {
        (
            symbol(http),
            chars:timestamp,
            chars:elb,
            chars:client_host,
            chars:target_host,
            chars:request_processing_time,
            chars:target_processing_time,
            chars:response_processing_time,
            chars:elb_status_code,
            chars:target_status_code,
            chars:received_bytes,
            chars:sent_bytes,
            chars:request | (chars:request_method, chars:request_url, chars:request_protocol),
            chars:user_agent,
            chars:ssl_cipher,
            chars:ssl_protocol,
            chars:target_group_arn,
            chars:trace_id,
            chars:domain_name,
            chars:chosen_cert_arn,
            chars:matched_rule_priority,
            chars:request_creation_time,
            chars:actions_executed,
            chars:redirect_url,
            chars:error_reason,
            chars:target_port_list,
            chars:target_status_code_list,
            chars:classification,
            chars:classification_reason,
            chars:traceability_id,
        )
   }
   }
```

```bash
name : aws
rule : /aws/*
---
sent_bytes:digit = take(sent_bytes) ;
target_status_code:digit = take(target_status_code) ;
elb_status_code:digit = take(elb_status_code) ;
extends : obj = object {
    ssl_cipher = read(ssl_cipher);
    ssl_protocol = read(ssl_protocol);
};
match_chars = match read(option:[wp_src_ip]) {
    ip(127.0.0.1) => chars(localhost); 
    !ip(127.0.0.1) => chars(attack_ip); 
};
str_elb_status = match read(option:[elb_status_code]) {
    digit(200) => chars(ok);
    digit(404) => chars(error); 
};
* : auto = read();
```

### Vector-VRL
- **解析配置（VRL）**

```bash
source = '''
  parsed = parse_regex!(.message, r'^(?P<type>\S+) (?P<timestamp>\S+) (?P<elb>\S+) (?P<client_host>\S+) (?P<target_host>\S+) (?P<request_processing_time>[-\d\.]+) (?P<target_processing_time>[-\d\.]+) (?P<response_processing_time>[-\d\.]+) (?P<elb_status_code>\S+) (?P<target_status_code>\S+) (?P<received_bytes>\d+) (?P<sent_bytes>\d+) "(?P<request_method>\S+) (?P<request_url>[^ ]+) (?P<request_protocol>[^"]+)" "(?P<user_agent>[^"]*)" "(?P<ssl_cipher>[^"]*)" "(?P<ssl_protocol>[^"]*)" (?P<target_group_arn>\S+) "(?P<trace_id>[^"]*)" "(?P<domain_name>[^"]*)" "(?P<chosen_cert_arn>[^"]*)" (?P<matched_rule_priority>\S+) (?P<request_creation_time>\S+) "(?P<actions_executed>[^"]*)" "(?P<redirect_url>[^"]*)" "(?P<error_reason>[^"]*)" "(?P<target_port_list>[^"]*)" "(?P<target_status_code_list>[^"]*)" "(?P<classification>[^"]*)" "(?P<classification_reason>[^"]*)" (?P<traceability_id>\S+)$')
  .timestamp = parsed.timestamp
  .symbol = parsed.type
  .elb = parsed.elb
  .client_host = parsed.client_host
  .target_host = parsed.target_host
  .request_processing_time = parsed.request_processing_time
  .target_processing_time = parsed.target_processing_time
  .response_processing_time = parsed.response_processing_time
  .elb_status_code = parsed.elb_status_code
  .target_status_code = parsed.target_status_code
  .received_bytes = parsed.received_bytes
  .sent_bytes = parsed.sent_bytes
  .request_method = parsed.request_method
  .request_url = parsed.request_url
  .request_protocol = parsed.request_protocol
  .user_agent = parsed.user_agent
  .ssl_cipher = parsed.ssl_cipher
  .ssl_protocol = parsed.ssl_protocol
  .target_group_arn = parsed.target_group_arn
  .trace_id = parsed.trace_id
  .domain_name = parsed.domain_name
  .chosen_cert_arn = parsed.chosen_cert_arn
  .matched_rule_priority = parsed.matched_rule_priority
  .request_creation_time = parsed.request_creation_time
  .actions_executed = parsed.actions_executed
  .redirect_url = parsed.redirect_url
  .error_reason = parsed.error_reason
  .target_port_list = parsed.target_port_list
  .target_status_code_list = parsed.target_status_code_list
  .classification = parsed.classification
  .classification_reason = parsed.classification_reason
  .traceability_id = parsed.traceability_id
  del(.message)
'''
```

- **解析+转换配置（VRL）**

```toml
source = '''
  parsed = parse_regex!(.message, r'^(?P<type>\S+) (?P<timestamp>\S+) (?P<elb>\S+) (?P<client_host>\S+) (?P<target_host>\S+) (?P<request_processing_time>[-\d\.]+) (?P<target_processing_time>[-\d\.]+) (?P<response_processing_time>[-\d\.]+) (?P<elb_status_code>\S+) (?P<target_status_code>\S+) (?P<received_bytes>\d+) (?P<sent_bytes>\d+) "(?P<request_method>\S+) (?P<request_url>[^ ]+) (?P<request_protocol>[^"]+)" "(?P<user_agent>[^"]*)" "(?P<ssl_cipher>[^"]*)" "(?P<ssl_protocol>[^"]*)" (?P<target_group_arn>\S+) "(?P<trace_id>[^"]*)" "(?P<domain_name>[^"]*)" "(?P<chosen_cert_arn>[^"]*)" (?P<matched_rule_priority>\S+) (?P<request_creation_time>\S+) "(?P<actions_executed>[^"]*)" "(?P<redirect_url>[^"]*)" "(?P<error_reason>[^"]*)" "(?P<target_port_list>[^"]*)" "(?P<target_status_code_list>[^"]*)" "(?P<classification>[^"]*)" "(?P<classification_reason>[^"]*)" (?P<traceability_id>\S+)$')
  .timestamp = parsed.timestamp
  .symbol = parsed.type
  .elb = parsed.elb
  .client_host = parsed.client_host
  .target_host = parsed.target_host
  .request_processing_time = parsed.request_processing_time
  .target_processing_time = parsed.target_processing_time
  .response_processing_time = parsed.response_processing_time
  .received_bytes = parsed.received_bytes
  .request_method = parsed.request_method
  .request_url = parsed.request_url
  .request_protocol = parsed.request_protocol
  .user_agent = parsed.user_agent
  .ssl_cipher = parsed.ssl_cipher
  .ssl_protocol = parsed.ssl_protocol
  .target_group_arn = parsed.target_group_arn
  .trace_id = parsed.trace_id
  .domain_name = parsed.domain_name
  .chosen_cert_arn = parsed.chosen_cert_arn
  .matched_rule_priority = parsed.matched_rule_priority
  .request_creation_time = parsed.request_creation_time
  .actions_executed = parsed.actions_executed
  .redirect_url = parsed.redirect_url
  .error_reason = parsed.error_reason
  .target_port_list = parsed.target_port_list
  .target_status_code_list = parsed.target_status_code_list
  .classification = parsed.classification
  .classification_reason = parsed.classification_reason
  .traceability_id = parsed.traceability_id
  del(.message)
  .elb_status_code = to_int!(parsed.elb_status_code)
  .target_status_code = to_int!(parsed.target_status_code)
  .sent_bytes = to_int!(parsed.sent_bytes)
if .host == "127.0.0.1" {
    .match_chars = "localhost"
} else if .host != "127.0.0.1" {
    .match_chars = "attack_ip"
}   
if .elb_status_code == 200 {
    .str_elb_status = "ok"
} else if .elb_status_code == 404 {
    .str__elb_status = "error"
}
  .extends = {
    "ssl_cipher": .ssl_cipher,
    "ssl_protocol": .ssl_protocol,
}
'''
```

### Vector-Fixed
- **解析配置**

```toml
source = '''
. |= parse_aws_alb_log!(.message)
del(.message)
'''
```

- **解析+转换配置**

```toml
source = '''
  . |= parse_aws_alb_log!(.message)
  del(.message)
  .symbol = .type
  del(.type)
  .elb_status_code    = to_int!(.elb_status_code)
  .target_status_code = to_int!(.target_status_code)
  .sent_bytes         = to_int!(.sent_bytes)

  if .host == "127.0.0.1" {
    .match_chars = "localhost"
  } else {
    .match_chars = "attack_ip"
  }

  if .elb_status_code == 200 {
    .str_elb_status = "ok"
  } else if .elb_status_code == 404 {
    .str_elb_status = "error"
  }

  .extends = {
    "ssl_cipher": .ssl_cipher,
    "ssl_protocol": .ssl_protocol,
  }
'''
```

### Logstash
- **解析配置**

```conf
input {
  file {
    path => ["in_data/medium_aws_411B"]
    start_position => "beginning"
    sincedb_path => "/dev/null"
  }
}

filter {
  dissect {
    mapping => {
      "message" => '%{symbol} %{timestamp} %{elb} %{client_host} %{target_host} %{request_processing_time} %{target_processing_time} %{response_processing_time} %{elb_status_code} %{target_status_code} %{received_bytes} %{sent_bytes} "%{raw_request}" "%{user_agent}" "%{ssl_cipher}" "%{ssl_protocol}" %{target_group_arn} "%{trace_id}" "%{domain_name}" "%{chosen_cert_arn}" %{matched_rule_priority} %{request_creation_time} "%{actions_executed}" "%{redirect_url}" "%{error_reason}" "%{target_port_list}" "%{target_status_code_list}" "%{classification}" "%{classification_reason}" %{traceability_id}'
    }
  }

  dissect {
    mapping => {
      "raw_request" => "%{request_method} %{request_url} %{request_protocol}"
    }
  }

  mutate {
  remove_field => ["message","@timestamp","@version","event","[event][original]","raw_request"]
}
}

output {
  file { path => "/dev/null" codec => "json_lines" }
}
```

- **解析+转换配置**

```conf
input {
  file {
    path => ["in_data/medium_aws_411B"]
    start_position => "beginning"
    sincedb_path => "/dev/null"
    add_field => {
      "src_ip"      => "127.0.0.1"
    }
  }
}

filter {
  #
  # 1) 解析：AWS ALB 全字段 dissect（字段名对齐你现有命名）
  #
   dissect {
    mapping => {
      "message" => '%{symbol} %{timestamp} %{elb} %{client_host} %{target_host} %{request_processing_time} %{target_processing_time} %{response_processing_time} %{elb_status_code} %{target_status_code} %{received_bytes} %{sent_bytes} "%{raw_request}" "%{user_agent}" "%{ssl_cipher}" "%{ssl_protocol}" %{target_group_arn} "%{trace_id}" "%{domain_name}" "%{chosen_cert_arn}" %{matched_rule_priority} %{request_creation_time} "%{actions_executed}" "%{redirect_url}" "%{error_reason}" "%{target_port_list}" "%{target_status_code_list}" "%{classification}" "%{classification_reason}" %{traceability_id}'
    }
  }

  #
  # 2) 解析 raw_request -> request_method / request_url / request_protocol（你原 conf 里就有这一步）
  #
  dissect {
    mapping => {
      "raw_request" => "%{request_method} %{request_url} %{request_protocol}"
    }
    tag_on_failure => ["aws_raw_request_dissect_failure"]
  }

  #
  # 3) 转换：类型对齐 Vector to_int/to_float 思路
  #
    mutate {
    convert => {
      "client_port"              => "integer"
      "target_port"              => "integer"

      "request_processing_time"  => "float"
      "target_processing_time"   => "float"
      "response_processing_time" => "float"

      "elb_status_code"          => "integer"
      "target_status_code"       => "integer"

      "received_bytes"           => "integer"
      "sent_bytes"               => "integer"

      "matched_rule_priority"    => "integer"
    }
  }
  mutate {
    add_field => {
      "[extends][ssl_cipher]"   => "%{ssl_cipher}"
      "[extends][ssl_protocol]" => "%{ssl_protocol}"
    }
  }

  # 2) match_chars：按你“显式注入字段”的手段来判断（推荐用 src_ip）
  # 你如果已经在 input 里 add_field 了 src_ip，这里就能稳定命中 localhost
  if [src_ip] == "127.0.0.1" {
    mutate { add_field => { "match_chars" => "localhost" } }
  } else {
    mutate { add_field => { "match_chars" => "attack_ip" } }
  }

  # 3) str_elb_status：示例映射（按你 Vector 里类似逻辑）
  if [elb_status_code] == 200 {
    mutate { add_field => { "str_elb_status" => "ok" } }
  } else if [elb_status_code] == 404 {
    mutate { add_field => { "str_elb_status" => "not_found" } }
  } else {
    mutate { add_field => { "str_elb_status" => "error" } }
  }

  #
  # 6) 清理：保持输出干净，对齐 benchmark 输出
  #
  mutate {
    remove_field => ["message","raw_request","@timestamp","@version","event","[event][original]"]
  }
}

output {
  file { path => "/dev/null" codec => "json_lines" }
}
```

## 3. Sysmon Log (1K, JSON)

### WarpParse
- **解析配置（WPL）**

```bash
package /sysmon/ {
   rule sysmon {
        (_:pri<<,>>,3*_,_),(_\S\y\s\m\o\n\:,
        json(
            @Id:id,
            @Description/ProcessId:process_id,
            @Level:severity,
            @Opcode:Opcode,
            @ProcessId:ProcessId,
            @Task:Task,
            @ThreadId:ThreadId
            @Version:Version,
            @Description/CommandLine:cmd_line,
            @Description/ParentCommandLine:parent_cmd_line,
            @Description/LogonGuid:logon_guid,
            @Description/LogonId:logon_id,
            @Description/Image:process_path,
            @Description/ParentImage:parent_process_path,
            @Description/ParentProcessGuid:parent_process_guid,
            @Description/ParentProcessId:parent_process_id,
            @Description/ParentUser:parent_process_user,
            @Description/ProcessGuid:process_guid,
            @Description/Company:product_company,
            @Description/Description:process_desc,
            @Description/FileVersion:file_version,
            chars@Description/Hashes:Hashes
            @Description/IntegrityLevel:integrity_level,
            @Description/OriginalFileName:origin_file_name,
            @Description/Product:product_name,
            @Description/RuleName:rule_name,
            @Description/User:user_name,
            chars@Description/UtcTime:occur_time,
            @Description/TerminalSessionId:terminal_session_id,
            @Description/CurrentDirectory:current_dir,
            @Keywords:keywords
            )
        )
    }
   }
```

- **解析+转换配置（WPL + OML）**

```bash
package /sysmon/ {
   rule sysmon {
        (_:pri<<,>>,3*_,_),(_\S\y\s\m\o\n\:,
        json(
            @Id:id,
            @Description/ProcessId:process_id,
            @Level:severity,
            @Opcode:Opcode,
            @ProcessId:ProcessId,
            @Task:Task,
            @ThreadId:ThreadId
            @Version:Version,
            @Description/CommandLine:cmd_line,
            @Description/ParentCommandLine:parent_cmd_line,
            @Description/LogonGuid:logon_guid,
            @Description/LogonId:logon_id,
            @Description/Image:process_path,
            @Description/ParentImage:parent_process_path,
            @Description/ParentProcessGuid:parent_process_guid,
            @Description/ParentProcessId:parent_process_id,
            @Description/ParentUser:parent_process_user,
            @Description/ProcessGuid:process_guid,
            @Description/Company:product_company,
            @Description/Description:process_desc,
            @Description/FileVersion:file_version,
            chars@Description/Hashes:Hashes
            @Description/IntegrityLevel:integrity_level,
            @Description/OriginalFileName:origin_file_name,
            @Description/Product:product_name,
            @Description/RuleName:rule_name,
            @Description/User:user_name,
            chars@Description/UtcTime:occur_time,
            @Description/TerminalSessionId:terminal_session_id,
            @Description/CurrentDirectory:current_dir,
            @Keywords:keywords
            )
        )
    }
   }
```

```bash
name : sysmon
rule : /sysmon/*
---
Id:digit = take(id) ;
LogonId:digit = take(logon_id) ;
enrich_level = match read(option:[severity]) {
    chars(4) => chars(severity);
    chars(3) => chars(normal);
};
extends : obj = object {
    OriginalFileName = read(origin_file_name);
    ParentCommandLine = read(parent_cmd_line);
};
extends_dir = object {
    ParentProcessPath = read(parent_process_path);
    Process_path = read(process_path);
};
match_chars = match read(option:[wp_src_ip]) {
    ip(127.0.0.1) => chars(localhost); 
    !ip(127.0.0.1) => chars(attack_ip); 
};
num_range = match read(option:[Id]) {
    in ( digit(0), digit(1000) ) => read(Id) ;
    _ => digit(0) ;
};
* : auto = read();
```

### Vector-VRL
- **解析配置（VRL）**

```bash
source = '''
  parsed_msg = parse_regex!(.message, r'^[^{]*(?P<body>\{.*)$')
  parsed = parse_regex!(parsed_msg.body, r'(?s)\{"Id":(?P<Id>[^,]+),"Version":(?P<Version>[^,]+),"Level":(?P<Level>[^,]+),"Task":(?P<Task>[^,]+),"Opcode":(?P<Opcode>[^,]+),"Keywords":(?P<Keywords>[^,]+),"RecordId":(?P<RecordId>[^,]+),"ProviderName":"(?P<ProviderName>[^"]*)","ProviderId":"(?P<ProviderId>[^"]*)","LogName":"(?P<LogName>[^"]*)","ProcessId":(?P<ProcessId>[^,]+),"ThreadId":(?P<ThreadId>[^,]+),"MachineName":"(?P<MachineName>[^"]*)","TimeCreated":"(?P<TimeCreated>[^"]*)","ActivityId":(?P<ActivityId>[^,]+),"RelatedActivityId":(?P<RelatedActivityId>[^,]+),"Qualifiers":(?P<Qualifiers>[^,]+),"LevelDisplayName":"(?P<LevelDisplayName>[^"]*)","OpcodeDisplayName":"(?P<OpcodeDisplayName>[^"]*)","TaskDisplayName":"(?P<TaskDisplayName>[^"]*)","Description":\{"RuleName":"(?P<RuleName>[^"]*)","UtcTime":"(?P<UtcTime>[^"]*)","ProcessGuid":"(?P<ProcessGuid>[^"]*)","ProcessId":"(?P<DescProcessId>[^"]*)","Image":"(?P<Image>[^"]*)","FileVersion":"(?P<FileVersion>[^"]*)","Description":"(?P<Description>[^"]*)","Product":"(?P<Product>[^"]*)","Company":"(?P<Company>[^"]*)","OriginalFileName":"(?P<OriginalFileName>[^"]*)","CommandLine":"(?P<CommandLine>[^"]*)","CurrentDirectory":"(?P<CurrentDirectory>[^"]*)","User":"(?P<User>[^"]*)","LogonGuid":"(?P<LogonGuid>[^"]*)","LogonId":"(?P<LogonId>[^"]*)","TerminalSessionId":"(?P<TerminalSessionId>[^"]*)","IntegrityLevel":"(?P<IntegrityLevel>[^"]*)","Hashes":"(?P<Hashes>[^"]*)","ParentProcessGuid":"(?P<ParentProcessGuid>[^"]*)","ParentProcessId":"(?P<ParentProcessId>[^"]*)","ParentImage":"(?P<ParentImage>[^"]*)","ParentCommandLine":"(?P<ParentCommandLine>[^"]*)","ParentUser":"(?P<ParentUser>[^"]*)"\},"DescriptionRawMessage":"(?P<DescriptionRawMessage>[^"]*)"\}$')
  .cmd_line = parsed.CommandLine
  .product_company = parsed.Company
  .process_id = parsed.ProcessId
  .Opcode = parsed.Opcode
  .ProcessId = parsed.ProcessId 
  .Task = parsed.Task
  .ThreadId = parsed.ThreadId
  .Version = parsed.Version
  .current_dir = parsed.CurrentDirectory
  .process_desc = parsed.Description
  .file_version = parsed.FileVersion
  .Hashes = parsed.Hashes
  .process_path = parsed.Image
  .integrity_level = parsed.IntegrityLevel
  .logon_guid = parsed.LogonGuid
  .logon_id = parsed.LogonId
  .origin_file_name = parsed.OriginalFileName
  .parent_cmd_line = parsed.ParentCommandLine
  .parent_process_path = parsed.ParentImage
  .parent_process_guid = parsed.ParentProcessGuid
  .parent_process_id = parsed.ParentProcessId
  .parent_process_user = parsed.ParentUser
  .process_guid = parsed.ProcessGuid
  .product_name = parsed.Product
  .rule_name = parsed.RuleName
  .terminal_session_id = parsed.TerminalSessionId
  .user_name = parsed.User
  .occur_time = parsed.UtcTime
  .DescriptionRawMessage = parsed.DescriptionRawMessage
  .id = parsed.Id
  .keywords = parsed.Keywords
  .severity = parsed.Level
  .LevelDisplayName = parsed.LevelDisplayName
  .LogName = parsed.LogName
  .MachineName = parsed.MachineName
  .OpcodeDisplayName = parsed.OpcodeDisplayName
  .ProviderId = parsed.ProviderId
  .ProviderName = parsed.ProviderName
  .TaskDisplayName = parsed.TaskDisplayName
  .TimeCreated = parsed.TimeCreated
  del(.message)
```

- **解析+转换配置（VRL）**

```toml
source = '''
  parsed_msg = parse_regex!(.message, r'^[^{]*(?P<body>\{.*)$')
  parsed = parse_regex!(parsed_msg.body, r'(?s)\{"Id":(?P<Id>[^,]+),"Version":(?P<Version>[^,]+),"Level":(?P<Level>[^,]+),"Task":(?P<Task>[^,]+),"Opcode":(?P<Opcode>[^,]+),"Keywords":(?P<Keywords>[^,]+),"RecordId":(?P<RecordId>[^,]+),"ProviderName":"(?P<ProviderName>[^"]*)","ProviderId":"(?P<ProviderId>[^"]*)","LogName":"(?P<LogName>[^"]*)","ProcessId":(?P<ProcessId>[^,]+),"ThreadId":(?P<ThreadId>[^,]+),"MachineName":"(?P<MachineName>[^"]*)","TimeCreated":"(?P<TimeCreated>[^"]*)","ActivityId":(?P<ActivityId>[^,]+),"RelatedActivityId":(?P<RelatedActivityId>[^,]+),"Qualifiers":(?P<Qualifiers>[^,]+),"LevelDisplayName":"(?P<LevelDisplayName>[^"]*)","OpcodeDisplayName":"(?P<OpcodeDisplayName>[^"]*)","TaskDisplayName":"(?P<TaskDisplayName>[^"]*)","Description":\{"RuleName":"(?P<RuleName>[^"]*)","UtcTime":"(?P<UtcTime>[^"]*)","ProcessGuid":"(?P<ProcessGuid>[^"]*)","ProcessId":"(?P<DescProcessId>[^"]*)","Image":"(?P<Image>[^"]*)","FileVersion":"(?P<FileVersion>[^"]*)","Description":"(?P<Description>[^"]*)","Product":"(?P<Product>[^"]*)","Company":"(?P<Company>[^"]*)","OriginalFileName":"(?P<OriginalFileName>[^"]*)","CommandLine":"(?P<CommandLine>[^"]*)","CurrentDirectory":"(?P<CurrentDirectory>[^"]*)","User":"(?P<User>[^"]*)","LogonGuid":"(?P<LogonGuid>[^"]*)","LogonId":"(?P<LogonId>[^"]*)","TerminalSessionId":"(?P<TerminalSessionId>[^"]*)","IntegrityLevel":"(?P<IntegrityLevel>[^"]*)","Hashes":"(?P<Hashes>[^"]*)","ParentProcessGuid":"(?P<ParentProcessGuid>[^"]*)","ParentProcessId":"(?P<ParentProcessId>[^"]*)","ParentImage":"(?P<ParentImage>[^"]*)","ParentCommandLine":"(?P<ParentCommandLine>[^"]*)","ParentUser":"(?P<ParentUser>[^"]*)"\},"DescriptionRawMessage":"(?P<DescriptionRawMessage>[^"]*)"\}$')
  .cmd_line = parsed.CommandLine
  .product_company= parsed.Company
  .Opcode = parsed.Opcode
  .process_id = parsed.ProcessId 
  .ProcessId = parsed.ProcessId 
  .Task = parsed.Task
  .ThreadId = parsed.ThreadId
  .Version = parsed.Version
  .current_dir = parsed.CurrentDirectory
  .process_desc = parsed.Description
  .file_version = parsed.FileVersion
  .Hashes = parsed.Hashes
  .process_path = parsed.Image
  .integrity_level = parsed.IntegrityLevel
  .logon_guid = parsed.LogonGuid
  .origin_file_name = parsed.OriginalFileName
  .parent_cmd_line = parsed.ParentCommandLine
  .parent_process_path = parsed.ParentImage
  .parent_process_guid = parsed.ParentProcessGuid
  .parent_process_id = parsed.ParentProcessId
  .parent_process_user = parsed.ParentUser
  .process_guid = parsed.ProcessGuid
  .product_name = parsed.Product
  .rule_name = parsed.RuleName
  .terminal_session_id = parsed.TerminalSessionId
  .user_name = parsed.User
  .occur_time = parsed.UtcTime
  .DescriptionRawMessage = parsed.DescriptionRawMessage
  .keywords = parsed.Keywords
  .severity = parsed.Level
  .LevelDisplayName = parsed.LevelDisplayName
  .LogName = parsed.LogName
  .MachineName = parsed.MachineName
  .OpcodeDisplayName = parsed.OpcodeDisplayName
  .ProviderId = parsed.ProviderId
  .ProviderName = parsed.ProviderName
  .TaskDisplayName = parsed.TaskDisplayName
  .TimeCreated = parsed.TimeCreated
  del(.message)
  .LogonId = to_int!(parsed.LogonId)
  .Id = to_int!(parsed.Id)
if .host == "127.0.0.1" {
    .match_chars = "localhost"
} else if .host != "127.0.0.1" {
    .match_chars = "attack_ip"
}   
if .severity == "4" {
    .enrich_level = "severity"
} else if .Level == "3" {
    .enrich_level = "normal"
} 
.extends = {
    "OriginalFileName": .origin_file_name,
    "ParentCommandLine": .parent_cmd_line,
}
.extends_dir = {
    "ParentProcessPath": .parent_process_path,
    "Process_path": .process_path,
}
.num_range = if .Id >= 0 && .Id <= 1000 {
    .Id
} else {
    0
}
'''
```

### Vector-Fixed
- **解析配置**

```toml
source = '''
  json_str = slice!(.message, start: 57)
  parsed = parse_json!(json_str, max_depth: 2)
  desc = parsed.Description
  .cmd_line            = desc.CommandLine
  .product_company     = desc.Company
  .process_id          = parsed.ProcessId
  .Opcode              = parsed.Opcode
  .ProcessId           = parsed.ProcessId
  .Task                = parsed.Task
  .ThreadId            = parsed.ThreadId
  .Version             = parsed.Version
  .current_dir         = desc.CurrentDirectory
  .process_desc        = desc.Description
  .file_version        = desc.FileVersion
  .Hashes              = desc.Hashes
  .process_path        = desc.Image
  .integrity_level     = desc.IntegrityLevel
  .logon_guid          = desc.LogonGuid
  .logon_id            = desc.LogonId
  .origin_file_name    = desc.OriginalFileName
  .parent_cmd_line     = desc.ParentCommandLine
  .parent_process_path = desc.ParentImage
  .parent_process_guid = desc.ParentProcessGuid
  .parent_process_id   = desc.ParentProcessId
  .parent_process_user = desc.ParentUser
  .process_guid        = desc.ProcessGuid
  .product_name        = desc.Product
  .rule_name           = desc.RuleName
  .terminal_session_id = desc.TerminalSessionId
  .user_name           = desc.User
  .occur_time          = desc.UtcTime
  .DescriptionRawMessage = parsed.DescriptionRawMessage
  .id                   = parsed.Id
  .keywords             = parsed.Keywords
  .severity             = parsed.Level
  .LevelDisplayName     = parsed.LevelDisplayName
  .LogName              = parsed.LogName
  .MachineName          = parsed.MachineName
  .OpcodeDisplayName    = parsed.OpcodeDisplayName
  .ProviderId           = parsed.ProviderId
  .ProviderName         = parsed.ProviderName
  .TaskDisplayName      = parsed.TaskDisplayName
  .TimeCreated          = parsed.TimeCreated
  del(.message)
'''
```

- **解析+转换配置**

```toml
source = '''
  json_str = slice!(.message, start: 57)
  parsed = parse_json!(json_str, max_depth: 2)
  desc = parsed.Description
  .cmd_line            = desc.CommandLine
  .product_company     = desc.Company
  .process_id          = parsed.ProcessId
  .Opcode              = parsed.Opcode
  .ProcessId           = parsed.ProcessId
  .Task                = parsed.Task
  .ThreadId            = parsed.ThreadId
  .Version             = parsed.Version
  .current_dir         = desc.CurrentDirectory
  .process_desc        = desc.Description
  .file_version        = desc.FileVersion
  .Hashes              = desc.Hashes
  .process_path        = desc.Image
  .integrity_level     = desc.IntegrityLevel
  .logon_guid          = desc.LogonGuid
  .logon_id            = desc.LogonId
  .origin_file_name    = desc.OriginalFileName
  .parent_cmd_line     = desc.ParentCommandLine
  .parent_process_path = desc.ParentImage
  .parent_process_guid = desc.ParentProcessGuid
  .parent_process_id   = desc.ParentProcessId
  .parent_process_user = desc.ParentUser
  .process_guid        = desc.ProcessGuid
  .product_name        = desc.Product
  .rule_name           = desc.RuleName
  .terminal_session_id = desc.TerminalSessionId
  .user_name           = desc.User
  .occur_time          = desc.UtcTime
  .DescriptionRawMessage = parsed.DescriptionRawMessage
  .id                   = parsed.Id
  .keywords             = parsed.Keywords
  .severity             = parsed.Level
  .LevelDisplayName     = parsed.LevelDisplayName
  .LogName              = parsed.LogName
  .MachineName          = parsed.MachineName
  .OpcodeDisplayName    = parsed.OpcodeDisplayName
  .ProviderId           = parsed.ProviderId
  .ProviderName         = parsed.ProviderName
  .TaskDisplayName      = parsed.TaskDisplayName
  .TimeCreated          = parsed.TimeCreated
  del(.message)
  .LogonId = to_int!(.logon_id)
  .Id = to_int!(.id)
if .host == "127.0.0.1" {
    .match_chars = "localhost"
} else if .host != "127.0.0.1" {
    .match_chars = "attack_ip"
}   
if .severity == "4" {
    .enrich_level = "severity"
} else if .Level == "3" {
    .enrich_level = "normal"
}
  .extends = {
    "OriginalFileName": .origin_file_name,
    "ParentCommandLine": .parent_cmd_line,
}
  .extends_dir = {
    "ParentProcessPath": .parent_process_path,
    "Process_path": .process_path,
}
  .num_range = if .Id >= 0 && .Id <= 1000 {
    .Id
  } else {
    0
  }
'''
```

### Logstash
- **解析配置**

```conf
input {
  file {
    path => ["in_data/complex_sysmon_986B"]
    start_position => "beginning"
    sincedb_path => "/dev/null"
  }
}

filter {
  dissect {
    mapping => {
      "message" => "<%{?pri}>%{?syslog_month} %{?syslog_day} %{?syslog_time} %{?forwarder} %{?prefix_provider}:%{json_body}"
    }
  }

  json {
    source => "json_body"
  }

  mutate {
    add_field => { "process_id" => "%{ProcessId}" }

    rename => {
      "[Description][RuleName]"        => "rule_name"
      "[Description][UtcTime]"         => "occur_time"
      "[Description][ProcessGuid]"     => "process_guid"
      "[Description][ProcessId]"       => "ProcessId"
      "[Description][Image]"           => "process_path"
      "[Description][FileVersion]"     => "file_version"
      "[Description][Description]"     => "process_desc"
      "[Description][Product]"         => "product_name"
      "[Description][Company]"         => "product_company"
      "[Description][OriginalFileName]"=> "origin_file_name"
      "[Description][CommandLine]"     => "cmd_line"
      "[Description][CurrentDirectory]"=> "current_dir"
      "[Description][User]"            => "user_name"
      "[Description][LogonGuid]"       => "logon_guid"
      "[Description][LogonId]"          => "logon_id"
      "[Description][TerminalSessionId]"=> "terminal_session_id"
      "[Description][IntegrityLevel]"  => "integrity_level"
      "[Description][Hashes]"          => "Hashes"
      "[Description][ParentProcessGuid]"=> "parent_process_guid"
      "[Description][ParentProcessId]" => "parent_process_id"
      "[Description][ParentImage]"     => "parent_process_path"
      "[Description][ParentCommandLine]"=> "parent_cmd_line"
      "[Description][ParentUser]"      => "parent_process_user"

      "Id"        => "id"
      "Level"     => "severity"
      "Keywords"  => "keywords"
    }
  }

  mutate {
    convert => {
      "id"        => "string"
      "severity"  => "string"
      "keywords"  => "string"

      "Opcode"    => "string"
      "Task"      => "string"
      "ThreadId"  => "string"
      "Version"   => "string"
      "ProcessId" => "string"
    }
  }

mutate {
  remove_field => [
    "Description",
    "RecordId",
    "ActivityId",
    "RelatedActivityId",
    "Qualifiers",
    "pri","syslog_month","syslog_day","syslog_time",
    "forwarder","prefix_provider","json_body","message",
    "@timestamp","@version","event","[event][original]"
  ]
}
}

output {
  file { path => "/dev/null" codec => "json_lines" }
}
```

- **解析+转换配置**

```conf
input {
  file {
    path => ["in_data/complex_sysmon_986B"]
    start_position => "beginning"
    sincedb_path => "/dev/null"
    add_field => {
      "src_ip"      => "127.0.0.1"
    }
  }
}

filter {
  # =========================
  # 解析段：完全沿用你现有 sysmon_syslog_to_file.conf 的写法（不改动）
  # =========================
  dissect {
    mapping => {
      "message" => "<%{?pri}>%{?syslog_month} %{?syslog_day} %{?syslog_time} %{?forwarder} %{?prefix_provider}:%{json_body}"
    }
    tag_on_failure => ["sysmon_prefix_dissect_failure"]
  }

  json {
    source => "json_body"
    tag_on_failure => ["sysmon_json_failure"]
  }

  mutate {
    add_field => { "process_id" => "%{ProcessId}" }
    rename => {
      "[Description][RuleName]"         => "rule_name"
      "[Description][UtcTime]"          => "occur_time"
      "[Description][ProcessGuid]"      => "process_guid"
      "[Description][ProcessId]"        => "ProcessId"
      "[Description][Image]"            => "process_path"
      "[Description][FileVersion]"      => "file_version"
      "[Description][Description]"      => "process_desc"
      "[Description][Product]"          => "product_name"
      "[Description][Company]"          => "product_company"
      "[Description][OriginalFileName]" => "origin_file_name"
      "[Description][CommandLine]"      => "cmd_line"
      "[Description][CurrentDirectory]" => "current_dir"
      "[Description][User]"             => "user_name"
      "[Description][LogonGuid]"        => "logon_guid"
      "[Description][LogonId]"          => "logon_id"
      "[Description][TerminalSessionId]"=> "terminal_session_id"
      "[Description][IntegrityLevel]"   => "integrity_level"
      "[Description][Hashes]"           => "Hashes"
      "[Description][ParentProcessGuid]"=> "parent_process_guid"
      "[Description][ParentProcessId]"  => "parent_process_id"
      "[Description][ParentImage]"      => "parent_process_path"
      "[Description][ParentCommandLine]"=> "parent_cmd_line"
      "[Description][ParentUser]"       => "parent_process_user"
      "Id"                              => "id"
      "Level"                           => "severity"
      "Keywords"                        => "keywords"
    }
  }

  mutate {
    convert => {
      "id"        => "string"
      "severity"  => "string"
      "keywords"  => "string"
      "Opcode"    => "string"
      "Task"      => "string"
      "ThreadId"  => "string"
      "Version"   => "string"
      "ProcessId" => "string"
    }
  }

 # =========================
# Sysmon Transform（对齐你 Vector 逻辑）
# 插入位置：解析完成后 / remove_field 前
# =========================

# 0)（建议）保证数值比较可用：Id 转 integer（否则范围判断会变成字符串比较）
mutate {
  convert => {
    "Id" => "integer"
  }
}

# 1) match_chars：对齐 Vector 的 host 判断
# Vector: if .host == "127.0.0.1" => localhost else attack_ip
if [src_ip] == "127.0.0.1" {
  mutate { add_field => { "match_chars" => "localhost" } }
} else {
  mutate { add_field => { "match_chars" => "attack_ip" } }
}

# 2) enrich_level：对齐 Vector 逻辑
# Vector:
# if .severity == "4" => "severity"
# else if .Level == "3" => "normal"
if [severity] == "4" or [Level] == "4" {
  mutate { add_field => { "enrich_level" => "severity" } }
} else if [Level] == "3" or [severity] == "3" {
  mutate { add_field => { "enrich_level" => "normal" } }
}

# 3) extends：对齐 Vector 的聚合对象
# .extends = { "OriginalFileName": .origin_file_name, "ParentCommandLine": .parent_cmd_line }
mutate {
  add_field => {
    "[extends][OriginalFileName]"  => "%{origin_file_name}"
    "[extends][ParentCommandLine]" => "%{parent_cmd_line}"
  }
}

# 4) extends_dir：第二个聚合对象（对齐 Vector）
# .extends_dir = { "ParentProcessPath": .parent_process_path, "Process_path": .process_path }
mutate {
  add_field => {
    "[extends_dir][ParentProcessPath]" => "%{parent_process_path}"
    "[extends_dir][Process_path]"      => "%{process_path}"
  }
}

# 5) num_range：范围判断（对齐 Vector）
# .num_range = if .Id >= 0 && .Id <= 1000 { .Id } else { 0 }
if [Id] and [Id] >= 0 and [Id] <= 1000 {
  mutate { add_field => { "num_range" => "%{Id}" } }
} else {
  mutate { add_field => { "num_range" => "0" } }
}

mutate { convert => { "num_range" => "integer" } }
  mutate {
    remove_field => [
      "Description",
      "RecordId",
      "ActivityId",
      "RelatedActivityId",
      "Qualifiers",
      "pri","syslog_month","syslog_day","syslog_time",
      "forwarder","prefix_provider","json_body","message",
      "@timestamp","@version","event","[event][original]"
    ]
  }
}

output {
  file { path => "/dev/null" codec => "json_lines" }
}
```

## 4. APT Threat Log (3K)

### WarpParse
- **解析配置（WPL）**

```bash
package /apt/ {
   rule apt {
        (
            _\#,
            time:timestamp,
            _,
            chars:Hostname,
            _\%\%, 
            chars:ModuleName\/,
            chars:SeverityHeader\/,
            symbol(ANTI-APT)\(,
            chars:type\),
            chars:Count<[,]>,
            _\:,
            chars:Content\(,
        ),
        (
            kv(chars@SyslogId),
            kv(chars@VSys),
            kv(chars@Policy),
            kv(chars@SrcIp),
            kv(chars@DstIp),
            kv(chars@SrcPort),
            kv(chars@DstPort),
            kv(chars@SrcZone),
            kv(chars@DstZone),
            kv(chars@User),
            kv(chars@Protocol),
            kv(chars@Application),
            kv(chars@Profile),
            kv(chars@Direction),
            kv(chars@ThreatType),
            kv(chars@ThreatName),
            kv(chars@Action),
            kv(chars@FileType),
            kv(chars@Hash)\),
        )\,
    }
   }
```

- **解析+转换配置（WPL + OML）**

```bash
package /apt/ {
   rule apt {
        (
            _\#,
            time:timestamp,
            _,
            chars:Hostname,
            _\%\%, 
            chars:ModuleName\/,
            chars:SeverityHeader\/,
            symbol(ANTI-APT)\(,
            chars:type\),
            chars:Count<[,]>,
            _\:,
            chars:Content\(,
        ),
        (
            kv(chars@SyslogId),
            kv(chars@VSys),
            kv(chars@Policy),
            kv(chars@SrcIp),
            kv(chars@DstIp),
            kv(chars@SrcPort),
            kv(chars@DstPort),
            kv(chars@SrcZone),
            kv(chars@DstZone),
            kv(chars@User),
            kv(chars@Protocol),
            kv(chars@Application),
            kv(chars@Profile),
            kv(chars@Direction),
            kv(chars@ThreatType),
            kv(chars@ThreatName),
            kv(chars@Action),
            kv(chars@FileType),
            kv(chars@Hash)\),
        )\,
    }
   }
```

```bash
name : apt
rule : /apt/*
---
count:digit = take(Count) ;
severity:digit = take(SeverityHeader) ;
match_chars = match read(option:[wp_src_ip]) {
    ip(127.0.0.1) => chars(localhost); 
    !ip(127.0.0.1) => chars(attack_ip); 
};
num_range = match read(option:[count]) {
    in ( digit(0), digit(1000) ) => read(count) ;
    _ => digit(0) ;
};
src_system_log_type = match read(option:[type]) {
    chars(l) => chars(日志信息);
    chars(s) => chars(安全日志信息);
};
extends_ip : obj = object {
    DstIp = read(DstIp);
    SrcIp = read(SrcIp);
};
extends_info : obj = object {
    hostname = read(Hostname);
    source_type = read(wp_src_key)
};
* : auto = read();
```

### Vector-VRL
- **解析配置（VRL）**

```bash
source = '''
  parsed_log = parse_regex!(.message, r'(?s)^#(?P<timestamp>\w+\s+\d+\s+\d{4}\s+\d{2}:\d{2}:\d{2}[+-]\d{2}:\d{2})\s+(?P<hostname>\S+)\s+%%(?P<ModuleName>\d+[^/]+)/(?P<SeverityHeader>\d+)/(?P<symbol>[^(]+)\((?P<type>[^)]+)\)\[(?P<count>\d+)\]:\s*(?P<content>[^()]+?)\s*\(SyslogId=(?P<SyslogId>[^,]+),\s+VSys="(?P<VSys>[^"]+)",\s+Policy="(?P<Policy>[^"]+),\s+SrcIp=(?P<SrcIp>[^,]+),\s+DstIp=(?P<DstIp>[^,]+),\s+SrcPort=(?P<SrcPort>[^,]+),\s+DstPort=(?P<DstPort>[^,]+),\s+SrcZone=(?P<SrcZone>[^,]+),\s+DstZone=(?P<DstZone>[^,]+),\s+User="(?P<User>[^"]+)",\s+Protocol=(?P<Protocol>[^,]+),\s+Application="(?P<Application>[^"]+)",\s+Profile="(?P<Profile>[^"]+)",\s+Direction=(?P<Direction>[^,]+),\s+ThreatType=(?P<ThreatType>[^,]+),\s+ThreatName=(?P<ThreatName>[^,]+),\s+Action=(?P<Action>[^,]+),\s+FileType=(?P<FileType>[^,]+),\s+Hash=(?P<Hash>.*)\)$')
  .Hostname = parsed_log.hostname
  .SrcPort = parsed_log.SrcPort
  .SeverityHeader = parsed_log.SeverityHeader
  .type = parsed_log.type
  .Count = parsed_log.count
  .Content = parsed_log.content
  .VSys = parsed_log.VSys
  .DstPort = parsed_log.DstPort
  .Policy = parsed_log.Policy
  .SrcIp = parsed_log.SrcIp
  .DstIp = parsed_log.DstIp
  .SrcZone = parsed_log.SrcZone
  .DstZone = parsed_log.DstZone
  .User = parsed_log.User
  .Protocol = parsed_log.Protocol
  .ModuleName = parsed_log.ModuleName
  .symbol = parsed_log.symbol
  .timestamp = parsed_log.timestamp
  .SyslogId = parsed_log.SyslogId
  .Application = parsed_log.Application
  .Profile = parsed_log.Profile
  .Direction = parsed_log.Direction
  .ThreatType = parsed_log.ThreatType
  .ThreatName = parsed_log.ThreatName
  .Action = parsed_log.Action
  .FileType = parsed_log.FileType
  .Hash = parsed_log.Hash
  del(.message)
'''
```

- **解析+转换配置（VRL）**

```toml
source = '''
parsed_log = parse_regex!(.message, r'(?s)^#(?P<timestamp>\w+\s+\d+\s+\d{4}\s+\d{2}:\d{2}:\d{2}[+-]\d{2}:\d{2})\s+(?P<hostname>\S+)\s+%%(?P<ModuleName>\d+[^/]+)/(?P<SeverityHeader>\d+)/(?P<symbol>[^(]+)\((?P<type>[^)]+)\)\[(?P<count>\d+)\]:\s*(?P<content>[^()]+?)\s*\(SyslogId=(?P<SyslogId>[^,]+),\s+VSys="(?P<VSys>[^"]+)",\s+Policy="(?P<Policy>[^"]+)",\s+SrcIp=(?P<SrcIp>[^,]+),\s+DstIp=(?P<DstIp>[^,]+),\s+SrcPort=(?P<SrcPort>[^,]+),\s+DstPort=(?P<DstPort>[^,]+),\s+SrcZone=(?P<SrcZone>[^,]+),\s+DstZone=(?P<DstZone>[^,]+),\s+User="(?P<User>[^"]+)",\s+Protocol=(?P<Protocol>[^,]+),\s+Application="(?P<Application>[^"]+)",\s+Profile="(?P<Profile>[^"]+)",\s+Direction=(?P<Direction>[^,]+),\s+ThreatType=(?P<ThreatType>[^,]+),\s+ThreatName=(?P<ThreatName>[^,]+),\s+Action=(?P<Action>[^,]+),\s+FileType=(?P<FileType>[^,]+),\s+Hash=(?P<Hash>.*)\)$')
  .Hostname = parsed_log.hostname
  .SrcPort = parsed_log.SrcPort
  .SeverityHeader = parsed_log.SeverityHeader
  .type = parsed_log.type
  .Content = parsed_log.content
  .VSys = parsed_log.VSys
  .DstPort = parsed_log.DstPort
  .Policy = parsed_log.Policy
  .SrcIp = parsed_log.SrcIp
  .DstIp = parsed_log.DstIp
  .SrcZone = parsed_log.SrcZone
  .DstZone = parsed_log.DstZone
  .User = parsed_log.User
  .Protocol = parsed_log.Protocol
  .ModuleName = parsed_log.ModuleName
  .symbol = parsed_log.symbol
  .timestamp = parsed_log.timestamp
  .SyslogId = parsed_log.SyslogId
  .Application = parsed_log.Application
  .Profile = parsed_log.Profile
  .Direction = parsed_log.Direction
  .ThreatType = parsed_log.ThreatType
  .ThreatName = parsed_log.ThreatName
  .Action = parsed_log.Action
  .FileType = parsed_log.FileType
  .Hash = parsed_log.Hash
  del(.message)
.severity = to_int!(parsed_log.SeverityHeader)
.count = to_int!(parsed_log.count)
if .host == "127.0.0.1" {
    .match_chars = "localhost"
} else if .host != "127.0.0.1" {
    .match_chars = "attack_ip"
}  
if .type == "l" {
.src_system_log_type = "日志信息"
} else if .type == "s" {
.src_system_log_type = "安全日志信息"
}
.extends_ip = {
    "DstIp": .DstIp,
    "SrcIp": .SrcIp,
}
.extends_info = {
    "hostname": .Hostname,
    "source_type": .source_type,
}
.num_range = if .count >= 0 && .count <= 1000 {
    .count
} else {
    0
}
'''
```

### Vector-Fixed
- **解析配置**

```toml
source = '''
  .|= parse_regex!(.message, r'(?s)^#(?P<timestamp>\w+\s+\d+\s+\d{4}\s+\d{2}:\d{2}:\d{2}[+-]\d{2}:\d{2})\s+(?P<Hostname>\S+)\s+%%(?P<ModuleName>\d+[^/]+)/(?P<SeverityHeader>\d+)/(?P<symbol>[^()]+)\((?P<type>[^)]+)\)\[(?P<Count>\d+)\]:\s*(?P<Content>[^()]+?)\s*\(SyslogId=(?P<SyslogId>[^,]+),\s+VSys="(?P<VSys>[^"]+)",\s+Policy="(?P<Policy>[^"]+)",\s+SrcIp=(?P<SrcIp>[^,]+),\s+DstIp=(?P<DstIp>[^,]+),\s+SrcPort=(?P<SrcPort>[^,]+),\s+DstPort=(?P<DstPort>[^,]+),\s+SrcZone=(?P<SrcZone>[^,]+),\s+DstZone=(?P<DstZone>[^,]+),\s+User="(?P<User>[^"]+)",\s+Protocol=(?P<Protocol>[^,]+),\s+Application="(?P<Application>[^"]+)",\s+Profile="(?P<Profile>[^"]+)",\s+Direction=(?P<Direction>[^,]+),\s+ThreatType=(?P<ThreatType>[^,]+),\s+ThreatName=(?P<ThreatName>[^,]+),\s+Action=(?P<Action>[^,]+),\s+FileType=(?P<FileType>[^,]+),\s+Hash=(?P<Hash>.*)\)$')
  del(.message)
'''
```

- **解析+转换配置**

```toml
source = '''
  .|= parse_regex!(.message, r'(?s)^#(?P<timestamp>\w+\s+\d+\s+\d{4}\s+\d{2}:\d{2}:\d{2}[+-]\d{2}:\d{2})\s+(?P<Hostname>\S+)\s+%%(?P<ModuleName>\d+[^/]+)/(?P<SeverityHeader>\d+)/(?P<symbol>[^()]+)\((?P<type>[^)]+)\)\[(?P<Count>\d+)\]:\s*(?P<Content>[^()]+?)\s*\(SyslogId=(?P<SyslogId>[^,]+),\s+VSys="(?P<VSys>[^"]+)",\s+Policy="(?P<Policy>[^"]+)",\s+SrcIp=(?P<SrcIp>[^,]+),\s+DstIp=(?P<DstIp>[^,]+),\s+SrcPort=(?P<SrcPort>[^,]+),\s+DstPort=(?P<DstPort>[^,]+),\s+SrcZone=(?P<SrcZone>[^,]+),\s+DstZone=(?P<DstZone>[^,]+),\s+User="(?P<User>[^"]+)",\s+Protocol=(?P<Protocol>[^,]+),\s+Application="(?P<Application>[^"]+)",\s+Profile="(?P<Profile>[^"]+)",\s+Direction=(?P<Direction>[^,]+),\s+ThreatType=(?P<ThreatType>[^,]+),\s+ThreatName=(?P<ThreatName>[^,]+),\s+Action=(?P<Action>[^,]+),\s+FileType=(?P<FileType>[^,]+),\s+Hash=(?P<Hash>.*)\)$')
  del(.message)
.severity = to_int!(.SeverityHeader)
.Count = to_int!(.Count)
if .host == "127.0.0.1" {
    .match_chars = "localhost"
} else if .host != "127.0.0.1" {
    .match_chars = "attack_ip"
}  
if .type == "l" {
.src_system_log_type = "日志信息"
} else if .type == "s" {
.src_system_log_type = "安全日志信息"
}
.extends_ip = {
    "DstIp": .DstIp,
    "SrcIp": .SrcIp,
}
.extends_info = {
    "hostname": .Hostname,
    "source_type": .source_type,
}
.num_range = if .Count >= 0 && .Count <= 1000 {
    .Count
} else {
    0
}
'''
```

### Logstash
- **解析配置**

```conf
input {
  file {
    path => ["in_data/final_apt_3547B"]
    start_position => "beginning"
    sincedb_path => "/dev/null"
  }
}

filter {

 mutate { copy => { "message" => "raw" } }

  mutate {
    gsub => [ "raw", "^#", "" ]
  }

  grok {
    match => {
      "raw" => [
        "^(?<timestamp>[A-Za-z]{3}\s+\d{1,2}\s+\d{4}\s+\d{2}:\d{2}:\d{2}\+\d{2}:\d{2})\s+(?<Hostname>\S+)\s+%%(?<ModuleName>[^/]+)/(?<SeverityHeader>\d+)/(?<symbol>[^(]+)\((?<type>[^)]+)\)\[(?<Count>\d+)\]:\s+(?<Content>.*?)\s+\((?<kv_pairs>.*)\)\s*$"
      ]
    }
    tag_on_failure => ["_grokfailure"]
  }

  kv {
    source => "kv_pairs"
    target => ""
    value_split => "="
    field_split_pattern => ", (?=[A-Za-z][A-Za-z0-9_]*=)"
    trim_key => " "
    trim_value => " \""
    remove_char_value => "\""
  }

  if [ExtraInfo] and [Hash] {

  mutate {
    gsub => [
      "ExtraInfo", "\\\\\"", "\""
    ]
  }

  mutate {
    replace => { "Hash" => "%{Hash}, ExtraInfo=\"%{ExtraInfo}\"" }
    remove_field => ["ExtraInfo"]
  }
}

  mutate {
    remove_field => ["raw", "kv_pairs"]
  }

  mutate {
    remove_field => ["@timestamp", "@version", "[event]","message"]
  }

}


output {
  file { path => "/dev/null" codec => "json_lines" }
}
```

- **解析+转换配置**

```conf
input {
  file {
    path => ["in_data/final_apt_3547B"]
    start_position => "beginning"
    sincedb_path => "/dev/null"
  }
}

filter {


 mutate { copy => { "message" => "raw" } }

  mutate {
    gsub => [ "raw", "^#", "" ]
  }


  grok {
    match => {
      "raw" => [
        "^(?<timestamp>[A-Za-z]{3}\s+\d{1,2}\s+\d{4}\s+\d{2}:\d{2}:\d{2}\+\d{2}:\d{2})\s+(?<Hostname>\S+)\s+%%(?<ModuleName>[^/]+)/(?<SeverityHeader>\d+)/(?<symbol>[^(]+)\((?<type>[^)]+)\)\[(?<Count>\d+)\]:\s+(?<Content>.*?)\s+\((?<kv_pairs>.*)\)\s*$"
      ]
    }
    tag_on_failure => ["_grokfailure"]
  }


  kv {
    source => "kv_pairs"
    target => ""
    value_split => "="
    field_split_pattern => ", (?=[A-Za-z][A-Za-z0-9_]*=)"
    trim_key => " "
    trim_value => " \""
    remove_char_value => "\""
  }

  if [ExtraInfo] and [Hash] {

  mutate {
    gsub => [
      "ExtraInfo", "\\\\\"", "\""
    ]
  }

  mutate {
    replace => { "Hash" => "%{Hash}, ExtraInfo=\"%{ExtraInfo}\"" }
    remove_field => ["ExtraInfo"]
  }
}


  mutate {
    remove_field => ["raw", "kv_pairs"]
  }
  # =========================
# APT Transform（对齐 Vector 转换逻辑）
# 插入位置：APT 解析完成后 / remove_field 之前
# =========================

# 1) severity / Count 转数值（对齐 to_int!）
mutate {
  convert => {
    "SeverityHeader" => "integer"
    "Count"          => "integer"
  }
}

# Vector: .severity = to_int!(.SeverityHeader)
mutate {
  add_field => { "severity" => "%{SeverityHeader}" }
}
mutate { convert => { "severity" => "integer" } }

# 2) match_chars（对齐 Vector 的 host 判断）
if [src_ip] == "127.0.0.1" {
  mutate { add_field => { "match_chars" => "localhost" } }
} else {
  mutate { add_field => { "match_chars" => "attack_ip" } }
}

# 3) src_system_log_type（对齐 Vector：type l/s）
if [type] == "l" {
  mutate { add_field => { "src_system_log_type" => "日志信息" } }
} else if [type] == "s" {
  mutate { add_field => { "src_system_log_type" => "安全日志信息" } }
}

# 4) 聚合字段 extends_ip（对齐 Vector）
mutate {
  add_field => {
    "[extends_ip][DstIp]" => "%{DstIp}"
    "[extends_ip][SrcIp]" => "%{SrcIp}"
  }
}

# 5) 聚合字段 extends_info（对齐 Vector）
mutate {
  add_field => {
    "[extends_info][hostname]"    => "%{Hostname}"
    "[extends_info][source_type]" => "%{source_type}"
  }
}

# 6) num_range：Count 范围判断（对齐 Vector）
if [Count] and [Count] >= 0 and [Count] <= 1000 {
  mutate { add_field => { "num_range" => "%{Count}" } }
} else {
  mutate { add_field => { "num_range" => "0" } }
}
mutate { convert => { "num_range" => "integer" } }

  mutate {
    remove_field => ["@timestamp", "@version", "[event]","message"]
  }

}


output {
  file { path => "/dev/null" codec => "json_lines" }
}
```
