# Mapeamento relacional para documental

As collections são projeções de uma mesma exportação Oracle consistente. Não há sincronização contínua ou alteração do backend Java. Os JSON são os bytes exportados pelo pacote PL/SQL; o importador apenas adiciona `_id` e converte datas em BSON Date.

| Origem Oracle | Destino documental | Conversão / motivo |
|---|---|---|
| NV_SOLICITACAO.id | solicitacoes._id e id | NUMBER → número; unicidade por origem |
| tipo, descricao, quantidade_pessoas, urgencia | tipo, descricao, quantidadePessoas, urgencia | Valores preservados; nomes camelCase |
| grupo_vulneravel | grupoVulneravel | 0/1 → false/true pelo SQL JSON |
| endereco, cidade, latitude, longitude | Campos homônimos | Nulos mantidos |
| status, prioridade | Campos homônimos | Cálculos realizados no Oracle; MongoDB não recalcula |
| criada_em, atualizada_em, excluida_em | criadaEm, atualizadaEm, excluidaEm | UTC ISO com milissegundos → Date/null |
| solicitante_id + NV_USUARIO.nome | solicitante { id, nome } | Identificação mínima incorporada; sem dados de autenticação |
| cadastrada_por_id | cadastradaPorId | ID de referência de equipe ou null |
| regiao_id + NV_REGIAO | regiao { id, nome, cidade, nivelRisco } | Projeção incorporada, ou null |
| NV_HISTORICO_STATUS WHERE solicitacao_id = id | historico[] | Ordem por id; equipeId, estados, motivo e data |
| NV_PONTO_AGUA.id | pontos_agua._id e id | NUMBER → número |
| capacidade_litros, estoque_litros | capacidadeLitros, estoqueLitros | Quantidades inteiras em litros |
| NV_PONTO_AGUA nome/tipo/endereco/cidade/status | Campos homônimos | Documentos com ciclo próprio |
| NV_AUDITORIA | Continua no Oracle | Registro completo transacional e histórico de DELETE |
| NV_USUARIO.ativo/papel, NV_REGIAO.populacao_afetada, NV_SOLICITACAO.versao | Não exportados | Controle operacional Oracle fora da projeção de leitura |

## Referências e incorporação

Solicitação é um agregado de leitura: solicitante mínimo, região e histórico acompanham o pedido. Pontos de água ficam separados porque têm estoque e ciclo de vida próprios. Não existe FK entre um ponto e uma solicitação no modelo aprovado: a região é o vínculo territorial comum, sem inventar uma alocação de entregas que o Java não possui.

A redundância de região é intencional e corresponde ao instante da exportação. Mudar uma região no Oracle requer nova exportação/importação para atualizar sua cópia no MongoDB. `equipeId` e `cadastradaPorId` preservam referências de origem; não há uma terceira collection de usuários. A equipe pode consultar o Oracle para resolver esses IDs. Não se afirma integridade referencial automática entre bancos.

## Equivalência dos relatórios

| Nome | Filtro | Chave / ordenação |
|---|---|---|
| fila | ABERTA ou EM_ATENDIMENTO; excluida_em/excluidaEm null | prioridade DESC, id ASC; regiaoId null se ausente |
| demanda | Somente pedidos sem exclusão lógica, incluindo cancelados | regiaoId ausente = 0; status; COUNT |
| estoque | status diferente de FECHADO | regiaoId ausente = 0; SUM capacidade/estoque; COUNT pontos |

`mongodb/04_validar.js` lê o resultado Oracle exportado na mesma transação dos datasets, confere cada campo dos 24 documentos, executa as consultas reais MongoDB e compara as linhas completas e ordenadas. SHA-256 usa chaves de objetos ordenadas; arrays mantêm a ordem. Reimportação deve produzir o mesmo snapshot.
