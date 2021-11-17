DECLARE

-- REPROCESSAMENTO DE AJUSTES DE ESTOQUE COM ERRO
-- GUSTAVO FELIX        - 18/12/2019

CURSOR c_main IS
    SELECT 
        inv.item_number                 AS  ITEM
        , inv.quantity_before           AS  QTY_B
        , inv.quantity_after            AS  QTY_A
        , inv.quantity_change           AS  QTY_C
        , inv.inventory_status_before   AS  INV_B
        , inv.inventory_status_after    AS  INV_A
        , inv.record_create_date        AS  DATA_REC
        , exp.error_message             AS  ERROR_M
        , inv.host_group_id             AS  HOST_GROUP
    FROM t_al_host_inventory_adjustment inv
        left join t_exception_log exp
            on inv.host_group_id = exp.location_id
        where inv.wh_id = '499'
        and inv.record_create_date >= trunc(SYSDATE)-30
        and not exists (select 1 from t_webservice_alloc_log
                            where  webservice_id = 'EXP_INV_ADJUST'
                            and param1 = inv.host_group_id
                            )        ;
    rec_main c_main%ROWTYPE;


     -- Error handling variables
     c_vchObjName   VARCHAR2(30 CHAR); -- The name that uniquely tags this object.
     v_vchErrorMsg  VARCHAR2(2000 CHAR);
     v_vchReturn    VARCHAR2(2000 CHAR);
     v_nErrorCode   NUMBER;
     -- Exceptions
     e_KnownError   EXCEPTION;
     e_UnknownError EXCEPTION;


BEGIN
	FOR rec_main IN c_main	LOOP
	
	IF c_main%NOTFOUND Then
      EXIT;
	END IF;
    
        -- Reprocessamento
        SELECT PKG_WEBSERVICES.USF_CALL_WEBSERVICE('EXP_INV_ADJUST', rec_main.HOST_GROUP) into v_vchReturn
        FROM DUAL;
        
        -- Atualizar o Status da Exceção
        UPDATE t_exception_log set STATUS = 'CLOSED', TRACKING_NUMBER = TO_CHAR(SYSDATE,'DD/MM/YYYY HH24:MI:SS')
        WHERE location_id = rec_main.HOST_GROUP;
			
							
  END LOOP;

COMMIT;

EXCEPTION 
          WHEN OTHERS THEN
               ROLLBACK;
               v_nErrorCode  := -20006;
               v_vchErrorMsg := 'SQLERRM = ' || SQLERRM;
               RAISE e_UnknownError;

END;