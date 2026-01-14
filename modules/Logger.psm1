# Logger.psm1 - Module de logging pour ITSMBootstrap

$script:LogPath = $null
$script:DryRun = $false

function Initialize-Logger {
    param(
        [switch]$DryRun
    )

    $script:DryRun = $DryRun
    $logDir = "C:\Dev\Logs"

    if (-not (Test-Path $logDir)) {
        if (-not $script:DryRun) {
            New-Item -ItemType Directory -Force -Path $logDir | Out-Null
        }
    }

    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $script:LogPath = Join-Path $logDir "bootstrap_$timestamp.log"

    if (-not $script:DryRun) {
        $header = @"
========================================
  ITSM Factory Bootstrap Log
  Started: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
  Computer: $env:COMPUTERNAME
  User: $env:USERNAME
========================================

"@
        $header | Out-File -FilePath $script:LogPath -Encoding UTF8
    }

    return $script:LogPath
}

function Write-Log {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [ValidateSet("INFO", "WARN", "ERROR", "SUCCESS", "DEBUG")]
        [string]$Level = "INFO",

        [switch]$NoConsole
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"

    # Couleurs pour la console
    $colors = @{
        "INFO"    = "White"
        "WARN"    = "Yellow"
        "ERROR"   = "Red"
        "SUCCESS" = "Green"
        "DEBUG"   = "DarkGray"
    }

    # Prefixes visuels
    $prefixes = @{
        "INFO"    = "  "
        "WARN"    = "! "
        "ERROR"   = "X "
        "SUCCESS" = "* "
        "DEBUG"   = "# "
    }

    # Ecriture console
    if (-not $NoConsole) {
        $prefix = $prefixes[$Level]
        $color = $colors[$Level]
        Write-Host "$prefix$Message" -ForegroundColor $color
    }

    # Ecriture fichier
    if ($script:LogPath -and -not $script:DryRun) {
        $logMessage | Out-File -FilePath $script:LogPath -Append -Encoding UTF8
    }
}

function Write-Section {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Title,

        [int]$Step,
        [int]$TotalSteps
    )

    $stepInfo = if ($Step -and $TotalSteps) { "[$Step/$TotalSteps] " } else { "" }

    Write-Host ""
    Write-Host "-------------------------------------------" -ForegroundColor DarkCyan
    Write-Host "$stepInfo$Title" -ForegroundColor Cyan
    Write-Host "-------------------------------------------" -ForegroundColor DarkCyan

    if ($script:LogPath -and -not $script:DryRun) {
        "`n=== $stepInfo$Title ===" | Out-File -FilePath $script:LogPath -Append -Encoding UTF8
    }
}

function Get-LogPath {
    return $script:LogPath
}

function Write-Summary {
    param(
        [int]$SuccessCount,
        [int]$FailCount,
        [int]$SkipCount
    )

    Write-Host ""
    Write-Host "========================================" -ForegroundColor Magenta
    Write-Host "            RESUME                      " -ForegroundColor Magenta
    Write-Host "========================================" -ForegroundColor Magenta
    Write-Host "  Succes:  $SuccessCount" -ForegroundColor Green
    Write-Host "  Echecs:  $FailCount" -ForegroundColor $(if ($FailCount -gt 0) { "Red" } else { "White" })
    Write-Host "  Ignores: $SkipCount" -ForegroundColor DarkGray
    Write-Host "========================================" -ForegroundColor Magenta

    if ($script:LogPath) {
        Write-Host ""
        Write-Host "  Log: $script:LogPath" -ForegroundColor DarkGray
    }
}

Export-ModuleMember -Function Initialize-Logger, Write-Log, Write-Section, Get-LogPath, Write-Summary
