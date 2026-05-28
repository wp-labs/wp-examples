CREATE DATABASE IF NOT EXISTS test_db;

DROP TABLE IF EXISTS test_db.wp_nginx_01;
CREATE TABLE test_db.wp_nginx_01 (
                                  `timestamp` bigint COMMENT '原始时间字符串',
                                  wp_event_id STRING COMMENT '事件唯一ID',
                                  wp_src_key STRING DEFAULT "" COMMENT '数据来源表示',
                                  sip STRING DEFAULT "" COMMENT '客户端IP',
                                  `http/request` STRING DEFAULT "" COMMENT 'HTTP请求行',
                                  status STRING DEFAULT "" COMMENT 'HTTP状态码',
                                  size STRING DEFAULT "" COMMENT '响应大小(byte)',
                                  referer STRING DEFAULT "" COMMENT '来源页面',
                                  `http/agent` STRING DEFAULT "" COMMENT 'User-Agent'
)
    ENGINE=OLAP
    DUPLICATE KEY(`timestamp`)
DISTRIBUTED BY HASH(`timestamp`) BUCKETS 8
PROPERTIES (
    "replication_num" = "1"
);


DROP TABLE IF EXISTS test_db.wp_nginx_02;
CREATE TABLE test_db.wp_nginx_02 (
                                     `timestamp` bigint COMMENT '原始时间字符串',
                                     wp_event_id STRING COMMENT '事件唯一ID',
                                     wp_src_key STRING DEFAULT "" COMMENT '数据来源表示',
                                     sip STRING DEFAULT "" COMMENT '客户端IP',
                                     `http/request` STRING DEFAULT "" COMMENT 'HTTP请求行',
                                     status STRING DEFAULT "" COMMENT 'HTTP状态码',
                                     size STRING DEFAULT "" COMMENT '响应大小(byte)',
                                     referer STRING DEFAULT "" COMMENT '来源页面',
                                     `http/agent` STRING DEFAULT "" COMMENT 'User-Agent'
)
    ENGINE=OLAP
    DUPLICATE KEY(`timestamp`)
DISTRIBUTED BY HASH(`timestamp`) BUCKETS 8
PROPERTIES (
    "replication_num" = "1"
);

select * from test_db.wp_nginx_01;
select * from test_db.wp_nginx_02;
