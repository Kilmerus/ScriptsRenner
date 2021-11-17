SET SERVEROUTPUT ON
DECLARE

CURSOR c_main IS
	SELECT distinct
		a.order_number as pedido
		,A.wh_id
	FROM
		T_PICK_DETAIL A
		INNER JOIN
		T_ORDER B ON A.ORDER_NUMBER = B.ORDER_NUMBER
	WHERE
		TO_CHAR(B.ORDER_DATE,'DD/MM/YYYY') >= '14/01/2020' 
		AND A.WH_ID = '3018' 
		AND A.STATUS = 'RELEASED';
rec_main c_main%ROWTYPE;


     -- Error handling variables
     c_vchObjName  VARCHAR2(30 CHAR); -- The name that uniquely tags this object.
     v_vchErrorMsg VARCHAR2(2000 CHAR);
     v_nErrorCode  NUMBER;
     
	 v_nCount  			NUMBER:=0;
	 v_nShipment_id  	NUMBER;
	 
	 -- Exceptions
     e_KnownError   EXCEPTION;
     e_UnknownError EXCEPTION;


BEGIN
	FOR rec_main IN c_main	LOOP
	
	IF c_main%NOTFOUND Then
      EXIT;
	END IF;
	
	SELECT COUNT(*) INTO v_nCount
		FROM t_al_host_shipment_master
		WHERE order_number = rec_main.pedido
		AND WH_ID = rec_main.wh_id
		AND status = 'PARTIAL';
	
	IF v_nCount = 0 THEN	
			
		-- INSERIR A CAPA
		INSERT INTO t_al_host_shipment_master(
			shipment_id,                    
			host_group_id,
			transaction_code,
			order_number,
			status,
			user_id,
			wh_id,
			record_create_date,               
			br_processing_status
		)VALUES(
			null,
			'0',
			'301',
			rec_main.pedido,
			'PARTIAL',
			'HJS',
			rec_main.wh_id,
			sysdate,
			'00'
			);
			
	END IF;
	
	v_nShipment_id:= null;
	
	SELECT shipment_id into v_nShipment_id 
		FROM t_al_host_shipment_master 
		where order_number = rec_main.pedido 
		and wh_id = rec_main.wh_id 
		and status = 'PARTIAL';
					
	
	-- Após ter a capa/master para PARTIAL, inserir os detalhes
	IF v_nShipment_id is not null THEN
		-- INSERIR OS DETALHES
		INSERT INTO v_al_host_shipment_detail(
			shipment_detail_id,
			shipment_id,
			line_number,
			item_number,
			lot_number,
			quantity_shipped,
			hu_id,
			delivery_sap,
			user_id,
			wh_id,
			record_create_date,
			owner_id,
			uom,
			tracking_number,
			order_number,
			br_processing_status)
		SELECT
		   null 
		  , v_nShipment_id
		  , A.line_number
		  , A.item_number
		  , null 				--as  LOT_NUMBER
		  , 0 					--as qty
		  , null 				--as HU_ID
		  , null 				--as Delivery_SAP
		  , 'HJS' 				--as user_id
		  , A.wh_id
		  , SYSDATE
		  , null 				--as owner_id
		  , null 				--as UOM
		  , null 				--as tracking_number
		  , rec_main.pedido 	--as "rec_main.pedido"
		  , '00' 				--as processing_code
		FROM
			T_PICK_DETAIL A
			INNER JOIN
			T_ORDER B ON A.ORDER_NUMBER = B.ORDER_NUMBER
		WHERE
			TO_CHAR(B.ORDER_DATE,'DD/MM/YYYY') >= '14/01/2020' 
			AND A.WH_ID = rec_main.wh_id 
			AND A.STATUS = 'RELEASED'
			AND A.ORDER_NUMBER =  rec_main.pedido;
			
			-- BO QTY
			UPDATE t_order_detail set bo_qty = qty
				WHERE order_number = rec_main.pedido
				AND line_number in (select line_number from t_al_host_shipment_detail where order_number = rec_main.pedido and shipment_id = v_nShipment_id);
			
			-- STAGED
			UPDATE t_pick_detail set status = 'STAGED', lot_number = 'HJ' 
				WHERE order_number = rec_main.pedido and status = 'RELEASED' 			
				AND line_number in (select line_number from t_al_host_shipment_detail where order_number = rec_main.pedido and shipment_id = v_nShipment_id);

    END IF;			
   
   SELECT COUNT(*) INTO v_nCount
		FROM t_al_host_shipment_master
		WHERE order_number = rec_main.pedido
		AND WH_ID = rec_main.wh_id
		AND status = 'COMPLETE';
   
   IF v_nCount = 0 THEN
   
	   INSERT INTO t_al_host_shipment_master(
				shipment_id,                    
				host_group_id,
				transaction_code,
				order_number,
				status,
				user_id,
				wh_id,
				record_create_date,               
				br_processing_status
			)VALUES(
				null,
				'0',
				'302',
				rec_main.pedido,
				'COMPLETE',
				'HJS',
				rec_main.wh_id,
				sysdate,
				'00'
				);
   END IF;
  
	-- Concluir o pedido
	UPDATE t_order set status = 'D' 
		WHERE order_number = rec_main.pedido 
		and wh_id = rec_main.wh_id;
	
   dbms_output.put_line ('Pedidos Finalizados '||rec_main.pedido); 	  
   
  END LOOP;

COMMIT;


 EXCEPTION -- Exceção do Laço (For)
          WHEN OTHERS THEN
               ROLLBACK;
               v_nErrorCode  := -20006;
               v_vchErrorMsg := 'SQLERRM = ' || SQLERRM;
               RAISE e_UnknownError;

END;