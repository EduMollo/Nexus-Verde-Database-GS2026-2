"""Produz os tres PDFs a partir do DDL e das evidencias executadas."""
from pathlib import Path
from xml.sax.saxutils import escape
import json
import re
from reportlab.lib import colors
from reportlab.lib.pagesizes import A4, landscape
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, PageBreak, KeepTogether
from reportlab.graphics.shapes import Drawing, Rect, String, Line, Polygon

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT/'docs'
OUT.mkdir(exist_ok=True)
FONT_DIR = Path('C:/Windows/Fonts')
if (FONT_DIR/'arial.ttf').exists():
    pdfmetrics.registerFont(TTFont('NV', str(FONT_DIR/'arial.ttf')))
    pdfmetrics.registerFont(TTFont('NV-Bold', str(FONT_DIR/'arialbd.ttf')))
else:
    pdfmetrics.registerFont(TTFont('NV', '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf'))
    pdfmetrics.registerFont(TTFont('NV-Bold', '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf'))
GREEN = colors.HexColor('#12634f')
INK = colors.HexColor('#17352d')
LIGHT = colors.HexColor('#edf5f1')
GREY = colors.HexColor('#52655d')
styles = getSampleStyleSheet()
styles.add(ParagraphStyle('NVTitle', fontName='NV-Bold', fontSize=25, leading=29, textColor=INK, spaceAfter=17))
styles.add(ParagraphStyle('NVH1', fontName='NV-Bold', fontSize=16, leading=20, textColor=GREEN, spaceBefore=12, spaceAfter=10))
styles.add(ParagraphStyle('NVH2', fontName='NV-Bold', fontSize=11, leading=15, textColor=INK, spaceBefore=9, spaceAfter=6))
styles.add(ParagraphStyle('NVBody', fontName='NV', fontSize=9, leading=13, textColor=INK, spaceAfter=8))
styles.add(ParagraphStyle('NVSmall', fontName='NV', fontSize=7.6, leading=10.5, textColor=INK, spaceAfter=3))
styles.add(ParagraphStyle('NVHead', fontName='NV-Bold', fontSize=8, leading=10.5, textColor=colors.white))

def p(text, style='NVBody'):
    return Paragraph(escape(str(text)).replace('\n','<br/>'), styles[style])

def table(headers, rows, widths):
    cells = [[p(h,'NVHead') for h in headers]] + [[p(c,'NVSmall') for c in row] for row in rows]
    t = Table(cells, colWidths=widths, repeatRows=1, hAlign='LEFT')
    t.setStyle(TableStyle([
        ('BACKGROUND',(0,0),(-1,0),GREEN), ('VALIGN',(0,0),(-1,-1),'TOP'),
        ('LEFTPADDING',(0,0),(-1,-1),7), ('RIGHTPADDING',(0,0),(-1,-1),7),
        ('TOPPADDING',(0,0),(-1,-1),6), ('BOTTOMPADDING',(0,0),(-1,-1),6),
        ('ROWBACKGROUNDS',(0,1),(-1,-1),[colors.white,LIGHT]),
        ('LINEBELOW',(0,0),(-1,0),0.5,GREEN),
        ('LINEBELOW',(0,1),(-1,-1),0.3,colors.HexColor('#d8e5de')),
    ]))
    return t

def footer(canvas, doc):
    w,h=doc.pagesize
    canvas.setStrokeColor(GREEN); canvas.setLineWidth(.7); canvas.line(38,33,w-38,33)
    canvas.setFont('NV',7);canvas.setFillColor(GREY)
    canvas.drawString(38,22,'NEXUS VERDE | FIAP 2026/2 | DATABASE | 2TDSPF')
    canvas.drawRightString(w-38,22,str(doc.page))

def build(name, story, size=A4):
    doc=SimpleDocTemplate(str(OUT/name),pagesize=size,rightMargin=38,leftMargin=38,topMargin=38,bottomMargin=47,
        title=name.replace('.pdf',''),author='Equipe Nexus Verde - 2TDSPF')
    doc.build(story,onFirstPage=footer,onLaterPages=footer)

