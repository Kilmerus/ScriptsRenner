SET SERVEROUTPUT ON
DECLARE

CURSOR c_main IS
    SELECT 
        DISTINCT alr.po_number
        , alr.wh_id
        , alr.host_group_id
        , pom.fulfillment_id
    FROM t_al_host_receipt alr
    INNER JOIN t_po_master pom
        ON pom.po_number = alr.po_number
        AND pom.wh_id = alr.wh_id
    WHERE alr.po_number IN (SELECT po_number FROM t_po_master WHERE type_id = '1762')
    AND alr.fulfillment_id = '0'
    AND alr.wh_id = '40499';
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
    v_Rertorno          VARCHAR2(2000 CHAR);

BEGIN

    FOR rec_main IN c_main	LOOP
    
        IF c_main%NOTFOUND Then
            EXIT;
        END IF;
      
        UPDATE t_al_host_receipt set fulfillment_id = rec_main.fulfillment_id
        WHERE host_group_id = rec_main.host_group_id
        AND po_number = rec_main.po_number
        and wh_id = rec_main.wh_id;
        
        COMMIT;
        
        SELECT PKG_WEBSERVICES.USF_CALL_WEBSERVICE('EXP_DESFAZIMENTO', rec_main.host_group_id) INTO v_Rertorno
        FROM DUAL;
        
    END LOOP;

COMMIT;

 EXCEPTION
          WHEN OTHERS THEN
               ROLLBACK;
               v_nErrorCode  := -20006;
               v_vchErrorMsg := 'SQLERRM = ' || SQLERRM;
               RAISE e_UnknownError;

END;