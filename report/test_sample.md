# Test Data Samples

本文档展示了四类日志在经过解析与转换后的输出数据样本 (Output Samples)。

## 1. Nginx Access Log Samples

**样本数据**

```json
180.57.30.148 - - [21/Jan/2025:01:40:02 +0800] "GET /nginx-logo.png HTTP/1.1" 500 368 "http://207.131.38.110/" "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_14_5) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/75.0.3770.142 Safari/537.36" "-"
```

**解析结果 (Parsed):**

* **WarpParse:**

```json
{
	"wp_event_id": 1764645169882925000,
	"sip": "180.57.30.148",
	"timestamp": "21/Jan/2025:01:40:02 +0800",
	"http_request": "GET /nginx-logo.png HTTP/1.1",
	"status": "500",
	"size": "368",
	"referer": "http://207.131.38.110/",
	"http_agent": "Mozilla/5.0(Macintosh; Intel Mac OS X 10_14_5) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/75.0.3770.142 Safari/537.36 ",
	"wp_src_key": "socket",
	"wp_src_ip": "127.0.0.1"
}
```

* **Vector:**

```json
{
	"host": "127.0.0.1",
	"http_agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_14_5) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/75.0.3770.142 Safari/537.36",
	"http_request": "GET /nginx-logo.png HTTP/1.1",
	"port": 58102,
	"referer": "http://207.131.38.110/",
	"sip": "180.57.30.148",
	"size": "368",
	"source_type": "socket",
	"status": "500",
	"timestamp": "21/Jan/2025:01:40:02 +0800"
}
```

**解析+转换结果 (Transformed):**

* **WarpParse:**

```json
{
	"host": "127.0.0.1",
	"http_agent": "Mozilla/5.0(Macintosh; Intel Mac OS X 10_14_5) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/75.0.3770.142 Safari/537.36 ",
	"http_request": "GET /nginx-logo.png HTTP/1.1",
	"match_chars": "localhost",
	"referer": "http://207.131.38.110/",
	"sip": "180.57.30.148",
	"size": 368,
	"source_type": "socket",
	"status": 500,
	"str_status": "Internal Server Error",
	"timestamp": "21/Jan/2025:01:40:02 +0800"
}
```

* **Vector:**

```json
{
	"host": "127.0.0.1",
	"http_agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_14_5) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/75.0.3770.142 Safari/537.36",
	"http_request": "GET /nginx-logo.png HTTP/1.1",
	"match_chars": "localhost",
	"port": 53894,
	"referer": "http://207.131.38.110/",
	"sip": "180.57.30.148",
	"size": 368,
	"source_type": "socket",
	"status": 500,
	"str_status": "Internal Server Error",
	"timestamp": "21/Jan/2025:01:40:02 +0800"
}
```

## 2. AWS ELB Log Samples

**样本数据**

```json
http 2018-11-30T22:23:00.186641Z app/my-lb 192.168.1.10:2000 10.0.0.15:8080 0.01 0.02 0.01 200 200 100 200 "POST https://api.example.com/u?p=1&sid=2&t=3 HTTP/1.1" "Mozilla/5.0 (Win) Chrome/90" "ECDHE" "TLSv1.3" arn:aws:elb:us:123:tg "Root=1-test" "api.example.com" "arn:aws:acm:us:123:cert/short" 1 2018-11-30T22:22:48.364000Z "forward" "https://auth.example.com/r" "err" "10.0.0.1:80" "200" "cls" "rsn" TID_x1
```

**解析结果 (Parsed):**

* **WarpParse:**

```json
{
	"wp_event_id": 1764646097464011000,
	"symbol": "http",
	"timestamp": "2018-11-30T22:23:00.186641Z",
	"elb": "app/my-lb",
	"client_host": "192.168.1.10:2000",
	"target_host": "10.0.0.15:8080",
	"request_processing_time": "0.01",
	"target_processing_time": "0.02",
	"response_processing_time": "0.01",
	"elb_status_code": "200",
	"target_status_code": "200",
	"received_bytes": "100",
	"sent_bytes": "200",
	"request_method": "POST",
	"request_url": "https://api.example.com/u?p=1&sid=2&t=3",
	"request_protocol": "HTTP/1.1",
	"user_agent": "Mozilla/5.0 (Win) Chrome/90",
	"ssl_cipher": "ECDHE",
	"ssl_protocol": "TLSv1.3",
	"target_group_arn": "arn:aws:elb:us:123:tg",
	"trace_id": "Root=1-test",
	"domain_name": "api.example.com",
	"chosen_cert_arn": "arn:aws:acm:us:123:cert/short",
	"matched_rule_priority": "1",
	"request_creation_time": "2018-11-30T22:22:48.364000Z",
	"actions_executed": "forward",
	"redirect_url": "https://auth.example.com/r",
	"error_reason": "err",
	"target_port_list": "10.0.0.1:80",
	"target_status_code_list": "200",
	"classification": "cls",
	"classification_reason": "rsn",
	"traceability_id": "TID_x1",
	"wp_src_key": "socket",
	"wp_src_ip": "127.0.0.1"
}
```

