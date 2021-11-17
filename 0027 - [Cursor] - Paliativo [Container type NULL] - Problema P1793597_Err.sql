SET SERVEROUTPUT ON
DECLARE

-- CORREÇÃO PALIATIVA PROBLEMA P1793597 (ERRO Operacional - SEM confirmação de leitura)
-- CRIADO: 12/02/2020 by Gustavo Félix
CURSOR c_main IS
        SELECT 
            HU_ID
            , WH_ID
            , LOCATION_ID
            , CONTROL_NUMBER
            , LOAD_ID
            , ERRO_PROGRAM
            --, LEITURA
            --, CONV_DESVIO
            --, CASE WHEN LEITURA > CONV_DESVIO THEN 'ERRO' ELSE 'OK' END ERRO_PROGRAM
        FROM (
            SELECT
                HUM.hu_id
                , HUM.wh_id
                , HUM.load_id
                , HUM.location_id
                , HUM.control_number
                , 'SEM IN DATA' as ERRO_PROGRAM
            FROM
                DBO.t_hu_master HUM
            WHERE HUM.wh_id = '464'
                AND HUM.location_id <> 'RECE_TRANSF'
                AND HUM.load_id IN ( SELECT display_po_number FROM t_po_master WHERE wh_id = '464')
                AND HUM.container_type IS NULL
                AND ( HUM.location_id LIKE '%CTN%%'
                      OR HUM.location_id = 'EST_REC_RS'
                      OR HUM.location_id LIKE '%DISTCX%' )
                AND not exists (select 1 from DBO.t_al_host_webservice_in_data ind
                                where ind.hu_id = hum.hu_id
                                and ind.wh_id = hum.wh_id));
rec_main c_main%ROWTYPE;


     -- Error handling variables
     c_vchObjName  VARCHAR2(30 CHAR); -- The name that uniquely tags this object.
     v_vchErrorMsg VARCHAR2(2000 CHAR);
     v_nErrorCode  NUMBER;
     -- Exceptions
     e_KnownError   EXCEPTION;
     e_UnknownError EXCEPTION;


BEGIN
	FOR rec_main IN c_main	LOOP
	
	IF c_main%NOTFOUND Then
      EXIT;
	END IF;
			
        Insert into DBO.t_exception_log (TRAN_TYPE,DESCRIPTION,EXCEPTION_DATE,EXCEPTION_TIME,EMPLOYEE_ID,WH_ID,LOAD_ID,LINE_NUMBER, LOCATION_ID, ERROR_MESSAGE) 
        VALUES ('874', 'CONTAINER TYPE NULL', SYSDATE, SYSDATE, 'HJS', REC_MAIN.WH_ID, REC_MAIN.LOAD_ID, REC_MAIN.CONTROL_NUMBER, REC_MAIN.LOCATION_ID, 'SEM IN DATA');
        
        UPDATE DBO.t_hu_master set CONTAINER_TYPE = 'CX'
        WHERE   hu_id = REC_MAIN.hu_id
        AND     wh_id = REC_MAIN.wh_id
        AND     container_type is null;
			
  END LOOP;

COMMIT;

EXCEPTION -- Exceção do Laço (For)
          WHEN OTHERS THEN
               ROLLBACK;
               v_nErrorCode  := -20006;
               v_vchErrorMsg := 'SQLERRM = ' || SQLERRM;
               RAISE e_UnknownError;

END;