SET SERVEROUTPUT ON
DECLARE

/*  
    GUSTAVO FÉLIX
    - 14/10/2020
    - Reenviar interface de Derrubada de Inbound (YopuCom)
    - Problema PRB0042007 
*/

CURSOR c_main IS
    SELECT DISTINCT host_group_id, so_line_number, so_number, item_number, wh_id
    FROM t_al_host_ship_detail 
        WHERE so_number IN (SELECT order_number 
                            FROM t_pick_detail 
                            WHERE wave_id IN ('WYC24.08.0001','WYC24.08.0003'))
        AND status = 'EX'
        AND lot_number = 'W';
rec_main c_main%ROWTYPE;


CURSOR c_consome IS
    SELECT DISTINCT host_group_id FROM t_al_host_ship_detail 
        WHERE status = 'EX'
        AND lot_number = 'W'
        AND ASN_LINE_NUMBER = 'PRB0042007'
        ;
rec_consome c_consome%ROWTYPE;


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
        
        UPDATE t_al_host_ship_detail 
        set so_line_number = '40'||so_line_number
        , ASN_LINE_NUMBER = 'PRB0042007'
        , host_group_id = SYS_GUID()
            WHERE host_group_id = rec_main.host_group_id
            and item_number     = rec_main.item_number
            and wh_id           = rec_main.wh_id
            and so_number       = rec_main.so_number
            and so_line_number  = rec_main.so_line_number;
    
    END LOOP;

COMMIT;


    FOR rec_consome IN c_consome	LOOP
    
        IF c_consome%NOTFOUND Then
            EXIT;
        END IF;
        
        SELECT pkg_webservices.USF_CALL_WEBSERVICE ('EXP_SOSTATUS',rec_consome.HOST_GROUP_ID) 
        INTO v_Rertorno FROM DUAL;
        
        update T_AL_HOST_SHIP_DETAIL set ASN_LINE_NUMBER = substr(v_Rertorno,0,10)
        where HOST_GROUP_ID = rec_consome.HOST_GROUP_ID;
   
    END LOOP;

-- dbms_output.put_line ('Tarefa Criada para o LPN: '||rec_main.HU_ID); 	
 EXCEPTION -- Exceção do Laço (For)
          WHEN OTHERS THEN
               ROLLBACK;
               v_nErrorCode  := -20006;
               v_vchErrorMsg := 'SQLERRM = ' || SQLERRM;
               RAISE e_UnknownError;

END;