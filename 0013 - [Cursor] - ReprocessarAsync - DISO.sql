SET SERVEROUTPUT ON
DECLARE


CURSOR c_main IS
    SELECT 
        eve.scevent_name
        , ASY.status
        , asy.procobject
        , usf_get_async_event_data(asy.event_id) as HOST_GROUP_ID
        , COUNT(*)
    FROM DBO.ea_t_async_work_queue ASY
      INNER JOIN DBO.ea_t_scevent eve
        ON asy.scevent_id = eve.scevent_id
    WHERE ASY.date_added >= trunc(SYSDATE)
    AND	ASY.STATUS = 'TEMP_STATUS'
    and asy.procobject = 'WABACKGROUND.WCS>App Distribution Results'
    GROUP BY eve.SCEVENT_NAME, ASY.status, asy.procobject, usf_get_async_event_data(asy.event_id);
rec_main c_main%ROWTYPE;


     -- Error handling variables
     c_vchObjName  VARCHAR2(30 CHAR); -- The name that uniquely tags this object.
     v_vchErrorMsg VARCHAR2(2000 CHAR);
     v_nErrorCode  NUMBER;
     -- Exceptions
     e_KnownError   EXCEPTION;
     e_UnknownError EXCEPTION;
     ErrMsg         VARCHAR2(3100);


BEGIN

    --
    UPDATE  ea_t_async_work_queue 
        set status = 'TEMP_STATUS'
        , date_started = SYSDATE
        where procobject = 'WABACKGROUND.WCS>App Distribution Results'
        and status = 'NEW'
        and date_started is null
        and rownum <= 30;
    
    
	FOR rec_main IN c_main	LOOP
	
	IF c_main%NOTFOUND Then
      EXIT;
	END IF;
    
            -- PROCESSAMENTO
            dbo.br_usp_al_import_dist_results ( rec_main.HOST_GROUP_ID, ErrMsg ); 
            --DBMS_OUTPUT.put_line (ErrMsg ); 
							
  END LOOP;
  
  --
  UPDATE ea_t_async_work_queue
    set status = 'SUCCESS'
    , date_finished = SYSDATE
    , alert_id = 200
    WHERE STATUS = 'TEMP_STATUS';

COMMIT;

-- dbms_output.put_line ('Tarefa Criada para o LPN: '||rec_main.HU_ID); 	
 EXCEPTION -- Exceção do Laço (For)
          WHEN OTHERS THEN
               ROLLBACK;
               v_nErrorCode  := -20006;
               v_vchErrorMsg := 'SQLERRM = ' || SQLERRM;
               RAISE e_UnknownError;

END;