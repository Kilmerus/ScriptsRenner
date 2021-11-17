SET SERVEROUTPUT ON
DECLARE
/**************************************************************************************
- Corrgir duplicidade PKD - PRE_RECE
- Gustavo Félix - 18/02/2020
**************************************************************************************/
CURSOR c_main IS
    SELECT item_number, order_number, line_number,  wh_id, COUNT(*) 
        FROM t_pick_detail 
        WHERE 1=1
        AND pick_id in (select 
                            pkd.pick_id
                        from t_stored_item sto
                            inner join t_hu_master hum
                                on sto.hu_id = hum.hu_id
                                and sto.wh_id = hum.wh_id
                                and hum.parent_hu_id in ('0010032400025978900114','0010032400025920100114','0010032400025983600114')
                            inner join t_pick_detail pkd
                                on pkd.line_number = hum.control_number
                                and pkd.order_number = sto.serial_number
                                and pkd.item_number = sto.item_number
                                and pkd.wh_id = sto.wh_id
                                and pkd.status = 'RELEASED')
        AND TYPE = 'PP'        
    GROUP BY item_number, order_number, line_number, wh_id
    HAVING  COUNT(*)  > 1;

    rec_main c_main%ROWTYPE;


     -- Error handling variables
     c_vchObjName  VARCHAR2(30 CHAR); -- The name that uniquely tags this object.
     v_vchErrorMsg VARCHAR2(2000 CHAR);
     v_nErrorCode  NUMBER;
     v_nPickID      NUMBER;
     -- Exceptions
     e_KnownError   EXCEPTION;
     e_UnknownError EXCEPTION;
     ErrMsg         VARCHAR2(3100);


BEGIN

	FOR rec_main IN c_main	LOOP
	
	IF c_main%NOTFOUND Then
      EXIT;
	END IF;
    
    Insert into DBO.t_exception_log (TRAN_TYPE,DESCRIPTION,EXCEPTION_DATE,EXCEPTION_TIME,EMPLOYEE_ID,WH_ID,LOAD_ID,LINE_NUMBER, ITEM_NUMBER, ERROR_MESSAGE) 
    VALUES ('973', 'PKD Duplicada - PRE_RECE', SYSDATE, SYSDATE, 'HJS', REC_MAIN.WH_ID, REC_MAIN.ORDER_NUMBER, REC_MAIN.LINE_NUMBER, REC_MAIN.ITEM_NUMBER, 'PKD Duplicada');
           
    
    SELECT MAX(PICK_ID) INTO v_nPickID 
    FROM t_pick_detail
        WHERE   order_number    = rec_main.order_number
        AND     wh_id           =   rec_main.wh_id
        AND     line_number     =   rec_main.line_number
        AND     item_number     =   rec_main.item_number;
        
    DELETE t_pick_detail where pick_id = v_nPickID;
							
  END LOOP;
  
COMMIT;

 EXCEPTION -- Exceção do Laço (For)
          WHEN OTHERS THEN
               ROLLBACK;
               v_nErrorCode  := -20006;
               v_vchErrorMsg := 'SQLERRM = ' || SQLERRM;
               RAISE e_UnknownError;

END;
