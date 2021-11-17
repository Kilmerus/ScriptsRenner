set serveroutput on;
DECLARE

/*
    Alteração de Endereço
*/


CURSOR c_main IS
    SELECT 
        location_id         AS old_loc
        , control_number    AS new_loc
        , wh_id             AS wh_id
        , exception_id
    FROM t_exception_log 
    WHERE tran_type = '075'
    AND error_message is null
   -- and rownum <= 5
    ;        
rec_main c_main%ROWTYPE;


    -- Error handling variables
    c_vchObjName   VARCHAR2(30 CHAR); -- The name that uniquely tags this object.
    v_vchErrorMsg  VARCHAR2(2000 CHAR);
    v_nErrorCode   NUMBER;

    -- Exceptions
    e_KnownError   EXCEPTION;
    e_UnknownError EXCEPTION;
    
    v_nQTY_STO NUMBER := 0;
    v_nQTY_HUM NUMBER := 0;
    v_nCLA NUMBER := 0;
    v_nZON NUMBER := 0;
    v_nREL NUMBER := 0;
    v_nLOC NUMBER := 0;


BEGIN

    
    FOR rec_main IN c_main	LOOP
        
        IF c_main%NOTFOUND Then
          EXIT;
        END IF;


        SELECT 
            (SELECT COUNT(*) FROM T_STORED_ITEM WHERE LOCATION_ID           = rec_main.old_loc AND WH_ID = rec_main.wh_id) AS QTY_STO
            , (SELECT COUNT(*) FROM T_HU_MASTER WHERE LOCATION_ID           = rec_main.old_loc AND WH_ID = rec_main.wh_id) AS QTY_HUM
            , (SELECT COUNT(*) FROM T_CLASS_LOCA WHERE LOCATION_ID          = rec_main.old_loc AND WH_ID = rec_main.wh_id) AS CLASS
            , (SELECT COUNT(*) FROM T_ZONE_LOCA WHERE LOCATION_ID           = rec_main.old_loc AND WH_ID = rec_main.wh_id) AS ZONA
            , (SELECT COUNT(*) FROM T_LOCATION_RELATION WHERE LOCATION_ID   = rec_main.old_loc AND WH_ID = rec_main.wh_id) AS RELAT
            , (SELECT COUNT(*) FROM T_LOCATION WHERE LOCATION_ID            = rec_main.new_loc AND WH_ID = rec_main.wh_id) AS LOC
            INTO v_nQTY_STO, v_nQTY_HUM, v_nCLA , v_nZON, v_nREL, v_nLOC
        FROM DUAL;
        
        IF v_nQTY_STO>0 or v_nQTY_HUM>0 THEN
        
           UPDATE t_exception_log set error_message = 'ENDEREÇO COM ESTOQUE'
           where exception_id = rec_main.exception_id;
           
        ELSE
        
            IF v_nLOC = 0 THEN

                -- INSER O NOVO ENDEREÇO COM BASE NO ANTIGO
                INSERT INTO T_LOCATION (WH_ID,LOCATION_ID,DESCRIPTION,SHORT_LOCATION_ID,STATUS,ZONE,PICKING_FLOW,CAPACITY_UOM,CAPACITY_QTY,STORED_QTY,TYPE,FIFO_DATE,CYCLE_COUNT_CLASS,LAST_COUNT_DATE,LAST_PHYSICAL_DATE,USER_COUNT,CAPACITY_VOLUME,TIME_BETWEEN_MAINTENANCE,LAST_MAINTAINED,LENGTH,WIDTH,HEIGHT,REPLENISHMENT_LOCATION_ID,PICK_AREA,ALLOW_BULK_PICK,SLOT_RANK,SLOT_STATUS,ITEM_HU_INDICATOR,C1,C2,C3,RANDOM_CC,X_COORDINATE,Y_COORDINATE,Z_COORDINATE,STORAGE_DEVICE_ID,EQUIPMENT_TYPE,LEAD_TIME_AREA) 
                SELECT WH_ID,REC_MAIN.NEW_LOC,DESCRIPTION,SHORT_LOCATION_ID,STATUS,ZONE,PICKING_FLOW,CAPACITY_UOM,CAPACITY_QTY,STORED_QTY,TYPE,FIFO_DATE,CYCLE_COUNT_CLASS,LAST_COUNT_DATE,LAST_PHYSICAL_DATE,USER_COUNT,CAPACITY_VOLUME,TIME_BETWEEN_MAINTENANCE,LAST_MAINTAINED,LENGTH,WIDTH,HEIGHT,REPLENISHMENT_LOCATION_ID,PICK_AREA,ALLOW_BULK_PICK,SLOT_RANK,SLOT_STATUS,ITEM_HU_INDICATOR,C1,C2,C3,RANDOM_CC,X_COORDINATE,Y_COORDINATE,Z_COORDINATE,STORAGE_DEVICE_ID,EQUIPMENT_TYPE,LEAD_TIME_AREA
                FROM T_LOCATION
                WHERE LOCATION_ID = REC_MAIN.OLD_LOC
                AND WH_ID = REC_MAIN.WH_ID;
            
            END IF;

            UPDATE T_CLASS_LOCA SET LOCATION_ID = REC_MAIN.new_loc
            WHERE LOCATION_ID   = REC_MAIN.old_loc
            AND WH_ID           = REC_MAIN.WH_ID;  
            
            UPDATE t_exception_log set error_message = 'CL'
                where exception_id = rec_main.exception_id;
        
            UPDATE T_ZONE_LOCA SET LOCATION_ID = REC_MAIN.new_loc
            WHERE LOCATION_ID   = REC_MAIN.old_loc
            AND WH_ID           = REC_MAIN.WH_ID;  
            
            UPDATE t_exception_log set error_message = error_message||' - ZO'
                where exception_id = rec_main.exception_id;
        
            UPDATE T_LOCATION_RELATION SET LOCATION_ID = REC_MAIN.new_loc
            WHERE LOCATION_ID   = REC_MAIN.old_loc
            AND WH_ID           = REC_MAIN.WH_ID;  
            
            UPDATE t_exception_log set error_message = error_message||' - RE'
                where exception_id = rec_main.exception_id;

            UPDATE t_location set status = 'I' where location_id = rec_main.old_loc and wh_id = rec_main.wh_id;
            
            UPDATE t_exception_log set error_message = error_message||' - IN'
                where exception_id = rec_main.exception_id;
         
                
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
                                   '075'
                                  , 'Alteração de Endereço'
                                  , TRUNC(sysdate)
                                  , TO_DATE(to_char(TRUNC(sysdate, 'MM'), 'DD/MM/YYYY')||' '||to_char(sysdate,'HH24:MI:SS'), 'DD/MM/YYYY HH24:MI:SS') --START_TRAN_TIME
                                  , TRUNC(sysdate)--TO_DATE('01/01/1900','MM/DD/YYYY')END_TRAN_DATE
                                  , TO_DATE(to_char(TRUNC(sysdate, 'MM'), 'DD/MM/YYYY')||' '||to_char(sysdate,'HH24:MI:SS'), 'DD/MM/YYYY HH24:MI:SS') --END_TRAN_TIME
                                  , 'HJS'                           --EMPLOYEE_ID
                                  , 'RITM0097674'                    --CONTROL_NUMBER
                                  , NULL
                                  , rec_main.wh_id
                                  , null
                                  , rec_main.old_loc             --LOCATION_ID
                                  , rec_main.new_loc                --LOCATION_ID_2
                                  , 0--NUM_ITEMS
                                  , null            --ITEM_NUMBER
                                  , null               --TRAN_QTY
                                  
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
/

