SET SERVEROUTPUT ON
DECLARE
/**************************************************************************************
- Corrgir duplicidade - LOG de cancelamento de Pedido
- Gustavo Félix - 21/09/2020
**************************************************************************************/
CURSOR c_main IS
        SELECT 
            control_number
            , DESCRIPTION
            , item_number
            , wh_id
            , employee_id
            , tran_qty
            , TO_CHAR(MAX(to_date(to_char(start_tran_date, 'DD/MM/YYYY') ||' '||to_char(start_tran_time, 'HH24:MI:SS'), 'DD/MM/YYYY HH24:MI:SS')),'DD/MM/YYYY HH24:MI:SS') as LOG
            , COUNT (DISTINCT tran_log_id)
        FROM t_tran_log WHERE tran_type = '361'
        AND start_tran_date >= TRUNC(sysdate)-10
        GROUP BY
        control_number
            , DESCRIPTION
            , item_number
            , wh_id
            , employee_id
            , tran_qty
        HAVING COUNT (DISTINCT tran_log_id) > 1
    ;
    

    rec_main c_main%ROWTYPE;


     -- Error handling variables
     c_vchObjName  VARCHAR2(30 CHAR); -- The name that uniquely tags this object.
     v_vchErrorMsg VARCHAR2(2000 CHAR);
     v_nErrorCode  NUMBER;
     v_nPickID      NUMBER;
     v_nTranLogID   NUMBER;
     
     -- Exceptions
     e_KnownError   EXCEPTION;
     e_UnknownError EXCEPTION;
     ErrMsg         VARCHAR2(3100);


BEGIN

	FOR rec_main IN c_main	LOOP
	
		IF c_main%NOTFOUND Then
		  EXIT;
		END IF;
		
		SELECT 
			MAX(tran_log_id) INTO v_nTranLogID 
		FROM t_tran_log
		WHERE control_number    = rec_main.control_number
		AND wh_id               = rec_main.wh_id
		AND employee_id         = rec_main.employee_id
		AND tran_type           = '361'
		AND item_number         = rec_main.item_number
		AND tran_qty            = rec_main.tran_qty;
		
		-- Exception
		INSERT INTO t_exception_log (tran_type,description, exception_date, exception_time, employee_id, control_number, item_number, quantity, error_message)
		VALUES ('041', 'Log Duplicado', sysdate, sysdate, rec_main.employee_id, rec_main.control_number, rec_main.item_number, rec_main.tran_qty, rec_main.log);
			
			
		DELETE t_tran_log where tran_log_id = v_nTranLogID;
							
  END LOOP;
  
COMMIT;

 EXCEPTION -- Exceção do Laço (For)
          WHEN OTHERS THEN
               ROLLBACK;
               v_nErrorCode  := -20006;
               v_vchErrorMsg := 'SQLERRM = ' || SQLERRM;
               RAISE e_UnknownError;

END;
