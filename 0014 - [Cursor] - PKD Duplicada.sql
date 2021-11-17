SET SERVEROUTPUT ON
DECLARE
/**************************************************************************************
- Corrgir duplicidade de Onda
- Gustavo Félix - 18/11/2019
**************************************************************************************/
CURSOR c_main IS
    SELECT item_number, order_number, line_number, wave_id, wh_id, COUNT(*) 
        FROM t_pick_detail 
        WHERE 1=1
        AND wave_id = 'CX_SR_FL05_200728_31' 
        AND TYPE = 'PP'        
    GROUP BY item_number, order_number, line_number, wave_id, wh_id
    HAVING  COUNT(*)  > 1
      
--    SELECT item_number, wave_id, count(*) from t_pick_detail 
--        WHERE wave_id = 'CX_SR_FL05_200728_31' 
--        and type <> 'PP'
--        and work_type = '26'
--        and lot_number = 'INC0075544'
--        GROUP BY item_number, wave_id
--        having count(*) > 1
    ;

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
    
    SELECT MAX(PICK_ID) INTO v_nPickID 
    FROM t_pick_detail
        WHERE wave_id = rec_main.wave_id
        AND     order_number    = rec_main.order_number
        AND     wh_id           =   rec_main.wh_id
        AND     line_number     =   rec_main.line_number
        AND     item_number     =   rec_main.item_number;
        
        
--    SELECT MAX(pick_id) INTO v_nPickID 
--    FROM t_pick_detail 
--        where wave_id   = rec_main.wave_id 
--        and type        <> 'PP'
--        and item_number = rec_main.item_number
--        and work_type   = '26'
--        and lot_number  = 'INC0075544'
--        and type        <> 'PP'
--    order by item_number, pick_id desc;
        
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
