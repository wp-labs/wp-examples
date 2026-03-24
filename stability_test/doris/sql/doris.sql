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

select COUNT(*) from test_db.wp_nginx;

delete from test_db.wp_jnginx where status is not null;
select COUNT(*) from test_db.wp_jnginx;


CREATE DATABASE IF NOT EXISTS wp_test;
CREATE TABLE IF NOT EXISTS wp_test.events_parsed (
    wp_event_id  BIGINT COMMENT '事件唯一ID',
    wp_src_key   VARCHAR(64) COMMENT '数据来源标识',
    sn           VARCHAR(64) COMMENT '设备序列号',
    dev_name     VARCHAR(128) COMMENT '设备名称',
    sip          VARCHAR(45) COMMENT '源 IP',
    from_zone    VARCHAR(32) COMMENT '来源区域',
    from_ip      VARCHAR(45) COMMENT '来源 IP',
    requ_uri     VARCHAR(512) COMMENT '请求 URI',
    requ_status  SMALLINT COMMENT '请求状态码',
    resp_len     INT COMMENT '响应长度',
    src_city     VARCHAR(32) COMMENT '源城市'
)
ENGINE=OLAP
DUPLICATE KEY(wp_event_id)
COMMENT '设备请求事件解析表'
DISTRIBUTED BY HASH(wp_event_id) BUCKETS 8
PROPERTIES (
    "replication_num" = "1"
);CREATE DATABASE IF NOT EXISTS test_db;


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

select COUNT(*) from test_db.wp_nginx;

delete from test_db.wp_jnginx where status is not null;
select COUNT(*) from test_db.wp_jnginx;


CREATE DATABASE IF NOT EXISTS wp_test;
CREATE TABLE IF NOT EXISTS wp_test.events_parsed (
                                                     wp_event_id  BIGINT COMMENT '事件唯一ID',
                                                     wp_src_key   VARCHAR(64) COMMENT '数据来源标识',
                                                     sn           VARCHAR(64) COMMENT '设备序列号',
                                                     dev_name     VARCHAR(128) COMMENT '设备名称',
                                                     sip          VARCHAR(45) COMMENT '源 IP',
                                                     from_zone    VARCHAR(32) COMMENT '来源区域',
                                                     from_ip      VARCHAR(45) COMMENT '来源 IP',
                                                     requ_uri     VARCHAR(512) COMMENT '请求 URI',
                                                     requ_status  SMALLINT COMMENT '请求状态码',
                                                     resp_len     INT COMMENT '响应长度',
                                                     src_city     VARCHAR(32) COMMENT '源城市'
)
    ENGINE=OLAP
    DUPLICATE KEY(wp_event_id)
COMMENT '设备请求事件解析表'
DISTRIBUTED BY HASH(wp_event_id) BUCKETS 8
PROPERTIES (
    "replication_num" = "1"
);

delete from test_db.wp_nginx where wp_event_id is not null;
select count(*) from test_db.wp_nginx

delete from test_db.wp_nginx where wp_event_id is not null;
select count(*) from test_db.wp_nginx