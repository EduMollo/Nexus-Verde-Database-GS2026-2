CREATE OR REPLACE PACKAGE PKG_NV_SOLICITACOES AS
 FUNCTION FN_CALCULAR_PRIORIDADE(p_urgencia VARCHAR2,p_pessoas NUMBER,p_vulneravel NUMBER,p_tipo VARCHAR2) RETURN NUMBER;
 FUNCTION FN_TRANSICAO_PERMITIDA(p_anterior VARCHAR2,p_novo VARCHAR2) RETURN NUMBER;
 PROCEDURE PRC_VALIDAR(p_solicitante NUMBER,p_regiao NUMBER,p_cidade VARCHAR2,p_cadastrada_por NUMBER);
 PROCEDURE PRC_CRIAR_SOLICITACAO(p_solicitante NUMBER,p_regiao NUMBER,p_tipo VARCHAR2,p_descricao VARCHAR2,
  p_pessoas NUMBER,p_urgencia VARCHAR2,p_vulneravel NUMBER,p_endereco VARCHAR2,p_cidade VARCHAR2,
  p_id OUT NUMBER,p_cadastrada_por NUMBER DEFAULT NULL);
 PROCEDURE PRC_ALTERAR_STATUS(p_id NUMBER,p_equipe NUMBER,p_status VARCHAR2,p_motivo VARCHAR2 DEFAULT NULL);
