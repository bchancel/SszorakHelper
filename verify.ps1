$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$root = [System.IO.Path]::GetFullPath($PSScriptRoot).TrimEnd('\', '/')
$mainToc = Join-Path $root "SszorakHelper.toc"
$optionsRoot = Join-Path $root "Options"
$optionsToc = Join-Path $optionsRoot "SszorakHelper_Options.toc"

function Get-TocEntries {
    param([string]$Path)
    return @(
        Get-Content -LiteralPath $Path | ForEach-Object {
            $entry = $_.Trim()
            if ($entry -and -not $entry.StartsWith('#')) { $entry }
        }
    )
}

function Test-TocFiles {
    param([string]$TocPath, [string]$BasePath)
    foreach ($entry in Get-TocEntries -Path $TocPath) {
        $relativePath = $entry -replace '[\\/]', [System.IO.Path]::DirectorySeparatorChar
        $candidate = Join-Path $BasePath $relativePath
        if (-not (Test-Path -LiteralPath $candidate -PathType Leaf)) {
            throw "Missing TOC file: $candidate"
        }
    }
}

foreach ($required in @($mainToc, $optionsToc, (Join-Path $root ".pkgmeta"))) {
    if (-not (Test-Path -LiteralPath $required -PathType Leaf)) {
        throw "Missing required project file: $required"
    }
}

Test-TocFiles -TocPath $mainToc -BasePath $root
Test-TocFiles -TocPath $optionsToc -BasePath $optionsRoot

$versionPattern = '^## Version:\s*(\d+\.\d+\.\d+(?:-\d+)?)\s*$'
$tocVersion = (Select-String -LiteralPath $mainToc -Pattern $versionPattern).Matches[0].Groups[1].Value
$luaVersion = (Select-String -LiteralPath (Join-Path $root "SszorakHelper.lua") -Pattern '^SH\.version\s*=\s*"([^"]+)"').Matches[0].Groups[1].Value
$optionsVersion = (Select-String -LiteralPath $optionsToc -Pattern $versionPattern).Matches[0].Groups[1].Value
if ($tocVersion -ne $luaVersion -or $tocVersion -ne $optionsVersion) {
    throw "Version mismatch: main TOC=$tocVersion Lua=$luaVersion options TOC=$optionsVersion"
}

$mainText = Get-Content -LiteralPath $mainToc -Raw
if ($mainText -notmatch '(?m)^## X-Website:\s*https://github\.com/bchancel/SszorakHelper\s*$') {
    throw "SszorakHelper.toc is missing the project website metadata."
}

$luaFiles = Get-ChildItem -LiteralPath $root -Recurse -Filter *.lua -File |
    Where-Object { $_.FullName -notmatch '[\\/]dist[\\/]|[\\/]\.build[\\/]' }
foreach ($file in $luaFiles) {
    $text = Get-Content -LiteralPath $file.FullName -Raw
    if ($text.Contains("`t")) { throw "Tab character found in $($file.FullName)" }
    if ($text -match '\bTODO\b|\bFIXME\b') { throw "Unresolved TODO/FIXME in $($file.FullName)" }
}

Write-Host "Sszorak Helper verification passed ($tocVersion)." -ForegroundColor Green
