SET SERVEROUTPUT ON
DECLARE

/*
001 - Tarefa de Coleta Dirigida aberta, Sem LPNs em estoque
-- Causa: Maioria das situações por erro operacional
*/

CURSOR c_main IS
    SELECT 
        'T_WORK_Q'              as  table_name
        , SYSDATE               as  create_date
        , '001'                 as  error_code   
        , wkq.wh_id
        , wkq.work_q_id
        , wkq.pick_ref_number   as  HU_ID
        , wkq.from_location_id  as  location_id
    FROM t_work_q wkq
    WHERE wkq.work_type = '06'
    AND wkq.work_status = 'U'
    AND wkq.pick_ref_number is not null
    AND not exists (select 1 from t_hu_master hum
                    where   hum.hu_id = wkq.pick_ref_number
                    and     hum.wh_id = wkq.wh_id
                    and     hum.location_id = wkq.from_location_id)
    AND rownum <= 5;
rec_main c_main%ROWTYPE;


     -- Error handling variables
     c_vchObjName   VARCHAR2(30 CHAR); -- The name that uniquely tags this object.
     v_vchErrorMsg  VARCHAR2(2000 CHAR);
     v_nErrorCode   NUMBER;
     v_nCount       NUMBER;
     v_vchHost      VARCHAR2(2000 CHAR);
     
     -- Exceptions
     e_KnownError   EXCEPTION;
     e_UnknownError EXCEPTION;


BEGIN

    SELECT SYS_GUID() INTO v_vchHost FROM DUAL;
    
    FOR rec_main IN c_main	LOOP
    
        IF c_main%NOTFOUND Then
          EXIT;
        END IF;
                
        INSERT INTO TMP_INCONSISTENCY (HOST_GROUP_ID, TABLE_NAME, ERROR_CODE, WH_ID, HU_ID, WORK_Q_ID, CREATE_DATE, LOCATION_ID)
        VALUES (v_vchHost, rec_main.table_name, rec_main.error_code, rec_main.wh_id, rec_main.hu_id, rec_main.work_q_id, rec_main.create_date, rec_main.location_id);
        
        UPDATE t_work_q set work_status = 'C', employee_id = 'INV_RENNER'
        WHERE work_q_id = rec_main.work_q_id;    
                            
    END LOOP;

    COMMIT;
    
    SELECT COUNT(*) INTO v_nCount FROM TMP_INCONSISTENCY
    WHERE host_group_id = v_vchHost;
    
    dbms_output.put_line ('Quantidade de Registros corrigidos: '||v_nCount); 	
	
 EXCEPTION 
          WHEN OTHERS THEN
               ROLLBACK;
               v_nErrorCode  := -20006;
               v_vchErrorMsg := 'SQLERRM = ' || SQLERRM;
               RAISE e_UnknownError;

END;