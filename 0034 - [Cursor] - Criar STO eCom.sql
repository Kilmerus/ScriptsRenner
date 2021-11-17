SET SERVEROUTPUT ON
DECLARE


/*  - Criar estoque no HJ
    - Gustavo Félix - 13/03/2020
*/

    v_vchDestinLocation VARCHAR2(100 CHAR)  := 'BIN.02.D.24.08';
    v_vchChamado        VARCHAR2(100 CHAR)  := '1713641';

CURSOR c_main IS
         SELECT 
            BLOCO1.ITEM
            , BLOCO1.WH_ID
            , (select COUNT(*) from t_stored_item where item_number = bloco1.item and location_id = 'BIN.02.D.24.08' and wh_id = BLOCO1.wh_id) as STO_COUNT
            , CASE WHEN RMS_TOTAL > HJ_TOTAL THEN 'INC_HJ'
                WHEN HJ_TOTAL>RMS_TOTAL THEN 'DEC_HJ'
                ELSE 'EQUALIZADO' END STATUS
            , CASE WHEN RMS_TOTAL > HJ_TOTAL THEN NVL(RMS_TOTAL-HJ_TOTAL,0)
                WHEN HJ_TOTAL>RMS_TOTAL THEN NVL(HJ_TOTAL-RMS_TOTAL,0)
                WHEN HJ_TOTAL=RMS_TOTAL THEN 0 END DIF_RMS_HJ
            , CASE WHEN  HJ_DISP>RMS_DISP THEN NVL(HJ_DISP-RMS_DISP,0)
                 WHEN HJ_DISP=RMS_DISP THEN 0
                 WHEN RMS_DISP > HJ_DISP THEN NVL(RMS_DISP-HJ_DISP,0) END ESTO_DISPO
            , CASE WHEN  HJ_IND>RMS_IND THEN  NVL(HJ_IND-RMS_IND,0)
                 WHEN HJ_IND=RMS_IND THEN 0
                 WHEN RMS_IND > HJ_IND THEN NVL(RMS_IND-HJ_IND,0) END ESTO_INDIS_QTY
             , CASE WHEN  HJ_IND>RMS_IND THEN  'DEC_RMS_IND'
                 WHEN HJ_IND=RMS_IND THEN 'EQUALIZADO'
                 WHEN RMS_IND > HJ_IND THEN 'INC_HJ_IND' END ESTO_INDIS
        FROM (
            select 
                rms.item
                , item.wh_id
                , rms.stock_on_hand                             AS  RMS_TOTAL
                , rms.stock_on_hand-rms.non_sellable_qty        AS  RMS_DISP
                , rms.non_sellable_qty                          AS  RMS_IND
                , NVL(sum(sto.actual_qty),0)                    AS  HJ_TOTAL
                , NVL(sum(sto.unavailable_qty),0)               AS  HJ_IND
                , NVL(sum(sto.actual_qty),0)-NVL(sum(sto.unavailable_qty),0)  AS  HJ_DISP
            from item_loc_soh@rms14 rms
            inner join dbo.tmp_item item
                on rms.item = item.item_number
                and rms.loc = item.wh_id+500
            left join t_stored_item sto
                on sto.item_number = item.item_number
                and sto.wh_id = item.wh_id
                --and sto.item_number in ('543586386','545663681')
            GROUP BY
                rms.item
                ,  item.wh_id
                , rms.stock_on_hand
                , rms.non_sellable_qty) BLOCO1 
        WHERE RMS_TOTAL > HJ_TOTAL;
rec_main c_main%ROWTYPE;


    -- Error handling variables
    c_vchObjName  VARCHAR2(30 CHAR); -- The name that uniquely tags this object.
    v_vchErrorMsg VARCHAR2(2000 CHAR);
    v_nErrorCode  NUMBER;
    
    -- Exceptions
    e_KnownError   EXCEPTION;
    e_UnknownError EXCEPTION;
    
    -- Variáveis
    /*Variável de Destino*/

    v_vchHost           VARCHAR2(100 CHAR);
    v_vchStatusA        VARCHAR2(100 CHAR);
    v_vchStatusB        VARCHAR2(100 CHAR);
    v_vchTransaction    VARCHAR2(100 CHAR);
    v_vchSourceHUID     VARCHAR2(100 CHAR);
    v_numCount          NUMBER:= 0;
    v_vchReturn         VARCHAR2(2000 CHAR);

