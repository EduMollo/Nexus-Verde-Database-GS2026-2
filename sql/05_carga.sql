-- Carga demonstrativa unica. O executor exige as seis tabelas vazias.
INSERT INTO NV_USUARIO(nome,papel,ativo) VALUES('Cidada Ana (ficticia)','CIDADAO',1);
INSERT INTO NV_USUARIO(nome,papel,ativo) VALUES('Cidadao Bruno (ficticio)','CIDADAO',1);
INSERT INTO NV_USUARIO(nome,papel,ativo) VALUES('Cidada Carla (ficticia)','CIDADAO',1);
INSERT INTO NV_USUARIO(nome,papel,ativo) VALUES('Cidadao Diego (ficticio)','CIDADAO',1);
INSERT INTO NV_USUARIO(nome,papel,ativo) VALUES('Equipe demonstracao','EQUIPE',1);
INSERT INTO NV_USUARIO(nome,papel,ativo) VALUES('Cidadao inativo (ficticio)','CIDADAO',0);
INSERT INTO NV_REGIAO(nome,cidade,nivel_risco,populacao_afetada) VALUES('Mathias Velho','Canoas','CRITICO',45000);
INSERT INTO NV_REGIAO(nome,cidade,nivel_risco,populacao_afetada) VALUES('Sao Geraldo','Porto Alegre','ALTO',7600);
INSERT INTO NV_REGIAO(nome,cidade,nivel_risco,populacao_afetada) VALUES('Centro','Sao Leopoldo','MODERADO',1800);
INSERT INTO NV_REGIAO(nome,cidade,nivel_risco,populacao_afetada) VALUES('Rio Branco','Canoas','BAIXO',900);
DECLARE
 v_id NUMBER; v_usuario NUMBER; v_equipe NUMBER; v_regiao NUMBER; v_cidade VARCHAR2(120); v_n NUMBER;
BEGIN
 SELECT id INTO v_equipe FROM NV_USUARIO WHERE papel='EQUIPE';
 FOR r IN (SELECT id,cidade FROM NV_REGIAO ORDER BY id) LOOP
  INSERT INTO NV_PONTO_AGUA(regiao_id,nome,cidade,endereco,tipo,status,capacidade_litros,estoque_litros)
   VALUES(r.id,'Posto '||r.id||' (ficticio)',r.cidade,'Endereco demonstrativo '||r.id,'POSTO_DISTRIBUICAO','DISPONIVEL',10000,7000);
  INSERT INTO NV_PONTO_AGUA(regiao_id,nome,cidade,endereco,tipo,status,capacidade_litros,estoque_litros)
   VALUES(r.id,'Apoio '||r.id||' (ficticio)',r.cidade,'Endereco demonstrativo secundario',
    'ABRIGO',CASE MOD(r.id,4) WHEN 0 THEN 'FECHADO' WHEN 1 THEN 'ESTOQUE_BAIXO' ELSE 'ESGOTADO' END,
    CASE WHEN MOD(r.id,4)=3 THEN 0 ELSE 4000 END,CASE WHEN MOD(r.id,4)=1 THEN 500 ELSE 0 END);
 END LOOP;
 FOR i IN 1..16 LOOP
  SELECT id INTO v_usuario FROM (SELECT id,ROW_NUMBER() OVER (ORDER BY id) n FROM NV_USUARIO WHERE papel='CIDADAO' AND ativo=1) WHERE n=MOD(i-1,4)+1;
  SELECT id,cidade INTO v_regiao,v_cidade FROM (SELECT id,cidade,ROW_NUMBER() OVER (ORDER BY id) n FROM NV_REGIAO) WHERE n=MOD(TRUNC((i-1)/4),4)+1;
  PKG_NV_SOLICITACOES.PRC_CRIAR_SOLICITACAO(v_usuario,v_regiao,
   CASE WHEN MOD(i,3)=0 THEN 'AGUA_CONTAMINADA' ELSE 'FALTA_DE_AGUA' END,
   'Familia ficticia '||i||' sem abastecimento. Texto com "aspas" e acentuacao: agua potavel.',
   MOD(i,12)+1,CASE MOD(i,4) WHEN 0 THEN 'CRITICA' WHEN 1 THEN 'BAIXA' WHEN 2 THEN 'MEDIA' ELSE 'ALTA' END,
   MOD(i,2),'Endereco ficticio '||i,v_cidade,v_id,CASE WHEN MOD(i,2)=0 THEN v_equipe ELSE NULL END);
  IF MOD(i,4) IN (1,2) THEN PKG_NV_SOLICITACOES.PRC_ALTERAR_STATUS(v_id,v_equipe,'EM_ATENDIMENTO'); END IF;
  IF MOD(i,4)=2 THEN PKG_NV_SOLICITACOES.PRC_ALTERAR_STATUS(v_id,v_equipe,'ATENDIDA'); END IF;
  IF MOD(i,4)=3 THEN PKG_NV_SOLICITACOES.PRC_ALTERAR_STATUS(v_id,v_equipe,'CANCELADA','Duplicidade confirmada na demonstracao'); END IF;
 END LOOP;
 DBMS_OUTPUT.PUT_LINE('Carga: 6 usuarios, 4 regioes, 8 pontos, 16 solicitacoes.');
END;
/
