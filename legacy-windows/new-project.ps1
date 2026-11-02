# Create a fresh Go project with agent-pairing-kit installed.
# Usage: pwsh -NoProfile -File new-project.ps1 -Path E:\Code\my-service [-Module my-service]
# Installs working agreements, skills, and scripts only; no application code.
param(
    [Parameter(Mandatory = $true)][string]$Path,
    [string]$Module = (Split-Path -Leaf $Path)
)
$ErrorActionPreference = 'Stop'
$kit = $PSScriptRoot

if (Test-Path $Path) {
    if (Get-ChildItem -Force $Path | Select-Object -First 1) { Write-Error "$Path exists and is not empty"; exit 1 }
} else {
    New-Item -ItemType Directory -Path $Path | Out-Null
}

Copy-Item (Join-Path $kit 'CLAUDE.md') $Path
Copy-Item (Join-Path $kit 'CLAUDE.md') (Join-Path $Path 'AGENTS.md')
Copy-Item (Join-Path $kit '.gitignore') $Path
Copy-Item (Join-Path $kit '.gitattributes') $Path
foreach ($dir in '.cursor', 'skills', 'scripts') {
    Copy-Item -Recurse (Join-Path $kit $dir) (Join-Path $Path $dir)
}
New-Item -ItemType Directory -Force -Path (Join-Path $Path '.claude') | Out-Null
Copy-Item -Recurse (Join-Path $kit 'claude-commands') (Join-Path $Path '.claude/commands')
Copy-Item (Join-Path $kit 'claude-settings.json') (Join-Path $Path '.claude/settings.json')

Push-Location $Path
try {
    & go mod init $Module
    & git init -q
    & git add -A
    & git commit -q -m 'chore: agent pairing working agreements and check scripts'
    Write-Host "`nReady: $Path" -ForegroundColor Green
    Write-Host 'Next: open it in your editor, then run scripts/check.ps1 once to confirm the toolchain.'
} finally {
    Pop-Location
}
