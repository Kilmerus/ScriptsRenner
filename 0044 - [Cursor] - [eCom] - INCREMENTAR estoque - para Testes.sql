SET SERVEROUTPUT ON
DECLARE

/*  - GERAR ESTOQUE EM BUFFER
*/

CURSOR c_main IS
   
   SELECT 
    DISTINCT ITEM_NUMBER
    , WH_ID
   FROM (
    SELECT  
        pkd.item_number
        , pkd.wh_id
    FROM t_pick_detail pkd
    INNER JOIN t_order orm
        ON pkd.order_number = orm.order_number
        AND pkd.wh_id = orm.wh_id
    WHERE   pkd.wh_id = '30400'
    AND     pkd.TYPE = 'PP'
    AND     pkd.status = 'RELEASED'
    ORDER BY pkd.create_date DESC)
    WHERE ROWNUM <= 500;
rec_main c_main%ROWTYPE;


    -- Error handling variables
    c_vchObjName  VARCHAR2(30 CHAR); -- The name that uniquely tags this object.
    v_vchErrorMsg VARCHAR2(2000 CHAR);
    v_nErrorCode  NUMBER;
    
    -- Exceptions
    e_KnownError   EXCEPTION;
    e_UnknownError EXCEPTION;
    
    -- Variáveis

    v_vchLocation       VARCHAR2(100 CHAR):= 'RENGERAL_C';
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