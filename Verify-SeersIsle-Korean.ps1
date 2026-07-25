[CmdletBinding()]
param(
    [string]$GameRoot = 'C:\Program Files (x86)\Steam\steamapps\common\Seers Isle',
    [ValidateSet('Installed', 'Restored')]
    [string]$ExpectedState = 'Installed'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
Import-Module (Join-Path $PSScriptRoot 'PatchCommon.psm1') -Force

$packageRoot = [System.IO.Path]::GetFullPath($PSScriptRoot)
$gameRootFull = [System.IO.Path]::GetFullPath($GameRoot)
$manifestInfo = Get-PatchManifest -PackageRoot $packageRoot
$manifest = $manifestInfo.Manifest
Assert-PatchPackageFiles -PackageRoot $packageRoot -Manifest $manifest
Assert-PatchGameCompatibility -GameRoot $gameRootFull -Manifest $manifest

$checked = 0
foreach ($target in $manifest.targets) {
    $livePath = Get-PatchContainedPath -Root $gameRootFull `
        -RelativePath ([string]$target.path)
    if ($ExpectedState -eq 'Installed') {
        Assert-PatchSize -Path $livePath -Expected ([long]$target.size) `
            -Label "Installed target $($target.path)"
        Assert-PatchHash -Path $livePath -Expected ([string]$target.sha256) `
            -Label "Installed target $($target.path)"
    }
    elseif (Test-Path -LiteralPath $livePath) {
        throw "Patch target should be absent after restore: $($target.path)"
    }
    $checked++
}

Write-Output (
    "Verification passed: state=$ExpectedState, targets=$checked, " +
    "manifest=$($manifestInfo.ManifestSha256)"
)
