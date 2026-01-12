-- 创建数据库
CREATE DATABASE IF NOT EXISTS test_db;
USE test_db;

-- wp_nginx 表
DROP TABLE IF EXISTS wp_nginx;
CREATE TABLE wp_nginx (
                          wp_event_id BIGINT NOT NULL COMMENT '事件唯一ID',
                          wp_src_key VARCHAR(128) COMMENT '数据来源表示',
                          sip VARCHAR(45) COMMENT '客户端IP',
                          `timestamp` VARCHAR(64) COMMENT '原始时间字符串',
                          `http/request` VARCHAR(512) COMMENT 'HTTP请求行',
                          status SMALLINT COMMENT 'HTTP状态码',
                          size INT COMMENT '响应大小(byte)',
                          referer VARCHAR(512) COMMENT '来源页面',
                          `http/agent` VARCHAR(512) COMMENT 'User-Agent',
                          PRIMARY KEY (wp_event_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='设备请求事件解析表';

-- wp_jnginx 表
DROP TABLE IF EXISTS wp_jnginx;
CREATE TABLE wp_jnginx (
                           wp_event_id BIGINT NOT NULL COMMENT '事件唯一ID',
                           wp_src_key VARCHAR(128) COMMENT '数据来源表示',
                           `date` DOUBLE COMMENT '时间戳(秒)',
                           sip VARCHAR(45) COMMENT '客户端IP',
                           `timestamp` VARCHAR(64) COMMENT '原始时间字符串',
                           `http/request` VARCHAR(512) COMMENT 'HTTP请求行',
                           status SMALLINT COMMENT 'HTTP状态码',
                           size INT COMMENT '响应大小(byte)',
                           referer VARCHAR(512) COMMENT '来源页面',
                           `http/agent` VARCHAR(512) COMMENT 'User-Agent',
                           PRIMARY KEY (wp_event_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='设备请求事件解析表';

select * from wp_nginx
