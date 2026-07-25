Set-StrictMode -Version Latest

function Get-PatchSha256 {
    param([Parameter(Mandatory = $true)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Required file is missing: $Path"
    }
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Read-PatchJson {
    param([Parameter(Mandatory = $true)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Required JSON file is missing: $Path"
    }
    return Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json
}

function Get-PatchFullPath {
    param([Parameter(Mandatory = $true)][string]$Path)
    return [System.IO.Path]::GetFullPath($Path)
}

function Get-PatchContainedPath {
    param(
        [Parameter(Mandatory = $true)][string]$Root,
        [Parameter(Mandatory = $true)][string]$RelativePath
    )
    if ([System.IO.Path]::IsPathRooted($RelativePath)) {
        throw "Manifest path must be relative: $RelativePath"
    }
    $rootFull = [System.IO.Path]::GetFullPath($Root)
    $candidate = [System.IO.Path]::GetFullPath(
        [System.IO.Path]::Combine($rootFull, $RelativePath)
    )
    $rootPrefix = $rootFull.TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar
    if (-not $candidate.StartsWith(
        $rootPrefix,
        [System.StringComparison]::OrdinalIgnoreCase
    )) {
        throw "Manifest path escapes its root: $RelativePath"
    }
    return $candidate
}

function Test-PatchPathWithin {
    param(
        [Parameter(Mandatory = $true)][string]$Candidate,
        [Parameter(Mandatory = $true)][string]$Root
    )
    $candidateFull = [System.IO.Path]::GetFullPath($Candidate)
    $rootFull = [System.IO.Path]::GetFullPath($Root)
    if ($candidateFull.Equals(
        $rootFull,
        [System.StringComparison]::OrdinalIgnoreCase
    )) {
        return $true
    }
    $rootPrefix = $rootFull.TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar
    return $candidateFull.StartsWith(
        $rootPrefix,
        [System.StringComparison]::OrdinalIgnoreCase
    )
}

function Assert-PatchNoReparseComponents {
    param(
        [Parameter(Mandatory = $true)][string]$Root,
        [Parameter(Mandatory = $true)][string]$Path
    )
    $rootFull = [System.IO.Path]::GetFullPath($Root)
    $pathFull = [System.IO.Path]::GetFullPath($Path)
    if (-not (Test-PatchPathWithin -Candidate $pathFull -Root $rootFull)) {
        throw "Path is outside the asserted root: $pathFull"
    }
    $current = $pathFull
    while ($true) {
        if (Test-Path -LiteralPath $current) {
            $item = Get-Item -LiteralPath $current -Force
            if (
                ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0
            ) {
                throw "Reparse points are not allowed in patch paths: $current"
            }
        }
        if ($current.Equals(
            $rootFull,
            [System.StringComparison]::OrdinalIgnoreCase
        )) {
            break
        }
        $parent = Split-Path -Parent $current
        if ([string]::IsNullOrWhiteSpace($parent) -or $parent -eq $current) {
            throw "Could not walk path back to asserted root: $pathFull"
        }
        $current = [System.IO.Path]::GetFullPath($parent)
    }
}

function Assert-PatchHash {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Expected,
        [string]$Label = $Path
    )
    $actual = Get-PatchSha256 -Path $Path
    if ($actual -ne $Expected.ToLowerInvariant()) {
        throw "$Label hash mismatch. Expected $Expected, got $actual"
    }
}

function Assert-PatchSize {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][long]$Expected,
        [string]$Label = $Path
    )
    $actual = (Get-Item -LiteralPath $Path).Length
    if ($actual -ne $Expected) {
        throw "$Label size mismatch. Expected $Expected, got $actual"
    }
}

