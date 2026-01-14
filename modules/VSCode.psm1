# VSCode.psm1 - Module d'installation des extensions VSCode

function Test-VSCodeInstalled {
    try {
        $null = Get-Command code -ErrorAction Stop
        return $true
    }
    catch {
        return $false
    }
}

function Get-InstalledExtensions {
    if (-not (Test-VSCodeInstalled)) {
        return @()
    }

    try {
        $extensions = code --list-extensions 2>$null
        return $extensions
    }
    catch {
        return @()
    }
}

function Test-ExtensionInstalled {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ExtensionId
    )

    $installed = Get-InstalledExtensions
    return $installed -contains $ExtensionId
}

function Install-VSCodeExtension {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ExtensionId,

        [string]$ExtensionName,

        [switch]$DryRun
    )

    $displayName = if ($ExtensionName) { $ExtensionName } else { $ExtensionId }

    if ($DryRun) {
        Write-Log "[DRY-RUN] Installerait extension: $displayName" -Level INFO
        return @{ Success = $true; Skipped = $false }
    }

    if (-not (Test-VSCodeInstalled)) {
        Write-Log "VSCode n'est pas installe" -Level WARN
        return @{ Success = $false; Skipped = $false }
    }

    # Vérifier si déjà installée
    if (Test-ExtensionInstalled -ExtensionId $ExtensionId) {
        Write-Log "$displayName deja installee" -Level DEBUG
        return @{ Success = $true; Skipped = $true }
    }

    try {
        Write-Log "Installation de $displayName..." -Level INFO

        $result = code --install-extension $ExtensionId --force 2>&1

        # Vérifier si l'installation a réussi
        if (Test-ExtensionInstalled -ExtensionId $ExtensionId) {
            Write-Log "$displayName installee" -Level SUCCESS
            return @{ Success = $true; Skipped = $false }
        }
        else {
            Write-Log "Echec installation $displayName" -Level ERROR
            return @{ Success = $false; Skipped = $false }
        }
    }
    catch {
        Write-Log "Erreur installation $displayName : $_" -Level ERROR
        return @{ Success = $false; Skipped = $false }
    }
}

function Install-VSCodeExtensions {
    param(
        [Parameter(Mandatory = $true)]
        [array]$Extensions,

        [switch]$DryRun
    )

    $results = @{
        Success = 0
        Failed = 0
        Skipped = 0
    }

    if (-not $DryRun -and -not (Test-VSCodeInstalled)) {
        Write-Log "VSCode n'est pas installe. Les extensions seront ignorees." -Level WARN
        return $results
    }

    $total = $Extensions.Count
    $current = 0

    foreach ($ext in $Extensions) {
        $current++
        Write-Host "  [$current/$total] " -NoNewline -ForegroundColor DarkGray

        $extId = if ($ext.id) { $ext.id } else { $ext }
        $extName = if ($ext.name) { $ext.name } else { $extId }

        $result = Install-VSCodeExtension -ExtensionId $extId -ExtensionName $extName -DryRun:$DryRun

        if ($result.Success) {
            if ($result.Skipped) {
                $results.Skipped++
            }
            else {
                $results.Success++
            }
        }
        else {
            $results.Failed++
        }
    }

    return $results
}

Export-ModuleMember -Function Test-VSCodeInstalled, Get-InstalledExtensions, Test-ExtensionInstalled, Install-VSCodeExtension, Install-VSCodeExtensions
