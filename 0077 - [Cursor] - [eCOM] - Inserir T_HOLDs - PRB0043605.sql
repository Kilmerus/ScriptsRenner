SET SERVEROUTPUT ON
DECLARE
/**************************************************************************************
-- Correção de contorno
-- PRB0043605
**************************************************************************************/
CURSOR c_main IS
    SELECT 
        sto.wh_id
        , sto.item_number
        , sto.location_id
        , sto.actual_qty
        , sto.TYPE
        , sto.lot_number
        , sto.stored_attribute_id
        , sto.hu_id
    FROM t_stored_item sto
    inner join t_location loc
        on sto.location_id = loc.location_id
        and sto.wh_id = loc.wh_id
        and loc.type <> 'F'
    WHERE sto.status = 'H'
    AND NOT EXISTS (SELECT 1 FROM t_holds hol
                    WHERE hol.item_number = sto.item_number
                    AND hol.wh_id = sto.wh_id
                    AND hol.location_id = sto.location_id
                    --and hol.lot_number = sto.lot_number
                    AND ((lot_number = sto.lot_number) OR (lot_number IS NULL AND sto.lot_number IS NULL))
                    )
    AND sto.wh_id = '30400'
    --and sto.item_number = '300000053'
	--and sto.location_id = 'ENDEREÇO'
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

        -- Inserção
        INSERT INTO t_holds 
            (item_number
            ,wh_id
            ,location_id
            ,lot_number
            ,TYPE
            ,stored_attribute_id
            ,hu_id
            ,reason_id
            ,date_created
            ,employee_id) 
        VALUES 
            (rec_main.item_number
            ,rec_main.wh_id
            ,rec_main.location_id
            ,rec_main.lot_number
            ,rec_main.TYPE
            ,rec_main.stored_attribute_id
            ,rec_main.hu_id
            ,'04'
            ,sysdate
            ,'PRB0043605');


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
                              , 'Correção - PRB0043605'
                              , TRUNC(sysdate)
                              , TO_DATE(to_char(TRUNC(sysdate, 'MM'), 'DD/MM/YYYY')||' '||to_char(sysdate,'HH24:MI:SS'), 'DD/MM/YYYY HH24:MI:SS') --START_TRAN_TIME
                              , TRUNC(sysdate)--TO_DATE('01/01/1900','MM/DD/YYYY')END_TRAN_DATE
                              , TO_DATE(to_char(TRUNC(sysdate, 'MM'), 'DD/MM/YYYY')||' '||to_char(sysdate,'HH24:MI:SS'), 'DD/MM/YYYY HH24:MI:SS') --END_TRAN_TIME
                              , 'HJS'        
                              , ''
                              , 'PRB0043605'          
                              , 'Inserção na T_HOLDS'                   
                              , rec_main.wh_id
                              , rec_main.hu_id
                              , rec_main.location_id
                              , rec_main.location_id                
                              , rec_main.actual_qty
                              , rec_main.item_number   
                              , rec_main.actual_qty        
                              
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
