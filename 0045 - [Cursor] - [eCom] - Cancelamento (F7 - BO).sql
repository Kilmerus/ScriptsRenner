SET SERVEROUTPUT ON
DECLARE

/*  CANCELAMENTO DE ORDEM
*/

CURSOR c_main IS
    SELECT DISTINCT LOG.control_number
    , LOG.item_number
    , log.wh_id
    , LOG.quantity
    , CASE WHEN (SELECT COUNT(DISTINCT ord.item_number) FROM t_order_detail ord
                    WHERE ord.order_number = LOG.control_number
                    AND ord.wh_id = LOG.wh_id
                    AND ord.item_number <> LOG.item_number
                    AND ord.bo_qty = 0
                    ) > 0 THEN 'PARTIAL' ELSE 'COMPLETE' END tipo
    FROM dbo.t_exception_log LOG
        WHERE LOG.tran_type = '033'
        --AND log.control_number in ('221820265986-1PC','221954882149-1PC')
        --AND rownum <= 100
        AND log.status is null
        and not exists (select 1 from DBO.t_al_host_shipment_master shm
                        where shm.order_number = log.control_number
                        and shm.transaction_code in ('360','361'))
        ;
rec_main c_main%ROWTYPE;


CURSOR c_main2 IS
    SELECT DISTINCT LOG.control_number
    , status
    , log.wh_id
    , CASE WHEN status = 'COMPLETE' THEN '360' ELSE '361' end TRANSACTION_CODE
    , SYS_GUID() as HOST_GROUP
    , CASE WHEN (SELECT COUNT(DISTINCT ord.item_number) FROM t_order_detail ord
                    WHERE ord.order_number = LOG.control_number
                    AND ord.wh_id = LOG.wh_id
                    AND ord.item_number <> LOG.item_number
                    AND ord.bo_qty = 0
                    ) > 0 THEN 'PARTIAL' ELSE 'COMPLETE' END tipo
    FROM dbo.t_exception_log LOG
        WHERE LOG.tran_type = '033'
        AND STATUS IS NOT NULL;
rec_main2 c_main2%ROWTYPE;

    -- Error handling variables
    c_vchObjName  VARCHAR2(30 CHAR); -- The name that uniquely tags this object.
    v_vchErrorMsg VARCHAR2(2000 CHAR);
    v_nErrorCode  NUMBER;
    
    -- Exceptions
    e_KnownError   EXCEPTION;
    e_UnknownError EXCEPTION;
    
    -- Variáveis
    v_vchTipo           VARCHAR2(100 CHAR);
    v_vchReturn         VARCHAR2(2000 CHAR);
    v_numSTO_qty        NUMBER;
    v_numCount          NUMBER:= 0;

BEGIN

    FOR rec_main IN c_main	LOOP
    
        IF c_main%NOTFOUND Then
            EXIT;
        END IF;

    SELECT COUNT(*) INTO  v_numCount
        FROM t_exception_log 
        where tran_type = '033'
        and control_number = rec_main.control_number
        and item_number = rec_main.item_number
        and status is null;
        
    IF v_numCount = 1 THEN
    
        UPDATE t_exception_log set status = rec_main.tipo
        WHERE control_number = rec_main.control_number
        and tran_type = '033';
    
        -- SET BO_QTY
        UPDATE t_order_detail set bo_qty = rec_main.quantity
            WHERE order_number = rec_main.control_number
            and wh_id = rec_main.wh_id
            and item_number = rec_main.item_number;
            
        UPDATE t_pick_detail set status = 'PICKED', user_assigned = 'HJS_C'
            WHERE order_number = rec_main.control_number
            and wh_id = rec_main.wh_id
            and item_number = rec_main.item_number;
    
    END IF;
                  
    END LOOP;

