set serveroutput on;
DECLARE

/*Versão 2.0 - KI 1067*/

-- SUBSTITUIR A VARIÁVEL COM O NÚMERO DO CHAMADO
v_vchTicket    VARCHAR2(2000 CHAR) := '_CHAMADO_';   


CURSOR c_main IS
    SELECT 
        ITEM
        , WH_ID
        , TRANSACTION_CODE
        , LOC
        , SUM_SOH
        , SUM_HJ
        , SUM_NON
        , SUM_HJ_UNA
        , DIF_RMS_HJ
        , INVENTORY_STATUS_BEFORE
        , INVENTORY_STATUS_AFTER
    FROM 
    (SELECT
      ITEM
      , WH_ID
      , TRANSACTION_CODE
      , LOC
      , SUM_SOH
      , SUM_HJ
      , SUM_NON
      , SUM_HJ_UNA
      , CASE WHEN DIF_RMS_HJ < 0 THEN DIF_RMS_HJ*(-1) ELSE DIF_RMS_HJ END DIF_RMS_HJ
      , INVENTORY_STATUS_BEFORE
      , CASE  WHEN    INVENTORY_STATUS_BEFORE = 'AVAILABLE'   THEN    'HOLD'
              WHEN    INVENTORY_STATUS_BEFORE = 'HOLD'        THEN    'AVAILABLE'
              END     INVENTORY_STATUS_AFTER
    FROM (
       SELECT
         RMS.ITEM                    AS  ITEM
         , RMS.LOC                   AS  LOC  
         , TMP.WH_ID
         , RMS.STOCK_ON_HAND    AS  SUM_SOH
         , SUM(STO.ACTUAL_QTY)      AS  SUM_HJ
         , RMS.NON_SELLABLE_QTY AS  SUM_NON     
         , NVL(SUM(STO.UNAVAILABLE_QTY),0)  AS  SUM_HJ_UNA
         , RMS.NON_SELLABLE_QTY-NVL(SUM(STO.UNAVAILABLE_QTY),0) AS  DIF_RMS_HJ
         , CASE   WHEN (RMS.NON_SELLABLE_QTY-NVL(SUM(STO.UNAVAILABLE_QTY),0)) > 0 THEN '750'
                  WHEN (RMS.NON_SELLABLE_QTY-NVL(SUM(STO.UNAVAILABLE_QTY),0)) < 0 THEN '700' END TRANSACTION_CODE
         , CASE   WHEN (RMS.NON_SELLABLE_QTY-NVL(SUM(STO.UNAVAILABLE_QTY),0)) > 0 THEN 'HOLD'
                  WHEN (RMS.NON_SELLABLE_QTY-NVL(SUM(STO.UNAVAILABLE_QTY),0)) < 0 THEN 'AVAILABLE' END INVENTORY_STATUS_BEFORE
      FROM ITEM_LOC_SOH@RMS14 RMS
      INNER JOIN DBO.TMP_ITEM TMP
         ON RMS.ITEM = TMP.ITEM_NUMBER
      LEFT JOIN T_STORED_ITEM STO
         ON TMP.ITEM_NUMBER = STO.ITEM_NUMBER
         AND TMP.WH_ID = STO.WH_ID
      WHERE LOC = '999'
         GROUP BY RMS.ITEM                   
         , RMS.LOC                  
         , RMS.STOCK_ON_HAND  
         , TMP.WH_ID
         , RMS.NON_SELLABLE_QTY
         , RMS.STOCK_ON_HAND)) BLOCO1
    WHERE BLOCO1.INVENTORY_STATUS_BEFORE IS NOT NULL;
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
    VALUES (null,v_vchHost,rec_main.transaction_code,rec_main.item,null,rec_main.DIF_RMS_HJ,rec_main.DIF_RMS_HJ,0,null,REC_MAIN.INVENTORY_STATUS_BEFORE,rec_main.INVENTORY_STATUS_AFTER,'42',null,'REN_BLOQUEIO','REN_BLOQUEIO',v_vchTicket,REC_MAIN.WH_ID,sysdate,'EA',null,null,null,null,null,null,null,null,null,null,null,null,REC_MAIN.ITEM,'001');
    
							
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
