SET SERVEROUTPUT ON
DECLARE

CURSOR c_main IS
        SELECT 
            ORDER_NUMBER
            , WH_ID
            , ITEM_NUMBER
        FROM (
            SELECT 
                DISTINCT orm.order_number
                , ord.item_number
                , ord.qty
                , ord.qty_shipped
                , ord.bo_qty
                , orm.wh_id
                , orm.master_bol_number
                , orm.status
                , (select al.transaction_code from t_al_host_shipment_master al
                    inner join t_al_host_shipment_detail ald
                        on al.shipment_id = ald.shipment_id
                        and al.order_number = orm.order_number
                        and al.wh_id = orm.wh_id
                        and al.transaction_code in ('360','361')
                        and ald.item_number = ord.item_number
                        ) as JaCancelado
                , (select MAX(al.transaction_code) from t_al_host_shipment_master al
                    inner join t_al_host_shipment_detail ald
                        on al.shipment_id = ald.shipment_id
                        and al.order_number = orm.order_number
                        and al.wh_id = orm.wh_id
                        and al.transaction_code not in ('360','361')
                        and ald.item_number = ord.item_number
                        ) as Shipped
            from DBO.t_order orm
                inner join DBO.tmp_item itm
                    ON orm.order_number = itm.item_number
                    AND orm.wh_id = itm.wh_id
                inner join t_order_detail ord
                    ON orm.order_number = ord.order_number
                    AND orm.wh_id = ord.wh_id
            --ORDER BY orm.order_number, ord.item_number
        )
        WHERE jacancelado   is null
        and shipped         is null
        AND ORDER_NUMBER = '2011057237357-1PC'
        ;
rec_main c_main%ROWTYPE;

    -- CURSOR PARA REPROCESSAMENTO
    CURSOR c_Process IS
        SELECT DISTINCT HOST_GROUP_ID as HOST_GROUP_ID
        FROM DBO.t_al_host_shipment_master
        WHERE user_id           = 'HJS_REP';
    rec_Process c_Process%ROWTYPE;


    -- Error handling variables
    c_vchObjName    VARCHAR2(30 CHAR); -- The name that uniquely tags this object.
    v_vchErrorMsg   VARCHAR2(2000 CHAR);
    v_nErrorCode    NUMBER;
    -- Exceptions
    e_KnownError    EXCEPTION;
    e_UnknownError  EXCEPTION;
    
    v_nCount        NUMBER:= 0;
    v_nSum          NUMBER:= 0;
    v_vchHost       VARCHAR2(100 CHAR);
    v_vchUser       VARCHAR2(100 CHAR)  := 'HJS_REP';
    v_vchTran       VARCHAR2(10 CHAR)   := '361'; -- EXP_CANCEL_PARTIAL_ORDER
    v_vchReturn     VARCHAR2(100 CHAR);
    -- EXP_CANCEL_ORDER
    -- EXP_CANCEL_PARTIAL_ORDER

