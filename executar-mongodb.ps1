param([ValidateSet('import','report','test')][string]$Acao='test')
$ErrorActionPreference='Stop'
if ($env:PATHEXT -notmatch '(^|;)\.EXE(;|$)') { $env:PATHEXT='.EXE;'+$env:PATHEXT }
Push-Location $PSScriptRoot
try {
 $shell = if ($env:MONGOSH_EXE) { $env:MONGOSH_EXE } else { 'mongosh' }
 $uri = if ($env:MONGODB_URI) { $env:MONGODB_URI } else { 'mongodb://127.0.0.1:27017' }
 $script = switch($Acao){ 'import' {'mongodb/02_importar.js'} 'report' {'mongodb/03_relatorios.js'} 'test' {'mongodb/04_validar.js'} }
 & $shell $uri --quiet --file $script
 if ($LASTEXITCODE -ne 0) { throw "MongoDB interrompido: codigo $LASTEXITCODE" }
} finally { Pop-Location }