* **Vector:**

```json
{
	"actions_executed": "forward",
	"chosen_cert_arn": "arn:aws:acm:us:123:cert/short",
	"classification": "cls",
	"classification_reason": "rsn",
	"client_host": "192.168.1.10:2000",
	"domain_name": "api.example.com",
	"elb": "app/my-lb",
	"elb_status_code": "200",
	"error_reason": "err",
	"host": "127.0.0.1",
	"matched_rule_priority": "1",
	"port": 58786,
	"received_bytes": "100",
	"redirect_url": "https://auth.example.com/r",
	"request_creation_time": "2018-11-30T22:22:48.364000Z",
	"request_method": "POST",
	"request_processing_time": "0.01",
	"request_protocol": "HTTP/1.1",
	"request_url": "https://api.example.com/u?p=1&sid=2&t=3",
	"response_processing_time": "0.01",
	"sent_bytes": "200",
	"source_type": "socket",
	"ssl_cipher": "ECDHE",
	"ssl_protocol": "TLSv1.3",
	"symbol": "http",
	"target_group_arn": "arn:aws:elb:us:123:tg",
	"target_host": "10.0.0.15:8080",
	"target_port_list": "10.0.0.1:80",
	"target_processing_time": "0.02",
	"target_status_code": "200",
	"target_status_code_list": "200",
	"timestamp": "2018-11-30T22:23:00.186641Z",
	"trace_id": "Root=1-test",
	"traceability_id": "TID_x1",
	"user_agent": "Mozilla/5.0 (Win) Chrome/90"
}
```

**解析+转换结果 (Transformed):**

* **WarpParse:**

```json
{
	"timestamp": "2018-11-30T22:23:00.186641Z",
	"actions_executed": "forward",
	"chosen_cert_arn": "arn:aws:acm:us:123:cert/short",
	"classification": "cls",
	"classification_reason": "rsn",
	"client_host": "192.168.1.10:2000",
	"domain_name": "api.example.com",
	"elb": "app/my-lb",
	"elb_status_code": 200,
	"error_reason": "err",
	"extends": {
		"ssl_cipher": "ECDHE",
		"ssl_protocol": "TLSv1.3"
	},
	"host": "127.0.0.1",
	"match_chars": "localhost",
	"matched_rule_priority": "1",
	"received_bytes": "100",
	"redirect_url": "https://auth.example.com/r",
	"request_creation_time": "2018-11-30T22:22:48.364000Z",
	"request_method": "POST",
	"request_processing_time": "0.01",
	"request_protocol": "HTTP/1.1",
	"request_url": "https://api.example.com/u?p=1&sid=2&t=3",
	"response_processing_time": "0.01",
	"sent_bytes": 200,
	"source_type": "socket",
	"ssl_cipher": "ECDHE",
	"ssl_protocol": "TLSv1.3",
	"str_elb_status": "ok",
	"target_group_arn": "arn:aws:elb:us:123:tg",
	"target_host": "10.0.0.15:8080",
	"target_port_list": "10.0.0.1:80",
	"target_processing_time": "0.02",
	"target_status_code": 200,
	"target_status_code_list": "200",
	"trace_id": "Root=1-test",
	"traceability_id": "TID_x1",
	"user_agent": "Mozilla/5.0 (Win) Chrome/90"
}
```

* **Vector:**

```json
{
	"actions_executed": "forward",
	"chosen_cert_arn": "arn:aws:acm:us:123:cert/short",
	"classification": "cls",
	"classification_reason": "rsn",
	"client_host": "192.168.1.10:2000",
	"domain_name": "api.example.com",
	"elb": "app/my-lb",
	"elb_status_code": 200,
	"error_reason": "err",
	"extends": {
		"ssl_cipher": "ECDHE",
		"ssl_protocol": "TLSv1.3"
	},
	"host": "127.0.0.1",
	"match_chars": "localhost",
	"matched_rule_priority": "1",
	"port": 53995,
	"received_bytes": "100",
	"redirect_url": "https://auth.example.com/r",
	"request_creation_time": "2018-11-30T22:22:48.364000Z",
	"request_method": "POST",
	"request_processing_time": "0.01",
	"request_protocol": "HTTP/1.1",
	"request_url": "https://api.example.com/u?p=1&sid=2&t=3",
	"response_processing_time": "0.01",
	"sent_bytes": 200,
	"source_type": "socket",
	"ssl_cipher": "ECDHE",
	"ssl_protocol": "TLSv1.3",
	"str_elb_status": "ok",
	"symbol": "http",
	"target_group_arn": "arn:aws:elb:us:123:tg",
	"target_host": "10.0.0.15:8080",
	"target_port_list": "10.0.0.1:80",
	"target_processing_time": "0.02",
	"target_status_code": 200,
	"target_status_code_list": "200",
	"timestamp": "2018-11-30T22:23:00.186641Z",
	"trace_id": "Root=1-test",
	"traceability_id": "TID_x1",
	"user_agent": "Mozilla/5.0 (Win) Chrome/90"
}
```

