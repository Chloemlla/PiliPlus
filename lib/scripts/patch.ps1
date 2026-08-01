param(
    [string]$platform = ""
)

$RepositoryRootPath = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "../..")).Path

$CanvasDanmakuRef = "697d4516df2fc3ba7417c7ce9aba079d34ba13e5"
$CanvasDanmakuPatch = Join-Path $PSScriptRoot "canvas_danmaku_stroke_color.patch"

# TODO: remove
# https://github.com/flutter/flutter/issues/182281
$NewOverScrollIndicator = "362b1de29974ffc1ed6faa826e1df870d7bec75f";

# set `gestureSettings`
$BottomSheetAndroidPatch = "lib/scripts/bottom_sheet_android.patch"

# https://github.com/Chloemlla/PiliPlus/issues/1906
$BottomSheetIOSFlutterPatch = "lib/scripts/bottom_sheet_ios_flutter.patch"
$BottomSheetIOSPiliPlusPatch = "lib/scripts/bottom_sheet_ios_piliplus.patch"

# TODO: remove
# https://github.com/flutter/flutter/issues/185052
$TextSelectionMenuFix = "beb2ad17004a1b118ff2bd09f55cee23198f6652";

# https://github.com/Chloemlla/PiliPlus/issues/1662
# handle bottom scroll event
$ScrollViewPatch = "lib/scripts/scroll_view.patch"

# https://github.com/Chloemlla/PiliPlus/issues/2106
# use `TouchGestureRecognizer` on all platforms
$TextSelectionPatch = "lib/scripts/text_selection.patch"

# https://github.com/Chloemlla/PiliPlus/issues/1947
$NavigatorPatch = "lib/scripts/navigator.patch"

# https://github.com/Chloemlla/PiliPlus/issues/2107
$ImageAnimPatch = "lib/scripts/image_anim.patch"

# remove `_scheduleRebuild`
$LayoutBuilderPatch = "lib/scripts/layout_builder.patch"

# https://github.com/Chloemlla/PiliPlus/issues/2308
$NavigationDrawerPatch = "lib/scripts/navigation_drawer.patch"

# apply text color to icon color
$PopupMenuPatch = "lib/scripts/popup_menu.patch"

# remove `Hero` effect
$FABPatch = "lib/scripts/fab.patch"

# https://github.com/flutter/flutter/issues/139890
# https://github.com/flutter/flutter/issues/174689
# separator support
# clamp handle offset
# widgetspan selection support
# clear selection when tapping outside
# free selection if there is only one text
# clamp dragging selection behavior on Android
# show selection menu if secondary tap position is in text region on desktop
$SelectableRegionPatch = "lib/scripts/selectable_region.patch"

# https://github.com/flutter/flutter/issues/132047
# https://github.com/flutter/flutter/issues/174689
$EditableTextPatch = "lib/scripts/editable_text.patch"

# set `selectAllOnFocus` to `false` by default
$TextFieldPatch = "lib/scripts/text_field.patch"

# notify `userScrollDirection` only if position is actually changing
$ScrollPositionPatch = "lib/scripts/scroll_position.patch"

# expose `_shouldIgnorePointer`
$ScrollablePatch = "lib/scripts/scrollable.patch"

$TabsPatch = "lib/scripts/tabs.patch"

# TODO: remove
# https://github.com/flutter/flutter/issues/124078
# https://github.com/flutter/flutter/pull/183261
$NullSafetySelectableRegionPatch = "lib/scripts/null_safety_for_selectable_region.patch"

# TODO: remove
# https://github.com/flutter/flutter/issues/90223
$ModalBarrierPatch = "lib/scripts/modal_barrier.patch"

# TODO: remove
# https://github.com/flutter/flutter/issues/182466
$MouseCursorPatch = "lib/scripts/mouse_cursor.patch"

$GeetestIOSPatch = "lib/scripts/geetest_ios.patch"

function Get-PubCacheRootPath {
    if (-not [string]::IsNullOrWhiteSpace($env:PUB_CACHE)) {
        return [System.IO.Path]::GetFullPath($env:PUB_CACHE)
    }

    if ($IsWindows) {
        $localAppData = [Environment]::GetFolderPath(
            [Environment+SpecialFolder]::LocalApplicationData
        )
        return Join-Path $localAppData "Pub/Cache"
    }

    $userProfile = [Environment]::GetFolderPath(
        [Environment+SpecialFolder]::UserProfile
    )
    return Join-Path $userProfile ".pub-cache"
}

