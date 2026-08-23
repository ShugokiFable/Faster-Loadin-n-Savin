# Build wrapper: VS dev shell + LDC on PATH, then both CPU profiles.
$ErrorActionPreference = 'Stop'
Import-Module "C:\Program Files\Microsoft Visual Studio\18\Community\Common7\Tools\Microsoft.VisualStudio.DevShell.dll"
Enter-VSDevShell -VsInstallPath "C:\Program Files\Microsoft Visual Studio\18\Community" -SkipAutomaticLocation -DevCmdArguments '-arch=x64 -host_arch=x64'
$env:PATH = "$env:LOCALAPPDATA\Programs\ldc2\ldc2-1.42.0-windows-x64\bin;$env:PATH"
Set-Location $PSScriptRoot
$V = (Get-Content "$PSScriptRoot\VERSION.txt" -Raw).Trim()
& "scripts\update-version-number.ps1" $V
foreach ($CPU in @('x86-64-v2', 'x86-64-v3')) {
    & .\build.ps1 -TargetCPU $CPU -BuildTag "-v$($CPU.Substring($CPU.Length-1))"
    if ($LASTEXITCODE -ne 0) { throw "build failed ($CPU): $LASTEXITCODE" }
}
Write-Host "ALL BUILDS OK"
