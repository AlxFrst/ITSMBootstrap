# Progress.psm1 - Module de sauvegarde/reprise de progression

$script:ProgressFile = "C:\Dev\.bootstrap_progress.json"

function Get-ProgressFile {
    return $script:ProgressFile
}

function Save-Progress {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$State
    )

    # S'assurer que le dossier parent existe
    $dir = Split-Path -Parent $script:ProgressFile
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
    }

    # Ajouter metadata
    $State["_lastUpdated"] = (Get-Date).ToString("o")
    $State["_version"] = "1.0"

    # Sauvegarder en JSON (Out-Null pour eviter l'affichage)
    $State | ConvertTo-Json -Depth 10 | Out-File -FilePath $script:ProgressFile -Encoding UTF8
}

function Get-Progress {
    if (-not (Test-Path $script:ProgressFile)) {
        return $null
    }

    try {
        $content = Get-Content $script:ProgressFile -Raw -Encoding UTF8
        $state = $content | ConvertFrom-Json -AsHashtable

        Write-Log "Progression recuperee depuis $script:ProgressFile" -Level DEBUG -NoConsole
        return $state
    }
    catch {
        Write-Log "Erreur lecture progression: $_" -Level WARN
        return $null
    }
}

function Clear-Progress {
    if (Test-Path $script:ProgressFile) {
        Remove-Item $script:ProgressFile -Force
        Write-Log "Fichier de progression supprime" -Level DEBUG -NoConsole
    }
}

function Test-ProgressExists {
    return (Test-Path $script:ProgressFile)
}

function New-ProgressState {
    param(
        [array]$SelectedApps,
        [hashtable]$GitConfig
    )

    return @{
        currentStep = 0
        totalSteps = 6
        installedApps = @()
        failedApps = @()
        selectedApps = $SelectedApps | ForEach-Object { $_.id }
        gitConfig = $GitConfig
        completedSteps = @()
        startedAt = (Get-Date).ToString("o")
    }
}

function Update-ProgressStep {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$State,

        [Parameter(Mandatory = $true)]
        [int]$Step,

        [switch]$Completed
    )

    $State.currentStep = $Step

    if ($Completed -and $Step -notin $State.completedSteps) {
        $State.completedSteps += $Step
    }

    Save-Progress -State $State
}

function Update-ProgressApp {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$State,

        [Parameter(Mandatory = $true)]
        [string]$AppId,

        [Parameter(Mandatory = $true)]
        [ValidateSet("Installed", "Failed", "Skipped")]
        [string]$Status
    )

    switch ($Status) {
        "Installed" {
            if ($AppId -notin $State.installedApps) {
                $State.installedApps += $AppId
            }
        }
        "Failed" {
            if ($AppId -notin $State.failedApps) {
                $State.failedApps += $AppId
            }
        }
    }

    Save-Progress -State $State
}

function Get-RemainingApps {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$State,

        [Parameter(Mandatory = $true)]
        [array]$AllApps
    )

    return $AllApps | Where-Object {
        $_.id -in $State.selectedApps -and
        $_.id -notin $State.installedApps
    }
}

Export-ModuleMember -Function Get-ProgressFile, Save-Progress, Get-Progress, Clear-Progress, Test-ProgressExists, New-ProgressState, Update-ProgressStep, Update-ProgressApp, Get-RemainingApps
