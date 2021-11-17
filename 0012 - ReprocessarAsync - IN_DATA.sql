UPDATE  ea_t_async_work_queue 
set status = 'TEMP_STATUS'
, date_started = SYSDATE
where procobject = 'WABACKGROUND.Msg>App Webservice In Data'
and status = 'NEW'
and date_started is null
and rownum <= 3000;

select '"%HJSBIN%ADV\Bin\RunProcessObject.exe" "WABACKGROUND.Msg>App Webservice In Data" "ea_SCEvent_Data" "'||'GUID|'||usf_get_async_event_data(asy.event_id)||'"'
from ea_t_async_work_queue asy
where 1=1
and procobject = 'WABACKGROUND.Msg>App Webservice In Data'
and status = 'TEMP_STATUS';

UPDATE ea_t_async_work_queue
set status = 'SUCCESS'
, date_finished = SYSDATE
, alert_id = 100
WHERE STATUS = 'TEMP_STATUS';


SELECT eve.scevent_name
    , ASY.status
    , COUNT(*)
FROM DBO.ea_t_async_work_queue ASY
  INNER JOIN DBO.ea_t_scevent eve
    ON asy.scevent_id = eve.scevent_id
WHERE ASY.date_added >= trunc(SYSDATE)-2
AND	ASY.STATUS = 'NEW'
GROUP BY eve.SCEVENT_NAME, ASY.status;