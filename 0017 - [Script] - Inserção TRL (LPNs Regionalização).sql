INSERT INTO T_TRAN_LOG_HOLDING 
(TRAN_TYPE, description, start_tran_date, start_tran_time, end_tran_date, end_tran_time
, employee_id, control_number, control_number_2, tran_qty, hu_id, item_number, location_id, line_number, wh_id, outside_id)
SELECT 
    '999'
    , 'LPNs de Regionalização com geração de Etiquetas'
    , SYSDATE
    , SYSDATE
    , SYSDATE
    , SYSDATE
    , 'HJ'
    , hum.parent_hu_id
    , pom.po_number
    , sto.actual_qty
    , hum.hu_id
    , sto.item_number
    , sto.location_id
    , hum.control_number
    , hum.wh_id
    , sto.serial_number
from t_hu_master hum
    inner join t_stored_item sto
        on hum.hu_id = sto.hu_id
        and hum.wh_id = sto.wh_id
    inner join t_po_master pom
        on  hum.parent_hu_id = pom.display_po_number
        and hum.wh_id = pom.wh_id
        and pom.type_id = '1762' -- Importado
        and exists (select 1 from t_whse whs
                    where hum.control_number = whs.wh_id)
WHERE hum.location_id = 'PRE_RECE_TRANSF';


DELETE from t_stored_item where hu_id in (
    select hu_id from t_hu_master hum 
    inner join t_po_master pom
            on  hum.parent_hu_id = pom.display_po_number
            and hum.wh_id = pom.wh_id
            and pom.type_id = '1762' -- Importado
    where exists (select 1 from t_whse whs
                        where hum.control_number = whs.wh_id)
    and hum.location_id = 'PRE_RECE_TRANSF')
and location_id = 'PRE_RECE_TRANSF';

DELETE from t_hu_master where hu_id in (
select HU_ID from t_hu_master hum 
inner join t_po_master pom
        on  hum.parent_hu_id = pom.display_po_number
        and hum.wh_id = pom.wh_id
        and pom.type_id = '1762' -- Importado
where exists (select 1 from t_whse whs
                    where hum.control_number = whs.wh_id)
                    and hum.location_id = 'PRE_RECE_TRANSF')
and location_id = 'PRE_RECE_TRANSF';