## 3. Sysmon Log Samples

**样本数据**

```json
<14>Apr 09 18:37:27 10.77.32.19 Microsoft-Windows-Sysmon:{"Id":1,"Version":1,"Level":4,"Task":1,"Opcode":0,"Keywords":0,"RecordId":null,"ProviderName":"P","ProviderId":"PID","LogName":"L","ProcessId":1,"ThreadId":1,"MachineName":"A","TimeCreated":"2025-04-10T14:17:28.693228+08:00","ActivityId":null,"RelatedActivityId":null,"Qualifiers":null,"LevelDisplayName":"信息","OpcodeDisplayName":"信息","TaskDisplayName":"Process Create","Description":{"RuleName":"R","UtcTime":"2025-04-10 06:17:28.503","ProcessGuid":"{G}","ProcessId":"1","Image":"C:\\Windows\\a.exe","FileVersion":"1","Description":"D","Product":"P","Company":"C","OriginalFileName":"a.exe","CommandLine":"a.exe","CurrentDirectory":"C:\\","User":"U","LogonGuid":"{LG}","LogonId":"1","TerminalSessionId":"1","IntegrityLevel":"M","Hashes":"H","ParentProcessGuid":"{PG}","ParentProcessId":"1","ParentImage":"C:\\Windows\\b.exe","ParentCommandLine":"b.exe","ParentUser":"U"},"DescriptionRawMessage":"Process Create\r\nRuleName: R"}
```

**解析结果 (Parsed):**

* **WarpParse:**

```json
{
	"wp_event_id": 1764657738662604000,
	"cmd_line": "a.exe",
	"product_company": "C",
	"current_dir": "C:\\\\",
	"process_desc": "D",
	"file_version": "1",
	"Hashes": "H",
	"process_path": "C:\\\\Windows\\\\a.exe",
	"integrity_level": "M",
	"logon_guid": "{LG}",
	"logon_id": "1",
	"origin_file_name": "a.exe",
	"parent_cmd_line": "b.exe",
	"parent_process_path": "C:\\\\Windows\\\\b.exe",
	"parent_process_guid": "{PG}",
	"parent_process_id": "1",
	"parent_process_user": "U",
	"process_guid": "{G}",
	"process_id": "1",
	"product_name": "P",
	"rule_name": "R",
	"terminal_session_id": "1",
	"user_name": "U",
	"occur_time": "2025-04-10 06:17:28.503",
	"DescriptionRawMessage": "Process Create\\r\\nRuleName: R",
	"id": "1",
	"keywords": "0",
	"severity": "4",
	"LevelDisplayName": "信息",
	"LogName": "L",
	"MachineName": "A",
	"Opcode": "0",
	"OpcodeDisplayName": "信息",
	"ProcessId": "1",
	"ProviderId": "PID",
	"ProviderName": "P",
	"Task": "1",
	"TaskDisplayName": "Process Create",
	"ThreadId": "1",
	"TimeCreated": "2025-04-10T14:17:28.693228+08:00",
	"Version": "1",
	"wp_src_key": "socket",
	"wp_src_ip": "127.0.0.1"
}
```

* **Vector:**

```json
{
	"DescriptionRawMessage": "Process Create\\r\\nRuleName: R",
	"Hashes": "H",
	"LevelDisplayName": "信息",
	"LogName": "L",
	"MachineName": "A",
	"Opcode": "0",
	"OpcodeDisplayName": "信息",
	"ProcessId": "1",
	"ProviderId": "PID",
	"ProviderName": "P",
	"Task": "1",
	"TaskDisplayName": "Process Create",
	"ThreadId": "1",
	"TimeCreated": "2025-04-10T14:17:28.693228+08:00",
	"Version": "1",
	"cmd_line": "a.exe",
	"current_dir": "C:\\\\",
	"file_version": "1",
	"host": "127.0.0.1",
	"id": "1",
	"integrity_level": "M",
	"keywords": "0",
	"logon_guid": "{LG}",
	"logon_id": "1",
	"occur_time": "2025-04-10 06:17:28.503",
	"origin_file_name": "a.exe",
	"parent_cmd_line": "b.exe",
	"parent_process_guid": "{PG}",
	"parent_process_id": "1",
	"parent_process_path": "C:\\\\Windows\\\\b.exe",
	"parent_process_user": "U",
	"port": 50558,
	"process_desc": "D",
	"process_guid": "{G}",
	"process_id": "1",
	"process_path": "C:\\\\Windows\\\\a.exe",
	"product_company": "C",
	"product_name": "P",
	"rule_name": "R",
	"severity": "4",
	"source_type": "socket",
	"terminal_session_id": "1",
	"timestamp": "2025-12-02T06:33:53.716258Z",
	"user_name": "U"
}
```

