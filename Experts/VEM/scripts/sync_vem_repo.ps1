# Copy MT5 VEM sources into _vem-git-root (then commit/push from that folder).
# Usage: powershell -File sync_vem_repo.ps1
$ErrorActionPreference = "Stop"
$vemDir = Split-Path $PSScriptRoot -Parent
$mql5 = (Resolve-Path (Join-Path $vemDir "..\..")).Path
$root = Join-Path $vemDir "_vem-git-root"
if (-not (Test-Path (Join-Path $root ".git"))) {
    Write-Error "Missing _vem-git-root/.git - run: git clone https://github.com/Atlas00000/VEM.git _vem-git-root"
}
New-Item -ItemType Directory -Force -Path "$root\Experts\VEM", "$root\Include\VEM", "$root\Profiles\Tester" | Out-Null
Get-ChildItem $vemDir -Exclude @("_vem-git-root", ".git") | ForEach-Object {
    Copy-Item $_.FullName "$root\Experts\VEM\" -Recurse -Force
}
Copy-Item "$mql5\Include\VEM\*" "$root\Include\VEM\" -Force
Copy-Item "$mql5\Profiles\Tester\vem5m*.set" "$root\Profiles\Tester\" -Force
Remove-Item "$root\Experts\VEM\VEM.ex5" -ErrorAction SilentlyContinue
Remove-Item "$root\Experts\VEM\scripts\__pycache__" -Recurse -Force -ErrorAction SilentlyContinue
Write-Host "Synced MT5 sources to $root"
Push-Location $root
git status --short
Pop-Location