function Get-PatchManifest {
    param([Parameter(Mandatory = $true)][string]$PackageRoot)
    $manifestPath = Join-Path $PackageRoot 'install_manifest.json'
    $manifestHashPath = Join-Path $PackageRoot 'install_manifest.sha256'
    $expectedManifestHash = (
        Get-Content -LiteralPath $manifestHashPath -Raw -Encoding ASCII
    ).Trim().ToLowerInvariant()
    if ($expectedManifestHash -notmatch '^[0-9a-f]{64}$') {
        throw "Invalid install_manifest.sha256"
    }
    Assert-PatchHash -Path $manifestPath -Expected $expectedManifestHash `
        -Label 'install_manifest.json'
    $manifest = Read-PatchJson -Path $manifestPath
    if ($manifest.format -ne 1) {
        throw "Unsupported install manifest format: $($manifest.format)"
    }
    if ($manifest.patch_id -ne 'seers-isle-ko-kr') {
        throw "Unexpected patch ID: $($manifest.patch_id)"
    }

    $allowedTargets = @(
        'Seers-Isle_Data\StreamingAssets\locales\ko-KR\config.json',
        'Seers-Isle_Data\StreamingAssets\locales\ko-KR\localizable.strings',
        'Seers-Isle_Data\StreamingAssets\locales\ko-KR\ui.strings',
        'Seers-Isle_Data\StreamingAssets\fonts\SeersIsle-Korean-Regular.ttf',
        'Seers-Isle_Data\StreamingAssets\fonts\SeersIsle-Korean-Bold.ttf'
    )
    $targetPaths = @($manifest.targets | ForEach-Object { [string]$_.path })
    if ($targetPaths.Count -ne $allowedTargets.Count) {
        throw "Manifest must contain exactly $($allowedTargets.Count) patch targets"
    }
    if (@($targetPaths | Select-Object -Unique).Count -ne $targetPaths.Count) {
        throw "Manifest contains duplicate target paths"
    }
    foreach ($allowed in $allowedTargets) {
        if ($targetPaths -notcontains $allowed) {
            throw "Manifest is missing allowlisted target: $allowed"
        }
    }
    foreach ($target in $manifest.targets) {
        if ($target.source_kind -ne 'payload') {
            throw "Invalid source_kind for $($target.path): $($target.source_kind)"
        }
        if ([string]$target.sha256 -notmatch '^[0-9a-fA-F]{64}$') {
            throw "Invalid SHA-256 for target $($target.path)"
        }
        if ([long]$target.size -lt 1) {
            throw "Invalid size for target $($target.path)"
        }
    }
    return [pscustomobject]@{
        Manifest = $manifest
        ManifestPath = $manifestPath
        ManifestSha256 = $expectedManifestHash
    }
}

function Assert-PatchPackageFiles {
    param(
        [Parameter(Mandatory = $true)][string]$PackageRoot,
        [Parameter(Mandatory = $true)]$Manifest
    )
    foreach ($file in $Manifest.package_files) {
        $path = Get-PatchContainedPath -Root $PackageRoot `
            -RelativePath ([string]$file.path)
        Assert-PatchNoReparseComponents -Root $PackageRoot -Path $path
        Assert-PatchSize -Path $path -Expected ([long]$file.size) `
            -Label "Package file $($file.path)"
        Assert-PatchHash -Path $path -Expected ([string]$file.sha256) `
            -Label "Package file $($file.path)"
    }
}

function Assert-PatchGameCompatibility {
    param(
        [Parameter(Mandatory = $true)][string]$GameRoot,
        [Parameter(Mandatory = $true)]$Manifest
    )
    $exePath = Get-PatchContainedPath -Root $GameRoot `
        -RelativePath ([string]$Manifest.game.executable)
    if (-not (Test-Path -LiteralPath $exePath -PathType Leaf)) {
        throw "Seers Isle executable not found: $exePath"
    }
    foreach ($file in $Manifest.game.compatibility_files) {
        $path = Get-PatchContainedPath -Root $GameRoot `
            -RelativePath ([string]$file.path)
        Assert-PatchNoReparseComponents -Root $GameRoot -Path $path
        Assert-PatchSize -Path $path -Expected ([long]$file.size) `
            -Label "Live compatibility file $($file.path)"
        Assert-PatchHash -Path $path -Expected ([string]$file.sha256) `
            -Label "Live compatibility file $($file.path)"
    }
}

