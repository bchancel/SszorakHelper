param(
    [string]$NewVersion,
    [switch]$Release,
    [switch]$NoTag
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$mainBranch = "main"

function Assert-LastExitCode {
    param([string]$Message)
    if ($LASTEXITCODE -ne 0) { throw $Message }
}

if ($Release -and $NoTag) {
    throw "Use either -Release or -NoTag, not both."
}

$originalBranch = (& git branch --show-current | Out-String).Trim()
Assert-LastExitCode "git branch --show-current failed."
if (-not $originalBranch) { throw "Switch to a branch before running this script." }

$tocPath = Join-Path $PSScriptRoot "SszorakHelper.toc"
$runtimePath = Join-Path $PSScriptRoot "SszorakHelper.lua"
$optionsTocPath = Join-Path (Join-Path $PSScriptRoot "Options") "SszorakHelper_Options.toc"
$toc = Get-Content -LiteralPath $tocPath -Raw
$runtime = Get-Content -LiteralPath $runtimePath -Raw
$optionsToc = Get-Content -LiteralPath $optionsTocPath -Raw

if ($toc -notmatch '(?m)^## Version:\s*(\d+)\.(\d+)\.(\d+)(?:-\d+)?\s*$') {
    throw "Could not find a supported Version value in SszorakHelper.toc."
}
$major, $minor, $patch = [int]$Matches[1], [int]$Matches[2], [int]$Matches[3]
$currentVersion = $Matches[0] -replace '^## Version:\s*', ''

if ($NewVersion) {
    if ($NewVersion -notmatch '^\d+\.\d+\.\d+(?:-\d+)?$') {
        throw "Version must use major.minor.patch with an optional numeric suffix."
    }
    $version = $NewVersion
}
else {
    $version = "$major.$minor.$($patch + 1)"
}

$tag = "v$version"
$shouldTag = -not $NoTag -and ($Release -or $originalBranch -eq $mainBranch)
Write-Host "Updating version: $currentVersion -> $version"

$toc = $toc -replace '(?m)^## Version:[^\r\n]*', "## Version: $version"
$runtime = $runtime -replace '(?m)^SH\.version\s*=\s*"[^"]+"', "SH.version = `"$version`""
$optionsToc = $optionsToc -replace '(?m)^## Version:[^\r\n]*', "## Version: $version"
Set-Content -LiteralPath $tocPath -Value $toc -NoNewline
Set-Content -LiteralPath $runtimePath -Value $runtime -NoNewline
Set-Content -LiteralPath $optionsTocPath -Value $optionsToc -NoNewline

& (Join-Path $PSScriptRoot "build.ps1")
& git add -A
Assert-LastExitCode "git add failed."

& git diff --cached --quiet
if ($LASTEXITCODE -ne 0) {
    & git commit -m "Update version $tag"
    Assert-LastExitCode "git commit failed."
}

& git push origin $originalBranch
Assert-LastExitCode "git push failed."
if (-not $shouldTag) {
    Write-Host "Pushed $originalBranch without a release tag."
    return
}

if ($originalBranch -ne $mainBranch) {
    throw "Create releases from main, or run with -NoTag on feature branches."
}

& git tag -a $tag -m "Release $tag"
Assert-LastExitCode "git tag failed."
& git push origin $tag
Assert-LastExitCode "git tag push failed."
Write-Host "Published release tag $tag." -ForegroundColor Green
