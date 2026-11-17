SET SERVEROUTPUT ON SIZE UNLIMITED
-- Consultas somente leitura: status dos objetos e os tres relatorios.
SELECT object_name,object_type,status FROM user_objects
WHERE object_name LIKE 'PKG_NV\_%' ESCAPE '\' OR object_name LIKE 'TRG_NV\_%' ESCAPE '\'
ORDER BY object_name,object_type;
SELECT PKG_NV_SOLICITACOES.FN_CALCULAR_PRIORIDADE('ALTA',5,1,'AGUA_CONTAMINADA') AS prioridade FROM dual;
SELECT * FROM V_NV_FILA ORDER BY prioridade DESC,id;
SELECT * FROM V_NV_DEMANDA ORDER BY "regiaoId",status;
SELECT * FROM V_NV_ESTOQUE ORDER BY "regiaoId";
-- Demonstra procedure + trigger + auditoria com rollback ao final.
DECLARE
 v_cid NUMBER; v_eq NUMBER; v_reg NUMBER; v_id NUMBER; v_cidade NV_REGIAO.cidade%TYPE;
BEGIN
 SAVEPOINT demonstracao_nv;
 SELECT MIN(id) INTO v_cid FROM NV_USUARIO WHERE papel='CIDADAO' AND ativo=1;
 SELECT MIN(id) INTO v_eq FROM NV_USUARIO WHERE papel='EQUIPE' AND ativo=1;
 SELECT id,cidade INTO v_reg,v_cidade FROM NV_REGIAO WHERE id=(SELECT MIN(id) FROM NV_REGIAO);
 PKG_NV_SOLICITACOES.PRC_CRIAR_SOLICITACAO(v_cid,v_reg,'AGUA_CONTAMINADA','Demonstracao presencial',5,'ALTA',1,'Endereco ficticio',v_cidade,v_id);
 DBMS_OUTPUT.PUT_LINE('Pedido temporario criado: '||v_id||'; prioridade esperada 75.');
 PKG_NV_SOLICITACOES.PRC_ALTERAR_STATUS(v_id,v_eq,'EM_ATENDIMENTO');
 FOR a IN (SELECT operacao,executada_em,
  JSON_VALUE(valores_antigos,'$.status') anterior,JSON_VALUE(valores_novos,'$.status') novo,
  JSON_VALUE(valores_novos,'$.prioridade') prioridade
  FROM NV_AUDITORIA WHERE solicitacao_id=v_id ORDER BY id) LOOP
  DBMS_OUTPUT.PUT_LINE(a.operacao||' | '||TO_CHAR(a.executada_em,'DD/MM/YYYY HH24:MI:SS')||' | '||NVL(a.anterior,'NULL')||' -> '||a.novo||' | prioridade '||a.prioridade);
 END LOOP;
 ROLLBACK TO demonstracao_nv;
 DBMS_OUTPUT.PUT_LINE('Rollback concluido: carga original preservada.');
EXCEPTION WHEN OTHERS THEN ROLLBACK TO demonstracao_nv; RAISE;
END;
/
