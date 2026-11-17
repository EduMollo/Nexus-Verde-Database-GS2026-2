load('mongodb/01_estrutura.js');
var fsNV = require('fs');
function documentosNV(nome) {
  var dados = JSON.parse(fsNV.readFileSync('dataset/' + nome + '.json', 'utf8'));
  if (!Array.isArray(dados) || dados.length === 0) throw Error('Dataset vazio: ' + nome);
  var ids = new Set();
  return dados.map(function (d) {
    if (!Number.isSafeInteger(d.id) || d.id < 1 || ids.has(d.id)) throw Error('ID Oracle invalido ou repetido');
    ids.add(d.id);
    var doc = { _id: d.id, ...d };
    for (var chave of ['criadaEm', 'atualizadaEm', 'excluidaEm']) if (doc[chave] != null) {
      doc[chave] = new Date(doc[chave]);
      if (isNaN(doc[chave].getTime())) throw Error('Data invalida: ' + chave);
    }
    if (doc.historico) doc.historico.forEach(h => { h.registradaEm = new Date(h.registradaEm); });
    return doc;
  });
}
// Valida ambos os arquivos antes de iniciar qualquer escrita de documentos.
var lotesNV = { solicitacoes: documentosNV('solicitacoes'), pontos_agua: documentosNV('pontos_agua') };
for (var nomeNV of Object.keys(lotesNV)) {
  var idsNV = lotesNV[nomeNV].map(d => d.id);
  if (dbNV.getCollection(nomeNV).countDocuments({ _id: { $nin: idsNV } }) > 0) {
    throw Error('Ha dados fora do snapshot Oracle em ' + nomeNV + '; nenhum documento sera removido.');
  }
}
for (var nomeNV of Object.keys(lotesNV)) {
  var collectionNV = dbNV.getCollection(nomeNV);
  if (collectionNV.countDocuments({}) === 0) {
    collectionNV.insertMany(lotesNV[nomeNV], { ordered: true });
  } else {
    collectionNV.bulkWrite(lotesNV[nomeNV].map(d => ({ replaceOne: { filter: { _id: d.id }, replacement: d, upsert: true } })), { ordered: true });
  }
  if (collectionNV.countDocuments({}) !== lotesNV[nomeNV].length) throw Error('Contagem divergente');
  print(nomeNV + ': ' + lotesNV[nomeNV].length + ' documentos; IDs Oracle preservados.');
}
