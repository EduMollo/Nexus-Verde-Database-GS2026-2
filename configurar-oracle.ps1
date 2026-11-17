$ErrorActionPreference='Stop'
$destino=Join-Path $PSScriptRoot '.env'
if(Test-Path -LiteralPath $destino){throw 'Configuracao ja existe. Edite o .env local se necessario.'}
$url=Read-Host 'URL JDBC Oracle (jdbc:oracle:thin:@//host:porta/servico)'
$usuario=Read-Host 'Usuario Oracle'
$segredo=Read-Host 'Senha Oracle' -AsSecureString
$ponteiro=[Runtime.InteropServices.Marshal]::SecureStringToBSTR($segredo)
try {
 $senha=[Runtime.InteropServices.Marshal]::PtrToStringBSTR($ponteiro)
 [IO.File]::WriteAllText($destino,"DB_URL=$url`nDB_USERNAME=$usuario`nDB_PASSWORD=$senha`n",[Text.UTF8Encoding]::new($false))
} finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ponteiro); $senha=$null }
Write-Output 'Configuracao local salva. O arquivo .env fica fora do Git e do ZIP.'