COMMIT;

    --========== SEGUNDO FOR
    FOR rec_main2 IN c_main2	LOOP
    
        IF c_main2%NOTFOUND Then
            EXIT;
        END IF;
    
        -- INSERIR A CAPA
        INSERT INTO v_al_host_shipment_master(
        host_group_id,					transaction_code,
        order_number,					display_order_number,
        load_id,						pro_number,
        seal_number,					carrier_code,
        status,							split_status,
        total_weight,					total_volume,
        user_id,						wh_id,
        client_code,					master_bol_number,
        order_type,						bill_to_code,
        bill_to_name,					bill_to_addr1,
        bill_to_addr2,					bill_to_city,
        bill_to_state,					bill_to_zip,
        bill_to_phone,					carrier_mode,
        delivery_sap,					fulfillment_id
        )SELECT
        rec_main2.HOST_GROUP,			rec_main2.TRANSACTION_CODE,
        orm.order_number,  				orm.display_order_number,
        orm.load_id,					orm.pro_number,
        orm.carton_label,				orm.carrier,
        'COMPLETE',						dbo.usf_al_order_split_status(orm.wh_id, orm.order_number),
        orm.weight,						orm.cubic_volume,
        'HJS_C',						orm.wh_id,
        orm.client_code,				orm.master_bol_number,
        'CP',							orm.bill_to_code,
        orm.bill_to_name,				orm.bill_to_addr1,
        orm.bill_to_addr2,				orm.bill_to_city,
        orm.bill_to_state,				orm.bill_to_zip,
        orm.bill_to_phone,				orm.carrier_mode,
        NULL AS delivery_sap,			orm.fulfillment_id
        FROM t_order orm
        WHERE orm.wh_id = REC_MAIN2.wh_id
        AND orm.order_number = rec_main2.control_number;        
        
        -- INSERIR DETALHE
        INSERT INTO v_al_host_shipment_detail(
        shipment_id,					line_number,
        item_number,					display_item_number,
        lot_number,						quantity_shipped,
        hu_id,							user_id,
        wh_id, 							client_code, 
        uom,							tracking_number,
        order_number,					display_order_number,
        delivery_sap,					gen_attribute_value1,
        gen_attribute_value2,			gen_attribute_value3,
        gen_attribute_value4,			gen_attribute_value5,
        gen_attribute_value6,			gen_attribute_value7,
        gen_attribute_value8,			gen_attribute_value9,
        gen_attribute_value10,			gen_attribute_value11
        )
        SELECT 
            (SELECT sm.shipment_id FROM t_al_host_shipment_master sm 
                WHERE sm.host_group_id = rec_main2.HOST_GROUP) AS shipment_id,
        ord.line_number AS line_number,
        ord.item_number AS item_number,
        itm.display_item_number AS display_item_number,
        null AS lot_number,
        ord.bo_qty AS quantity_shipped,
        NULL AS hu_id,
        'HJS_C' AS user_id,
        ord.wh_id AS wh_id, 
        orm.client_code AS client_code, 
        dbo.sf_GetMinUOM(ord.item_number, ord.wh_id) AS uom,
        NULL AS tracking_number,
        ord.order_number AS order_number,
        orm.display_order_number AS display_order_number,
        NULL AS delivery_sap,
        NULL AS gen_attribute_value1,
        NULL AS gen_attribute_value2,
        NULL AS gen_attribute_value3,
        NULL AS gen_attribute_value4,
        NULL AS gen_attribute_value5,
        NULL AS gen_attribute_value6,
        NULL AS gen_attribute_value7,
        NULL AS gen_attribute_value8,
        NULL AS gen_attribute_value9,
        NULL AS gen_attribute_value10,
        NULL AS gen_attribute_value11
        FROM t_order_detail ord
        INNER JOIN t_order orm
        ON ord.wh_id = orm.wh_id
        AND ord.order_number = orm.order_number
        INNER JOIN t_item_master itm
        ON itm.wh_id = ord.wh_id
        AND itm.item_number = ord.item_number
        WHERE ord.wh_id = rec_main2.wh_id
        AND ord.order_number = rec_main2.control_number
        AND ord.bo_qty > 0;
        
        COMMIT;
        
        IF rec_main2.tipo = 'PARTIAL' THEN
        
            -- CHAMAR SERVIÇO
            SELECT PKG_WEBSERVICES.USF_CALL_WEBSERVICE('EXP_CANCEL_PARTIAL_ORDER', rec_main2.host_group) INTO v_vchReturn FROM DUAL;
            
        ELSIF rec_main2.tipo = 'COMPLETE' THEN
        
             SELECT PKG_WEBSERVICES.USF_CALL_WEBSERVICE('EXP_CANCEL_ORDER', rec_main2.host_group) INTO v_vchReturn FROM DUAL;
        
        END IF;
        
    END LOOP;
    
 EXCEPTION -- Exceção do Laço (For)
          WHEN OTHERS THEN
               ROLLBACK;
               v_nErrorCode  := -20006;
               v_vchErrorMsg := 'SQLERRM = ' || SQLERRM;
               RAISE e_UnknownError;

END;