SET SERVEROUTPUT ON
DECLARE
/**************************************************************************************
-- Correção de contorno
-- Problema PRB0045270
**************************************************************************************/
CURSOR c_main IS
    SELECT 
        DISTINCT hum.hu_id
        , hum.wh_id
        , pkd.line_number
        , hum.location_id
        , CASE WHEN ord.cust_part = ord.wh_id THEN 'SHIP'
                                ELSE 'TRANSF_'||ord.cust_part
                           END new_reserved
    FROM t_hu_master hum
    INNER JOIN t_stored_item sto
        ON sto.hu_id = hum.hu_id
        AND sto.wh_id = hum.wh_id
    INNER JOIN t_pick_detail pkd
        ON to_char(pkd.pick_id) = sto.TYPE
        AND pkd.wh_id = sto.wh_id
    INNER JOIN t_order_detail ord
        ON ord.order_number = pkd.order_number
        AND ord.line_number = pkd.line_number
        AND ord.item_number = pkd.item_number
    WHERE hum.reserved_for = 'TSFCON'
    AND hum.control_number IS NULL
    AND hum.location_id NOT IN ('RECE_TRANSF','PRE_RECE_TRANSF')
    ;
rec_main c_main%ROWTYPE;

     -- Default
     v_vchErrorMsg  VARCHAR2(2000 CHAR);
     v_nErrorCode   NUMBER;
     e_UnknownError EXCEPTION;
     
     
BEGIN

    FOR rec_main IN c_main	LOOP
    
        IF c_main%notfound THEN
            EXIT;
        END IF;
        
        UPDATE t_hu_master set control_number = rec_main.line_number, reserved_for = rec_main.new_reserved where hu_id = rec_main.hu_id and wh_id = rec_main.wh_id;
        
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
                              , 'Atualização - Reserved/Control_number'
                              , TRUNC(sysdate)
                              , TO_DATE(to_char(TRUNC(sysdate, 'MM'), 'DD/MM/YYYY')||' '||to_char(sysdate,'HH24:MI:SS'), 'DD/MM/YYYY HH24:MI:SS') --START_TRAN_TIME
                              , TRUNC(sysdate)--TO_DATE('01/01/1900','MM/DD/YYYY')END_TRAN_DATE
                              , TO_DATE(to_char(TRUNC(sysdate, 'MM'), 'DD/MM/YYYY')||' '||to_char(sysdate,'HH24:MI:SS'), 'DD/MM/YYYY HH24:MI:SS') --END_TRAN_TIME
                              , 'HJS'        
                              , rec_main.line_number
                              , 'PRB0045270'                 
                              , rec_main.new_reserved                    
                              , rec_main.wh_id
                              , rec_main.hu_id
                              , rec_main.location_id
                              , null                
                              , 0
                              , ''   
                              , 0        
                              
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
