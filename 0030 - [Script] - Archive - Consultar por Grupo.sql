SELECT * 
FROM (
    select 
         grp.group_id
        , grp.name              AS  GRUPO
        , bcon.table_name       AS  TABELA
        , bcon.control_type     AS  TIPO
        , bgrp.group_sequence   AS  SEQUENCE
        , CASE  WHEN grp.group_status = 'A' THEN 'Grupo Ativo'
                WHEN grp.group_status = 'I' THEN '** Grupo Inativo'
                ELSE grp.group_status  END  STATUS_DO_GP
        , bcon.last_processed_date  AS  ULT_EXCE
        , bcon.elapsed_time     AS  TIME_EXEC
        , (select num_rows from all_tables where  table_name = bcon.table_name) registros
        , (select all_tables.LAST_ANALYZED from all_tables where  table_name = bcon.table_name) LAST_ANALYZED
        , CASE WHEN sche.name IS NULL THEN '** Sem programação'
          ELSE sche.name END  SCHEDULE
        , MAX(schd.start_time)  AS  START_TIME
        , (select date_activated from t_msg_bus@ADV where msg_bus_id =  sche.message_id) PROX_EXEC
        , CASE WHEN bcon.status = 'F' THEN 'FAILURE'
            ELSE 'SUCCESS' END STATUS_EXEC
    from t_arch_group grp
        left join t_arch_backup_control_group bgrp
            on bgrp.group_id = grp.group_id
        right join DBO.t_arch_backup_control bcon
            on bcon.id = bgrp.backup_control_id
        left join t_arch_group_schedule sch
            on  grp.group_id = sch.group_id
        left join t_arch_schedule sche
            on sch.schedule_id = sche.schedule_id
        left join t_arch_schedule_detail schd
            on sche.schedule_id = schd.schedule_id
  --WHERE    grp.group_id = '241'         
    GROUP BY
    grp.group_id
        , grp.name        
        , bcon.table_name   
        , grp.group_status 
        , sche.name
        , bcon.status
        , bcon.last_processed_date
        , bgrp.group_sequence
        , sche.message_id
        , bcon.elapsed_time
        , bcon.control_type
        )
--WHERE GRUPO in ('GP - Alocação','GP - Alocação - AL Hosts')
--WHERE TABELA like '%T_AL_HOST_INVENTORY_ADJUSTMENT%'
ORDER BY ULT_EXCE desc, START_TIME, SEQUENCE;