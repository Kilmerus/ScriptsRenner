SET SERVEROUTPUT ON
DECLARE
/**************************************************************************************
-- Correção de contorno
-- 
**************************************************************************************/
CURSOR c_main IS
    SELECT 
        sto.item_number
        , sto.wh_id
        , hum.hu_id
        , sto.actual_qty as qty
        --, sto.type
        , hum.ZONE
        , hum.parent_hu_id
        , sto2.type
        , sto.location_id
        , hum.control_number
        , COUNT(DISTINCT sto.TYPE) as contador
    FROM t_stored_item sto
    INNER JOIN t_hu_master hum
        ON hum.hu_id = sto.hu_id
        AND hum.wh_id = sto.wh_id
    INNER JOIN t_stored_item sto2
        on sto.hu_id = sto2.hu_id
        and sto.item_number = sto2.item_number
        and sto.wh_id = sto2.wh_id
    WHERE sto.hu_id = '00000114000017378808'
    AND sto.location_id = 'PRE_RECE_TRANSF'
    GROUP BY sto.item_number
        , sto.wh_id        , hum.ZONE
        , sto2.type        , sto.actual_qty
        , hum.parent_hu_id        , hum.hu_id
        , hum.control_number, sto.location_id
    HAVING COUNT(DISTINCT sto.TYPE)  > 1
    ;
rec_main c_main%ROWTYPE;

     -- Default
     v_vchErrorMsg  VARCHAR2(2000 CHAR);
     v_nErrorCode   NUMBER;
     e_UnknownError EXCEPTION;
     
     v_vchType  VARCHAR2(20 CHAR);
     
     
BEGIN

    FOR rec_main IN c_main	LOOP
    
        IF c_main%notfound THEN
            EXIT;
        END IF;
        
        SELECT max(type) into v_vchType
        FROM t_stored_item
          where hu_id = rec_main.hu_id
          and item_number = rec_main.item_number
          and location_id = rec_main.location_id
          and wh_id = rec_main.wh_id;
          
        DELETE t_stored_item 
          where hu_id = rec_main.hu_id
          and item_number = rec_main.item_number
          and wh_id = rec_main.wh_id
          and location_id = rec_main.location_id
          and type <> v_vchType;
                
        UPDATE t_stored_item set actual_qty = rec_main.contador * rec_main.qty
          where hu_id = rec_main.hu_id
          and item_number = rec_main.item_number
          and wh_id = rec_main.wh_id
          and location_id = rec_main.location_id
          and type = v_vchType;
        
        INSERT INTO t_tran_log_holding(
                              tran_type
                              , DESCRIPTION
                              , start_tran_date
                              , start_tran_time
                              , end_tran_date
                              , end_tran_time
                              , employee_id
                              , line_number
                              , control_number
                              , control_number_2
                              , wh_id
                              , hu_id
                              , location_id
                              , location_id_2
                              , num_items
                              , item_number
                              , tran_qty
                              
                        ) VALUES (
                               '999'
                              , 'Correção - DEVTRI'
                              , TRUNC(sysdate)
                              , TO_DATE(to_char(TRUNC(sysdate, 'MM'), 'DD/MM/YYYY')||' '||to_char(sysdate,'HH24:MI:SS'), 'DD/MM/YYYY HH24:MI:SS') --START_TRAN_TIME
                              , TRUNC(sysdate)--TO_DATE('01/01/1900','MM/DD/YYYY')END_TRAN_DATE
                              , TO_DATE(to_char(TRUNC(sysdate, 'MM'), 'DD/MM/YYYY')||' '||to_char(sysdate,'HH24:MI:SS'), 'DD/MM/YYYY HH24:MI:SS') --END_TRAN_TIME
                              , 'HJS'        
                              , ''
                              , rec_main.zone                
                              , v_vchType                   
                              , rec_main.wh_id
                              , rec_main.hu_id
                              , rec_main.location_id
                              , rec_main.location_id                
                              , rec_main.contador
                              , rec_main.item_number   
                              , rec_main.qty        
                              
                          );
    END LOOP;
  
  COMMIT;
  

 EXCEPTION 
          WHEN OTHERS THEN
               ROLLBACK;
               v_nErrorCode  := -20006;
               v_vchErrorMsg := 'SQLERRM = ' || SQLERRM;
               RAISE e_UnknownError;

END;
