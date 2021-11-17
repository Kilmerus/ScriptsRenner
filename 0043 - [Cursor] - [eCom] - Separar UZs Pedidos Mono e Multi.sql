SET SERVEROUTPUT ON
DECLARE

/*  - SEGREGAR PEDIDOS MONO E MULTI DA UZ
    - Gustavo Félix 30/05
*/

    v_vchHU_ID          VARCHAR2(50 CHAR);
    v_vchNOVO_HU_ID     VARCHAR2(50 CHAR):= '_INFORMAR_A_UZ_NOVA_';

CURSOR c_main IS
    SELECT 
        order_number
        , item_number
        , location_id
        , hu_id
        , wh_id
        , wave_id
        , pick_id
        , ITMS
    FROM (
        SELECT 
            pkd.order_number
            , sto.item_number
            , sto.location_id
            , sto.hu_id
            , pkd.wh_id
            , pkd.status
            , pkd.pick_id
            , pkd.wave_id
            , (select count(distinct item_number) from t_order_detail ord
                where ord.order_number = pkd.order_number
                and ord.wh_id = pkd.wh_id) as ITMS
        from t_stored_item sto
            inner join t_pick_detail PKD
                on sto.type = pkd.pick_id
        where hu_id = 'UZCNT06464'
        --and sto.item_number = '549293015'
        )
    WHERE ITMS > 1;
rec_main c_main%ROWTYPE;


    -- Error handling variables
    c_vchObjName  VARCHAR2(30 CHAR); -- The name that uniquely tags this object.
    v_vchErrorMsg VARCHAR2(2000 CHAR);
    v_nErrorCode  NUMBER;
    
    -- Exceptions
    e_KnownError   EXCEPTION;
    e_UnknownError EXCEPTION;
    
    -- Variáveis
    v_vchSourceHUID     VARCHAR2(100 CHAR);
    v_numSTO_qty        NUMBER;
    v_numCount          NUMBER:= 0;

BEGIN

    FOR rec_main IN c_main	LOOP
    
        IF c_main%NOTFOUND Then
            EXIT;
        END IF;
        
       SELECT COUNT(*) INTO  v_numCount
       FROM t_hu_master where hu_id = v_vchNOVO_HU_ID
       AND wh_id = rec_main.wh_id;
       
       IF v_numCount = 0 THEN
       
            Insert into T_HU_MASTER (HU_ID,TYPE,CONTROL_NUMBER,LOCATION_ID,SUBTYPE,STATUS,FIFO_DATE,WH_ID,LOAD_POSITION,HAZ_MATERIAL,LOAD_ID,LOAD_SEQ,VER_FLAG,ZONE,RESERVED_FOR,CONTAINER_TYPE,STOP_ID,PARENT_HU_ID,USER_ID) 
            values (v_vchNOVO_HU_ID,'SO',null,rec_main.location_id,null,'A',SYSDATE,rec_main.wh_id,0,null,rec_main.order_number,0,null,null,null,null,null,null,null);
            
            UPDATE t_stored_item set hu_id = v_vchNOVO_HU_ID
            WHERE hu_id         = rec_main.hu_id
            AND item_number     = rec_main.item_number
            AND wh_id           = rec_main.wh_id
            AND type            = rec_main.pick_id
            and location_id     = rec_main.location_id;
            
            -- RASTREABILIDADE
            insert into t_tran_log_holding(tran_log_holding_id, tran_type, description, start_tran_date, start_tran_time, employee_id, control_number, hu_id, hu_id_2, location_id, control_number_2, item_number)
            values(null, '090', 'Segregar UZs, Mono e Multi', sysdate, sysdate, 'HJS', rec_main.order_number, rec_main.hu_id, v_vchNOVO_HU_ID, rec_main.location_id, rec_main.wave_id, rec_main.item_number);  
       
       ELSE
       
            UPDATE t_stored_item set hu_id = v_vchNOVO_HU_ID
            WHERE hu_id         = rec_main.hu_id
            AND item_number     = rec_main.item_number
            AND wh_id           = rec_main.wh_id
            AND type            = rec_main.pick_id
            and location_id     = rec_main.location_id;
            
            -- RASTREABILIDADE
            insert into t_tran_log_holding(tran_log_holding_id, tran_type, description, start_tran_date, start_tran_time, employee_id, control_number, hu_id, hu_id_2, location_id, control_number_2, item_number)
            values(null, '090', 'Segregar UZs, Mono e Multi', sysdate, sysdate, 'HJS', rec_main.order_number, rec_main.hu_id, v_vchNOVO_HU_ID, rec_main.location_id, rec_main.wave_id, rec_main.item_number);     
       
       END IF;
                    
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