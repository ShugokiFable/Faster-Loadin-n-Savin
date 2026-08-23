[CmdletBinding()]
Param (
    [Parameter(Mandatory, Position = 0)]
        [Version] $Version
)

$ErrorActionPreference = 'Stop'
$RootPath = Resolve-Path "$PSScriptRoot/.."

if ($Version.Build -lt 0) { throw 'Version must include major.minor.patch.' }
$Revision = if ($Version.Revision -lt 0) { 0 } else { $Version.Revision }
$AsSemantic = "$($Version.Major).$($Version.Minor).$($Version.Build)"
$AsRCLiteral = "$($Version.Major),$($Version.Minor),$($Version.Build),$Revision"
$AsRCString = "$($Version.Major).$($Version.Minor).$($Version.Build).$Revision"
$AsPackedUIntDLiteral = '{0:X02}_{1:X02}_{2:X03}_{3:X01}' -f $Version.Major, $Version.Minor, $Version.Build, $Revision
$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)

function Update-TextFile {
    Param([string]$Path, [scriptblock]$Transform)
    $FullPath = Join-Path $RootPath $Path
    $Text = [IO.File]::ReadAllText($FullPath)
    $Updated = & $Transform $Text
    [IO.File]::WriteAllText($FullPath, $Updated, $Utf8NoBom)
}

Update-TextFile 'mod/slack_common/user_interface.d' {
    Param($Text)
    [regex]::Replace($Text, 'Save & Load Accelerator for SKSE Cosaves v\d+\.\d+\.\d+', ('Save & Load Accelerator for SKSE Cosaves v' + $AsSemantic))
}

Update-TextFile 'mod/slack_mod/Save&LoadAcceleratorForSKSECosaves.rc' {
    Param($Text)
    $Text = [regex]::Replace($Text, '(?m)^(\s*(?:FILE|PRODUCT)VERSION\s+)\S+', "`${1}$AsRCLiteral")
    [regex]::Replace($Text, '(VALUE "(?:File|Product)Version", ")[^"]+', "`${1}$AsRCString\\0")
}

Update-TextFile 'mod/fomod/info.xml' {
    Param($Text)
    [regex]::Replace($Text, '<Version MachineVersion="[^"]+">[^<]+</Version>', ('<Version MachineVersion="' + $AsSemantic + '">' + $AsSemantic + '</Version>'))
}

# Upstream 1.3.3 stamps the packed version into entrypoint.d (SKSEPlugin_Version
# and GetReleaseVersion). The fork's 1.4.0-1.5.1 releases shipped 1.3.2 there.
Update-TextFile 'mod/slack_mod/entrypoint.d' {
    Param($Text)
    [regex]::Replace($Text, '(/\+release-version\+/0x)[0-9a-fA-F_]+', "`${1}$AsPackedUIntDLiteral")
}

Update-TextFile 'build.ps1' {
    Param($Text)
    [regex]::Replace($Text, "(<#release-version#>'v)[^']+", ('$1v' + $AsSemantic))
}

Write-Host "Updated source metadata to $AsRCString"
