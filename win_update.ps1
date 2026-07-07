$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

Write-Host "=== 1. Provider NuGet + PSGallery ===" -ForegroundColor Cyan
if (-not (Get-PackageProvider -Name NuGet -ErrorAction SilentlyContinue)) {
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force | Out-Null
}
Set-PSRepository -Name PSGallery -InstallationPolicy Trusted

Write-Host "=== 2. Modulo PSWindowsUpdate ===" -ForegroundColor Cyan
if (-not (Get-Module -ListAvailable -Name PSWindowsUpdate)) {
    Install-Module -Name PSWindowsUpdate -Force -Confirm:$false
}
Import-Module PSWindowsUpdate -Force

Write-Host "=== 3. Registrazione Microsoft Update (include driver) ===" -ForegroundColor Cyan
Add-WUServiceManager -MicrosoftUpdate -Confirm:$false | Out-Null

Write-Host "=== 4. Scarico e installo tutti gli aggiornamenti (Windows + driver) ===" -ForegroundColor Cyan
Get-WindowsUpdate -MicrosoftUpdate -AcceptAll -Install -IgnoreReboot -Verbose

Write-Host ""
Write-Host "=== Aggiornamento completato ===" -ForegroundColor Green

# NOTA: il riavvio NON viene eseguito automaticamente qui.
# Un riavvio a questo punto interromperebbe pc_test.exe a meta' del collaudo,
# impedendo la generazione del report finale. Il riavvio va fatto manualmente
# dall'operatore SOLO dopo che il collaudo completo (incluso il report TXT) e' terminato.
if (Get-WURebootStatus -Silent) {
    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Yellow
    Write-Host "RIAVVIO RICHIESTO PER COMPLETARE L'INSTALLAZIONE" -ForegroundColor Yellow
    Write-Host "Riavviare il PC manualmente al termine dell'intero collaudo." -ForegroundColor Yellow
    Write-Host "============================================================" -ForegroundColor Yellow
}
