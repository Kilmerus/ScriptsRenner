
---- CAPA
INSERT INTO t_exception_log (wh_id, tran_type, control_number)
select wh_id, '036', order_number from t_order where wh_id = '499' and order_date >= trunc(SYSDATE)
and rownum <= 100;

-- CAPA
-- EXPORTAR COMO INSERT
select 
null as ORDER_ID, WH_ID,ORDER_NUMBER,STORE_ORDER_NUMBER,TYPE_ID,CUSTOMER_ID,CUST_PO_NUMBER,CUSTOMER_NAME,CUSTOMER_PHONE,CUSTOMER_FAX,CUSTOMER_EMAIL,DEPARTMENT,LOAD_ID,LOAD_SEQ,BOL_NUMBER,PRO_NUMBER,MASTER_BOL_NUMBER,CARRIER,CARRIER_SCAC,FREIGHT_TERMS,RUSH,PRIORITY,ORDER_DATE,ARRIVE_DATE,ACTUAL_ARRIVAL_DATE,DATE_PICKED,DATE_EXPECTED,PROMISED_DATE,WEIGHT,CUBIC_VOLUME,CONTAINERS,BACKORDER,PRE_PAID,COD_AMOUNT,INSURANCE_AMOUNT,PIP_AMOUNT,FREIGHT_COST,REGION,BILL_TO_CODE,BILL_TO_NAME,BILL_TO_ADDR1,BILL_TO_ADDR2,BILL_TO_ADDR3,BILL_TO_CITY,BILL_TO_STATE,BILL_TO_ZIP,BILL_TO_COUNTRY_CODE,BILL_TO_COUNTRY_NAME,BILL_TO_PHONE,SHIP_TO_CODE,SHIP_TO_NAME,SHIP_TO_ADDR1,SHIP_TO_ADDR2,SHIP_TO_ADDR3,SHIP_TO_CITY,SHIP_TO_STATE,SHIP_TO_ZIP,SHIP_TO_COUNTRY_CODE,SHIP_TO_COUNTRY_NAME,SHIP_TO_PHONE,DELIVERY_NAME,DELIVERY_ADDR1,DELIVERY_ADDR2,DELIVERY_ADDR3,DELIVERY_CITY,DELIVERY_STATE,DELIVERY_ZIP,DELIVERY_COUNTRY_CODE,DELIVERY_COUNTRY_NAME,DELIVERY_PHONE,BILL_FRGHT_TO_CODE,BILL_FRGHT_TO_NAME,BILL_FRGHT_TO_ADDR1,BILL_FRGHT_TO_ADDR2,BILL_FRGHT_TO_ADDR3,BILL_FRGHT_TO_CITY,BILL_FRGHT_TO_STATE,BILL_FRGHT_TO_ZIP,BILL_FRGHT_TO_COUNTRY_CODE,BILL_FRGHT_TO_COUNTRY_NAME,BILL_FRGHT_TO_PHONE,RETURN_TO_CODE,RETURN_TO_NAME,RETURN_TO_ADDR1,RETURN_TO_ADDR2,RETURN_TO_ADDR3,RETURN_TO_CITY,RETURN_TO_STATE,RETURN_TO_ZIP,RETURN_TO_COUNTRY_CODE,RETURN_TO_COUNTRY_NAME,RETURN_TO_PHONE,RMA_NUMBER,RMA_EXPIRATION_DATE,CARTON_LABEL,VER_FLAG,FULL_PALLETS,HAZ_FLAG,ORDER_WGT,STATUS,ZONE,DROP_SHIP,LOCK_FLAG,PARTIAL_ORDER_FLAG,EARLIEST_SHIP_DATE,LATEST_SHIP_DATE,ACTUAL_SHIP_DATE,EARLIEST_DELIVERY_DATE,LATEST_DELIVERY_DATE,ACTUAL_DELIVERY_DATE,ROUTE,BASELINE_RATE,PLANNING_RATE,CARRIER_ID,MANIFEST_CARRIER_ID,SHIP_VIA_ID,DISPLAY_ORDER_NUMBER,CLIENT_CODE,SHIP_TO_RESIDENTIAL_FLAG,CARRIER_MODE,SERVICE_LEVEL,SHIP_TO_ATTENTION,EARLIEST_APPT_TIME,LATEST_APPT_TIME,SHIP_VIA,SHIP_CONTEXT,SCHEDULED_DELIVERY_PERIOD,SAP_ORDER,WEB_ORDER,GIFT_LIST,DOCUMENT_TYPE,ORDER_ORIGIN,ANTECIPATED_NF,FULFILLMENT_ID,CREATED_NF
from t_order where wh_id = '499' and order_date >= trunc(SYSDATE)
and order_number in (select control_number from t_exception_log where tran_type = '036');



