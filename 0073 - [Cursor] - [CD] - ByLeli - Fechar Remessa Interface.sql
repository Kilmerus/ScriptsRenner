/*
######### SCRIPT FECHAR OE 1763 - Remessa Transf CD
######### Criado por Wellington Teske
######### Data: 09/10/2020

*/
set serveroutput on
declare

v_host varchar2(50);
v_val varchar2(500);

cursor cPo is select *
            from T_PO_MASTER
            where PO_NUMBER in ('15215697')
            and WH_ID = '464'
AND type_id = '1763'
            and STATUS = 'C';
begin
for c1 in cPo loop
   
  SELECT SYS_GUID() into v_host FROM DUAL;
 
 INSERT INTO t_al_host_receipt
(
    host_group_id,
transaction_code,
user_id,
vendor_code,
po_number,
item_number,
line_number,
qty_received,
hu_id,
wh_id,
display_po_number,
scac_code,
status,
client_code
)

SELECT
       v_host,
       '158',
       'HJS_WSUP',
       pm.VENDOR_CODE
       ,pm.po_number po_number
      ,to_char(sk.item) item_number
      ,rownum line_number
     ,sum(qty_expected) QTY_RECEIVED
      ,sk.carton hu_id
     ,pm.wh_id wh_id
     ,pm.display_po_number display_po_number
     ,sk.distro_type||'-'||sk.distro_no
   ,(select distinct contexto from (
       select
                  case when nvl(asn.context,'X') in ('DEVTRI','ACORDO','SINFIS','BUFFER','TSFCST','TSFDOA') then 'TRBL'
                       when asn.context = 'BUFFER' then 'TRBL'
                       else 'ATS' end contexto
       from t_al_host_transfer_asn asn
       where asn.hu_id = sk.carton)) as status  
   --,'ATS' Status -- ATS ou TRBL, depende do context do LPN
   ,pm.CLIENT_CODE
from t_po_master pm
   inner join shipment@consulta_rms sh on sh.bol_no              = pm.display_po_number
   and sh.to_loc          = pm.wh_id
   and pm.type_id         = '1763'
   inner join shipsku@consulta_rms sk on
   sh.shipment            = sk.shipment
where pm.po_number = c1.po_number
      and pm.wh_id = c1.wh_id
group by pm.vendor_code
     ,pm.wh_id
     ,pm.po_number
     ,to_char(sk.item)
     ,rownum
     ,pm.display_po_number
     ,sk.carton
     ,pm.status
     ,sk.distro_type||'-'||sk.distro_no
     ,pm.client_code;
 
  commit;
 
  SELECT PKG_WEBSERVICES.USF_CALL_WEBSERVICE('EXP_RECEB', v_host) into v_val FROM dual;
 
end loop;      
End;  