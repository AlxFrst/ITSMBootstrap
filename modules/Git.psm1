# Git.psm1 - Module de configuration Git

function Test-GitInstalled {
    try {
        $null = Get-Command git -ErrorAction Stop
        return $true
    }
    catch {
        return $false
    }
}

function Get-CurrentGitConfig {
    if (-not (Test-GitInstalled)) {
        return $null
    }

    try {
        $name = git config --global user.name 2>$null
        $email = git config --global user.email 2>$null

        return @{
            Name = $name
            Email = $email
        }
    }
    catch {
        return $null
    }
}

function Set-GitConfig {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [string]$Email,

        [switch]$DryRun
    )

    if ($DryRun) {
        Write-Log "[DRY-RUN] Configurerait Git:" -Level INFO
        Write-Log "  user.name = $Name" -Level INFO
        Write-Log "  user.email = $Email" -Level INFO
        Write-Log "  init.defaultBranch = master" -Level INFO
        Write-Log "  core.autocrlf = true" -Level INFO
        return $true
    }

    if (-not (Test-GitInstalled)) {
        Write-Log "Git n'est pas installe. Installez-le d'abord." -Level ERROR
        return $false
    }

    try {
        Write-Log "Configuration de Git..." -Level INFO

        git config --global user.name $Name
        Write-Log "  user.name = $Name" -Level SUCCESS

        git config --global user.email $Email
        Write-Log "  user.email = $Email" -Level SUCCESS

        git config --global init.defaultBranch master
        Write-Log "  init.defaultBranch = master" -Level SUCCESS

        git config --global core.autocrlf true
        Write-Log "  core.autocrlf = true" -Level SUCCESS

        # Configurations additionnelles utiles
        git config --global pull.rebase false
        Write-Log "  pull.rebase = false" -Level SUCCESS

        git config --global fetch.prune true
        Write-Log "  fetch.prune = true" -Level SUCCESS

        return $true
    }
    catch {
        Write-Log "Erreur configuration Git: $_" -Level ERROR
        return $false
    }
}

function Test-GitConfigured {
    $config = Get-CurrentGitConfig

    if (-not $config) {
        return $false
    }

    return (-not [string]::IsNullOrWhiteSpace($config.Name)) -and
           (-not [string]::IsNullOrWhiteSpace($config.Email))
}

Export-ModuleMember -Function Test-GitInstalled, Get-CurrentGitConfig, Set-GitConfig, Test-GitConfigured
