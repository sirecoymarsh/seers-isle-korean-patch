[CmdletBinding()]
param(
    [string]$GameRoot = 'C:\Program Files (x86)\Steam\steamapps\common\Seers Isle',
    [string]$BackupRoot = (
        Join-Path $env:LOCALAPPDATA 'SeersIsleKoreanPatch\backups'
    ),
    [switch]$SkipProcessCheck
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
Import-Module (Join-Path $PSScriptRoot 'PatchCommon.psm1') -Force

$packageRoot = [System.IO.Path]::GetFullPath($PSScriptRoot)
$gameRootFull = [System.IO.Path]::GetFullPath($GameRoot)
$backupRootFull = [System.IO.Path]::GetFullPath($BackupRoot)
$stageRoot = $null
$backupPath = $null
$installedTargets = New-Object System.Collections.Generic.List[string]
$temporaryFiles = New-Object System.Collections.Generic.List[string]
$createdDirectories = New-Object System.Collections.Generic.List[string]

try {
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
    Assert-PatchTargetSources -PackageRoot $packageRoot -Manifest $manifest
    Assert-PatchGameCompatibility -GameRoot $gameRootFull -Manifest $manifest

    $states = @()
    foreach ($target in $manifest.targets) {
        $livePath = Get-PatchContainedPath -Root $gameRootFull `
            -RelativePath ([string]$target.path)
        Assert-PatchNoReparseComponents -Root $gameRootFull -Path $livePath
        $exists = Test-Path -LiteralPath $livePath -PathType Leaf
        $hash = if ($exists) { Get-PatchSha256 -Path $livePath } else { $null }
        $state = if (-not $exists) {
            'absent'
        }
        elseif ($hash -eq ([string]$target.sha256).ToLowerInvariant()) {
            'patched'
        }
        else {
            'unknown'
        }
        $states += [pscustomobject]@{
            path = [string]$target.path
            live_path = $livePath
            exists = $exists
            sha256 = $hash
            state = $state
        }
    }

    $patchedCount = @($states | Where-Object { $_.state -eq 'patched' }).Count
    $absentCount = @($states | Where-Object { $_.state -eq 'absent' }).Count
    $unknown = @($states | Where-Object { $_.state -eq 'unknown' })
    if ($unknown.Count -gt 0) {
        $details = ($unknown | ForEach-Object {
            "$($_.path) [$($_.sha256)]"
        }) -join '; '
        throw "Unknown pre-existing patch target(s); no files were written: $details"
    }
    if ($patchedCount -eq $states.Count) {
        Assert-PatchRecoveryBackup -BackupRoot $backupRootFull `
            -GameRoot $gameRootFull -PackageRoot $packageRoot `
            -ManifestInfo $manifestInfo | Out-Null
        Write-Output (
            "Seers Isle Korean patch is already installed and all target " +
            "hashes plus the external recovery backup are valid."
        )
        exit 0
    }
    if ($absentCount -ne $states.Count) {
        throw (
            "Mixed installed/absent patch state detected. Use the restore script " +
            "with the recorded backup before reinstalling."
        )
    }

    New-Item -ItemType Directory -Force -Path $backupRootFull | Out-Null
    Assert-PatchNoReparseComponents -Root $backupRootFull -Path $backupRootFull
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $backupPath = Join-Path $backupRootFull (
        $stamp + '-' + [guid]::NewGuid().ToString('N')
    )
    New-Item -ItemType Directory -Path $backupPath | Out-Null
    New-Item -ItemType Directory -Path (
        Join-Path $backupPath 'original'
    ) | Out-Null
    New-Item -ItemType Directory -Path (
        Join-Path $backupPath 'patched'
    ) | Out-Null
    $journalPath = Join-Path $backupPath 'install_journal.log'
    "preflight-complete $(Get-Date -Format o)" |
        Set-Content -LiteralPath $journalPath -Encoding UTF8

    $backupTargets = @()
    foreach ($state in $states) {
        $backupTargets += [pscustomobject]@{
            path = $state.path
            original_exists = $false
            original_sha256 = $null
            patched_sha256 = [string](
                $manifest.targets |
                    Where-Object { $_.path -eq $state.path } |
                    Select-Object -First 1
            ).sha256
        }
    }
    $backupManifest = [ordered]@{
        format = 1
        patch_id = [string]$manifest.patch_id
        status = 'prepared'
        created_at = (Get-Date).ToUniversalTime().ToString('o')
        game_root = $gameRootFull
        package_root = $packageRoot
        install_manifest_sha256 = $manifestInfo.ManifestSha256
        targets = $backupTargets
    }
    $backupManifestPath = Join-Path $backupPath 'backup_manifest.json'
    Write-PatchJsonAtomic -Path $backupManifestPath -Value $backupManifest

    $stageRoot = Get-PatchContainedPath -Root $gameRootFull `
        -RelativePath (
            '.seers-isle-ko-stage-' + [guid]::NewGuid().ToString('N')
        )
    New-Item -ItemType Directory -Path $stageRoot | Out-Null
    foreach ($target in $manifest.targets) {
        $source = Get-PatchTargetSource -PackageRoot $packageRoot `
            -Manifest $manifest -Target $target
        $staged = Get-PatchContainedPath -Root $stageRoot `
            -RelativePath ([string]$target.path)
        New-Item -ItemType Directory -Force -Path (
            Split-Path -Parent $staged
        ) | Out-Null
        Copy-Item -LiteralPath $source -Destination $staged
        Assert-PatchSize -Path $staged -Expected ([long]$target.size) `
            -Label "Staged target $($target.path)"
        Assert-PatchHash -Path $staged -Expected ([string]$target.sha256) `
            -Label "Staged target $($target.path)"
    }

    if (-not $SkipProcessCheck) {
        Assert-PatchProcessStopped
    }
    foreach ($target in $manifest.targets) {
        $livePath = Get-PatchContainedPath -Root $gameRootFull `
            -RelativePath ([string]$target.path)
        Assert-PatchNoReparseComponents -Root $gameRootFull -Path $livePath
        $staged = Get-PatchContainedPath -Root $stageRoot `
            -RelativePath ([string]$target.path)
        $parent = Split-Path -Parent $livePath
        if (-not (Test-Path -LiteralPath $parent -PathType Container)) {
            New-Item -ItemType Directory -Force -Path $parent | Out-Null
            $createdDirectories.Add($parent)
        }
        Assert-PatchNoReparseComponents -Root $gameRootFull -Path $parent
        $temp = Join-Path $parent (
            '.' + [System.IO.Path]::GetFileName($livePath) + '.' +
            [guid]::NewGuid().ToString('N') + '.tmp'
        )
        $temporaryFiles.Add($temp)
        Copy-Item -LiteralPath $staged -Destination $temp
        Assert-PatchHash -Path $temp -Expected ([string]$target.sha256) `
            -Label "Temporary target $($target.path)"
        Move-Item -LiteralPath $temp -Destination $livePath -Force
        [void]$temporaryFiles.Remove($temp)
        $installedTargets.Add($livePath)
        "installed $($target.path) $(Get-Date -Format o)" |
            Add-Content -LiteralPath $journalPath -Encoding UTF8
    }

    foreach ($target in $manifest.targets) {
        $livePath = Get-PatchContainedPath -Root $gameRootFull `
            -RelativePath ([string]$target.path)
        Assert-PatchHash -Path $livePath -Expected ([string]$target.sha256) `
            -Label "Installed target $($target.path)"
        $recoveryPath = Get-PatchContainedPath -Root (
            Join-Path $backupPath 'patched'
        ) -RelativePath ([string]$target.path)
        New-Item -ItemType Directory -Force -Path (
            Split-Path -Parent $recoveryPath
        ) | Out-Null
        Copy-Item -LiteralPath $livePath -Destination $recoveryPath
        Assert-PatchHash -Path $recoveryPath -Expected ([string]$target.sha256) `
            -Label "Patched recovery copy $($target.path)"
    }

    $backupManifest.status = 'installed'
    $backupManifest.completed_at = (Get-Date).ToUniversalTime().ToString('o')
    Write-PatchJsonAtomic -Path $backupManifestPath -Value $backupManifest
    $backupManifestHash = Get-PatchSha256 -Path $backupManifestPath
    [System.IO.File]::WriteAllText(
        (Join-Path $backupPath 'backup_manifest.sha256'),
        $backupManifestHash + [Environment]::NewLine,
        [System.Text.Encoding]::ASCII
    )
    $current = [ordered]@{
        format = 1
        patch_id = [string]$manifest.patch_id
        status = 'installed'
        backup_path = $backupPath
        backup_manifest_sha256 = $backupManifestHash
        game_root = $gameRootFull
        updated_at = (Get-Date).ToUniversalTime().ToString('o')
    }
    Write-PatchJsonAtomic -Path (
        Join-Path $backupRootFull 'current.json'
    ) -Value $current
    "completed $(Get-Date -Format o)" |
        Add-Content -LiteralPath $journalPath -Encoding UTF8

    if ($stageRoot -and (Test-Path -LiteralPath $stageRoot)) {
        if (-not (Test-PatchPathWithin -Candidate $stageRoot -Root $gameRootFull)) {
            throw "Refusing to remove unverified staging path: $stageRoot"
        }
        Remove-Item -LiteralPath $stageRoot -Recurse -Force
        $stageRoot = $null
    }
    Write-Output "Korean patch installed successfully."
    Write-Output "Backup: $backupPath"
}
catch {
    $failure = $_
    foreach ($temp in @($temporaryFiles)) {
        if (
            (Test-PatchPathWithin -Candidate $temp -Root $gameRootFull) -and
            (Test-Path -LiteralPath $temp -PathType Leaf)
        ) {
            Remove-Item -LiteralPath $temp -Force
        }
    }
    foreach ($livePath in @($installedTargets)) {
        if (
            (Test-PatchPathWithin -Candidate $livePath -Root $gameRootFull) -and
            (Test-Path -LiteralPath $livePath -PathType Leaf)
        ) {
            Remove-Item -LiteralPath $livePath -Force
        }
    }
    if ($stageRoot -and (Test-Path -LiteralPath $stageRoot)) {
        if (Test-PatchPathWithin -Candidate $stageRoot -Root $gameRootFull) {
            Remove-Item -LiteralPath $stageRoot -Recurse -Force
        }
    }
    $directories = @($createdDirectories)
    [array]::Reverse($directories)
    foreach ($directory in $directories) {
        if (
            (Test-PatchPathWithin -Candidate $directory -Root $gameRootFull) -and
            (Test-Path -LiteralPath $directory -PathType Container) -and
            @(Get-ChildItem -LiteralPath $directory -Force).Count -eq 0
        ) {
            Remove-Item -LiteralPath $directory -Force
        }
    }
    if ($backupPath -and (Test-Path -LiteralPath $backupPath)) {
        "failed-and-rolled-back $(Get-Date -Format o): $($failure.Exception.Message)" |
            Add-Content -LiteralPath (
                Join-Path $backupPath 'install_journal.log'
            ) -Encoding UTF8
    }
    throw $failure
}
