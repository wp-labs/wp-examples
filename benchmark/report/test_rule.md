# Rule Definitions

本文档汇总了测试中使用的解析与解析+转换规则，按日志类型与引擎归档。

## 1. Nginx Access Log (239B)

### WarpParse
- **解析配置（WPL）**

```bash
package /nginx/ {
   rule nginx {
        (ip:sip,2*_,chars:timestamp<[,]>,http/request:http_request",chars:status,chars:size,chars:referer",http/agent:http_agent",_")
   }
}
```

- **解析+转换配置（WPL + OML）**

```bash
package /nginx/ {
   rule nginx {
        (ip:sip,2*_,chars:timestamp<[,]>,http/request:http_request",chars:status,chars:size,chars:referer",http/agent:http_agent",_")
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
```

- **解析+转换配置**

```conf
filter {
  dissect {
    mapping => {
      "message" => '%{sip} - - [%{timestamp}] "%{http_request}" %{status} %{size} "%{referer}" "%{http_agent}"'
    }
  }

  mutate {
    convert => {
      "status" => "integer"
      "size"   => "integer"
    }
  }
  
  if [src_ip] == "127.0.0.1" {
    mutate { add_field => { "match_chars" => "localhost" } }
  } else {
    mutate { add_field => { "match_chars" => "attack_ip" } }
  }

  if [status] == 200 {
    mutate { add_field => { "str_status" => "OK" } }
  } else if [status] == 500 {
    mutate { add_field => { "str_status" => "Internal Server Error" } }
  } 

  mutate {
    remove_field => ["message", "@timestamp", "@version", "event", "[event][original]"]
  }
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
  . |= parse_regex!(.message, r'^(?P<symbol>\S+) (?P<timestamp>\S+) (?P<elb>\S+) (?P<client_host>\S+) (?P<target_host>\S+) (?P<request_processing_time>[-\d\.]+) (?P<target_processing_time>[-\d\.]+) (?P<response_processing_time>[-\d\.]+) (?P<elb_status_code>\S+) (?P<target_status_code>\S+) (?P<received_bytes>\d+) (?P<sent_bytes>\d+) "(?P<request_method>\S+) (?P<request_url>[^ ]+) (?P<request_protocol>[^"]+)" "(?P<user_agent>[^"]*)" "(?P<ssl_cipher>[^"]*)" "(?P<ssl_protocol>[^"]*)" (?P<target_group_arn>\S+) "(?P<trace_id>[^"]*)" "(?P<domain_name>[^"]*)" "(?P<chosen_cert_arn>[^"]*)" (?P<matched_rule_priority>\S+) (?P<request_creation_time>\S+) "(?P<actions_executed>[^"]*)" "(?P<redirect_url>[^"]*)" "(?P<error_reason>[^"]*)" "(?P<target_port_list>[^"]*)" "(?P<target_status_code_list>[^"]*)" "(?P<classification>[^"]*)" "(?P<classification_reason>[^"]*)" (?P<traceability_id>\S+)$')
  del(.message)
'''
```

- **解析+转换配置（VRL）**

```toml
source = '''
  . |= parse_regex!(.message, r'^(?P<symbol>\S+) (?P<timestamp>\S+) (?P<elb>\S+) (?P<client_host>\S+) (?P<target_host>\S+) (?P<request_processing_time>[-\d\.]+) (?P<target_processing_time>[-\d\.]+) (?P<response_processing_time>[-\d\.]+) (?P<elb_status_code>\S+) (?P<target_status_code>\S+) (?P<received_bytes>\d+) (?P<sent_bytes>\d+) "(?P<request_method>\S+) (?P<request_url>[^ ]+) (?P<request_protocol>[^"]+)" "(?P<user_agent>[^"]*)" "(?P<ssl_cipher>[^"]*)" "(?P<ssl_protocol>[^"]*)" (?P<target_group_arn>\S+) "(?P<trace_id>[^"]*)" "(?P<domain_name>[^"]*)" "(?P<chosen_cert_arn>[^"]*)" (?P<matched_rule_priority>\S+) (?P<request_creation_time>\S+) "(?P<actions_executed>[^"]*)" "(?P<redirect_url>[^"]*)" "(?P<error_reason>[^"]*)" "(?P<target_port_list>[^"]*)" "(?P<target_status_code_list>[^"]*)" "(?P<classification>[^"]*)" "(?P<classification_reason>[^"]*)" (?P<traceability_id>\S+)$')
  del(.message)
if .host == "127.0.0.1" {
    .match_chars = "localhost"
} else if .host != "127.0.0.1" {
    .match_chars = "attack_ip"
}   
if .elb_status_code == "200" {
    .str_elb_status = "ok"
} else if .elb_status_code == "404" {
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
```

- **解析+转换配置**

