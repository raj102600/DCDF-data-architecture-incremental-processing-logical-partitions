use database DEV_WEBINAR_ORDERS_RL_DB;
use schema   TPCH;
use warehouse dev_webinar_wh;

CREATE TABLE part (
    p_partkey INT,
    p_name STRING,
    p_mfgr STRING,
    p_brand STRING,
    p_type STRING,
    p_size INT,
    p_container STRING,
    p_retailprice DECIMAL(10, 2),
    p_comment STRING,
    last_modified_dt TIMESTAMP
);

copy into
    @~/part
from
(
    with l_part as
    (
        select
              row_number() over(order by uniform( 1, 60, random() ) ) as seq_no
             ,p.p_partkey
             ,p.p_name
             ,p.p_mfgr
             ,p.p_brand
             ,p.p_type
             ,p.p_size
             ,p.p_container
             ,p.p_retailprice
             ,p.p_comment
        from
            snowflake_sample_data.tpch_sf1000.part p
    )
    select
         p.p_partkey
        ,p.p_name
        ,p.p_mfgr
        ,p.p_brand
        ,p.p_type
        ,p.p_size
        ,p.p_container
        ,p.p_retailprice
        ,p.p_comment
        ,current_timestamp()            as last_modified_dt -- generating a last modified timestamp as part of data acquisition.
    from
        l_part p
    order by
        p.p_partkey
)
file_format      = ( type=csv field_optionally_enclosed_by = '"' )
overwrite        = false
single           = false
include_query_id = true
max_file_size    = 16000000
;

list @~/part;





