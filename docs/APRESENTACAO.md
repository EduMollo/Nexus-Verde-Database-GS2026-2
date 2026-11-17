# Roteiro da apresentação presencial

Apresentação entre 23 e 27/11, durante a aula da disciplina. Todos devem compreender o modelo, os pacotes e a transição. Distribuição sugerida dos seis itens de 5 pontos; pode ser ajustada pelo grupo conforme o tempo do professor.

| Momento | Demonstrar | Arquivo / comando |
|---|---|---|
| 1. Problema e modelo | Cidadãos sem abastecimento; equipe prioriza pedidos; 6 tabelas e relacionamentos | Modelo lógico e físico em PDF |
| 2. Função e procedimento | Calcular prioridade; criar pedido; mudar status com equipe | SQL Developer: `sql/08_consultas_apresentacao.sql` |
| 3. Gatilhos e pacotes | Mostrar specification/body; prioridade recalculada; auditoria antiga/nova e rollback | Mesmo SQL; `sql/07_testes.sql` |
| 4. Collections e dados | Selecionar database; criar duas collections; importar 24 documentos Oracle | `mongodb/02_importar.js` no mongosh |
| 5. Relatórios | Fila, demanda e estoque; mostrar resultados e hashes iguais | `mongodb/04_validar.js`; `evidencias/validacao_mongodb.json` |
| 6. Justificativa | Incorporação, referências, snapshot e consistência | `docs/MAPEAMENTO.md` |

## Preparar antes da aula

1. Na mesma pasta do projeto, executar `.\executar-oracle.ps1 all` com rede FIAP disponível. Em instalação já existente os dados são preservados.
2. Iniciar Docker (`docker compose up -d --wait`) ou um MongoDB local e mongosh. Nesta máquina a alternativa é `.\iniciar-mongodb-local.ps1`.
3. Executar o teste MongoDB depois da exportação Oracle: `.\executar-mongodb.ps1 test` (ou `docker compose exec -T mongodb mongosh --quiet --file mongodb/04_validar.js`).
4. Conferir a mensagem APROVADO, PDFs e TXT de integrantes. Não abrir `.env` durante a apresentação.

## Demonstração sem alterar a carga

Abrir `sql/08_consultas_apresentacao.sql` no SQL Developer e executar F5. O bloco cria um pedido temporário, mostra a prioridade/auditoria, altera o status e executa ROLLBACK. Nenhuma mudança de demonstração permanece; o contador de identidade pode avançar.

No mongosh, a partir da raiz do projeto:

```javascript
use nexus_verde_gs2026
load('mongodb/02_importar.js')
db.solicitacoes.countDocuments({})
db.pontos_agua.countDocuments({})
load('mongodb/03_relatorios.js')
load('mongodb/04_validar.js')
```

Na primeira carga de um database vazio, o script executa createCollection e insertMany. Em uma base já preparada, ele preserva a estrutura e reimporta por ID. Para mostrar a primeira criação, usar ambiente vazio preparado previamente; não apagar dados durante a aula.

## Respostas que o grupo deve dominar

- **Por que três pacotes?** Solicitações concentra regras; auditoria registra imagens; relatórios produz projeções. Facilita reutilização e alteração localizada.
- **Como funciona a prioridade?** Base de 10/30/50/70 + até 10 pessoas + 15 vulnerabilidade + 5 água contaminada, limitada a 100. Exemplo: ALTA, 5 pessoas, vulnerável e água contaminada = 75.
- **Como evitam status inválido?** Função de transição é chamada pela procedure e pelo trigger. A procedure bloqueia a linha com FOR UPDATE e registra a equipe/histórico.
- **Por que auditoria não tem FK?** Para poder manter a imagem de um pedido removido. A operação e os valores são da mesma transação; rollback também desfaz auditoria.
- **O usuário da auditoria é o cidadão?** Não. É a conta Oracle executora. O responsável operacional da mudança de status é equipe_id no histórico.
- **Por que incorporar e não usar joins?** Cada pedido é lido com seu contexto e histórico. Pontos de água têm ciclo próprio e são outra collection.
- **Está sincronizado ao vivo?** Não. É uma exportação consistente, seguida de importação por scripts; o PDF não exige sincronização automática.
- **Como provam a equivalência?** Comparação de todos os campos importados, resultados completos dos três relatórios, ordenação determinística e hashes iguais.
- **O que o teste não comprova?** Não é teste de carga/produção nem uma migração integral do Java; o escopo é a entrega Oracle/MongoDB do PDF.

O PDF de Database não exige vídeo. O grupo ainda deve enviar o ZIP no Portal FIAP até 19/11 às 23h55 e realizar a apresentação presencial.
