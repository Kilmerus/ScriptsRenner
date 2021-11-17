SET SERVEROUTPUT ON
DECLARE
/**************************************************************************************
Retornar LPNs movidos erroneamentes para o HANG, para o endereço de Origem (BUFFER)

**************************************************************************************/
CURSOR c_main IS

    SELECT 
        log2.location_id
        , log2.item_number
        , log2.wh_id
        , log2.hu_id
        , SUM(log2.tran_qty) AS qty
        , log2.location_id_2
    FROM t_tran_log log2
    WHERE log2.tran_type = '317'
    AND log2.location_id NOT IN ('RAIL_BUF1','RAIL_BUF2')
    AND log2.wh_id = '324'
    AND not exists (select 1 from t_hu_master hum
                    where hum.hu_id = log2.hu_id
                    and hum.wh_id = log2.wh_id)
    AND log2.start_tran_date >= TRUNC(sysdate)-5
    AND not exists (select 1 from t_tran_log log
                    where log.tran_type = '024'
                    and log.hu_id = log2.hu_id)
    GROUP BY log2.location_id
        , log2.wh_id
        , log2.item_number
        , log2.hu_id
        , log2.location_id_2
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

    v_Tran_Type		:= '024';
    v_vchChamado	:= 'INC0242567';


    FOR rec_main IN c_main	LOOP
    
        IF c_main%notfound THEN
            EXIT;
        END IF;


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
                                   v_tran_type
                                  , 'Retorno LPN Buffer'
                                  , TRUNC(sysdate)
                                  , TO_DATE(to_char(TRUNC(sysdate, 'MM'), 'DD/MM/YYYY')||' '||to_char(sysdate,'HH24:MI:SS'), 'DD/MM/YYYY HH24:MI:SS') --START_TRAN_TIME
                                  , TRUNC(sysdate)--TO_DATE('01/01/1900','MM/DD/YYYY')END_TRAN_DATE
                                  , TO_DATE(to_char(TRUNC(sysdate, 'MM'), 'DD/MM/YYYY')||' '||to_char(sysdate,'HH24:MI:SS'), 'DD/MM/YYYY HH24:MI:SS') --END_TRAN_TIME
                                  , 'HJS'                           --EMPLOYEE_ID
                                  , v_vchchamado                    --CONTROL_NUMBER
                                  , NULL
                                  , rec_main.wh_id
                                  , rec_main.hu_id
                                  , rec_main.location_id_2             --LOCATION_ID
                                  , rec_main.location_id                --LOCATION_ID_2
                                  , 0--NUM_ITEMS
                                  , rec_main.item_number            --ITEM_NUMBER
                                  , rec_main.qty               --TRAN_QTY
                                  
                              );
                              
        -- RETIRAR DO SORTER
        usp_universal_move_items(
                 'WA',                      --:CONST Application Identifier:,
                 '203',                     --:MoveParam Transaction Code:,
                 'HJS',                     --:MoveParam Employee ID:,
                 rec_main.location_id_2,       --:MoveParam Source Location:,
                 rec_main.location_id,      --:MoveParam Destination Location:,
                 'STORAGE',                 --:MoveParam Source Type:,
                 'STORAGE',                 --:MoveParam Destination Type:,
                 rec_main.wh_id,            --:MoveParam Warehouse ID:,
                 NULL,                      --:MoveParam Source HU_ID:,
                 rec_main.hu_id,                      --:MoveParam Destination HU_ID:,
                 rec_main.item_number,      --:MoveParam Item Number:,
                 NULL,                      --:MoveParam Stored Attribute ID:, 
                 NULL,                      --:MoveParam Lot Number:,
                 -----------
                 /*Quantidade da UZ e não a quantidade "Planejada"*/
                 rec_main.qty,         --:MoveParam Quantity:,
                 -----------
                 'A',                       --:MoveParam Invent Status Before:,
                 'A',                       --:MoveParam Invent Status After:,
                 NULL                       --:MoveParam Destination HU Type:
                 );
        
        
        UPDATE t_hu_master set reserved_for = 'BUFFER' , container_type = 'EN'
        where hu_id = rec_main.hu_id
        and wh_id = rec_main.wh_id;
        
    END LOOP;
  
  
  COMMIT;

 EXCEPTION -- Exceção do Laço (For)
          WHEN OTHERS THEN
               ROLLBACK;
               v_nErrorCode  := -20006;
               v_vchErrorMsg := 'SQLERRM = ' || SQLERRM;
               RAISE e_UnknownError;

END;
