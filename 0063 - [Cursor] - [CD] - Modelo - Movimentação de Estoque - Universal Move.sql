SET SERVEROUTPUT ON
DECLARE
/**************************************************************************************
- Movimentação de estoque
- Gustavo Félix - 11/12/2020
- Ajustes pré-inventário

**************************************************************************************/

G_v_vchLocation         VARCHAR2(50 CHAR);
G_v_vchWhID             VARCHAR2(50 CHAR);

G_v_vchLocationDest     VARCHAR2(50 CHAR):= 'LOC_INV_RESERVADO';
G_v_vchLocationDestI    VARCHAR2(50 CHAR):= 'LOC_INV_RESERVADO_I';

G_v_vchLocationDestPre  VARCHAR2(50 CHAR):= 'LOC_INV_PRE';
G_v_vchLocationDestPreI VARCHAR2(50 CHAR):= 'LOC_INV_PRE_I';

G_v_vchStorage          VARCHAR2(50 CHAR);

    CURSOR c_main IS
    SELECT
        LOCATION_ID
        , WH_ID
        , TYPE
        , STATUS
        , ZONE_TYPE
        , ZONE
        , item_hu_indicator
    FROM (
        SELECT 
                LOC.location_id
                , LOC.wh_id
                , LOC.type
                , loc.item_hu_indicator
                , LOC.status
                , CASE WHEN EXISTS (select 1 from t_zone_loca zlo
                                    inner join t_zone zon
                                        on zlo.zone = zon.zone
                                        and zlo.wh_id = zon.wh_id
                                        and zlo.location_id = LOC.location_id
                                        and zon.zone_type = 'CC') THEN 'CC'
                        WHEN EXISTS (select 1 from t_zone_loca zlo
                                    inner join t_zone zon
                                        on zlo.zone = zon.zone
                                        and zlo.wh_id = zon.wh_id
                                        and zlo.location_id = LOC.location_id
                                        and zon.zone_type like 'CC_%'
                                        and zon.zone <> 'ALL') THEN 'ATENÇÃO'
                ELSE '-' end ZONE_TYPE
                , (select MAX(zon.zone_type) from t_zone_loca zlo
                                    inner join t_zone zon
                                        on zlo.zone = zon.zone
                                        and zlo.wh_id = zon.wh_id
                                        and zlo.location_id = LOC.location_id
                                        --and zon.zone_type <> 'CC'
                                        --and zon.zone <> 'ALL'
                                        and zon.zone_type in ('CC PRE','CC POS')
                                        --and zon.zone_type is not null
                                        ) as ZONE
            FROM t_location LOC
            WHERE 1=1
            AND EXISTS (
                        SELECT 1
                        FROM t_stored_item STOA
                            WHERE STOA.wh_id = LOC.wh_id
                            AND STOA.location_id = LOC.location_id
                            AND STOA.TYPE = 'STORAGE')
    
            AND EXISTS (
                        SELECT 1
                        FROM t_stored_item STOB
                            WHERE STOB.wh_id = LOC.wh_id
                            AND STOB.location_id = LOC.location_id
                            AND STOB.TYPE <> 'STORAGE')
            -- APENAS ENDEREÇOS DE ZONAS DIFERENTE DE ALL
            AND EXISTS (select 1
                        from t_zone_loca zlo
                        inner join t_zone zon
                            on zlo.zone = zon.zone
                            and zlo.wh_id = zon.wh_id
                            and zlo.location_id = LOC.location_id
                            and zon.zone<>'ALL')
            ORDER BY 1,2)
    WHERE ZONE_TYPE = 'ATENÇÃO'
    --AND LOCATION_ID IN ('CTN_STG99499','CX.B0.C08.S24.N4.0')
    ;

