DECLARE

/*  CANCELAMENTO DE ORDEM*/
-- Ultima Atualização Gustavo
-- 22/07/2020
    -- Atualização t_order
    -- Geração de NF
    -- Fechamento de Tarefas

    -- VARIÁVEIS GLOBAIS
    v_vchOrdem              VARCHAR2(100 CHAR);
    v_vchwhID               VARCHAR2(100 CHAR);

CURSOR c_main IS
 SELECT 
        control_number
        , wh_id
        , tipo
    FROM (
    SELECT 
        DISTINCT LOG.control_number
        , log.wh_id
        , CASE WHEN (SELECT COUNT(DISTINCT ord.item_number) FROM t_order_detail ord
                        WHERE ord.order_number = LOG.control_number
                        AND ord.wh_id = LOG.wh_id
                        AND ord.item_number <> LOG.item_number
                        AND ord.bo_qty = 0
                        ) > 0 THEN 'PARTIAL' ELSE 'COMPLETE' END tipo
        FROM dbo.t_exception_log LOG
            left join t_pick_detail pkd
                on log.control_number   = pkd.order_number
                and log.wh_id           = pkd.wh_id
                and log.item_number     = pkd.item_number
                and log.load_id         = pkd.wave_id
                and pkd.status          = 'RELEASED'
        WHERE LOG.tran_type             = '033'
        and log.exception_date          >= trunc(SYSDATE)-1
        and log.lot_number              = 'PRO_E'
        -- CASOS NAO CLASSIFICADOS
        AND log.status                  is null
        -- NAO ENVIADOS
        and not exists (select 1 from DBO.t_al_host_shipment_master shm
                            inner join DBO.t_al_host_shipment_detail shd
                                on shm.shipment_id = shd.shipment_id
                        where shm.order_number = log.control_number
                        and shm.transaction_code in ('360')
                        and shd.item_number = log.item_number)
        ORDER BY log.control_number)
    WHERE ROWNUM <= 250;
    
rec_main c_main%ROWTYPE;


CURSOR c_ord IS
    SELECT ITEM_NUMBER  AS ITEM
    , QUANTITY
    , CONTROL_NUMBER    AS ORDER_NUMBER
    , WH_ID 
    , LOAD_ID           AS WAVE
    FROM DBO.T_EXCEPTION_LOG      
        WHERE CONTROL_NUMBER    = V_VCHORDEM
        AND WH_ID               = V_VCHWHID
        AND TRAN_TYPE           = '033';
        
rec_ord c_ord%ROWTYPE;

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
        AND log.suggested_value = 'PEND'
        and not exists (select 1 from DBO.t_al_host_shipment_master shm
								INNER JOIN t_al_host_shipment_detail SHD
									on SHM.shipment_id = SHD.shipment_id
                                where shm.order_number = log.control_number
                                and shm.transaction_code in ('360','361')
								and shd.item_number = LOG.item_number
								)
        AND STATUS in ('PARTIAL', 'COMPLETE');
rec_main2 c_main2%ROWTYPE;


CURSOR c_NF IS
    SELECT DISTINCT HOST_GROUP_ID AS HOST_GROUP_ID 
    , wh_id
    , order_number
    from t_al_host_shipment_master
        WHERE user_id = 'HJS_CORTE'
        AND transaction_code = '936';        
rec_NF c_NF%ROWTYPE;