function Get-PatchTargetSource {
    param(
        [Parameter(Mandatory = $true)][string]$PackageRoot,
        [Parameter(Mandatory = $true)]$Manifest,
        [Parameter(Mandatory = $true)]$Target
    )
    if ($Target.source_kind -ne 'payload') {
        throw "Patch targets must come from the verified package payload"
    }
    return Get-PatchContainedPath -Root $PackageRoot `
        -RelativePath ([string]$Target.source)
}

function Assert-PatchTargetSources {
    param(
        [Parameter(Mandatory = $true)][string]$PackageRoot,
        [Parameter(Mandatory = $true)]$Manifest
    )
    foreach ($target in $Manifest.targets) {
        $source = Get-PatchTargetSource -PackageRoot $PackageRoot `
            -Manifest $Manifest -Target $target
        Assert-PatchNoReparseComponents -Root $PackageRoot -Path $source
        Assert-PatchSize -Path $source -Expected ([long]$target.size) `
            -Label "Target source for $($target.path)"
        Assert-PatchHash -Path $source -Expected ([string]$target.sha256) `
            -Label "Target source for $($target.path)"
    }
}

function Assert-PatchProcessStopped {
    $running = @(Get-Process -Name 'Seers-Isle' -ErrorAction SilentlyContinue)
    if ($running.Count -gt 0) {
        throw "Seers Isle is running. Close the game before installing or restoring."
    }
}

function Write-PatchJsonAtomic {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)]$Value
    )
    $parent = Split-Path -Parent $Path
    New-Item -ItemType Directory -Force -Path $parent | Out-Null
    $temp = Join-Path $parent (
        '.' + [System.IO.Path]::GetFileName($Path) + '.' +
        [guid]::NewGuid().ToString('N') + '.tmp'
    )
    $json = $Value | ConvertTo-Json -Depth 20
    [System.IO.File]::WriteAllText(
        $temp,
        $json + [Environment]::NewLine,
        (New-Object System.Text.UTF8Encoding($false))
    )
    Move-Item -LiteralPath $temp -Destination $Path -Force
}

function Assert-PatchBackupOutside {
    param(
        [Parameter(Mandatory = $true)][string]$BackupRoot,
        [Parameter(Mandatory = $true)][string]$GameRoot,
        [Parameter(Mandatory = $true)][string]$PackageRoot
    )
    $backup = [System.IO.Path]::GetFullPath($BackupRoot)
    $game = [System.IO.Path]::GetFullPath($GameRoot)
    $package = [System.IO.Path]::GetFullPath($PackageRoot)
    if (
        (Test-PatchPathWithin -Candidate $backup -Root $game) -or
        (Test-PatchPathWithin -Candidate $backup -Root $package) -or
        (Test-PatchPathWithin -Candidate $game -Root $backup) -or
        (Test-PatchPathWithin -Candidate $package -Root $backup)
    ) {
        throw "Backup root must be outside both game and package trees: $backup"
    }
}

