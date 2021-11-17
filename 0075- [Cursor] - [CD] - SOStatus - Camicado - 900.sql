SET SERVEROUTPUT ON
DECLARE
/**************************************************************************************
**************************************************************************************/
CURSOR c_main IS
    SELECT 
        shd.so_number
        , shd.so_line_number
        , shd.wh_id
        , shd.item_number
        , COM.br_order_number_orig
        , shd.host_group_id
        , sys_guid() AS new_host
        , shd.host_ship_detail_id
    FROM t_al_host_ship_detail shd
    LEFT JOIN dbo.t_order_detail_comment COM
        ON shd.so_number = COM.order_number
        AND shd.wh_id = COM.wh_id
        AND shd.so_line_number = COM.line_number
        AND shd.item_number = COM.item_number
    WHERE so_number LIKE    '9%'
    AND container_type      = 'A'
    AND client_code         = '003'
    AND transaction_code    = '336'
    AND ROWNUM <= 400    
    ;
rec_main c_main%ROWTYPE;

     -- Default
     v_vchErrorMsg  VARCHAR2(2000 CHAR);
     v_nErrorCode   NUMBER;
     e_UnknownError EXCEPTION;
     
     v_vchReturn  VARCHAR2(2000 CHAR);
     
BEGIN

    FOR rec_main IN c_main	LOOP
    
        IF c_main%notfound THEN
            EXIT;
        END IF;

    UPDATE t_al_host_ship_detail SET host_group_id = rec_main.new_host
                                    , so_number = rec_main.br_order_number_orig
                                    , container_type = 'T'
                                    , asn_number = so_number
    WHERE host_ship_detail_id = rec_main.host_ship_detail_id;
    
    
    COMMIT;
    
    SELECT pkg_webservices.USF_CALL_WEBSERVICE ('EXP_SOSTATUS',rec_main.new_host) 
    INTO v_vchReturn FROM DUAL;      
    

    END LOOP;
  
  COMMIT;

 EXCEPTION 
          WHEN OTHERS THEN
               ROLLBACK;
               v_nErrorCode  := -20006;
               v_vchErrorMsg := 'SQLERRM = ' || SQLERRM;
               RAISE e_UnknownError;

END;
