SET SERVEROUTPUT ON
DECLARE
/**************************************************************************************
- Corrgir Envio de UPCs nas interfaces de Ajustes
- Gustavo Félix - 08/10/2020
**************************************************************************************/
CURSOR c_main IS
        SELECT 
            adj.item_number as upc
            , adj.adjustment_id
            , adj.host_group_id
            , upc.item_number
            , adj.wh_id
        FROM dbo.t_al_host_inventory_adjustment adj
        INNER JOIN t_item_upc upc
            ON adj.item_number = upc.upc
            AND adj.wh_id = upc.wh_id
        WHERE NOT EXISTS (SELECT 1 FROM t_item_master itm
                            WHERE adj.item_number = itm.item_number
                            AND adj.wh_id = itm.wh_id)
        ORDER BY adj.record_create_date DESC;   
rec_main c_main%ROWTYPE;


CURSOR c_main2 IS
    select distinct host_group_id as host_group_id
    from DBO.t_al_host_inventory_adjustment
    where gen_attribute_value1 = 'Problema PRB0043131'
    and gen_attribute_value3 is null
    ;
rec_main2 c_main2%ROWTYPE;


     -- Error handling variables
     c_vchObjName  VARCHAR2(30 CHAR); -- The name that uniquely tags this object.
     v_vchErrorMsg VARCHAR2(2000 CHAR);
     v_nErrorCode  NUMBER;
     v_nPickID      NUMBER;
     v_nTranLogID   NUMBER;
     v_vchReturn    VARCHAR2(2000 CHAR);
     
     -- Exceptions
     e_KnownError   EXCEPTION;
     e_UnknownError EXCEPTION;
     ErrMsg         VARCHAR2(3100);


BEGIN

	FOR rec_main IN c_main	LOOP
	
		IF c_main%NOTFOUND Then
		  EXIT;
		END IF;
		
    -- Atualiza a informação
    UPDATE t_al_host_inventory_adjustment 
    set item_number = rec_main.item_number
    , display_item_number = rec_main.item_number
    , gen_attribute_value1 = 'Problema PRB0043131'
    , gen_attribute_value2 = item_number /*UPC*/
    WHERE adjustment_id = rec_main.adjustment_id;
							
  END LOOP;
  
  COMMIT;
  
  
  -- REPROCESSAR OS HOSTS CORRIGIDOS
    FOR rec_main2 IN c_main2 LOOP
	
		IF c_main2%NOTFOUND Then
		  EXIT;
		END IF;
		
        SELECT PKG_WEBSERVICES.USF_CALL_WEBSERVICE('EXP_INV_ADJUST',rec_main2.host_group_id) into v_vchReturn
        FROM DUAL;
        
        UPDATE DBO.t_al_host_inventory_adjustment set gen_attribute_value3 = v_vchReturn
        where host_group_id = rec_main2.host_group_id;
							
    END LOOP;
  
COMMIT;

 EXCEPTION -- Exceção do Laço (For)
          WHEN OTHERS THEN
               ROLLBACK;
               v_nErrorCode  := -20006;
               v_vchErrorMsg := 'SQLERRM = ' || SQLERRM;
               RAISE e_UnknownError;

END;
