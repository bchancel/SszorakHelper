param(
    [string]$OutputDirectory,
    [switch]$SkipVerify
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$root = [System.IO.Path]::GetFullPath($PSScriptRoot).TrimEnd('\', '/')
$mainToc = Join-Path $root "SszorakHelper.toc"
$optionsRoot = Join-Path $root "Options"
$optionsToc = Join-Path $optionsRoot "SszorakHelper_Options.toc"

if (-not $SkipVerify) { & (Join-Path $root "verify.ps1") }

$tocText = Get-Content -LiteralPath $mainToc -Raw
if ($tocText -notmatch '(?m)^## Version:\s*(\d+\.\d+\.\d+(?:-\d+)?)\s*$') {
    throw "SszorakHelper.toc does not contain a supported Version value."
}
$version = $Matches[1]

if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    $OutputDirectory = Join-Path $root "dist"
}
elseif (-not [System.IO.Path]::IsPathRooted($OutputDirectory)) {
    $OutputDirectory = Join-Path $root $OutputDirectory
}
$OutputDirectory = [System.IO.Path]::GetFullPath($OutputDirectory).TrimEnd('\', '/')

$buildRoot = Join-Path $root ".build"
$mainStage = Join-Path $buildRoot "SszorakHelper"
$optionsStage = Join-Path $buildRoot "SszorakHelper_Options"
$archivePath = Join-Path $OutputDirectory "SszorakHelper-$version.zip"

function Get-TocEntries {
    param([string]$Path)
    return @(
        Get-Content -LiteralPath $Path | ForEach-Object {
            $entry = $_.Trim()
            if ($entry -and -not $entry.StartsWith('#')) { $entry }
        }
    )
}

function Copy-TocPayload {
    param([string]$TocPath, [string]$SourceRoot, [string]$DestinationRoot)
    foreach ($entry in Get-TocEntries -Path $TocPath) {
        $relativePath = $entry -replace '[\\/]', [System.IO.Path]::DirectorySeparatorChar
        $source = Join-Path $SourceRoot $relativePath
        $destination = Join-Path $DestinationRoot $relativePath
        New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force | Out-Null
        Copy-Item -LiteralPath $source -Destination $destination
    }
}

if (Test-Path -LiteralPath $buildRoot) {
    $resolved = [System.IO.Path]::GetFullPath((Resolve-Path -LiteralPath $buildRoot).Path).TrimEnd('\', '/')
    if (-not $resolved.StartsWith($root + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to clean unexpected build path: $resolved"
    }
    Remove-Item -LiteralPath $resolved -Recurse -Force
}

New-Item -ItemType Directory -Path $mainStage -Force | Out-Null
New-Item -ItemType Directory -Path $optionsStage -Force | Out-Null
New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null

try {
    Copy-Item -LiteralPath $mainToc -Destination (Join-Path $mainStage "SszorakHelper.toc")
    Copy-TocPayload -TocPath $mainToc -SourceRoot $root -DestinationRoot $mainStage
    Copy-Item -LiteralPath $optionsToc -Destination (Join-Path $optionsStage "SszorakHelper_Options.toc")
    Copy-TocPayload -TocPath $optionsToc -SourceRoot $optionsRoot -DestinationRoot $optionsStage

    Add-Type -AssemblyName System.IO.Compression
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    if (Test-Path -LiteralPath $archivePath) { Remove-Item -LiteralPath $archivePath -Force }
    $archive = [System.IO.Compression.ZipFile]::Open(
        $archivePath,
        [System.IO.Compression.ZipArchiveMode]::Create
    )
    try {
        foreach ($stagingPath in @($mainStage, $optionsStage)) {
            Get-ChildItem -LiteralPath $stagingPath -File -Recurse | ForEach-Object {
                $relativePath = $_.FullName.Substring($buildRoot.Length).TrimStart([char[]]'\/').Replace('\', '/')
                [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
                    $archive,
                    $_.FullName,
                    $relativePath,
                    [System.IO.Compression.CompressionLevel]::Optimal
                ) | Out-Null
            }
        }
    }
    finally { $archive.Dispose() }

    $archive = [System.IO.Compression.ZipFile]::OpenRead($archivePath)
    try {
        $actual = @($archive.Entries | Where-Object { -not $_.FullName.EndsWith('/') } | ForEach-Object { $_.FullName.Replace('\', '/') } | Sort-Object)
    }
    finally { $archive.Dispose() }

    $expected = @(
        "SszorakHelper/SszorakHelper.toc"
        Get-TocEntries -Path $mainToc | ForEach-Object { "SszorakHelper/$($_.Replace('\', '/'))" }
        "SszorakHelper_Options/SszorakHelper_Options.toc"
        Get-TocEntries -Path $optionsToc | ForEach-Object { "SszorakHelper_Options/$($_.Replace('\', '/'))" }
    ) | Sort-Object
    $differences = @(Compare-Object -ReferenceObject $expected -DifferenceObject $actual)
    if ($differences.Count -gt 0) {
        $detail = ($differences | ForEach-Object { "$($_.SideIndicator) $($_.InputObject)" }) -join '; '
        throw "Release archive contents do not match the TOCs: $detail"
    }
}
finally {
    if (Test-Path -LiteralPath $buildRoot) { Remove-Item -LiteralPath $buildRoot -Recurse -Force }
}

Write-Host "Sszorak Helper package created: $archivePath" -ForegroundColor Green