def model_diagram(physical=False):
    # Coordenadas exatas: tres niveis, linhas em corredores entre os retangulos.
    d=Drawing(760,405)
    names={
      'u':('NV_USUARIO' if physical else 'USUARIO', ['PK id','nome; papel; ativo']),
      'r':('NV_REGIAO' if physical else 'REGIAO',['PK id','nome; cidade','nivel_risco; populacao_afetada']),
      's':('NV_SOLICITACAO' if physical else 'SOLICITACAO',['PK id','FK solicitante_id (obrigatorio)','FK regiao_id; cadastrada_por_id','tipo; pessoas; urgencia; prioridade','status; datas; versao']),
      'p':('NV_PONTO_AGUA' if physical else 'PONTO_AGUA',['PK id; FK regiao_id','nome; tipo; localizacao','status; capacidade; estoque']),
      'h':('NV_HISTORICO_STATUS' if physical else 'HISTORICO_STATUS',['PK id; FK solicitacao_id','FK equipe_id','status anterior/novo; motivo; data']),
      'a':('NV_AUDITORIA' if physical else 'AUDITORIA',['PK id; solicitacao_id (sem FK)','operacao; data; usuario_banco','valores antigos/novos JSON']),
    }
    boxes={'u':(25,300,270,85),'r':(465,300,270,85),'s':(25,135,325,112),
           'p':(465,145,270,92),'h':(25,5,325,86),'a':(465,5,270,86)}
    def line(x1,y1,x2,y2,label=None,lx=None,ly=None,dashed=False):
        ln=Line(x1,y1,x2,y2,strokeColor=GREEN,strokeWidth=1)
        if dashed: ln.strokeDashArray=[4,3]
        d.add(ln)
        if label:d.add(String(lx if lx is not None else (x1+x2)/2,ly if ly is not None else (y1+y2)/2,label,fontName='NV',fontSize=8,fillColor=GREEN))
    line(95,300,95,247,'1 : 0..N (solicitante)',103,275)
    line(210,300,210,268);line(210,268,380,268,'0..1 : 0..N (cadastro)',235,277)
    line(380,268,380,204);line(380,204,350,204)
    line(510,300,510,280);line(510,280,420,280);line(420,280,420,226);line(420,226,350,226)
    d.add(String(390,289,'0..1 : 0..N (regiao)',fontName='NV',fontSize=8,fillColor=GREEN))
    line(645,300,645,237,'0..1 : 0..N',651,263)
    line(95,135,95,91,'1 : 0..N',103,111)
    line(25,344,9,344);line(9,344,9,51);line(9,51,25,51)
    d.add(String(17,107,'equipe: 1 : 0..N',fontName='NV',fontSize=7,fillColor=GREEN))
    line(350,163,402,163,dashed=True);line(402,163,402,47,dashed=True);line(402,47,465,47,'DML',424,56,True)
    for key,(x,y,w,h) in boxes.items():
        title,fields=names[key]
        d.add(Rect(x,y,w,h,fillColor=colors.white,strokeColor=GREEN,strokeWidth=.8))
        d.add(Rect(x,y+h-24,w,24,fillColor=GREEN,strokeColor=GREEN))
        d.add(String(x+10,y+h-16,title,fontName='NV-Bold',fontSize=9,fillColor=colors.white))
        for i,f in enumerate(fields):d.add(String(x+10,y+h-39-i*12,f,fontName='NV',fontSize=8,fillColor=INK))
    d.scale(.82,.82)
    d.width *= .82
    d.height *= .82
    return d

