// mongosh: equivalente a `use nexus_verde_gs2026`.
// Executar na raiz do projeto. Nao apaga collections ou dados existentes.
var dbNV = db.getSiblingDB('nexus_verde_gs2026');
var numNV = { bsonType: ['int', 'long', 'double', 'decimal'] };
var textoNV = { bsonType: 'string', minLength: 1 };
var regiaoNV = { bsonType: ['object', 'null'], required: ['id', 'nome', 'cidade', 'nivelRisco'], properties: {
  id: numNV, nome: textoNV, cidade: textoNV,
  nivelRisco: { enum: ['BAIXO', 'MODERADO', 'ALTO', 'CRITICO'] }
}};
var statusNV = ['ABERTA', 'EM_ATENDIMENTO', 'ATENDIDA', 'CANCELADA'];
var schemaSolicNV = { bsonType: 'object', required: ['_id', 'id', 'tipo', 'descricao', 'quantidadePessoas',
  'urgencia', 'grupoVulneravel', 'endereco', 'cidade', 'status', 'prioridade', 'solicitante',
  'regiao', 'historico', 'criadaEm', 'atualizadaEm', 'excluidaEm'], properties: {
  _id: numNV, id: numNV, descricao: textoNV, endereco: textoNV, cidade: textoNV,
  tipo: { enum: ['FALTA_DE_AGUA', 'AGUA_CONTAMINADA', 'ENTREGA_DE_AGUA', 'OUTRO'] },
  quantidadePessoas: { ...numNV, minimum: 1 }, urgencia: { enum: ['BAIXA', 'MEDIA', 'ALTA', 'CRITICA'] },
  grupoVulneravel: { bsonType: 'bool' }, status: { enum: statusNV }, prioridade: { ...numNV, minimum: 0, maximum: 100 },
  latitude: { bsonType: ['double', 'int', 'long', 'decimal', 'null'], minimum: -90, maximum: 90 },
  longitude: { bsonType: ['double', 'int', 'long', 'decimal', 'null'], minimum: -180, maximum: 180 },
  solicitante: { bsonType: 'object', required: ['id', 'nome'], properties: { id: numNV, nome: textoNV } },
  regiao: regiaoNV, cadastradaPorId: { bsonType: ['int', 'long', 'double', 'decimal', 'null'] },
  criadaEm: { bsonType: 'date' }, atualizadaEm: { bsonType: 'date' }, excluidaEm: { bsonType: ['date', 'null'] },
  historico: { bsonType: 'array', items: { bsonType: 'object', required: ['id', 'equipeId', 'statusAnterior', 'statusNovo', 'registradaEm'],
    properties: { id: numNV, equipeId: numNV, statusAnterior: { enum: statusNV }, statusNovo: { enum: statusNV },
      motivo: { bsonType: ['string', 'null'] }, registradaEm: { bsonType: 'date' } } } }
}};
var schemaPontoNV = { bsonType: 'object', required: ['_id', 'id', 'nome', 'tipo', 'endereco', 'cidade', 'status',
  'capacidadeLitros', 'estoqueLitros', 'regiao'], properties: {
  _id: numNV, id: numNV, nome: textoNV, endereco: textoNV, cidade: textoNV, regiao: regiaoNV,
  tipo: { enum: ['POSTO_DISTRIBUICAO', 'CAMINHAO_PIPA', 'RESERVATORIO', 'ABRIGO'] },
  status: { enum: ['DISPONIVEL', 'ESTOQUE_BAIXO', 'ESGOTADO', 'FECHADO'] },
  capacidadeLitros: { ...numNV, minimum: 0 }, estoqueLitros: { ...numNV, minimum: 0 }
}};
var validadoresNV = {
  solicitacoes: { $and: [{ $jsonSchema: schemaSolicNV }, { $expr: { $eq: ['$_id', '$id'] } }] },
  pontos_agua: { $and: [{ $jsonSchema: schemaPontoNV }, { $expr: { $lte: ['$estoqueLitros', '$capacidadeLitros'] } },
    { $expr: { $eq: ['$_id', '$id'] } }] }
};
for (var nomeNV of Object.keys(validadoresNV)) {
  if (!dbNV.getCollectionNames().includes(nomeNV)) {
    dbNV.createCollection(nomeNV, { validator: validadoresNV[nomeNV], validationLevel: 'strict', validationAction: 'error' });
  } else {
    // Nao substitui silenciosamente uma estrutura de terceiros.
    var optionsNV = dbNV.getCollectionInfos({ name: nomeNV })[0].options;
    if (EJSON.stringify(optionsNV.validator) !== EJSON.stringify(validadoresNV[nomeNV]) ||
        optionsNV.validationLevel !== 'strict' || optionsNV.validationAction !== 'error') {
      throw Error('Collection existente com estrutura diferente: ' + nomeNV);
    }
  }
  dbNV.getCollection(nomeNV).createIndex({ id: 1 }, { unique: true, name: 'uk_oracle_id' });
}
dbNV.solicitacoes.createIndex({ status: 1, excluidaEm: 1, prioridade: -1, id: 1 }, { name: 'ix_triagem' });
dbNV.solicitacoes.createIndex({ 'regiao.id': 1, status: 1 }, { name: 'ix_demanda_regiao' });
dbNV.pontos_agua.createIndex({ 'regiao.id': 1, status: 1 }, { name: 'ix_estoque_regiao' });
print('Estrutura MongoDB aprovada: duas collections com validadores e indices.');
