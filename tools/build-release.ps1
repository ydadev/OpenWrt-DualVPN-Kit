[CmdletBinding()]
param([string]$Version = '')

$ErrorActionPreference = 'Stop'
$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
if (-not $Version) { $Version = (Get-Content (Join-Path $Root 'VERSION') -Raw).Trim() }
if ($Version -notmatch '^[0-9]+\.[0-9]+\.[0-9]+(?:[-+][0-9A-Za-z.-]+)?$') { throw "Invalid version: $Version" }
& (Join-Path $PSScriptRoot 'validate-repo.ps1')

$Dist = Join-Path $Root 'dist'
New-Item -ItemType Directory -Path $Dist -Force | Out-Null
$Name = "OpenWrt-DualVPN-Kit-v$Version.zip"
$Archive = Join-Path $Dist $Name
$Temp = Join-Path ([IO.Path]::GetTempPath()) ("openwrt-dualvpn-" + [guid]::NewGuid().ToString('N'))
$Package = Join-Path $Temp 'OpenWrt-DualVPN-Kit'
New-Item -ItemType Directory -Path $Package -Force | Out-Null

try {
    foreach ($File in Get-ChildItem -LiteralPath $Root -Recurse -File) {
        $Relative = $File.FullName.Substring($Root.Length + 1)
        if ($Relative -match '^(\.git|dist)([\\/]|$)' -or $Relative -match '\.(backup|bak|tar\.gz|log)$') { continue }
        if ($File.Extension -eq '.conf' -and $Relative -notmatch '^examples[\\/].+\.example\.conf$') { continue }
        $Target = Join-Path $Package $Relative
        New-Item -ItemType Directory -Path (Split-Path $Target -Parent) -Force | Out-Null
        Copy-Item -LiteralPath $File.FullName -Destination $Target
    }
    if (Test-Path $Archive) { Remove-Item -LiteralPath $Archive -Force }
    Add-Type -AssemblyName System.IO.Compression
    $Stream = [IO.File]::Open($Archive, [IO.FileMode]::CreateNew)
    $Zip = [IO.Compression.ZipArchive]::new($Stream, [IO.Compression.ZipArchiveMode]::Create, $false)
    try {
        foreach ($File in Get-ChildItem -LiteralPath $Package -Recurse -File) {
            $Relative = $File.FullName.Substring($Package.Length + 1).Replace('\','/')
            $Entry = $Zip.CreateEntry("OpenWrt-DualVPN-Kit/$Relative", [IO.Compression.CompressionLevel]::Optimal)
            $Input = [IO.File]::OpenRead($File.FullName); $Output = $Entry.Open()
            try { $Input.CopyTo($Output) } finally { $Output.Dispose(); $Input.Dispose() }
        }
    } finally { $Zip.Dispose(); $Stream.Dispose() }
    $Hash = (Get-FileHash $Archive -Algorithm SHA256).Hash.ToLowerInvariant()
    [IO.File]::WriteAllText("$Archive.sha256", "$Hash  $Name`n", [Text.UTF8Encoding]::new($false))
} finally {
    if ($Temp.StartsWith([IO.Path]::GetTempPath(), [StringComparison]::OrdinalIgnoreCase) -and (Test-Path $Temp)) {
        Remove-Item -LiteralPath $Temp -Recurse -Force
    }
}
Write-Host "Created: $Archive"
Write-Host "SHA256: $Hash"
