SET SERVEROUTPUT ON
DECLARE

/*  
    Recriar o estoque em endereço de TRIAGEM / INTENCAO_ACERTO
*/

-- Variáveis
v_vchLocation       VARCHAR2(100 CHAR) := 'INTENCAO_ACERTO';
v_vchControle       VARCHAR2(100 CHAR) := 'PRB0043269';
v_vchTranType       VARCHAR2(100 CHAR) := '044';
v_vchDescription    VARCHAR2(100 CHAR) := 'Incremento de estoque';
v_vchDescription2   VARCHAR2(100 CHAR) := 'Incremento de estoque - UPD';

CURSOR c_main IS
  select alm.wh_id, ald.item_number, sum(ald.quantity_shipped) as SUM_QTY 
    from DBO.t_al_host_shipment_master alm
    inner join t_al_host_shipment_detail ald
        on alm.shipment_id = ald.shipment_id
    where alm.load_id = '297069'
    GROUP BY ald.item_number, alm.wh_id;
rec_main c_main%ROWTYPE;


    -- Error handling variables
    c_vchObjName  VARCHAR2(30 CHAR); -- The name that uniquely tags this object.
    v_vchErrorMsg VARCHAR2(2000 CHAR);
    v_nErrorCode  NUMBER;
    
    -- Exceptions
    e_KnownError   EXCEPTION;
    e_UnknownError EXCEPTION;
    
    -- Variáveis
    v_numCount          NUMBER:= 0;

BEGIN

    FOR rec_main IN c_main	LOOP
    
        IF c_main%NOTFOUND Then
            EXIT;
        END IF;
        
    -- VALIDAR SE JÁ TEM ESTOQUE NO ENDEREÇO DE DESTINO
    SELECT count(*) INTO v_numCount
    from t_stored_item
    where location_id = v_vchLocation
    and item_number = rec_main.item_number
    and wh_id = rec_main.wh_id;
    
    IF v_numCount > 0 THEN
    
        -- INSERIR RASTREABILIDADE
        INSERT INTO t_tran_log_holding  
            (TRAN_TYPE, DESCRIPTION, START_TRAN_DATE, START_TRAN_TIME, END_TRAN_DATE, END_TRAN_TIME, CONTROL_NUMBER,
            EMPLOYEE_ID, LOCATION_ID, LOCATION_ID_2, ITEM_NUMBER, TRAN_QTY, WH_ID)
        VALUES                          
            (v_vchTranType,v_vchDescription2, SYSDATE, SYSDATE, SYSDATE, SYSDATE, v_vchControle,
            'HJS',v_vchLocation, v_vchLocation, REC_MAIN.ITEM_number, rec_main.SUM_QTY, REC_MAIN.wh_id);
    
        UPDATE t_stored_item set actual_qty = actual_qty+rec_main.SUM_QTY
        WHERE item_number = rec_main.item_number
        and wh_id = rec_main.wh_id
        and location_id = v_vchLocation;
    
    ELSE
        
        -- INSERIR RASTREABILIDADE
        INSERT INTO t_tran_log_holding  
            (TRAN_TYPE, DESCRIPTION, START_TRAN_DATE, START_TRAN_TIME, END_TRAN_DATE, END_TRAN_TIME, CONTROL_NUMBER,
            EMPLOYEE_ID, LOCATION_ID, LOCATION_ID_2, ITEM_NUMBER, TRAN_QTY, WH_ID)
        VALUES                          
            (v_vchTranType,v_vchDescription, SYSDATE, SYSDATE, SYSDATE, SYSDATE, v_vchControle,
            'HJS',v_vchLocation, v_vchLocation, REC_MAIN.ITEM_number, rec_main.SUM_QTY, REC_MAIN.wh_id);
        
        INSERT INTO t_stored_item (SEQUENCE, ITEM_NUMBER, ACTUAL_QTY, UNAVAILABLE_QTY, STATUS, WH_ID, LOCATION_ID, type)
        VALUES (0, rec_main.item_number, rec_main.SUM_QTY, 0, 'A', REC_MAIN.wh_id, v_vchLocation, 0);  
    
    END IF;
    
                    
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