---- DETALHES
delete t_exception_log where tran_type = '037';
INSERT INTO t_exception_log (wh_id, tran_type, control_number, item_number, line_number, quantity)
select 
wh_id, '037', order_number, item_number, line_number, qty
from t_order_detail ord where wh_id = '499' 
and order_number in (select control_number from t_exception_log where tran_type = '036');



---- INSERIR OS DETALHES DOS ITENS
-- EXPORTAR COMO INSERT
SELECT 
null as EXCEPTION_ID,TRAN_TYPE,DESCRIPTION,EXCEPTION_DATE,EXCEPTION_TIME,EMPLOYEE_ID,WH_ID,SUGGESTED_VALUE,ENTERED_VALUE,LOCATION_ID,ITEM_NUMBER,LOT_NUMBER,QUANTITY,HU_ID,LOAD_ID,CONTROL_NUMBER,LINE_NUMBER,TRACKING_NUMBER,ERROR_CODE,ERROR_MESSAGE,STATUS
FROM t_exception_log where tran_type = '037';


SELECT 
null as ITEM_MASTER_ID,ITEM_NUMBER,DESCRIPTION,UOM,INVENTORY_TYPE,SHELF_LIFE,ALT_ITEM_NUMBER,COMMODITY_CODE,NAFTA_PREF_CRITERIA,NAFTA_PRODUCER,NAFTA_NET_COST,PRICE,STD_HAND_QTY,STD_QTY_UOM,INSPECTION_CODE,SERIALIZED,LOT_CONTROL,WH_ID,REORDER_POINT,REORDER_QTY,CYCLE_COUNT_CLASS,LAST_COUNT_DATE,CLASS_ID,PICK_LOCATION,STACKING_SEQ,COMMENT_FLAG,VER_FLAG,UPC,UNIT_WEIGHT,TARE_WEIGHT,HAZ_MATERIAL,INV_CAT,INV_CLASS,UNIT_VOLUME,NESTED_VOLUME,XDOCK_PROFILE_ID,PICK_PUT_ID,SUGGESTED_DISPOSITION,LENGTH,WIDTH,HEIGHT,SAMPLE_RATE,COMPATIBILITY_ID,COMMODITY_TYPE_ID,FREIGHT_CLASS_ID,AUDIT_REQUIRED,MSDS_URL,EXPIRATION_DATE_CONTROL,UCC_COMPANY_PREFIX,ATTRIBUTE_COLLECTION_ID,DISPLAY_ITEM_NUMBER,CLIENT_CODE,BR_HIE_DEPART,BR_HIE_CLASS,BR_HIE_SUBCLASS,BR_ITEM_SIZE,REQUIRE_PHOTO_FLAG
FROM t_item_master where wh_id = '499' and item_number in (select item_number from t_exception_log where tran_type = '037');



-- ================================= CRIAR ESTOQUE               ==========================================================================================================
-- ========================================================================================================================================================================
SET SERVEROUTPUT ON
DECLARE

/*  - GERAR ESTOQUE EM BUFFER
*/

CURSOR c_main IS
   
   SELECT 
    DISTINCT log.ITEM_NUMBER
    , log.WH_ID
  FROM t_exception_log  log
  WHERE log.tran_type = '037'
  AND not exists (select 1 from t_stored_item sto
                  where sto.item_number = log.item_number
                  and sto.wh_id = log.wh_id
                  and sto.location_id = 'RENGERAL');
rec_main c_main%ROWTYPE;


    -- Error handling variables
    c_vchObjName  VARCHAR2(30 CHAR); -- The name that uniquely tags this object.
    v_vchErrorMsg VARCHAR2(2000 CHAR);
    v_nErrorCode  NUMBER;
    
    -- Exceptions
    e_KnownError   EXCEPTION;
    e_UnknownError EXCEPTION;
    
    -- Variáveis

    v_vchLocation       VARCHAR2(100 CHAR):= 'RENGERAL';
    v_numSTO_qty        NUMBER;
    v_numCount          NUMBER:= 0;

BEGIN

    FOR rec_main IN c_main	LOOP
    
        IF c_main%NOTFOUND Then
            EXIT;
        END IF;
        
        Insert into t_stored_item (SEQUENCE,ITEM_NUMBER,ACTUAL_QTY,UNAVAILABLE_QTY,STATUS,WH_ID,LOCATION_ID,FIFO_DATE,EXPIRATION_DATE,RESERVED_FOR,LOT_NUMBER,INSPECTION_CODE,SERIAL_NUMBER,TYPE,PUT_AWAY_LOCATION,STORED_ATTRIBUTE_ID,HU_ID,SHIPMENT_NUMBER) 
        values (0,rec_main.item_number,200,0,'A',rec_main.wh_id,v_vchLocation,SYSDATE,to_date('01/01/1900 00:00:00','DD/MM/YYYY HH24:MI:SS'),null,null,null,null,0,null,null,null,null);

                    
    END LOOP;

