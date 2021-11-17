DECLARE

    -- DECLARA AS VARIÁVEIS
    v_nCount                        INT := 0;
    v_return_fnc                    VARCHAR2(4000);
    v_nLogErrorNum                  int;

    e_KnownError                    EXCEPTION;
    e_UnknownError                  EXCEPTION;
    v_vchCode                       t_data_type.output_code%TYPE;
    v_vchMsg                        t_data_type.output_msg%TYPE;
    v_Tran_Type                     VARCHAR2(3);     

CURSOR C_STO_ITEMS IS
    SELECT 
              pod.PO_NUMBER       as  PO
              , pom.DISPLAY_PO_NUMBER as display
              , pom.wh_id         as  wh
              , pom.CLIENT_CODE   as  Client_Code
              , pod.ITEM_NUMBER   as  Item
              , SUM(pod.QTY)      as  Qty
              /* PEGA OS ENDEREÇOS QUE ESTIVEREM SETADOS NO PARÂMETRO*/
              /*SE FOR 1767 - LOC_RECEB_SI
                SE Não - IA 
              */
              , CASE WHEN pom.type_id = '1767' THEN (SELECT max(con.c1) FROM t_client_control con
                                                      WHERE con.wh_id = pom.wh_id
                                                      AND   con.CLIENT_CODE = pom.client_code
                                                      AND   con.CONTROL_TYPE = 'LOC_RECEB_SI')  else (SELECT max(con.c1) FROM t_client_control con
                                                                                                      WHERE con.wh_id = pom.wh_id
                                                                                                      AND   con.CLIENT_CODE = pom.client_code
                                                                                                      AND   con.CONTROL_TYPE = 'LOC_RECEB_IA') end Loc
              FROM t_po_master pom
                INNER JOIN t_po_detail pod    ON  pom.wh_id     = pod.wh_id
                                              AND pom.po_number = pod.po_number
                INNER JOIN t_lookup lkp       ON  pom.TYPE_ID   = lkp.LOOKUP_ID
                                              AND lkp.LOOKUP_TYPE = 'TYPE'
                                              AND lkp.LOCALE_ID = '1046'
                                              AND lkp.LOOKUP_ID in ('1767','1766')
                                              /*PEGA OS TIPOS SI E IA*/
              WHERE pom.wh_id = '324'
              /* APENAS O QUE ESTIVER ABERTO*/
              AND   pom.status = 'O'
              --AND   pom.po_number in ('00000P_SI','014819')
              AND   pom.CLIENT_CODE = '004'
              AND   pom.po_number in ('048147')
              GROUP BY 
                  pod.PO_NUMBER
                , pom.wh_id
                , pom.CLIENT_CODE
                , pod.ITEM_NUMBER
                , pom.type_id 
                , pom.DISPLAY_PO_NUMBER
              ORDER BY pod.po_number;
          

BEGIN

  FOR rec IN C_STO_ITEMS LOOP
		
            -- VALIDAR DE EXISTE ESTOQUE NO ENDEREÇO
            SELECT count(*) INTO v_nCount
            FROM t_stored_item
              WHERE item_number = rec.Item
              AND   wh_id = rec.wh
              AND   location_id = rec.Loc;
              
              IF v_nCount = 0 THEN
                 
                /*INSERE O ESTOQUE*/
                Insert into T_STORED_ITEM (SEQUENCE,ITEM_NUMBER,ACTUAL_QTY,UNAVAILABLE_QTY,STATUS,WH_ID,LOCATION_ID,FIFO_DATE,EXPIRATION_DATE,RESERVED_FOR,LOT_NUMBER,INSPECTION_CODE,SERIAL_NUMBER,TYPE,PUT_AWAY_LOCATION,STORED_ATTRIBUTE_ID,HU_ID) 
                values ('0',rec.Item, rec.Qty,'0','A',rec.WH,rec.Loc,sysdate,sysdate,null,null,null,null,'STORAGE',null,null,null);
                 
                  /*INCREMENTA O ESTOQUE NO ENDEREÇO*/
                  /*SE JÁ ESTIVER ESTOQUE DO ITEM/ENDEREÇO*/
                  ELSE                 
                        Update T_STORED_ITEM SET actual_qty = actual_qty + rec.qty
                                                , fifo_date = sysdate
                        WHERE item_number = rec.Item
                        AND   wh_id = rec.wh
                        AND   location_id = rec.Loc;
                      
                END IF;
              
              /*FECHA A PO*/  
              UPDATE t_po_master set status = 'C'
              WHERE po_number = rec.po
              AND   wh_id = rec.wh;
              
          
          v_Tran_Type := '854'; -- Criação de Estoque por Integração
          
          INSERT INTO t_tran_log_holding(
                                  TRAN_TYPE
                                  , DESCRIPTION
                                  , START_TRAN_DATE
                                  , START_TRAN_TIME
                                  , END_TRAN_DATE
                                  , END_TRAN_TIME
                                  , EMPLOYEE_ID
                                  , CONTROL_NUMBER
                                  , CONTROL_NUMBER_2
                                  , WH_ID
                                  , LOCATION_ID
                                  , NUM_ITEMS
                                  , ITEM_NUMBER
                                  , TRAN_QTY
                                  , LOCATION_ID_2
                            ) values (
                                    v_Tran_Type
                                  , (select description from t_transaction where tran_type = v_Tran_Type)
                                  , trunc(sysdate)
                                  , TO_DATE(TO_CHAR(TRUNC(sysdate, 'MM'), 'DD/MM/YYYY')||' '||TO_CHAR(sysdate,'HH24:MI:SS'), 'DD/MM/YYYY HH24:MI:SS') --START_TRAN_TIME
                                  , trunc(sysdate)--TO_DATE('01/01/1900','MM/DD/YYYY')END_TRAN_DATE
                                  , TO_DATE(TO_CHAR(TRUNC(sysdate, 'MM'), 'DD/MM/YYYY')||' '||TO_CHAR(sysdate,'HH24:MI:SS'), 'DD/MM/YYYY HH24:MI:SS') --END_TRAN_TIME
                                  , 'HJS'--EMPLOYEE_ID
                                  , rec.PO --CONTROL_NUMBER
                                  , rec.display
                                  , rec.wh
                                  , rec.Loc--LOCATION_ID
                                  , 0--NUM_ITEMS
                                  , rec.item--ITEM_NUMBER
                                  , rec.qty--TRAN_QTY
                                  , rec.Loc--LOCATION_ID_2
                              );
             
        COMMIT;          
    END LOOP;   
  
    
    EXCEPTION    
    WHEN others THEN
    ROLLBACK;
    v_nLogErrorNum := -20001;
    RAISE_APPLICATION_ERROR(v_nLogErrorNum, sqlerrm);
    
END ;