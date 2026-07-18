<# SPDX-LICENSE-IDENTIFIER: 0BSD #>

<#
.SYNOPSIS
    Build and package Save & Load Accelerator for SKSE Cosaves for release.

.DESCRIPTION
    Builds both CPU profiles (High-End x86-64-v3, Universal x86-64-v2) for all
    game-version variants, stages a clean FOMOD payload, and produces the
    release zip plus a SHA-256 sidecar. Public payloads never contain PDBs or
    other build artifacts; symbols stay in the build tree for developers.
#>

[CmdletBinding()]
Param
(
    [Parameter()]
        [ValidateNotNull()]
            $Version = '1.4.0',

    [Parameter()]
        [Switch] $SkipBuild
)

$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $Root

$Variants = @('ae', 'ae1130', 'ae640', 'ae353', 'se', 'vr', 'gog', 'gog659')
$DLLName = 'Save&LoadAcceleratorForSKSECosaves.dll'
$ININame = 'Save&LoadAcceleratorForSKSECosaves.ini'

if (-not $SkipBuild)
{
    & (Join-Path $Root 'build.ps1') -TargetCPU 'x86-64-v3' -BuildTag '-v3'
    if ($LASTEXITCODE -ne 0) { throw "High-End (x86-64-v3) build failed: $LASTEXITCODE" }

    & (Join-Path $Root 'build.ps1') -TargetCPU 'x86-64-v2' -BuildTag '-v2'
    if ($LASTEXITCODE -ne 0) { throw "Universal (x86-64-v2) build failed: $LASTEXITCODE" }
}

# --- Verify every expected DLL exists -----------------------------------------
foreach ($Profile in @('v3', 'v2'))
{
    foreach ($Variant in $Variants)
    {
        $dll = Join-Path $Root "build/release-$Profile/$Variant/$DLLName"
        if (-not (Test-Path $dll)) { throw "Missing build output: $dll" }
    }
}

# --- Stage ---------------------------------------------------------------------
$DistRoot = Join-Path $Root 'dist'
$Stage = Join-Path $DistRoot "SaveLoadAcceleratorForSKSECosaves-$Version"
$Zip = Join-Path $DistRoot "Save & Load Accelerator For SKSE Cosaves $Version.zip"
$SHAFile = Join-Path $DistRoot "Save & Load Accelerator For SKSE Cosaves $Version-SHA256.txt"

Remove-Item $Stage -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item $Zip -Force -ErrorAction SilentlyContinue

foreach ($Variant in $Variants)
{
    $highEnd = New-Item (Join-Path $Stage "$Variant/DLLPlugins") -ItemType Directory -Force
    Copy-Item (Join-Path $Root "build/release-v3/$Variant/$DLLName") $highEnd
    Copy-Item (Join-Path $Root "mod/$ININame") $highEnd

    $universal = New-Item (Join-Path $Stage "Optional/Universal (x86-64-v2)/$Variant/DLLPlugins") -ItemType Directory -Force
    Copy-Item (Join-Path $Root "build/release-v2/$Variant/$DLLName") $universal
    Copy-Item (Join-Path $Root "mod/$ININame") $universal
}

Copy-Item (Join-Path $Root 'mod/fomod') (Join-Path $Stage 'fomod') -Recurse

foreach ($doc in @('README.md', 'changelog.md', 'documentation/description-for-nexus-mods.bbcode'))
{
    $src = Join-Path $Root $doc
    if (-not (Test-Path $src)) { throw "Missing release document: $doc" }
    if ($doc -like 'documentation/*')
    {
        New-Item (Join-Path $Stage 'documentation') -ItemType Directory -Force | Out-Null
    }
    Copy-Item $src (Join-Path $Stage $doc)
}

# --- Gates ---------------------------------------------------------------------
[xml]$moduleConfig = Get-Content (Join-Path $Stage 'fomod/ModuleConfig.xml') -Raw
$gameDependencies = @($moduleConfig.config.installSteps.installStep.optionalFileGroups.group.plugins.plugin.typeDescriptor.dependencyType.patterns.pattern.dependencies.gameDependency)
if ($gameDependencies.Count -ne 8) { throw "FOMOD should auto-detect all 8 game versions; found $($gameDependencies.Count) game dependencies" }

foreach ($Variant in $Variants)
{
    if (-not ($moduleConfig.SelectNodes("//folder[@source='$Variant']"))) { throw "FOMOD does not reference variant folder $Variant" }
    $dlls = @(Get-ChildItem (Join-Path $Stage "$Variant/DLLPlugins") -Filter '*.dll' -File)
    if ($dlls.Count -ne 1 -or $dlls[0].Name -ne $DLLName) { throw "Variant $Variant must contain exactly $DLLName" }
    if (-not (Test-Path (Join-Path $Stage "$Variant/DLLPlugins/$ININame"))) { throw "Variant $Variant is missing its INI" }
}

$forbidden = Get-ChildItem $Stage -Recurse -File | Where-Object {
    $_.Extension -in @('.pdb', '.lib', '.exp', '.ilk', '.obj', '.iobj', '.ipdb')
}
if ($forbidden) { throw "Forbidden build artifacts in public stage: $($forbidden.FullName -join ', ')" }

# --- Archive -------------------------------------------------------------------
Compress-Archive -Path (Join-Path $Stage '*') -DestinationPath $Zip -CompressionLevel Optimal
$hash = (Get-FileHash $Zip -Algorithm SHA256).Hash.ToLowerInvariant()
"$hash  $(Split-Path $Zip -Leaf)" | Set-Content $SHAFile -Encoding ASCII

Write-Host "RELEASE PACKAGE OK"
Write-Host "ZIP: $Zip"
Write-Host "SHA256: $hash"
