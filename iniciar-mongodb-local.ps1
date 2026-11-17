$ErrorActionPreference='Stop'
if ($env:PATHEXT -notmatch '(^|;)\.EXE(;|$)') { $env:PATHEXT='.EXE;'+$env:PATHEXT }
$cache=Join-Path $PSScriptRoot '.cache/mongodb'
$server=Join-Path $cache 'server/mongodb-win32-x86_64-windows-8.0.5/bin/mongod.exe'
$shell=Join-Path $cache 'shell/mongosh-2.5.10-win32-x64/bin/mongosh.exe'
if (-not (Test-Path -LiteralPath $server) -or -not (Test-Path -LiteralPath $shell)) {
 throw 'Ferramentas portateis ausentes. Use Docker Compose ou instale MongoDB e mongosh oficiais conforme o README.'
}
$env:MONGOSH_EXE=$shell
$env:MONGODB_URI='mongodb://127.0.0.1:27019'
$cliente=[Net.Sockets.TcpClient]::new()
try { $cliente.Connect('127.0.0.1',27019); $ativo=$true } catch { $ativo=$false } finally { $cliente.Dispose() }
if (-not $ativo) {
 $data=Join-Path $cache 'data'
 New-Item -ItemType Directory -Path $data -Force | Out-Null
 $log=Join-Path $cache 'mongod.log'
 Start-Process -FilePath $server -ArgumentList @('--dbpath',('"'+$data+'"'),'--bind_ip','127.0.0.1','--port','27019','--logpath',('"'+$log+'"')) -WindowStyle Hidden
}
& $shell $env:MONGODB_URI --quiet --eval 'db.adminCommand({ping:1}).ok'
if($LASTEXITCODE -ne 0){throw 'MongoDB nao respondeu; confira .cache/mongodb/mongod.log'}
Write-Output 'MongoDB local pronto na porta 27019. Execute .\executar-mongodb.ps1 test nesta janela.'
