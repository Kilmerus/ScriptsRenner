SET SERVEROUTPUT ON
DECLARE


--********************************************************************************************************

--								QUANTIDADE BLOQUEADA NEGATIVA

--********************************************************************************************************

CURSOR c_main IS
 SELECT 
        ITEM as ITEM_NUMBER
        , wh_id
        , non_sellable_qty*(-1) as qty
        , TO_CHAR(SYSDATE,'DDMMYYYY') as PO
    FROM (
        SELECT 
            rms.item
            , rms.loc-500 as wh_id
            , sum(sto.actual_qty) as sto_qty
            , rms.stock_on_hand
            , rms.non_sellable_qty
            , rms.in_transit_qty
        FROM item_loc_soh@consulta_rms rms 
        LEFT JOIN t_stored_item sto
            on sto.wh_id+500 = rms.loc
            and sto.item_number = rms.item
        WHERE rms.loc in (614,824,964) 
        and rms.non_sellable_qty < 0
        GROUP BY 
        rms.item
        , rms.loc-500
        , rms.stock_on_hand
        , rms.non_sellable_qty
        , rms.in_transit_qty)
    WHERE sto_qty is null
    and stock_on_hand = 0
    and in_transit_qty = 0
    --and rownum <= 500
    --and item = '539355690'
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
            (v_vchHost,'192',rec_main.item_number,null,0,0,rec_main.qty,null,null,null,'6',null,'ATS','TRBL','HJS_SG',rec_main.wh_id,SYSDATE,null,rec_main.po,null,null,null,null,null,null,null,null,null,null,null,null,'001');
                
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
           control_number_2,
           line_number,
           wh_id,
           num_items,
           item_number,
           tran_qty,
           elapsed_time)
        VALUES
          ('006',
           'Equalização RMS - Sala de Guerra',
           sysdate,
           sysdate,
           sysdate,
           sysdate,
           'HJS_SG',
           rec_main.po,
           'Equalização Saldo Indisp.',
           null,
           rec_main.wh_id,
           rec_main.qty,
           rec_main.item_number,
           rec_main.qty,
           10);
               
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