function Assert-PatchRecoveryBackup {
    param(
        [Parameter(Mandatory = $true)][string]$BackupRoot,
        [Parameter(Mandatory = $true)][string]$GameRoot,
        [Parameter(Mandatory = $true)][string]$PackageRoot,
        [Parameter(Mandatory = $true)]$ManifestInfo
    )
    $manifest = $ManifestInfo.Manifest
    $currentPath = Join-Path $BackupRoot 'current.json'
    $current = Read-PatchJson -Path $currentPath
    if ($current.patch_id -ne $manifest.patch_id -or $current.status -ne 'installed') {
        throw "Installed targets exist but the current recovery pointer is not valid"
    }
    if (
        -not ([System.IO.Path]::GetFullPath([string]$current.game_root)).Equals(
            [System.IO.Path]::GetFullPath($GameRoot),
            [System.StringComparison]::OrdinalIgnoreCase
        )
    ) {
        throw "Current recovery pointer belongs to another game root"
    }
    $backupPath = [System.IO.Path]::GetFullPath([string]$current.backup_path)
    if (-not (Test-PatchPathWithin -Candidate $backupPath -Root $BackupRoot)) {
        throw "Current recovery pointer escapes the configured backup root"
    }
    Assert-PatchNoReparseComponents -Root $BackupRoot -Path $backupPath
    if (
        (Test-PatchPathWithin -Candidate $backupPath -Root $GameRoot) -or
        (Test-PatchPathWithin -Candidate $backupPath -Root $PackageRoot)
    ) {
        throw "Recovery backup is inside the game or package tree"
    }

    $backupManifestPath = Join-Path $backupPath 'backup_manifest.json'
    $backupHashPath = Join-Path $backupPath 'backup_manifest.sha256'
    $sidecarHash = (
        Get-Content -LiteralPath $backupHashPath -Raw -Encoding ASCII
    ).Trim().ToLowerInvariant()
    $pointerHash = ([string]$current.backup_manifest_sha256).ToLowerInvariant()
    if (
        $sidecarHash -notmatch '^[0-9a-f]{64}$' -or
        $sidecarHash -ne $pointerHash
    ) {
        throw "Recovery pointer and backup manifest hash do not agree"
    }
    Assert-PatchHash -Path $backupManifestPath -Expected $pointerHash `
        -Label 'backup_manifest.json'
    $backupManifest = Read-PatchJson -Path $backupManifestPath
    if (
        $backupManifest.format -ne 1 -or
        $backupManifest.patch_id -ne $manifest.patch_id -or
        $backupManifest.status -ne 'installed' -or
        $backupManifest.install_manifest_sha256 -ne
            $ManifestInfo.ManifestSha256
    ) {
        throw "Recovery backup metadata is invalid or belongs to another package"
    }
    $manifestTargets = @{}
    foreach ($target in $manifest.targets) {
        $manifestTargets[[string]$target.path] = $target
    }
    $backupTargets = @($backupManifest.targets)
    if ($backupTargets.Count -ne $manifestTargets.Count) {
        throw "Recovery backup target count is invalid"
    }
    foreach ($backupTarget in $backupTargets) {
        $relative = [string]$backupTarget.path
        if (-not $manifestTargets.ContainsKey($relative)) {
            throw "Recovery backup has an unknown target: $relative"
        }
        if (
            [bool]$backupTarget.original_exists -or
            $null -ne $backupTarget.original_sha256
        ) {
            throw "This additive patch requires every recorded original target to be absent"
        }
        $target = $manifestTargets[$relative]
        if (
            ([string]$backupTarget.patched_sha256).ToLowerInvariant() -ne
            ([string]$target.sha256).ToLowerInvariant()
        ) {
            throw "Recovery backup target hash disagrees with package: $relative"
        }
        $recovery = Get-PatchContainedPath -Root (
            Join-Path $backupPath 'patched'
        ) -RelativePath $relative
        Assert-PatchNoReparseComponents -Root $backupPath -Path $recovery
        Assert-PatchHash -Path $recovery -Expected ([string]$target.sha256) `
            -Label "Patched recovery copy $relative"
    }
    return [pscustomobject]@{
        Current = $current
        BackupPath = $backupPath
        BackupManifest = $backupManifest
        BackupManifestPath = $backupManifestPath
        BackupManifestSha256 = $pointerHash
    }
}

Export-ModuleMember -Function @(
    'Get-PatchSha256',
    'Read-PatchJson',
    'Get-PatchFullPath',
    'Get-PatchContainedPath',
    'Test-PatchPathWithin',
    'Assert-PatchNoReparseComponents',
    'Assert-PatchHash',
    'Assert-PatchSize',
    'Get-PatchManifest',
    'Assert-PatchPackageFiles',
    'Assert-PatchGameCompatibility',
    'Get-PatchTargetSource',
    'Assert-PatchTargetSources',
    'Assert-PatchProcessStopped',
    'Write-PatchJsonAtomic',
    'Assert-PatchBackupOutside',
    'Assert-PatchRecoveryBackup'
)