CURSOR c_CloseTasks IS
    SELECT DISTINCT pkd.work_q_id AS wk_id, pkd.wh_id , pkd.order_number, pkd.wave_id, pkd.status, pkd.lot_number,wkq.work_q_id,wkq.work_status,pkd.pick_area,pkd.pendency
        FROM t_pick_detail pkd
        INNER JOIN t_work_q wkq ON wkq.work_q_id = pkd.work_q_id
        WHERE pkd.work_type IS NULL
        AND wkq.work_status <> 'C'
        AND pkd.status <> 'RELEASED'
        AND pkd.wh_id = '499'
        AND NOT EXISTS (SELECT 1 FROM t_pick_detail pkd2
                      WHERE pkd2.work_q_id = wkq.work_q_id
                      AND pkd2.wh_id = wkq.wh_id
                      AND pkd2.status = 'RELEASED')
        AND NOT EXISTS (SELECT 1 FROM t_work_q_assignment wka1
                      WHERE pkd.work_q_id = wka1.work_q_id
                      AND pkd.wh_id = wka1.wh_id)
        AND EXISTS (SELECT 1 FROM t_al_host_shipment_master spm
                   INNER JOIN t_al_host_shipment_detail spd ON spd.shipment_id = spm.shipment_id
                   WHERE spm.transaction_code IN ('360','361')
                   AND spm.order_number = pkd.order_number
                   AND spd.item_number = pkd.item_number)
    AND ROWNUM <= 200;      
rec_CloseTasks c_CloseTasks%ROWTYPE;

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
    v_vchReturnNF       VARCHAR2(2000 CHAR);
    
    v_numSTO_qty        NUMBER;
    v_numCount          NUMBER:= 0;
    --
    v_numPicked         NUMBER:= 0;
    v_numReleased       NUMBER:= 0;    
    v_vchHostNF         VARCHAR2(100 CHAR);
    v_WKQ               VARCHAR2(50 CHAR);
    
    v_wave              VARCHAR2(50 CHAR);
    
    
    

BEGIN

-- INICIO INSERCAO
INSERT INTO dbo.t_exception_log
  (control_number,
   item_number,
   wh_id,
   quantity,
   load_id,
   tran_type,
   lot_number)
  SELECT DISTINCT bloco1.order_number,
                  bloco1.item_number,
                  bloco1.wh_id,
                  bloco1.plan_qty,
                  bloco1.wave_id,
                  '033',
                  'PRO_E'
    FROM (SELECT pkd.wave_id,
                 pkd.wh_id,
                 pkd.pick_id,
                 pkd.order_number,
                 pkd.item_number,
                 MIN(pkd.create_date)       AS create_date,
                 SUM(pkd.planned_quantity)  AS plan_qty,
                 sto.qty_sto,
                 sto.qty_sto_una,
                 nvl(sto.dis, 0)            AS disponivel
            FROM t_pick_detail pkd
            LEFT JOIN (SELECT item_number,
                             wh_id,
                             SUM(actual_qty) AS qty_sto,
                             SUM(unavailable_qty) AS qty_sto_una,
                             SUM(actual_qty) - SUM(unavailable_qty) AS dis
                        FROM t_stored_item
                       WHERE TYPE = 0
                       GROUP BY item_number, wh_id) sto
              ON pkd.item_number = sto.item_number
             AND pkd.wh_id = sto.wh_id
           WHERE pkd.wh_id = '499'
             AND pkd.status = 'RELEASED'
             AND pkd.TYPE = 'PP'
           GROUP BY pkd.wave_id,
                    pkd.wh_id,
                    pkd.order_number,
                    pkd.item_number,
                    pkd.pick_id,
                    sto.dis) bloco1
   WHERE disponivel = 0
    -- Não exista Transação de Picking
     AND NOT EXISTS (SELECT 1
                        FROM t_tran_log LOG
                       WHERE LOG.control_number = bloco1.order_number
                         AND LOG.wh_id = bloco1.wh_id
                         AND LOG.item_number = bloco1.item_number
                         AND LOG.tran_type = '301')
     -- Não exista NF
     AND NOT EXISTS (SELECT 1
            FROM t_al_host_shipment_master shm
           WHERE shm.order_number = bloco1.order_number
             AND shm.wh_id = bloco1.wh_id
             AND shm.transaction_code = '936')
     AND NOT EXISTS
   (SELECT 1 FROM t_stored_item sto WHERE sto.TYPE = bloco1.pick_id);
   
   
   COMMIT;
