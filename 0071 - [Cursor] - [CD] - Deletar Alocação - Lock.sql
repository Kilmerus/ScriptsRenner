SET SERVEROUTPUT ON
DECLARE
/**************************************************************************************
Atualizar GTIN - T_ITEM_UOM
-- CAMICADO
**************************************************************************************/
CURSOR c_main IS
    SELECT 
    case when exists (select 1 from DBO.t_afo_wave_detail afo
                        where afo.order_number = alom.order_number
                        ) then 'EM_ONDA'
        ELSE 'SEM_ONDA' end WAVE
    , alom.order_number
    FROM t_al_host_order_master alom
    WHERE UPPER(alom.processing_code) LIKE '%DELETE%'
    AND alom.record_create_date >= TRUNC(sysdate)-1;
rec_main c_main%ROWTYPE;



     -- Error handling variables
     c_vchObjName   VARCHAR2(30 CHAR); -- The name that uniquely tags this object.
     v_vchErrorMsg  VARCHAR2(2000 CHAR);
     v_nErrorCode   NUMBER;
     v_vchReturn    VARCHAR2(2000 CHAR);
     
     -- Exceptions
     e_KnownError   EXCEPTION;
     e_UnknownError EXCEPTION;
     v_Tran_Type VARCHAR2(5 CHAR);
     v_vchChamado VARCHAR2(20 CHAR);

     
BEGIN

    FOR rec_main IN c_main	LOOP
    
        IF c_main%notfound THEN
            EXIT;
        END IF;
        
        IF rec_main.wave = 'SEM_ONDA' THEN
            
            DELETE t_order where order_number = rec_main.order_number;
            
            -- INSERIR LOG
            INSERT INTO t_tran_log_holding(
                                  tran_type
                                  , DESCRIPTION
                                  , start_tran_date
                                  , start_tran_time
                                  , end_tran_date
                                  , end_tran_time
                                  , employee_id
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
                                   '025'
                                  , 'Delete - Order'
                                  , TRUNC(sysdate)
                                  , TO_DATE(to_char(TRUNC(sysdate, 'MM'), 'DD/MM/YYYY')||' '||to_char(sysdate,'HH24:MI:SS'), 'DD/MM/YYYY HH24:MI:SS') --START_TRAN_TIME
                                  , TRUNC(sysdate)--TO_DATE('01/01/1900','MM/DD/YYYY')END_TRAN_DATE
                                  , TO_DATE(to_char(TRUNC(sysdate, 'MM'), 'DD/MM/YYYY')||' '||to_char(sysdate,'HH24:MI:SS'), 'DD/MM/YYYY HH24:MI:SS') --END_TRAN_TIME
                                  , 'HJS'                           --EMPLOYEE_ID
                                  , rec_main.order_number                    --CONTROL_NUMBER
                                  , ''                    
                                  , ''
                                  , null
                                  , null                            --LOCATION_ID
                                  , null                            --LOCATION_ID_2
                                  , 0--NUM_ITEMS
                                  , ''            --ITEM_NUMBER
                                  , 0              --TRAN_QTY
                                  
                              );
                              
        ELSE
        
                        INSERT INTO t_tran_log_holding(
                                  tran_type
                                  , DESCRIPTION
                                  , start_tran_date
                                  , start_tran_time
                                  , end_tran_date
                                  , end_tran_time
                                  , employee_id
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
                                   '025'
                                  , 'Delete - Order (Em Onda)'
                                  , TRUNC(sysdate)
                                  , TO_DATE(to_char(TRUNC(sysdate, 'MM'), 'DD/MM/YYYY')||' '||to_char(sysdate,'HH24:MI:SS'), 'DD/MM/YYYY HH24:MI:SS') --START_TRAN_TIME
                                  , TRUNC(sysdate)--TO_DATE('01/01/1900','MM/DD/YYYY')END_TRAN_DATE
                                  , TO_DATE(to_char(TRUNC(sysdate, 'MM'), 'DD/MM/YYYY')||' '||to_char(sysdate,'HH24:MI:SS'), 'DD/MM/YYYY HH24:MI:SS') --END_TRAN_TIME
                                  , 'HJS'                           --EMPLOYEE_ID
                                  , rec_main.order_number                    --CONTROL_NUMBER
                                  , 'Delete não efetuado'                    
                                  , ''
                                  , null
                                  , null                            --LOCATION_ID
                                  , null                            --LOCATION_ID_2
                                  , 0--NUM_ITEMS
                                  , ''            --ITEM_NUMBER
                                  , 0              --TRAN_QTY
                                  
                              );
            
            
        
        END IF;
        
    END LOOP;
  
  
  COMMIT;

 EXCEPTION -- Exceção do Laço (For)
          WHEN OTHERS THEN
               ROLLBACK;
               v_nErrorCode  := -20006;
               v_vchErrorMsg := 'SQLERRM = ' || SQLERRM;
               RAISE e_UnknownError;

END;