**解析+转换结果 (Transformed):**

* **WarpParse:**

```json
{
	"Id": 1,
	"LogonId": 1,
	"enrich_level": "severity",
	"extends": {
		"OriginalFileName": "a.exe",
		"ParentCommandLine": "b.exe"
	},
	"extends_dir": {
		"ParentProcessPath": "C:\\\\Windows\\\\b.exe",
		"Process_path": "C:\\\\Windows\\\\a.exe"
	},
	"match_chars": "localhost",
	"num_range": 1,
	"wp_event_id": 1764813339134818000,
	"cmd_line": "a.exe",
	"product_company": "C",
	"current_dir": "C:\\\\",
	"process_desc": "D",
	"file_version": "1",
	"Hashes": "H",
	"process_path": "C:\\\\Windows\\\\a.exe",
	"integrity_level": "M",
	"logon_guid": "{LG}",
	"origin_file_name": "a.exe",
	"parent_cmd_line": "b.exe",
	"parent_process_path": "C:\\\\Windows\\\\b.exe",
	"parent_process_guid": "{PG}",
	"parent_process_id": "1",
	"parent_process_user": "U",
	"process_guid": "{G}",
	"process_id": "1",
	"product_name": "P",
	"rule_name": "R",
	"terminal_session_id": "1",
	"user_name": "U",
	"occur_time": "2025-04-10 06:17:28.503",
	"DescriptionRawMessage": "Process Create\\\\r\\\\nRuleName: R",
	"keywords": "0",
	"severity": "4",
	"LevelDisplayName": "信息",
	"LogName": "L",
	"MachineName": "A",
	"Opcode": "0",
	"OpcodeDisplayName": "信息",
	"ProcessId": "1",
	"ProviderId": "PID",
	"ProviderName": "P",
	"Task": "1",
	"TaskDisplayName": "Process Create",
	"ThreadId": "1",
	"TimeCreated": "2025-04-10T14:17:28.693228+08:00",
	"Version": "1",
	"wp_src_key": "socket",
	"wp_src_ip": "127.0.0.1"
}
```

* **Vector:**

```json
{
	"DescriptionRawMessage": "Process Create\\\\r\\\\nRuleName: R",
	"Hashes": "H",
	"Id": 1,
	"LevelDisplayName": "信息",
	"LogName": "L",
	"LogonId": 1,
	"MachineName": "A",
	"Opcode": "0",
	"OpcodeDisplayName": "信息",
	"ProcessId": "1",
	"ProviderId": "PID",
	"ProviderName": "P",
	"Task": "1",
	"TaskDisplayName": "Process Create",
	"ThreadId": "1",
	"TimeCreated": "2025-04-10T14:17:28.693228+08:00",
	"Version": "1",
	"cmd_line": "a.exe",
	"current_dir": "C:\\\\",
	"enrich_level": "severity",
	"extends": {
		"OriginalFileName": "a.exe",
		"ParentCommandLine": "b.exe"
	},
	"extends_dir": {
		"ParentProcessPath": "C:\\\\Windows\\\\b.exe",
		"Process_path": "C:\\\\Windows\\\\a.exe"
	},
	"file_version": "1",
	"host": "127.0.0.1",
	"integrity_level": "M",
	"keywords": "0",
	"logon_guid": "{LG}",
	"match_chars": "localhost",
	"num_range": 1,
	"occur_time": "2025-04-10 06:17:28.503",
	"origin_file_name": "a.exe",
	"parent_cmd_line": "b.exe",
	"parent_process_guid": "{PG}",
	"parent_process_id": "1",
	"parent_process_path": "C:\\\\Windows\\\\b.exe",
	"parent_process_user": "U",
	"port": 49838,
	"process_desc": "D",
	"process_guid": "{G}",
	"process_id": "1",
	"process_path": "C:\\\\Windows\\\\a.exe",
	"product_company": "C",
	"product_name": "P",
	"rule_name": "R",
	"severity": "4",
	"source_type": "socket",
	"terminal_session_id": "1",
	"timestamp": "2025-12-04T02:04:24.686378Z",
	"user_name": "U"
}
```

## 4. APT Threat Log Samples

**样本数据**