```conf
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
    tag_on_failure => ["aws_raw_request_dissect_failure"]
  }

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

  if [src_ip] == "127.0.0.1" {
    mutate { add_field => { "match_chars" => "localhost" } }
  } else {
    mutate { add_field => { "match_chars" => "attack_ip" } }
  }

  if [elb_status_code] == 200 {
    mutate { add_field => { "str_elb_status" => "ok" } }
  } else if [elb_status_code] == 404 {
    mutate { add_field => { "str_elb_status" => "not_found" } }
  } else {
    mutate { add_field => { "str_elb_status" => "error" } }
  }

  mutate {
    remove_field => ["message","raw_request","@timestamp","@version","event","[event][original]"]
  }
}
```

## 3. Firewall Log (1K, KV)

### WarpParse
- **解析配置（WPL）**

```bash
package /firewall/{
    rule firewall{
        (
          chars:timestamp\S,
          2*_,
          kv()| (*kv()\|),
        )
    }
}
```

- **解析+转换配置（WPL + OML）**

```bash
package /firewall/{
    rule firewall{
        (
          chars:timestamp\S,
          2*_,
          kv()| (*kv()\|),
        )
    }
}
```

```bash
name : /oml/firewall
rule : /firewall/*
---
ipVersion:digit = take(ipVersion) ;
packetCount:digit = take(packetCount) ;
enrich_level = match read(option:[proto]) {
    chars(UDP) => chars(0);
    chars(TCP) => chars(1);
};
extends : obj = object {
    srcIP = read(srcIP);
    srcPort = read(srcPort);
};
extends_dir = object {
    url = read(url);
    urlCategory = read(urlCategory);
};
match_chars = match read(option:[srcIP]) {
    chars(10.17.34.12) => chars(internal); 
    !chars(10.17.34.12) => chars(external); 
};
num_range = match read(option:[ipVersion]) {
    in ( digit(0), digit(1000) ) => read(ipVersion) ;
    _ => digit(0) ;
};
* : auto = read();

```

### Vector-VRL
- **解析配置（VRL）**

```bash
source = '''
raw = to_string!(.message)
m = parse_regex!(raw,r'^(?P<ts>\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})\s+(?P<severity>\S+)\s+(?P<tz>[+-]\d{2}:\d{2})\s+(?P<label>Block|Allow|Drop|Reject):\s+(?P<kv>.*)$')
.timestamp = m.ts
. |= parse_key_value!(m.kv,field_delimiter: "|",key_value_delimiter: "=")
del(.message)
'''
```

- **解析+转换配置（VRL）**

```toml
source = '''
raw = to_string!(.message)
m = parse_regex!(raw,r'^(?P<ts>\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})\s+(?P<severity>\S+)\s+(?P<tz>[+-]\d{2}:\d{2})\s+(?P<label>Block|Allow|Drop|Reject):\s+(?P<kv>.*)$')
.timestamp = m.ts
. |= parse_key_value!(m.kv,field_delimiter: "|",key_value_delimiter: "=")

.ipVersion = to_int!(.ipVersion)
.packetCount = to_int!(.packetCount)           
if .proto == "UDP" {
    .enrich_level = "0"
} else if .host != "TCP" {
    .enrich_level = "1"
}   
.extends = {
    "srcIP": .srcIP,
    "srcPort": .srcPort,
}
.extends_dir = {
    "url": .url,
    "urlCategory": .urlCategory,
}
if .srcIP == "10.17.34.12" {
    .match_chars = "internal"
} else if .srcIP != "10.17.34.12"{
    .match_chars = "external"
} 
.num_range = if .ipVersion >= 0 && .ipVersion <= 1000 {
    .ipVersion
} else {
    0
}

del(.message)
'''
```

### Logstash
- **解析配置**

```conf
filter {
  grok {
    match => {
      "message" => [
        "^(?<timestamp>\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}) %{WORD:severity} (?<tz>[+-]\d{2}:\d{2}) %{WORD:label}: %{GREEDYDATA:body}$"
      ]
    }
  }

  kv {
    source => "body"
    field_split => "|"
    value_split => "="
    trim_key => " "
    trim_value => " "
    allow_empty_values => true
  }

  mutate {
    remove_field => [
      "severity","tz","label","body","message","@version","host","event"
    ]
  }
}
```

- **解析+转换配置**

