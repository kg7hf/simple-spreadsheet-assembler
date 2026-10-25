# Lesson 2: automate the build with PowerShell

[Lesson one](LESSON-1.md) covered the manual workflow: edit a value in Calc, recalculate, save Image as CSV, convert the hex values to bytes, and run the executable.

**build.ps1** automates the recalculation, export, and conversion. Calc still encodes the instructions. The script runs LibreOffice and the same converter used in lesson one.

## 1. Map the manual steps to the automated build

| Step from lesson one | What happens in lesson two |
|---|---|
| Edit Assembler.B4 | You still do this in Calc |
| Save the ODS workbook | You still do this in Calc |
| Recalculate the saved workbook | The script asks LibreOffice to do this |
| Select Image and export CSV | The script exports sheet 2, which is Image |
| Run hex-to-exe.ps1 | The script calls the same converter |
| Run program.exe | You still run it explicitly |
| Inspect the exit code | You still read `$LASTEXITCODE` |

There is still a CSV file between the spreadsheet and the executable. The script performs the same export and conversion steps.

## 2. Edit and save the source workbook

Open **assembler.ods** in Calc. If you still have **image.csv** open from lesson one, reopen the ODS file first. The CSV is an exported snapshot, not the source workbook.

Select **Assembler**, enter **7** in **B4**, and press **Enter**. Save the workbook with **Ctrl+S**. You can use **Ctrl+Shift+F9** to inspect the recalculated values in the visible workbook, but the build will also recalculate its own loaded copy.

Save before building. The script reads the workbook from disk, so unsaved edits are not included.

You do not need to select Image or manually save a CSV this time. Keep the worksheet order unchanged: the script expects Image to be the second sheet.

## 3. Build the executable

Open PowerShell in your project folder. These examples use `C:\work\simple-spreadsheet-assembler`; substitute your own path. In the transcript, `export-<id>` abbreviates the unique export directory created by the build.

Run:

```powershell
.\build.ps1
```

LibreOffice will load the saved workbook in **headless mode**, meaning it performs the conversion without opening an editing window for this build. Your existing Calc window can remain open.

The output should mention a CSV export of the Image sheet, followed by a message like:

```text
Wrote 1536 bytes to C:\work\simple-spreadsheet-assembler\program.exe
```

The export directory name changes with each build. The default executable destination stays the same.

If the build reports an error, fix it before running the executable. An unsuccessful build may leave the previous `program.exe` in place; its presence alone does not prove the new build succeeded.

## 4. Run the program and read its exit code

After the build succeeds, run:

```powershell
.\program.exe
$LASTEXITCODE
```

The expected result is:

```text
7
```

The executable prints nothing. PowerShell displays its exit code when you evaluate `$LASTEXITCODE`.

```text
PS C:\work\simple-spreadsheet-assembler> .\build.ps1
convert C:\work\simple-spreadsheet-assembler\assembler.ods as a Calc document using filter : Text - txt - csv (StarCalc):44,34,76,1,,0,false,true,false,false,false,2
Writing sheet Image -> C:\work\simple-spreadsheet-assembler\artifacts\export-<id>\assembler-Image.csv
Wrote 1536 bytes to C:\work\simple-spreadsheet-assembler\program.exe
PS C:\work\simple-spreadsheet-assembler> .\program.exe
PS C:\work\simple-spreadsheet-assembler> $LASTEXITCODE
7
```

*This run used a saved workbook input of 7. build.ps1 exported Image and invoked the converter. The next commands ran program.exe and read its exit code. Lesson one used 42; the different result here reflects the changed input.*

Now change **B4** to **9** in Calc, press Enter, and save. Repeat the three commands:

```powershell
.\build.ps1
.\program.exe
$LASTEXITCODE
```

The next run should return **9**. The build script handled CSV export and conversion.

## 5. Read the build script

The script is short enough to follow in order. Open **build.ps1** in a text editor and identify these parts.

### Default input and output

The first line declares the workbook and executable paths:

```powershell
param([string]$Workbook = "$PSScriptRoot\assembler.ods", [string]$Output = "$PSScriptRoot\program.exe")
```

`$PSScriptRoot` is the folder containing the script. The defaults therefore refer to the files beside `build.ps1`.

The script then locates LibreOffice at its configured installation path:

```powershell
$calc = 'C:\Program Files\LibreOffice\program\soffice.com'
```

