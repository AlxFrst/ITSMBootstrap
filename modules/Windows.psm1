# Windows.psm1 - Module de configuration Windows

function Set-WindowsTweaks {
    param(
        [switch]$DryRun
    )

    $tweaks = @(
        @{
            Name = "Desactiver Bing dans le menu demarrer"
            Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search"
            Key = "BingSearchEnabled"
            Value = 0
        },
        @{
            Name = "Afficher les extensions de fichiers"
            Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
            Key = "HideFileExt"
            Value = 0
        },
        @{
            Name = "Afficher les fichiers caches"
            Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
            Key = "Hidden"
            Value = 1
        },
        @{
            Name = "Desactiver les suggestions du menu demarrer"
            Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
            Key = "SubscribedContent-338388Enabled"
            Value = 0
        },
        @{
            Name = "Activer le mode sombre (Apps)"
            Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize"
            Key = "AppsUseLightTheme"
            Value = 0
        },
        @{
            Name = "Activer le mode sombre (Systeme)"
            Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize"
            Key = "SystemUsesLightTheme"
            Value = 0
        }
    )

    $success = 0
    $failed = 0

    foreach ($tweak in $tweaks) {
        if ($DryRun) {
            Write-Log "[DRY-RUN] $($tweak.Name)" -Level INFO
            $success++
            continue
        }

        try {
            # Créer le chemin de registre s'il n'existe pas
            if (-not (Test-Path $tweak.Path)) {
                New-Item -Path $tweak.Path -Force | Out-Null
            }

            Set-ItemProperty -Path $tweak.Path -Name $tweak.Key -Value $tweak.Value -ErrorAction Stop
            Write-Log "$($tweak.Name)" -Level SUCCESS
            $success++
        }
        catch {
            Write-Log "$($tweak.Name) - Echec: $_" -Level WARN
            $failed++
        }
    }

    return @{
        Success = $success
        Failed = $failed
    }
}

function Install-WSL {
    param(
        [switch]$DryRun
    )

    if ($DryRun) {
        Write-Log "[DRY-RUN] Installerait WSL" -Level INFO
        return $true
    }

    try {
        Write-Log "Installation de WSL..." -Level INFO

        $result = wsl --install --no-launch 2>&1

        Write-Log "WSL installe (redemarrage requis pour finaliser)" -Level SUCCESS
        return $true
    }
    catch {
        Write-Log "Erreur installation WSL: $_" -Level ERROR
        return $false
    }
}

function New-DevFolders {
    param(
        [Parameter(Mandatory = $true)]
        [array]$Folders,

        [switch]$DryRun
    )

    $created = 0
    $existed = 0

    foreach ($folder in $Folders) {
        if ($DryRun) {
            if (Test-Path $folder) {
                Write-Log "[DRY-RUN] Existe: $folder" -Level DEBUG
                $existed++
            }
            else {
                Write-Log "[DRY-RUN] Creerait: $folder" -Level INFO
                $created++
            }
            continue
        }

        if (-not (Test-Path $folder)) {
            try {
                New-Item -ItemType Directory -Force -Path $folder | Out-Null
                Write-Log "Cree: $folder" -Level SUCCESS
                $created++
            }
            catch {
                Write-Log "Echec creation: $folder - $_" -Level ERROR
            }
        }
        else {
            Write-Log "Existe: $folder" -Level DEBUG
            $existed++
        }
    }

    return @{
        Created = $created
        Existed = $existed
    }
}

function Test-AdminRights {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Request-AdminRights {
    if (-not (Test-AdminRights)) {
        Write-Log "Ce script necessite les droits administrateur." -Level WARN
        Write-Log "Relancement en tant qu'administrateur..." -Level INFO

        $scriptPath = $MyInvocation.PSCommandPath
        Start-Process powershell -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`""
        exit
    }
}

Export-ModuleMember -Function Set-WindowsTweaks, Install-WSL, New-DevFolders, Test-AdminRights, Request-AdminRights
