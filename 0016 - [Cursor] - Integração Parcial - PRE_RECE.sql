SET SERVEROUTPUT ON
DECLARE

--Versão 3.0

v_vchASN VARCHAR2(2000 CHAR):= '0010046400026242400114';

CURSOR c_main IS
        select pkd.order_number, pkd.item_number, pkd.wh_id , orm.cust_po_number
        from t_order orm
            inner join t_pick_detail pkd
                on orm.order_number = pkd.order_number
                and orm.wh_id = pkd.wh_id
            inner join t_order_detail ord
                on ord.order_number =  orm.order_number
                and ord.wh_id = orm.wh_id
        where orm.cust_po_number = '0010046400026242400114'
        and pkd.status = 'RELEASED'
        and not exists (select 1 from t_stored_item sto
                        where sto.serial_number = orm.order_number
                        and sto.item_number = ord.item_number
                        and sto.wh_id = orm.wh_id);
rec_main c_main%ROWTYPE;

CURSOR c_main_2 IS
    SELECT HU_ID, WH_ID,parent_hu_id  FROM t_hu_master where parent_hu_id = v_vchASN
    and location_id = 'PRE_RECE_TRANSF'
    --and hu_id in ('00000114000010131848','00000114000010119307')
    ;


     -- Error handling variables
     c_vchObjName  VARCHAR2(30 CHAR); -- The name that uniquely tags this object.
     
     
     v_vchErrorMsg VARCHAR2(2000 CHAR);
     v_nErrorCode  NUMBER;
     -- Exceptions
     e_KnownError   EXCEPTION;
     e_UnknownError EXCEPTION;

    v_chHU_ID      VARCHAR2(30 CHAR);
    v_nCount        NUMBER;
    v_nCont         NUMBER:= 0;

BEGIN


    <<Reinicio>>
	FOR rec_main IN c_main	LOOP
	
	IF c_main%NOTFOUND Then
      EXIT;
	END IF;

        -- PEGAR  1 LPN A SER ATUALIZADO
        select 
        max(sto.hu_id) into v_chHU_ID
        from t_stored_item sto
            inner join t_hu_master hum
                on sto.hu_id = hum.hu_id
                and sto.wh_id = hum.wh_id
                and hum.parent_hu_id = rec_main.cust_po_number
                and hum.location_id = 'PRE_RECE_TRANSF'
        where sto.serial_number =0;
        
        -- REATRIBUICAO DA ALOCACAO AO LPN
        UPDATE t_stored_item sto
            SET sto.serial_number = rec_main.order_number
        where sto.hu_id = v_chHU_ID
        and sto.item_number = rec_main.item_number
        and sto.wh_id = rec_main.wh_id;
        
       						
  END LOOP; -- FIM DO LAÇO PRINCIPAL
  
  COMMIT;
  
  
    FOR rec_main_2 IN c_main_2	LOOP	
    
        IF c_main_2%NOTFOUND THEN
            EXIT;
        END IF;            
        
        -- PROCESSA
         USP_PROCESS_TRANSFER_LPS (rec_main_2.wh_id,rec_main_2.parent_hu_id,rec_main_2.hu_id); 
        
        -- FIM CURSOR rec_main
    END LOOP;
  

 EXCEPTION -- Exceção do Laço (For)
          WHEN OTHERS THEN
               ROLLBACK;
               v_nErrorCode  := -20006;
               v_vchErrorMsg := 'SQLERRM = ' || SQLERRM;
               RAISE e_UnknownError;

END;