rec_main c_main%ROWTYPE;

    
    CURSOR c_ccPRE IS
        SELECT 
            sto.hu_id
            , sto.item_number
            , sto.wh_id
            , sto.TYPE
            , sto.actual_qty
            , sto.status
            , hum.type as HUM_TYPE
        FROM t_stored_item sto
        inner join t_hu_master hum
            ON hum.hu_id = sto.hu_id
            AND hum.wh_id = sto.wh_id
        WHERE sto.location_id = G_v_vchLocation
        AND sto.wh_id = G_v_vchWhID
        --AND HU_ID in ('25588945349967890015','26274505304665450045')
        AND sto.TYPE <> 'STORAGE';
    rec_ccPRE c_ccPRE%ROWTYPE;

    CURSOR c_ccPOS IS
        SELECT 
            sto.hu_id
            , sto.item_number
            , sto.wh_id
            , sto.TYPE
            , sto.actual_qty
            , sto.status
            , hum.type as HUM_TYPE
        FROM t_stored_item sto
        inner join t_hu_master hum
            ON hum.hu_id = sto.hu_id
            AND hum.wh_id = sto.wh_id
        WHERE sto.location_id = G_v_vchLocation
        AND sto.wh_id = G_v_vchWhID
        --AND HU_ID in ('25588945349967890015','26274505304665450045')
        AND sto.TYPE = 'STORAGE';
    rec_ccPOS c_ccPOS%ROWTYPE;


    CURSOR c_ccPRE_I IS
        SELECT 
            sto.location_id
            , sto.item_number
            , sto.wh_id
            , sto.TYPE
            , SUM(sto.actual_qty) as qty
            , sto.status
        FROM t_stored_item sto
        WHERE sto.location_id = G_v_vchLocation
        AND sto.wh_id = G_v_vchWhID
        --AND HU_ID in ('25588945349967890015','26274505304665450045')
        AND sto.TYPE <> 'STORAGE'
        GROUP BY 
        sto.location_id
            , sto.item_number
            , sto.wh_id
            , sto.TYPE
            , sto.status;
    rec_ccPRE_I c_ccPRE_I%ROWTYPE;
    
    CURSOR c_ccPOS_I IS
        SELECT 
            sto.location_id
            , sto.item_number
            , sto.wh_id
            , sto.TYPE
            , SUM(sto.actual_qty) as qty
            , sto.status
        FROM t_stored_item sto
        WHERE sto.location_id = G_v_vchLocation
        AND sto.wh_id = G_v_vchWhID
        --AND HU_ID in ('25588945349967890015','26274505304665450045')
        AND sto.TYPE = 'STORAGE'
        GROUP BY 
        sto.location_id
            , sto.item_number
            , sto.wh_id
            , sto.TYPE
            , sto.status;
    rec_ccPOS_I c_ccPOS_I%ROWTYPE;

     -- Error handling variables
     c_vchObjName   VARCHAR2(30 CHAR); -- The name that uniquely tags this object.
     v_vchErrorMsg  VARCHAR2(2000 CHAR);
     v_nErrorCode   NUMBER;
     v_vchReturn    VARCHAR2(2000 CHAR);
     
     -- Exceptions
     e_KnownError   EXCEPTION;
     e_UnknownError EXCEPTION;
     ErrMsg         VARCHAR2(3100);
     
     
     v_Tran_Type    VARCHAR2(30 CHAR);
     --v_vchChamado   VARCHAR2(30 CHAR):= 'INC0242510';
     v_nQtySto      NUMBER:=0;
     v_nQtyLog      NUMBER:=0;
     
