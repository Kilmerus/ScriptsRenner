SET SERVEROUTPUT ON
DECLARE

/*  
    GUSTAVO FÉLIX
    - 15/10/2020
    - Remessas não integradas
*/

CURSOR c_main IS
    SELECT 
        alo.host_group_id
        , alo.order_number
        , alo.wh_id
        , alo.customer_po_number
        , sys_guid() as new_guid
    FROM t_al_host_order_master alo
        WHERE alo.host_group_id IN (SELECT host_group_id FROM t_al_host_po_master alp
                                WHERE alp.po_number IN ('2125685'))
        AND EXISTS (SELECT 1 FROM t_order orm
                    WHERE orm.order_number = alo.order_number)
        AND NOT EXISTS (SELECT 1 FROM t_po_master pom
                        WHERE pom.display_po_number = alo.customer_po_number)
                    ;
rec_main c_main%ROWTYPE;


CURSOR c_consome IS
    SELECT DISTINCT host_group_id FROM t_al_host_po_master 
        WHERE po_number in ('2125685')
        ;
rec_consome c_consome%ROWTYPE;


    -- Error handling variables
    c_vchObjName  VARCHAR2(30 CHAR); -- The name that uniquely tags this object.
    v_vchErrorMsg VARCHAR2(2000 CHAR);
    v_nErrorCode  NUMBER;
    
    -- Exceptions
    e_KnownError   EXCEPTION;
    e_UnknownError EXCEPTION;
    

BEGIN

    FOR rec_main IN c_main	LOOP
    
        IF c_main%NOTFOUND Then
            EXIT;
        END IF;
        
    -- DESASSOCIAR A ALOCAÇÃO DO HOST DA PO (CAPA)
    UPDATE t_al_host_order_master 
            set host_group_id = rec_main.new_guid
            , display_order_number = order_number
        WHERE order_number = rec_main.order_number
        and wh_id = rec_main.wh_id
        and host_group_id = rec_main.host_group_id
        and customer_po_number = rec_main.customer_po_number;
    
    
    -- DETALHE
    UPDATE  t_al_host_order_detail 
            set host_group_id = rec_main.new_guid
            , display_order_number = order_number
        WHERE order_number = rec_main.order_number
        and wh_id = rec_main.wh_id
        and host_group_id = rec_main.host_group_id;
    
    END LOOP;

COMMIT;


    FOR rec_consome IN c_consome	LOOP
    
        IF c_consome%NOTFOUND Then
            EXIT;
        END IF;
        
        BR_USP_INSERT_EA_EVENT ('IMP_PO_ALLOC',rec_consome.HOST_GROUP_ID);
  
    END LOOP;

-- dbms_output.put_line ('Tarefa Criada para o LPN: '||rec_main.HU_ID); 	
 EXCEPTION -- Exceção do Laço (For)
          WHEN OTHERS THEN
               ROLLBACK;
               v_nErrorCode  := -20006;
               v_vchErrorMsg := 'SQLERRM = ' || SQLERRM;
               RAISE e_UnknownError;

END;