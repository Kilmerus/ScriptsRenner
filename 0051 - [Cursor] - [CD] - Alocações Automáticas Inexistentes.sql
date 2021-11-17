SET SERVEROUTPUT ON
DECLARE

-- Atribuir novas alocações para a Expedição


CURSOR c_main IS
    select 
        shipment_detail_id
        , order_number      as  Alloc1
        , wh_id+500         as  whOrigem
        , item_number
        , line_number       as  loja
        , delivery_sap+500  as  whDestino
        , gen_attribute_value3 as Alloc2
    from t_al_host_shipment_detail where shipment_id = '16095681' and order_number in ('4013042278','4013102590','4013090254');


rec_main c_main%ROWTYPE;


     -- Error handling variables
     c_vchObjName  VARCHAR2(30 CHAR); -- The name that uniquely tags this object.
     v_vchErrorMsg VARCHAR2(2000 CHAR);
     v_nErrorCode  NUMBER;
     -- Exceptions
     e_KnownError   EXCEPTION;
     e_UnknownError EXCEPTION;



    v_vchAlloc2          VARCHAR2(40 CHAR);
    v_vchAlloc1_tsf      VARCHAR2(40 CHAR);

BEGIN
	FOR rec_main IN c_main	LOOP
	
	IF c_main%NOTFOUND Then
      EXIT;
	END IF;
	
    
    SELECT 
    alloc2, alloc1_tsf INTO v_vchAlloc2, v_vchAlloc1_tsf
    FROM (
    select 
        hd.alloc_no     as  alloc2
        , hd.order_no   as  alloc1_tsf
        , hd.release_date
    from alloc_header@consulta_rms hd
        inner join alloc_detail@consulta_rms dt
            on hd.alloc_no  = dt.alloc_no
            and dt.to_loc   = rec_main.loja                                     -- LINE_NUMBER - Interface
        inner join tsfhead@consulta_rms th  
            on th.tsf_no    = hd.order_no
            and th.from_loc = rec_main.whOrigem                                 -- CD de Origem      
        where hd.wh = rec_main.whDestino and hd.item = rec_main.item_number     -- Item
    order by hd.release_date desc)
    WHERE rownum = 1
    and alloc1_tsf <> rec_main.Alloc1;
    
    IF v_vchAlloc2 is not null THEN
    
        UPDATE DBO.t_al_host_shipment_detail
            SET     gen_attribute_value10   = order_number
                ,   gen_attribute_value11   = gen_attribute_value3
                ,   gen_attribute_value9    = null
                ,   order_number            = v_vchAlloc1_tsf
                ,   gen_attribute_value3    = v_vchAlloc2
        WHERE shipment_detail_id = rec_main.shipment_detail_id;
    
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