BEGIN
    FOR rec_main IN c_main	LOOP
	
        IF c_main%NOTFOUND Then
          EXIT;
        END IF;
        
        -- INFORMAR QUAIS ITENS SERÂO CANCELADOS
        UPDATE T_ORDER_DETAIL
            SET BO_QTY = QTY
        WHERE   order_number    =   REC_MAIN.order_number
        AND     item_number     =   REC_MAIN.item_number
        AND     wh_id           =   REC_MAIN.wh_id;
        
        SELECT COUNT(*) INTO v_nCount
            FROM DBO.t_al_host_shipment_master
            WHERE   order_number = rec_main.ORDER_NUMBER
            AND     wh_id = rec_main.WH_ID
            AND     transaction_code = v_vchTran;
        
        IF v_nCount = 0 THEN
        
        SELECT SYS_GUID() INTO v_vchHost
        FROM DUAL;
    
     -- INSERIR A MASTER
        INSERT INTO v_al_host_shipment_master(
            host_group_id,
            transaction_code,
            order_number,
            display_order_number,
            load_id,
            pro_number,
            seal_number,
            carrier_code,
            status,
            split_status,
            total_weight,
            total_volume,
            user_id,
            wh_id,
            client_code,
            master_bol_number,
            order_type,
            bill_to_code,
            bill_to_name,
            bill_to_addr1,
            bill_to_addr2,
            bill_to_city,
            bill_to_state,
            bill_to_zip,
            bill_to_phone,
            carrier_mode,
            delivery_sap
            )SELECT
            v_vchHost,              -- Host Group ID
            v_vchTran,              -- Transaction
            orm.order_number,  
            orm.display_order_number,
            orm.load_id,
            orm.pro_number,
            orm.carton_label,
            orm.carrier,
            'COMPLETE',
            dbo.usf_al_order_split_status(orm.wh_id, orm.order_number),
            orm.weight,
            orm.cubic_volume,
            v_vchUser,          -- Usuário
            orm.wh_id,
            orm.client_code,
            orm.master_bol_number,
            'CP',
            orm.bill_to_code,
            orm.bill_to_name,
            orm.bill_to_addr1,
            orm.bill_to_addr2,
            orm.bill_to_city,
            orm.bill_to_state,
            orm.bill_to_zip,
            orm.bill_to_phone,
            orm.carrier_mode,
            NULL AS delivery_sap
            FROM t_order orm
            WHERE orm.wh_id = REC_MAIN.wh_id
            AND orm.order_number = REC_MAIN.order_number;
    
    END IF;
    
   
   -- INSERE OS DETALHES
        INSERT INTO v_al_host_shipment_detail(
            shipment_id,
            line_number,
            item_number,
            display_item_number,
            lot_number,
            quantity_shipped,
            hu_id,
            user_id,
            wh_id, 
            client_code, 
            uom,
            tracking_number,
            order_number,
            display_order_number,
            delivery_sap,
            gen_attribute_value1,
            gen_attribute_value2,
            gen_attribute_value3,
            gen_attribute_value4,
            gen_attribute_value5,
            gen_attribute_value6,
            gen_attribute_value7,
            gen_attribute_value8,
            gen_attribute_value9,
            gen_attribute_value10,
            gen_attribute_value11
        )
        SELECT 
            (SELECT sm.shipment_id 
                FROM t_al_host_shipment_master sm 
                WHERE   sm.order_number = REC_MAIN.ORDER_NUMBER
                AND     sm.user_id = v_vchUser
                AND     sm.transaction_code = v_vchTran) AS shipment_id,
            ord.line_number AS line_number,
            ord.item_number AS item_number,
            itm.display_item_number AS display_item_number,
            null AS lot_number,
            ord.bo_qty AS quantity_shipped,
            NULL AS hu_id,
            v_vchUser AS user_id,
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
            WHERE ord.wh_id         = REC_MAIN.WH_ID
            AND ord.order_number    = REC_MAIN.order_number
            AND ord.item_number     = REC_MAIN.ITEM_NUMBER
            AND ord.bo_qty > 0;
            
    
        -- ATUAIZA O STATUS DO PEDIDO
        SELECT SUM (qty - bo_qty) INTO v_nSum
        FROM t_order_detail ord
        WHERE ord.wh_id = rec_main.wh_id
        AND ord.order_number = rec_main.order_number;
        
        IF v_nSum = 0 THEN
            UPDATE t_order set status = 'C' 
                where order_number = rec_main.order_number 
                AND wh_id = rec_main.WH_ID;
        END IF;
    
   END LOOP;

COMMIT;

    FOR rec_Process IN c_Process	LOOP
    
        IF c_Process%NOTFOUND Then
        EXIT;
        END IF;
        
        SELECT PKG_WEBSERVICES.USF_CALL_WEBSERVICE('EXP_CANCEL_PARTIAL_ORDER', rec_Process.HOST_GROUP_ID) INTO v_vchReturn    FROM DUAL;
        
        UPDATE DBO.t_al_host_shipment_master
        SET user_id = 'HJS_COMP'
        WHERE host_group_id = rec_Process.HOST_GROUP_ID;    
        
    END LOOP;

 EXCEPTION -- Exceção do Laço (For)
          WHEN OTHERS THEN
               ROLLBACK;
               v_nErrorCode  := -20006;
               v_vchErrorMsg := 'SQLERRM = ' || SQLERRM;
               RAISE e_UnknownError;

END;