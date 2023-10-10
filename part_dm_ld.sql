use database dev_webinar_pl_db;
create  database dev_webinar_pl_db;
create  schema   main;
use schema   main;
use warehouse dev_webinar_wh;

CREATE or replace  TABLE part_dm (
    dw_part_shk binary(20),  -- Replace with the appropriate data type
    p_partkey NUMBER,    -- Replace with the appropriate data type
    part_name VARCHAR2(255),  -- Replace with the appropriate data type and length
    mfgr VARCHAR2(255),       -- Replace with the appropriate data type and length
    brand VARCHAR2(255),      -- Replace with the appropriate data type and length
    type VARCHAR2(255),       -- Replace with the appropriate data type and length
    size NUMBER,              -- Replace with the appropriate data type
    container VARCHAR2(255),  -- Replace with the appropriate data type and length
    retail_price NUMBER,      -- Replace with the appropriate data type
    comment VARCHAR2(4000),   -- Replace with the appropriate data type and length
    first_orderdate DATE,     -- Replace with the appropriate data type
    last_modified_dt DATE,    -- Replace with the appropriate data type
    dw_load_ts TIMESTAMP,     -- Replace with the appropriate data type
    dw_update_ts TIMESTAMP    -- Replace with the appropriate data type
);
create or replace table part_first_order_dt
(
     dw_part_shk                    binary( 20 )        not null
    --
    ,first_orderdate                date                not null
    --
    ,dw_load_ts                     timestamp_ltz       not null
    ,dw_update_ts                   timestamp_ltz       not null
)
data_retention_time_in_days = 1
copy grants
;

execute immediate '

declare
  l_start_dt date;
  l_end_dt   date;
  -- Grab the dates for the logical partitions to process
  c1 cursor for select start_dt, end_dt FROM table(dev_webinar_common_db.util.dw_delta_date_range_f(''week'')) order by 1;
  
begin
    
  for record in c1 do
    l_start_dt := record.start_dt;
    l_end_dt   := record.end_dt;

    --
    -- Merge Pattern
    --
    merge into part_first_order_dt t using
    (
        with l_stg as
        (
            -- 
            -- Driving CTE to identify all the records in the logical partition to be process
            --
            select
                 p.dw_part_shk
                ,min( s.o_orderdate ) as first_orderdate
                ,current_timestamp() as last_modified_dt
            from
                dev_webinar_orders_rl_db.tpch.line_item_ld s
                join dev_webinar_orders_rl_db.tpch.part_ld p
                  on p.p_partkey = s.l_partkey
            where
                    s.o_orderdate >= :l_start_dt
                and s.o_orderdate  < :l_end_dt
            group by
                1
        )
        select
             current_timestamp()        as dw_update_ts
            ,s.*
        from
            l_stg s
            left join part_first_order_dt t on
                t.dw_part_shk = s.dw_part_shk
        where
            t.first_orderdate       != s.first_orderdate
    ) s
    on
    (
        t.dw_part_shk = s.dw_part_shk
    )
    when matched then update set
         t.first_orderdate    = s.first_orderdate
        ,t.dw_update_ts  = s.dw_update_ts
    when not matched then insert
    (
         dw_part_shk
        ,first_orderdate
        ,dw_load_ts
        ,dw_update_ts
    )
    values
    (
         s.dw_part_shk
        ,s.first_orderdate
        ,s.dw_update_ts
        ,s.dw_update_ts
    )
    ;

  end for;
  
  return ''SUCCESS'';

end;'
;

execute immediate '

begin
    
   insert overwrite into part_dm
   select
       p.dw_part_shk
      ,p.p_partkey
      ,p.p_name as part_name
      ,p.p_mfgr as mfgr
      ,p.p_brand as brand
      ,p.p_type as type
      ,p.p_size as size
      ,p.p_container as container
      ,p.p_retailprice as retail_price
      ,p.p_comment as comment
      ,d.first_orderdate
      ,p.last_modified_dt
      ,p.dw_load_ts
      ,p.dw_update_ts
   from
       dev_webinar_orders_rl_db.tpch.part_ld p
       left join dev_webinar_pl_db.main.part_first_order_dt d
         on d.dw_part_shk = p.dw_part_shk;
  
  return ''SUCCESS'';

end;'
;
