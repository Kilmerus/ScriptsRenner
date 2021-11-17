SET SERVEROUTPUT ON
DECLARE
/**************************************************************************************
- Enviar fechamento de remessa de Loja (CAMICADO)
**************************************************************************************/
CURSOR c_main IS
    SELECT
        '00'    as HOST,
        '164'   as transaction_code,
        'HJS'   as user_id,
        pom.vendor_code,
        pom.po_number,
        pod.item_number,
        ROWNUM AS line_number,
        pod.qty,
        ass.hu_id,
        pom.wh_id,
        pom.display_po_number,
        ass.document_type||'-'||ass.distro_number AS scac_code,
        CASE WHEN nvl(ass.CONTEXT,'X') IN ('DEVTRI','ACORDO','SINFIS','BUFFER','TSFCST','TSFDOA')
        THEN 'TRBL'
        ELSE 'ATS' END status,
        pom.client_code,
        'BUFFER' as CONTEXT
        --ass.CONTEXT
    FROM 
    t_po_master pom
        INNER JOIN t_exception_log LOG
            ON pom.po_number = LOG.item_number
            AND LOG.tran_type = '059'
        INNER JOIN t_po_detail pod
            ON pom.po_number = pod.po_number
            AND pom.wh_id = pod.wh_id
        INNER JOIN t_al_host_transfer_asn ass
            ON ass.display_po_number = pom.display_po_number
            AND ass.wh_id = pom.wh_id
            AND UPPER(ass.processing_code) = 'NEW'
    WHERE pom.status = 'O'
    AND pom.type_id = '1637'
    --AND pom.po_number = '1565393'
    --AND pom.po_number = '1565398'
    AND NOT EXISTS (SELECT 1 FROM t_al_host_receipt al
                    WHERE al.po_number = pom.po_number);

rec_main c_main%ROWTYPE;

CURSOR c_consome IS
    SELECT po_number, SYS_GUID() as HOST_GROUP
    FROM t_al_host_receipt
    WHERE host_group_id = '00';
rec_consome c_consome%ROWTYPE;


     -- Error handling variables
     c_vchObjName   VARCHAR2(30 CHAR); -- The name that uniquely tags this object.
     v_vchErrorMsg  VARCHAR2(2000 CHAR);
     v_nErrorCode   NUMBER;
     v_vchReturn    VARCHAR2(2000 CHAR);
     
     -- Exceptions
     e_KnownError   EXCEPTION;
     e_UnknownError EXCEPTION;
     ErrMsg         VARCHAR2(3100);
     
     
     v_Tran_Type    VARCHAR2(30 CHAR);
     
     v_vchChamado   VARCHAR2(30 CHAR):= 'INC0242510';
     
     
BEGIN

    v_Tran_Type:= '045';

    FOR rec_main IN c_main	LOOP
    
        IF c_main%NOTFOUND Then
            EXIT;
        END IF;
    
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
        pack_slip
    ) VALUES
    (
        rec_main.HOST
        , rec_main.transaction_code
        , rec_main.user_id
        , rec_main.vendor_code
        , rec_main.po_number
        , rec_main.item_number
        , rec_main.line_number
        , rec_main.qty
        , rec_main.hu_id
        , rec_main.wh_id
        , rec_main.display_po_number
        , rec_main.scac_code
        , rec_main.status
        , rec_main.client_code
        , rec_main.context);
        
    END LOOP;
  
  COMMIT;
  
  
      FOR rec_consome IN c_consome	LOOP
    
        IF c_consome%NOTFOUND Then
            EXIT;
        END IF;
        
             UPDATE t_al_host_receipt set host_group_id = rec_consome.HOST_GROUP
                WHERE po_number = rec_consome.po_number
                and host_group_id = '00';
                
            UPDATE t_po_master set status = 'C'
                WHERE po_number = rec_consome.po_number;

            COMMIT;
           
        SELECT PKG_WEBSERVICES.USF_CALL_WEBSERVICE('EXP_RECEB', rec_consome.HOST_GROUP) into v_vchReturn FROM dual;

    END LOOP;
    
    COMMIT;

 EXCEPTION -- Exceção do Laço (For)
          WHEN OTHERS THEN
               ROLLBACK;
               v_nErrorCode  := -20006;
               v_vchErrorMsg := 'SQLERRM = ' || SQLERRM;
               RAISE e_UnknownError;

END;