-- FIM INSERCAO

    FOR rec_main IN c_main  LOOP
    
        IF c_main%NOTFOUND Then
            EXIT;
        END IF;
    
        v_vchOrdem  := rec_main.control_number;
        v_vchwhID   := rec_main.wh_id;
    

        
        SELECT count(*) into v_numCount  
        FROM t_exception_log 
        WHERE control_number = rec_main.control_number
        and tran_type = '033'
        and suggested_value = 'PEND';
        
    IF v_numCount = 0 THEN
        
            UPDATE t_exception_log set status = rec_main.tipo, suggested_value = 'PEND'
                WHERE control_number = rec_main.control_number
                and tran_type = '033';
        
        FOR rec_ord IN c_ord  LOOP
        
                IF c_ord%NOTFOUND Then
                    EXIT;
                END IF;
                
                v_wave := rec_ord.WAVE;
            
                -- SET BO_QTY
                UPDATE t_order_detail set bo_qty = rec_ord.quantity
                    WHERE order_number  = rec_ord.order_number
                    and wh_id           = rec_ord.wh_id
                    and item_number     = rec_ord.item;
                    
                -- ** IF PARA AFO PLAN QTY**
                IF v_wave IS NULL THEN
                  UPDATE t_order_detail set afo_plan_qty = 0
                      WHERE order_number    = rec_ord.order_number
                      and wh_id             = rec_ord.wh_id
                      and item_number       = rec_ord.item;
                end if;
                
                -- Adicionado a atualização do campo PENDECY
                UPDATE t_pick_detail set status = 'PICKED', lot_number = 'HJS', pendency = 'C'
                    WHERE order_number  =   rec_ord.order_number
                    and wh_id           =   rec_ord.wh_id
                    and status          =   'RELEASED'
                    and item_number     =   rec_ord.item;
          
            END loop; -- FIM CURSOR ORD (Detalhes do Pedido)
                 
            COMMIT;
        
        END IF;
        
        
        v_numCount:= 0;        
        -- Atualizar Status do PEDIDO na t_order
        SELECT COUNT(*) INTO v_numcount FROM t_order_detail 
        WHERE order_number = rec_main.control_number
        AND bo_qty = 0;
        
        IF v_numCount > 0 THEN
            -- Se exister ainda Itens que não foram cortados (bo_qty = 0) Atualizar para D
            UPDATE t_order set status  = 'D' WHERE order_number = rec_main.control_number;            
        ELSE                
            --  Se não, seta pra C
            UPDATE t_order set status  = 'C' WHERE order_number = rec_main.control_number;                
        END IF;
        
     
        ---============ VERIFICAR SE O ITEM CORTADO É O ÚLTIMO ITEM A SER DISTRIBUÍDO  ============---
        
        SELECT COUNT (*) INTO v_numPicked FROM T_PICK_DETAIL
        WHERE ORDER_NUMBER = rec_main.control_number
        AND WH_ID = rec_main.wh_id
        AND STATUS = 'PICKED'
        AND picked_quantity > 0;
        
        SELECT COUNT (*) INTO v_numReleased FROM T_PICK_DETAIL
        WHERE ORDER_NUMBER  = rec_main.control_number
        AND WH_ID           = rec_main.wh_id
        AND STATUS          = 'RELEASED';
        
        IF v_numPicked > 0 THEN
            EXIT;
        ELSIF v_numReleased > 0 THEN
            EXIT;
        ELSE
        
            SELECT SYS_GUID() INTO v_vchHostNF FROM DUAL;
        
            -- ENVIAR A GERAÇÃO DE NF
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
                delivery_sap,
                printer_id
                )SELECT
                v_vchHostNF,
                '936',
                pkd.order_number,  
                orm.display_order_number,
                pkd.order_number,
                orm.pro_number,
                orm.carton_label,
                orm.carrier,
                CASE WHEN SUM(pkd.planned_quantity) = SUM(pkd.picked_quantity) THEN 'COMPLETE' ELSE 'PARTIAL' END,
                dbo.usf_al_order_split_status(pkd.wh_id, pkd.order_number),
                orm.weight,
                orm.cubic_volume,
                'HJS_CORTE',
                pkd.wh_id,--:Warehouse ID:,
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
                'il11405'--:Printer:
                FROM
                t_pick_detail pkd,
                t_stored_item sto,
                t_order orm
                left join t_vendor vdo
                on orm.bill_to_code = vdo.vendor_code,
                v_type typ
                WHERE
                pkd.wh_id = sto.wh_id
                AND pkd.load_id = rec_main.control_number
                AND pkd.pick_id = sto.type
                AND pkd.wh_id = sto.wh_id
                AND pkd.order_number = orm.order_number
                AND pkd.wh_id = orm.wh_id
                AND orm.type_id = typ.type_id
                AND pkd.wh_id = rec_main.wh_id
                AND sto.type <> 0
                GROUP BY
                pkd.wh_id,
                pkd.order_number,
                orm.display_order_number,
                orm.pro_number,
                orm.carton_label,
                orm.carrier,
                orm.weight,
                orm.cubic_volume,
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
                vdo.vqm_profile;
                
                              
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
                    al_shm.shipment_id,
                    pkd.line_number,
                    pkd.item_number,
                    itm.display_item_number,
                    decode (0,1,sto.lot_number,NULL) as lot_number,
                    NVL(SUM (sto.actual_qty),0),
                    sto.hu_id,
                    'HJS_CORTE', --:User ID:,
                    rec_main.wh_id,
                    orm.client_code,   
                    dbo.sf_GetMinUOM(pkd.item_number, rec_main.wh_id),
                    pkc.tracking_number,
                    pkd.order_number,     
                    orm.display_order_number,   
                    orm.customer_id,
                    (SELECT tsacd.attribute_value
                    FROM t_sto_attrib_collection_detail tsacd
                    WHERE tsacd.stored_attribute_id = sto.stored_attribute_id
                    AND attribute_id = alm.generic_attribute_1) AS val1,    
                    (SELECT tsacd.attribute_value 
                    FROM t_sto_attrib_collection_detail tsacd
                    WHERE tsacd.stored_attribute_id = sto.stored_attribute_id
                    AND attribute_id = alm.generic_attribute_2) AS val2, 
                    (SELECT tsacd.attribute_value 
                    FROM t_sto_attrib_collection_detail tsacd
                    WHERE tsacd.stored_attribute_id = sto.stored_attribute_id
                    AND attribute_id = alm.generic_attribute_3) AS val3, 
                    (SELECT tsacd.attribute_value 
                    FROM t_sto_attrib_collection_detail tsacd
                    WHERE tsacd.stored_attribute_id = sto.stored_attribute_id
                    AND attribute_id = alm.generic_attribute_4) AS val4, 
                    (SELECT tsacd.attribute_value 
                    FROM t_sto_attrib_collection_detail tsacd
                    WHERE tsacd.stored_attribute_id = sto.stored_attribute_id
                    AND attribute_id = alm.generic_attribute_5) AS val5, 
                    (SELECT tsacd.attribute_value 
                    FROM t_sto_attrib_collection_detail tsacd
                    WHERE tsacd.stored_attribute_id = sto.stored_attribute_id
                    AND attribute_id = alm.generic_attribute_6) AS val6, 
                    (SELECT tsacd.attribute_value 
                    FROM t_sto_attrib_collection_detail tsacd
                    WHERE tsacd.stored_attribute_id = sto.stored_attribute_id
                    AND attribute_id = alm.generic_attribute_7) AS val7, 
                    (SELECT tsacd.attribute_value 
                    FROM t_sto_attrib_collection_detail tsacd
                    WHERE tsacd.stored_attribute_id = sto.stored_attribute_id
                    AND attribute_id = alm.generic_attribute_8) AS val8, 
                    (SELECT tsacd.attribute_value 
                    FROM t_sto_attrib_collection_detail tsacd
                    WHERE tsacd.stored_attribute_id = sto.stored_attribute_id
                    AND attribute_id = alm.generic_attribute_9) AS val9, 
                    (SELECT tsacd.attribute_value 
                    FROM t_sto_attrib_collection_detail tsacd
                    WHERE tsacd.stored_attribute_id = sto.stored_attribute_id
                    AND attribute_id = alm.generic_attribute_10) AS val10, 
                    (SELECT tsacd.attribute_value 
                    FROM t_sto_attrib_collection_detail tsacd
                    WHERE tsacd.stored_attribute_id = sto.stored_attribute_id
                    AND attribute_id = alm.generic_attribute_11) AS val11
                    FROM
                    t_stored_item sto,
                    t_pick_detail pkd,
                    t_pick_container pkc,
                    v_al_host_shipment_master al_shm,   
                    t_attribute_legacy_map alm,
                    t_item_master itm,
                    t_order orm 
                    WHERE
                    pkd.load_id = rec_main.control_number
                    AND pkd.wh_id = rec_main.wh_id
                    AND itm.item_number = sto.item_number
                    AND itm.wh_id = sto.wh_id
                    AND pkd.pick_id = sto.type(+)
                    AND pkd.wh_id = sto.wh_id
                    AND pkd.container_id = pkc.container_id(+)
                    AND pkd.wh_id = pkc.wh_id(+)
                    AND al_shm.host_group_id = v_vchHostNF -- HOST
                    AND al_shm.load_id = pkd.load_id
                    AND al_shm.order_number = pkd.order_number
                    AND al_shm.wh_id = pkd.wh_id
                    AND pkd.order_number = orm.order_number
                    AND pkd.wh_id = orm.wh_id
                    AND sto.type <> 0
                    GROUP BY
                    al_shm.shipment_id,
                    pkd.line_number,
                    pkd.item_number,
                    itm.display_item_number,
                    decode (0,1,sto.lot_number,NULL),
                    sto.hu_id,
                    orm.client_code,   
                    pkc.tracking_number,
                    pkd.order_number,
                    orm.display_order_number,
                    orm.customer_id,
                    sto.stored_attribute_id,
                    alm.generic_attribute_1, 
                    alm.generic_attribute_2, 
                    alm.generic_attribute_3, 
                    alm.generic_attribute_4, 
                    alm.generic_attribute_5, 
                    alm.generic_attribute_6, 
                    alm.generic_attribute_7, 
                    alm.generic_attribute_8, 
                    alm.generic_attribute_9, 
                    alm.generic_attribute_10, 
                    alm.generic_attribute_11;
            
        END IF;
        
    END LOOP;