BEGIN

    v_Tran_Type:= '045';

    FOR rec_main IN c_main	LOOP
    
        IF c_main%NOTFOUND Then
            EXIT;
        END IF;
        
        
        IF (rec_main.zone = 'CC PRE' and rec_main.item_hu_indicator = 'H') THEN 
        
            G_v_vchLocation:= rec_main.location_id;
            G_v_vchWhID:= rec_main.wh_id;
            
            -- SE A ZONA FOR CC PRE, DEVE-SE CHAMAR O CURSOR CC_PRE
            -- PEGAR TUDO DIFERENTE DE STORAGE e MOVER PARA O ENDEREÇO RESERVADO
            FOR rec_ccPRE in c_ccPRE LOOP
            
                IF c_ccPRE%NOTFOUND Then
                    EXIT;
                END IF;
                
                -- INSERIR LOG
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
                                                  , HU_ID
                                                  , HU_ID_2
                                                  , LOCATION_ID
                                                  , LOCATION_ID_2
                                                  , NUM_ITEMS
                                                  , ITEM_NUMBER
                                                  , TRAN_QTY
                      
                ) VALUES (
                                                    v_Tran_Type
                                                  , (select description from t_transaction where tran_type = v_Tran_Type)
                                                  , trunc(sysdate)
                                                  , TO_DATE(TO_CHAR(TRUNC(sysdate, 'MM'), 'DD/MM/YYYY')||' '||TO_CHAR(sysdate,'HH24:MI:SS'), 'DD/MM/YYYY HH24:MI:SS') --START_TRAN_TIME
                                                  , trunc(sysdate)--TO_DATE('01/01/1900','MM/DD/YYYY')END_TRAN_DATE
                                                  , TO_DATE(TO_CHAR(TRUNC(sysdate, 'MM'), 'DD/MM/YYYY')||' '||TO_CHAR(sysdate,'HH24:MI:SS'), 'DD/MM/YYYY HH24:MI:SS') --END_TRAN_TIME
                                                  , 'HJS'                               --EMPLOYEE_ID
                                                  , 'PRE_INVENTÁRIO'                    --CONTROL_NUMBER
                                                  , null
                                                  , G_v_vchWhID
                                                  , rec_ccPRE.hu_id
                                                  , rec_ccPRE.hu_id
                                                  , G_v_vchLocation                 --LOCATION_ID
                                                  /*ENDEREÇO RESERVADO*/
                                                  , G_v_vchLocationDest             --LOCATION_ID_2
                                                  , 0--NUM_ITEMS
                                                  , rec_ccPRE.item_number          --ITEM_NUMBER
                                                  , rec_ccPRE.actual_qty           --TRAN_QTY
                      
                  );
                  
                  
                  "USP_UNIVERSAL_MOVE_WHOLE_HU" 
                                            (  'WA'                 --in_vchAppIdentifier           VARCHAR2,
                                              ,'203'                --in_vchTransactionCode         VARCHAR2,
                                              ,'HJS'                --in_vchEmpID                   VARCHAR2,
                                              ,G_v_vchLocation		--in_vchSourceLocation          VARCHAR2,
                                              ,G_v_vchLocationDest	--in_vchDestinationLocation     VARCHAR2,
                                              ,rec_ccPRE.type		--in_vchSourceType              VARCHAR2,
                                              ,rec_ccPRE.type		--in_vchDestinationType         VARCHAR2,
                                              ,rec_ccPRE.wh_id		--in_vchWhID                    VARCHAR2,
                                              ,rec_ccPRE.hu_id		--in_vchSourceHUID              VARCHAR2,
                                              ,rec_ccPRE.hu_id		--in_vchDestinationHUID         VARCHAR2,
                                              ,null					--ITEM              VARCHAR2,
                                              ,null                 --in_vchStoredAttribID          VARCHAR2,
                                              ,null                 --in_vchLotNumber               VARCHAR2,
                                              ,null                 --in_vchQuantity                FLOAT,
                                              ,'A'                  --in_vchInventoryStatusBefore   VARCHAR2,
                                              ,'A'                  --in_vchInventoryStatusAfter    VARCHAR2,
                                              ,rec_ccPRE.HUM_TYPE	--in_vchDestinationHUType       VARCHAR2
                    ); 
                          
       
            END LOOP; -- rec_ccPRE
            
        ELSIF (rec_main.zone = 'CC POS' and rec_main.item_hu_indicator = 'H') THEN
            
            /*
            
                -- MOVERE TUDO QUE ESTIVER COM O TYPR IGUAL A STORAGE
            
            */      
            
            G_v_vchLocation:= rec_main.location_id;
            G_v_vchWhID:= rec_main.wh_id;
        
            FOR rec_ccPOS in c_ccPOS LOOP
            
                IF c_ccPOS%NOTFOUND Then
                    EXIT;
                END IF;
                
                -- INSERIR LOG
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
                                                  , HU_ID
                                                  , HU_ID_2
                                                  , LOCATION_ID
                                                  , LOCATION_ID_2
                                                  , NUM_ITEMS
                                                  , ITEM_NUMBER
                                                  , TRAN_QTY
                      
                ) VALUES (
                                                    v_Tran_Type
                                                  , (select description from t_transaction where tran_type = v_Tran_Type)
                                                  , trunc(sysdate)
                                                  , TO_DATE(TO_CHAR(TRUNC(sysdate, 'MM'), 'DD/MM/YYYY')||' '||TO_CHAR(sysdate,'HH24:MI:SS'), 'DD/MM/YYYY HH24:MI:SS') --START_TRAN_TIME
                                                  , trunc(sysdate)--TO_DATE('01/01/1900','MM/DD/YYYY')END_TRAN_DATE
                                                  , TO_DATE(TO_CHAR(TRUNC(sysdate, 'MM'), 'DD/MM/YYYY')||' '||TO_CHAR(sysdate,'HH24:MI:SS'), 'DD/MM/YYYY HH24:MI:SS') --END_TRAN_TIME
                                                  , 'HJS'                               --EMPLOYEE_ID
                                                  , 'PRE_INVENTÁRIO'                    --CONTROL_NUMBER
                                                  , null
                                                  , G_v_vchWhID
                                                  , rec_ccPOS.hu_id
                                                  , rec_ccPOS.hu_id
                                                  , G_v_vchLocation				--LOCATION_ID
                                                  /*ENDEREÇO RESERVADO*/
                                                  , G_v_vchLocationDestPre		--LOCATION_ID_2
                                                  , 0							--NUM_ITEMS
                                                  , rec_ccPOS.item_number		--ITEM_NUMBER
                                                  , rec_ccPOS.actual_qty		--TRAN_QTY
                      
                  );
                  
                  
                  "USP_UNIVERSAL_MOVE_WHOLE_HU" 
                                            (  'WA'                 --in_vchAppIdentifier           VARCHAR2,
                                              ,'203'                --in_vchTransactionCode         VARCHAR2,
                                              ,'HJS'                --in_vchEmpID                   VARCHAR2,
                                              ,G_v_vchLocation      --in_vchSourceLocation          VARCHAR2,
                                              ,G_v_vchLocationDestPre	--in_vchDestinationLocation     VARCHAR2,
                                              ,rec_ccPOS.type		--in_vchSourceType              VARCHAR2,
                                              ,rec_ccPOS.type		--in_vchDestinationType         VARCHAR2,
                                              ,rec_ccPOS.wh_id		--in_vchWhID                    VARCHAR2,
                                              ,rec_ccPOS.hu_id		--in_vchSourceHUID              VARCHAR2,
                                              ,rec_ccPOS.hu_id		--in_vchDestinationHUID         VARCHAR2,
                                              ,null					--ITEM              VARCHAR2,
                                              ,null                 --in_vchStoredAttribID          VARCHAR2,
                                              ,null                 --in_vchLotNumber               VARCHAR2,
                                              ,null                 --in_vchQuantity                FLOAT,
                                              ,'A'                  --in_vchInventoryStatusBefore   VARCHAR2,
                                              ,'A'                  --in_vchInventoryStatusAfter    VARCHAR2,
                                              ,rec_ccPOS.HUM_TYPE	--in_vchDestinationHUType       VARCHAR2
                    ); 
                          
       
            END LOOP; -- rec_ccPOS
            
        ELSIF (rec_main.zone = 'CC PRE' and rec_main.item_hu_indicator = 'I') THEN
        
            G_v_vchLocation:= rec_main.location_id;
            G_v_vchWhID:= rec_main.wh_id;
            
            -- SE A ZONA FOR CC PRE, DEVE-SE CHAMAR O CURSOR CC_PRE
            -- PEGAR TUDO DIFERENTE DE STORAGE e MOVER PARA O ENDEREÇO RESERVADO
            FOR rec_ccPRE_I in c_ccPRE_I LOOP
            
                IF c_ccPRE_I%NOTFOUND Then
                    EXIT;
                END IF;
                
                -- INSERIR LOG
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
                                                  , HU_ID
                                                  , HU_ID_2
                                                  , LOCATION_ID
                                                  , LOCATION_ID_2
                                                  , NUM_ITEMS
                                                  , ITEM_NUMBER
                                                  , TRAN_QTY
                      
                ) VALUES (
                                                    v_Tran_Type
                                                  , (select description from t_transaction where tran_type = v_Tran_Type)
                                                  , trunc(sysdate)
                                                  , TO_DATE(TO_CHAR(TRUNC(sysdate, 'MM'), 'DD/MM/YYYY')||' '||TO_CHAR(sysdate,'HH24:MI:SS'), 'DD/MM/YYYY HH24:MI:SS') --START_TRAN_TIME
                                                  , trunc(sysdate)--TO_DATE('01/01/1900','MM/DD/YYYY')END_TRAN_DATE
                                                  , TO_DATE(TO_CHAR(TRUNC(sysdate, 'MM'), 'DD/MM/YYYY')||' '||TO_CHAR(sysdate,'HH24:MI:SS'), 'DD/MM/YYYY HH24:MI:SS') --END_TRAN_TIME
                                                  , 'HJS'						--EMPLOYEE_ID
                                                  , 'PRE_INVENTÁRIO'			--CONTROL_NUMBER
                                                  , null
                                                  , G_v_vchWhID
                                                  , null
                                                  , null
                                                  , G_v_vchLocation				--LOCATION_ID
                                                  , G_v_vchLocationDestPreI		--LOCATION_ID_2
                                                  , 0							--NUM_ITEMS
                                                  , rec_ccPRE_I.item_number		--ITEM_NUMBER
                                                  , rec_ccPRE_I.qty				--TRAN_QTY
                      
                  );
                  
                  
            USP_UNIVERSAL_MOVE_ITEMS(
                 'WA',                      --:CONST Application Identifier:,
                 '203',                     --:MoveParam Transaction Code:,
                 'HJS',                     --:MoveParam Employee ID:,
                 rec_ccPRE_I.location_id,	--:MoveParam Source Location:,
                 G_v_vchLocationDestPreI,	--:MoveParam Destination Location:,
                 rec_ccPRE_I.type,			--:MoveParam Source Type:,
                 rec_ccPRE_I.type,			--:MoveParam Destination Type:,
                 rec_ccPRE_I.wh_id,			--:MoveParam Warehouse ID:,
                 null,                      --:MoveParam Source HU_ID:,
                 null,                      --:MoveParam Destination HU_ID:,
                 rec_ccPRE_I.item_number,	--:MoveParam Item Number:,
                 null,                      --:MoveParam Stored Attribute ID:, 
                 null,                      --:MoveParam Lot Number:,
                 rec_ccPRE_I.qty,			--:MoveParam Quantity:,
                 'A',                       --:MoveParam Invent Status Before:,
                 'A',						--:MoveParam Invent Status After:,
                 null						--:MoveParam Destination HU Type:
                 );
       
            END LOOP; 
            
        ELSIF (rec_main.zone = 'CC POS' and rec_main.item_hu_indicator = 'I') THEN
        
            G_v_vchLocation:= rec_main.location_id;
            G_v_vchWhID:= rec_main.wh_id;
            
            -- SE A ZONA FOR CC PRE, DEVE-SE CHAMAR O CURSOR CC_PRE
            -- PEGAR TUDO DIFERENTE DE STORAGE e MOVER PARA O ENDEREÇO RESERVADO
            FOR rec_ccPOS_I in c_ccPOS_I LOOP
            
                IF c_ccPOS_I%NOTFOUND Then
                    EXIT;
                END IF;
                
                -- INSERIR LOG
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
                                                  , HU_ID
                                                  , HU_ID_2
                                                  , LOCATION_ID
                                                  , LOCATION_ID_2
                                                  , NUM_ITEMS
                                                  , ITEM_NUMBER
                                                  , TRAN_QTY
                      
                ) VALUES (
                                                    v_Tran_Type
                                                  , (select description from t_transaction where tran_type = v_Tran_Type)
                                                  , trunc(sysdate)
                                                  , TO_DATE(TO_CHAR(TRUNC(sysdate, 'MM'), 'DD/MM/YYYY')||' '||TO_CHAR(sysdate,'HH24:MI:SS'), 'DD/MM/YYYY HH24:MI:SS') --START_TRAN_TIME
                                                  , trunc(sysdate)--TO_DATE('01/01/1900','MM/DD/YYYY')END_TRAN_DATE
                                                  , TO_DATE(TO_CHAR(TRUNC(sysdate, 'MM'), 'DD/MM/YYYY')||' '||TO_CHAR(sysdate,'HH24:MI:SS'), 'DD/MM/YYYY HH24:MI:SS') --END_TRAN_TIME
                                                  , 'HJS'						--EMPLOYEE_ID
                                                  , 'PRE_INVENTÁRIO'			--CONTROL_NUMBER
                                                  , null
                                                  , G_v_vchWhID
                                                  , null
                                                  , null
                                                  , G_v_vchLocation				--LOCATION_ID
                                                  /*ENDEREÇO RESERVADO*/
                                                  , G_v_vchLocationDestI		--LOCATION_ID_2
                                                  , 0							--NUM_ITEMS
                                                  , rec_ccPOS_I.item_number		--ITEM_NUMBER
                                                  , rec_ccPOS_I.qty				--TRAN_QTY
                      
                  );
                  
                  
            USP_UNIVERSAL_MOVE_ITEMS(
                 'WA',                      --:CONST Application Identifier:,
                 '203',                     --:MoveParam Transaction Code:,
                 'HJS',                     --:MoveParam Employee ID:,
                 rec_ccPOS_I.location_id,  	--:MoveParam Source Location:,
                 G_v_vchLocationDestI,      --:MoveParam Destination Location:,
                 rec_ccPOS_I.type,         	--:MoveParam Source Type:,
                 rec_ccPOS_I.type,         	--:MoveParam Destination Type:,
                 rec_ccPOS_I.wh_id,        	--:MoveParam Warehouse ID:,
                 null,                      --:MoveParam Source HU_ID:,
                 null,                      --:MoveParam Destination HU_ID:,
                 rec_ccPOS_I.item_number,  	--:MoveParam Item Number:,
                 null,                      --:MoveParam Stored Attribute ID:, 
                 null,                      --:MoveParam Lot Number:,
                 rec_ccPOS_I.qty,         	--:MoveParam Quantity:,
                 'A',                       --:MoveParam Invent Status Before:,
                 'A',                       --:MoveParam Invent Status After:,
                 null                       --:MoveParam Destination HU Type:
                 );
       
            END LOOP;
   
        END IF;

    END LOOP; -- rec_main
  
  COMMIT;

 EXCEPTION -- Exceção do Laço (For)
          WHEN OTHERS THEN
               ROLLBACK;
               v_nErrorCode  := -20006;
               v_vchErrorMsg := 'SQLERRM = ' || SQLERRM;
               RAISE e_UnknownError;

END;
