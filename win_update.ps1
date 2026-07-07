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

# Riavvio se richiesto da un aggiornamento (facoltativo, commenta se non vuoi il riavvio automatico)
if (Get-WURebootStatus -Silent) {
    Write-Host "E' richiesto un riavvio per completare l'installazione." -ForegroundColor Yellow
    $risposta = Read-Host "Riavviare ora? (S/N)"
    if ($risposta -match '^[Ss]') {
        Restart-Computer -Force
    }
}