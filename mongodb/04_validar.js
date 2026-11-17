load('mongodb/02_importar.js');
load('mongodb/03_relatorios.js');
var cryptoNV = require('crypto');
function canonicoNV(v) {
  if (v instanceof Date) return v.toISOString();
  if (Array.isArray(v)) return v.map(canonicoNV);
  if (v && typeof v === 'object') return Object.fromEntries(Object.keys(v).sort().map(k => [k, canonicoNV(v[k])]));
  return v;
}
function igualNV(a, b, msg) {
  if (JSON.stringify(canonicoNV(a)) !== JSON.stringify(canonicoNV(b))) throw Error(msg);
}
function snapshotNV() {
  return Object.fromEntries(Object.keys(lotesNV).map(n => [n, dbNV.getCollection(n).find().sort({ id: 1 }).toArray()]));
}
// Confere cada campo, cada ID e cada data, alem das contagens.
for (var nomeNV of Object.keys(lotesNV)) {
  igualNV(dbNV.getCollection(nomeNV).find().sort({ id: 1 }).toArray(), lotesNV[nomeNV].slice().sort((a,b) => a.id-b.id),
    'Conteudo importado diferente do Oracle: ' + nomeNV);
}
var antesNV = snapshotNV();
load('mongodb/02_importar.js');
igualNV(antesNV, snapshotNV(), 'Reimportacao modificou o snapshot');
function rejeitaNV(doc, collection, codigo) {
  try { dbNV.getCollection(collection).insertOne(doc); }
  catch (e) { if (e.code === codigo) return; throw e; }
  dbNV.getCollection(collection).deleteOne({ _id: doc._id });
  throw Error('Documento invalido foi aceito');
}
rejeitaNV({ ...lotesNV.pontos_agua[0], _id: -1, id: -1, estoqueLitros: -1 }, 'pontos_agua', 121);
rejeitaNV({ ...lotesNV.pontos_agua[0], _id: -1, id: -1, estoqueLitros: 100000000 }, 'pontos_agua', 121);
rejeitaNV({ ...lotesNV.solicitacoes[0], _id: -1, id: -1, status: 'INVALIDO' }, 'solicitacoes', 121);
rejeitaNV({ ...lotesNV.solicitacoes[0] }, 'solicitacoes', 11000);
igualNV(antesNV, snapshotNV(), 'Teste alterou os documentos originais');
var oracleNV = JSON.parse(fsNV.readFileSync('evidencias/relatorios_oracle.json', 'utf8'));
var mongoNV = relatoriosNV();
var comparacoesNV = Object.keys(oracleNV).map(nome => {
  igualNV(oracleNV[nome], mongoNV[nome], 'Relatorio divergente: ' + nome);
  var hash = v => cryptoNV.createHash('sha256').update(JSON.stringify(canonicoNV(v))).digest('hex');
  return { relatorio: nome, linhasOracle: oracleNV[nome].length, linhasMongoDB: mongoNV[nome].length,
    igual: true, sha256Oracle: hash(oracleNV[nome]), sha256MongoDB: hash(mongoNV[nome]) };
});
fsNV.mkdirSync('evidencias', { recursive: true });
fsNV.writeFileSync('evidencias/relatorios_mongodb.json', JSON.stringify(mongoNV, null, 2) + '\n');
fsNV.writeFileSync('evidencias/validacao_mongodb.json', JSON.stringify({ executadoEm: new Date().toISOString(),
  versaoMongoDB: dbNV.version(), solicitacoes: lotesNV.solicitacoes.length, pontosAgua: lotesNV.pontos_agua.length,
  documentosConferidosIntegralmente: true, reimportacaoSemDuplicacao: true, validadoresRejeitamInvalidos: true,
  relatorios: comparacoesNV }, null, 2) + '\n');
print('APROVADO: conteudo completo, reimportacao, validadores e tres relatorios identicos.');
