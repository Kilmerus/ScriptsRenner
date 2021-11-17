SET SERVEROUTPUT ON
DECLARE

/*  - ESTOQUE COM LOTE SETADO, PORÉM SEM CONTROLE DE LOTE
*/


CURSOR c_main IS
    SELECT 
        item_number
        , wh_id
        , location_id
        , status
        , SUM(actual_qty) as actual_qty
        , lot_number
    FROM t_stored_item 
    where item_number in (select itm.item_number from t_item_master itm
        where itm.wh_id = '499'
        and itm.lot_control = 'N'
        and exists (select 1 from t_stored_item sto
                        where sto.item_number = itm.item_number
                        and sto.wh_id = itm.wh_id
                        and sto.lot_number is not null))
    and lot_number is not null
   --and item_number = '549698864'
   and type = 0
    GROUP BY 
    item_number
            , wh_id
            , location_id
            , status
            , lot_number;
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

BEGIN

    FOR rec_main IN c_main	LOOP
    
        IF c_main%NOTFOUND Then
            EXIT;
        END IF;
    
        -- 
        
        SELECT count(*) into v_numCount
        FROM t_stored_item
        WHERE item_number = rec_main.item_number
        AND wh_id = rec_main.wh_id
        AND location_id  = rec_main.location_id
        and lot_number is null;
        
        IF v_numCount > 0 THEN
            
            UPDATE t_stored_item set actual_qty = actual_qty + rec_main.actual_qty
            WHERE item_number = rec_main.item_number
            and wh_id = rec_main.wh_id
            and location_id = rec_main.location_id
            and lot_number is null; -- AUMENTAR ONDE O LOT FOR NULO
            
            DELETE t_stored_item 
            WHERE item_number = rec_main.item_number
            and wh_id = rec_main.wh_id
            and location_id = rec_main.location_id
            and lot_number is not null; -- DELETAR ONDE O LOTE NÃO FOR NULO
            
                    -- RASTREABILIDADE
                    INSERT INTO T_TRAN_LOG_HOLDING(TRAN_LOG_HOLDING_ID, TRAN_TYPE, DESCRIPTION, START_TRAN_DATE, START_TRAN_TIME, EMPLOYEE_ID, WH_ID, CONTROL_NUMBER, LOCATION_ID, ITEM_NUMBER, TRAN_QTY)
                    VALUES(NULL, '091', 'I - Ajuste no Lote', SYSDATE, SYSDATE, 'HJS', REC_MAIN.WH_ID, 'Lote Antigo: '||REC_MAIN.LOT_NUMBER, REC_MAIN.LOCATION_ID, REC_MAIN.ITEM_NUMBER, REC_MAIN.ACTUAL_QTY);  
            
        ELSE 
        
                UPDATE t_stored_item set lot_number = null
                WHERE item_number = rec_main.item_number
                and wh_id = rec_main.wh_id
                and lot_number = rec_main.lot_number
                and location_id = rec_main.location_id;
                
                    -- RASTREABILIDADE
                    INSERT INTO T_TRAN_LOG_HOLDING(TRAN_LOG_HOLDING_ID, TRAN_TYPE, DESCRIPTION, START_TRAN_DATE, START_TRAN_TIME, EMPLOYEE_ID, WH_ID, CONTROL_NUMBER, LOCATION_ID, ITEM_NUMBER, TRAN_QTY)
                    VALUES(NULL, '091', 'U - Ajuste no Lote', SYSDATE, SYSDATE, 'HJS', REC_MAIN.WH_ID, 'Lote Antigo: '||REC_MAIN.LOT_NUMBER, REC_MAIN.LOCATION_ID, REC_MAIN.ITEM_NUMBER, REC_MAIN.ACTUAL_QTY);  
        
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