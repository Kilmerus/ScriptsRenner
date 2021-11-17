SET SERVEROUTPUT ON
DECLARE
/**************************************************************************************
-- Correção de contorno - Agrupamento de Estoque em Sinistros
-- 
**************************************************************************************/
CURSOR c_main IS
 SELECT 
    sto.hu_id
    , sto.wh_id
    , sto.item_number
    , hum.parent_hu_id
    , sto.location_id
    , hum.ZONE
    , SUM(sto.actual_qty) as qty
FROM t_stored_item sto
INNER JOIN t_hu_master hum
    ON sto.hu_id = hum.hu_id
    AND sto.wh_id = hum.wh_id
WHERE sto.location_id = 'SINISTROS'
AND sto.hu_id IS NOT NULL
and ROWNUM <= 2000
GROUP BY sto.hu_id, sto.item_number
, hum.parent_hu_id
, sto.wh_id
, sto.location_id
, hum.ZONE;

rec_main c_main%ROWTYPE;

     -- Default
     v_vchErrorMsg  VARCHAR2(2000 CHAR);
     v_nErrorCode   NUMBER;
     v_nCount       NUMBER;
     v_nSUM         NUMBER;
     
     e_UnknownError EXCEPTION;
     
     v_vchType  VARCHAR2(20 CHAR);
     
     
BEGIN

    FOR rec_main IN c_main	LOOP
    
        IF c_main%notfound THEN
            EXIT;
        END IF;
        
 
        -- Verifica se o Item existe no endereço de destino
        SELECT COUNT(*) INTO v_nCount 
        FROM t_stored_item
            WHERE item_number   = rec_main.item_number
            AND wh_id           = rec_main.wh_id
            AND location_id     = rec_main.location_id
            AND hu_id           is null
            AND type            = 'STORAGE';
        
        IF v_nCount > 0 THEN
        
            -- ATUALIZA
            UPDATE t_stored_item set actual_qty = actual_qty + rec_main.qty
                WHERE item_number       = rec_main.item_number
                and wh_id               = rec_main.wh_id
                and location_id         = rec_main.location_id
                AND type                = 'STORAGE'
                AND hu_id               is NULL;
        
            -- DECREMENTA do LPN
            UPDATE t_stored_item set actual_qty = actual_qty - rec_main.qty
            WHERE item_number   = rec_main.item_number
            and wh_id           = rec_main.wh_id
            and location_id     = rec_main.location_id
            and hu_id           = rec_main.hu_id;
        
            -- Verifica se há estoque no LPN
            SELECT SUM(actual_qty) INTO v_nsum
            FROM t_stored_item
                WHERE hu_id     = rec_main.hu_id
                AND wh_id       = rec_main.wh_id
                AND location_id = rec_main.location_id;
            
            IF v_nsum = 0 THEN        
                DELETE t_stored_item    where hu_id = rec_main.hu_id and wh_id = rec_main.wh_id;     
                DELETE t_hu_master      where hu_id = rec_main.hu_id and wh_id = rec_main.wh_id;                   
            END IF;
            
        ELSE
            -- INSERE 
            INSERT INTO t_stored_item (SEQUENCE,item_number,actual_qty,unavailable_qty,status,wh_id,location_id,fifo_date,expiration_date,reserved_for,lot_number,inspection_code,serial_number,TYPE,put_away_location,stored_attribute_id,hu_id) 
            VALUES ('0',rec_main.item_number,rec_main.qty,'0','A',rec_main.wh_id,rec_main.location_id,sysdate,sysdate,NULL,NULL,NULL,NULL,'STORAGE',NULL,NULL,NULL);
            
            -- DECREMENTA
            UPDATE t_stored_item set actual_qty = actual_qty - rec_main.qty
            WHERE item_number   = rec_main.item_number
            and wh_id           = rec_main.wh_id
            and location_id     = rec_main.location_id
            and hu_id           = rec_main.hu_id;  
            
            -- Verifica se há estoque no LPN
            SELECT SUM(actual_qty) INTO v_nsum
            FROM t_stored_item
                WHERE hu_id     = rec_main.hu_id
                AND wh_id       = rec_main.wh_id
                AND location_id = rec_main.location_id;
            
            IF v_nsum = 0 THEN        
                DELETE t_stored_item    where hu_id = rec_main.hu_id and wh_id = rec_main.wh_id;   
                DELETE t_hu_master      where hu_id = rec_main.hu_id and wh_id = rec_main.wh_id;                     
            END IF;
            
        END IF;
 
 
        INSERT INTO t_tran_log_holding(
                              tran_type
                              , DESCRIPTION
                              , start_tran_date
                              , start_tran_time
                              , end_tran_date
                              , end_tran_time
                              , employee_id
                              , line_number
                              , control_number
                              , control_number_2
                              , wh_id
                              , hu_id
                              , location_id
                              , location_id_2
                              , num_items
                              , item_number
                              , tran_qty
                              
                        ) VALUES (
                               '999'
                              , 'Agrupamento de estoque'
                              , TRUNC(sysdate)
                              , TO_DATE(to_char(TRUNC(sysdate, 'MM'), 'DD/MM/YYYY')||' '||to_char(sysdate,'HH24:MI:SS'), 'DD/MM/YYYY HH24:MI:SS') --START_TRAN_TIME
                              , TRUNC(sysdate)--TO_DATE('01/01/1900','MM/DD/YYYY')END_TRAN_DATE
                              , TO_DATE(to_char(TRUNC(sysdate, 'MM'), 'DD/MM/YYYY')||' '||to_char(sysdate,'HH24:MI:SS'), 'DD/MM/YYYY HH24:MI:SS') --END_TRAN_TIME
                              , 'HJS'        
                              , ''
                              , rec_main.parent_hu_id                
                              , rec_main.zone                
                              , rec_main.wh_id
                              , rec_main.hu_id
                              , rec_main.location_id
                              , rec_main.location_id                
                              , ''--rec_main.contador
                              , rec_main.item_number   
                              , rec_main.qty        
                              
                          );
    END LOOP;
  
  COMMIT;
  

 EXCEPTION 
          WHEN OTHERS THEN
               ROLLBACK;
               v_nErrorCode  := -20006;
               v_vchErrorMsg := 'SQLERRM = ' || SQLERRM;
               RAISE e_UnknownError;

END;
