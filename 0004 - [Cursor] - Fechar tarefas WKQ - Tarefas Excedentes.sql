/*
Fechar tarefas excedentes
*/

SET SERVEROUTPUT ON
DECLARE

CURSOR c_main IS
    SELECT 
        LOCATION_ID
        , WH_ID
        , CONTADOR
    FROM (
        SELECT 
            wkq.location_id
            , wkq.wh_id
            , COUNT(*) as CONTADOR
        FROM t_work_q wkq
            WHERE   wkq.work_status = 'U' 
            AND     wkq.work_type IN ('80')        
        GROUP BY wkq.location_id, wkq.wh_id
        HAVING COUNT(*) > 1)
    WHERE ROWNUM <= 4;
rec_main c_main%ROWTYPE;


     -- Error handling variables
     c_vchObjName   VARCHAR2(30 CHAR); -- The name that uniquely tags this object.
     v_vchErrorMsg  VARCHAR2(2000 CHAR);
     v_nErrorCode   NUMBER;
     v_nCount       NUMBER;
     -- Exceptions
     e_KnownError   EXCEPTION;
     e_UnknownError EXCEPTION;


BEGIN
	FOR rec_main IN c_main	LOOP
	
	IF c_main%NOTFOUND Then
      EXIT;
	END IF;
    
    
    <<CloseWKQ>>
    -- FECHAR TAREFA
    UPDATE t_work_q set work_status = 'C'
    WHERE work_q_id in (select 
                            min(wkq.work_q_id)
                        FROM t_work_q wkq
                            where   wkq.work_status = 'U' 
                            and     wkq.work_type in ('80')
                            and     wkq.location_id =   rec_main.location_id
                            and     wkq.wh_id       =   rec_main.wh_id);
                            
    COMMIT;
    
    -- Buscar se há mais tarefas a serem encerradas                      
    SELECT COUNT(*) into v_nCount
    FROM t_work_q wkq
        WHERE   wkq.work_status = 'U' 
        AND     wkq.work_type IN ('80')
        AND     wkq.location_id = rec_main.location_id
        AND     wkq.wh_id = rec_main.wh_id;
    
    IF v_nCount > 1 THEN
        GOTO CloseWKQ;
    END IF;
    
							
  END LOOP;

COMMIT;

-- dbms_output.put_line ('Tarefa Criada para o LPN: '||rec_main.HU_ID); 	
 EXCEPTION -- Exceção do Laço (For)
          WHEN OTHERS THEN
               ROLLBACK;
               v_nErrorCode  := -20006;
               v_vchErrorMsg := 'SQLERRM = ' || SQLERRM;
               RAISE e_UnknownError;

END;