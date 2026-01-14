# Apps.psm1 - Module d'installation des applications via winget

function Test-WingetInstalled {
    try {
        $null = Get-Command winget -ErrorAction Stop
        return $true
    }
    catch {
        return $false
    }
}

function Test-AppInstalled {
    param(
        [Parameter(Mandatory = $true)]
        [string]$AppId
    )

    try {
        $result = winget list --id $AppId --accept-source-agreements 2>$null
        return $result -match $AppId
    }
    catch {
        return $false
    }
}

function Install-App {
    param(
        [Parameter(Mandatory = $true)]
        [string]$AppId,

        [Parameter(Mandatory = $true)]
        [string]$AppName,

        [switch]$DryRun
    )

    if ($DryRun) {
        Write-Log "[DRY-RUN] Installerait: $AppName ($AppId)" -Level INFO
        return @{ Success = $true; Skipped = $false }
    }

    # Vérifier si déjà installé
    if (Test-AppInstalled -AppId $AppId) {
        Write-Log "$AppName deja installe" -Level DEBUG
        return @{ Success = $true; Skipped = $true }
    }

    try {
        Write-Log "Installation de $AppName..." -Level INFO

        $process = Start-Process -FilePath "winget" -ArgumentList @(
            "install",
            "--id", $AppId,
            "--source", "winget",
            "--silent",
            "--accept-package-agreements",
            "--accept-source-agreements"
        ) -Wait -PassThru -NoNewWindow

        if ($process.ExitCode -eq 0) {
            Write-Log "$AppName installe avec succes" -Level SUCCESS
            return @{ Success = $true; Skipped = $false }
        }
        else {
            Write-Log "Echec installation $AppName (code: $($process.ExitCode))" -Level ERROR
            return @{ Success = $false; Skipped = $false }
        }
    }
    catch {
        Write-Log "Erreur lors de l'installation de $AppName : $_" -Level ERROR
        return @{ Success = $false; Skipped = $false }
    }
}

function Install-Apps {
    param(
        [Parameter(Mandatory = $true)]
        [array]$Apps,

        [hashtable]$ProgressState,

        [switch]$DryRun
    )

    $results = @{
        Success = 0
        Failed = 0
        Skipped = 0
    }

    # Vérifier winget
    if (-not $DryRun -and -not (Test-WingetInstalled)) {
        Write-Log "winget n'est pas installe. Veuillez installer App Installer depuis le Microsoft Store." -Level ERROR
        return $results
    }

    $total = $Apps.Count
    $current = 0

    foreach ($app in $Apps) {
        $current++

        # Vérifier si déjà installé dans cette session
        if ($ProgressState -and $app.id -in $ProgressState.installedApps) {
            Write-Log "[$current/$total] $($app.name) - deja traite" -Level DEBUG
            $results.Skipped++
            continue
        }

        Write-Host "`n  [$current/$total] " -NoNewline -ForegroundColor DarkGray

        $result = Install-App -AppId $app.id -AppName $app.name -DryRun:$DryRun

        if ($result.Success) {
            if ($result.Skipped) {
                $results.Skipped++
            }
            else {
                $results.Success++
            }

            # Mettre à jour progression
            if ($ProgressState) {
                Update-ProgressApp -State $ProgressState -AppId $app.id -Status "Installed"
            }
        }
        else {
            $results.Failed++

            if ($ProgressState) {
                Update-ProgressApp -State $ProgressState -AppId $app.id -Status "Failed"
            }
        }
    }

    return $results
}

Export-ModuleMember -Function Test-WingetInstalled, Test-AppInstalled, Install-App, Install-Apps
