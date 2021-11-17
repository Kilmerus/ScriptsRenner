SET SERVEROUTPUT ON
DECLARE

CURSOR c_main IS
     select 
        shd.order_number               
        , shd.item_number
        , shd.line_number
        , shd.wh_id
        , shd.quantity_shipped
        , shd.CLIENT_CODE
        , shd.DELIVERY_SAP
        , shd.TRACKING_NUMBER
        , shd.user_id
        , shd.RECORD_CREATE_DATE
        , shd.hu_id
        , com.br_order_number_orig
        , com.br_qty
        , com.br_qty_shipped
        , shd.host_group_id
        , com.comment_text
        , shd.shipment_id
        , shd.shipment_detail_id
     from t_al_host_shipment_detail shd 
        left join t_order_detail_comment com
            on  shd.order_number    =   com.order_number
            and shd.wh_id           =   com.wh_id
            and shd.item_number     =   com.item_number
            and shd.line_number     =   com.line_number
        where shd.shipment_id in (select shipment_id from t_al_host_shipment_master where load_id = '_Load_Id_')
        and shd.order_number like '900%'
        and shd.host_group_id <> '0';
		
rec_main c_main%ROWTYPE;


     -- Error handling variables
     c_vchObjName  VARCHAR2(30 CHAR); -- The name that uniquely tags this object.
     v_vchErrorMsg VARCHAR2(2000 CHAR);
     v_nErrorCode  NUMBER;
     -- Exceptions
     e_KnownError   EXCEPTION;
     e_UnknownError EXCEPTION;


BEGIN
	FOR rec_main IN c_main	LOOP
	
	IF c_main%NOTFOUND Then
      EXIT;
	END IF;
	
    -- INSERIR INTERFACE DAS TRANSFERENCIAS		
    Insert into T_AL_HOST_SHIPMENT_DETAIL
    (SHIPMENT_ID,LINE_NUMBER,ITEM_NUMBER,QUANTITY_SHIPPED,HU_ID
    ,DELIVERY_SAP,USER_ID,WH_ID,CLIENT_CODE,RECORD_CREATE_DATE,UOM,TRACKING_NUMBER
    ,ORDER_NUMBER,DISPLAY_ORDER_NUMBER,GEN_ATTRIBUTE_VALUE1,GEN_ATTRIBUTE_VALUE2,GEN_ATTRIBUTE_VALUE3,GEN_ATTRIBUTE_VALUE4,GEN_ATTRIBUTE_VALUE5,GEN_ATTRIBUTE_VALUE6,HOST_GROUP_ID) 
    values 
    (rec_main.SHIPMENT_ID,rec_main.line_number,rec_main.ITEM_NUMBER,rec_main.QUANTITY_SHIPPED,rec_main.HU_ID
    ,rec_main.DELIVERY_SAP,rec_main.USER_ID,rec_main.WH_ID,rec_main.CLIENT_CODE,rec_main.RECORD_CREATE_DATE,null,rec_main.TRACKING_NUMBER
    ,rec_main.br_order_number_orig,'T',null,null,rec_main.comment_text,null,null,rec_main.order_number,rec_main.host_group_id);
    
    UPDATE T_AL_HOST_SHIPMENT_DETAIL set 
        host_group_id = '0'
        , gen_attribute_value1 = rec_main.host_group_id
        , gen_attribute_value8 = 'CORRECÃO'
    WHERE shipment_detail_id = rec_main.shipment_detail_id;
    
							
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