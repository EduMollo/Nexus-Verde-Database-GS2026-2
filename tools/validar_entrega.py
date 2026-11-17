"""Confere material entregue e evidencias reais, sem consultar bancos ou credenciais."""
from pathlib import Path
import hashlib
import json

ROOT = Path(__file__).resolve().parents[1]

def canonical(value):
    # Mesma serializacao JSON usada pelo comparador JS para os dados desta entrega.
    return json.dumps(value, sort_keys=True, separators=(',', ':'), ensure_ascii=False)

def validate():
    required = [
        'README.md', 'INTEGRANTES.txt', '.env.example', 'compose.yml',
        'configurar-oracle.ps1', 'executar-oracle.ps1', 'executar-mongodb.ps1',
        'sql/instalar.sql', 'sql/01_estrutura.sql', 'sql/02_solicitacoes.sql',
        'sql/03_auditoria.sql', 'sql/04_relatorios.sql', 'sql/05_carga.sql',
        'sql/06_blocos.sql', 'sql/07_testes.sql', 'sql/08_consultas_apresentacao.sql',
        'mongodb/01_estrutura.js', 'mongodb/02_importar.js', 'mongodb/03_relatorios.js', 'mongodb/04_validar.js',
        'tools/OracleNexus.java', 'docs/MAPEAMENTO.md', 'docs/APRESENTACAO.md',
        'docs/Nexus-Verde-Modelo-Logico.pdf', 'docs/Nexus-Verde-Modelo-Fisico.pdf',
        'docs/Nexus-Verde-Database-Documentacao.pdf', 'evidencias/execucao_oracle.txt',
        'evidencias/testes_oracle.txt', 'evidencias/execucao_mongodb.txt',
    ]
    for name in required:
        assert (ROOT/name).is_file() and (ROOT/name).stat().st_size > 0, f'Ausente/vazio: {name}'
    load = lambda name: json.loads((ROOT/name).read_text(encoding='utf-8'))
    solicitacoes = load('dataset/solicitacoes.json')
    pontos = load('dataset/pontos_agua.json')
    assert len(solicitacoes) == 16 and len(pontos) == 8
    for records in (solicitacoes, pontos):
        assert len({r['id'] for r in records}) == len(records), 'IDs duplicados'
    objects = load('evidencias/objetos_oracle.json')
    assert len(objects) == 17 and all(o['status'] == 'VALID' for o in objects)
    oracle = load('evidencias/relatorios_oracle.json')
    mongo = load('evidencias/relatorios_mongodb.json')
    assert oracle == mongo, 'Relatorios diferentes'
    evidence = load('evidencias/validacao_mongodb.json')
    assert evidence['documentosConferidosIntegralmente'] and evidence['reimportacaoSemDuplicacao']
    assert evidence['validadoresRejeitamInvalidos']
    assert len(evidence['relatorios']) == 3
    for report in evidence['relatorios']:
        digest = hashlib.sha256(canonical(oracle[report['relatorio']]).encode()).hexdigest()
        assert report['igual'] and report['sha256Oracle'] == report['sha256MongoDB'] == digest
    for name in ('execucao_oracle.txt', 'testes_oracle.txt', 'execucao_mongodb.txt'):
        assert 'APROVADO' in (ROOT/'evidencias'/name).read_text(encoding='utf-8')
    print('APROVADO: arquivos, 17 objetos VALID, 24 documentos e tres relatorios/hashes iguais.')

if __name__ == '__main__':
    validate()