relations=[
 ['Usuário / solicitação','Usuário 1 : 0..N pedidos','Cada pedido possui exatamente um cidadão solicitante.'],
 ['Equipe / cadastro','Usuário 0..1 : 0..N pedidos','Cadastro por equipe é opcional; pacote valida papel e situação ativa.'],
 ['Região / solicitação','Região 0..1 : 0..N pedidos','Região é opcional; quando informada deve pertencer à cidade.'],
 ['Região / ponto de água','Região 0..1 : 0..N pontos','Pontos têm ciclo próprio e estoque; não há FK pedido-ponto.'],
 ['Solicitação / histórico','Pedido 1 : 0..N eventos','Cada mudança operacional guarda equipe, estados, motivo e data.'],
 ['Equipe / histórico','Usuário 1 : 0..N eventos','Cada evento tem um responsável da equipe.'],
 ['Solicitação / auditoria','Associação lógica por ID','Sem FK: a imagem de DELETE pode sobreviver à remoção do pedido.'],
]

story=[p('Modelo lógico','NVTitle'),p('Nexus Verde | Do Oracle ao MongoDB','NVH1'),
 p('Acesso à água potável, registro de necessidades, triagem e acompanhamento de atendimento. Recorte acadêmico do domínio Java de referência.'),
 model_diagram(),p('Legenda: PK = identificador; FK = referência. 0..1 indica vínculo opcional; 0..N indica várias ocorrências. A linha tracejada representa geração de auditoria, sem integridade referencial física.','NVSmall'),
 PageBreak(),p('Relacionamentos e decisões','NVTitle'),table(['Vínculo','Cardinalidade','Regra'],relations,[175,180,410]),Spacer(1,15),
 p('Integridade e recorte','NVH1'),p('As entidades operacionais são normalizadas. Papel e situação do usuário, limites de estoque, domínios e coordenadas são validados. Histórico pertence ao pedido; auditoria é uma trilha transacional gerada por gatilho.'),
 p('Não há associação de entrega entre solicitação e ponto de água: esse comportamento não existe no Java analisado. Região é o contexto territorial comum. Autenticação e análise de IA ficam fora deste modelo Database.'),
 p('Modelo documental','NVH1'),p('Duas collections: solicitacoes incorpora solicitante mínimo, região e histórico; pontos_agua incorpora a região. IDs Oracle permanecem no documento. Auditoria continua no Oracle. Trata-se de um snapshot, sem sincronização automática.')]
build('Nexus-Verde-Modelo-Logico.pdf',story,landscape(A4))

ddl=(ROOT/'sql/01_estrutura.sql').read_text(encoding='utf-8')
tables=re.findall(r'CREATE TABLE (NV_\w+) \(\s*(.*?)\n\);',ddl,re.S)
story=[p('Modelo físico','NVTitle'),p('Oracle 19c | schema-v1','NVH1'),model_diagram(True),
 p('As seis tabelas e os vínculos são implementados em sql/01_estrutura.sql. Auditoria usa CLOB com CHECK IS JSON e não tem FK para solicitação. As colunas completas e os índices constam nas próximas páginas.','NVBody')]
for name,body in tables:
    story += [PageBreak(),p(name,'NVTitle')]
    rows=[]; extra=[]
    for raw in body.splitlines():
        line=raw.strip().rstrip(',')
        if line.startswith('CONSTRAINT '): extra.append(line);continue
        field,definition=line.split(None,1)
        rows.append([field,definition])
    story.append(table(['Coluna','Tipo, obrigatoriedade e restrições'],rows,[170,595]))
    if extra:story += [Spacer(1,10),p('Restrições da tabela','NVH2')]+[p(x,'NVSmall') for x in extra]
    if name=='NV_USUARIO':story += [p('Marcador: COMMENT ON TABLE = Nexus Verde GS2026/2 schema-v1. Criação/cadastro exige CIDADAO ativo; mudanças de status exigem EQUIPE ativa.','NVBody')]
    if name=='NV_AUDITORIA':story += [p('INSERT: valores_antigos nulo; DELETE: valores_novos nulo; UPDATE: ambas as imagens. A mesma transação da operação grava a auditoria; não existe transação autônoma.','NVBody')]
