CREATE OR REPLACE VIEW V_NV_FILA AS
 SELECT id,prioridade,regiao_id AS "regiaoId",urgencia FROM NV_SOLICITACAO
 WHERE status IN ('ABERTA','EM_ATENDIMENTO') AND excluida_em IS NULL;
CREATE OR REPLACE VIEW V_NV_DEMANDA AS
 SELECT NVL(regiao_id,0) AS "regiaoId",status,COUNT(*) AS quantidade FROM NV_SOLICITACAO
 WHERE excluida_em IS NULL GROUP BY NVL(regiao_id,0),status;
CREATE OR REPLACE VIEW V_NV_ESTOQUE AS
 SELECT NVL(regiao_id,0) AS "regiaoId",SUM(capacidade_litros) AS "capacidadeLitros",
 SUM(estoque_litros) AS "estoqueLitros",COUNT(*) AS pontos FROM NV_PONTO_AGUA
 WHERE status<>'FECHADO' GROUP BY NVL(regiao_id,0);
CREATE OR REPLACE PACKAGE PKG_NV_RELATORIOS AS
 PROCEDURE PRC_EXPORTAR_SOLICITACOES(p_json OUT CLOB);
 PROCEDURE PRC_EXPORTAR_PONTOS(p_json OUT CLOB);
END PKG_NV_RELATORIOS;
/
CREATE OR REPLACE PACKAGE BODY PKG_NV_RELATORIOS AS
 PROCEDURE PRC_EXPORTAR_SOLICITACOES(p_json OUT CLOB) IS
 BEGIN
  SELECT COALESCE(JSON_ARRAYAGG(JSON_OBJECT(
   'id' VALUE s.id,'tipo' VALUE s.tipo,'descricao' VALUE s.descricao,
   'quantidadePessoas' VALUE s.quantidade_pessoas,'urgencia' VALUE s.urgencia,
   'grupoVulneravel' VALUE CASE s.grupo_vulneravel WHEN 1 THEN 'true' ELSE 'false' END FORMAT JSON,
   'endereco' VALUE s.endereco,'cidade' VALUE s.cidade,'latitude' VALUE s.latitude,'longitude' VALUE s.longitude,
   'status' VALUE s.status,'prioridade' VALUE s.prioridade,
   'criadaEm' VALUE TO_CHAR(SYS_EXTRACT_UTC(s.criada_em),'YYYY-MM-DD"T"HH24:MI:SS.FF3"Z"'),
   'atualizadaEm' VALUE TO_CHAR(SYS_EXTRACT_UTC(s.atualizada_em),'YYYY-MM-DD"T"HH24:MI:SS.FF3"Z"'),
   'excluidaEm' VALUE TO_CHAR(SYS_EXTRACT_UTC(s.excluida_em),'YYYY-MM-DD"T"HH24:MI:SS.FF3"Z"'),
   'solicitante' VALUE JSON_OBJECT('id' VALUE u.id,'nome' VALUE u.nome),
   'cadastradaPorId' VALUE s.cadastrada_por_id,
   'regiao' VALUE CASE WHEN r.id IS NOT NULL THEN JSON_OBJECT('id' VALUE r.id,'nome' VALUE r.nome,
      'cidade' VALUE r.cidade,'nivelRisco' VALUE r.nivel_risco) ELSE 'null' END FORMAT JSON,
   'historico' VALUE COALESCE((SELECT JSON_ARRAYAGG(JSON_OBJECT('id' VALUE h.id,'equipeId' VALUE h.equipe_id,
     'statusAnterior' VALUE h.status_anterior,'statusNovo' VALUE h.status_novo,'motivo' VALUE h.motivo,
     'registradaEm' VALUE TO_CHAR(SYS_EXTRACT_UTC(h.registrada_em),'YYYY-MM-DD"T"HH24:MI:SS.FF3"Z"')
     RETURNING CLOB) ORDER BY h.id RETURNING CLOB) FROM NV_HISTORICO_STATUS h WHERE h.solicitacao_id=s.id),TO_CLOB('[]')) FORMAT JSON
   RETURNING CLOB) ORDER BY s.id RETURNING CLOB),TO_CLOB('[]')) INTO p_json
  FROM NV_SOLICITACAO s JOIN NV_USUARIO u ON u.id=s.solicitante_id LEFT JOIN NV_REGIAO r ON r.id=s.regiao_id;
 END;
 PROCEDURE PRC_EXPORTAR_PONTOS(p_json OUT CLOB) IS
 BEGIN
  SELECT COALESCE(JSON_ARRAYAGG(JSON_OBJECT('id' VALUE p.id,'nome' VALUE p.nome,'tipo' VALUE p.tipo,
   'endereco' VALUE p.endereco,'cidade' VALUE p.cidade,'status' VALUE p.status,
   'capacidadeLitros' VALUE p.capacidade_litros,'estoqueLitros' VALUE p.estoque_litros,
   'regiao' VALUE CASE WHEN r.id IS NOT NULL THEN JSON_OBJECT('id' VALUE r.id,'nome' VALUE r.nome,
    'cidade' VALUE r.cidade,'nivelRisco' VALUE r.nivel_risco) ELSE 'null' END FORMAT JSON
   RETURNING CLOB) ORDER BY p.id RETURNING CLOB),TO_CLOB('[]')) INTO p_json
  FROM NV_PONTO_AGUA p LEFT JOIN NV_REGIAO r ON r.id=p.regiao_id;
 END;
END PKG_NV_RELATORIOS;
/
