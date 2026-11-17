# Nexus Verde - Database GS 2026/2

CitizenTech para organizar pedidos de acesso a água potável e localizar pontos de distribuição durante interrupções e catástrofes. O cidadão registra sua necessidade; a equipe prioriza e acompanha o atendimento. Esta entrega implementa as regras em **Oracle 19c / PL/SQL** e representa parte dos mesmos dados no **MongoDB**.

[Repositório](https://github.com/EduMollo/Nexus-Verde-Database-GS2026-2) | [Java de referência](https://github.com/EduMollo/Nexus-Verde-Java-GS2026-2/tree/d8715e9e0348f17c4acd70d3d1405385c5921bae)

## Equipe - 2TDSPF

| Integrante | RM |
|---|---|
| Carlos Alberto Guedes Neto | 566022 |
| Eduardo Novaes Mollo | 561515 |
| Luan Peixoto Marins Rocha | 562258 |
| Mathaus Victor Souza Marcelino | 564146 |
| Vinicius Luis Exposito Morassi | 563340 |

## Resultado validado

Execução real em 17/11/2026 na conta Oracle FIAP e MongoDB Community 8.0.5: **17 objetos Oracle principais válidos**, sem erros de compilação; **16 solicitações + 8 pontos de água** importados; conteúdo completo e reimportação conferidos; **3 relatórios iguais**. Veja `evidencias/` para saídas e hashes. Todos os nomes, endereços e dados quantitativos da carga são fictícios; não representam um levantamento real das cidades.

| Critério do PDF, páginas 71-76 | Implementação | Evidência |
|---|---|---|
| Modelo e 2 blocos PL/SQL (10) | 6 tabelas relacionadas; `sql/01_estrutura.sql`, `06_blocos.sql` | Modelos em `docs/`; `testes_oracle.txt` |
| 2 funções e 2 procedimentos (15) | Prioridade, transições, criação, alteração de status | `02_solicitacoes.sql`, `07_testes.sql` |
| 2 gatilhos e auditoria (10) | Validação/prioridade e auditoria de INSERT/UPDATE/DELETE | `03_auditoria.sql`, teste de valores antigo/novo e rollback |
| 2 pacotes com spec/body e testes (10) | 3 pacotes: solicitações, auditoria, relatórios | `objetos_oracle.json`, `testes_oracle.txt` |
| 2 collections e 10+ documentos (10) | 2 collections; 24 documentos; createCollection/insertMany | `mongodb/01_estrutura.js`, `02_importar.js` |
| Mapeamento e 3 relatórios (15) | find + 2 aggregates equivalentes a views Oracle | `docs/MAPEAMENTO.md`, `validacao_mongodb.json` |
| Apresentação presencial (30) | Roteiro com demonstrações e perguntas | `docs/APRESENTACAO.md` |

O PDF da GS é a regra de avaliação. A GS não exige integração automática Oracle-MongoDB ou chamada de procedures pelo backend Java. Os scripts JDBC desta entrega chamam as procedures Oracle de fato. O backend Java continua independente, usando PostgreSQL/H2. A estrutura de organização da CS4 foi usada como referência, adaptada ao domínio Nexus Verde.

## Execução Oracle

Requisitos: **JDK 21**, acesso de rede ao Oracle FIAP 19c e driver oficial `ojdbc11`. Não usar senhas no terminal, no Git ou em arquivos de entrega.

Na primeira execução:

```powershell
.\configurar-oracle.ps1
.\executar-oracle.ps1 check
.\executar-oracle.ps1 all
```

O configurador pede URL/usuário/senha e cria `.env` local ignorado pelo Git. Se `.env` já existe, use a configuração existente. `DB_URL`, `DB_USERNAME` e `DB_PASSWORD` no ambiente têm precedência. O executor procura o driver no cache Maven. Se necessário, baixe `com.oracle.database.jdbc:ojdbc11:21.9.0.0` do Maven Central e defina `ORACLE_JDBC_JAR` para o caminho do JAR oficial.

```powershell
$env:ORACLE_JDBC_JAR = 'C:\caminho\ojdbc11-21.9.0.0.jar'
.\executar-oracle.ps1 all
```

| Ação | Comportamento |
|---|---|
| `check` | Apenas conecta; não altera dados |
| `install` | Cria estrutura, pacotes, gatilhos e views em instalação nova |
| `compile` | Recompila pacotes, gatilhos e views, sem repetir DDL das tabelas |
| `seed` | Insere a carga se todas as seis tabelas estiverem vazias |
| `test` | Executa testes e dois blocos; desfaz as alterações dos testes |
| `export` | Exporta JSON e relatórios de uma mesma transação Oracle somente leitura |
| `all` | Instala se necessário, preserva carga existente, testa e exporta |

Nenhum comando apaga objetos. A instalação recusa nomes já ocupados ou estrutura parcial. DDL Oracle possui commit implícito: se uma instalação falhar, revisar o erro antes de continuar; não executar DROP em objetos da CS4. Os objetos desta entrega possuem `NV_`, `PKG_NV_`, `TRG_NV_` e `V_NV_`.

No SQL Developer, para esquema novo, abrir `sql/instalar.sql` e executar como script (F5). Para instalação existente, executar `sql/07_testes.sql` e `06_blocos.sql` como script. A exportação para arquivos é feita pelo executor JDBC, chamando `PKG_NV_RELATORIOS` com parâmetro CLOB de saída.

Os testes usam SAVEPOINT e ROLLBACK, inclusive para auditoria. Sequências de identidade Oracle podem avançar apesar do rollback: lacunas de IDs são normais. Não há COMMIT nem transação autônoma dentro das regras e gatilhos.

## Execução MongoDB

Opção A, com Docker Desktop iniciado:

```powershell
docker compose up -d --wait
docker compose exec -T mongodb mongosh --quiet --file mongodb/04_validar.js
```

Opção B, com MongoDB e mongosh instalados, executar na raiz do projeto:

```powershell
$env:MONGODB_URI = 'mongodb://127.0.0.1:27017'
.\executar-mongodb.ps1 test
```

`MONGOSH_EXE` permite informar o caminho completo do shell. As ações são `import`, `report` e `test`. Os scripts usam `db.getSiblingDB('nexus_verde_gs2026')`, equivalente ao comando interativo `use nexus_verde_gs2026`. Não há credenciais nos scripts.

Nesta máquina também há uma execução portátil preparada para a apresentação:

```powershell
.\iniciar-mongodb-local.ps1
.\executar-mongodb.ps1 test
```

O iniciador usa os executáveis já disponíveis em `.cache/mongodb`, porta **27019**, restrita ao próprio computador; essa pasta não entra no ZIP. Em outro computador, usar a opção Docker ou instalar MongoDB/mongosh oficiais. A carga inicial usa `insertMany`; reexecuções usam substituição/upsert pelo ID Oracle. O importador recusa documentos com IDs fora do snapshot e estruturas incompatíveis, sem apagar coleções.

## Modelo e regras

`NV_USUARIO` identifica cidadão/equipe e situação ativa. `NV_REGIAO` organiza o território. `NV_PONTO_AGUA` guarda capacidade/estoque. `NV_SOLICITACAO` contém o pedido e sua prioridade. `NV_HISTORICO_STATUS` registra responsável e motivo. `NV_AUDITORIA` guarda uma imagem JSON completa da solicitação antes/depois de cada DML.

O recorte Oracle preserva as regras principais do Java no commit de referência; não é uma migração integral do backend. Autenticação, senha, JWT, análise de IA e identificador de requisição do painel ficam fora desta entrega de Database.

**Prioridade** = mínimo entre 100 e: base da urgência (BAIXA 10 / MEDIA 30 / ALTA 50 / CRITICA 70) + mínimo entre pessoas e 10 + 15 se grupo vulnerável + 5 se água contaminada.

**Status:** ABERTA → EM_ATENDIMENTO ou CANCELADA; EM_ATENDIMENTO → ATENDIDA ou CANCELADA. Estados finais não reabrem. Repetir o status atual não cria histórico nem uma nova atualização. A operação de equipe exige usuário EQUIPE ativo; cancelamento exige motivo de até 400 caracteres.

**Criação:** cidadão ativo, descrição/endereço/cidade obrigatórios e quantidade de pessoas inteira positiva. Região informada deve pertencer à cidade. Sem região explícita, só há associação automática quando existe exatamente uma região na cidade. Estoque nunca pode ser negativo ou maior que a capacidade.

**Auditoria:** gatilho AFTER registra INSERT, UPDATE e DELETE com data, usuário Oracle e valores antigos/novos em CLOB JSON. Não há FK da auditoria para solicitação, permitindo preservar a evidência de DELETE. Histórico tem FK e impede apagar pedido com histórico sem tratá-lo antes. A trilha é transacional; rollback também desfaz auditoria. O usuário registrado é a conta do banco, não uma identidade autenticada do aplicativo. Mudanças de status operacionais devem usar o pacote para registrar equipe e histórico.

## Transição e relatórios

O Oracle exporta `dataset/solicitacoes.json` e `dataset/pontos_agua.json`. Datas são UTC ISO 8601 e tornam-se BSON Date no importador. O campo `_id` MongoDB recebe o `id` Oracle; o campo `id` também permanece para comparação.

| Oracle | MongoDB | Decisão |
|---|---|---|
| NV_SOLICITACAO + NV_USUARIO | solicitacoes + solicitante incorporado | Leitura do pedido com identificação mínima |
| NV_REGIAO | regiao incorporada nas duas collections | Consulta territorial sem join; snapshot da exportação |
| NV_HISTORICO_STATUS | historico[] em solicitacoes | Histórico do agregado pedido; equipeId mantém origem |
| NV_PONTO_AGUA | pontos_agua | Ciclo de vida/consultas independentes do pedido |
| NV_AUDITORIA | Mantida no Oracle | Evidência transacional, sem duplicar no snapshot operacional |

As referências Oracle permanecem no banco relacional; o snapshot documental não se atualiza automaticamente. Se o nome de uma região mudar, exportar/importar novamente. Para históricos muito extensos em produção, seria necessário avaliar coleção própria e o limite de tamanho do documento; a amostra acadêmica incorpora o histórico.

| Relatório | Oracle | MongoDB | Resultado validado |
|---|---|---|---|
| Fila de atendimento | V_NV_FILA, prioridade DESC/id ASC | find + sort | 8 pedidos, mesma ordem |
| Demanda por região/status | V_NV_DEMANDA, COUNT/GROUP BY | aggregate + $group/$sum | 16 grupos, 16 pedidos |
| Estoque por região | V_NV_ESTOQUE, SUM/GROUP BY | aggregate + $match/$group | 4 grupos; 28.500 L; 7 pontos abertos |

Pedidos excluídos logicamente não entram na fila nem na demanda. Demanda inclui cancelados sem exclusão lógica. Região ausente fica null na fila e 0 nas agregações. Pontos fechados não entram no estoque; pontos com estoque/capacidade zero entram. Ordenação de status usa comparação binária no MongoDB e valores enum maiúsculos no Oracle. A validação compara todas as linhas, ordenação e valores e registra SHA-256 de representações canônicas.

Consulte `sql/08_consultas_apresentacao.sql` para visualizar funções, objetos, auditoria e consultas equivalentes. `docs/APRESENTACAO.md` organiza a demonstração presencial de 23 a 27/11. O envio ao Portal FIAP deve ser realizado pelo grupo até **19/11/2026 às 23h55**.

## Evidências, documentação e pacote

- `evidencias/execucao_oracle.txt`: instalação e primeira execução real.
- `evidencias/testes_oracle.txt`: execução dos testes ampliados, sem persistir dados de teste.
- `evidencias/objetos_oracle.json`: situação dos 17 objetos principais.
- `evidencias/relatorios_oracle.json` e `relatorios_mongodb.json`: resultados completos.
- `evidencias/execucao_mongodb.txt` e `validacao_mongodb.json`: conteúdo, reimportação, validação e hashes dos três relatórios.
- `docs/Nexus-Verde-Modelo-Logico.pdf`, `Nexus-Verde-Modelo-Fisico.pdf`, `Nexus-Verde-Database-Documentacao.pdf`: modelos, dicionário, regras, execução, resultados e evidências.

Validação do material e geração do ZIP (Python 3.10+, somente biblioteca padrão):

```powershell
python tools/validar_entrega.py
python tools/empacotar.py
```

O ZIP exclui `.env`, `.git`, `.cache`, temporários e dependências locais. PDFs podem ser reproduzidos com `pip install -r tools/requirements-docs.txt` e `python tools/gerar_documentacao.py`. O CI executa MongoDB e verifica os arquivos entregues; os testes Oracle dependem da conexão FIAP e são comprovados nas evidências locais, sem divulgar credenciais no GitHub.

## Uso de IA generativa

ChatGPT/Codex apoiou a inspeção dos requisitos e do Java, adaptação dos scripts, implementação de testes, comparação de dados, revisão e documentação. Os resultados de execução automática estão em `evidencias/`. Cada integrante deve ler, revisar e compreender o código e as decisões antes da apresentação; a geração e a validação automática não substituem essa preparação.

## Referências

- Guia FIAP: Global Solution 2026/2 CitizenTech, páginas 71-76 (Database) e 15-17 (entrega/IA).
- [Java Nexus Verde, commit d8715e9](https://github.com/EduMollo/Nexus-Verde-Java-GS2026-2/tree/d8715e9e0348f17c4acd70d3d1405385c5921bae).
- [CS4 Database do grupo](https://github.com/EduMollo/EcoCreate-BD-Challenge-Sprint-2026-parte-4), referência de organização e execução, com domínio adaptado.
- [Oracle 19c - PL/SQL Language Reference](https://docs.oracle.com/en/database/oracle/oracle-database/19/lnpls/).
- [MongoDB - Schema Validation](https://www.mongodb.com/docs/manual/core/schema-validation/) e [Aggregation](https://www.mongodb.com/docs/manual/aggregation/).
