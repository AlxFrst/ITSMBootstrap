# ITSM Factory Bootstrap

Script d'automatisation pour configurer un environnement de developpement Windows.

## Installation rapide

Ouvrir PowerShell **en tant qu'administrateur** et executer :

```powershell
irm https://raw.githubusercontent.com/AlxFrst/ITSMBootstrap/master/bootstrap.ps1 | iex
```

> Remplacer `USER` par ton username GitHub.

## Options

### Mode simulation (dry-run)

Voir ce qui serait fait sans rien installer :

```powershell
$env:BOOTSTRAP_DRYRUN = "1"; irm https://raw.githubusercontent.com/AlxFrst/ITSMBootstrap/master/bootstrap.ps1 | iex
```

### Reprendre apres interruption

Si l'installation a ete interrompue, reprendre ou elle s'etait arretee :

```powershell
$env:BOOTSTRAP_RESUME = "1"; irm https://raw.githubusercontent.com/AlxFrst/ITSMBootstrap/master/bootstrap.ps1 | iex
```

## Ce qui est installe

### Applications (via winget)

| Categorie | Applications |
|-----------|--------------|
| Developpement | Git, VSCode, Docker, NVM, Windows Terminal, DBeaver, WinSCP, Postman |
| Productivite | Chrome, Notion |
| Communication | Discord, Tailscale, OpenVPN |
| Utilitaires | 7-Zip, PowerToys, Everything |
| Media | VLC, Spotify |

### Extensions VSCode

- Docker
- PHP Intelephense
- GitLens
- Prettier
- Auto Close Tag
- Material Icon Theme
- WSL
- ESLint
- Tailwind CSS IntelliSense
- PowerShell

### Configuration Windows

- Mode sombre active
- Extensions de fichiers visibles
- Fichiers caches visibles
- Bing desactive dans le menu demarrer
- Suggestions du menu demarrer desactivees

### Dossiers crees

```
C:\Dev\
C:\Dev\Projects\
C:\Dev\Tools\
C:\Dev\Docker\
C:\Dev\Scripts\
C:\Dev\Logs\
```

## Structure du projet

```
ITSMBootstrap/
├── bootstrap.ps1          # Point d'entree (one-liner)
├── main.ps1               # Script principal
├── config/
│   ├── apps.json          # Liste des applications
│   ├── extensions.json    # Extensions VSCode
│   └── folders.json       # Dossiers a creer
├── modules/
│   ├── Logger.psm1        # Logging
│   ├── UI.psm1            # Interface utilisateur
│   ├── Progress.psm1      # Sauvegarde progression
│   ├── Apps.psm1          # Installation apps
│   ├── Git.psm1           # Configuration Git
│   ├── Windows.psm1       # Tweaks Windows
│   └── VSCode.psm1        # Extensions VSCode
└── README.md
```

## Personnalisation

### Ajouter une application

Editer `config/apps.json` :

```json
{
    "id": "Publisher.AppName",
    "name": "Nom affiche",
    "category": "dev",
    "required": false,
    "description": "Description"
}
```

Trouver l'ID avec : `winget search "nom de l'app"`

### Ajouter une extension VSCode

Editer `config/extensions.json` :

```json
{
    "id": "publisher.extension-name",
    "name": "Nom affiche",
    "description": "Description"
}
```

## Logs

Les logs sont sauvegardes dans `C:\Dev\Logs\bootstrap_YYYYMMDD_HHMMSS.log`

## Apres l'installation

1. Redemarrer le PC pour finaliser WSL
2. Se connecter a Tailscale
3. Se connecter a Docker Desktop
4. Configurer les preferences VSCode

## Prerequis

- Windows 10/11
- PowerShell 5.1+
- winget (App Installer)

## License

MIT
