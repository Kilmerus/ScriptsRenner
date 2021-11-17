set serveroutput on;
DECLARE

/*
    - Erro no processo de Contagem Cíclica - Permitindo efetuar contagem (Pré-Distribuição) para LPNs reservados
    - Cenário (1)
*/


CURSOR c_main IS
    SELECT 
        cyc.location_id
        , cyc.wh_id
        , cyc.hu_id
        , cyc.item_number
        , cyc.count_qty
        , cyc.expected_qty
        , sto.location_id as location_id_2
        , sto.TYPE
        , cyc.cycle_count_type
        , cyc.updated_by
        , to_char(cyc.cycle_count_date, 'DD/MM/YYYY HH24:MI:SS') as data_cycle
        , cyc.parent_hu_id
    FROM t_cycle_count_detail cyc
    INNER JOIN t_stored_item sto
        ON cyc.hu_id = sto.hu_id
        AND cyc.cycle_count_type = 'PRD'
        AND sto.location_id = 'RETENCAO'
        AND sto.TYPE <> 'STORAGE'
        AND cyc.status = 'APRV'
        AND cyc.wh_id = '30098'
        --AND cyc.hu_id = '00030098000000703643'
        ;
        
rec_main c_main%ROWTYPE;


     -- Error handling variables
     c_vchObjName   VARCHAR2(30 CHAR); -- The name that uniquely tags this object.
     v_vchErrorMsg  VARCHAR2(2000 CHAR);
     v_vchReturn    VARCHAR2(2000 CHAR);
     v_vchHost      VARCHAR2(2000 CHAR);
    
     v_vchIns       NUMBER;
     v_nErrorCode   NUMBER;
     -- Exceptions
     e_KnownError   EXCEPTION;
     e_UnknownError EXCEPTION;
     
     v_nCount   NUMBER;


BEGIN
    
	FOR rec_main IN c_main	LOOP
	
        IF c_main%NOTFOUND Then
          EXIT;
        END IF;

        -- RASTREABILIDADE
        INSERT INTO T_TRAN_LOG_HOLDING(TRAN_LOG_HOLDING_ID, TRAN_TYPE, DESCRIPTION, START_TRAN_DATE, START_TRAN_TIME, EMPLOYEE_ID, WH_ID, ITEM_NUMBER, NUM_ITEMS,  TRAN_QTY, CONTROL_NUMBER, CONTROL_NUMBER_2, LOT_NUMBER, LOCATION_ID, LOCATION_ID_2, HU_ID, PARENT_HU_ID)
        VALUES(NULL
                , '053'
                , 'LPNs Excluídos de Retenção'
                , SYSDATE
                , SYSDATE
                , rec_main.updated_by
                , rec_main.WH_ID
                , rec_main.item_number
                , rec_main.expected_qty
                , rec_main.count_qty
                , 'Contagem: '||rec_main.cycle_count_type
                , 'Data: '||rec_main.data_cycle
                , rec_main.type
                , rec_main.location_id
                , rec_main.location_id_2
                , rec_main.hu_id
                , rec_main.parent_hu_id
                );  
          
        SELECT count(*) INTO v_nCount
        FROM t_stored_item 
        WHERE hu_id = rec_main.hu_id
        and wh_id = rec_main.wh_id;
        
        
        IF v_nCount > 0 THEN        
            DELETE t_stored_item  where hu_id = rec_main.hu_id and wh_id = rec_main.wh_id and location_id = 'RETENCAO';  
            
            DELETE t_hu_master where hu_id = rec_main.hu_id and wh_id = rec_main.wh_id and location_id = 'RETENCAO';  
            
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


/*

		CENÀRIO 2
	
*/


set serveroutput on;
DECLARE

/*
    - Erro no processo de Contagem Cíclica - Permitindo efetuar contagem (Pré-Distribuição) para LPNs reservados
    - Cenário (1)
*/


CURSOR c_main IS
    SELECT 
        sto.item_number
        , sto.wh_id
        , sto.location_id
        , null as location_id_2
        , sto.type
        , sto.actual_qty
        , sto.hu_id
    FROM t_stored_item sto
    WHERE location_id = 'RETENCAO'
    AND wh_id = '30098'
    AND EXISTS (SELECT 1 FROM dbo.t_cycle_count_detail cyc
                    WHERE cyc.hu_id = sto.hu_id
                    AND cyc.wh_id = sto.wh_id
                    --and cyc.item_number = sto.item_number
                    AND cyc.status = 'APRV'
                    AND cyc.cycle_count_type NOT IN ('POS')
                    )
    AND NOT EXISTS (SELECT 1 FROM dbo.t_cycle_count_detail cyc
                    WHERE cyc.hu_id = sto.hu_id
                    AND cyc.wh_id = sto.wh_id
                    AND cyc.item_number = sto.item_number
                    AND cyc.status = 'PEND'
                    AND cyc.cycle_count_type NOT IN ('POS')
                    )
                    
    --and sto.hu_id = '00030098001200009919'
    ;
        
rec_main c_main%ROWTYPE;


     -- Error handling variables
     c_vchObjName   VARCHAR2(30 CHAR); -- The name that uniquely tags this object.
     v_vchErrorMsg  VARCHAR2(2000 CHAR);
     v_vchReturn    VARCHAR2(2000 CHAR);
     v_vchHost      VARCHAR2(2000 CHAR);
    
     v_vchIns       NUMBER;
     v_nErrorCode   NUMBER;
     -- Exceptions
     e_KnownError   EXCEPTION;
     e_UnknownError EXCEPTION;
     
     v_nCount   NUMBER;


BEGIN
    
	FOR rec_main IN c_main	LOOP
	
        IF c_main%NOTFOUND Then
          EXIT;
        END IF;

        -- RASTREABILIDADE
        INSERT INTO T_TRAN_LOG_HOLDING(TRAN_LOG_HOLDING_ID, TRAN_TYPE, DESCRIPTION, START_TRAN_DATE, START_TRAN_TIME, EMPLOYEE_ID, WH_ID, ITEM_NUMBER, NUM_ITEMS,  TRAN_QTY, CONTROL_NUMBER, CONTROL_NUMBER_2, LOT_NUMBER, LOCATION_ID, LOCATION_ID_2, HU_ID)
        VALUES(NULL
                , '053'
                , 'LPNs Excluídos de Retenção'
                , SYSDATE
                , SYSDATE
                , 'HJS'
                , rec_main.WH_ID
                , rec_main.item_number
                , 0
                , rec_main.actual_qty
                , 'Cenário 2'
                , null
                , rec_main.type
                , rec_main.location_id
                , rec_main.location_id_2
                , rec_main.hu_id
                --, rec_main.parent_hu_id
                );  
          
        SELECT count(*) INTO v_nCount
        FROM t_stored_item 
        WHERE hu_id = rec_main.hu_id
        and wh_id = rec_main.wh_id;
        
        
        IF v_nCount > 0 THEN        
            
            DELETE t_stored_item  where hu_id = rec_main.hu_id and wh_id = rec_main.wh_id and location_id = 'RETENCAO';              
            
            DELETE t_hu_master where hu_id = rec_main.hu_id and wh_id = rec_main.wh_id and location_id = 'RETENCAO';  
            
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

