param([string]$Workbook = "$PSScriptRoot\assembler.ods", [string]$Output = "$PSScriptRoot\program.exe")
$ErrorActionPreference = 'Stop'
$calc = 'C:\Program Files\LibreOffice\program\soffice.com'
if (!(Test-Path -LiteralPath $calc)) { throw 'LibreOffice is required at C:\Program Files\LibreOffice.' }
$source = (Resolve-Path -LiteralPath $Workbook).Path
$run = Join-Path $PSScriptRoot ('artifacts\export-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $run -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $run 'profile\user') -Force | Out-Null
@'
<?xml version="1.0" encoding="UTF-8"?>
<oor:items xmlns:oor="http://openoffice.org/2001/registry">
<item oor:path="/org.openoffice.Office.Calc/Formula/Load"><prop oor:name="ODFRecalcMode" oor:op="fuse"><value>0</value></prop><prop oor:name="OOXMLRecalcMode" oor:op="fuse"><value>0</value></prop></item>
</oor:items>
'@ | Set-Content -LiteralPath (Join-Path $run 'profile\user\registrymodifications.xcu') -Encoding utf8
$profile = ([uri](Join-Path $run 'profile')).AbsoluteUri
# Sheet 2 is Image. Export calculated values, never formula text.
& $calc "-env:UserInstallation=$profile" --headless --convert-to 'csv:Text - txt - csv (StarCalc):44,34,76,1,,0,false,true,false,false,false,2' --outdir $run $source
if ($LASTEXITCODE -ne 0) { throw 'Calc export failed.' }
$csv = @(Get-ChildItem -LiteralPath $run -Filter '*.csv')
if ($csv.Count -ne 1) { throw 'Expected exactly one Image CSV export.' }
& "$PSScriptRoot\hex-to-exe.ps1" -Csv $csv[0].FullName -Output $Output
