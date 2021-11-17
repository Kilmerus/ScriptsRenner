SET SERVEROUTPUT ON
DECLARE

CURSOR c_main IS
    select distinct pkd.work_q_id as WK_ID, pkd.wh_id , pkd.order_number, pkd.wave_id, pkd.status, pkd.lot_number,wkq.work_q_id,wkq.work_status,pkd.pick_area,pkd.pendency
        from t_pick_detail pkd
        inner join t_work_q wkq on wkq.work_q_id = pkd.work_q_id
        where pkd.work_type is null
        and wkq.work_status <> 'C'
        and pkd.status <> 'RELEASED'
        and pkd.wh_id = '499'
        --and pkd.pick_area in ('ALL','CAL')
        and not exists (select 1 from t_pick_detail PKD2
                      where PKD2.WORK_Q_ID = WKQ.WORK_Q_ID
                      and PKD2.wh_id = WKQ.wh_id
                      and PKD2.status = 'RELEASED')
        and not exists (select 1 from t_work_q_assignment wka1
                      where pkd.WORK_Q_ID = wka1.WORK_Q_ID
                      and pkd.wh_id = wka1.wh_id)
        and exists (select 1 from t_al_host_shipment_master spm
                   inner join t_al_host_shipment_detail spd on spd.shipment_id = spm.shipment_id
                   where spm.transaction_code in ('360','361')
                   and spm.order_number = pkd.order_number
                   and spd.item_number = pkd.item_number)
    AND ROWNUM <= 3000;
rec_main c_main%ROWTYPE;


    -- Error handling variables
    c_vchObjName  VARCHAR2(30 CHAR); -- The name that uniquely tags this object.
    v_vchErrorMsg VARCHAR2(2000 CHAR);
    v_nErrorCode  NUMBER;
    
    -- Exceptions
    e_KnownError   EXCEPTION;
    e_UnknownError EXCEPTION;

BEGIN

    FOR rec_main IN c_main	LOOP
    
        IF c_main%NOTFOUND Then
            EXIT;
        END IF;
    
      
      UPDATE t_work_q set work_status = 'C' where work_q_id = rec_main.WK_ID
      AND wh_id=  '499'
      and work_status <> 'C';
      
            
    -- RASTREABILIDADE
    INSERT INTO T_TRAN_LOG_HOLDING(TRAN_LOG_HOLDING_ID, TRAN_TYPE, DESCRIPTION, START_TRAN_DATE, START_TRAN_TIME, EMPLOYEE_ID, WH_ID, CONTROL_NUMBER, CONTROL_NUMBER_2, LOT_NUMBER, LOCATION_ID, LOCATION_ID_2)
    VALUES(NULL, '015', 'Fechamento de tarefa', SYSDATE, SYSDATE, 'HJS', REC_MAIN.WH_ID, rec_main.order_number, rec_main.wave_id , rec_main.lot_number, REC_MAIN.WK_ID, rec_main.PICK_AREA);  
        
    END LOOP;

COMMIT;

 EXCEPTION -- Exceção do Laço (For)
          WHEN OTHERS THEN
               ROLLBACK;
               v_nErrorCode  := -20006;
               v_vchErrorMsg := 'SQLERRM = ' || SQLERRM;
               RAISE e_UnknownError;

END;