story += [PageBreak(),p('Índices e objetos programáveis','NVTitle')]
indexes=re.findall(r'CREATE INDEX (\w+) ON (\w+)\((.*?)\);',ddl)
story += [table(['Índice','Tabela','Colunas'],indexes,[180,205,380]),Spacer(1,14),
 p('Pacotes, gatilhos e views','NVH1'),table(['Objeto','Responsabilidade'],[
 ['PKG_NV_SOLICITACOES','2 funções de regra; validação, criação e alteração de status.'],
 ['PKG_NV_AUDITORIA','Registro transacional dos valores antigo/novo e executor Oracle.'],
 ['PKG_NV_RELATORIOS','Exportação JSON das solicitações e dos pontos via CLOB.'],
 ['TRG_NV_VALIDAR_SOLIC','BEFORE INSERT/UPDATE: vínculos, transição, prioridade, versão e data.'],
 ['TRG_NV_AUDITAR_SOLIC','AFTER INSERT/UPDATE/DELETE: imagens JSON completas da solicitação.'],
 ['V_NV_FILA / V_NV_DEMANDA / V_NV_ESTOQUE','Consultas de referência para comparação com MongoDB.'],
 ],[220,545]),p('Chaves primárias e a UNIQUE de região também geram índices Oracle. Nenhum objeto de instalação é apagado. Não há COMMIT nas regras: o executor controla a transação.','NVBody')]
build('Nexus-Verde-Modelo-Fisico.pdf',story,landscape(A4))

