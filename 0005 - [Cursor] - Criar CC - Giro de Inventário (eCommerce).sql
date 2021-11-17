/*
Criar Tarefa de contagem Cíclica- Giro de inventário
*/

SET SERVEROUTPUT ON
DECLARE

CURSOR c_main IS
    select loc.location_id, loc.wh_id from t_location loc 
    where loc.location_id like 'BIN.42%' 
    ---and rownum <= 300
    and loc.status <> 'I'
    and loc.type IN ('M', 'I')
    AND NOT EXISTS (SELECT 1 FROM t_work_q
                        WHERE wh_id = loc.wh_id
                        AND location_id = loc.location_id
                        AND work_type = '08'
                        AND work_status IN ('A', 'U'));
    --and loc.location_id = 'BIN.42.I.21.03';
rec_main c_main%ROWTYPE;


     -- Error handling variables
     c_vchObjName   VARCHAR2(30 CHAR); -- The name that uniquely tags this object.
     v_vchErrorMsg  VARCHAR2(2000 CHAR);
     v_nErrorCode   NUMBER;
     v_nCount       NUMBER;
     -- Exceptions
     e_KnownError   EXCEPTION;
     e_UnknownError EXCEPTION;
     
     --
     v_nPriority    NUMBER := 70;


BEGIN
	FOR rec_main IN c_main	LOOP
	
	IF c_main%NOTFOUND Then
      EXIT;
	END IF;
    
    
    BEGIN
        -- INSERÇÃO
        INSERT INTO t_work_q (work_q_id, work_type, description, pick_ref_number, priority, date_due, time_due, wh_id, location_id, work_status, workers_required, datetime_stamp)
        SELECT dbo.usf_get_next_work_q_id, '08', 'Cycle Count', 'CYCLIC', v_nPriority, SYSDATE, SYSDATE, wh_id, location_id, 'U', 1, SYSDATE
        FROM t_location loc
        WHERE wh_id = rec_main.wh_id
        AND status <> 'I'
        AND type IN ('M', 'I')
        AND location_id = rec_main.location_id
        AND NOT EXISTS (SELECT 1 FROM t_work_q
                        WHERE wh_id = loc.wh_id
                        AND location_id = loc.location_id
                        AND work_type = '08'
                        AND work_status IN ('A', 'U'));

    EXCEPTION
      WHEN OTHERS THEN
        ROLLBACK;
        v_vchErrorMsg := 'Erro ao gerar (Inserir) tarefas de contagem';
       
    END;
    
    
    
    -- Insere na tabela de controle de inventáírio cíclico
    BEGIN

        INSERT INTO t_cyclic_inventory (wh_id, cyclic_inventory, work_q_id, status)
        SELECT wkq.wh_id, TO_CHAR(SYSDATE, 'DDMMYYYY'), wkq.work_q_id, 'O'
        FROM t_work_q wkq
        INNER JOIN t_location loc
           ON loc.wh_id = wkq.wh_id
          AND loc.location_id = wkq.location_id
        WHERE wkq.wh_id = rec_main.wh_id
        AND wkq.work_type = '08'
        AND wkq.work_status IN ('A', 'U')
        AND loc.status <> 'I'
        AND loc.type IN ('M', 'I')
        AND loc.location_id = rec_main.location_id;

    EXCEPTION
      WHEN OTHERS THEN
        ROLLBACK;
        v_vchErrorMsg := 'Erro ao gravar tarefas na tabela de controle de inventáírio';
       
    END;
    
    -- GERAR LOG
    
    -- Insere transação de abertura de inventário cíclico
    BEGIN

        INSERT INTO t_tran_log_holding (
             tran_type
            ,description
            ,start_tran_date
            ,start_tran_time
            ,end_tran_date
            ,end_tran_time
            ,wh_id
            ,employee_id
            ,control_number
            ,control_number_2)
         VALUES (
             '790'
            ,'Abertura de Inventáírio Cíclico'
            ,TRUNC(SYSDATE)
            ,SYSDATE
            ,TRUNC(SYSDATE)
            ,SYSDATE
            ,rec_main.wh_id
            ,'HJS'
            ,TO_CHAR(SYSDATE, 'DDMMYYYY')
            ,'Chamado: 1505137');

    EXCEPTION
      WHEN OTHERS THEN
        ROLLBACK;
        v_vchErrorMsg := 'Erro ao gravar transa¿º¿úo de abertura de invent¿írio';
        
    END;
   
							
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