SELECT 
    eve.scevent_name
    , ASY.status
    , COUNT(*)
FROM DBO.ea_t_async_work_queue ASY
  INNER JOIN DBO.ea_t_scevent eve
    ON asy.scevent_id = eve.scevent_id
WHERE ASY.date_added >= trunc(SYSDATE)
AND	ASY.STATUS = 'NEW'
GROUP BY eve.SCEVENT_NAME, ASY.status;

