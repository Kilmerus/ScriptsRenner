set serveroutput on;
DECLARE

/*
    Exclusão de endereço
*/


CURSOR c_main IS
    SELECT 
        LOC.location_id
        , LOC.wh_id
        , LOC.status
        , LOC.type
        , loc.item_hu_indicator
        , nVL((select SUM(actual_qty)
            FROM t_stored_item 
            where location_id = loc.location_id
            and wh_id = loc.wh_id),0) as SUM_ESTOQUE
        , exl.LOAD_ID 
    FROM t_exception_log exl
    inner join t_location loc
        on exl.item_number = loc.location_id
    where exl.tran_type = '027'
    and loc.wh_id = '464';
        
rec_main c_main%ROWTYPE;


     -- Error handling variables
     c_vchObjName   VARCHAR2(30 CHAR); -- The name that uniquely tags this object.
     v_vchErrorMsg  VARCHAR2(2000 CHAR);
     v_vchReturn    VARCHAR2(2000 CHAR);
     v_vchHost      VARCHAR2(2000 CHAR);
    
     v_vchIns       NUMBER;
     v_nErrorCode   NUMBER;
     -- Exceptions
     e_KnownError   EXCEPTION;
     e_UnknownError EXCEPTION;


BEGIN
    
    
    SELECT SYS_GUID() INTO v_vchHost from dual;
    
    
	FOR rec_main IN c_main	LOOP
	
	IF c_main%NOTFOUND Then
      EXIT;
	END IF;
	
        IF rec_main.SUM_ESTOQUE = 0 THEN
    
            DELETE t_zone_loca where location_id = rec_main.location_id and wh_id = rec_main.wh_id;
            
            DELETE t_location where location_id = rec_main.location_id and wh_id = rec_main.wh_id;
            
            -- RASTREABILIDADE
            INSERT INTO T_TRAN_LOG_HOLDING(TRAN_LOG_HOLDING_ID, TRAN_TYPE, DESCRIPTION, START_TRAN_DATE, START_TRAN_TIME, EMPLOYEE_ID, WH_ID, ITEM_NUMBER, TRAN_QTY, CONTROL_NUMBER, CONTROL_NUMBER_2, LOT_NUMBER, LOCATION_ID, LOCATION_ID_2)
            VALUES(NULL
                    , '027'
                    , 'Exclusão de Endereço'
                    , SYSDATE
                    , SYSDATE
                    , 'HJS'
                    , rec_main.WH_ID
                    , null
                    , null
                    , 'RITM0070835'
                    , 'REQ0070481'
                    , null
                    , rec_main.location_id
                    , null);  
                    
            UPDATE DBO.t_exception_log set load_id = 'OK' where tran_type = '027' and item_number = rec_main.location_id and load_id is null;
                    
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
