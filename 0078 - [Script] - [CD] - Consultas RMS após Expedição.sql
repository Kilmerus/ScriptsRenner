-- Tabela intermediária antes da integração com o RMS
select from_location, to_location, asn_nbr , source 
from fm_stg_asnout_desc 
where  asn_nbr IN  ('03240000587060064');


-- Caso tenha dado erro e esteja no Hospital
select * from rib_message_failure 
	where message_num in(
							select message_num from rib_message 
								where family in ('ASNOut','ShipInfo','stockorder','SOStatus')
	--and publish_time >= '16/08/2016'
	and message_data like '%03240000683290064%') --ASN