END PKG_NV_SOLICITACOES;
/
CREATE OR REPLACE PACKAGE BODY PKG_NV_SOLICITACOES AS
 FUNCTION FN_CALCULAR_PRIORIDADE(p_urgencia VARCHAR2,p_pessoas NUMBER,p_vulneravel NUMBER,p_tipo VARCHAR2) RETURN NUMBER IS
  v_base NUMBER;
 BEGIN
  IF p_urgencia IS NULL OR p_urgencia NOT IN ('BAIXA','MEDIA','ALTA','CRITICA') OR
     p_pessoas IS NULL OR p_pessoas<=0 OR p_pessoas<>TRUNC(p_pessoas) OR
     p_vulneravel IS NULL OR p_vulneravel NOT IN (0,1) OR
     p_tipo IS NULL OR p_tipo NOT IN ('FALTA_DE_AGUA','AGUA_CONTAMINADA','ENTREGA_DE_AGUA','OUTRO') THEN
   RAISE_APPLICATION_ERROR(-20101,'Parametros invalidos para prioridade');
  END IF;
  v_base:=CASE p_urgencia WHEN 'BAIXA' THEN 10 WHEN 'MEDIA' THEN 30 WHEN 'ALTA' THEN 50 ELSE 70 END;
  RETURN LEAST(100,v_base+LEAST(p_pessoas,10)+15*p_vulneravel+CASE WHEN p_tipo='AGUA_CONTAMINADA' THEN 5 ELSE 0 END);
 END;
 FUNCTION FN_TRANSICAO_PERMITIDA(p_anterior VARCHAR2,p_novo VARCHAR2) RETURN NUMBER IS
 BEGIN
  IF p_anterior IS NULL OR p_novo IS NULL OR
   p_anterior NOT IN ('ABERTA','EM_ATENDIMENTO','ATENDIDA','CANCELADA') OR
   p_novo NOT IN ('ABERTA','EM_ATENDIMENTO','ATENDIDA','CANCELADA') THEN RETURN 0; END IF;
  IF p_anterior=p_novo OR (p_anterior='ABERTA' AND p_novo IN ('EM_ATENDIMENTO','CANCELADA')) OR
   (p_anterior='EM_ATENDIMENTO' AND p_novo IN ('ATENDIDA','CANCELADA')) THEN RETURN 1; END IF;
  RETURN 0;
 END;
 PROCEDURE PRC_VALIDAR(p_solicitante NUMBER,p_regiao NUMBER,p_cidade VARCHAR2,p_cadastrada_por NUMBER) IS
  v_qtd NUMBER;
 BEGIN
  SELECT COUNT(*) INTO v_qtd FROM NV_USUARIO WHERE id=p_solicitante AND papel='CIDADAO' AND ativo=1;
  IF v_qtd<>1 THEN RAISE_APPLICATION_ERROR(-20102,'Cidadao ativo inexistente'); END IF;
  IF TRIM(p_cidade) IS NULL THEN RAISE_APPLICATION_ERROR(-20103,'Cidade obrigatoria'); END IF;
  IF p_regiao IS NOT NULL THEN
   SELECT COUNT(*) INTO v_qtd FROM NV_REGIAO WHERE id=p_regiao AND UPPER(cidade)=UPPER(TRIM(p_cidade));
   IF v_qtd<>1 THEN RAISE_APPLICATION_ERROR(-20103,'Regiao inexistente ou de outra cidade'); END IF;
  END IF;
  IF p_cadastrada_por IS NOT NULL THEN
   SELECT COUNT(*) INTO v_qtd FROM NV_USUARIO WHERE id=p_cadastrada_por AND papel='EQUIPE' AND ativo=1;
   IF v_qtd<>1 THEN RAISE_APPLICATION_ERROR(-20104,'Equipe ativa inexistente'); END IF;
  END IF;
 END;
 PROCEDURE PRC_CRIAR_SOLICITACAO(p_solicitante NUMBER,p_regiao NUMBER,p_tipo VARCHAR2,p_descricao VARCHAR2,
  p_pessoas NUMBER,p_urgencia VARCHAR2,p_vulneravel NUMBER,p_endereco VARCHAR2,p_cidade VARCHAR2,
  p_id OUT NUMBER,p_cadastrada_por NUMBER DEFAULT NULL) IS
  v_regiao NUMBER:=p_regiao; v_qtd NUMBER;
 BEGIN
  IF TRIM(p_descricao) IS NULL OR TRIM(p_endereco) IS NULL OR TRIM(p_cidade) IS NULL THEN
   RAISE_APPLICATION_ERROR(-20105,'Descricao, endereco e cidade obrigatorios'); END IF;
  IF v_regiao IS NULL THEN
   SELECT COUNT(*),MIN(id) INTO v_qtd,v_regiao FROM NV_REGIAO WHERE UPPER(cidade)=UPPER(TRIM(p_cidade));
   IF v_qtd<>1 THEN v_regiao:=NULL; END IF;
  END IF;
  PRC_VALIDAR(p_solicitante,v_regiao,p_cidade,p_cadastrada_por);
  INSERT INTO NV_SOLICITACAO(solicitante_id,regiao_id,cadastrada_por_id,tipo,descricao,quantidade_pessoas,
   urgencia,grupo_vulneravel,endereco,cidade,status,prioridade)
  VALUES(p_solicitante,v_regiao,p_cadastrada_por,p_tipo,TRIM(p_descricao),p_pessoas,p_urgencia,
   p_vulneravel,TRIM(p_endereco),TRIM(p_cidade),'ABERTA',FN_CALCULAR_PRIORIDADE(p_urgencia,p_pessoas,p_vulneravel,p_tipo))
  RETURNING id INTO p_id;
 EXCEPTION WHEN VALUE_ERROR THEN RAISE_APPLICATION_ERROR(-20105,'Valor invalido na criacao da solicitacao');
 END;
 PROCEDURE PRC_ALTERAR_STATUS(p_id NUMBER,p_equipe NUMBER,p_status VARCHAR2,p_motivo VARCHAR2 DEFAULT NULL) IS
  v_anterior NV_SOLICITACAO.status%TYPE; v_qtd NUMBER;
 BEGIN
  SELECT COUNT(*) INTO v_qtd FROM NV_USUARIO WHERE id=p_equipe AND papel='EQUIPE' AND ativo=1;
  IF v_qtd<>1 THEN RAISE_APPLICATION_ERROR(-20104,'Equipe ativa inexistente'); END IF;
  SELECT status INTO v_anterior FROM NV_SOLICITACAO WHERE id=p_id AND excluida_em IS NULL FOR UPDATE;
  IF FN_TRANSICAO_PERMITIDA(v_anterior,p_status)=0 THEN RAISE_APPLICATION_ERROR(-20106,'Transicao de status invalida'); END IF;
  IF v_anterior=p_status THEN RETURN; END IF;
  IF p_status='CANCELADA' AND TRIM(p_motivo) IS NULL THEN RAISE_APPLICATION_ERROR(-20107,'Cancelamento pela equipe exige motivo'); END IF;
  IF LENGTH(p_motivo)>400 THEN RAISE_APPLICATION_ERROR(-20107,'Motivo deve ter ate 400 caracteres'); END IF;
  UPDATE NV_SOLICITACAO SET status=p_status WHERE id=p_id;
  INSERT INTO NV_HISTORICO_STATUS(solicitacao_id,equipe_id,status_anterior,status_novo,motivo)
   VALUES(p_id,p_equipe,v_anterior,p_status,TRIM(p_motivo));
 EXCEPTION WHEN NO_DATA_FOUND THEN RAISE_APPLICATION_ERROR(-20108,'Solicitacao inexistente ou excluida');
 END;
END PKG_NV_SOLICITACOES;
/
