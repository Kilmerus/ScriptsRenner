SET SERVEROUTPUT ON
DECLARE

    CURSOR c_main IS
       SELECT 
            bloco1.item_number
            , bloco1.wh_id
            , bloco1.QTY_A_DISPONIBILIZAR as qty
            , (select client_code from t_item_master where item_number = bloco1.item_number and wh_id = bloco1.wh_id) as client_code
            FROM (
                select 
                item_number
                , wh_id
                , quantity as QTY_A_DISPONIBILIZAR
                from t_exception_log 
                where tran_type = '035'
            ) bloco1
                WHERE bloco1.QTY_A_DISPONIBILIZAR > 0
                --and rownum <= 5
                ;
        rec_main c_main%ROWTYPE;

    -- Error handling variables
    c_vchObjName  VARCHAR2(30 CHAR); -- The name that uniquely tags this object.
    v_vchErrorMsg VARCHAR2(2000 CHAR);
    v_nErrorCode  NUMBER;
    -- Exceptions
    e_KnownError   EXCEPTION;
    e_UnknownError EXCEPTION;
    
    v_vchHost   VARCHAR2(50 CHAR);
    v_vchReturn VARCHAR2(2000 CHAR);
    
BEGIN
	FOR rec_main IN c_main	LOOP
	
        IF c_main%NOTFOUND Then
          EXIT;
        END IF;
        
        -- HOST
        SELECT SYS_GUID() INTO v_vchHost    from dual;
    
        INSERT INTO t_al_host_inventory_adjustment 
            (HOST_GROUP_ID,TRANSACTION_CODE,ITEM_NUMBER,LOT_NUMBER,QUANTITY_BEFORE,QUANTITY_AFTER,QUANTITY_CHANGE,HU_ID,INVENTORY_STATUS_BEFORE,INVENTORY_STATUS_AFTER,REASON_CODE,FIFO_DATE,FROM_LOCATION_ID,TO_LOCATION_ID,USER_ID,WH_ID,RECORD_CREATE_DATE,UOM,REFERENCE_CODE,GEN_ATTRIBUTE_VALUE1,GEN_ATTRIBUTE_VALUE2,GEN_ATTRIBUTE_VALUE3,GEN_ATTRIBUTE_VALUE4,GEN_ATTRIBUTE_VALUE5,GEN_ATTRIBUTE_VALUE6,GEN_ATTRIBUTE_VALUE7,GEN_ATTRIBUTE_VALUE8,GEN_ATTRIBUTE_VALUE9,GEN_ATTRIBUTE_VALUE10,GEN_ATTRIBUTE_VALUE11,DISPLAY_ITEM_NUMBER,CLIENT_CODE) 
        VALUES 
            (v_vchHost,'192',rec_main.item_number,null,0,0,rec_main.qty,null,null,null,'6',null,'TRBL','ATS','HJS_CURSOR',rec_main.wh_id,SYSDATE,null,null,null,null,null,null,null,null,null,null,null,null,null,null,rec_main.client_code);
                
        COMMIT;
        
        SELECT PKG_WEBSERVICES.USF_CALL_WEBSERVICE('EXP_INV_ADJUST',v_vchHost) INTO v_vchReturn
        FROM DUAL;
        
        COMMIT;
        
        INSERT INTO t_tran_log_holding
          (tran_type,
           description,
           start_tran_date,
           start_tran_time,
           end_tran_date,
           end_tran_time,
           employee_id,
           control_number,
           line_number,
           wh_id,
           num_items,
           item_number,
           tran_qty,
           elapsed_time,
           control_number_2)
        VALUES
          ('035',
           'Equalização Non Sellable',
           sysdate,
           sysdate,
           sysdate,
           sysdate,
           'HJS_CURSOR',
           'Equalização',
           null,
           rec_main.wh_id,
           rec_main.qty,
           rec_main.item_number,
           rec_main.qty,
           10,
           'Disponi. Auto');
               
        END LOOP;
        
        commit;
        
COMMIT;


 EXCEPTION -- Exceção do Laço (For)
          WHEN OTHERS THEN
               ROLLBACK;
               v_nErrorCode  := -20006;
               v_vchErrorMsg := 'SQLERRM = ' || SQLERRM;
               RAISE e_UnknownError;

END;