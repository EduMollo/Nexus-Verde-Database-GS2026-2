-- SQL Developer: executar como script (F5) em esquema SEM objetos NV_.
-- DDL Oracle tem commit implicito. Nao repetir sobre instalacao parcial.
WHENEVER SQLERROR EXIT FAILURE ROLLBACK
SET SERVEROUTPUT ON SIZE UNLIMITED
DECLARE v_total NUMBER;
BEGIN
 SELECT COUNT(*) INTO v_total FROM user_objects
 WHERE object_name LIKE 'NV\_%' ESCAPE '\' OR object_name LIKE 'PKG_NV\_%' ESCAPE '\'
 OR object_name LIKE 'TRG_NV\_%' ESCAPE '\' OR object_name LIKE 'V_NV\_%' ESCAPE '\';
 IF v_total>0 THEN RAISE_APPLICATION_ERROR(-20901,'Objetos NV_ ja existem; preservar instalacao'); END IF;
END;
/
@@01_estrutura.sql
@@02_solicitacoes.sql
@@03_auditoria.sql
@@04_relatorios.sql
@@05_carga.sql
COMMIT;
@@06_blocos.sql
@@07_testes.sql
