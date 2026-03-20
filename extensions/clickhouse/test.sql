CREATE DATABASE IF NOT EXISTS test_db;

DROP TABLE IF EXISTS default.wp_nginx;
CREATE TABLE default.wp_nginx
(
    wp_event_id        Int64              COMMENT '事件唯一ID',
    wp_src_key         LowCardinality(String) COMMENT '数据来源表示',
    sip                IPv4               COMMENT '客户端IP',
    `timestamp`        String             COMMENT '原始时间（毫秒精度）',
    `http/request`     String             COMMENT 'HTTP请求行',
    status             UInt16             COMMENT 'HTTP状态码',
    size               UInt32             COMMENT '响应大小(byte)',
    referer            String             COMMENT '来源页面',
    `http/agent`       String             COMMENT 'User-Agent'
)
    ENGINE = MergeTree
        ORDER BY (wp_src_key)
        SETTINGS index_granularity = 8192;
select count(*) from default.wp_nginx
