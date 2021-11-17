SET SERVEROUTPUT ON
DECLARE


    CURSOR c_main IS
        SELECT
        POM.po_number
        , SUBSTR(POM.po_number,0,8) as PO
        , POD.item_number
        , SUM(POD.qty) as QTY
        , pom.display_po_number
        , pom.wh_id
        , pom.create_date
        FROM t_po_master pom
        inner join t_po_detail POD
            ON  pom.po_number = POD.po_number
            AND pom.wh_id = POD.wh_id
        WHERE pom.status = 'C'
        AND pom.create_date >= trunc(SYSDATE)-60
        AND pom.type_id in ('1762')
        AND pom.client_code = '001'
        AND  NOT EXISTS (select 1 -- DISPONIBILIZAÇÃO DE ESTOQUE
                       from t_tran_log log
                       where log.tran_type = '192'
                       and log.control_number = pom.po_number
                       and log.wh_id = pom.wh_id)
        AND NOT EXISTS (select 1 -- STO_UNAVAILABLE
                       from DBO.t_po_sto_unavailable sto
                       WHERE STO.po_number = pom.po_number
                       AND sto.wh_id = pom.wh_id)
       -- AND pom.po_number like '%2509117%'
        GROUP BY 
        POM.po_number
        , POD.item_number
        , pom.display_po_number
        , pom.wh_id
        , pom.create_date;
        rec_main c_main%ROWTYPE;

    CURSOR c_reprocessar IS
        SELECT DISTINCT reference_code FROM t_al_host_inventory_adjustment
        WHERE host_group_id = '000';
    rec_reprocessar c_reprocessar%ROWTYPE;

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
    
        INSERT INTO t_al_host_inventory_adjustment 
            (HOST_GROUP_ID,TRANSACTION_CODE,ITEM_NUMBER,LOT_NUMBER,QUANTITY_BEFORE,QUANTITY_AFTER,QUANTITY_CHANGE,HU_ID,INVENTORY_STATUS_BEFORE,INVENTORY_STATUS_AFTER,REASON_CODE,FIFO_DATE,FROM_LOCATION_ID,TO_LOCATION_ID,USER_ID,WH_ID,RECORD_CREATE_DATE,UOM,REFERENCE_CODE,GEN_ATTRIBUTE_VALUE1,GEN_ATTRIBUTE_VALUE2,GEN_ATTRIBUTE_VALUE3,GEN_ATTRIBUTE_VALUE4,GEN_ATTRIBUTE_VALUE5,GEN_ATTRIBUTE_VALUE6,GEN_ATTRIBUTE_VALUE7,GEN_ATTRIBUTE_VALUE8,GEN_ATTRIBUTE_VALUE9,GEN_ATTRIBUTE_VALUE10,GEN_ATTRIBUTE_VALUE11,DISPLAY_ITEM_NUMBER,CLIENT_CODE) 
        VALUES 
            ('000','192',rec_main.item_number,null,0,0,rec_main.qty,null,null,null,null,null,'TRBL','ATS','HJS_AUTO',rec_main.wh_id,SYSDATE,null,rec_main.po,null,null,null,null,null,null,null,null,null,null,null,null,'001');
                
               
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
          ('192',
           'Estoque Disponível RMS',
           sysdate,
           sysdate,
           sysdate,
           sysdate,
           'HJS_AUTO',
           rec_main.po_number,
           null,
           rec_main.wh_id,
           rec_main.qty,
           rec_main.item_number,
           rec_main.qty,
           10,
           'Disponi. Auto');
               
        END LOOP;
        
    -- REPROCESSAR
	FOR rec_reprocessar IN c_reprocessar	LOOP
	
        IF c_reprocessar%NOTFOUND Then
          EXIT;
        END IF;
    
        -- HOST
        SELECT SYS_GUID() INTO v_vchHost    from dual;
        
        UPDATE t_al_host_inventory_adjustment SET host_group_id = v_vchHost
        WHERE reference_code = rec_reprocessar.reference_code
        AND user_id = 'HJS_AUTO';
    
        SELECT PKG_WEBSERVICES.USF_CALL_WEBSERVICE('EXP_INV_ADJUST',v_vchHost) INTO v_vchReturn
        FROM DUAL;
                
    END LOOP;
        

COMMIT;

-- dbms_output.put_line ('Tarefa Criada para o LPN: '||rec_main.HU_ID); 	
 EXCEPTION -- Exceção do Laço (For)
          WHEN OTHERS THEN
               ROLLBACK;
               v_nErrorCode  := -20006;
               v_vchErrorMsg := 'SQLERRM = ' || SQLERRM;
               RAISE e_UnknownError;

END;
