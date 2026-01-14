# main.ps1 - Script principal ITSM Factory Bootstrap
# Ce script est appele par bootstrap.ps1 apres le clonage du repo

#Requires -Version 5.1

param(
    [switch]$DryRun,
    [switch]$Resume,
    [switch]$SkipApps,
    [switch]$SkipExtensions
)

$ErrorActionPreference = "Stop"
$scriptRoot = $PSScriptRoot

# ===========================================
# Chargement des modules
# ===========================================
$modules = @(
    "Logger",
    "UI",
    "Progress",
    "Apps",
    "Git",
    "Windows",
    "VSCode"
)

foreach ($module in $modules) {
    $modulePath = Join-Path $scriptRoot "modules\$module.psm1"
    if (Test-Path $modulePath) {
        Import-Module $modulePath -Force -DisableNameChecking
    }
    else {
        Write-Host "  X Module introuvable: $module" -ForegroundColor Red
        exit 1
    }
}

# ===========================================
# Chargement des configurations
# ===========================================
$appsConfig = Get-Content (Join-Path $scriptRoot "config\apps.json") -Raw | ConvertFrom-Json
$extensionsConfig = Get-Content (Join-Path $scriptRoot "config\extensions.json") -Raw | ConvertFrom-Json
$foldersConfig = Get-Content (Join-Path $scriptRoot "config\folders.json") -Raw | ConvertFrom-Json

# ===========================================
# Initialisation
# ===========================================
Clear-Host
Show-Banner

# Initialiser le logger
$logPath = Initialize-Logger -DryRun:$DryRun

if ($DryRun) {
    Write-Host ""
    Write-Host "  ========================================" -ForegroundColor Yellow
    Write-Host "           MODE SIMULATION (DRY-RUN)      " -ForegroundColor Yellow
    Write-Host "    Aucune modification ne sera faite     " -ForegroundColor Yellow
    Write-Host "  ========================================" -ForegroundColor Yellow
}

# ===========================================
# Gestion de la reprise
# ===========================================
$progressState = $null
$selectedApps = @()
$gitConfig = $null

if ($Resume -and (Test-ProgressExists)) {
    Write-Host ""
    Write-Log "Reprise d'une installation precedente detectee" -Level INFO

    $progressState = Get-Progress

    if ($progressState) {
        $selectedApps = $appsConfig.apps | Where-Object { $_.id -in $progressState.selectedApps }
        $gitConfig = $progressState.gitConfig

        Write-Log "  Etape: $($progressState.currentStep)/$($progressState.totalSteps)" -Level INFO
        Write-Log "  Apps installees: $($progressState.installedApps.Count)" -Level INFO
        Write-Log "  Apps en echec: $($progressState.failedApps.Count)" -Level INFO

        $continueResume = Confirm-Action -Message "Reprendre cette installation ?" -DefaultYes

        if (-not $continueResume) {
            Clear-Progress
            $progressState = $null
            Write-Log "Installation precedente annulee. Nouvelle installation." -Level INFO
        }
    }
}

# ===========================================
# Selection des applications
# ===========================================
if (-not $progressState -and -not $SkipApps) {
    Write-Section -Title "Selection des applications" -Step 0 -TotalSteps 6

    # Convertir categories en hashtable
    $categories = @{}
    $appsConfig.categories.PSObject.Properties | ForEach-Object {
        $categories[$_.Name] = $_.Value
    }

    $selectedApps = Show-AppSelector -Apps $appsConfig.apps -Categories $categories

    Write-Host ""
    Write-Log "$($selectedApps.Count) applications selectionnees" -Level SUCCESS
}
elseif ($SkipApps) {
    Write-Log "Installation des applications ignoree (--SkipApps)" -Level INFO
    $selectedApps = @()
}

# ===========================================
# Configuration Git
# ===========================================
if (-not $progressState -or -not $progressState.gitConfig) {
    Write-Section -Title "Configuration Git" -Step 0 -TotalSteps 6

    $existingConfig = Get-CurrentGitConfig

    if ($existingConfig -and $existingConfig.Name -and $existingConfig.Email) {
        Write-Log "Configuration Git existante detectee:" -Level INFO
        Write-Log "  Nom: $($existingConfig.Name)" -Level INFO
        Write-Log "  Email: $($existingConfig.Email)" -Level INFO

        $useExisting = Confirm-Action -Message "Garder cette configuration ?" -DefaultYes

        if ($useExisting) {
            $gitConfig = $existingConfig
        }
        else {
            $gitConfig = Read-GitConfig
        }
    }
    else {
        $gitConfig = Read-GitConfig
    }
}

# ===========================================
# Initialisation de l'etat de progression
# ===========================================
if (-not $progressState) {
    $progressState = New-ProgressState -SelectedApps $selectedApps -GitConfig $gitConfig
    Save-Progress -State $progressState
}

# ===========================================
# Compteurs
# ===========================================
$totalSuccess = 0
$totalFailed = 0
$totalSkipped = 0

