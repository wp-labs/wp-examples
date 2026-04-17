CREATE TABLE nginx_logs (
    sip VARCHAR(50),
    timestamp VARCHAR(50),
    "http/request" TEXT,    -- 注意：特殊字符需使用双引号
    status VARCHAR(10),
    size VARCHAR(20),
    referer TEXT,
    "http/agent" TEXT,      -- 注意：特殊字符需使用双引号
    wp_event_id BIGSERIAL PRIMARY KEY  -- 使用 BIGSERIAL 实现自增
);
