SET SERVEROUTPUT ON
DECLARE

/*
    - Script - Corrigir Satatus dos pedidos
    - Gustavo Félix - 17/06/2020
*/

CURSOR c_main IS
    SELECT 
        ORDER_NUMBER
        , WH_ID
        , TIPO    
    FROM (
    SELECT 
        DISTINCT orm.order_number
        , orm.wh_id
        , orm.status
        , CASE WHEN (SELECT COUNT(DISTINCT ord.item_number) FROM t_order_detail ord
                        WHERE ord.order_number = orm.order_number
                        AND ord.wh_id = orm.wh_id
                        ) = 1 THEN 'MONO' ELSE 'MULTI' END tipo
        , CASE WHEN EXISTS (SELECT 1 FROM t_order_detail ord
                                WHERE ord.order_number = orm.order_number
                                AND ord.wh_id = orm.wh_id
                                AND ord.bo_qty = 0
                                ) THEN 'PARCIAL' ELSE 'COMPLETE' END Corte
    FROM t_order orm
        where exists (select 1 from DBO.t_al_host_shipment_master shm
                        where shm.order_number = orm.order_number
                        and shm.wh_id = orm.wh_id
                        and shm.transaction_code in ('360','361')
                        and shm.user_id like '%HJS%')
        and orm.order_date >= trunc(SYSDATE)-30
        and orm.wh_id = '499'
        and orm.status in ('D','U'));
rec_main c_main%ROWTYPE;

        -- Error handling variables
        c_vchObjName    VARCHAR2(30 CHAR); -- The name that uniquely tags this object.
        v_vchErrorMsg   VARCHAR2(2000 CHAR);
        v_vchRetorno    VARCHAR2(2000 CHAR);
        v_nErrorCode    NUMBER;
        -- Exceptions
        e_KnownError    EXCEPTION;
        e_UnknownError  EXCEPTION;
        
        v_Tran_Type     VARCHAR2(5 CHAR):='089'; -- Saneamento
        v_nCount        NUMBER;

BEGIN
	
  
  	FOR rec_main IN c_main	LOOP	
    
    IF c_main%NOTFOUND THEN
        EXIT;
    END IF;            

    -- INSERIR LOG
        INSERT INTO t_tran_log_holding(
              TRAN_TYPE
              , DESCRIPTION
              , START_TRAN_DATE
              , START_TRAN_TIME
              , EMPLOYEE_ID
              , CONTROL_NUMBER
              , CONTROL_NUMBER_2
              , WH_ID
              , LOCATION_ID
              , ITEM_NUMBER
              , TRAN_QTY
              , HU_ID
        ) values (
                v_Tran_Type
              , (select description from t_transaction where tran_type = v_Tran_Type)
              , SYSDATE
              , SYSDATE
              , 'HJS'--EMPLOYEE_ID
              , rec_main.order_number --CONTROL_NUMBER
              , rec_main.tipo
              , rec_main.wh_id
              , null--LOCATION_ID
              , null--ITEM_NUMBER
              , null--TRAN_QTY
              , null
          );
          
        -- UPDATE
        UPDATE t_order set status = 'C'
        WHERE order_number = rec_main.order_number
        and wh_id = rec_main.wh_id
        and status in ('D','U');
        
	END LOOP;

COMMIT;

 EXCEPTION 
          WHEN OTHERS THEN
               ROLLBACK;

               v_nErrorCode  := -20006;
               v_vchErrorMsg := 'SQLERRM = ' || SQLERRM;
               RAISE e_UnknownError;
END;