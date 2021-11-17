SET SERVEROUTPUT ON
DECLARE

CURSOR c_main IS
-- CONSULTA
    SELECT     
        DISTINCT pom.po_number,
        (select SYS_GUID() from dual) as HOST_GROUP,
        '158'                as  TRANSACTION_CODE,
        'HJS'                as  USER_ID,
        pom.vendor_code      ,        
        asn.item_number,
        null                 as line_number,
        asn.qty              as qty_received,
        asn.hu_id,
        pom.wh_id,
        pom.display_po_number,
        asn.document_type||'-'||asn.distro_number as DOCUMENT_TYPE,
        --'ATS'               as status,
         case when nvl(asn.context,'X') in ('DEVTRI','ACORDO','SINFIS','BUFFER','TSFCST','TSFDOA') then 'TRBL' else 'ATS' END status
        , pom.client_code,
        asn.context             as  PACK_SLIP
    FROM t_al_host_transfer_asn asn
        inner join t_po_master pom
            on asn.display_po_number = pom.display_po_number
            and asn.wh_id = pom.wh_id
    where pom.po_number in ('12050847');
    rec_main c_main%ROWTYPE;


    CURSOR c_main2 IS
    -- CONSULTA
    SELECT DISTINCT PO_NUMBER FROM t_al_host_receipt
    WHERE fork_id = 'TEMP_USER'
   ;
    rec_main2 c_main2%ROWTYPE;


        -- Error handling variables
        c_vchObjName  VARCHAR2(30 CHAR); -- The name that uniquely tags this object.
        v_vchErrorMsg VARCHAR2(2000 CHAR);
        v_nErrorCode  NUMBER;
        -- Exceptions
        e_KnownError   EXCEPTION;
        e_UnknownError EXCEPTION;
        v_vchNewHost    VARCHAR2(50 CHAR);
        v_vchReturn     VARCHAR2(2000 CHAR);


BEGIN


	FOR  rec_main IN c_main	LOOP
	
    IF c_main%NOTFOUND Then
      EXIT;
    END IF;	
    
        -- INSERIR
          INSERT INTO t_al_host_receipt
            (
                host_group_id,
                transaction_code,
                user_id,
                vendor_code,
                po_number,
                item_number,
                line_number,
                qty_received,
                hu_id,
                wh_id,
                display_po_number,
                scac_code,
                status,
                client_code,
                pack_slip,
                fork_id
            ) VALUES
            (
                REC_MAIN.HOST_GROUP
                , REC_MAIN.TRANSACTION_CODE
                , REC_MAIN.USER_ID
                , REC_MAIN.VENDOR_CODE
                , REC_MAIN.PO_NUMBER
                , REC_MAIN.ITEM_NUMBER
                , NULL
                , REC_MAIN.QTY_RECEIVED
                , REC_MAIN.HU_ID
                , REC_MAIN.WH_ID
                , REC_MAIN.DISPLAY_PO_NUMBER
                , REC_MAIN.DOCUMENT_TYPE
                , REC_MAIN.STATUS
                , REC_MAIN.CLIENT_CODE
                , REC_MAIN.PACK_SLIP
                , 'TEMP_USER'
            );
							
    END LOOP;
    
    COMMIT;
    
	FOR  rec_main2 IN c_main2	LOOP
	
    IF c_main2%NOTFOUND Then
      EXIT;
    END IF;	
        
        SELECT SYS_GUID()  INTO v_vchNewHost FROM DUAL;
        
        UPDATE t_al_host_receipt set host_group_id = v_vchNewHost, fork_id = 'COMPLETE'
        WHERE po_number = REC_MAIN2.PO_NUMBER;
        
        COMMIT;
        
        SELECT PKG_WEBSERVICES.USF_CALL_WEBSERVICE('EXP_RECEB',v_vchNewHost) INTO v_vchReturn FROM DUAL;
        dbms_output.put_line ('PO: '||REC_MAIN2.PO_NUMBER|| ' Host Group: '|| v_vchNewHost||' Retorno: '||v_vchReturn); 	

    
    END LOOP;
    

COMMIT;


 EXCEPTION -- Exceção do Laço (For)
          WHEN OTHERS THEN
               ROLLBACK;
               v_nErrorCode  := -20006;
               v_vchErrorMsg := 'SQLERRM = ' || SQLERRM;
               RAISE e_UnknownError;

END;