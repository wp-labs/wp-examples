# Rule Definitions

本文档汇总了测试中使用的解析与解析+转换规则，按日志类型与引擎归档，并用 Markdown 对“解析配置 / 解析+转换配置”作清晰标注。

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

### Vector
- **解析配置（VRL）**

```bash
source = '''
  parsed = parse_regex!(.message, r'^(?P<client>\S+) \S+ \S+ \[(?P<time>[^\]]+)\] "(?P<request>[^"]*)" (?P<status>\d{3}) (?P<size>\d+) "(?P<referer>[^"]*)" "(?P<agent>[^"]*)" "(?P<extra>[^"]*)"')
  .sip = parsed.client
  .http_request = parsed.request
  .status = parsed.status
  .size = parsed.size
  .referer = parsed.referer
  .http_agent = parsed.agent
  .timestamp = parsed.time
  del(.message)
'''
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

### Vector
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

### Vector
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

### Vector
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