function Apply-CanvasDanmakuPatch {
    $packageConfigPath = Join-Path $RepositoryRootPath ".dart_tool/package_config.json"
    if (-not (Test-Path -LiteralPath $packageConfigPath)) {
        throw "Missing $packageConfigPath. Run flutter pub get before lib/scripts/patch.ps1."
    }

    try {
        $packageConfig = Get-Content -Raw -Encoding UTF8 -LiteralPath $packageConfigPath |
            ConvertFrom-Json
    }
    catch {
        throw "Failed to read Dart package config at $packageConfigPath`: $($_.Exception.Message)"
    }

    $packageEntries = @(
        $packageConfig.packages | Where-Object { $_.name -eq "canvas_danmaku" }
    )
    if ($packageEntries.Count -ne 1) {
        throw "Expected exactly one canvas_danmaku entry in $packageConfigPath; found $($packageEntries.Count)."
    }

    $packageUri = [Uri]$packageEntries[0].rootUri
    if (-not $packageUri.IsFile) {
        throw "canvas_danmaku rootUri is not a local file URI: $packageUri"
    }

    $pubCacheRootPath = Get-PubCacheRootPath
    $expectedPackagePath = Join-Path (
        Join-Path $pubCacheRootPath "git"
    ) "canvas_danmaku-$CanvasDanmakuRef"
    if (-not (Test-Path -LiteralPath $expectedPackagePath)) {
        throw "Pinned canvas_danmaku checkout not found at $expectedPackagePath. Run flutter pub get first."
    }

    $directorySeparators = [char[]]@(
        [IO.Path]::DirectorySeparatorChar,
        [IO.Path]::AltDirectorySeparatorChar
    )
    $resolvedPackagePath = (Resolve-Path -LiteralPath $packageUri.LocalPath).Path.TrimEnd($directorySeparators)
    $resolvedExpectedPath = (Resolve-Path -LiteralPath $expectedPackagePath).Path.TrimEnd($directorySeparators)
    if ($resolvedPackagePath -ne $resolvedExpectedPath) {
        throw "canvas_danmaku resolved to unexpected checkout $resolvedPackagePath; expected $resolvedExpectedPath."
    }

    $packageName = Get-Content -Encoding UTF8 -LiteralPath (
        Join-Path $resolvedPackagePath "pubspec.yaml"
    ) | Where-Object { $_ -match '^name:\s*canvas_danmaku\s*$' }
    if (-not $packageName) {
        throw "Refusing to patch checkout without name: canvas_danmaku at $resolvedPackagePath."
    }

    $headOutput = @(& git -C $resolvedPackagePath rev-parse HEAD 2>&1)
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to inspect canvas_danmaku checkout at $resolvedPackagePath`: $($headOutput -join [Environment]::NewLine)"
    }
    $head = ($headOutput | Select-Object -Last 1).Trim()
    if ($head -ne $CanvasDanmakuRef) {
        throw "canvas_danmaku HEAD is $head; expected pinned ref $CanvasDanmakuRef."
    }

    if (-not (Test-Path -LiteralPath $CanvasDanmakuPatch)) {
        throw "canvas_danmaku patch file not found: $CanvasDanmakuPatch"
    }

    $statusOutput = @(
        & git -C $resolvedPackagePath status --porcelain=v1 --untracked-files=all 2>&1
    )
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to inspect canvas_danmaku worktree state: $($statusOutput -join [Environment]::NewLine)"
    }

    $applyCheckOutput = @(
        & git -C $resolvedPackagePath apply --check -- $CanvasDanmakuPatch 2>&1
    )
    if ($LASTEXITCODE -eq 0) {
        if ($statusOutput.Count -ne 0) {
            throw "Refusing to patch a dirty canvas_danmaku checkout: $($statusOutput -join [Environment]::NewLine)"
        }
        $applyOutput = @(
            & git -C $resolvedPackagePath apply --whitespace=nowarn -- $CanvasDanmakuPatch 2>&1
        )
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to apply $CanvasDanmakuPatch`: $($applyOutput -join [Environment]::NewLine)"
        }
        Write-Host "$CanvasDanmakuPatch applied to canvas_danmaku@$CanvasDanmakuRef"
        return
    }

    $reverseCheckOutput = @(
        & git -C $resolvedPackagePath apply --reverse --check -- $CanvasDanmakuPatch 2>&1
    )
    if ($LASTEXITCODE -eq 0) {
        $expectedStatus = @(
            " M lib/models/danmaku_content_item.dart",
            " M lib/utils/utils.dart"
        )
        if (@(Compare-Object $expectedStatus $statusOutput).Count -ne 0) {
            throw "canvas_danmaku contains changes beyond the expected patch: $($statusOutput -join [Environment]::NewLine)"
        }
        Write-Host "$CanvasDanmakuPatch already applied to canvas_danmaku@$CanvasDanmakuRef"
        return
    }

    throw @"
