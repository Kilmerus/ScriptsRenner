SET SERVEROUTPUT ON
DECLARE


CURSOR c_main IS
    
    SELECT 
       WH_ID
       , ITEM_NUMBER
       , QTD_NON_SEL
       , QTD_ENVIADA
       , QTD_A
       , QTD_B
       , STATUS
    FROM (
        SELECT 
            wh_id
            , item_number        
            , nonse         AS  QTD_NON_SEL
            , sum(QTY)      AS  QTD_ENVIADA
            , sum(QTY)/2    AS  QTD_A
            , nonse*(-1)    AS  QTD_B     
            , CASE WHEN sum(QTY)/2 = nonse*(-1) THEN 'OK'
                ELSE  '' END STATUS
        FROM (
            SELECT 
                al.wh_id
                , al.item_number
                , SUM(al.quantity_change) as QTY
                , (select non_sellable_qty from item_loc_soh@consulta_rms where item = al.item_number and loc = al.wh_id+500) as nonse
                , al.reference_code
                , count(distinct al.user_id)
            from DBO.t_al_host_inventory_adjustment al
            where al.transaction_code = '192' 
            --AND al.item_number = '548218945'
            --and reference_code  = '10781208' 
            --AND record_create_date >= trunc(SYSDATE)-90
            GROUP BY
            al.item_number
                , al.reference_code
                , al.wh_id
            HAVING count(distinct al.user_id) > 1)
        WHERE nonse < 0
        GROUP BY 
            wh_id
                , item_number        
                , nonse)
        WHERE STATUS = 'OK'
        --AND rownum <= 200
        ;
rec_main c_main%ROWTYPE;
--
--    CURSOR c_reprocessar IS
--        SELECT DISTINCT reference_code as reference_code
--        FROM t_al_host_inventory_adjustment
--        WHERE host_group_id = '000';
--    rec_reprocessar c_reprocessar%ROWTYPE;


    -- Error handling variables
    c_vchObjName  VARCHAR2(30 CHAR); -- The name that uniquely tags this object.
    v_vchErrorMsg VARCHAR2(2000 CHAR);
    v_nErrorCode  NUMBER;
    
    -- Exceptions
    e_KnownError   EXCEPTION;
    e_UnknownError EXCEPTION;
    
    v_vchHostGroup      VARCHAR2(100 CHAR);
    v_vchReturn         VARCHAR2(5000 CHAR);
    
BEGIN

    FOR rec_main IN c_main	LOOP
    
        IF c_main%NOTFOUND Then
            EXIT;
        END IF;


    SELECT SYS_GUID() INTO v_vchHostGroup FROM DUAL;
    
    
        INSERT INTO t_al_host_inventory_adjustment 
            (HOST_GROUP_ID,TRANSACTION_CODE,ITEM_NUMBER,LOT_NUMBER,QUANTITY_BEFORE,QUANTITY_AFTER,QUANTITY_CHANGE,HU_ID,INVENTORY_STATUS_BEFORE,INVENTORY_STATUS_AFTER,REASON_CODE,FIFO_DATE,FROM_LOCATION_ID,TO_LOCATION_ID,USER_ID,WH_ID,RECORD_CREATE_DATE,UOM,REFERENCE_CODE,GEN_ATTRIBUTE_VALUE1,GEN_ATTRIBUTE_VALUE2,GEN_ATTRIBUTE_VALUE3,GEN_ATTRIBUTE_VALUE4,GEN_ATTRIBUTE_VALUE5,GEN_ATTRIBUTE_VALUE6,GEN_ATTRIBUTE_VALUE7,GEN_ATTRIBUTE_VALUE8,GEN_ATTRIBUTE_VALUE9,GEN_ATTRIBUTE_VALUE10,GEN_ATTRIBUTE_VALUE11,DISPLAY_ITEM_NUMBER,CLIENT_CODE) 
        VALUES 
            (v_vchHostGroup,'192',rec_main.item_number,null,0,0,rec_main.qtd_a,null,null,null,null,null,'ATS','TRBL','HJS_SG',rec_main.wh_id,SYSDATE,null,'500',null,null,null,null,null,null,null,null,null,null,null,null,'001');   

        COMMIT;
        
        SELECT PKG_WEBSERVICES.USF_CALL_WEBSERVICE('EXP_INV_ADJUST',v_vchHostGroup) INTO v_vchReturn FROM DUAL;
        
        COMMIT;
        
        --dbms_output.put_line (v_vchHostGroup); 	
        --dbms_output.put_line (v_vchReturn); 	
                            
    END LOOP;
    
COMMIT;
    
     --REPROCESSAR
--	FOR rec_reprocessar IN c_reprocessar	LOOP
--	
--        IF c_reprocessar%NOTFOUND Then
--          EXIT;
--        END IF;
--    
--        -- HOST
--        SELECT SYS_GUID() INTO v_vchHostGroup    from dual;
--        
--        UPDATE t_al_host_inventory_adjustment SET host_group_id = v_vchHostGroup
--        WHERE reference_code = rec_reprocessar.reference_code;
--    
--        SELECT PKG_WEBSERVICES.USF_CALL_WEBSERVICE('EXP_INV_ADJUST',v_vchHostGroup) INTO v_vchReturn
--        FROM DUAL;
--                
--    END LOOP;
-- dbms_output.put_line ('Tarefa Criada para o LPN: '||rec_main.HU_ID); 	
 EXCEPTION -- Exceção do Laço (For)
          WHEN OTHERS THEN
               ROLLBACK;
               v_nErrorCode  := -20006;
               v_vchErrorMsg := 'SQLERRM = ' || SQLERRM;
               RAISE e_UnknownError;

END;