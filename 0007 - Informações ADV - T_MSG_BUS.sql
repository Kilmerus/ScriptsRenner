-- SQL Server
SELECT 
	(SELECT name FROM t_application WHERE application_id = mb.pub_application_id) AS PUB_APPLI,
	mdm.name AS mensagem,
	sub.business_obj_name as PROCESSO,
	(SELECT distinct name FROM t_application WHERE application_id = mb.sub_application_id) as  SUB_APPLI,
	typ.name  ,
	(SELECT network_name FROM t_server WHERE server_id = mb.pub_server_id) AS pub_server_name,
	(SELECT network_name FROM t_server WHERE server_id = mb.sub_server_id) AS sub_server_name,
	mb.message
FROM	t_msg_bus mb, 
	t_msg_def_detail mdd,
	t_msg_def_master mdm,
	t_msg_bus_type typ,
	t_msg_sub sub
WHERE 	mb.msg_def_detail_id = mdd.msg_def_detail_id
AND	mdd.msg_def_master_id = mdm.msg_def_master_id
AND	status_id = 2
and mb.date_published >= GETDATE()-1
AND  mb.type_id = typ.type_id
AND mb.msg_def_detail_id = sub.msg_def_detail_id
AND  mb.msg_def_detail_id = mdd.msg_def_detail_id
--AND	 mdd.msg_def_detail_id = mdm.msg_def_master_id
and typ.name = 'Republish'
order by mb.date_published desc;