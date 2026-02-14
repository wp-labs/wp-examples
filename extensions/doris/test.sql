CREATE DATABASE IF NOT EXISTS wp_test;
drop table wp_test.events_parsed;
CREATE TABLE IF NOT EXISTS wp_test.events_parsed (
    wp_event_id BIGINT COMMENT '事件唯一ID',
    wp_src_key  STRING COMMENT '数据来源表示',
    sn           STRING COMMENT '设备序列号',
    dev_name     STRING COMMENT '设备名称',
    sip          STRING COMMENT '源 IP',
    from_zone    STRING COMMENT '来源区域',
    from_ip      STRING COMMENT '来源 IP',
    requ_uri     STRING COMMENT '请求 URI',
    requ_status  SMALLINT COMMENT '请求状态码',
    resp_len     INT COMMENT '响应长度',
    src_city     STRING COMMENT '源城市'
)
ENGINE=OLAP
DUPLICATE KEY(wp_event_id)
COMMENT '设备请求事件解析表'
DISTRIBUTED BY HASH(wp_event_id) BUCKETS 8
PROPERTIES (
    "replication_num" = "1"
);
select count(*) from wp_test.events_parsed