SET SERVEROUTPUT ON
DECLARE


    CURSOR c_main IS
       select 
            log.item_number
            , log.wh_id
            , log.tran_qty as qty
            , SUBSTR(log.control_number,0,8) as po
        from t_tran_log log
        where log.tran_type  = '167'
        and log.start_tran_date >= trunc(SYSDATE)-30
        --and item_number = '550551472'
       and not exists (select 1 from t_tran_log log2
                        where log2.item_number = log.item_number
                           and log2.wh_id = log.wh_id
                        and log2.tran_type = '005'
                        and log2.control_number = SUBSTR(log.control_number,0,8))
        order by 1 desc;
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
            (v_vchHost,'192',rec_main.item_number,null,0,0,rec_main.qty,null,null,null,null,null,'TRBL','ATS','HJS_AUTO',rec_main.wh_id,SYSDATE,null,rec_main.po,null,null,null,null,null,null,null,null,null,null,null,null,'001');
                
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
          ('005',
           'Equalização RMS - PO Importado',
           sysdate,
           sysdate,
           sysdate,
           sysdate,
           'HJS_AUTO',
           rec_main.po,
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

-- dbms_output.put_line ('Tarefa Criada para o LPN: '||rec_main.HU_ID); 	
 EXCEPTION -- Exceção do Laço (For)
          WHEN OTHERS THEN
               ROLLBACK;
               v_nErrorCode  := -20006;
               v_vchErrorMsg := 'SQLERRM = ' || SQLERRM;
               RAISE e_UnknownError;

END;