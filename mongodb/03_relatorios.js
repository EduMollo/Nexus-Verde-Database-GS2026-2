var dbNV = db.getSiblingDB('nexus_verde_gs2026');
// Consulta 1: find, projecao, filtro e ordenacao total; regiao ausente permanece null.
function relatoriosNV() {
  var fila = dbNV.solicitacoes.find({ status: { $in: ['ABERTA', 'EM_ATENDIMENTO'] }, excluidaEm: null },
    { _id: 0, id: 1, prioridade: 1, regiao: 1, urgencia: 1 }).sort({ prioridade: -1, id: 1 }).toArray()
    .map(s => ({ id: s.id, prioridade: s.prioridade, regiaoId: s.regiao ? s.regiao.id : null, urgencia: s.urgencia }));
  // Consulta 2: aggregate com agrupamento; chave 0 identifica regiao ausente nos dois bancos.
  var demanda = dbNV.solicitacoes.aggregate([
    { $match: { excluidaEm: null } },
    { $group: { _id: { regiaoId: { $ifNull: ['$regiao.id', 0] }, status: '$status' }, quantidade: { $sum: 1 } } },
    { $project: { _id: 0, regiaoId: '$_id.regiaoId', status: '$_id.status', quantidade: 1 } },
    { $sort: { regiaoId: 1, status: 1 } }
  ], { collation: { locale: 'simple' } }).toArray();
  // Consulta 3: estoques zerados entram; pontos fechados nao entram.
  var estoque = dbNV.pontos_agua.aggregate([
    { $match: { status: { $ne: 'FECHADO' } } },
    { $group: { _id: { $ifNull: ['$regiao.id', 0] }, capacidadeLitros: { $sum: '$capacidadeLitros' },
      estoqueLitros: { $sum: '$estoqueLitros' }, pontos: { $sum: 1 } } },
    { $project: { _id: 0, regiaoId: '$_id', capacidadeLitros: 1, estoqueLitros: 1, pontos: 1 } },
    { $sort: { regiaoId: 1 } }
  ]).toArray();
  return { fila, demanda, estoque };
}
var resultadosNV = relatoriosNV();
print(JSON.stringify(resultadosNV, null, 2));
