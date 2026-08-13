[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$Failures = [System.Collections.Generic.List[string]]::new()
function Fail([string]$Message) { $Failures.Add($Message); Write-Host "ERROR: $Message" -ForegroundColor Red }

$Required = @(
    'README.md','LICENSE','VERSION','SECURITY.md','examples/setup.env.example',
    'examples/wireguard.example.conf','examples/amneziawg.example.conf',
    'scripts/preflight.sh','scripts/install-dual-vpn.sh','scripts/uninstall-dual-vpn.sh',
    'scripts/vpn-switch','scripts/vpn-apply-route','docs/INSTALL-RU.md'
)
foreach ($Relative in $Required) {
    if (-not (Test-Path -LiteralPath (Join-Path $Root $Relative))) { Fail "missing: $Relative" }
}

$ForbiddenExtensions = @('.apk','.ipk','.ko','.bin','.img')
foreach ($File in Get-ChildItem -LiteralPath $Root -Recurse -File) {
    if ($File.FullName -match '[\\/]\.git[\\/]') { continue }
    if ($File.Extension -in $ForbiddenExtensions) { Fail "device-specific binary: $($File.Name)" }
}

$Text = Get-ChildItem -LiteralPath $Root -Recurse -File | Where-Object {
    $_.FullName -notmatch '[\\/]\.git[\\/]' -and $_.Extension -in @('.md','.sh','.conf','.example','.ps1','.py','.yml','.yaml')
}
$Patterns = @(
    '(?im)^\s*(PrivateKey|PresharedKey)\s*=\s*(?!REPLACE_WITH_)[A-Za-z0-9+/]{40,}={0,2}\s*$',
    '(?im)^\s*option\s+(private_key|preshared_key|password)\s+''(?!REPLACE_WITH_)[^'']+''\s*$'
)
foreach ($File in $Text) {
    $Content = Get-Content -LiteralPath $File.FullName -Raw
    foreach ($Pattern in $Patterns) { if ($Content -match $Pattern) { Fail "possible secret: $($File.Name)" } }
}

$Python = Get-Command python -ErrorAction SilentlyContinue
if ($Python) {
    & $Python.Source (Join-Path $Root 'tools/check-markdown-links.py') $Root
    if ($LASTEXITCODE -ne 0) { Fail 'Markdown links failed' }
} else {
    $Regex = [regex]'(?<!!)\[[^\]]*\]\(([^)]+)\)'
    foreach ($Document in Get-ChildItem -LiteralPath $Root -Recurse -File -Filter '*.md') {
        if ($Document.FullName -match '[\\/]\.git[\\/]') { continue }
        foreach ($Match in $Regex.Matches((Get-Content $Document.FullName -Raw))) {
            $Target = $Match.Groups[1].Value.Trim().Trim('<','>')
            if (-not $Target -or $Target -match '^(https?://|mailto:|#)') { continue }
            $Target = [uri]::UnescapeDataString(($Target -split '#',2)[0])
            $Resolved = [IO.Path]::GetFullPath((Join-Path $Document.DirectoryName $Target))
            if (-not (Test-Path -LiteralPath $Resolved)) { Fail "missing Markdown link: $Target" }
        }
    }
}

$Git = Get-Command git -ErrorAction SilentlyContinue
$Shell = if ($Git) { Join-Path (Split-Path (Split-Path $Git.Source -Parent) -Parent) 'usr\bin\sh.exe' }
if ($Shell -and (Test-Path -LiteralPath $Shell)) {
    foreach ($Script in Get-ChildItem (Join-Path $Root 'scripts') -File) {
        & $Shell -n $Script.FullName
        if ($LASTEXITCODE -ne 0) { Fail "shell syntax: $($Script.Name)" }
    }
} else { Write-Warning 'No sh found; shell syntax skipped' }

if ($Failures.Count) { throw "Validation failed: $($Failures.Count) error(s)" }
Write-Host 'Repository validation: OK' -ForegroundColor Green
