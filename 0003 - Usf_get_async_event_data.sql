SELECT 
    usf_get_async_event_data(asy.event_id) host_id
    , asy.event_id
    , asy.date_added
    , asy.date_started
    , asy.date_finished
    , asy.alert_id
    , asy.procobject
    , asy.status
    , 'UPDATE ea_t_async_work_queue set status = ''NEW'', date_started = null, date_finished = null, retry_count = 0, priority = 10 where event_id= '||ASY.EVENT_ID||';'
FROM ea_t_async_work_queue asy
where 1=1
and asy.date_added >= trunc(SYSDATE)-2
and usf_get_async_event_data(asy.event_id) in ('9E12AD4021TIM9EBE053B10C140A9618');


SELECT 
	ASY.*
FROM ea_t_async_work_queue asy
where 1=1
--and asy.date_added >= trunc(SYSDATE)-2
and usf_get_async_event_data(asy.event_id) in ('_HOST_GROUP_');