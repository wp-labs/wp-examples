CREATE TABLE IF NOT EXISTS `table_example`
(
    `id`
    int
    AUTO_INCREMENT
    NOT
    NULL
    PRIMARY
    KEY,
    `x_recv_time`
    varchar
(
    64
), `x_occur_time` varchar
(
    64
), `x_from_ip` varchar
(
    64
), `from_zone` varchar
(
    64
), `src_ip` varchar
(
    64
), `requ_uri` varchar
(
    255
), `requ_status` int, `resp_len` int, `src_city` varchar
(
    64
))