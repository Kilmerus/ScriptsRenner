SET SERVEROUTPUT ON
DECLARE

/*  Reenvio de PRESHIP com erro   
    **** GUSTAVO FÉLIX
    **** 07/07/2020
*/
CURSOR c_main IS
   SELECT 
        DISTINCT SHM.host_group_id as HostGroup
        , SHM.order_number
        , SHM.wh_id
        , 'Cannot find dispatch method' AS ErrorType
    FROM DBO.t_al_host_shipment_master SHM
    WHERE shm.record_create_date >= trunc(SYSDATE)-5
    AND shm.transaction_code = '936'
    AND not exists (SELECT 1 FROM DBO.t_webservice_alloc_log alo
                    WHERE alo.param1 = shm.host_group_id
                    AND alo.soap_respond like '%SuccessStatus%')
    AND exists (SELECT 1 FROM DBO.t_webservice_alloc_log alo
                    WHERE alo.param1 = shm.host_group_id
                    AND alo.soap_respond like '%Cannot find dispatch method%')    
    UNION ALL
    
    SELECT 
        DISTINCT SHM.host_group_id
        , SHM.order_number
        , SHM.wh_id
        , 'Familia não encontrada' AS ErrorType
    FROM DBO.t_al_host_shipment_master SHM
    WHERE shm.record_create_date >= trunc(SYSDATE)-5
    AND shm.transaction_code = '936'
    AND not exists (SELECT 1 FROM DBO.t_webservice_alloc_log alo
                    WHERE alo.param1 = shm.host_group_id
                    AND alo.soap_respond like '%SuccessStatus%')
    AND  exists (SELECT 1 FROM DBO.t_webservice_alloc_log alo
                    WHERE alo.param1 = shm.host_group_id
                    AND alo.soap_respond like '%Familia não encontrada%')  ;
rec_main c_main%ROWTYPE;
    -- Error handling variables
    c_vchObjName  VARCHAR2(30 CHAR); -- The name that uniquely tags this object.
    v_vchErrorMsg VARCHAR2(2000 CHAR);
    v_nErrorCode  NUMBER;   
    -- Exceptions
    e_KnownError   EXCEPTION;
    e_UnknownError EXCEPTION;   
    -- Variáveis
    v_numCount          NUMBER:= 0;
    v_vchHost           VARCHAR2(50 CHAR);
    v_vchReturn         VARCHAR2(2000 CHAR);
BEGIN
    FOR rec_main IN c_main	LOOP    
        IF c_main%NOTFOUND Then
            EXIT;
        END IF; 
       

    -- INVOCAR SERVIÇo
    select PKG_WEBSERVICES.USF_CALL_WEBSERVICE('EXP_PRE_SHIP', rec_main.HostGroup) into v_vchReturn FROM DUAL;
    
    insert into t_tran_log_holding(tran_log_holding_id, tran_type, description, start_tran_date, start_tran_time, employee_id, control_number, control_number_2, wh_id)
    values(null, '086', 'Reenvio ShipInfo' , sysdate, sysdate, 'HJS', rec_main.order_number, rec_main.ErrorType, rec_main.wh_id);
                    
    END LOOP;

COMMIT;

 EXCEPTION -- Exceção do Laço (For)
          WHEN OTHERS THEN
               ROLLBACK;
               v_nErrorCode  := -20006;
               v_vchErrorMsg := 'SQLERRM = ' || SQLERRM;
               RAISE e_UnknownError;

END;

