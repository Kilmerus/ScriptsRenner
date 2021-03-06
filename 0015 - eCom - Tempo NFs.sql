SELECT 
    PEDIDO
    , AL_DATE               AS  SHIP_AL_HOTS
    , WEB_S_PRE_SHIP        AS  SHIP_WEB_SER
    , NF_PRINT              AS  NF_WEB_SERVI
    --, TO_TIMESTAMP (NF_PRINT, 'dd/mm/yy hh24:mi:ss')-TO_TIMESTAMP (WEB_S_PRE_SHIP, 'dd/mm/yy hh24:mi:ss')   AS DIF_NF_SHIP_WEB_S
    , SUBSTR(TO_CHAR(TO_TIMESTAMP (NF_PRINT, 'dd/mm/yy hh24:mi:ss')-TO_TIMESTAMP (WEB_S_PRE_SHIP, 'dd/mm/yy hh24:mi:ss')),12,9)   AS PROCS
   -- , TO_TIMESTAMP (NF_PRINT, 'dd/mm/yy hh24:mi:ss')-TO_TIMESTAMP (AL_DATE, 'dd/mm/yy hh24:mi:ss')          AS DIF_NF_INTERFACE
    , SUBSTR(TO_CHAR(TO_TIMESTAMP (NF_PRINT, 'dd/mm/yy hh24:mi:ss')-TO_TIMESTAMP (AL_DATE, 'dd/mm/yy hh24:mi:ss')),12,9)          AS PROCS_AL
    --, TO_TIMESTAMP (WEB_S_PRE_SHIP, 'dd/mm/yy hh24:mi:ss')-TO_TIMESTAMP (AL_DATE, 'dd/mm/yy hh24:mi:ss')    AS DIF_SHIP_W_AL_HOST
    , SUBSTR(TO_CHAR(TO_TIMESTAMP (WEB_S_PRE_SHIP, 'dd/mm/yy hh24:mi:ss')-TO_TIMESTAMP (AL_DATE, 'dd/mm/yy hh24:mi:ss')),12,9)    AS WEB_ALHOST
FROM (
SELECT 
    AL.ORDER_NUMBER         AS  PEDIDO
    , AL.RECORD_CREATE_DATE AS  AL_DATE
    , (SELECT MIN(PROCESS_DATE) FROM T_WEBSERVICE_ALLOC_LOG WHERE PARAM1 = AL.HOST_GROUP_ID) AS WEB_S_PRE_SHIP
    , (SELECT MIN(PROCESS_DATE) FROM T_WEBSERVICE_ALLOC_LOG WHERE SOAP_REQUEST LIKE '%'||SUBSTR(AL.ORDER_NUMBER,0,11)||'%'
        AND WEBSERVICE_ID = 'EXP_PRINT_NF'
        --and trunc(process_date) >= trunc(SYSDATE)-10
        AND PROCESS_DATE >= SYSDATE-1/24) AS NF_PRINT
    , AL.HOST_GROUP_ID
FROM T_AL_HOST_SHIPMENT_MASTER AL
    WHERE AL.TRANSACTION_CODE = '936'
    -- TARZER INFORMAÇÕES DA ÚLTIMA HORA
    AND AL.RECORD_CREATE_DATE >= SYSDATE-1/24)
WHERE 1=1
AND NF_PRINT IS NOT NULL
ORDER BY AL_DATE DESC;