create database DEV_WEBINAR_ORDERS_RL_DB;
use database DEV_WEBINAR_ORDERS_RL_DB;
create schema TPCH;
USE SCHEMA TPCH;

-- Set variables for this sample data for the time frame to acquire
set l_start_dt = dateadd( day, -16, to_date( '1998-07-02', 'yyyy-mm-dd' ) );
set l_end_dt   = dateadd( day,   1, to_date( '1998-07-02', 'yyyy-mm-dd' ) ); 

CREATE TABLE line_item (
    l_orderkey INT,
    o_orderdate DATE,
    l_partkey INT,
    l_suppkey INT,
    l_linenumber INT,
    l_quantity DECIMAL(10, 2),
    l_extendedprice DECIMAL(10, 2),
    l_discount DECIMAL(10, 2),
    l_tax DECIMAL(10, 2),
    l_returnflag CHAR(1),
    l_shipdate DATE,
    l_commitdate DATE,
    l_receiptdate DATE,
    l_shipinstruct VARCHAR(50),
    l_shipmode VARCHAR(50),
    l_comment VARCHAR(255),
    last_modified_dt TIMESTAMP
);

-- run this 2 or 3 times to produce overlapping files with new and modified records.
copy into
    @~/line_item
from
(
    with l_line_item as
    (
        select
              row_number() over(order by uniform( 1, 60, random() ) ) as seq_no
             ,l.l_orderkey
             ,o.o_orderdate
             ,l.l_partkey
             ,l.l_suppkey
             ,l.l_linenumber
             ,l.l_quantity
             ,l.l_extendedprice
             ,l.l_discount
             ,l.l_tax
             ,l.l_returnflag
             ,l.l_linestatus
             ,l.l_shipdate
             ,l.l_commitdate
             ,l.l_receiptdate
             ,l.l_shipinstruct
             ,l.l_shipmode
             ,l.l_comment
        from
            snowflake_sample_data.tpch_sf1000.orders o
            join snowflake_sample_data.tpch_sf1000.lineitem l
              on l.l_orderkey = o.o_orderkey
        where
                o.o_orderdate >= $l_start_dt
            and o.o_orderdate  < $l_end_dt
    )
    select
         l.l_orderkey
        ,l.o_orderdate
        ,l.l_partkey
        ,l.l_suppkey
        ,l.l_linenumber
        ,l.l_quantity
        ,l.l_extendedprice
        ,l.l_discount
        ,l.l_tax
        ,l.l_returnflag
        -- simulate modified data by randomly changing the status
        ,case uniform( 1, 100, random() )
            when  1 then 'A'
            when  5 then 'B'
            when 20 then 'C'
            when 30 then 'D'
            when 40 then 'E'
            else l.l_linestatus
         end                            as l_linestatus
        ,l.l_shipdate
        ,l.l_commitdate
        ,l.l_receiptdate
        ,l.l_shipinstruct
        ,l.l_shipmode
        ,l.l_comment
        ,current_timestamp()            as last_modified_dt -- generating a last modified timestamp as part of data acquisition.
    from
        l_line_item l
    order by
        l.l_orderkey
)
file_format      = ( type=csv field_optionally_enclosed_by = '"' )
overwrite        = false
single           = false
include_query_id = true
max_file_size    = 16000000
;