set serveroutput on;
DECLARE

/*
    SCRIPT LIVRE PARA ENVIAR AJUSTE
    -- Escolher se é para Bloquear ou Liberar
    -- Não há validação, é feito apenas o envio
*/


CURSOR c_main IS
    SELECT 
        itm.item_number as item
        , itm.wh_id
        , itm.qty AS dif_rms_hj
        , 'AVAILABLE'   AS inventory_status_before
        , 'HOLD'        AS inventory_status_after
        , 700           AS transaction_code
        , (SELECT client_code FROM t_item_master 
            WHERE item_number = itm.item_number
            AND wh_id = itm.wh_id) AS client_code
        FROM dbo.tmp_item itm;
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
			
   --
    INSERT INTO T_AL_HOST_INVENTORY_ADJUSTMENT (ADJUSTMENT_ID,HOST_GROUP_ID,TRANSACTION_CODE,ITEM_NUMBER,LOT_NUMBER,QUANTITY_BEFORE,QUANTITY_AFTER,QUANTITY_CHANGE,HU_ID,INVENTORY_STATUS_BEFORE,INVENTORY_STATUS_AFTER,REASON_CODE,FIFO_DATE,FROM_LOCATION_ID,TO_LOCATION_ID,USER_ID,WH_ID,RECORD_CREATE_DATE,UOM,REFERENCE_CODE,GEN_ATTRIBUTE_VALUE1,GEN_ATTRIBUTE_VALUE2,GEN_ATTRIBUTE_VALUE3,GEN_ATTRIBUTE_VALUE4,GEN_ATTRIBUTE_VALUE5,GEN_ATTRIBUTE_VALUE6,GEN_ATTRIBUTE_VALUE7,GEN_ATTRIBUTE_VALUE8,GEN_ATTRIBUTE_VALUE9,GEN_ATTRIBUTE_VALUE10,GEN_ATTRIBUTE_VALUE11,DISPLAY_ITEM_NUMBER,CLIENT_CODE) 
    VALUES (null,v_vchHost,rec_main.transaction_code,rec_main.item,null,rec_main.DIF_RMS_HJ,rec_main.DIF_RMS_HJ,0,null,REC_MAIN.INVENTORY_STATUS_BEFORE,rec_main.INVENTORY_STATUS_AFTER,'42',null,'REN_BLOQUEIO','REN_BLOQUEIO','YOUCOM',REC_MAIN.WH_ID,sysdate,'EA',null,null,null,null,null,null,null,null,null,null,null,null,REC_MAIN.ITEM,rec_main.client_code);
    
							
  END LOOP;

COMMIT;

    select count(*) into v_vchIns from t_al_host_inventory_adjustment where host_group_id = v_vchHost;
    
    IF v_vchIns > 0 THEN 
      
      SELECT PKG_WEBSERVICES.USF_CALL_WEBSERVICE('EXP_INV_ADJUST', v_vchHost) into v_vchReturn FROM dual;
      
      dbms_output.put_line( ' Verificar host na webservice alloc log: ' || v_vchHost); 
        ELSE
            dbms_output.put_line( ' falha ao inserir na al host inv adj: ' ||v_vchHost || 'Msg: ' ||v_vchReturn);
    END IF;

 EXCEPTION -- Exceção do Laço (For)
          WHEN OTHERS THEN
               ROLLBACK;
               v_nErrorCode  := -20006;
               v_vchErrorMsg := 'SQLERRM = ' || SQLERRM;
               RAISE e_UnknownError;

END;
