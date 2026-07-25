[CmdletBinding()]
param(
    [string]$GameRoot = 'C:\Program Files (x86)\Steam\steamapps\common\Seers Isle',
    [string]$BackupRoot = (
        Join-Path $env:LOCALAPPDATA 'SeersIsleKoreanPatch\backups'
    ),
    [string]$BackupPath,
    [switch]$SkipProcessCheck
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
Import-Module (Join-Path $PSScriptRoot 'PatchCommon.psm1') -Force

$packageRoot = [System.IO.Path]::GetFullPath($PSScriptRoot)
$gameRootFull = [System.IO.Path]::GetFullPath($GameRoot)
$backupRootFull = [System.IO.Path]::GetFullPath($BackupRoot)

if (-not $SkipProcessCheck) {
    Assert-PatchProcessStopped
}
if (-not (Test-Path -LiteralPath $gameRootFull -PathType Container)) {
    throw "Game root does not exist: $gameRootFull"
}
Assert-PatchNoReparseComponents -Root $gameRootFull -Path $gameRootFull
Assert-PatchNoReparseComponents -Root $packageRoot -Path $packageRoot
Assert-PatchBackupOutside -BackupRoot $backupRootFull `
    -GameRoot $gameRootFull -PackageRoot $packageRoot

$manifestInfo = Get-PatchManifest -PackageRoot $packageRoot
$manifest = $manifestInfo.Manifest
Assert-PatchPackageFiles -PackageRoot $packageRoot -Manifest $manifest
Assert-PatchGameCompatibility -GameRoot $gameRootFull -Manifest $manifest

if ([string]::IsNullOrWhiteSpace($BackupPath)) {
    $currentPath = Join-Path $backupRootFull 'current.json'
    $current = Read-PatchJson -Path $currentPath
    if ($current.patch_id -ne $manifest.patch_id) {
        throw "Current backup pointer belongs to another patch"
    }
    $BackupPath = [string]$current.backup_path
    $expectedBackupManifestHash = [string]$current.backup_manifest_sha256
}
else {
    $expectedBackupManifestHash = $null
}
$backupPathFull = [System.IO.Path]::GetFullPath($BackupPath)
if (-not (Test-PatchPathWithin -Candidate $backupPathFull -Root $backupRootFull)) {
    throw "Backup path must be contained by the configured backup root"
}
if (Test-PatchPathWithin -Candidate $backupPathFull -Root $gameRootFull) {
    throw "Backup cannot be inside the game tree: $backupPathFull"
}
if (Test-PatchPathWithin -Candidate $backupPathFull -Root $packageRoot) {
    throw "Backup cannot be inside the package tree: $backupPathFull"
}
if (-not (Test-Path -LiteralPath $backupPathFull -PathType Container)) {
    throw "Backup directory does not exist: $backupPathFull"
}
Assert-PatchNoReparseComponents -Root $backupRootFull -Path $backupPathFull

$backupManifestPath = Join-Path $backupPathFull 'backup_manifest.json'
$backupHashPath = Join-Path $backupPathFull 'backup_manifest.sha256'
$recordedBackupHash = (
    Get-Content -LiteralPath $backupHashPath -Raw -Encoding ASCII
).Trim().ToLowerInvariant()
if ($recordedBackupHash -notmatch '^[0-9a-f]{64}$') {
    throw "Invalid backup_manifest.sha256"
}
Assert-PatchHash -Path $backupManifestPath -Expected $recordedBackupHash `
    -Label 'backup_manifest.json'
if (
    $expectedBackupManifestHash -and
    $recordedBackupHash -ne $expectedBackupManifestHash.ToLowerInvariant()
) {
    throw "Current pointer and backup manifest hashes disagree"
}
$backupManifest = Read-PatchJson -Path $backupManifestPath
if ($backupManifest.format -ne 1 -or $backupManifest.patch_id -ne $manifest.patch_id) {
    throw "Unsupported or unrelated backup manifest"
}
if (
    $backupManifest.install_manifest_sha256 -ne
    $manifestInfo.ManifestSha256
) {
    throw "Backup was created by a different patch package"
}
if (
    -not ([System.IO.Path]::GetFullPath([string]$backupManifest.game_root)).Equals(
        $gameRootFull,
        [System.StringComparison]::OrdinalIgnoreCase
    )
) {
    throw "Backup belongs to a different game root"
}

$manifestTargets = @{}
foreach ($target in $manifest.targets) {
    $manifestTargets[[string]$target.path] = $target
}
$backupTargets = @($backupManifest.targets)
if ($backupTargets.Count -ne $manifestTargets.Count) {
    throw "Backup target count does not match patch target count"
}
$backupPaths = @($backupTargets | ForEach-Object { [string]$_.path })
if (@($backupPaths | Select-Object -Unique).Count -ne $backupPaths.Count) {
    throw "Backup manifest contains duplicate target paths"
}
foreach ($path in $manifestTargets.Keys) {
    if ($backupPaths -notcontains $path) {
        throw "Backup manifest is missing target: $path"
    }
}

# Complete every backup and live-state check before writing anything.
$liveStates = @()
foreach ($backupTarget in $backupTargets) {
    $relative = [string]$backupTarget.path
    $target = $manifestTargets[$relative]
    if (
        ([string]$backupTarget.patched_sha256).ToLowerInvariant() -ne
        ([string]$target.sha256).ToLowerInvariant()
    ) {
        throw "Backup patched hash disagrees with package for $relative"
    }
    $patchedRecovery = Get-PatchContainedPath -Root (
        Join-Path $backupPathFull 'patched'
    ) -RelativePath $relative
    Assert-PatchNoReparseComponents -Root $backupPathFull `
        -Path $patchedRecovery
    Assert-PatchHash -Path $patchedRecovery `
        -Expected ([string]$target.sha256) `
        -Label "Patched recovery copy $relative"

    if (
        [bool]$backupTarget.original_exists -or
        $null -ne $backupTarget.original_sha256
    ) {
        throw (
            "This additive patch requires every recorded original target " +
            "to be absent: $relative"
        )
    }

    $livePath = Get-PatchContainedPath -Root $gameRootFull -RelativePath $relative
    Assert-PatchNoReparseComponents -Root $gameRootFull -Path $livePath
    $exists = Test-Path -LiteralPath $livePath -PathType Leaf
    $liveHash = if ($exists) { Get-PatchSha256 -Path $livePath } else { $null }
    $allowed = $false
    if (-not $exists -and -not [bool]$backupTarget.original_exists) {
        $allowed = $true
    }
    elseif (
        $exists -and
        $liveHash -eq ([string]$target.sha256).ToLowerInvariant()
    ) {
        $allowed = $true
    }
    elseif (
        $exists -and [bool]$backupTarget.original_exists -and
        $liveHash -eq ([string]$backupTarget.original_sha256).ToLowerInvariant()
    ) {
        $allowed = $true
    }
    if (-not $allowed) {
        throw (
            "Unknown live state for $relative; expected patched, recorded " +
            "original, or recorded absence. No files were written."
        )
    }
    $liveStates += [pscustomobject]@{
        path = $relative
        live_path = $livePath
        live_hash = $liveHash
        exists = $exists
        original_exists = [bool]$backupTarget.original_exists
        original_sha256 = $backupTarget.original_sha256
    }
}

$journalPath = Join-Path $backupPathFull 'restore_journal.log'
"restore-preflight-complete $(Get-Date -Format o)" |
    Add-Content -LiteralPath $journalPath -Encoding UTF8
if (-not $SkipProcessCheck) {
    Assert-PatchProcessStopped
}
try {
    foreach ($state in $liveStates) {
        if (Test-Path -LiteralPath $state.live_path -PathType Leaf) {
            Remove-Item -LiteralPath $state.live_path -Force
        }
        "restored $($state.path) $(Get-Date -Format o)" |
            Add-Content -LiteralPath $journalPath -Encoding UTF8
    }

    foreach ($state in $liveStates) {
        if (Test-Path -LiteralPath $state.live_path) {
            throw "Added patch target still exists after restore: $($state.path)"
        }
    }
}
catch {
    $restoreFailure = $_
    $rollbackErrors = New-Object System.Collections.Generic.List[string]
    foreach ($state in $liveStates) {
        try {
            if ($state.exists) {
                $source = Get-PatchContainedPath -Root (
                    Join-Path $backupPathFull 'patched'
                ) -RelativePath $state.path
                $parent = Split-Path -Parent $state.live_path
                New-Item -ItemType Directory -Force -Path $parent | Out-Null
                Assert-PatchNoReparseComponents -Root $gameRootFull -Path $parent
                $temp = Join-Path $parent (
                    '.' + [System.IO.Path]::GetFileName($state.live_path) + '.' +
                    [guid]::NewGuid().ToString('N') + '.rollback.tmp'
                )
                Copy-Item -LiteralPath $source -Destination $temp
                Assert-PatchHash -Path $temp `
                    -Expected ([string]$manifestTargets[$state.path].sha256) `
                    -Label "Restore rollback $($state.path)"
                Move-Item -LiteralPath $temp `
                    -Destination $state.live_path -Force
            }
            elseif (Test-Path -LiteralPath $state.live_path -PathType Leaf) {
                Remove-Item -LiteralPath $state.live_path -Force
            }
        }
        catch {
            $rollbackErrors.Add("$($state.path): $($_.Exception.Message)")
        }
    }
    if ($rollbackErrors.Count -gt 0) {
        "restore-failed-rollback-incomplete $(Get-Date -Format o): " +
            ($rollbackErrors -join '; ') |
            Add-Content -LiteralPath $journalPath -Encoding UTF8
        throw (
            "Restore failed and rollback was incomplete. Recovery backup was " +
            "preserved at $backupPathFull. Original error: " +
            "$($restoreFailure.Exception.Message). Rollback errors: " +
            ($rollbackErrors -join '; ')
        )
    }
    "restore-failed-rolled-back $(Get-Date -Format o): " +
        $restoreFailure.Exception.Message |
        Add-Content -LiteralPath $journalPath -Encoding UTF8
    throw $restoreFailure
}

$localeDirectory = Get-PatchContainedPath -Root $gameRootFull `
    -RelativePath 'Seers-Isle_Data\StreamingAssets\locales\ko-KR'
if (Test-Path -LiteralPath $localeDirectory -PathType Container) {
    $remaining = @(Get-ChildItem -LiteralPath $localeDirectory -Force)
    if ($remaining.Count -eq 0) {
        Remove-Item -LiteralPath $localeDirectory -Force
    }
}

# The recovery manifest is immutable after installation.  Restore state belongs
# in the pointer and append-only journal so an interrupted metadata update can
# never invalidate the backup's hash chain.
$current = [ordered]@{
    format = 1
    patch_id = [string]$manifest.patch_id
    status = 'restored'
    backup_path = $backupPathFull
    backup_manifest_sha256 = $recordedBackupHash
    game_root = $gameRootFull
    updated_at = (Get-Date).ToUniversalTime().ToString('o')
}
Write-PatchJsonAtomic -Path (
    Join-Path $backupRootFull 'current.json'
) -Value $current
"restore-complete $(Get-Date -Format o)" |
    Add-Content -LiteralPath $journalPath -Encoding UTF8

Write-Output "Original state restored successfully."
Write-Output "Backup retained at: $backupPathFull"
