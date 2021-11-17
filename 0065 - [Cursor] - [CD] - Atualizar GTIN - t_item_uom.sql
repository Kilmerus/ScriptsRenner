SET SERVEROUTPUT ON
DECLARE
/**************************************************************************************
Atualizar GTIN - T_ITEM_UOM
-- CAMICADO
**************************************************************************************/
CURSOR c_main IS
    SELECT 
        uom.item_number
        , uom.wh_id
        , uom.gtin
        , (SELECT COUNT(DISTINCT upc) FROM t_item_upc upc2
            WHERE upc2.item_number = uom.item_number
            AND upc2.wh_id = uom.wh_id) AS count_upc
        , upc.upc
    FROM t_item_uom uom
    INNER JOIN t_item_upc upc
        ON uom.item_number = upc.item_number
        AND uom.wh_id = upc.wh_id
    WHERE uom.wh_id = '30098' 
    --and uom.item_number in ('100034558','100001107')
    AND uom.gtin IS NULL
    AND ROWNUM <= 5000
    ;
rec_main c_main%ROWTYPE;



     -- Error handling variables
     c_vchObjName   VARCHAR2(30 CHAR); -- The name that uniquely tags this object.
     v_vchErrorMsg  VARCHAR2(2000 CHAR);
     v_nErrorCode   NUMBER;
     v_vchReturn    VARCHAR2(2000 CHAR);
     
     -- Exceptions
     e_KnownError   EXCEPTION;
     e_UnknownError EXCEPTION;
     v_Tran_Type VARCHAR2(5 CHAR);
     v_vchChamado VARCHAR2(20 CHAR);

     
BEGIN

    FOR rec_main IN c_main	LOOP
    
        IF c_main%notfound THEN
            EXIT;
        END IF;


      IF rec_main.count_upc = '1' THEN
      
      -- INSERIR LOG
            INSERT INTO t_tran_log_holding(
                                  tran_type
                                  , DESCRIPTION
                                  , start_tran_date
                                  , start_tran_time
                                  , end_tran_date
                                  , end_tran_time
                                  , employee_id
                                  , control_number
                                  , control_number_2
                                  , wh_id
                                  , hu_id
                                  , location_id
                                  , location_id_2
                                  , num_items
                                  , item_number
                                  , tran_qty
                                  
                            ) VALUES (
                                   '023'
                                  , 'Atualização GTIN'
                                  , TRUNC(sysdate)
                                  , TO_DATE(to_char(TRUNC(sysdate, 'MM'), 'DD/MM/YYYY')||' '||to_char(sysdate,'HH24:MI:SS'), 'DD/MM/YYYY HH24:MI:SS') --START_TRAN_TIME
                                  , TRUNC(sysdate)--TO_DATE('01/01/1900','MM/DD/YYYY')END_TRAN_DATE
                                  , TO_DATE(to_char(TRUNC(sysdate, 'MM'), 'DD/MM/YYYY')||' '||to_char(sysdate,'HH24:MI:SS'), 'DD/MM/YYYY HH24:MI:SS') --END_TRAN_TIME
                                  , 'HJS'                           --EMPLOYEE_ID
                                  , rec_main.upc                    --CONTROL_NUMBER
                                  , 'GTIN NULL'                    
                                  , rec_main.wh_id
                                  , null
                                  , null                            --LOCATION_ID
                                  , null                            --LOCATION_ID_2
                                  , 0--NUM_ITEMS
                                  , rec_main.item_number            --ITEM_NUMBER
                                  , 0              --TRAN_QTY
                                  
                              );
       
       UPDATE t_item_uom set GTIN = rec_main.UPC
       WHERE item_number = rec_main.item_number
       and wh_id = rec_main.wh_id
       and gtin is null;
      
      END IF;
        
    END LOOP;
  
  
  COMMIT;

 EXCEPTION -- Exceção do Laço (For)
          WHEN OTHERS THEN
               ROLLBACK;
               v_nErrorCode  := -20006;
               v_vchErrorMsg := 'SQLERRM = ' || SQLERRM;
               RAISE e_UnknownError;

END;
