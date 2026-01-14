# bootstrap.ps1 - Point d'entree ITSM Factory Bootstrap
# Usage: irm https://raw.githubusercontent.com/USER/ITSMBootstrap/main/bootstrap.ps1 | iex
#
# Variables d'environnement optionnelles:
#   $env:BOOTSTRAP_DRYRUN = "1"   -> Mode simulation
#   $env:BOOTSTRAP_RESUME = "1"   -> Reprendre une installation interrompue

#Requires -Version 5.1

$ErrorActionPreference = "Stop"

# Configuration
$RepoUrl = "https://github.com/AlxFrst/ITSMBootstrap.git"
$TempDir = Join-Path $env:TEMP "ITSMBootstrap_$(Get-Random)"
$MainScript = "main.ps1"

# Banniere
Write-Host ""
Write-Host "  ================================================" -ForegroundColor Magenta
Write-Host "       ITSM Factory Bootstrap - Initialisation    " -ForegroundColor Magenta
Write-Host "  ================================================" -ForegroundColor Magenta
Write-Host ""

# Verification des droits admin
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "  ! Ce script necessite les droits administrateur." -ForegroundColor Yellow
    Write-Host "  ! Relancement en mode administrateur..." -ForegroundColor Yellow
    Write-Host ""

    # Construire la commande a relancer
    $scriptUrl = "https://raw.githubusercontent.com/AlxFrst/ITSMBootstrap/master/bootstrap.ps1"
    $cmd = "irm '$scriptUrl' | iex"

    # Passer les variables d'environnement
    if ($env:BOOTSTRAP_DRYRUN) { $cmd = "`$env:BOOTSTRAP_DRYRUN='1'; $cmd" }
    if ($env:BOOTSTRAP_RESUME) { $cmd = "`$env:BOOTSTRAP_RESUME='1'; $cmd" }

    Start-Process powershell -Verb RunAs -ArgumentList "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", $cmd
    exit
}

# Verification de Git
Write-Host "  * Verification de Git..." -ForegroundColor Cyan
$gitInstalled = $null -ne (Get-Command git -ErrorAction SilentlyContinue)

if (-not $gitInstalled) {
    Write-Host "  ! Git n'est pas installe. Installation via winget..." -ForegroundColor Yellow

    $wingetInstalled = $null -ne (Get-Command winget -ErrorAction SilentlyContinue)

    if (-not $wingetInstalled) {
        Write-Host "  X winget n'est pas disponible." -ForegroundColor Red
        Write-Host "  X Veuillez installer Git manuellement: https://git-scm.com" -ForegroundColor Red
        Write-Host ""
        Read-Host "Appuyez sur Entree pour quitter"
        exit 1
    }

    winget install Git.Git --source winget --silent --accept-package-agreements --accept-source-agreements

    # Rafraichir le PATH
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")

    # Re-verifier
    $gitInstalled = $null -ne (Get-Command git -ErrorAction SilentlyContinue)

    if (-not $gitInstalled) {
        Write-Host "  X Echec de l'installation de Git." -ForegroundColor Red
        Write-Host "  X Veuillez redemarrer PowerShell et reessayer." -ForegroundColor Red
        Write-Host ""
        Read-Host "Appuyez sur Entree pour quitter"
        exit 1
    }

    Write-Host "  * Git installe avec succes !" -ForegroundColor Green
}

# Clonage du repository
Write-Host "  * Telechargement du bootstrap..." -ForegroundColor Cyan

if (Test-Path $TempDir) {
    Remove-Item -Recurse -Force $TempDir
}

# Utiliser cmd pour eviter que PowerShell traite stderr de git comme erreur
cmd /c "git clone --depth 1 $RepoUrl `"$TempDir`" 2>nul"

if (-not (Test-Path (Join-Path $TempDir $MainScript))) {
    Write-Host "  X Echec du telechargement. Verifiez votre connexion internet." -ForegroundColor Red
    Write-Host "  X URL: $RepoUrl" -ForegroundColor Red
    Write-Host ""
    Read-Host "Appuyez sur Entree pour quitter"
    exit 1
}

Write-Host "  * Telechargement termine !" -ForegroundColor Green

# Construction des arguments
$arguments = @()

if ($env:BOOTSTRAP_DRYRUN -eq "1") {
    $arguments += "-DryRun"
    Write-Host "  # Mode DRY-RUN active" -ForegroundColor DarkGray
}

if ($env:BOOTSTRAP_RESUME -eq "1") {
    $arguments += "-Resume"
    Write-Host "  # Mode RESUME active" -ForegroundColor DarkGray
}

# Lancement du script principal
Write-Host ""
Write-Host "  * Lancement de l'installation..." -ForegroundColor Cyan
Write-Host ""

try {
    $mainScriptPath = Join-Path $TempDir $MainScript
    & $mainScriptPath @arguments
}
catch {
    Write-Host ""
    Write-Host "  X Erreur durant l'installation: $_" -ForegroundColor Red
}
finally {
    # Nettoyage
    if (Test-Path $TempDir) {
        Remove-Item -Recurse -Force $TempDir -ErrorAction SilentlyContinue
    }
}

Write-Host ""
Write-Host "  Fin du bootstrap." -ForegroundColor Magenta
Write-Host ""
