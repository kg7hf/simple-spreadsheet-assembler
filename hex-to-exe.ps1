param([Parameter(Mandatory)][string]$Csv, [Parameter(Mandatory)][string]$Output,
      [ValidateRange(512,1048576)][int]$ExpectedBytes = 1536)
$ErrorActionPreference = 'Stop'
$rows = @(Import-Csv -LiteralPath $Csv)
if ($rows.Count -ne $ExpectedBytes) { throw "Expected $ExpectedBytes byte rows for the selected PE32 layout." }
$bytes = New-Object byte[] $rows.Count
for ($i=0; $i -lt $rows.Count; $i++) {
    $row = $rows[$i]
    if ($row.Offset -cne [string]$i -or $row.Hex -notmatch '^[0-9A-Fa-f]{2}$') {
        throw "Invalid offset or hex byte at row $($i+2). No executable written."
    }
    $bytes[$i] = [Convert]::ToByte($row.Hex,16)
    if ($row.Byte -cne [string]$bytes[$i]) { throw "Decimal/hex mismatch at offset $i." }
}
if ($bytes[0] -ne 77 -or $bytes[1] -ne 90) { throw 'Missing MZ header.' }
# PowerShell's current location can differ from the process working directory.
# Resolve relative paths the same way as .\program.exe at the prompt.
$outputPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Output)
[IO.File]::WriteAllBytes($outputPath,$bytes)
Write-Output "Wrote $($bytes.Length) bytes to $outputPath"