COMMIT;


    -- FECHAMENTO DE TAREFAS
        FOR rec_CloseTasks IN c_CloseTasks  LOOP
    
        IF c_CloseTasks%NOTFOUND Then
            EXIT;
        END IF;
        
        UPDATE t_work_q set work_status = 'C' where work_q_id = rec_CloseTasks.WK_ID
        AND wh_id =  rec_CloseTasks.wh_id
        and work_status <> 'C';
            
        -- RASTREABILIDADE
        INSERT INTO T_TRAN_LOG_HOLDING(TRAN_LOG_HOLDING_ID, TRAN_TYPE, DESCRIPTION, START_TRAN_DATE, START_TRAN_TIME, EMPLOYEE_ID, WH_ID, CONTROL_NUMBER, CONTROL_NUMBER_2, LOT_NUMBER, LOCATION_ID, LOCATION_ID_2)
        VALUES(NULL, '015', 'Fechamento de tarefa', SYSDATE, SYSDATE, 'HJS_C', rec_CloseTasks.WH_ID, rec_CloseTasks.order_number, rec_CloseTasks.wave_id , rec_CloseTasks.lot_number, rec_CloseTasks.WK_ID, rec_CloseTasks.PICK_AREA);  
        
        END LOOP;
    
    COMMIT;
    

    --========== INTERFACE DE CORTE
    FOR rec_main2 IN c_main2  LOOP
    
        IF c_main2%NOTFOUND Then
            EXIT;
        END IF;
        
          UPDATE t_exception_log set suggested_value = 'OK'
            WHERE control_number = rec_main2.control_number
            and tran_type = '033'
            and suggested_value = 'PEND';      
    
        -- INSERIR A CAPA
        INSERT INTO v_al_host_shipment_master(
        host_group_id,          transaction_code,
        order_number,         display_order_number,
        load_id,            pro_number,
        seal_number,          carrier_code,
        status,             split_status,
        total_weight,         total_volume,
        user_id,            wh_id,
        client_code,          master_bol_number,
        order_type,           bill_to_code,
        bill_to_name,         bill_to_addr1,
        bill_to_addr2,          bill_to_city,
        bill_to_state,          bill_to_zip,
        bill_to_phone,          carrier_mode,
        delivery_sap,         fulfillment_id
        )SELECT
        rec_main2.HOST_GROUP,     rec_main2.TRANSACTION_CODE,
        orm.order_number,         orm.display_order_number,
        orm.load_id,          orm.pro_number,
        orm.carton_label,       orm.carrier,
        'COMPLETE',           dbo.usf_al_order_split_status(orm.wh_id, orm.order_number),
        orm.weight,           orm.cubic_volume,
        'HJS_C',            orm.wh_id,
        orm.client_code,        orm.master_bol_number,
        'CP',             orm.bill_to_code,
        orm.bill_to_name,       orm.bill_to_addr1,
        orm.bill_to_addr2,        orm.bill_to_city,
        orm.bill_to_state,        orm.bill_to_zip,
        orm.bill_to_phone,        orm.carrier_mode,
        NULL AS delivery_sap,     orm.fulfillment_id
        FROM t_order orm
        WHERE orm.wh_id = REC_MAIN2.wh_id
        AND orm.order_number = rec_main2.control_number;        
        
        -- INSERIR DETALHE
        INSERT INTO v_al_host_shipment_detail(
        shipment_id,          line_number,
        item_number,          display_item_number,
        lot_number,           quantity_shipped,
        hu_id,              user_id,
        wh_id,              client_code, 
        uom,              tracking_number,
        order_number,         display_order_number,
        delivery_sap,         gen_attribute_value1,
        gen_attribute_value2,     gen_attribute_value3,
        gen_attribute_value4,     gen_attribute_value5,
        gen_attribute_value6,     gen_attribute_value7,
        gen_attribute_value8,     gen_attribute_value9,
        gen_attribute_value10,      gen_attribute_value11
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
    
    -- CONSUMIR INTERFACE DE GERAÇÃO DE NF
     FOR rec_NF IN c_NF  LOOP
    
        IF c_NF%NOTFOUND Then
            EXIT;
        END IF;
        
    select PKG_WEBSERVICES.USF_CALL_WEBSERVICE('EXP_PRE_SHIP', rec_NF.HOST_GROUP_ID) into v_vchReturnNF FROM DUAL;
    
    insert into t_tran_log_holding(tran_log_holding_id, tran_type, description, start_tran_date, start_tran_time, employee_id, control_number, wh_id)
    values(null, '071', 'Interface PRE_SHIP (Corte)' , sysdate, sysdate, 'HJS', rec_nf.order_number, rec_nf.wh_id);        
        
    END LOOP;
    
 EXCEPTION -- Exceção do Laço (For)
          WHEN OTHERS THEN
               ROLLBACK;
               v_nErrorCode  := -20006;
               v_vchErrorMsg := 'SQLERRM = ' || SQLERRM;
               RAISE e_UnknownError;

END;