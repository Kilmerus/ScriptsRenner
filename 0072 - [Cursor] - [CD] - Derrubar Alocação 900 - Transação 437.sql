SET SERVEROUTPUT ON
DECLARE

    CURSOR c_main IS
        SELECT 
            als.so_number as order_number
            , als.host_group_id
            , als.host_ship_detail_id
            , COM.br_order_number_orig AS so_number
            , COM.item_number
            , COM.wh_id
            , COM.line_number
            , COM.br_qty_shipped
            , als.qty
            , als.container_type
            , als.status
        FROM t_al_host_ship_detail als
        INNER JOIN t_order_detail_comment COM
            ON als.so_number = COM.order_number
            AND als.so_line_number = COM.line_number
            AND als.wh_id = COM.wh_id
            AND als.item_number = COM.item_number
        WHERE als.status = 'EX'
        AND als.so_number LIKE '9%'
        AND als.client_code = '003'
        and com.order_number in ('901477857'
                                ,'901456965'
                                ,'901455189'
                                ,'901452714'
                                ,'901438114'
                                ,'901434534'
                                ,'901434442'
                                ,'901434130'
                                ,'901434153'
                                ,'901437561'
                                ,'901440158'
                                )
        AND als.record_create_date >= TRUNC(sysdate)-60
        ;
        rec_main c_main%ROWTYPE;

    -- Error handling variables
    c_vchObjName  VARCHAR2(30 CHAR); -- The name that uniquely tags this object.
    v_vchErrorMsg VARCHAR2(2000 CHAR);
    v_nErrorCode  NUMBER;
    -- Exceptions
    e_KnownError   EXCEPTION;
    e_UnknownError EXCEPTION;
    
    v_vchHost   VARCHAR2(50 CHAR);
    v_vchReturn VARCHAR2(2000 CHAR);
    
BEGIN
	FOR rec_main IN c_main	LOOP
	
        IF c_main%NOTFOUND Then
          EXIT;
        END IF;
        
            UPDATE t_al_host_ship_detail 
            set so_number = rec_main.so_number
            , asn_number = so_number
            , container_type = 'T'
            , asn_line_number = 'SOStatusCre'
            where host_ship_detail_id = rec_main.host_ship_detail_id;
            
            
            update t_order_detail_comment set br_qty_shipped = br_qty_shipped + rec_main.qty
            where order_number = rec_main.order_number
            and item_number = rec_main.item_number
            and wh_id = rec_main.wh_id
            and line_number = rec_main.line_number;
            
            commit;
            
            SELECT pkg_webservices.USF_CALL_WEBSERVICE ('EXP_SOSTATUS',rec_main.HOST_GROUP_ID) 
            INTO v_vchReturn FROM DUAL;      


        END LOOP;
        
COMMIT;


 EXCEPTION -- Exceção do Laço (For)
          WHEN OTHERS THEN
               ROLLBACK;
               v_nErrorCode  := -20006;
               v_vchErrorMsg := 'SQLERRM = ' || SQLERRM;
               RAISE e_UnknownError;

END;