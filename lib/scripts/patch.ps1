param(
    [string]$platform = ""
)

# TODO: remove
# https://github.com/flutter/flutter/issues/182281
$NewOverScrollIndicator = "362b1de29974ffc1ed6faa826e1df870d7bec75f";

$BottomSheetAndroidPatch = "lib/scripts/bottom_sheet_android.patch"

# https://github.com/Chloemlla/PiliPlus/issues/1906
$BottomSheetIOSFlutterPatch = "lib/scripts/bottom_sheet_ios_flutter.patch"
$BottomSheetIOSPiliPlusPatch = "lib/scripts/bottom_sheet_ios_piliplus.patch"

# https://github.com/Chloemlla/PiliPlus/issues/1662
$ScrollViewPatch = "lib/scripts/scroll_view.patch"

# https://github.com/Chloemlla/PiliPlus/issues/2106
$TextSelectionPatch = "lib/scripts/text_selection.patch"

# https://github.com/Chloemlla/PiliPlus/issues/1947
$NavigatorPatch = "lib/scripts/navigator.patch"

# https://github.com/Chloemlla/PiliPlus/issues/2107
$ImageAnimPatch = "lib/scripts/image_anim.patch"

$LayoutBuilderPatch = "lib/scripts/layout_builder.patch"

# https://github.com/Chloemlla/PiliPlus/issues/2308
$NavigationDrawerPatch = "lib/scripts/navigation_drawer.patch"

$PopupMenuPatch = "lib/scripts/popup_menu.patch"

$FABPatch = "lib/scripts/fab.patch"

$SelectableRegionSelectionPatch = "lib/scripts/selectable_region.patch"

# TODO: remove
# https://github.com/flutter/flutter/pull/183261
$SelectableRegionPatch = "lib/scripts/null_safety_for_selectable_region.patch"

# TODO: remove
# https://github.com/flutter/flutter/issues/90223
$ModalBarrierPatch = "lib/scripts/modal_barrier.patch"

# TODO: remove
# https://github.com/flutter/flutter/issues/182466
$MouseCursorPatch = "lib/scripts/mouse_cursor.patch"

$GeetestIOSPatch = "lib/scripts/geetest_ios.patch"

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
    if (-not [string]::IsNullOrWhiteSpace($env:PUB_CACHE)) {
        $pubCachePath = $env:PUB_CACHE
    }
    else {
        $pubCachePath = Join-Path $HOME ".pub-cache"
    }

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
if (-not [string]::IsNullOrWhiteSpace($env:GITHUB_WORKSPACE)) {
    $WorkspacePath = Resolve-Path -LiteralPath $env:GITHUB_WORKSPACE
    if ($FlutterRootPath.Path -eq $WorkspacePath.Path) {
        throw "FLUTTER_ROOT points at GITHUB_WORKSPACE; refusing to reset the project repository."
    }
}

Set-Location $FlutterRootPath

$picks   = @()
$reverts = @()
$patches = @($ModalBarrierPatch, $TextSelectionPatch, $MouseCursorPatch,
            $ImageAnimPatch, $LayoutBuilderPatch, $NavigationDrawerPatch,
            $PopupMenuPatch, $FABPatch, $SelectableRegionPatch, $SelectableRegionSelectionPatch)

switch ($platform.ToLower()) {
    "android" {
        $reverts += $NewOverScrollIndicator
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
    git apply "$env:GITHUB_WORKSPACE/$patch"
    if ($LASTEXITCODE -eq 0) {
        Write-Host "$patch applied"
    }
}