oracle=json.loads((ROOT/'evidencias/relatorios_oracle.json').read_text(encoding='utf-8'))
evidence=json.loads((ROOT/'evidencias/validacao_mongodb.json').read_text(encoding='utf-8'))
story=[p('Nexus Verde','NVTitle'),p('Database | Global Solution 2026/2','NVH1'),
 p('Do Oracle ao MongoDB: dados a serviço do cidadão.'),Spacer(1,18),
 p('Problema CitizenTech','NVH1'),p('Interrupções de abastecimento e catástrofes dificultam o acesso à água potável e a identificação das famílias que precisam de atendimento. Informações fragmentadas prejudicam a triagem e a consulta de recursos disponíveis.'),
 p('Solução','NVH1'),p('O Nexus Verde organiza solicitações de cidadãos, calcula prioridade por regras transparentes e permite que uma equipe acompanhe o atendimento. Regiões e pontos de distribuição permitem consultar o estoque territorial. A contribuição se relaciona a comunidades resilientes e redução de desigualdades, com ligação direta ao ODS 6 - água potável e saneamento.'),
 p('Equipe - 2TDSPF','NVH1'),table(['Integrante','RM'],[
 ['Carlos Alberto Guedes Neto','566022'],['Eduardo Novaes Mollo','561515'],['Luan Peixoto Marins Rocha','562258'],
 ['Mathaus Victor Souza Marcelino','564146'],['Vinicius Luis Exposito Morassi','563340']],[390,129]),Spacer(1,12),
 p('Código e instruções: github.com/EduMollo/Nexus-Verde-Database-GS2026-2','NVSmall'),
 p('Base normativa: PDF FIAP Global Solution 2026/2, páginas 71-76. Entrega: 19/11/2026 às 23h55. Apresentação presencial: 23 a 27/11.','NVSmall'),
 PageBreak(),p('1. Escopo e arquitetura de dados','NVTitle'),
 p('Oracle 19c guarda seis tabelas, três pacotes com specification/body, dois gatilhos e três views. Um executor Java 21/JDBC chama as procedures e grava os JSON. O mongosh cria duas collections e importa os mesmos registros. Relatórios equivalentes comprovam a transição.'),
 table(['Camada','Responsabilidade'],[
 ['Oracle','Regras, transações, auditoria e origem dos dados.'],['JSON exportado','Snapshot consistente: ambos os datasets e relatórios Oracle vêm da mesma transação somente leitura.'],
 ['MongoDB','Projeção documental, validadores, índices, find e agregações.'],['Validação','Conteúdo completo, reimportação, exceções e comparação de relatórios/hash.']],[120,399]),
 p('Dados e limites','NVH1'),p('A carga contém 6 usuários, 4 regiões, 8 pontos e 16 solicitações. Nomes, endereços, população e estoques são fictícios, mesmo quando as cidades e bairros existem. Nenhuma informação da carga representa levantamento de uma catástrofe real.'),
 p('O backend Java de referência permanece usando PostgreSQL/H2. Esta entrega implementa um recorte Oracle independente para Database, sem migração de autenticação/IA. A GS não exige integração automática entre bancos. A CS4 orientou a organização dos scripts, adaptados ao Nexus Verde.'),
 p('Correspondência com a rubrica','NVH1'),table(['Item','Implementação'],[
 ['Modelo + blocos (10)','6 tabelas e 2 blocos com cursores, decisão e repetição.'],['Funções/procedimentos (15)','Prioridade, transição, criação e mudança de status.'],
 ['Gatilhos/auditoria (10)','Validação BEFORE e auditoria AFTER.'],['Pacotes/testes (10)','3 pacotes válidos e testes transacionais.'],['MongoDB (10)','2 collections; 24 documentos; insertMany.'],
 ['Transição/relatórios (15)','Mapa relacional-documental, find e 2 aggregate; resultados iguais.'],['Apresentação (30)','Roteiro presencial e SQL demonstrativo incluídos.']],[155,364]),
 PageBreak(),p('2. Regras PL/SQL','NVTitle'),p('Prioridade de atendimento','NVH1'),
 p('FN_CALCULAR_PRIORIDADE retorna min(100, base + min(pessoas,10) + vulnerabilidade + contaminação). Bases: BAIXA=10, MEDIA=30, ALTA=50, CRITICA=70; vulnerabilidade soma 15; água contaminada soma 5. ALTA + 5 pessoas + vulnerável + água contaminada = 75.'),
 p('Transições e procedimentos','NVH1'),p('FN_TRANSICAO_PERMITIDA autoriza ABERTA para EM_ATENDIMENTO/CANCELADA e EM_ATENDIMENTO para ATENDIDA/CANCELADA. Estados finais não reabrem. Repetição do mesmo estado é idempotente. PRC_CRIAR_SOLICITACAO valida cidadão ativo, parâmetros e região/cidade. PRC_ALTERAR_STATUS valida equipe ativa, bloqueia o pedido com FOR UPDATE, atualiza e registra histórico. Cancelamento exige motivo.'),
 table(['Código','Exceção de negócio'],[
 ['-20101','Parâmetros inválidos para prioridade.'],['-20102','Cidadão ativo inexistente.'],['-20103','Cidade ausente ou região incompatível.'],['-20104','Equipe ativa inexistente.'],
 ['-20105','Dados obrigatórios/valor inválido na criação.'],['-20106','Transição indisponível.'],['-20107','Motivo obrigatório ou maior que 400 caracteres.'],['-20108','Solicitação inexistente/excluída.'],['-20109','Operação de auditoria inválida.']],[100,419]),
 p('Auditoria e transações','NVH1'),p('TRG_NV_VALIDAR_SOLIC calcula prioridade e valida vínculos/transição. TRG_NV_AUDITAR_SOLIC delega ao pacote de auditoria o registro de INSERT/UPDATE/DELETE, data, conta Oracle e imagens completas. Não há FK para solicitação na auditoria: a evidência pode permanecer após DELETE. ROLLBACK desfaz a operação e sua auditoria. A equipe responsável é registrada separadamente no histórico.'),
 PageBreak(),p('3. Mapeamento documental','NVTitle'),
 table(['Origem Oracle','Documento MongoDB','Escolha'],[
 ['NV_SOLICITACAO','solicitacoes; id e _id Oracle','Pedido é o agregado principal.'],['NV_USUARIO','solicitante {id,nome}','Identificação mínima incorporada.'],
 ['NV_REGIAO','regiao {id,nome,cidade,nivelRisco}','Snapshot territorial incorporado; pode ser null.'],['NV_HISTORICO_STATUS','historico[]','Eventos ordenados por id, com equipeId.'],
 ['NV_PONTO_AGUA','pontos_agua','Ciclo próprio de estoque/disponibilidade.'],['NV_AUDITORIA','Mantida no Oracle','Trilha completa transacional.']],[135,180,204]),
 p('Conversões e referências','NVH1'),p('Campos snake_case tornam-se camelCase. NUMBER 0/1 de grupo vulnerável vira boolean JSON no Oracle. Datas são UTC ISO 8601 com milissegundos e viram BSON Date. ID original permanece em id e _id. CadastradaPorId e equipeId são referências de origem, sem uma terceira collection de usuários.'),
 p('Trade-offs','NVH1'),p('A incorporação permite ler pedido/contexto/histórico em um documento e evita joins para os relatórios. A região é redundante e reflete a exportação: mudanças exigem nova exportação/importação. O dataset acadêmico é pequeno; um histórico de produção muito extenso exigiria avaliar coleção própria e limite de documento. Não há integridade referencial automática entre Oracle e MongoDB.'),
 p('Importação reproduzível','NVH1'),p('01_estrutura.js seleciona o database e cria collections com validadores e índices. 02_importar.js lê os dois JSON, valida IDs e usa insertMany na primeira carga; reexecuções fazem upsert/substituição por ID. Dados externos ao snapshot ou estrutura incompatível interrompem o processo. Não há remoção de collections ou documentos da carga.'),
 PageBreak(),p('4. Relatórios equivalentes','NVTitle'),p('Filtros compartilhados','NVH1'),p('Fila e demanda desconsideram exclusão lógica. Fila inclui ABERTA/EM_ATENDIMENTO; demanda inclui cancelados sem exclusão. Região ausente é null na fila e 0 no agrupamento. Estoque ignora FECHADO, incluindo estoque e capacidade zero. Ordenação da fila: prioridade DESC, id ASC.'),
 p('Fila de atendimento - find + sort','NVH2'),table(['Pedido','Prioridade','Região','Urgência'],[[r['id'],r['prioridade'],r['regiaoId'],r['urgencia']] for r in oracle['fila']],[80,110,100,229]),
 p('Demanda - aggregate $group/$sum','NVH2'),p('Foram encontrados 16 grupos: cada uma das quatro regiões possui 1 pedido ABERTA, 1 ATENDIDA, 1 CANCELADA e 1 EM_ATENDIMENTO. Os resultados completos estão em evidencias/relatorios_oracle.json e relatorios_mongodb.json.'),
 p('Estoque por região - aggregate','NVH2'),table(['Região','Capacidade (L)','Estoque (L)','Pontos abertos'],[[r['regiaoId'],r['capacidadeLitros'],r['estoqueLitros'],r['pontos']] for r in oracle['estoque']],[85,145,145,144]),
 p('Total: 28.500 litros em 7 pontos não fechados. As consultas SQL estão nas views de sql/04_relatorios.sql e em sql/08_consultas_apresentacao.sql; as equivalentes documentais ficam em mongodb/03_relatorios.js.','NVSmall'),
 PageBreak(),p('5. Evidências e verificação','NVTitle'),p('Execução real em 17/11/2026','NVH1'),
 p('Oracle FIAP 19c: os 17 objetos principais estão VALID e USER_ERRORS está vazio. Pacotes, funções, procedures, gatilhos, histórico, JSON e rollback foram executados. MongoDB Community '+evidence['versaoMongoDB']+': 16 solicitações e 8 pontos importados e conferidos campo a campo.'),
 table(['Verificação','Resultado observado'],[
 ['Oracle - regras/exceções','Prioridade limite/base; nulos/quantidade inválida; usuário inativo; região/cidade; equipe; transições; cancelamento.'],
 ['Oracle - gatilhos/auditoria','INSERT, UPDATE e DELETE; imagens antigo/novo; prioridade recalculada; rollback restaura auditoria.'],
 ['Oracle - limites','Estoque acima da capacidade rejeitado; região ausente e exclusão lógica conferidos nas views.'],
 ['MongoDB - documentos','Todos os campos, IDs, datas e históricos conferidos contra os JSON Oracle.'],
 ['MongoDB - reimportação','Novo carregamento mantém exatamente o mesmo snapshot, sem duplicação.'],
 ['MongoDB - rejeições','Estoque negativo/acima da capacidade, status inválido e ID duplicado rejeitados.'],
 ['Relatórios','Fila (8 linhas), demanda (16), estoque (4); igualdade integral e SHA-256 coincidentes.']],[145,374]),
 p('Hashes de comparação','NVH1')]