```json
#Feb  7 2025 15:07:18+08:00 USG1000E %%01ANTI-APT/4/ANTI-APT(l)[29]: An advanced persistent threat was detected. (SyslogId=1, VSys="public-long-virtual-system-name-for-testing-extra-large-value-to-simulate-enterprise-scenario", Policy="trust-untrust-high-risk-policy-with-deep-inspection-and-layer7-protection-enabled-for-advanced-threat-detection", SrcIp=192.168.1.123, DstIp=182.150.63.102, SrcPort=51784, DstPort=10781, SrcZone=trust-zone-with-multiple-segments-for-internal-security-domains-and-access-control, DstZone=untrust-wide-area-network-zone-with-external-facing-interfaces-and-honeynet-integration, User="unknown-long-user-field-used-for-simulation-purpose-with-extra-description-and-tags-[tag1][tag2][tag3]-to-reach-required-size", Protocol=TCP, Application="HTTP-long-application-signature-identification-with-multiple-behavior-patterns-and-deep-packet-inspection-enabled", Profile="IPS_default_advanced_extended_profile_with_ml_detection-long", Direction=aaa-long-direction-field-used-to-extend-size-with-additional-info-about-traffic-orientation-from-client-to-server, ThreatType=File Reputation with additional descriptive context of multi-layer analysis engine including sandbox-behavioral-signature-ml-static-analysis-and-network-correlation-modules-working-together, ThreatName=bbb-advanced-threat-campaign-with-code-name-operation-shadow-storm-and-related-IOCs-collected-over-multiple-incidents-in-the-wild-attached-metadata-[phase1][phase2][phase3], Action=ccc-block-and-alert-with-deep-scan-followed-by-quarantine-and-forensic-dump-generation-for-further-investigation, FileType=ddd-executable-binary-with-multiple-packed-layers-suspicious-import-table-behavior-and-evasion-techniques, Hash=eee1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef-long-hash-value-used-for-testing-purpose-extended-with-multiple-hash-representations-[MD5:aaa111bbb222ccc333]-[SHA1:bbb222ccc333ddd444]-[SHA256:ccc333ddd444eee555]-[SSDEEP:ddd444eee555fff666]-end-of-hash-section, Extr... [truncated]
```

**解析结果 (Parsed):**

* **WarpParse:**

```json
{
	"wp_event_id": 1764661811871722000,
	"timestamp": "2025-02-07 15:07:18",
	"Hostname": "USG1000E",
	"ModuleName": "01ANTI-APT",
	"SeverityHeader": "4",
	"symbol": "ANTI-APT",
	"type": "l",
	"Count": "29",
	"Content": "An advanced persistent threat was detected.",
	"SyslogId": "1",
	"VSys": "public-long-virtual-system-name-for-testing-extra-large-value-to-simulate-enterprise-scenario",
	"Policy": "trust-untrust-high-risk-policy-with-deep-inspection-and-layer7-protection-enabled-for-advanced-threat-detection",
	"SrcIp": "192.168.1.123",
	"DstIp": "182.150.63.102",
	"SrcPort": "51784",
	"DstPort": "10781",
	"SrcZone": "trust-zone-with-multiple-segments-for-internal-security-domains-and-access-control",
	"DstZone": "untrust-wide-area-network-zone-with-external-facing-interfaces-and-honeynet-integration",
	"User": "unknown-long-user-field-used-for-simulation-purpose-with-extra-description-and-tags-[tag1][tag2][tag3]-to-reach-required-size",
	"Protocol": "TCP",
	"Application": "HTTP-long-application-signature-identification-with-multiple-behavior-patterns-and-deep-packet-inspection-enabled",
	"Profile": "IPS_default_advanced_extended_profile_with_ml_detection-long",
	"Direction": "aaa-long-direction-field-used-to-extend-size-with-additional-info-about-traffic-orientation-from-client-to-server",
	"ThreatType": "File Reputation with additional descriptive context of multi-layer analysis engine including sandbox-behavioral-signature-ml-static-analysis-and-network-correlation-modules-working-together",
	"ThreatName": "bbb-advanced-threat-campaign-with-code-name-operation-shadow-storm-and-related-IOCs-collected-over-multiple-incidents-in-the-wild-attached-metadata-[phase1][phase2][phase3]",
	"Action": "ccc-block-and-alert-with-deep-scan-followed-by-quarantine-and-forensic-dump-generation-for-further-investigation",
	"FileType": "ddd-executable-binary-with-multiple-packed-layers-suspicious-import-table-behavior-and-evasion-techniques",
	"Hash": "eee1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef-long-hash-value-used-for-testing-purpose-extended-with-multiple-hash-representations-[MD5:aaa111bbb222ccc333]-[SHA1:bbb222ccc333ddd444]-[SHA256:ccc333ddd444eee555]-[SSDEEP:ddd444eee555fff666]-end-of-hash-section, ExtraInfo=\"This is additional extended information purposely added to inflate the total log size for stress testing of log ingestion engines such as Vector, Fluent Bit, self-developed ETL pipelines, and any high-throughput log processing systems. It contains repeated segments to simulate realistic verbose threat intelligence attachment blocks. [SEG-A-BEGIN] The threat was part of a coordinated multi-vector campaign observed across various geographic regions targeting enterprise networks with spear-phishing, watering-hole attacks, and supply-chain compromise vectors. Enriched indicators include C2 domains, malware families, behavioral clusters, sandbox detonation traces, and network telemetry correlation. [SEG-A-END] [SEG-B-BEGIN] Further analysis revealed that the payload exhibited persistence techniques including registry autoruns, scheduled tasks, masquerading, process injection, and lateral movement attempts leveraging remote service creation and stolen credentials. The binary contains multiple obfuscation layers, anti-debugging, anti-VM checks, and unusual API call sequences. [SEG-B-END] [SEG-C-BEGIN] IOC Bundle: Domains=malicious-domain-example-01.com,malicious-domain-example-02.net,malicious-update-service.info; IPs=103.21.244.0,198.51.100.55,203.0.113.77; FileNames=update_service.exe,winlog_service.dll,mscore_update.bin; RegistryKeys=HKCU\\\\Software\\\\Microsoft\\\\Windows\\\\CurrentVersion\\\\Run,HKLM\\\\System\\\\Services\\\\FakeService; Mutex=Global\\\\A1B2C3D4E5F6G7H8; YARA Matches=[rule1,rule2,rule3]. [SEG-C-END] EndOfExtraInfo\",
	"wp_src_key": "socket",
	"wp_src_ip": "127.0.0.1"
}
```

