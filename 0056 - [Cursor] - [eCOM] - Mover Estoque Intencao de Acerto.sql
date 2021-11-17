SET SERVEROUTPUT ON
DECLARE
/**************************************************************************************
- Agrupar itens nos endereços corretos (Intenção de Acerto)
- Gustavo Félix - 13/10/2020
**************************************************************************************/
CURSOR c_main IS
    SELECT 
        STO.wh_id
        , sto.item_number
        , sto.hu_id
        , sto.location_id
        , SUM(sto.actual_qty) as QTY
        , itm.client_code as CC_ITEM
        --, cli.client_code as CC_LOC
        , cli.c1
        , (select cli2.C1 from t_client_control cli2
            where cli2.control_type = 'LOC_RECEB_IA'
            and cli2.client_code = itm.client_code
            and cli2.wh_id = sto.wh_id) as CC_LOC
    FROM t_stored_item STO
        inner join t_client_control CLI
            ON cli.wh_id = sto.wh_id
            AND cli.c1 = sto.location_id
            AND cli.control_type = 'LOC_RECEB_IA'
        INNER JOIN t_item_master ITM
            ON  itm.item_number = sto.item_number
            AND itm.wh_id = sto.wh_id
        WHERE cli.client_code <> itm.client_code
        AND sto.hu_id is not null
        --AND sto.item_number = '549871452'
        --AND sto.wh_id <> '114'
        --AND ROWNUM <= 10
    GROUP BY
    STO.wh_id
    , sto.item_number
    , sto.location_id
    , itm.client_code
    , cli.c1
    , sto.hu_id
    ; 
rec_main c_main%ROWTYPE;



     -- Error handling variables
     c_vchObjName   VARCHAR2(30 CHAR); -- The name that uniquely tags this object.
     v_vchErrorMsg  VARCHAR2(2000 CHAR);
     v_nErrorCode   NUMBER;
     v_nCount       NUMBER;
     v_nTranLogID   NUMBER;
     v_vchReturn    VARCHAR2(2000 CHAR);
     
     -- Exceptions
     e_KnownError   EXCEPTION;
     e_UnknownError EXCEPTION;
     ErrMsg         VARCHAR2(3100);
     
     
     v_Tran_Type  VARCHAR2(30 CHAR):= '042'; -- Movimentação - Endereços (IA)


BEGIN

    FOR rec_main IN c_main	LOOP
    
        IF c_main%NOTFOUND Then
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
                                  , 'HJS'                           --EMPLOYEE_ID
                                  , 'Separar estoques/Clientes' --CONTROL_NUMBER
                                  , 'Problema: PRB0043269'
                                  , rec_main.wh_id
                                  , rec_main.hu_id
                                  , rec_main.location_id    --LOCATION_ID
                                  , rec_main.cc_loc         --LOCATION_ID_2
                                  , 0--NUM_ITEMS
                                  , rec_main.item_number    --ITEM_NUMBER
                                  , rec_main.qty            --TRAN_QTY
                                  
                              );
    
            -- MOVIMENTAÇÃO DE ESTOQUE
            USP_UNIVERSAL_MOVE_ITEMS(
                 'WA',                      --:CONST Application Identifier:,
                 '203',                     --:MoveParam Transaction Code:,
                 'HJS',                     --:MoveParam Employee ID:,
                 rec_main.location_id,      --:MoveParam Source Location:,
                 rec_main.cc_loc,           --:MoveParam Destination Location:,
                 'STORAGE',                 --:MoveParam Source Type:,
                 'STORAGE',                 --:MoveParam Destination Type:,
                 rec_main.wh_id,            --:MoveParam Warehouse ID:,
                 rec_main.hu_id,            --:MoveParam Source HU_ID:,
                 null,                      --:MoveParam Destination HU_ID:,
                 rec_main.item_number,      --:MoveParam Item Number:,
                 null,                      --:MoveParam Stored Attribute ID:, 
                 null,                      --:MoveParam Lot Number:,
                 -----------
                 /*Quantidade da UZ e não a quantidade "Planejada"*/
                 rec_main.qty,             --:MoveParam Quantity:,
                 -----------
                 'A',                       --:MoveParam Invent Status Before:,
                 'A',                       --:MoveParam Invent Status After:,
                 null                       --:MoveParam Destination HU Type:
                 );
        
    END LOOP;
  
  COMMIT;

 EXCEPTION -- Exceção do Laço (For)
          WHEN OTHERS THEN
               ROLLBACK;
               v_nErrorCode  := -20006;
               v_vchErrorMsg := 'SQLERRM = ' || SQLERRM;
               RAISE e_UnknownError;

END;
