DECLARE
 v_Grupo           t_arch_group.group_id%type;
 v_Query           varchar(5000);
 v_Procedure       varchar(100);
 v_TableName       t_arch_backup_control.table_name%type;
 v_TableID         t_arch_backup_control.id%type;
CURSOR CURSOR_1 IS
 SELECT group_id 
 FROM t_arch_group
 WHERE group_status = 'A'
 AND group_id = '81'; 
CURSOR CURSOR_2 IS
 SELECT control_type as procedure_name, c.table_name,  c.id as table_id
 FROM t_arch_backup_control c, t_arch_backup_control_group b
 WHERE b.backup_control_id = c.id
 AND b.group_id = v_Grupo
 ORDER BY b.group_id, b.group_sequence;
BEGIN
FOR umGrupo in CURSOR_1 LOOP
 v_Grupo := umGrupo.group_id;
 FOR umaTabela IN CURSOR_2 LOOP
     v_Procedure := 'PKG_MAIN_ARCHIVING.USP_ARCH_PROCESS_CTYPE_' || umaTabela.procedure_name;
     v_TableName := umaTabela.table_name;
     v_TableID := umaTabela.table_id;
     v_Query := 'BEGIN ' || v_Procedure || ' (:0,:1); END;';
     EXECUTE IMMEDIATE v_Query USING  v_TableName, v_TableID;
 -- Gera retorno
 v_Query := v_Query || ' ' || v_TableName || ' ' || v_TableID;
 DBMS_OUTPUT.PUT_LINE(v_Query);
     v_Query := 'UPDATE t_arch_backup_control SET last_processed_date = SYSDATE WHERE id = :0';
     EXECUTE IMMEDIATE v_Query USING v_TableID;
 -- Gera retorno
 v_Query := v_Query || ' ' || v_TableID;
 DBMS_OUTPUT.PUT_LINE(v_Query);
 END LOOP;
END LOOP;
COMMIT;
END;



DROP TABLE ARCH.HT_NF_LOG; 
DROP PUBLIC SYNONYM HT_NF_LOG; 


select * from all_objects where object_name like '%T_NF_LOG%';
select * from DBO.t_arch_created_hist_table where table_name = 'T_NF_LOG';
DELETE from DBO.t_arch_created_hist_table where table_name = 'T_NF_LOG';
select * from DBO.t_arch_backup_control where table_name = 'T_NF_LOG';
DELETE from DBO.t_arch_backup_control where table_name = 'T_NF_LOG';


DECLARE
  VTABLE VARCHAR2(50);
  VID NUMBER;
BEGIN
  VTABLE := 'T_NF_LOG';
  VID := 76;

  DBO.PKG_CREATE_HISTORY_TABLES.USP_ARCH_PROCESS_CTYPE_CT(
    VTABLE => VTABLE,
    VID => VID
  );
--rollback; 
END;