* **Vector:**

```json
{
	"Action": "ccc-block-and-alert-with-deep-scan-followed-by-quarantine-and-forensic-dump-generation-for-further-investigation",
	"Application": "HTTP-long-application-signature-identification-with-multiple-behavior-patterns-and-deep-packet-inspection-enabled",
	"Content": "An advanced persistent threat was detected.",
	"Count": "29",
	"Direction": "aaa-long-direction-field-used-to-extend-size-with-additional-info-about-traffic-orientation-from-client-to-server",
	"DstIp": "182.150.63.102",
	"DstPort": "10781",
	"DstZone": "untrust-wide-area-network-zone-with-external-facing-interfaces-and-honeynet-integration",
	"FileType": "ddd-executable-binary-with-multiple-packed-layers-suspicious-import-table-behavior-and-evasion-techniques",
	"Hash": "eee1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef-long-hash-value-used-for-testing-purpose-extended-with-multiple-hash-representations-[MD5:aaa111bbb222ccc333]-[SHA1:bbb222ccc333ddd444]-[SHA256:ccc333ddd444eee555]-[SSDEEP:ddd444eee555fff666]-end-of-hash-section, ExtraInfo=\"This is additional extended information purposely added to inflate the total log size for stress testing of log ingestion engines such as Vector, Fluent Bit, self-developed ETL pipelines, and any high-throughput log processing systems. It contains repeated segments to simulate realistic verbose threat intelligence attachment blocks. [SEG-A-BEGIN] The threat was part of a coordinated multi-vector campaign observed across various geographic regions targeting enterprise networks with spear-phishing, watering-hole attacks, and supply-chain compromise vectors. Enriched indicators include C2 domains, malware families, behavioral clusters, sandbox detonation traces, and network telemetry correlation. [SEG-A-END] [SEG-B-BEGIN] Further analysis revealed that the payload exhibited persistence techniques including registry autoruns, scheduled tasks, masquerading, process injection, and lateral movement attempts leveraging remote service creation and stolen credentials. The binary contains multiple obfuscation layers, anti-debugging, anti-VM checks, and unusual API call sequences. [SEG-B-END] [SEG-C-BEGIN] IOC Bundle: Domains=malicious-domain-example-01.com,malicious-domain-example-02.net,malicious-update-service.info; IPs=103.21.244.0,198.51.100.55,203.0.113.77; FileNames=update_service.exe,winlog_service.dll,mscore_update.bin; RegistryKeys=HKCU\\\\Software\\\\Microsoft\\\\Windows\\\\CurrentVersion\\\\Run,HKLM\\\\System\\\\Services\\\\FakeService; Mutex=Global\\\\A1B2C3D4E5F6G7H8; YARA Matches=[rule1,rule2,rule3]. [SEG-C-END] EndOfExtraInfo\",
	"Hostname": "USG1000E",
	"ModuleName": "01ANTI-APT",
	"Policy": "trust-untrust-high-risk-policy-with-deep-inspection-and-layer7-protection-enabled-for-advanced-threat-detection",
	"Profile": "IPS_default_advanced_extended_profile_with_ml_detection-long",
	"Protocol": "TCP",
	"SeverityHeader": "4",
	"SrcIp": "192.168.1.123",
	"SrcPort": "51784",
	"SrcZone": "trust-zone-with-multiple-segments-for-internal-security-domains-and-access-control",
	"SyslogId": "1",
	"ThreatName": "bbb-advanced-threat-campaign-with-code-name-operation-shadow-storm-and-related-IOCs-collected-over-multiple-incidents-in-the-wild-attached-metadata-[phase1][phase2][phase3]",
	"ThreatType": "File Reputation with additional descriptive context of multi-layer analysis engine including sandbox-behavioral-signature-ml-static-analysis-and-network-correlation-modules-working-together",
	"User": "unknown-long-user-field-used-for-simulation-purpose-with-extra-description-and-tags-[tag1][tag2][tag3]-to-reach-required-size",
	"VSys": "public-long-virtual-system-name-for-testing-extra-large-value-to-simulate-enterprise-scenario",
	"host": "127.0.0.1",
	"port": 55771,
	"source_type": "socket",
	"symbol": "ANTI-APT",
	"timestamp": "Feb  7 2025 15:07:18+08:00",
	"type": "l"
}
```