BEGIN

    SELECT SYS_GUID() INTO v_vchHost from dual;

    FOR rec_main IN c_main	LOOP
    
        IF c_main%NOTFOUND Then
            EXIT;
        END IF;
        
      
        -- INSERIR RASTREABILIDADE
        INSERT INTO t_tran_log_holding  
            (TRAN_TYPE, DESCRIPTION, START_TRAN_DATE, START_TRAN_TIME, END_TRAN_DATE, END_TRAN_TIME, CONTROL_NUMBER,
            EMPLOYEE_ID, LOCATION_ID, LOCATION_ID_2, ITEM_NUMBER, TRAN_QTY, WH_ID)
        VALUES                          
            ('009','Incremento de Estoque', SYSDATE, SYSDATE, SYSDATE, SYSDATE, v_vchChamado,
            'HJS',null, v_vchDestinLocation, REC_MAIN.ITEM, REC_MAIN.DIF_RMS_HJ, REC_MAIN.wh_id);

        
        
        IF REC_MAIN.ESTO_INDIS = 'EQUALIZADO' THEN
        
            IF  REC_MAIN.STO_COUNT = 0 THEN            
                INSERT INTO t_stored_item (SEQUENCE, ITEM_NUMBER, ACTUAL_QTY, UNAVAILABLE_QTY, STATUS, WH_ID, LOCATION_ID, type)
                VALUES (0, rec_main.item, REC_MAIN.DIF_RMS_HJ, 0, 'A', REC_MAIN.wh_id, v_vchDestinLocation, 0);            
            ELSE
                UPDATE t_stored_item  set actual_qty = actual_qty + REC_MAIN.DIF_RMS_HJ
                    WHERE   item_number = rec_main.item
                    AND     wh_id = rec_main.wh_id
                    AND     location_id = v_vchDestinLocation;
            END IF;

            
        ELSIF REC_MAIN.ESTO_INDIS = 'INC_HJ_IND' THEN
        -- DECREMENTAR A QTY NON_SELABLE DO RMS
        
            v_vchStatusB        := 'HOLD';
            v_vchStatusA        := 'AVAILABLE';            
            v_vchTransaction    := '750';
     
        
            IF  REC_MAIN.STO_COUNT = 0 THEN            
                INSERT INTO t_stored_item (SEQUENCE, ITEM_NUMBER, ACTUAL_QTY, UNAVAILABLE_QTY, STATUS, WH_ID, LOCATION_ID, type)
                VALUES (0, rec_main.item, REC_MAIN.DIF_RMS_HJ, 0, 'A', REC_MAIN.wh_id, v_vchDestinLocation, 0);            
            ELSE
                UPDATE t_stored_item  set actual_qty = actual_qty + REC_MAIN.DIF_RMS_HJ
                    WHERE   item_number = rec_main.item
                    AND     wh_id = rec_main.wh_id
                    AND     location_id = v_vchDestinLocation;
            END IF;           

            
            -- ENVIA O AJUSTE DE ESTOQUE            
            INSERT INTO T_AL_HOST_INVENTORY_ADJUSTMENT (ADJUSTMENT_ID,HOST_GROUP_ID,TRANSACTION_CODE,ITEM_NUMBER,LOT_NUMBER,QUANTITY_BEFORE,QUANTITY_AFTER,QUANTITY_CHANGE,HU_ID,INVENTORY_STATUS_BEFORE,INVENTORY_STATUS_AFTER,REASON_CODE,FIFO_DATE,FROM_LOCATION_ID,TO_LOCATION_ID,USER_ID,WH_ID,RECORD_CREATE_DATE,UOM,REFERENCE_CODE,GEN_ATTRIBUTE_VALUE1,GEN_ATTRIBUTE_VALUE2,GEN_ATTRIBUTE_VALUE3,GEN_ATTRIBUTE_VALUE4,GEN_ATTRIBUTE_VALUE5,GEN_ATTRIBUTE_VALUE6,GEN_ATTRIBUTE_VALUE7,GEN_ATTRIBUTE_VALUE8,GEN_ATTRIBUTE_VALUE9,GEN_ATTRIBUTE_VALUE10,GEN_ATTRIBUTE_VALUE11,DISPLAY_ITEM_NUMBER,CLIENT_CODE) 
            VALUES (null,v_vchHost,v_vchTransaction,rec_main.item,null,rec_main.ESTO_INDIS_QTY,rec_main.ESTO_INDIS_QTY,0,null,v_vchStatusB,v_vchStatusA,'42',null,v_vchDestinLocation,v_vchDestinLocation,v_vchChamado,REC_MAIN.WH_ID,sysdate,'EA',null,null,null,null,null,null,null,null,null,null,null,null,REC_MAIN.ITEM,'001');
            
            COMMIT;
            
            SELECT PKG_WEBSERVICES.USF_CALL_WEBSERVICE('EXP_INV_ADJUST', v_vchHost) into v_vchReturn FROM dual;
            
            dbms_output.put_line( ' Verificar host na webservice alloc log: ' || v_vchHost); 
            
        ELSIF REC_MAIN.ESTO_INDIS = 'DEC_RMS_IND' THEN
        -- INCREMENTA A QTY NON_SELABLE DO RMS
        
            v_vchStatusB        := 'AVAILABLE';
            v_vchStatusA        := 'HOLD';            
            v_vchTransaction    := '700';
          
            IF  REC_MAIN.STO_COUNT = 0 THEN            
                INSERT INTO t_stored_item (SEQUENCE, ITEM_NUMBER, ACTUAL_QTY, UNAVAILABLE_QTY, STATUS, WH_ID, LOCATION_ID, type)
                VALUES (0, rec_main.item, REC_MAIN.DIF_RMS_HJ, 0, 'A', REC_MAIN.wh_id, v_vchDestinLocation, 0);            
            ELSE
                UPDATE t_stored_item  set actual_qty = actual_qty + REC_MAIN.DIF_RMS_HJ
                    WHERE   item_number = rec_main.item
                    AND     wh_id = rec_main.wh_id
                    AND     location_id = v_vchDestinLocation;
            END IF;         

            
            -- ENVIA O AJUSTE DE ESTOQUE            
            INSERT INTO T_AL_HOST_INVENTORY_ADJUSTMENT (ADJUSTMENT_ID,HOST_GROUP_ID,TRANSACTION_CODE,ITEM_NUMBER,LOT_NUMBER,QUANTITY_BEFORE,QUANTITY_AFTER,QUANTITY_CHANGE,HU_ID,INVENTORY_STATUS_BEFORE,INVENTORY_STATUS_AFTER,REASON_CODE,FIFO_DATE,FROM_LOCATION_ID,TO_LOCATION_ID,USER_ID,WH_ID,RECORD_CREATE_DATE,UOM,REFERENCE_CODE,GEN_ATTRIBUTE_VALUE1,GEN_ATTRIBUTE_VALUE2,GEN_ATTRIBUTE_VALUE3,GEN_ATTRIBUTE_VALUE4,GEN_ATTRIBUTE_VALUE5,GEN_ATTRIBUTE_VALUE6,GEN_ATTRIBUTE_VALUE7,GEN_ATTRIBUTE_VALUE8,GEN_ATTRIBUTE_VALUE9,GEN_ATTRIBUTE_VALUE10,GEN_ATTRIBUTE_VALUE11,DISPLAY_ITEM_NUMBER,CLIENT_CODE) 
            VALUES (null,v_vchHost,v_vchTransaction,rec_main.item,null,rec_main.ESTO_INDIS_QTY,rec_main.ESTO_INDIS_QTY,0,null,v_vchStatusB,v_vchStatusA,'42',null,v_vchDestinLocation,v_vchDestinLocation,v_vchChamado,REC_MAIN.WH_ID,sysdate,'EA',null,null,null,null,null,null,null,null,null,null,null,null,REC_MAIN.ITEM,'001');
            
            COMMIT;
            
            SELECT PKG_WEBSERVICES.USF_CALL_WEBSERVICE('EXP_INV_ADJUST', v_vchHost) into v_vchReturn FROM dual;
            
            dbms_output.put_line( ' Verificar host na webservice alloc log: ' || v_vchHost); 
            
        END IF;

                            
    END LOOP;

COMMIT;

 EXCEPTION -- Exceção do Laço (For)
          WHEN OTHERS THEN
               ROLLBACK;
               v_nErrorCode  := -20006;
               v_vchErrorMsg := 'SQLERRM = ' || SQLERRM;
               RAISE e_UnknownError;

END;