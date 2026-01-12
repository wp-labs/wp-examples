CREATE DATABASE IF NOT EXISTS test_db;

DROP TABLE IF EXISTS test_db.wp_nginx;
CREATE TABLE test_db.wp_nginx (
     wp_event_id BIGINT COMMENT '事件唯一ID',
     wp_src_key STRING COMMENT '数据来源表示',
     sip STRING COMMENT '客户端IP',
     `timestamp` STRING COMMENT '原始时间字符串',
     `http/request` STRING COMMENT 'HTTP请求行',
     status SMALLINT COMMENT 'HTTP状态码',
     size INT COMMENT '响应大小(byte)',
     referer STRING COMMENT '来源页面',
     `http/agent` STRING COMMENT 'User-Agent'
)
    ENGINE=OLAP
    DUPLICATE KEY(wp_event_id)
DISTRIBUTED BY HASH(wp_event_id) BUCKETS 8
PROPERTIES (
    "replication_num" = "1"
);

DROP TABLE IF EXISTS test_db.wp_jnginx;
CREATE TABLE test_db.wp_jnginx (
      wp_event_id BIGINT COMMENT '事件唯一ID',
      wp_src_key STRING COMMENT '数据来源表示',
      `date` DOUBLE COMMENT '时间戳(秒)',
      sip STRING COMMENT '客户端IP',
      `timestamp` STRING COMMENT '原始时间字符串',
      `http/request` STRING COMMENT 'HTTP请求行',
      status SMALLINT COMMENT 'HTTP状态码',
      size INT COMMENT '响应大小(byte)',
      referer STRING COMMENT '来源页面',
      `http/agent` STRING COMMENT 'User-Agent'
)
    ENGINE=OLAP
    DUPLICATE KEY(wp_event_id)
DISTRIBUTED BY HASH(wp_event_id) BUCKETS 8
PROPERTIES (
    "replication_num" = "1"
);