for report in evidence['relatorios']:
    story += [p(report['relatorio'].upper()+' | Oracle = MongoDB | '+str(report['linhasOracle'])+' linhas','NVH2'),p(report['sha256Oracle'],'NVSmall')]
story += [p('A comparação ordena chaves de objetos para serialização canônica e preserva a ordem de arrays. Evidências: execucao_oracle.txt, testes_oracle.txt, objetos_oracle.json, execucao_mongodb.txt e validacao_mongodb.json. Não são testes de carga ou comprovação de prontidão de produção.','NVSmall'),
 PageBreak(),p('6. Executar e apresentar','NVTitle'),p('Oracle','NVH1'),p('JDK 21 + driver ojdbc11 oficial + rede FIAP. Na raiz, executar configurar-oracle.ps1 uma vez e executar-oracle.ps1 all. Configuração fica somente em .env local. O executor preserva a carga existente e não apaga objetos. Para SQL Developer em esquema vazio: sql/instalar.sql (F5).'),
 p('MongoDB','NVH1'),p('Com Docker iniciado: docker compose up -d --wait; depois docker compose exec -T mongodb mongosh --quiet --file mongodb/04_validar.js. Alternativa: MongoDB/mongosh instalados e executar-mongodb.ps1 test. Nesta máquina, iniciar-mongodb-local.ps1 configura a instância portátil na porta local 27019.'),
 p('Ordem da demonstração presencial','NVH1'),table(['Passo','Ação'],[
 ['1','Explicar o problema e abrir os modelos lógico/físico.'],['2','Executar a função e o bloco de sql/08_consultas_apresentacao.sql.'],
 ['3','Mostrar specification/body, gatilhos, valores antigo/novo e rollback.'],['4','Importar as duas collections a partir dos JSON Oracle.'],
 ['5','Executar os três relatórios e mostrar os hashes iguais.'],['6','Justificar referências/incorporação e o snapshot.']],[60,459]),
 p('Entrega e responsabilidade','NVH1'),p('O ZIP inclui SQL, JavaScript, JSON real, PDFs, instruções, testes, evidências e TXT dos cinco integrantes. Senhas, .env real, .git e dependências locais são excluídos. O grupo deve enviar o ZIP ao Portal FIAP até 19/11 às 23h55 e realizar a apresentação de 23 a 27/11. Não é exigido vídeo na seção Database do PDF.'),
 p('Uso de IA','NVH1'),p('ChatGPT/Codex apoiou inspeção dos requisitos/código, implementação, testes, revisão e documentação. As evidências registram execução automática real. Cada integrante deve revisar e compreender o material para a apresentação.'),
 p('Referências: guia FIAP GS 2026/2, páginas 71-76; Java Nexus Verde commit d8715e9; CS4 Database do grupo; Oracle 19c PL/SQL Language Reference; documentação oficial MongoDB de validação e agregação. Links completos no README.','NVSmall')]
build('Nexus-Verde-Database-Documentacao.pdf',story)
print('Gerados tres PDFs em docs/.')