```conf
filter {
  grok {
    match => {
      "message" => [
        "^(?<timestamp>\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}) %{WORD:severity} (?<tz>[+-]\d{2}:\d{2}) %{WORD:label}: %{GREEDYDATA:body}$"
      ]
    }
  }

  kv {
    source => "body"
    field_split => "|"
    value_split => "="
    trim_key => " "
    trim_value => " "
    allow_empty_values => true
  }
  mutate {
  convert => {
    "ipVersion" => "integer"
    "packetCount" => "integer"

  }
}
if [proto] == "UDP"  {
  mutate { add_field => { "enrich_level" => "0" } }
} else if [proto] == "TCP" {
  mutate { add_field => { "enrich_level" => "1" } }
}
mutate {
  add_field => {
    "[extends][srcIP]"  => "%{srcIP}"
    "[extends][srcPort]" => "%{srcPort}"
  }
}
mutate {
  add_field => {
    "[extends_dir][url]" => "%{url}"
    "[extends_dir][urlCategory]" => "%{urlCategory}"
  }
}
if [srcIP] == "10.17.34.12" {
  mutate { add_field => { "match_chars" => "internal" } }
} else {
  mutate { add_field => { "match_chars" => "external" } }
}
if [ipVersion] and [ipVersion] >= 0 and [ipVersion] <= 1000 {
  mutate { add_field => { "num_range" => "%{ipVersion}" } }
} else {
  mutate { add_field => { "num_range" => "0" } }
}
  mutate {
    remove_field => [
      "severity",
      "tz",
      "label",
      "body",
      "message",
      "@version",
      "host",
      "event"
    ]
  }
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
  . |= parse_regex!(.message, r'(?s)^#(?P<timestamp>\w+\s+\d+\s+\d{4}\s+\d{2}:\d{2}:\d{2}[+-]\d{2}:\d{2})\s+(?P<Hostname>\S+)\s+%%(?P<ModuleName>\d+[^/]+)/(?P<SeverityHeader>\d+)/(?P<symbol>[^(]+)\((?P<type>[^)]+)\)\[(?P<Count>\d+)\]:\s*(?P<Content>[^()]+?)\s*\(SyslogId=(?P<SyslogId>[^,]+),\s+VSys="(?P<VSys>[^"]+)",\s+Policy="(?P<Policy>[^"]+)",\s+SrcIp=(?P<SrcIp>[^,]+),\s+DstIp=(?P<DstIp>[^,]+),\s+SrcPort=(?P<SrcPort>[^,]+),\s+DstPort=(?P<DstPort>[^,]+),\s+SrcZone=(?P<SrcZone>[^,]+),\s+DstZone=(?P<DstZone>[^,]+),\s+User="(?P<User>[^"]+)",\s+Protocol=(?P<Protocol>[^,]+),\s+Application="(?P<Application>[^"]+)",\s+Profile="(?P<Profile>[^"]+)",\s+Direction=(?P<Direction>[^,]+),\s+ThreatType=(?P<ThreatType>[^,]+),\s+ThreatName=(?P<ThreatName>[^,]+),\s+Action=(?P<Action>[^,]+),\s+FileType=(?P<FileType>[^,]+),\s+Hash=(?P<Hash>.*)\)$')
  del(.message)
'''
```

- **解析+转换配置（VRL）**

```toml
source = '''
  . |= parse_regex!(.message, r'(?s)^#(?P<timestamp>\w+\s+\d+\s+\d{4}\s+\d{2}:\d{2}:\d{2}[+-]\d{2}:\d{2})\s+(?P<Hostname>\S+)\s+%%(?P<ModuleName>\d+[^/]+)/(?P<SeverityHeader>\d+)/(?P<symbol>[^(]+)\((?P<type>[^)]+)\)\[(?P<Count>\d+)\]:\s*(?P<Content>[^()]+?)\s*\(SyslogId=(?P<SyslogId>[^,]+),\s+VSys="(?P<VSys>[^"]+)",\s+Policy="(?P<Policy>[^"]+)",\s+SrcIp=(?P<SrcIp>[^,]+),\s+DstIp=(?P<DstIp>[^,]+),\s+SrcPort=(?P<SrcPort>[^,]+),\s+DstPort=(?P<DstPort>[^,]+),\s+SrcZone=(?P<SrcZone>[^,]+),\s+DstZone=(?P<DstZone>[^,]+),\s+User="(?P<User>[^"]+)",\s+Protocol=(?P<Protocol>[^,]+),\s+Application="(?P<Application>[^"]+)",\s+Profile="(?P<Profile>[^"]+)",\s+Direction=(?P<Direction>[^,]+),\s+ThreatType=(?P<ThreatType>[^,]+),\s+ThreatName=(?P<ThreatName>[^,]+),\s+Action=(?P<Action>[^,]+),\s+FileType=(?P<FileType>[^,]+),\s+Hash=(?P<Hash>.*)\)$')
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
  convert => {
    "SeverityHeader" => "integer"
    "Count"          => "integer"
  }
}

mutate {
  add_field => { "severity" => "%{SeverityHeader}" }
}
mutate { convert => { "severity" => "integer" } }

if [src_ip] == "127.0.0.1" {
  mutate { add_field => { "match_chars" => "localhost" } }
} else {
  mutate { add_field => { "match_chars" => "attack_ip" } }
}

if [type] == "l" {
  mutate { add_field => { "src_system_log_type" => "日志信息" } }
} else if [type] == "s" {
  mutate { add_field => { "src_system_log_type" => "安全日志信息" } }
}

mutate {
  add_field => {
    "[extends_ip][DstIp]" => "%{DstIp}"
    "[extends_ip][SrcIp]" => "%{SrcIp}"
  }
}

mutate {
  add_field => {
    "[extends_info][hostname]"    => "%{Hostname}"
    "[extends_info][source_type]" => "%{source_type}"
  }
}

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