SELECT
    MAX(msgm.NAME)
    ,priority
    , COUNT(*)
FROM T_MSG_BUS@adv  msg
inner join T_MSG_DEF_DETAIL@adv msgd 
  on msg.MSG_DEF_DETAIL_ID = msgd.MSG_DEF_DETAIL_ID
INNER   JOIN T_MSG_DEF_MASTER@adv msgm 
  ON msgm.MSG_DEF_MASTER_ID = msgd.MSG_DEF_MASTER_ID
WHERE msg.STATUS_ID = 1
AND (msg.sub_APPLICATION_ID <> '5227C276-EF84-4E9A-AE23-6E991896737C' 
OR msg.sub_APPLICATION_ID is null)
AND msgm.name <> 'Schedule Message'
GROUP BY msg.MSG_DEF_DETAIL_ID, priority;