$CanvasDanmakuPatch neither applies cleanly nor appears already applied.
Apply check:
$($applyCheckOutput -join [Environment]::NewLine)
Reverse check:
$($reverseCheckOutput -join [Environment]::NewLine)
"@
}

function Remove-AndroidManifestPackageAttribute {
    param(
        [Parameter(Mandatory=$true)]
        [string]$ManifestPath
    )

    $doc = [System.Xml.XmlDocument]::new()
    $doc.PreserveWhitespace = $true
    $doc.Load($ManifestPath)

    if ($null -eq $doc.DocumentElement -or -not $doc.DocumentElement.HasAttribute("package")) {
        return $false
    }

    $packageName = $doc.DocumentElement.GetAttribute("package")
    $doc.DocumentElement.RemoveAttribute("package")
    $doc.Save($ManifestPath)
    Write-Host "Removed AndroidManifest package attribute ($packageName): $ManifestPath"
    return $true
}

function Remove-PubCacheAndroidManifestPackageAttributes {
    $pubCachePath = Get-PubCacheRootPath
    $hostedPath = Join-Path $pubCachePath "hosted"
    if (-not (Test-Path -LiteralPath $hostedPath)) {
        Write-Host "Pub cache hosted directory not found: $hostedPath"
        return
    }

    $patchedCount = 0
    foreach ($hostedSource in Get-ChildItem -LiteralPath $hostedPath -Directory) {
        foreach ($packageDir in Get-ChildItem -LiteralPath $hostedSource.FullName -Directory) {
            $manifestPath = Join-Path $packageDir.FullName "android/src/main/AndroidManifest.xml"
            if ((Test-Path -LiteralPath $manifestPath) -and
                (Remove-AndroidManifestPackageAttribute -ManifestPath $manifestPath)) {
                $patchedCount++
            }
        }
    }

    Write-Host "Removed AndroidManifest package attributes from $patchedCount pub-cache package(s)."
}

Apply-CanvasDanmakuPatch

if ($platform.ToLower() -eq "ios") {
    git apply $BottomSheetIOSPiliPlusPatch
    if ($LASTEXITCODE -eq 0) {
        Write-Host "$BottomSheetIOSPiliPlusPatch applied"
    }
    git apply $GeetestIOSPatch
    if ($LASTEXITCODE -eq 0) {
        Write-Host "$GeetestIOSPatch applied"
    }
}

if ($platform.ToLower() -eq "android") {
    Remove-PubCacheAndroidManifestPackageAttributes
}

if ([string]::IsNullOrWhiteSpace($env:FLUTTER_ROOT)) {
    throw "FLUTTER_ROOT is not set; refusing to patch an unknown SDK path."
}

$FlutterRootPath = Resolve-Path -LiteralPath $env:FLUTTER_ROOT
if ($FlutterRootPath.Path -eq $RepositoryRootPath) {
    throw "FLUTTER_ROOT points at the project repository; refusing to reset it."
}

Set-Location $FlutterRootPath

$picks   = @($TextSelectionMenuFix)
$reverts = @()
$patches = @($ModalBarrierPatch, $TextSelectionPatch, $MouseCursorPatch,
            $ImageAnimPatch, $LayoutBuilderPatch, $NavigationDrawerPatch,
            $PopupMenuPatch, $FABPatch, $NullSafetySelectableRegionPatch,
            $SelectableRegionPatch, $EditableTextPatch, $TextFieldPatch,
            $ScrollPositionPatch, $ScrollablePatch, $TabsPatch)

switch ($platform.ToLower()) {
    "android" {
        $patches += $BottomSheetAndroidPatch
        $patches += $ScrollViewPatch
        $patches += $NavigatorPatch
    }
    "ios" {
        $patches += $ScrollViewPatch
        $patches += $BottomSheetIOSFlutterPatch
        $patches += $NavigatorPatch
    }
    "linux" {
    }
    "macos" {
    }
    "windows" {
    }
    default {}
}

git config --global user.name "ci"
git config --global user.email "example@example.com"

git reset --hard HEAD

foreach ($pick in $picks) {
    git stash
    git cherry-pick $pick --no-edit
    if ($LASTEXITCODE -eq 0) {
        git reset --soft HEAD~1
        Write-Host "$pick picked"
    }
    git stash pop
}

foreach ($revert in $reverts) {
    git stash
    git revert $revert --no-edit
    if ($LASTEXITCODE -eq 0) {
        git reset --soft HEAD~1
        Write-Host "$revert reverted"
    }
    git stash pop
}

foreach ($patch in $patches) {
    git apply (Join-Path $RepositoryRootPath $patch)
    if ($LASTEXITCODE -eq 0) {
        Write-Host "$patch applied"
    }
}