**解析+转换结果 (Transformed):**

* **WarpParse:**

```json
{
	"count": 29,
	"severity": 4,
	"match_chars": "localhost",
	"num_range": 29,
	"src_system_log_type": "日志信息",
	"extends_ip": {
		"DstIp": "182.150.63.102",
		"SrcIp": "192.168.1.123"
	},
	"extends_info": {
		"hostname": "USG1000E",
		"source_type": "socket"
	},
	"wp_event_id": 1764815397395451000,
	"timestamp": "2025-02-07 15:07:18",
	"Hostname": "USG1000E",
	"ModuleName": "01ANTI-APT",
	"symbol": "ANTI-APT",
	"type": "l",
	"Content": "An advanced persistent threat was detected.",
	"SyslogId": "1",
	"VSys": "public-long-virtual-system-name-for-testing-extra-large-value-to-simulate-enterprise-scenario",
	"Policy": "trust-untrust-high-risk-policy-with-deep-inspection-and-layer7-protection-enabled-for-advanced-threat-detection",
	"SrcIp": "192.168.1.123",
	"DstIp": "182.150.63.102",
	"SrcPort": "51784",
	"DstPort": "10781",
	"SrcZone": "trust-zone-with-multiple-segments-for-internal-security-domains-and-access-control",
	"DstZone": "untrust-wide-area-network-zone-with-external-facing-interfaces-and-honeynet-integration",
	"User": "unknown-long-user-field-used-for-simulation-purpose-with-extra-description-and-tags-[tag1][tag2][tag3]-to-reach-required-size",
	"Protocol": "TCP",
	"Application": "HTTP-long-application-signature-identification-with-multiple-behavior-patterns-and-deep-packet-inspection-enabled",
	"Profile": "IPS_default_advanced_extended_profile_with_ml_detection-long",
	"Direction": "aaa-long-direction-field-used-to-extend-size-with-additional-info-about-traffic-orientation-from-client-to-server",
	"ThreatType": "File Reputation with additional descriptive context of multi-layer analysis engine including sandbox-behavioral-signature-ml-static-analysis-and-network-correlation-modules-working-together",
	"ThreatName": "bbb-advanced-threat-campaign-with-code-name-operation-shadow-storm-and-related-IOCs-collected-over-multiple-incidents-in-the-wild-attached-metadata-[phase1][phase2][phase3]",
	"Action": "ccc-block-and-alert-with-deep-scan-followed-by-quarantine-and-forensic-dump-generation-for-further-investigation",
	"FileType": "ddd-executable-binary-with-multiple-packed-layers-suspicious-import-table-behavior-and-evasion-techniques",
	"Hash": "eee1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef-long-hash-value-used-for-testing-purpose-extended-with-multiple-hash-representations-[MD5:aaa111bbb222ccc333]-[SHA1:bbb222ccc333ddd444]-[SHA256:ccc333ddd444eee555]-[SSDEEP:ddd444eee555fff666]-end-of-hash-section, ExtraInfo=\"This is additional extended information purposely added to inflate the total log size for stress testing of log ingestion engines such as Vector, Fluent Bit, self-developed ETL pipelines, and any high-throughput log processing systems. It contains repeated segments to simulate realistic verbose threat intelligence attachment blocks. [SEG-A-BEGIN] The threat was part of a coordinated multi-vector campaign observed across various geographic regions targeting enterprise networks with spear-phishing, watering-hole attacks, and supply-chain compromise vectors. Enriched indicators include C2 domains, malware families, behavioral clusters, sandbox detonation traces, and network telemetry correlation. [SEG-A-END] [SEG-B-BEGIN] Further analysis revealed that the payload exhibited persistence techniques including registry autoruns, scheduled tasks, masquerading, process injection, and lateral movement attempts leveraging remote service creation and stolen credentials. The binary contains multiple obfuscation layers, anti-debugging, anti-VM checks, and unusual API call sequences. [SEG-B-END] [SEG-C-BEGIN] IOC Bundle: Domains=malicious-domain-example-01.com,malicious-domain-example-02.net,malicious-update-service.info; IPs=103.21.244.0,198.51.100.55,203.0.113.77; FileNames=update_service.exe,winlog_service.dll,mscore_update.bin; RegistryKeys=HKCU\\\\\\\\Software\\\\\\\\Microsoft\\\\\\\\Windows\\\\\\\\CurrentVersion\\\\\\\\Run,HKLM\\\\\\\\System\\\\\\\\Services\\\\\\\\FakeService; Mutex=Global\\\\\\\\A1B2C3D4E5F6G7H8; YARA Matches=[rule1,rule2,rule3]. [SEG-C-END] EndOfExtraInfo\",
	"wp_src_key": "socket",
	"wp_src_ip": "127.0.0.1"
}
```

