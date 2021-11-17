SELECT 
    procobject
    , semana
    , SUM(HR_FIN_ADD+MI_FIN_ADD+SE_FIN_ADD) as SEGUNDOS_ADD_FIM
    , ROUND(SUM(HR_FIN_ADD+MI_FIN_ADD+SE_FIN_ADD)/COUNT(*)) as MEDIA_ADD
    , SUM(HR_FIN_STAR+MI_FIN_STAR+SE_FIN_STAR) as SEGUNDOS_START_FIM
    , ROUND(SUM(HR_FIN_STAR+MI_FIN_STAR+SE_FIN_STAR)/COUNT(*)) as MEDIA_START
    , COUNT(*)
FROM (
SELECT
    procobject
    , date_added
    , date_started
    , date_finished
    , SUBSTR(TO_CHAR(TO_TIMESTAMP (date_finished, 'dd/mm/yy hh24:mi:ss')-TO_TIMESTAMP (date_added, 'dd/mm/yy hh24:mi:ss')),12,9)   AS FIN_ADD
    , (TO_NUMBER(SUBSTR(TO_CHAR(SUBSTR(TO_CHAR(TO_TIMESTAMP (date_finished, 'dd/mm/yy hh24:mi:ss')-TO_TIMESTAMP (date_added, 'dd/mm/yy hh24:mi:ss')),12,9)),0,2))*60)*60 HR_FIN_ADD
    , TO_NUMBER(SUBSTR(TO_CHAR(SUBSTR(TO_CHAR(TO_TIMESTAMP (date_finished, 'dd/mm/yy hh24:mi:ss')-TO_TIMESTAMP (date_added, 'dd/mm/yy hh24:mi:ss')),12,9)),4,2))*60 MI_FIN_ADD
    , TO_NUMBER(SUBSTR(TO_CHAR(SUBSTR(TO_CHAR(TO_TIMESTAMP (date_finished, 'dd/mm/yy hh24:mi:ss')-TO_TIMESTAMP (date_added, 'dd/mm/yy hh24:mi:ss')),12,9)),7,2)) SE_FIN_ADD
    --
    , SUBSTR(TO_CHAR(TO_TIMESTAMP (date_finished, 'dd/mm/yy hh24:mi:ss')-TO_TIMESTAMP (date_started, 'dd/mm/yy hh24:mi:ss')),12,9)   AS FIN_STAR
    , (TO_NUMBER(SUBSTR(TO_CHAR(SUBSTR(TO_CHAR(TO_TIMESTAMP (date_finished, 'dd/mm/yy hh24:mi:ss')-TO_TIMESTAMP (date_started, 'dd/mm/yy hh24:mi:ss')),12,9)),0,2))*60)*60 HR_FIN_STAR
    , TO_NUMBER(SUBSTR(TO_CHAR(SUBSTR(TO_CHAR(TO_TIMESTAMP (date_finished, 'dd/mm/yy hh24:mi:ss')-TO_TIMESTAMP (date_started, 'dd/mm/yy hh24:mi:ss')),12,9)),4,2))*60 MI_FIN_STAR
    , TO_NUMBER(SUBSTR(TO_CHAR(SUBSTR(TO_CHAR(TO_TIMESTAMP (date_finished, 'dd/mm/yy hh24:mi:ss')-TO_TIMESTAMP (date_started, 'dd/mm/yy hh24:mi:ss')),12,9)),7,2)) SE_FIN_STAR
    , TO_CHAR(date_added,'IW') as SEMANA
from DBO.ea_t_async_work_queue
where date_added between '01/01/2020 00:00:00' and '29/02/2020 23:59:59'
and date_started > date_added
and date_finished > date_added
and date_finished > date_started
)
GROUP BY procobject, semana
--GROUP BY procobject
ORDER BY procobject, semana
;