If LibreOffice is installed somewhere else, this path needs to match that installation. This is a dependency on LibreOffice, not on Microsoft Excel.

### A separate folder and profile for each build

Each invocation creates an `artifacts\export-...` folder with a unique identifier. This prevents a previous CSV from being mistaken for the current export.

Inside it, the script creates a separate LibreOffice **user profile**. That profile contains settings for this conversion process, including **Always Recalculate** for ODS and XLSX input. It does not change the settings of your normal LibreOffice profile.

Spreadsheets can store previously calculated formula results. During development, I found that changing an input in a file without recalculating left old results behind. The build requests recalculation before exporting.

The profile and exported CSV remain in the build folder for inspection.

### Load, recalculate, and export

The long command starting with `& $calc` launches LibreOffice. Its important pieces are:

| Argument | Purpose |
|---|---|
| `-env:UserInstallation=...` | Use this build's separate profile |
| `--headless` | Perform the operation without an editing window |
| `--convert-to ...` | Export using the configured CSV filter |
| `--outdir ...` | Put the CSV in this build's export folder |
| The final source path | Load the saved workbook |

The CSV filter options select comma-separated UTF-8 text, calculated values rather than formula text, and sheet 2. These match the manual export settings in lesson one. Leave the option string unchanged for this exercise.

### Check the export and call the converter

Immediately after LibreOffice runs, the script checks:

```powershell
if ($LASTEXITCODE -ne 0) { throw 'Calc export failed.' }
```

**This checks LibreOffice's exit code.** The generated program has not run yet. A successful LibreOffice export normally returns zero. The value 7 in the transcript comes from running program.exe afterward.

The script also requires exactly one CSV in the new export folder. Then it invokes:

```powershell
& "$PSScriptRoot\hex-to-exe.ps1" -Csv $csv[0].FullName -Output $Output
```

This is the converter from lesson one. It checks the byte rows and writes them into the executable. It does not interpret assembly mnemonics or create the Windows headers. Those bytes still come from the workbook.

That call is the end of the build script. There is no command in it to run `program.exe`.

## 6. Inspect the intermediate CSV

Read the CSV path printed during the build, or list recent export folders:

```powershell
Get-ChildItem .\artifacts -Directory -Filter 'export-*' |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 3 Name, LastWriteTime
```

Inside the folder for the successful build, look for **assembler-Image.csv**. You can open it in a text editor and find the record with offset **513**, just as in lesson one.

For the first input of 7, that record should contain decimal `7` and hex `07`. After changing the input to 9, it should contain `9` and `09`.

The root-level **image.csv** from the manual lesson is not used by this build. Editing or inspecting that old file will not tell you what the latest automated build exported.

## 7. Choose another output filename

The parameters let you preserve one executable while building another:

```powershell
.\build.ps1 -Workbook .\assembler.ods -Output .\experiment.exe
.\experiment.exe
$LASTEXITCODE
```

Run the output you actually requested. If you build `experiment.exe` and then run `program.exe`, you may be running the result of an earlier experiment.

With the same workbook input and template, the manual and automated workflows produce the same executable bytes. To compare retained outputs from the two workflows, you can use PowerShell's `Get-FileHash`. Both builds must use the same input value for that comparison to be meaningful.

## Troubleshooting the automated workflow

| Symptom | What to check |
|---|---|
| The program returns the previous value | Did you press Enter and save **assembler.ods** after changing B4? |
| The old image.csv has not changed | Expected: the automated build exports a new CSV under `artifacts`, not the manual lesson's file |
| LibreOffice cannot be found | Check the `$calc` installation path in the script |
| CSV row or column validation fails | Confirm Image is still sheet 2 and the workbook structure has not changed |
| Formula errors stop conversion | Check B4 is a whole number from 0 to 255 |
| A successful build seems to return zero | Run the generated executable before reading `$LASTEXITCODE`; the build's export check concerns LibreOffice |
| An output filename was customized | Run that filename, and check the converter's full destination path |

The build script removes the manual export steps. The spreadsheet and each generated CSV remain available to inspect when a result differs from the expected value.

## Related files

- [Lesson 1](LESSON-1.md): perform the export and conversion manually.
- [build.ps1](build.ps1): coordinate LibreOffice and the converter.
- [hex-to-exe.ps1](hex-to-exe.ps1): validate the CSV and write the bytes.
- [LibreOffice CSV filter parameters](https://help.libreoffice.org/latest/en-US/text/shared/guide/csv_params.html): reference for the export option string.
