set serveroutput on;
DECLARE

/*
    Desagrupar estoque COM/SEM lote
*/


CURSOR c_main IS
    SELECT 
        STO.ITEM_NUMBER
        , STO.wh_id
        , STO.LOCATION_ID
        , ITM.lot_control
    FROM t_stored_item STO
    INNER JOIN t_item_master ITM
        ON sto.item_number = itm.item_number
        and sto.wh_id = itm.wh_id
    WHERE sto.location_id = 'AVARIA.099'
    AND sto.wh_id = '99'
    AND sto.lot_number is null
    AND exists (select 1 from t_stored_item STO2
                where STO2.location_id = STO.location_id
                and sto2.item_number = sto.item_number
                AND STO2.wh_id = STO.wh_id
                and STO2.lot_number is not null);
rec_main c_main%ROWTYPE;


     -- Error handling variables
     c_vchObjName   VARCHAR2(30 CHAR); -- The name that uniquely tags this object.
     v_vchErrorMsg  VARCHAR2(2000 CHAR);
     v_vchReturn    VARCHAR2(2000 CHAR);
     v_vchHost      VARCHAR2(2000 CHAR);
    
     v_vchIns       NUMBER;
     v_nErrorCode   NUMBER;
     -- Exceptions
     e_KnownError   EXCEPTION;
     e_UnknownError EXCEPTION;


BEGIN
    
    
    SELECT SYS_GUID() INTO v_vchHost from dual;
    
    
	FOR rec_main IN c_main	LOOP
	
	IF c_main%NOTFOUND Then
      EXIT;
	END IF;
	
    IF rec_main.lot_control = 'N' THEN
 
        -- SOMAR A QUANTIDADE
        UPDATE t_stored_item set actual_qty = actual_qty + (select SUM(actual_qty) from t_stored_item
                                                            where item_number = rec_main.item_number
                                                            and wh_id = rec_main.wh_id
                                                            and location_id = rec_main.location_id
                                                            and lot_number is not null)
        WHERE item_number = rec_main.item_number
        and wh_id = rec_main.wh_id
        and lot_number is null
        and location_id = rec_main.location_id;
    
        -- DELETAR A LINHA
        DELETE t_stored_item 
            WHERE item_number = rec_main.item_number
            and wh_id = rec_main.wh_id
            and lot_number is not null -- DELETE O QUE TEM LOTE
            and location_id = rec_main.location_id;
            
    ELSE
    
        -- SOMAR A QUANTIDADE
        UPDATE t_stored_item set actual_qty = actual_qty + (select SUM(actual_qty) from t_stored_item
                                                            where item_number = rec_main.item_number
                                                            and wh_id = rec_main.wh_id
                                                            and location_id = rec_main.location_id
                                                            and lot_number is null)
        WHERE item_number = rec_main.item_number
        and wh_id = rec_main.wh_id
        and lot_number is not null
        and location_id = rec_main.location_id;
    
        -- DELETAR A LINHA
        DELETE t_stored_item 
            WHERE item_number = rec_main.item_number
            and wh_id = rec_main.wh_id
            and lot_number is null -- DELETE O QUE "NÃO" TEM LOTE
            and location_id = rec_main.location_id;
    
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
