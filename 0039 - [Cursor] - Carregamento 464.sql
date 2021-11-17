SET SERVEROUTPUT ON
DECLARE

/*  - Mover estoque de SINISTRO para INTECAO DE ACERTO
    - Gustavo Félix - 11/03/2020
*/

CURSOR c_main IS
   select 
    sto.location_id     as  LOC_STO
    , hum.location_id   as  LOC_HUM
    , sto.hu_id
    , sto.item_number
    , pkd.planned_quantity  AS  PKD_QTY
    , sto.actual_qty        AS  STO_QTY
    , pkd.pick_id
    , hum.load_id           AS  CARGA
    , (select door_location from DBO.t_br_shipping_master where shipping_id = hum.load_id) as DOCA
    , sto.type
    , hum.control_number
    , hum.type          AS HUM
from t_stored_item sto
inner join t_hu_master hum
    on sto.hu_id = hum.hu_id
    and sto.wh_id = hum.wh_id
left join t_pick_detail PKD
    on PKD.item_number = sto.item_number
    and PKD.order_number = sto.serial_number
    and PKD.wh_id = sto.wh_id
    and PKD.line_number = hum.control_number
where sto.hu_id in ('00000002000001693451');
rec_main c_main%ROWTYPE;


    -- Error handling variables
    c_vchObjName  VARCHAR2(30 CHAR); -- The name that uniquely tags this object.
    v_vchErrorMsg VARCHAR2(2000 CHAR);
    v_nErrorCode  NUMBER;
    
    -- Exceptions
    e_KnownError   EXCEPTION;
    e_UnknownError EXCEPTION;
    
    -- Variáveis
    v_vchSourceLocation VARCHAR2(100 CHAR) := 'SINISTROS';
    v_vchDestinLocation VARCHAR2(100 CHAR) := 'INTENCAO_ACERTO';
    v_vchSourceHUID     VARCHAR2(100 CHAR);
    v_numSTO_qty        NUMBER;
    v_numCount          NUMBER:= 0;

BEGIN

    FOR rec_main IN c_main	LOOP
    
        IF c_main%NOTFOUND Then
            EXIT;
        END IF;
        
     -- UPD STO
     UPDATE t_stored_item 
         set location_id = rec_main.DOCA
         , type = rec_main.pick_id
     WHERE hu_id = rec_main.hu_id
     AND item_number = rec_main.item_number;
     
     -- UPD HUM
     UPDATE t_hu_master 
         set location_id = rec_main.doca
         , type = 'LO'
     where hu_id = rec_main.hu_id;
     
     -- UPD PKD
     UPDATE t_pick_detail 
         set status = 'LOADED'
         , picked_quantity = planned_quantity
         , staged_quantity = planned_quantity
         , loaded_quantity = planned_quantity
     where pick_id = rec_main.pick_id;
     
                    
    END LOOP;

COMMIT;

-- dbms_output.put_line ('Tarefa Criada para o LPN: '||rec_main.HU_ID); 	
 EXCEPTION -- Exceção do Laço (For)
          WHEN OTHERS THEN
               ROLLBACK;
               v_nErrorCode  := -20006;
               v_vchErrorMsg := 'SQLERRM = ' || SQLERRM;
               RAISE e_UnknownError;

END;