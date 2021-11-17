SET SERVEROUTPUT ON
DECLARE

/*  
    GERAR SHIPINFO, para pedidos já expedidos
    
    **** GUSTAVO FÉLIX
    **** 20/05/2020
*/

CURSOR c_main IS
    SELECT DISTINCT shm.order_number, shm.wh_id, to_char(sysdate,'DDMMYYYY') AS control
    FROM dbo.t_al_host_shipment_master shm
    WHERE shm.transaction_code = '340'
    AND shm.record_create_date >= TRUNC(sysdate)-20
    AND NOT EXISTS (SELECT 1 FROM t_al_host_shipment_master shm2
                    WHERE shm2.order_number = shm.order_number
                    AND shm2.wh_id = shm.wh_id
                    AND shm2.transaction_code = '936')
    --AND shm.order_number in ('221289146809-1PC','221773526237-1PC')
    ;
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
        
        
        -- HOST
        SELECT SYS_GUID() INTO v_vchHost    from dual;
        
        
        -- INSERIR A CAPA
        INSERT INTO v_al_host_shipment_master(host_group_id, transaction_code, order_number, display_order_number, load_id, pro_number, seal_number, carrier_code, status,
            split_status, total_weight, total_volume, user_id, wh_id, client_code, master_bol_number, order_type, bill_to_code, bill_to_name, bill_to_addr1, bill_to_addr2, bill_to_city,
            bill_to_state, bill_to_zip, bill_to_phone, carrier_mode, delivery_sap, printer_id)
         SELECT v_vchHost,
            '936' shipinfo,
            pkd.order_number,
            orm.display_order_number,
            orm.order_number load_id,
            orm.pro_number,
            orm.carton_label,
            orm.carrier,
            CASE WHEN SUM(pkd.planned_quantity) = SUM(pkd.picked_quantity) THEN 'COMPLETE' ELSE 'PARTIAL' END complete_partial,
            dbo.usf_al_order_split_status(pkd.wh_id, pkd.order_number) func_split,
            orm.weight,
            orm.cubic_volume,
            'HJS_CUR' usuario,
            pkd.wh_id,
            orm.client_code,
            orm.master_bol_number,
            typ.type,
            orm.bill_to_code,
            orm.bill_to_name,
            orm.bill_to_addr1,
            orm.bill_to_addr2,
            orm.bill_to_city,
            orm.bill_to_state,
            orm.bill_to_zip,
            orm.bill_to_phone,
            orm.carrier_mode,
            vdo.vqm_profile,
            'il11405' impressora
         FROM T_PICK_DETAIL PKD, T_ORDER ORM
            LEFT JOIN T_VENDOR VDO
            ON ORM.BILL_TO_CODE = VDO.VENDOR_CODE, V_TYPE TYP
         WHERE PKD.LOAD_ID      = REC_MAIN.ORDER_NUMBER
         AND PKD.WH_ID          = REC_MAIN.WH_ID
         AND PKD.ORDER_NUMBER   = ORM.ORDER_NUMBER
         AND PKD.WH_ID          = ORM.WH_ID
         AND ORM.TYPE_ID        = TYP.TYPE_ID
             GROUP BY PKD.WH_ID, PKD.ORDER_NUMBER, ORM.DISPLAY_ORDER_NUMBER, ORM.PRO_NUMBER, ORM.CARTON_LABEL, ORM.CARRIER, ORM.WEIGHT, ORM.CUBIC_VOLUME,
                ORM.CLIENT_CODE, ORM.MASTER_BOL_NUMBER, TYP.TYPE, ORM.BILL_TO_CODE, ORM.BILL_TO_NAME, ORM.BILL_TO_ADDR1, ORM.BILL_TO_ADDR2, ORM.BILL_TO_CITY, ORM.BILL_TO_STATE, ORM.BILL_TO_ZIP,
                ORM.BILL_TO_PHONE, ORM.CARRIER_MODE, VDO.VQM_PROFILE, ORM.ORDER_NUMBER;


    COMMIT;
    
     INSERT INTO v_al_host_shipment_detail(shipment_id, line_number, item_number, display_item_number, lot_number, quantity_shipped, hu_id, user_id, wh_id, client_code,
        uom, tracking_number, order_number, display_order_number, delivery_sap)
      SELECT al_shm.shipment_id,
        pkd.line_number,
        pkd.item_number,
        pkd.item_number display_item_number, --itm.display_item_number,
        NULL lot_number,
        nvl(SUM (pkd.picked_quantity),0) qtd, -- NVL(SUM (sto.actual_qty),0)
        orm.order_number || '1', --sto.hu_id,
        'HJS' usuario,
        orm.wh_id,
        orm.client_code,
        'EA',
        pkc.tracking_number,
        pkd.order_number,
        orm.display_order_number,
        orm.customer_id
     FROM t_pick_detail pkd,
          t_pick_container pkc,
          t_al_host_shipment_master al_shm,
          t_order orm
     WHERE al_shm.order_number      = REC_MAIN.order_number
     AND pkd.load_id                = al_shm.order_number
     AND pkd.container_id           = pkc.container_id(+)
     AND pkd.wh_id                  = pkc.wh_id(+)
     AND pkd.wh_id                  = rec_main.wh_id
     AND al_shm.transaction_code    = '936'
     AND al_shm.load_id             = pkd.load_id
     AND al_shm.order_number        = pkd.order_number
     AND al_shm.wh_id               = pkd.wh_id
     AND pkd.order_number           = orm.order_number
     AND pkd.wh_id                  = orm.wh_id
     AND pkd.status                 = 'SHIPPED'
     GROUP BY orm.order_number || '1', orm.wh_id, al_shm.shipment_id, pkd.line_number
     , pkd.item_number, /*itm.display_item_number,*/ orm.client_code, pkc.tracking_number
     , pkd.order_number, orm.display_order_number, orm.customer_id;
    
    COMMIT;
    
    -- INVOCAR SERVIÇo
    select PKG_WEBSERVICES.USF_CALL_WEBSERVICE('EXP_PRE_SHIP', v_vchHost) into v_vchReturn FROM DUAL;
    
    insert into t_tran_log_holding(tran_log_holding_id, tran_type, description, start_tran_date, start_tran_time, employee_id, control_number)
    values(null, '088', 'Shipinfo gerada normalmente ' || rec_main.order_number, sysdate, sysdate, 'HJS', rec_main.order_number);
                    
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