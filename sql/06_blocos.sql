SET SERVEROUTPUT ON
-- Bloco 1: cursor, repeticao e decisao para explicar a triagem.
DECLARE v_total NUMBER:=0; v_criticos NUMBER:=0;
BEGIN
 FOR r IN (SELECT id,prioridade FROM V_NV_FILA ORDER BY prioridade DESC,id) LOOP
  v_total:=v_total+1;
  IF r.prioridade>=70 THEN v_criticos:=v_criticos+1; END IF;
  DBMS_OUTPUT.PUT_LINE('Pedido '||r.id||' prioridade '||r.prioridade);
 END LOOP;
 DBMS_OUTPUT.PUT_LINE('Pendentes: '||v_total||'; prioridade >=70: '||v_criticos);
END;
/
-- Bloco 2: cursor e decisao para estoque; capacidade zero nao provoca divisao por zero.
DECLARE v_alertas NUMBER:=0;
BEGIN
 FOR p IN (SELECT id,status,estoque_litros,capacidade_litros FROM NV_PONTO_AGUA ORDER BY id) LOOP
  IF p.status<>'FECHADO' AND (p.capacidade_litros=0 OR p.estoque_litros<=p.capacidade_litros*0.2) THEN
   v_alertas:=v_alertas+1;
   DBMS_OUTPUT.PUT_LINE('Conferir ponto '||p.id||': estoque '||p.estoque_litros||' litros');
  END IF;
 END LOOP;
 DBMS_OUTPUT.PUT_LINE('Pontos para conferencia: '||v_alertas);
END;
/
