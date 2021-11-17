SET SERVEROUTPUT ON
DECLARE


-- CAPA
CURSOR c_master IS
    SELECT ROWID 
    FROM T_AL_HOST_ORDER_MASTER 
        WHERE HOST_ORDER_MASTER_ID IS NULL
        AND RECORD_CREATE_DATE >= TRUNC(SYSDATE)
        --AND order_number = '2050314428'
        ;
rec_master c_master%ROWTYPE;

-- DETALHES
CURSOR c_detail IS
    SELECT ROWID 
    FROM T_AL_HOST_ORDER_DETAIL 
        WHERE HOST_ORDER_DETAIL_ID IS NULL
        AND RECORD_CREATE_DATE >= TRUNC(SYSDATE);
rec_detail c_detail%ROWTYPE;

    -- Error handling variables
    c_vchObjName  VARCHAR2(30 CHAR); -- The name that uniquely tags this object.
    v_vchErrorMsg VARCHAR2(2000 CHAR);
    v_nErrorCode  NUMBER;
    
    -- Exceptions
    e_KnownError   EXCEPTION;
    e_UnknownError EXCEPTION;
    v_NewID NUMBER;
    

BEGIN

    FOR rec_master IN c_master	LOOP
    
        IF c_master%NOTFOUND Then
            EXIT;
        END IF;
        
        SELECT DBO.sq_host_order_master_id.NEXTVAL INTO v_NewID FROM dual;
        
        -- ATUALIZAR A MASTER
        UPDATE t_al_host_order_master set HOST_ORDER_MASTER_ID = v_NewID
        WHERE rowid = rec_master.ROWID;
    
    END LOOP;

COMMIT;    
    
    FOR rec_detail IN c_detail	LOOP
    
        IF c_detail%NOTFOUND Then
            EXIT;
        END IF;
        
        SELECT DBO.sq_host_order_detail_id.NEXTVAL INTO v_NewID FROM dual;
        
        -- ATUALIZAR A MASTER
        UPDATE t_al_host_order_detail set HOST_ORDER_DETAIL_ID = v_NewID
        WHERE rowid = rec_detail.ROWID;
    
    END LOOP;

COMMIT;

UPDATE T_AL_HOST_ORDER_DETAIL ALD
    SET ALD.host_order_master_id = (select host_order_master_id 
                                    FROM T_AL_HOST_ORDER_MASTER ALO
                                    WHERE ALO.order_number = ALD.order_number
                                    AND alo.host_order_master_id is not null)
    WHERE ALD.HOST_ORDER_MASTER_ID IS NULL
    AND ALD.RECORD_CREATE_DATE >= TRUNC(SYSDATE);
    
COMMIT;

-- dbms_output.put_line ('Tarefa Criada para o LPN: '||rec_master.HU_ID); 	
 EXCEPTION -- Exceção do Laço (For)
          WHEN OTHERS THEN
               ROLLBACK;
               v_nErrorCode  := -20006;
               v_vchErrorMsg := 'SQLERRM = ' || SQLERRM;
               RAISE e_UnknownError;

END;