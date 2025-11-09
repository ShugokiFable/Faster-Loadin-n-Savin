
<# SPDX-LICENSE-IDENTIFIER: 0BSD #>

[CmdletBinding()]
Param
(
	[Parameter()]
		[ValidateNotNull()]
			$Configuration = 'Release'
)

. "$PSScriptRoot/common.ps1"

$Source = "$PSScriptRoot/mod"
$BuildPath = "$PSScriptRoot/build/$Configuration"
$PackagePath = "$PSScriptRoot/package/$Configuration"

New-Item -ItemType Directory -Force -Path $PackagePath > $Null

Push-Location -LiteralPath $PackagePath

try
{
	$INIFilePath = "$Source/Save&LoadAcceleratorForSKSECosaves.ini"

	$Variants = @('ae', 'ae640', 'se', 'vr', 'gog', 'gog659')

	ForEach-InParallel $Variants `
	{
		if (-not $IsSerial)
		{
			$Configuration = $Using:Configuration
			$BuildPath = $Using:BuildPath
			$INIFilePath = $Using:INIFilePath
		}

		$Variant = $_

		$BuildVariant = "$BuildPath/$Variant"
		$ModPath = "$Variant/Save & Load Accelerator For SKSE Cosaves"
		$DLLPluginsPath = "$ModPath/DLLPlugins"

		New-Item -ItemType Directory -Force -Path $DLLPluginsPath > $Null

		Push-Location -LiteralPath $ModPath

		try
		{
			Copy-Item -Force -LiteralPath "$BuildVariant/Save&LoadAcceleratorForSKSECosaves.dll" -Destination DLLPlugins
			Copy-Item -Force -LiteralPath "$BuildVariant/Save&LoadAcceleratorForSKSECosaves.pdb" -Destination DLLPlugins
			Copy-Item -Force -LiteralPath $INIFilePath -Destination DLLPlugins

			$ZipFilePath = "../../Save & Load Accelerator For SKSE Cosaves ($($Variant.ToUpperInvariant() -replace '([a-z])([0-9])', '$1 $2'))$(if ($Configuration -ne 'Release') {" ($Configuration)"}).zip"

			Remove-Item -Force -LiteralPath $ZipFilePath -ErrorAction Ignore
			7za u -sse -mx9 $ZipFilePath * > $Null

			Get-Item -LiteralPath $ZipFilePath
		}
		finally
		{
			Pop-Location
		}
	}
}
finally
{
	Pop-Location
}

