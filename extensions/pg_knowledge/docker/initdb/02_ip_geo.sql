-- 第二个 PostgreSQL 数据库：ip_geo_db（IP 归属地）
-- 由 docker-entrypoint-initdb.d 在 knowdb_demo 上执行；先建库再切库建表。
CREATE DATABASE ip_geo_db;

\c ip_geo_db

CREATE TABLE IF NOT EXISTS ip_geo_city (
    ip TEXT PRIMARY KEY,
    country TEXT NOT NULL,
    city TEXT NOT NULL
);

INSERT INTO ip_geo_city (ip, country, city) VALUES
    ('222.133.52.20', 'CN', 'Beijing'),
    ('10.10.10.8', 'US', 'Los Angeles')
ON CONFLICT (ip) DO UPDATE
SET country = EXCLUDED.country,
    city = EXCLUDED.city;
