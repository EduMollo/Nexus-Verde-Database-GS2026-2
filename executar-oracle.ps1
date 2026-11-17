param([ValidateSet('check','install','compile','seed','test','demo','export','all')][string]$Acao='check')
$ErrorActionPreference='Stop'
if ($env:PATHEXT -notmatch '(^|;)\.EXE(;|$)') { $env:PATHEXT='.EXE;'+$env:PATHEXT }
Push-Location $PSScriptRoot
try {
 $driver = $env:ORACLE_JDBC_JAR
 if (-not $driver) {
  $profileDir = if ($env:USERPROFILE) { $env:USERPROFILE } else { [Environment]::GetFolderPath([Environment+SpecialFolder]::UserProfile) }
  $driver = Get-ChildItem -LiteralPath (Join-Path $profileDir '.m2/repository/com/oracle/database/jdbc/ojdbc11') -Filter 'ojdbc11-*.jar' -Recurse -File |
   Where-Object { $_.Name -notmatch 'sources|javadoc' } | Sort-Object FullName -Descending | Select-Object -First 1 -ExpandProperty FullName
 }
 if (-not $driver -or -not (Test-Path -LiteralPath $driver)) { throw 'Defina ORACLE_JDBC_JAR com o driver ojdbc11 oficial ou obtenha pelo Maven (ver README).' }
 $java = if ($env:JAVA_HOME) { Join-Path $env:JAVA_HOME 'bin/java.exe' }
 elseif (Test-Path 'C:\Program Files\Java\jdk-21\bin\java.exe') { 'C:\Program Files\Java\jdk-21\bin\java.exe' }
 else { 'java' }
 & $java -cp $driver tools/OracleNexus.java $Acao
 if ($LASTEXITCODE -ne 0) { throw "Oracle interrompido: codigo $LASTEXITCODE" }
} finally { Pop-Location }