* **Vector:**

```json
{
	"Action": "ccc-block-and-alert-with-deep-scan-followed-by-quarantine-and-forensic-dump-generation-for-further-investigation",
	"Application": "HTTP-long-application-signature-identification-with-multiple-behavior-patterns-and-deep-packet-inspection-enabled",
	"Content": "An advanced persistent threat was detected.",
	"Direction": "aaa-long-direction-field-used-to-extend-size-with-additional-info-about-traffic-orientation-from-client-to-server",
	"DstIp": "182.150.63.102",
	"DstPort": "10781",
	"DstZone": "untrust-wide-area-network-zone-with-external-facing-interfaces-and-honeynet-integration",
	"FileType": "ddd-executable-binary-with-multiple-packed-layers-suspicious-import-table-behavior-and-evasion-techniques",
	"Hash": "eee1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef-long-hash-value-used-for-testing-purpose-extended-with-multiple-hash-representations-[MD5:aaa111bbb222ccc333]-[SHA1:bbb222ccc333ddd444]-[SHA256:ccc333ddd444eee555]-[SSDEEP:ddd444eee555fff666]-end-of-hash-section, ExtraInfo=\"This is additional extended information purposely added to inflate the total log size for stress testing of log ingestion engines such as Vector, Fluent Bit, self-developed ETL pipelines, and any high-throughput log processing systems. It contains repeated segments to simulate realistic verbose threat intelligence attachment blocks. [SEG-A-BEGIN] The threat was part of a coordinated multi-vector campaign observed across various geographic regions targeting enterprise networks with spear-phishing, watering-hole attacks, and supply-chain compromise vectors. Enriched indicators include C2 domains, malware families, behavioral clusters, sandbox detonation traces, and network telemetry correlation. [SEG-A-END] [SEG-B-BEGIN] Further analysis revealed that the payload exhibited persistence techniques including registry autoruns, scheduled tasks, masquerading, process injection, and lateral movement attempts leveraging remote service creation and stolen credentials. The binary contains multiple obfuscation layers, anti-debugging, anti-VM checks, and unusual API call sequences. [SEG-B-END] [SEG-C-BEGIN] IOC Bundle: Domains=malicious-domain-example-01.com,malicious-domain-example-02.net,malicious-update-service.info; IPs=103.21.244.0,198.51.100.55,203.0.113.77; FileNames=update_service.exe,winlog_service.dll,mscore_update.bin; RegistryKeys=HKCU\\\\\\\\Software\\\\\\\\Microsoft\\\\\\\\Windows\\\\\\\\CurrentVersion\\\\\\\\Run,HKLM\\\\\\\\System\\\\\\\\Services\\\\\\\\FakeService; Mutex=Global\\\\\\\\A1B2C3D4E5F6G7H8; YARA Matches=[rule1,rule2,rule3]. [SEG-C-END] EndOfExtraInfo\",
	"Hostname": "USG1000E",
	"ModuleName": "01ANTI-APT",
	"Policy": "trust-untrust-high-risk-policy-with-deep-inspection-and-layer7-protection-enabled-for-advanced-threat-detection",
	"Profile": "IPS_default_advanced_extended_profile_with_ml_detection-long",
	"Protocol": "TCP",
	"SeverityHeader": "4",
	"SrcIp": "192.168.1.123",
	"SrcPort": "51784",
	"SrcZone": "trust-zone-with-multiple-segments-for-internal-security-domains-and-access-control",
	"SyslogId": "1",
	"ThreatName": "bbb-advanced-threat-campaign-with-code-name-operation-shadow-storm-and-related-IOCs-collected-over-multiple-incidents-in-the-wild-attached-metadata-[phase1][phase2][phase3]",
	"ThreatType": "File Reputation with additional descriptive context of multi-layer analysis engine including sandbox-behavioral-signature-ml-static-analysis-and-network-correlation-modules-working-together",
	"User": "unknown-long-user-field-used-for-simulation-purpose-with-extra-description-and-tags-[tag1][tag2][tag3]-to-reach-required-size",
	"VSys": "public-long-virtual-system-name-for-testing-extra-large-value-to-simulate-enterprise-scenario",
	"count": 29,
	"extends_info": {
		"hostname": "USG1000E",
		"source_type": "socket"
	},
	"extends_ip": {
		"DstIp": "182.150.63.102",
		"SrcIp": "192.168.1.123"
	},
	"host": "127.0.0.1",
	"match_chars": "localhost",
	"num_range": 29,
	"port": 51272,
	"severity": 4,
	"source_type": "socket",
	"src_system_log_type": "日志信息",
	"symbol": "ANTI-APT",
	"timestamp": "Feb  7 2025 15:07:18+08:00",
	"type": "l"
}
```