COMMIT;

 EXCEPTION -- Exceção do Laço (For)
          WHEN OTHERS THEN
               ROLLBACK;
               v_nErrorCode  := -20006;
               v_vchErrorMsg := 'SQLERRM = ' || SQLERRM;
               RAISE e_UnknownError;

END;


-- ========================================================================================================================================================================
-- CURSOR (CRIAR DETALHES DOS PEDIDOS) ====================================================================================================================================
SET SERVEROUTPUT ON
DECLARE

CURSOR c_main IS
  select 
    log.control_number
    , (select order_id from t_order where order_number = log.control_number) as order_id
    , log.wh_id
    , log.item_number
    , log.line_number
    , log.quantity
    , itm.item_master_id
  from t_exception_log log
    inner join t_item_master itm  
      on log.item_number = itm.item_number
      and log.wh_id = itm.wh_id
  where tran_type = '037';
rec_main c_main%ROWTYPE;


    -- Error handling variables
    c_vchObjName  VARCHAR2(30 CHAR); -- The name that uniquely tags this object.
    v_vchErrorMsg VARCHAR2(2000 CHAR);
    
    v_nErrorCode  NUMBER;
    
    -- Exceptions
    e_KnownError   EXCEPTION;
    e_UnknownError EXCEPTION;
    
    -- Variáveis
    v_vchSourceHUID     VARCHAR2(100 CHAR);
    v_numSTO_qty        NUMBER;
    v_numCount          NUMBER:= 0;
    
    v_vchReturn VARCHAR2(2000 CHAR);

BEGIN

    FOR rec_main IN c_main	LOOP
    
        IF c_main%NOTFOUND Then
            EXIT;
        END IF;
        
        Insert
          into T_ORDER_DETAIL ord
            (
              ORDER_DETAIL_ID,
              ORDER_ID,
              ITEM_MASTER_ID,
              WH_ID,
              ORDER_NUMBER,
              LINE_NUMBER,
              ITEM_NUMBER,
              BO_QTY,
              BO_DESCRIPTION,
              BO_WEIGHT,
              QTY,
              AFO_PLAN_QTY,
              UNIT_PACK,
              ITEM_WEIGHT,
              ITEM_TARE_WEIGHT,
              HAZ_MATERIAL,
              B_O_L_CLASS,
              B_O_L_LINE1,
              B_O_L_LINE2,
              B_O_L_LINE3,
              B_O_L_PLAC_CODE,
              B_O_L_PLAC_DESC,
              B_O_L_CODE,
              QTY_SHIPPED,
              LINE_TYPE,
              ITEM_DESCRIPTION,
              STACKING_SEQ,
              CUST_PART,
              LOT_NUMBER,
              PICKING_FLOW,
              UNIT_WEIGHT,
              UNIT_VOLUME,
              EXTENDED_WEIGHT,
              EXTENDED_VOLUME,
              OVER_ALLOC_QTY,
              DATE_EXPECTED,
              ORDER_UOM,
              HOST_WAVE_ID,
              TRAN_PLAN_QTY,
              USE_SHIPPABLE_UOM,
              UNIT_INSURANCE_AMOUNT,
              STORED_ATTRIBUTE_ID,
              HOLD_REASON_ID
            )
            values
            (
              null,
              rec_main.order_id,
              rec_main.item_master_id,
              rec_main.wh_id,
              rec_main.control_number,
              rec_main.line_number,
              rec_main.item_number,
              '0',
              null,
              '0',
              rec_main.quantity,
              '0',
              'E',
              '0',
              '0',
              null,
              null,
              null,
              null,
              null,
              null,
              null,
              null,
              '1',
              'P',
              null,
              null,
              null,
              null,
              null,
              '0',
              '0',
              '0',
              '0',
              '0',
              SYSDATE,
              null,
              '0',
              '0',
              'N',
              '0',
              null,
              null
            );
        
    END LOOP;

COMMIT;

 EXCEPTION -- Exceção do Laço (For)
          WHEN OTHERS THEN
               ROLLBACK;
               v_nErrorCode  := -20006;
               v_vchErrorMsg := 'SQLERRM = ' || SQLERRM;
               RAISE e_UnknownError;

END;
