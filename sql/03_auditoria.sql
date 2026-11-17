CREATE OR REPLACE PACKAGE PKG_NV_AUDITORIA AS
 PROCEDURE PRC_REGISTRAR(p_id NUMBER,p_operacao VARCHAR2,p_antigo CLOB,p_novo CLOB);
END PKG_NV_AUDITORIA;
/
CREATE OR REPLACE PACKAGE BODY PKG_NV_AUDITORIA AS
 PROCEDURE PRC_REGISTRAR(p_id NUMBER,p_operacao VARCHAR2,p_antigo CLOB,p_novo CLOB) IS
 BEGIN
  IF p_operacao IS NULL OR p_operacao NOT IN ('INSERT','UPDATE','DELETE') THEN
   RAISE_APPLICATION_ERROR(-20109,'Operacao de auditoria invalida'); END IF;
  INSERT INTO NV_AUDITORIA(solicitacao_id,operacao,usuario_banco,valores_antigos,valores_novos)
   VALUES(p_id,p_operacao,SYS_CONTEXT('USERENV','SESSION_USER'),p_antigo,p_novo);
 END;
END PKG_NV_AUDITORIA;
/
CREATE OR REPLACE TRIGGER TRG_NV_VALIDAR_SOLIC
BEFORE INSERT OR UPDATE ON NV_SOLICITACAO FOR EACH ROW
BEGIN
 IF INSERTING THEN
  IF :NEW.status<>'ABERTA' THEN RAISE_APPLICATION_ERROR(-20106,'Solicitacao deve iniciar aberta'); END IF;
 ELSE
  IF PKG_NV_SOLICITACOES.FN_TRANSICAO_PERMITIDA(:OLD.status,:NEW.status)=0 THEN
   RAISE_APPLICATION_ERROR(-20106,'Transicao de status invalida'); END IF;
  :NEW.versao:=:OLD.versao+1;
 END IF;
 -- Revalidar identidade/localizacao na criacao ou quando esses vinculos mudarem.
 IF INSERTING OR :NEW.solicitante_id<>:OLD.solicitante_id OR
  NVL(:NEW.regiao_id,-1)<>NVL(:OLD.regiao_id,-1) OR :NEW.cidade<>:OLD.cidade OR
  NVL(:NEW.cadastrada_por_id,-1)<>NVL(:OLD.cadastrada_por_id,-1) THEN
  PKG_NV_SOLICITACOES.PRC_VALIDAR(:NEW.solicitante_id,:NEW.regiao_id,:NEW.cidade,:NEW.cadastrada_por_id);
 END IF;
 :NEW.prioridade:=PKG_NV_SOLICITACOES.FN_CALCULAR_PRIORIDADE(:NEW.urgencia,:NEW.quantidade_pessoas,:NEW.grupo_vulneravel,:NEW.tipo);
 :NEW.atualizada_em:=SYSTIMESTAMP;
END;
/
CREATE OR REPLACE TRIGGER TRG_NV_AUDITAR_SOLIC
AFTER INSERT OR UPDATE OR DELETE ON NV_SOLICITACAO FOR EACH ROW
DECLARE v_antigo CLOB; v_novo CLOB; v_op VARCHAR2(6);
BEGIN
 IF INSERTING THEN v_op:='INSERT'; ELSIF UPDATING THEN v_op:='UPDATE'; ELSE v_op:='DELETE'; END IF;
 IF UPDATING OR DELETING THEN
  SELECT JSON_OBJECT('id' VALUE :OLD.id,'solicitanteId' VALUE :OLD.solicitante_id,'regiaoId' VALUE :OLD.regiao_id,
   'cadastradaPorId' VALUE :OLD.cadastrada_por_id,'tipo' VALUE :OLD.tipo,'descricao' VALUE :OLD.descricao,
   'quantidadePessoas' VALUE :OLD.quantidade_pessoas,'urgencia' VALUE :OLD.urgencia,
   'grupoVulneravel' VALUE :OLD.grupo_vulneravel,'endereco' VALUE :OLD.endereco,'cidade' VALUE :OLD.cidade,
   'latitude' VALUE :OLD.latitude,'longitude' VALUE :OLD.longitude,'status' VALUE :OLD.status,
   'prioridade' VALUE :OLD.prioridade,'criadaEm' VALUE :OLD.criada_em,'atualizadaEm' VALUE :OLD.atualizada_em,
   'excluidaEm' VALUE :OLD.excluida_em,'versao' VALUE :OLD.versao RETURNING CLOB) INTO v_antigo FROM dual;
 END IF;
 IF INSERTING OR UPDATING THEN
  SELECT JSON_OBJECT('id' VALUE :NEW.id,'solicitanteId' VALUE :NEW.solicitante_id,'regiaoId' VALUE :NEW.regiao_id,
   'cadastradaPorId' VALUE :NEW.cadastrada_por_id,'tipo' VALUE :NEW.tipo,'descricao' VALUE :NEW.descricao,
   'quantidadePessoas' VALUE :NEW.quantidade_pessoas,'urgencia' VALUE :NEW.urgencia,
   'grupoVulneravel' VALUE :NEW.grupo_vulneravel,'endereco' VALUE :NEW.endereco,'cidade' VALUE :NEW.cidade,
   'latitude' VALUE :NEW.latitude,'longitude' VALUE :NEW.longitude,'status' VALUE :NEW.status,
   'prioridade' VALUE :NEW.prioridade,'criadaEm' VALUE :NEW.criada_em,'atualizadaEm' VALUE :NEW.atualizada_em,
   'excluidaEm' VALUE :NEW.excluida_em,'versao' VALUE :NEW.versao RETURNING CLOB) INTO v_novo FROM dual;
 END IF;
 PKG_NV_AUDITORIA.PRC_REGISTRAR(NVL(:NEW.id,:OLD.id),v_op,v_antigo,v_novo);
END;
/
