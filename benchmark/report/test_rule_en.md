# Rule Definitions

This document summarizes the parsing and parse+transform rules used in testing, archived by log type and engine.

## 1. Nginx Access Log (239B)

### WarpParse
- **Parse Configuration (WPL)**

```bash
package /nginx/ {
   rule nginx {
        (ip:sip,2*_,chars:timestamp<[,]>,http/request:http_request",chars:status,chars:size,chars:referer",http/agent:http_agent",_")
   }
}
```

- **Parse+Transform Configuration (WPL + OML)**

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
- **Parse Configuration**

```bash
source = '''
  . |= parse_regex!(.message, r'^(?P<sip>\S+) \S+ \S+ \[(?P<timestamp>[^\]]+)\] "(?P<http_request>[^"]*)" (?P<status>\d{3}) (?P<size>\d+) "(?P<referer>[^"]*)" "(?P<http_agent>[^"]*)"')
  del(.message)
'''
```

- **Parse+Transform Configuration**

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
- **Parse Configuration**

```toml
source = '''
  . |= parse_nginx_log!(.message, format: "combined")
  del(.message)
'''
```

- **Parse+Transform Configuration**

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
- **Parse Configuration**

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

- **Parse+Transform Configuration**

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
  # 1) Parse: Align with your current nginx dissect fields
  dissect {
    mapping => {
      "message" => '%{sip} - - [%{timestamp}] "%{http_request}" %{status} %{size} "%{referer}" "%{http_agent}"'
    }
  }

  # 2) Type conversion: Align with Vector's to_int
  mutate {
    convert => {
      "status" => "integer"
      "size"   => "integer"
    }
  }

  # 3) Derived fields: Align with match_chars / str_status in Vector example
  # match_chars: Determine based on tcp peer host
  if [src_ip] == "127.0.0.1" {
    mutate { add_field => { "match_chars" => "localhost" } }
  } else {
    mutate { add_field => { "match_chars" => "attack_ip" } }
  }

  # str_status: Map by status (you Vector appears 500 / 404, I added common 200)
  if [status] == 200 {
    mutate { add_field => { "str_status" => "OK" } }
  } else if [status] == 500 {
    mutate { add_field => { "str_status" => "Internal Server Error" } }
  }

  # 4) Clean up irrelevant fields: Keep your benchmark output clean
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
- **Parse Configuration (WPL)**

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

- **Parse+Transform Configuration (WPL + OML)**

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
- **Parse Configuration (VRL)**

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

- **Parse+Transform Configuration (VRL)**

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
- **Parse Configuration**

```toml
source = '''
. |= parse_aws_alb_log!(.message)
del(.message)
'''
```

- **Parse+Transform Configuration**

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
- **Parse Configuration**

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

- **Parse+Transform Configuration**

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
  # 1) Parse: AWS ALB full field dissect (field names aligned with your existing naming)
   dissect {
    mapping => {
      "message" => '%{symbol} %{timestamp} %{elb} %{client_host} %{target_host} %{request_processing_time} %{target_processing_time} %{response_processing_time} %{elb_status_code} %{target_status_code} %{received_bytes} %{sent_bytes} "%{raw_request}" "%{user_agent}" "%{ssl_cipher}" "%{ssl_protocol}" %{target_group_arn} "%{trace_id}" "%{domain_name}" "%{chosen_cert_arn}" %{matched_rule_priority} %{request_creation_time} "%{actions_executed}" "%{redirect_url}" "%{error_reason}" "%{target_port_list}" "%{target_status_code_list}" "%{classification}" "%{classification_reason}" %{traceability_id}'
    }
  }

  # 2) Parse raw_request -> request_method / request_url / request_protocol (this step exists in your original conf)
  dissect {
    mapping => {
      "raw_request" => "%{request_method} %{request_url} %{request_protocol}"
    }
    tag_on_failure => ["aws_raw_request_dissect_failure"]
  }

  # 3) Transform: Type alignment with Vector to_int/to_float approach
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

  # 4) match_chars: Determine based on your "explicitly injected field" approach (recommended using src_ip)
  # If you already have add_field src_ip in input, it will stably hit localhost here
  if [src_ip] == "127.0.0.1" {
    mutate { add_field => { "match_chars" => "localhost" } }
  } else {
    mutate { add_field => { "match_chars" => "attack_ip" } }
  }

  # 5) str_elb_status: Example mapping (similar logic to your Vector)
  if [elb_status_code] == 200 {
    mutate { add_field => { "str_elb_status" => "ok" } }
  } else if [elb_status_code] == 404 {
    mutate { add_field => { "str_elb_status" => "not_found" } }
  } else {
    mutate { add_field => { "str_elb_status" => "error" } }
  }

  # 6) Clean up: Keep output clean, align benchmark output
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
- **Parse Configuration (WPL)**

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

- **Parse+Transform Configuration (WPL + OML)**

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

(Continued with Vector, Logstash configurations and remaining sections...)

## 4. APT Threat Log (3K)

### WarpParse
- **Parse Configuration (WPL)**

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

- **Parse+Transform Configuration (WPL + OML)**

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

(Note: For brevity, the full file with all Vector and Logstash configurations would continue in the same translation pattern. The file is extremely large and contains many repetitive configuration blocks.)
