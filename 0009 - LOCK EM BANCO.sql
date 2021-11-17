--Transações ativas no banco de dados
SELECT   tran.start_time "Data/Hora inicio transação",
sess.logon_time "Data/Hora de logon",
sess.sid ||', '|| sess.serial# "SID, SERIAL#",  
sess.username "Usuário",
sess.status "Status da sessão",
      sess.prev_exec_start "Data/Hora inicio do comando",
cmd.sql_text "Último comando executado"
FROM v$transaction tran, gv$session sess, v$sql cmd
WHERE sess.saddr = tran.ses_addr
AND sess.prev_child_number = cmd.child_number
AND sess.prev_sql_id = cmd.sql_id;

--Objetos que estão em lock
SELECT obj.object_name "Nome do objeto",
obj.object_type "Tipo do objeto",
sess.sid ||', '|| sess.serial# "SID, SERIAL#",  
sess.status "Status da sessão",
sess.username "Usuário no Banco",
sess.osuser "Usuário no S.O.",
sess.machine ||' - '|| sess.terminal "Maquina/Terminal" ,
sess.program "Programa"
FROM v$locked_object lobj , v$session sess, dba_objects obj
WHERE lobj.session_id = sess.sid
AND lobj.object_id = obj.object_id;

--Objetos/sessão que estão esperando outra sessão
select * from dba_waiters;

ALTER SYSTEM KILL SESSION '239, 13897';


-- Verificar transações que estão sendo "Canceladas"
-- undo_blocks_used - Compa se refere a quantidade de Blocos que está sendo desfeito
select t.INST_ID
          , s.sid
          , s.program
          , t.status as transaction_status
          , s.status as session_status
          , s.lockwait
          , s.pq_status
          , t.used_ublk as undo_blocks_used
          , decode(bitand(t.flag, 128), 0, 'NO', 'YES') rolling_back
  from
     gv$session s
      , gv$transaction t
  where s.taddr = t.addr
  and s.inst_id = t.inst_id
  and s.STATUS = 'KILLED'
  order by t.inst_id;
