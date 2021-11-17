SET SERVEROUTPUT ON
DECLARE

/*  - Mover estoque de SINISTRO para INTECAO DE ACERTO
    - Gustavo Félix - 11/03/2020
*/

CURSOR c_main IS
    SELECT 
        exp.item_number
        , exp.exception_id
        , exp.wh_id
        , exp.quantity     as exp_qty
        , NVL((select sum(sto.actual_qty) from t_stored_item sto
            where sto.item_number = exp.item_number
            and sto.wh_id = exp.wh_id
            and sto.location_id = 'SINISTROS'),0) as sto_qty
    FROM t_exception_log exp
    WHERE   exp.tran_type = '837'
    and     exp.status is null;
rec_main c_main%ROWTYPE;


    -- Error handling variables
    c_vchObjName  VARCHAR2(30 CHAR); -- The name that uniquely tags this object.
    v_vchErrorMsg VARCHAR2(2000 CHAR);
    v_nErrorCode  NUMBER;
    
    -- Exceptions
    e_KnownError   EXCEPTION;
    e_UnknownError EXCEPTION;
    
    -- Variáveis
    v_vchSourceLocation VARCHAR2(100 CHAR) := 'SINISTROS';
    v_vchDestinLocation VARCHAR2(100 CHAR) := 'INTENCAO_ACERTO';
    v_vchSourceHUID     VARCHAR2(100 CHAR);
    v_numSTO_qty        NUMBER;
    v_numCount          NUMBER:= 0;

BEGIN

    FOR rec_main IN c_main	LOOP
    
        IF c_main%NOTFOUND Then
            EXIT;
        END IF;
        
        -- VERIFICA SE HÁ ESTOQUE EM ENDEREÇO DE SINISTRO
        IF REC_MAIN.STO_QTY > 0 THEN
        
        <<BuscaHUID>>
            SELECT HU_ID, ACTUAL_QTY
                INTO v_vchSourceHUID, v_numSTO_qty
                FROM (
                    SELECT 
                        HU_ID
                        , ITEM_NUMBER
                        , ACTUAL_QTY
                    FROM t_stored_item 
                        WHERE item_number   = rec_main.item_number
                        AND location_id     = v_vchSourceLocation
                        AND actual_qty      <= rec_main.exp_qty
                    ORDER BY actual_qty DESC)
                WHERE ROWNUM <= 1;
                
            --MOVIMENTA O ESTOQUE DA UZ QUE CONTÉM MAIS ITENS            
            USP_UNIVERSAL_MOVE_ITEMS(
                 'WA',                      --:CONST Application Identifier:,
                 '203',                     --:MoveParam Transaction Code:,
                 'HJS',                     --:MoveParam Employee ID:,
                 v_vchSourceLocation,       --:MoveParam Source Location:,
                 v_vchDestinLocation,       --:MoveParam Destination Location:,
                 'STORAGE',                 --:MoveParam Source Type:,
                 'STORAGE',                 --:MoveParam Destination Type:,
                 rec_main.wh_id,            --:MoveParam Warehouse ID:,
                 v_vchSourceHUID,           --:MoveParam Source HU_ID:,
                 null,                      --:MoveParam Destination HU_ID:,
                 rec_main.item_number,      --:MoveParam Item Number:,
                 null,                      --:MoveParam Stored Attribute ID:, 
                 null,                      --:MoveParam Lot Number:,
                 -----------
                 /*Quantidade da UZ e não a quantidade "Planejada"*/
                 v_numSTO_qty,             --:MoveParam Quantity:,
                 -----------
                 'A',                       --:MoveParam Invent Status Before:,
                 'A',                       --:MoveParam Invent Status After:,
                 null                       --:MoveParam Destination HU Type:
                 );
        
            -- Decrementar da Quantidade Planejada
            UPDATE t_exception_log set QUANTITY = QUANTITY-v_numSTO_qty, entered_value = nvl(entered_value,0) + v_numSTO_qty
            WHERE exception_id = rec_main.exception_id;
            
            INSERT INTO T_TRAN_LOG_HOLDING 
                (TRAN_TYPE, description, start_tran_date, start_tran_time, end_tran_date, end_tran_time, employee_id,  tran_qty, hu_id, item_number, location_id, location_id_2, wh_id)
            VALUES
                ('202', 'Mov. Sistêmica', SYSDATE, SYSDATE, SYSDATE, SYSDATE, 'HJS', v_numSTO_qty, v_vchSourceHUID, rec_main.item_number, v_vchSourceLocation, v_vchDestinLocation, rec_main.wh_id);
            
            -- VERIFICA SE AINDA TEM ESTOQUE NO ENDEREÇO INICIAL
            BEGIN
                SELECT HU_ID, ACTUAL_QTY
                INTO v_vchSourceHUID, v_numSTO_qty
                FROM (
                    SELECT 
                        HU_ID
                        , ITEM_NUMBER
                        , ACTUAL_QTY
                    FROM t_stored_item 
                        WHERE item_number   = rec_main.item_number
                        AND location_id     = v_vchSourceLocation
                        AND actual_qty      <= rec_main.exp_qty
                    ORDER BY actual_qty DESC)
                WHERE ROWNUM <= 1;
            
            EXCEPTION
               WHEN no_data_found THEN
                  v_numSTO_qty := 0;
            
            END;
                
            IF v_numSTO_qty > 0 THEN
                GOTO BuscaHUID;
            END IF;
        
        END IF; -- Count STO
        
        UPDATE t_exception_log set status = 'X'
        WHERE exception_id = rec_main.exception_id;
                    
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