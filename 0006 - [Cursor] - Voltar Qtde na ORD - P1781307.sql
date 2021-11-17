SET SERVEROUTPUT ON
DECLARE


CURSOR c_main IS
    select wam.item_number
    , wam.order_number
    , wam.line_number
    , WAM.wave_id
    , wam.wh_id
    , sum(wam.planned_qty) as qty_afo
    , nvl(sum(pkd.planned_quantity),0) as qty_pkd
    , wam.wave_detail_line_id 
    , sum(wam.planned_qty) - NVL(sum(pkd.planned_quantity),0) as DIF
    from v_wave wam
        LEFT join t_pick_detail pkd
            on pkd.item_number = wam.item_number
            and pkd.wh_id = wam.wh_id
            and pkd.line_number = wam.line_number
            and pkd.order_number = wam.order_number
    where wam.wave_id = 'CX_SR_FL11_191024_03'
    --AND wam.order_number = '900841117'
    group by wam.item_number, wam.order_number
    , wam.line_number
    , wam.wh_id
    , WAM.wave_id
    , wave_detail_line_id
    having nvl(sum(pkd.planned_quantity),0) = 0;
rec_main c_main%ROWTYPE;


     -- Error handling variables
     c_vchObjName  VARCHAR2(30 CHAR); -- The name that uniquely tags this object.
     v_vchErrorMsg VARCHAR2(2000 CHAR);
     v_nErrorCode  NUMBER;
     -- Exceptions
     e_KnownError   EXCEPTION;
     e_UnknownError EXCEPTION;


BEGIN
	FOR rec_main IN c_main	LOOP
	
	IF c_main%NOTFOUND Then
      EXIT;
	END IF;
    
    -- RETORNAR QUANTIDADE DISPONÍVEL PARA LIBERAÇÂO DE ONDA
    UPDATE t_order_detail set afo_plan_qty = rec_main.qty_afo
        WHERE order_number      = rec_main.order_number
        and     wh_id           = rec_main.wh_id
        and     line_number     = rec_main.line_number
        and     afo_plan_qty    = 0;
        
    -- DELETAR INFORMAÇÕES DA AFO_WAVE_DETAIL
    DELETE T_AFO_WAVE_DETAIL_LINE
    WHERE WAVE_DETAIL_LINE_ID = rec_main.WAVE_DETAIL_LINE_ID
    AND item_number = rec_main.item_number
    AND line_number = rec_main.line_number;
    
    -- DELETAR ORDEM, CASO NÃO EXISTA MAIS DETALHE A NÍVEL DE LOJA
    DELETE t_afo_wave_detail WDE
    WHERE NOT EXISTS (SELECT 1 FROM t_afo_wave_detail_line
                        WHERE wave_detail_id = WDE.wave_detail_id)
    AND WDE.ORDER_NUMBER = rec_main.order_number
    AND WDE.WAVE_ID = rec_main.wave_id;
    
    Insert into DBO.T_EXCEPTION_LOG 
      (TRAN_TYPE,DESCRIPTION,EXCEPTION_DATE,EXCEPTION_TIME,EMPLOYEE_ID,WH_ID
      ,QUANTITY,HU_ID,CONTROL_NUMBER,LINE_NUMBER,ERROR_CODE,ERROR_MESSAGE,STATUS, ITEM_NUMBER, tracking_number) 
      values 
      (REC_MAIN.WH_ID,'Lojas não Liberadas',sysdate,sysdate,'Cursor',rec_main.wh_id
      ,rec_main.qty_afo,0,rec_main.WAVE_ID,rec_main.line_number,'0','Linha inexistente na PKD','NEW', REC_MAIN.ITEM_NUMBER, rec_main.order_number);
   							
  END LOOP;

COMMIT;

 EXCEPTION -- Exceção do Laço (For)
          WHEN OTHERS THEN
               ROLLBACK;
               v_nErrorCode  := -20006;
               v_vchErrorMsg := 'SQLERRM = ' || SQLERRM;
               RAISE e_UnknownError;

END;