# ===========================================
# ETAPE 1: Installation des applications
# ===========================================
if (-not $SkipApps -and $selectedApps.Count -gt 0 -and 1 -notin $progressState.completedSteps) {
    Write-Section -Title "Installation des applications" -Step 1 -TotalSteps 6
    Update-ProgressStep -State $progressState -Step 1

    $results = Install-Apps -Apps $selectedApps -ProgressState $progressState -DryRun:$DryRun

    $totalSuccess += $results.Success
    $totalFailed += $results.Failed
    $totalSkipped += $results.Skipped

    Update-ProgressStep -State $progressState -Step 1 -Completed
}
elseif (1 -in $progressState.completedSteps) {
    Write-Log "Etape 1 (Applications) deja completee - ignoree" -Level DEBUG
}

# ===========================================
# ETAPE 2: Configuration Git
# ===========================================
if (2 -notin $progressState.completedSteps) {
    Write-Section -Title "Configuration Git" -Step 2 -TotalSteps 6
    Update-ProgressStep -State $progressState -Step 2

    $gitResult = Set-GitConfig -Name $gitConfig.Name -Email $gitConfig.Email -DryRun:$DryRun

    if ($gitResult) {
        $totalSuccess++
    }
    else {
        $totalFailed++
    }

    Update-ProgressStep -State $progressState -Step 2 -Completed
}
else {
    Write-Log "Etape 2 (Git) deja completee - ignoree" -Level DEBUG
}

# ===========================================
# ETAPE 3: Creation des dossiers
# ===========================================
if (3 -notin $progressState.completedSteps) {
    Write-Section -Title "Creation des dossiers" -Step 3 -TotalSteps 6
    Update-ProgressStep -State $progressState -Step 3

    $folderPaths = $foldersConfig.folders | ForEach-Object { $_.path }
    $folderResults = New-DevFolders -Folders $folderPaths -DryRun:$DryRun

    $totalSuccess += $folderResults.Created
    $totalSkipped += $folderResults.Existed

    Update-ProgressStep -State $progressState -Step 3 -Completed
}
else {
    Write-Log "Etape 3 (Dossiers) deja completee - ignoree" -Level DEBUG
}

# ===========================================
# ETAPE 4: Installation WSL
# ===========================================
if (4 -notin $progressState.completedSteps) {
    Write-Section -Title "Installation WSL" -Step 4 -TotalSteps 6
    Update-ProgressStep -State $progressState -Step 4

    $wslResult = Install-WSL -DryRun:$DryRun

    if ($wslResult) {
        $totalSuccess++
    }
    else {
        $totalFailed++
    }

    Update-ProgressStep -State $progressState -Step 4 -Completed
}
else {
    Write-Log "Etape 4 (WSL) deja completee - ignoree" -Level DEBUG
}

# ===========================================
# ETAPE 5: Configuration Windows
# ===========================================
if (5 -notin $progressState.completedSteps) {
    Write-Section -Title "Configuration Windows" -Step 5 -TotalSteps 6
    Update-ProgressStep -State $progressState -Step 5

    $tweakResults = Set-WindowsTweaks -DryRun:$DryRun

    $totalSuccess += $tweakResults.Success
    $totalFailed += $tweakResults.Failed

    Update-ProgressStep -State $progressState -Step 5 -Completed
}
else {
    Write-Log "Etape 5 (Windows) deja completee - ignoree" -Level DEBUG
}

# ===========================================
# ETAPE 6: Extensions VSCode
# ===========================================
if (-not $SkipExtensions -and 6 -notin $progressState.completedSteps) {
    Write-Section -Title "Extensions VSCode" -Step 6 -TotalSteps 6
    Update-ProgressStep -State $progressState -Step 6

    $extResults = Install-VSCodeExtensions -Extensions $extensionsConfig.extensions -DryRun:$DryRun

    $totalSuccess += $extResults.Success
    $totalFailed += $extResults.Failed
    $totalSkipped += $extResults.Skipped

    Update-ProgressStep -State $progressState -Step 6 -Completed
}
elseif ($SkipExtensions) {
    Write-Log "Extensions VSCode ignorees (--SkipExtensions)" -Level INFO
}
else {
    Write-Log "Etape 6 (Extensions) deja completee - ignoree" -Level DEBUG
}

# ===========================================
# Resume final
# ===========================================
Write-Summary -SuccessCount $totalSuccess -FailCount $totalFailed -SkipCount $totalSkipped

# Nettoyer la progression si tout est OK
if ($totalFailed -eq 0) {
    Clear-Progress
}
else {
    Write-Host ""
    Write-Log "Des erreurs sont survenues. Utilisez -Resume pour reprendre." -Level WARN
    Write-Log "Fichier de progression: $(Get-ProgressFile)" -Level INFO
}

# ===========================================
# Actions restantes
# ===========================================
Write-Host ""
Write-Host "  Actions restantes:" -ForegroundColor Yellow
Write-Host "    - Redemarrer le PC pour finaliser WSL" -ForegroundColor White
Write-Host "    - Se connecter a Tailscale" -ForegroundColor White
Write-Host "    - Se connecter a Docker Desktop" -ForegroundColor White
Write-Host "    - Configurer les themes VSCode" -ForegroundColor White
Write-Host ""

if (-not $DryRun) {
    $restart = Confirm-Action -Message "Redemarrer maintenant ?"

    if ($restart) {
        Write-Log "Redemarrage dans 10 secondes..." -Level INFO
        Start-Sleep -Seconds 10
        Restart-Computer -Force
    }
}

Write-Host ""
Write-Host "  Merci d'utiliser ITSM Factory Bootstrap !" -ForegroundColor Magenta
Write-Host ""
