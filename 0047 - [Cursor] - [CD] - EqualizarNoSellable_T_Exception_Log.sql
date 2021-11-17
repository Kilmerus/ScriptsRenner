SET SERVEROUTPUT ON
DECLARE


    CURSOR c_main IS
       SELECT 
            item_number
            , wh_id
            , QTY_A_DISPONIBILIZAR as qty
            FROM (
                SELECT 
                    item_number
                    , wh_id
                    , QTY_HJ
                    , RMS_DISP
                    , RMS_SOH
                    , RMS_NON
                    , po_sto
                    , CASE WHEN RMS_DISP < 0 THEN (RMS_NON - RMS_SOH) + (QTY_HJ+po_sto) 
                        WHEN RMS_SOH = 0 THEN 0
                        WHEN RMS_SOH > 0 AND ((RMS_SOH = QTY_HJ) AND RMS_NON = QTY_HJ) THEN QTY_HJ
                        WHEN QTY_HJ > RMS_SOH THEN RMS_NON
                        WHEN (RMS_SOH > QTY_HJ) and RMS_DISP < QTY_HJ THEN QTY_HJ - RMS_DISP
                        WHEN (RMS_SOH = QTY_HJ) and RMS_DISP < QTY_HJ THEN RMS_NON
                        WHEN (RMS_SOH = QTY_HJ) and RMS_DISP = QTY_HJ THEN 0
                        WHEN RMS_DISP = QTY_HJ THEN 0
                        WHEN RMS_DISP > QTY_HJ THEN 0
                        ELSE 0.5 END QTY_A_DISPONIBILIZAR
                FROM (
                    SELECT 
                        log.item_number
                        , log.wh_id
                        , sum(sto.actual_qty)   as QTY_HJ
                        , rms.stock_on_hand - rms.non_sellable_qty AS  RMS_DISP
                        , rms.stock_on_hand     as RMS_SOH
                        , rms.non_sellable_qty  as RMS_NON    
                        , NVL(sum (po.qty_unavailable),0) as po_sto
                    FROM t_exception_log log
                        inner join item_loc_soh@consulta_rms rms
                            on rms.item = log.item_number
                            and rms.loc = log.wh_id+500
                        left join t_stored_item sto
                            on log.wh_id = sto.wh_id
                            and log.item_number = sto.item_number
                        left join t_po_sto_unavailable po
                            on po.item_number = log.item_number
                            and po.wh_id = log.wh_id
                            and po.status = 'O'
                    where log.tran_type = '035'
                    and sto.type = 'STORAGE'
                    and sto.location_id not in ('RETENCAO')
                    GROUP BY 
                    log.item_number
                        , log.wh_id
                        , rms.stock_on_hand 
                        , rms.non_sellable_qty))
                WHERE QTY_A_DISPONIBILIZAR > 0
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
            (v_vchHost,'192',rec_main.item_number,null,0,0,rec_main.qty,null,null,null,'6',null,'TRBL','ATS','HJS_DISP',rec_main.wh_id,SYSDATE,null,null,null,null,null,null,null,null,null,null,null,null,null,null,'001');
                
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
           'HJS_DISP',
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

-- dbms_output.put_line ('Tarefa Criada para o LPN: '||rec_main.HU_ID); 	
 EXCEPTION -- Exceção do Laço (For)
          WHEN OTHERS THEN
               ROLLBACK;
               v_nErrorCode  := -20006;
               v_vchErrorMsg := 'SQLERRM = ' || SQLERRM;
               RAISE e_UnknownError;

END;