CREATE DATABASE IF NOT EXISTS wparse
  CHARACTER SET utf8mb4 
  COLLATE utf8mb4_unicode_ci;

USE wparse;

CREATE TABLE nginx_logs (
    `sip` VARCHAR(50),
    `timestamp` VARCHAR(50),
    `http/request` TEXT,
    `status` VARCHAR(10),
    `size` VARCHAR(20),
    `referer` TEXT,
    `http/agent` TEXT,
    `wp_event_id` BIGINT AUTO_INCREMENT PRIMARY KEY
);