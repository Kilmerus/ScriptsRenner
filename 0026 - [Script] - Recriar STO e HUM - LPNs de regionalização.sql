--Insert into t_hu_master (HU_ID,TYPE,LOCATION_ID,STATUS,FIFO_DATE,WH_ID,LOAD_POSITION,LOAD_SEQ,RESERVED_FOR,CONTAINER_TYPE,STOP_ID,PARENT_HU_ID) 
Insert into t_stored_item (SEQUENCE,ITEM_NUMBER,ACTUAL_QTY,UNAVAILABLE_QTY,STATUS,WH_ID,LOCATION_ID,FIFO_DATE,EXPIRATION_DATE,TYPE,HU_ID)
select 
    0
    , item_number
    , sum(tran_qty) as qty
    , 0
    ,'A'
    , '114'
    , location_id_2
    , SYSDATE
    , '01/01/1970 00:00:00'
    , 'STORAGE'
    , hu_id
--     hu_id    
--    , 'IV'
--    , location_id_2
--    , 'A'
--    , SYSDATE
--    , '114'
--    , 1
--    , 1
--    , routing_code
--    , 'EN'
--    , 0
--    , parent_hu_id
    
--    , item_number
--    , sum(tran_qty) as qty
    --, (select location_id from t_hu_master where hu_id = t_tran_log.parent_hu_id and location_id = 'RECE_EN_TRANSF_BUF') as pai
from t_tran_log where hu_id in (
    select log.hu_id from t_tran_log log 
    where log.control_number = '11894323-2536545' 
    and log.tran_type = '178'
    and exists (select 1 from t_tran_log log2
                where log2.hu_id = log.hu_id
                and log2.tran_type = '999'))
and tran_type = '132'
and wh_id = '114'
GROUP BY 
 hu_id
    , item_number
    , parent_hu_id
    , location_id_2
    , routing_code;