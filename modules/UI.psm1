# UI.psm1 - Module d'interface utilisateur pour ITSMBootstrap

function Show-Banner {
    $banner = @"

  _____ _____ ____  __  __   ____              _       _
 |_   _|_   _/ ___||  \/  | | __ )  ___   ___ | |_ ___| |_ _ __ __ _ _ __
   | |   | | \___ \| |\/| | |  _ \ / _ \ / _ \| __/ __| __| '__/ _` | '_ \
   | |   | |  ___) | |  | | | |_) | (_) | (_) | |_\__ \ |_| | | (_| | |_) |
   |_|   |_| |____/|_|  |_| |____/ \___/ \___/ \__|___/\__|_|  \__,_| .__/
                                                                    |_|
                         ITSM Factory - Windows Setup

"@
    Write-Host $banner -ForegroundColor Magenta
}

function Show-AppSelector {
    param(
        [Parameter(Mandatory = $true)]
        [array]$Apps,

        [hashtable]$Categories
    )

    Write-Host "`n  Selection des applications a installer" -ForegroundColor Cyan
    Write-Host "  (Espace = selectionner, Entree = valider, A = tout, N = rien)`n" -ForegroundColor DarkGray

    # Grouper par catégorie
    $grouped = @{}
    foreach ($app in $Apps) {
        $cat = $app.category
        if (-not $grouped.ContainsKey($cat)) {
            $grouped[$cat] = @()
        }
        $grouped[$cat] += $app
    }

    # État de sélection (tout sélectionné par défaut sauf si required = false)
    $selected = @{}
    foreach ($app in $Apps) {
        $selected[$app.id] = ($app.required -ne $false)
    }

    $currentIndex = 0
    $flatList = @()

    # Construire liste plate pour navigation
    foreach ($catKey in ($grouped.Keys | Sort-Object)) {
        foreach ($app in $grouped[$catKey]) {
            $flatList += @{
                app = $app
                category = $catKey
            }
        }
    }

    $done = $false

    while (-not $done) {
        Clear-Host
        Show-Banner

        Write-Host "  Selection des applications" -ForegroundColor Cyan
        Write-Host "  [Espace] Selectionner  [A] Tout  [N] Rien  [Entree] Valider`n" -ForegroundColor DarkGray

        $lastCat = ""
        $index = 0

        foreach ($item in $flatList) {
            $app = $item.app
            $cat = $item.category

            # Afficher header catégorie
            if ($cat -ne $lastCat) {
                $catName = if ($Categories -and $Categories[$cat]) { $Categories[$cat] } else { $cat }
                Write-Host "`n  --- $catName ---" -ForegroundColor Yellow
                $lastCat = $cat
            }

            # Indicateur de sélection
            $check = if ($selected[$app.id]) { "[X]" } else { "[ ]" }
            $color = if ($index -eq $currentIndex) { "White" } else { "Gray" }
            $pointer = if ($index -eq $currentIndex) { ">" } else { " " }
            $reqMarker = if ($app.required) { "*" } else { " " }

            Write-Host "  $pointer $check $($app.name)$reqMarker" -ForegroundColor $color -NoNewline

            if ($app.description -and $index -eq $currentIndex) {
                Write-Host " - $($app.description)" -ForegroundColor DarkGray
            } else {
                Write-Host ""
            }

            $index++
        }

        Write-Host "`n  * = Requis (ne peut pas etre desactive)" -ForegroundColor DarkGray

        # Lecture touche
        $key = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

        switch ($key.VirtualKeyCode) {
            38 { # Fleche haut
                $currentIndex = [Math]::Max(0, $currentIndex - 1)
            }
            40 { # Fleche bas
                $currentIndex = [Math]::Min($flatList.Count - 1, $currentIndex + 1)
            }
            32 { # Espace
                $app = $flatList[$currentIndex].app
                if (-not $app.required) {
                    $selected[$app.id] = -not $selected[$app.id]
                }
            }
            65 { # A - Tout sélectionner
                foreach ($app in $Apps) {
                    $selected[$app.id] = $true
                }
            }
            78 { # N - Rien sélectionner
                foreach ($app in $Apps) {
                    if (-not $app.required) {
                        $selected[$app.id] = $false
                    }
                }
            }
            13 { # Entrée - Valider
                $done = $true
            }
        }
    }

    # Retourner les apps sélectionnées
    return $Apps | Where-Object { $selected[$_.id] }
}

function Read-GitConfig {
    Write-Host "`n  Configuration Git" -ForegroundColor Cyan
    Write-Host "  -----------------`n" -ForegroundColor DarkCyan

    $name = ""
    while ([string]::IsNullOrWhiteSpace($name)) {
        Write-Host "  Votre nom complet: " -NoNewline -ForegroundColor White
        $name = Read-Host
        if ([string]::IsNullOrWhiteSpace($name)) {
            Write-Host "  ! Le nom ne peut pas etre vide" -ForegroundColor Yellow
        }
    }

    $email = ""
    while ([string]::IsNullOrWhiteSpace($email) -or $email -notmatch "^[\w\.-]+@[\w\.-]+\.\w+$") {
        Write-Host "  Votre email: " -NoNewline -ForegroundColor White
        $email = Read-Host
        if ([string]::IsNullOrWhiteSpace($email)) {
            Write-Host "  ! L'email ne peut pas etre vide" -ForegroundColor Yellow
        } elseif ($email -notmatch "^[\w\.-]+@[\w\.-]+\.\w+$") {
            Write-Host "  ! Format d'email invalide" -ForegroundColor Yellow
        }
    }

    return @{
        Name = $name
        Email = $email
    }
}

function Confirm-Action {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [switch]$DefaultYes
    )

    $default = if ($DefaultYes) { "[O/n]" } else { "[o/N]" }
    Write-Host "`n  $Message $default " -NoNewline -ForegroundColor Yellow
    $response = Read-Host

    if ([string]::IsNullOrWhiteSpace($response)) {
        return $DefaultYes
    }

    return $response -match "^[oOyY]"
}

function Show-Progress {
    param(
        [int]$Current,
        [int]$Total,
        [string]$Activity
    )

    $percent = [math]::Round(($Current / $Total) * 100)
    $barLength = 30
    $filledLength = [math]::Round($barLength * $Current / $Total)
    $bar = ("=" * $filledLength) + ("-" * ($barLength - $filledLength))

    Write-Host "`r  [$bar] $percent% - $Activity" -NoNewline -ForegroundColor Cyan

    if ($Current -eq $Total) {
        Write-Host ""
    }
}

function Read-Choice {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [Parameter(Mandatory = $true)]
        [array]$Options
    )

    Write-Host "`n  $Message" -ForegroundColor Cyan

    for ($i = 0; $i -lt $Options.Count; $i++) {
        Write-Host "    [$($i + 1)] $($Options[$i])" -ForegroundColor White
    }

    $choice = 0
    while ($choice -lt 1 -or $choice -gt $Options.Count) {
        Write-Host "`n  Votre choix (1-$($Options.Count)): " -NoNewline -ForegroundColor Yellow
        $input = Read-Host
        if ($input -match "^\d+$") {
            $choice = [int]$input
        }
    }

    return $choice - 1
}

Export-ModuleMember -Function Show-Banner, Show-AppSelector, Read-GitConfig, Confirm-Action, Show-Progress, Read-Choice
