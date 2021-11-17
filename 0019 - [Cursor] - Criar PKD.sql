SET SERVEROUTPUT ON
DECLARE



CURSOR c_main IS
        SELECT                  
            bloco1.TYPE
            , SUM(bloco1.ACTUAL_QTY) ACTUAL_QTY
            , bloco1.ITEM_NUMBER
            , bloco1.WH_ID
            , bloco1.RESERVED_FOR
            , bloco1.CONTROL_NUMBER
            , bloco1.ALLOC1
        FROM (
        select 
            sto.hu_id
            , sto.item_number
            , sto.actual_qty
            , sto.type
            , sto.wh_id
            , hum.location_id
            , hum.reserved_for
            , hum.control_number    
            ,(select max(control_number) from t_tran_log
                        where tran_type = '351'
                        and hu_id = sto.hu_id
                        and wh_id = sto.wh_id) as Alloc1
        from t_stored_item sto
        inner join t_hu_master hum
            on sto.hu_id    = hum.hu_id
            and sto.wh_id   = hum.wh_id
        where sto.type <> 'STORAGE'
        and sto.wh_id = '114'
        and not exists (select 1 from t_pick_detail
                        where to_char(pick_id) = sto.type
                        and wh_id = sto.wh_id)
        and sto.location_id not in ('PRE_RECE_TRANSF')) bloco1
        where Alloc1 is not null
        and not exists (select 1 from t_pick_detail pkd
                        where pkd.order_number = bloco1.Alloc1
                        and line_number = bloco1.control_number
                        and pkd.wh_id = bloco1.wh_id)
        --and type not in ('156609664','156609674')
        GROUP BY 
              TYPE
            , WH_ID
            , RESERVED_FOR
            , CONTROL_NUMBER
            , ALLOC1
            , ITEM_NUMBER
       --and alloc1 = '2041192453'
        ;
rec_main c_main%ROWTYPE;


     -- Error handling variables
     c_vchObjName  VARCHAR2(30 CHAR); -- The name that uniquely tags this object.
     v_vchErrorMsg VARCHAR2(2000 CHAR);
     v_nErrorCode  NUMBER;
     NewWKQ      NUMBER;
     -- Exceptions
     e_KnownError   EXCEPTION;
     e_UnknownError EXCEPTION;


BEGIN
	FOR rec_main IN c_main	LOOP
	
	IF c_main%NOTFOUND Then
      EXIT;
	END IF;
	
    SELECT sq_pick_id.NEXTVAL-50000000 into NewWKQ FROM dual;
    
    Insert into T_WORK_Q (WORK_Q_ID,WORK_TYPE,DESCRIPTION,PICK_REF_NUMBER,PRIORITY,DATE_DUE,TIME_DUE,ITEM_NUMBER,WH_ID,LOCATION_ID,FROM_LOCATION_ID,WORK_STATUS,QTY,WORKERS_REQUIRED,WORKERS_ASSIGNED,ZONE,EMPLOYEE_ID,DATETIME_STAMP) 
    values (NewWKQ,'03','Order Pick',null,'20',SYSDATE,SYSDATE,null,rec_main.wh_id,null,null,'U','0','90','0',null,null,SYSDATE);
           
    Insert into T_PICK_DETAIL 
    (PICK_ID,ORDER_NUMBER,LINE_NUMBER,TYPE,UOM,WORK_Q_ID,WORK_TYPE,STATUS,ITEM_NUMBER,LOT_NUMBER,SERIAL_NUMBER,UNPLANNED_QUANTITY,PLANNED_QUANTITY,PICKED_QUANTITY,STAGED_QUANTITY,LOADED_QUANTITY,PACKED_QUANTITY,SHIPPED_QUANTITY,PICK_LOCATION,PICKING_FLOW,STAGING_LOCATION,ZONE,WAVE_ID,LOAD_ID,LOAD_SEQUENCE,STOP_ID,CONTAINER_ID,PICK_CATEGORY,USER_ASSIGNED,BULK_PICK_FLAG,STACKING_SEQUENCE,PICK_AREA,WH_ID,CARTONIZATION_BATCH_ID,MANIFEST_BATCH_ID,STORED_ATTRIBUTE_ID,CREATE_DATE,BEFORE_PICK_RULE,DURING_PICK_RULE,PICK_LOCATION_CHANGE_DATE) 
    values 
    (0,rec_main.alloc1,rec_main.control_number,'PP','EA',NewWKQ,'03','RELEASED',rec_main.item_number, rec_main.type ,null,'0',rec_main.actual_qty,'0','0','0','0','0',null,null,null,null,'WAVE-',null,'0',null,null,'CX',null,null,'1','GERAL','114',null,rec_main.alloc1,null,SYSDATE,null,null,null);

    UPDATE t_pick_detail set pick_id = rec_main.type
    where lot_number = rec_main.type
    and order_number = rec_main.alloc1
    and line_number = rec_main.control_number;

							
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