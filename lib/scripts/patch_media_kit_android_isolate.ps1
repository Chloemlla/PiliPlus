$ErrorActionPreference = "Stop"

$RepositoryRootPath = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "../..")).Path
$MediaKitRevision = "deac6b62569584b6a5e28e6c60c187a0a7281b3a"
$PatchPath = Join-Path $PSScriptRoot "media_kit_android_isolate.patch"
$PackageConfigPath = Join-Path $RepositoryRootPath ".dart_tool/package_config.json"
$LockPath = Join-Path $RepositoryRootPath "pubspec.lock"

foreach ($path in @($PackageConfigPath, $LockPath, $PatchPath)) {
    if (-not (Test-Path -LiteralPath $path)) {
        throw "Required media_kit patch input not found: $path"
    }
}

try {
    $packageConfig = Get-Content -Raw -Encoding UTF8 -LiteralPath $PackageConfigPath |
        ConvertFrom-Json
}
catch {
    throw "Failed to read Dart package config at $PackageConfigPath`: $($_.Exception.Message)"
}

$packageEntries = @(
    $packageConfig.packages | Where-Object { $_.name -eq "media_kit" }
)
if ($packageEntries.Count -ne 1) {
    throw "Expected exactly one media_kit entry in $PackageConfigPath; found $($packageEntries.Count)."
}

$packageUri = [Uri]$packageEntries[0].rootUri
if (-not $packageUri.IsFile) {
    throw "media_kit rootUri is not a local file URI: $packageUri"
}
$packagePath = (Resolve-Path -LiteralPath $packageUri.LocalPath).Path
$packageName = Get-Content -Encoding UTF8 -LiteralPath (Join-Path $packagePath "pubspec.yaml") |
    Where-Object { $_ -match '^name:\s*media_kit\s*$' }
if (-not $packageName) {
    throw "Refusing to patch checkout without name: media_kit at $packagePath."
}

$lockLines = @(Get-Content -Encoding UTF8 -LiteralPath $LockPath)
$lockStarts = @(for ($i = 0; $i -lt $lockLines.Count; $i++) {
    if ($lockLines[$i] -eq "  media_kit:") { $i }
})
if ($lockStarts.Count -ne 1) {
    throw "Expected exactly one media_kit entry in $LockPath; found $($lockStarts.Count)."
}
$lockEnd = $lockLines.Count
for ($i = $lockStarts[0] + 1; $i -lt $lockLines.Count; $i++) {
    if ($lockLines[$i] -match '^  \S') {
        $lockEnd = $i
        break
    }
}
$lockBlock = $lockLines[$lockStarts[0]..($lockEnd - 1)]
foreach ($requiredLine in @(
    "      path: media_kit",
    "      ref: $MediaKitRevision",
    "      resolved-ref: $MediaKitRevision",
    '      url: "https://github.com/My-Responsitories/media-kit.git"',
    "    source: git"
)) {
    if ($lockBlock -notcontains $requiredLine) {
        throw "media_kit lock entry does not contain expected line: $requiredLine"
    }
}

$gitRootOutput = @(& git -C $packagePath rev-parse --show-toplevel 2>&1)
if ($LASTEXITCODE -ne 0) {
    throw "Failed to resolve media_kit checkout: $($gitRootOutput -join [Environment]::NewLine)"
}
$checkoutPath = (Resolve-Path -LiteralPath ($gitRootOutput | Select-Object -Last 1)).Path
$expectedPackagePath = (Join-Path $checkoutPath "media_kit")
if ($packagePath.TrimEnd([IO.Path]::DirectorySeparatorChar) -ne
    $expectedPackagePath.TrimEnd([IO.Path]::DirectorySeparatorChar)) {
    throw "media_kit resolved to unexpected package path $packagePath; expected $expectedPackagePath."
}
if ((Split-Path -Leaf $checkoutPath) -ne "media-kit-$MediaKitRevision") {
    throw "media_kit checkout directory is $checkoutPath; expected media-kit-$MediaKitRevision."
}

$headOutput = @(& git -C $checkoutPath rev-parse HEAD 2>&1)
if ($LASTEXITCODE -ne 0) {
    throw "Failed to inspect media_kit HEAD: $($headOutput -join [Environment]::NewLine)"
}
$head = ($headOutput | Select-Object -Last 1).Trim()
if ($head -ne $MediaKitRevision) {
    throw "media_kit HEAD is $head; expected pinned revision $MediaKitRevision."
}

$statusOutput = @(& git -C $checkoutPath status --porcelain=v1 --untracked-files=all 2>&1)
if ($LASTEXITCODE -ne 0) {
    throw "Failed to inspect media_kit worktree: $($statusOutput -join [Environment]::NewLine)"
}
$expectedStatus = " M media_kit/lib/src/player/native/core/initializer.dart"
if ($statusOutput.Count -eq 0) {
    $applyCheckOutput = @(& git -C $checkoutPath apply --unidiff-zero --check -- $PatchPath 2>&1)
    if ($LASTEXITCODE -ne 0) {
        throw "Failed media_kit patch apply check: $($applyCheckOutput -join [Environment]::NewLine)"
    }
    $applyOutput = @(& git -C $checkoutPath apply --unidiff-zero --whitespace=nowarn -- $PatchPath 2>&1)
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to apply $PatchPath`: $($applyOutput -join [Environment]::NewLine)"
    }
    $patchState = "applied"
} elseif ($statusOutput.Count -eq 1 -and $statusOutput[0] -eq $expectedStatus) {
    $reverseCheckOutput = @(& git -C $checkoutPath apply --unidiff-zero --reverse --check -- $PatchPath 2>&1)
    if ($LASTEXITCODE -ne 0) {
        throw "Expected media_kit patch state failed reverse check: $($reverseCheckOutput -join [Environment]::NewLine)"
    }
    $patchState = "already applied"
} else {
    throw "Refusing to patch a dirty media_kit checkout: $($statusOutput -join [Environment]::NewLine)"
}

$patchedStatus = @(& git -C $checkoutPath status --porcelain=v1 --untracked-files=all 2>&1)
if ($LASTEXITCODE -ne 0 -or $patchedStatus.Count -ne 1 -or $patchedStatus[0] -ne $expectedStatus) {
    throw "media_kit contains changes beyond the expected patch: $($patchedStatus -join [Environment]::NewLine)"
}

$initializerPath = Join-Path $packagePath "lib/src/player/native/core/initializer.dart"
$initializer = Get-Content -Raw -Encoding UTF8 -LiteralPath $initializerPath
$markers = @(
    "import 'dart:io';",
    'if\s*\(Platform\.isAndroid\)\s*\{\s*return InitializerIsolate\.create\(',
    'if\s*\(Platform\.isAndroid\)\s*\{\s*InitializerIsolate\.dispose\(handle\);\s*return;',
    'try\s*\{\s*return InitializerNativeEventLoop\.create\(',
    'try\s*\{\s*InitializerNativeEventLoop\.dispose\(handle\);'
)
foreach ($marker in $markers) {
    if ($initializer -notmatch $marker) {
        throw "Patched media_kit initializer is missing expected marker: $marker"
    }
}
if ([regex]::Matches($initializer, 'Platform\.isAndroid').Count -ne 2) {
    throw "Patched media_kit initializer must contain exactly two Android backend guards."
}

Write-Host "$PatchPath $patchState to media_kit@$MediaKitRevision"
