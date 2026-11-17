"""Gera ZIP reproduzivel de entrega, sem configuracoes ou dependencias locais."""
from pathlib import Path
import hashlib
import json
import zipfile
from validar_entrega import ROOT, validate

validate()
folders = ('sql', 'mongodb', 'dataset', 'evidencias', 'docs', 'tools', '.github')
files = [p for p in ROOT.iterdir() if p.is_file() and
         (p.name in ('README.md', 'INTEGRANTES.txt', 'compose.yml', '.env.example', '.gitignore', '.gitattributes') or p.suffix == '.ps1')]
for folder in folders:
    files.extend(p for p in (ROOT/folder).rglob('*') if p.is_file() and
                 '__pycache__' not in p.parts and p.suffix not in ('.pyc', '.log', '.tmp', '.class') and p.name != 'manifesto_sha256.json')
files = sorted(set(files))
manifest = {p.relative_to(ROOT).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest() for p in files}
manifest_path = ROOT/'evidencias/manifesto_sha256.json'
manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
files.append(manifest_path)
out = ROOT/'output/2TDSPF_Nexus-Verde_Database_GS2026-2.zip'
out.parent.mkdir(parents=True, exist_ok=True)
with zipfile.ZipFile(out, 'w', zipfile.ZIP_DEFLATED) as z:
    for path in files:
        z.write(path, 'Nexus-Verde-Database-GS2026-2/'+path.relative_to(ROOT).as_posix())
with zipfile.ZipFile(out) as z:
    assert z.testzip() is None
    for name, digest in manifest.items():
        assert hashlib.sha256(z.read('Nexus-Verde-Database-GS2026-2/'+name)).hexdigest() == digest
    assert not any('/.env' in n and not n.endswith('/.env.example') for n in z.namelist())
print(f'ZIP aprovado: {len(files)} arquivos; {out.name}; {out.stat().st_size} bytes.')
