# system_report.ps1
# Report di sistema: stato batteria, numero seriale, CPU, tipo PC, RAM, spazio disco e salute SSD.

$logPath = Join-Path $PSScriptRoot "system_report_output.txt"
Start-Transcript -Path $logPath -Force | Out-Null

# ============================================================
# STATO BATTERIA
# ============================================================
Write-Host "================================"
Write-Host "STATO BATTERIA"
Write-Host "================================"

$reportPath = Join-Path $env:TEMP "battery-report.html"

try {
    powercfg /batteryreport /output "$reportPath" | Out-Null
} catch {
    Write-Host "Errore durante l'esecuzione di powercfg: $_"
}

if (Test-Path $reportPath) {
    $html = Get-Content -Path $reportPath -Raw

    $designMatch = [regex]::Match($html, '(?s)DESIGN CAPACITY.*?<td[^>]*>(.*?)</td>')
    $fullMatch   = [regex]::Match($html, '(?s)FULL CHARGE CAPACITY.*?<td[^>]*>(.*?)</td>')

    if ($designMatch.Success -and $fullMatch.Success) {
        $designValue = [int]([regex]::Replace($designMatch.Groups[1].Value, '[^\d]', ''))
        $fullValue   = [int]([regex]::Replace($fullMatch.Groups[1].Value, '[^\d]', ''))

        if ($designValue -gt 0) {
            $batteryPercentage = [math]::Round(($fullValue / $designValue) * 100)
            $batteryLine = "Stato Batteria: $batteryPercentage%"
            if ($batteryPercentage -lt 80) {
                $batteryLine += " - DA SOSTITUIRE"
            }
            Write-Host $batteryLine
            Write-Host "Design Capacity:      $designValue mWh"
            Write-Host "Full Charge Capacity: $fullValue mWh"
        } else {
            Write-Host "Valore di Design Capacity non valido."
        }
    } else {
        Write-Host "Non e' stato possibile trovare i dati di capacita' nel report."
    }
    Write-Host "Report completo salvato in: $reportPath"
} else {
    Write-Host "Impossibile trovare il file battery-report.html generato."
    Write-Host "(Su desktop senza batteria questo e' normale)"
}

Write-Host ""

# ============================================================
# NUMERO SERIALE
# ============================================================
Write-Host "================================"
Write-Host "NUMERO SERIALE"
Write-Host "================================"

try {
    $bios = Get-CimInstance -ClassName Win32_BIOS -ErrorAction Stop
    $serial = $bios.SerialNumber
    if ([string]::IsNullOrWhiteSpace($serial) -or $serial -eq "System Serial Number" -or $serial -eq "Default string") {
        $csp = Get-CimInstance -ClassName Win32_ComputerSystemProduct -ErrorAction Stop
        $serial = $csp.IdentifyingNumber
    }
    Write-Host "Numero Seriale: $serial"
} catch {
    Write-Host "Numero Seriale: non disponibile"
}

Write-Host ""

# ============================================================
# TIPO DISPOSITIVO E CPU
# ============================================================
Write-Host "================================"
Write-Host "TIPO DISPOSITIVO E CPU"
Write-Host "================================"

try {
    $cs = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction Stop
    $tipoPC = switch ($cs.PCSystemType) {
        1 { "Desktop" }
        2 { "Laptop/Notebook" }
        3 { "Workstation" }
        4 { "Enterprise Server" }
        5 { "SOHO Server" }
        6 { "Appliance PC" }
        7 { "Performance Server" }
        8 { "Slate/Tablet" }
        default { "Non specificato" }
    }
    Write-Host "Tipo PC: $tipoPC"
    Write-Host "Produttore: $($cs.Manufacturer)"
    Write-Host "Modello: $($cs.Model)"
} catch {
    Write-Host "Tipo PC: non disponibile"
}

try {
    $cpu = Get-CimInstance -ClassName Win32_Processor -ErrorAction Stop | Select-Object -First 1
    $cpuName = ($cpu.Name -replace '\s+', ' ').Trim()
    Write-Host "CPU: $cpuName"
} catch {
    Write-Host "CPU: non disponibile"
}

Write-Host ""

# ============================================================
# RAM
# ============================================================
Write-Host "================================"
Write-Host "RAM"
Write-Host "================================"

try {
    $os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
    $totalRamGB = [math]::Round($os.TotalVisibleMemorySize / 1MB, 2)
    $freeRamGB  = [math]::Round($os.FreePhysicalMemory / 1MB, 2)
    $usedRamGB  = [math]::Round($totalRamGB - $freeRamGB, 2)
    $ramPercentUsed = [math]::Round((($totalRamGB - $freeRamGB) / $totalRamGB) * 100)

    Write-Host "RAM Totale: $totalRamGB GB"
    Write-Host "RAM Usata:  $usedRamGB GB ($ramPercentUsed%)"
    Write-Host "RAM Libera: $freeRamGB GB"

    $modules = Get-CimInstance -ClassName Win32_PhysicalMemory -ErrorAction Stop
    $i = 1
    foreach ($mod in $modules) {
        $capGB = [math]::Round($mod.Capacity / 1GB, 2)
        Write-Host "  Banco $i : $capGB GB - $($mod.Speed) MHz - $($mod.Manufacturer)"
        $i++
    }
} catch {
    Write-Host "RAM: dati non disponibili"
}

Write-Host ""

# ============================================================
# SPAZIO SU DISCO
# ============================================================
Write-Host "================================"
Write-Host "SPAZIO SU DISCO"
Write-Host "================================"

try {
    $disks = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DriveType=3" -ErrorAction Stop
    foreach ($disk in $disks) {
        $totalGB = [math]::Round($disk.Size / 1GB, 2)
        $freeGB  = [math]::Round($disk.FreeSpace / 1GB, 2)
        $usedGB  = [math]::Round($totalGB - $freeGB, 2)
        $percentUsed = [math]::Round((($totalGB - $freeGB) / $totalGB) * 100)
        Write-Host "Disco $($disk.DeviceID) - Totale: $totalGB GB | Usato: $usedGB GB ($percentUsed%) | Libero: $freeGB GB"
    }
} catch {
    Write-Host "Spazio disco: dati non disponibili"
}

Write-Host ""

# ============================================================
# SALUTE SSD
# ============================================================
Write-Host "================================"
Write-Host "SALUTE SSD"
Write-Host "================================"

try {
    $physicalDisks = Get-PhysicalDisk -ErrorAction Stop
    foreach ($pd in $physicalDisks) {
        $name = $pd.FriendlyName
        $mediaType = $pd.MediaType
        $healthStatus = $pd.HealthStatus
        $wearLine = ""

        try {
            $reliability = $pd | Get-StorageReliabilityCounter -ErrorAction Stop
            if ($null -ne $reliability.Wear) {
                $ssdHealth = 100 - $reliability.Wear
                $wearLine = " | Salute SSD: $ssdHealth%"
                if ($ssdHealth -lt 75) {
                    $wearLine += " - DA SOSTITUIRE"
                }
            }
        } catch {
            $wearLine = " | Dato di usura non supportato da questo disco"
        }

        Write-Host "$name ($mediaType) - Stato: $healthStatus$wearLine"
    }
} catch {
    Write-Host "Salute SSD: dati non disponibili (servono permessi di amministratore)"
}

Write-Host ""
Write-Host "================================"
Write-Host "Report completato."
Write-Host "================================"

Stop-Transcript | Out-Null
