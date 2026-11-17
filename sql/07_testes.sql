SET SERVEROUTPUT ON SIZE UNLIMITED
DECLARE
 v_id NUMBER; v_cid NUMBER; v_eq NUMBER; v_inativo NUMBER; v_reg NUMBER; v_cidade VARCHAR2(120);
 v_antes NUMBER; v_depois NUMBER; v_hist NUMBER; v_valor NUMBER; v_json CLOB;
 PROCEDURE exigir(p BOOLEAN,p_msg VARCHAR2) IS BEGIN IF p IS NULL OR NOT p THEN RAISE_APPLICATION_ERROR(-20990,p_msg); END IF; END;
 PROCEDURE erro(p_sql VARCHAR2,p_codigo NUMBER) IS v_ok BOOLEAN:=FALSE;
 BEGIN
  BEGIN EXECUTE IMMEDIATE p_sql;
  EXCEPTION WHEN OTHERS THEN IF SQLCODE<>p_codigo THEN RAISE; END IF; v_ok:=TRUE; END;
  exigir(v_ok,'Excecao esperada nao ocorreu: '||p_codigo);
 END;
BEGIN
 SAVEPOINT testes_nv;
 SELECT MIN(id) INTO v_cid FROM NV_USUARIO WHERE papel='CIDADAO' AND ativo=1;
 SELECT MIN(id) INTO v_eq FROM NV_USUARIO WHERE papel='EQUIPE' AND ativo=1;
 SELECT MIN(id) INTO v_inativo FROM NV_USUARIO WHERE papel='CIDADAO' AND ativo=0;
 SELECT id,cidade INTO v_reg,v_cidade FROM NV_REGIAO WHERE id=(SELECT MIN(id) FROM NV_REGIAO);
 exigir(PKG_NV_SOLICITACOES.FN_CALCULAR_PRIORIDADE('CRITICA',20,1,'AGUA_CONTAMINADA')=100,'Limite da prioridade');
 exigir(PKG_NV_SOLICITACOES.FN_CALCULAR_PRIORIDADE('BAIXA',1,0,'OUTRO')=11,'Prioridade baixa');
 exigir(PKG_NV_SOLICITACOES.FN_CALCULAR_PRIORIDADE('ALTA',5,1,'FALTA_DE_AGUA')=70,'Formula do Java');
 erro('DECLARE n NUMBER; BEGIN n:=PKG_NV_SOLICITACOES.FN_CALCULAR_PRIORIDADE(NULL,2,0,''OUTRO''); END;',-20101);
 erro('DECLARE n NUMBER; BEGIN n:=PKG_NV_SOLICITACOES.FN_CALCULAR_PRIORIDADE(''ALTA'',0,0,''OUTRO''); END;',-20101);
 erro('DECLARE n NUMBER; BEGIN n:=PKG_NV_SOLICITACOES.FN_CALCULAR_PRIORIDADE(''ALTA'',1.5,0,''OUTRO''); END;',-20101);
 exigir(PKG_NV_SOLICITACOES.FN_TRANSICAO_PERMITIDA('ABERTA','ATENDIDA')=0,'Salto indevido');
 exigir(PKG_NV_SOLICITACOES.FN_TRANSICAO_PERMITIDA('CANCELADA','ABERTA')=0,'Reabertura indevida');
 exigir(PKG_NV_SOLICITACOES.FN_TRANSICAO_PERMITIDA(NULL,'ABERTA')=0,'Estado nulo');
 erro('BEGIN PKG_NV_SOLICITACOES.PRC_VALIDAR('||v_inativo||',NULL,''Canoas'',NULL); END;',-20102);
 erro('BEGIN PKG_NV_SOLICITACOES.PRC_VALIDAR('||v_cid||','||v_reg||',''Outra cidade'',NULL); END;',-20103);
 SELECT COUNT(*) INTO v_antes FROM NV_AUDITORIA;
 PKG_NV_SOLICITACOES.PRC_CRIAR_SOLICITACAO(v_cid,v_reg,'AGUA_CONTAMINADA','Teste: "aspas", barra \ e quebra '||CHR(10)||'linha',5,'ALTA',1,'Endereco ficticio',v_cidade,v_id);
 SELECT COUNT(*) INTO v_depois FROM NV_AUDITORIA WHERE solicitacao_id=v_id AND operacao='INSERT' AND valores_antigos IS NULL AND valores_novos IS NOT NULL;
 exigir(v_depois=1,'Auditoria de INSERT');
 SELECT prioridade INTO v_valor FROM NV_SOLICITACAO WHERE id=v_id; exigir(v_valor=75,'Prioridade na criacao');
 UPDATE NV_SOLICITACAO SET prioridade=0 WHERE id=v_id;
 SELECT prioridade INTO v_valor FROM NV_SOLICITACAO WHERE id=v_id; exigir(v_valor=75,'Trigger recalcula prioridade');
 erro('BEGIN PKG_NV_SOLICITACOES.PRC_ALTERAR_STATUS('||v_id||','||v_cid||',''EM_ATENDIMENTO''); END;',-20104);
 erro('BEGIN PKG_NV_SOLICITACOES.PRC_ALTERAR_STATUS('||v_id||','||v_eq||',''ATENDIDA''); END;',-20106);
 erro('BEGIN PKG_NV_SOLICITACOES.PRC_ALTERAR_STATUS('||v_id||','||v_eq||',''CANCELADA''); END;',-20107);
 erro('UPDATE NV_SOLICITACAO SET status=''ATENDIDA'' WHERE id='||v_id,-20106);
 erro('UPDATE NV_PONTO_AGUA SET estoque_litros=capacidade_litros+1',-2290);
 erro('BEGIN PKG_NV_SOLICITACOES.PRC_ALTERAR_STATUS(-1,'||v_eq||',''EM_ATENDIMENTO''); END;',-20108);
 PKG_NV_SOLICITACOES.PRC_ALTERAR_STATUS(v_id,v_eq,'EM_ATENDIMENTO');
 SELECT COUNT(*) INTO v_hist FROM NV_HISTORICO_STATUS WHERE solicitacao_id=v_id;
 PKG_NV_SOLICITACOES.PRC_ALTERAR_STATUS(v_id,v_eq,'EM_ATENDIMENTO');
 SELECT COUNT(*) INTO v_depois FROM NV_HISTORICO_STATUS WHERE solicitacao_id=v_id;
 exigir(v_hist=1 AND v_depois=v_hist,'Repeticao de status deve ser idempotente');
 SELECT COUNT(*) INTO v_depois FROM NV_AUDITORIA WHERE solicitacao_id=v_id AND operacao='UPDATE'
  AND JSON_VALUE(valores_antigos,'$.status')='ABERTA' AND JSON_VALUE(valores_novos,'$.status')='EM_ATENDIMENTO';
 exigir(v_depois=1,'Conteudo antigo/novo na auditoria');
 PKG_NV_SOLICITACOES.PRC_ALTERAR_STATUS(v_id,v_eq,'CANCELADA','Teste cancelamento');
 erro('BEGIN PKG_NV_SOLICITACOES.PRC_ALTERAR_STATUS('||v_id||','||v_eq||',''ABERTA''); END;',-20106);
 PKG_NV_RELATORIOS.PRC_EXPORTAR_SOLICITACOES(v_json);
 exigir(DBMS_LOB.INSTR(v_json,'\"aspas\"')>0,'Escape JSON nativo');
 DELETE FROM NV_HISTORICO_STATUS WHERE solicitacao_id=v_id;
 DELETE FROM NV_SOLICITACAO WHERE id=v_id;
 SELECT COUNT(*) INTO v_depois FROM NV_AUDITORIA WHERE solicitacao_id=v_id AND operacao='DELETE' AND valores_antigos IS NOT NULL AND valores_novos IS NULL;
 exigir(v_depois=1,'Auditoria de DELETE');
 -- Cidade sem regiao: mantem NULL e os relatorios usam a chave 0.
 PKG_NV_SOLICITACOES.PRC_CRIAR_SOLICITACAO(v_cid,NULL,'OUTRO','Teste sem regiao',1,'BAIXA',0,'Endereco ficticio','Cidade sem cobertura',v_id);
 SELECT COUNT(*) INTO v_depois FROM V_NV_FILA WHERE id=v_id AND "regiaoId" IS NULL;
 exigir(v_depois=1,'Fila deve preservar regiao ausente');
 SELECT COUNT(*) INTO v_depois FROM V_NV_DEMANDA WHERE "regiaoId"=0 AND status='ABERTA';
 exigir(v_depois=1,'Agregacao deve incluir regiao ausente');
 UPDATE NV_SOLICITACAO SET status='CANCELADA',excluida_em=SYSTIMESTAMP WHERE id=v_id;
 SELECT COUNT(*) INTO v_depois FROM V_NV_DEMANDA WHERE "regiaoId"=0;
 exigir(v_depois=0,'Exclusao logica deve sair da demanda');
 ROLLBACK TO testes_nv;
 SELECT COUNT(*) INTO v_depois FROM NV_AUDITORIA;
 exigir(v_antes=v_depois,'Rollback da auditoria');
 DBMS_OUTPUT.PUT_LINE('APROVADO: funcoes, procedures, excecoes, gatilhos, JSON, historico, idempotencia e rollback.');
EXCEPTION WHEN OTHERS THEN ROLLBACK TO testes_nv; RAISE;
END;
/
