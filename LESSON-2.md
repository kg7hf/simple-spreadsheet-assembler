# Lesson 2: automate the build with PowerShell

In [lesson one](LESSON-1.md), we performed every step ourselves: edit a value in Calc, recalculate, save the Image sheet as CSV, convert its hex values to bytes, and run the resulting executable.

Now we will automate the repeated export and conversion work with **build.ps1**. The spreadsheet still assembles the instructions. The script coordinates the tools we already used.

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

There is still a CSV file between the spreadsheet and the executable. Automation changes who performs the steps, not the file formats or instruction encoding.

## 2. Edit and save the source workbook

Open **assembler.ods** in Calc. If you still have **image.csv** open from lesson one, reopen the ODS file first. The CSV is an exported snapshot, not the source workbook.

Select **Assembler**, enter **42** in **B4**, and press **Enter**. Save the workbook with **Ctrl+S**. You can use **Ctrl+Shift+F9** to inspect the recalculated values in the visible workbook, but the build will also recalculate its own loaded copy.

**Saving is essential.** The script reads the workbook from disk. It cannot see an edit that exists only in your open Calc window.

You do not need to select Image or manually save a CSV this time. Keep the worksheet order unchanged: the script expects Image to be the second sheet.

## 3. Build the executable

Open PowerShell in the project folder:

```powershell
cd D:\source\repos\misc-projects\simple-excel-assembler
```

Run:

```powershell
.\build.ps1
```

LibreOffice will load the saved workbook in **headless mode**, meaning it performs the conversion without opening an editing window for this build. Your existing Calc window can remain open.

The output should mention a CSV export of the Image sheet, followed by a message like:

```text
Wrote 1536 bytes to D:\source\repos\misc-projects\simple-excel-assembler\program.exe
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
42
```

The executable itself prints nothing. PowerShell displays its exit code when you evaluate `$LASTEXITCODE`.

Now change **B4** to **9** in Calc, press Enter, and save. Repeat the three commands:

```powershell
.\build.ps1
.\program.exe
$LASTEXITCODE
```

You should see **9**. You have repeated the experiment from lesson one without visiting the CSV export dialog or invoking the converter yourself.

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

This matters because spreadsheets can store previously calculated formula results. We encountered that during development: changing an input in a file without recalculating its formulas can leave old results behind. The build explicitly requests recalculation before exporting.

The profile and exported CSV remain in the build folder so we can inspect what happened.

### Load, recalculate, and export

The long command starting with `& $calc` launches LibreOffice. Its important pieces are:

| Argument | Purpose |
|---|---|
| `-env:UserInstallation=...` | Use this build's separate profile |
| `--headless` | Perform the operation without an editing window |
| `--convert-to ...` | Export using the configured CSV filter |
| `--outdir ...` | Put the CSV in this build's export folder |
| The final source path | Load the saved workbook |

The CSV filter options select comma-separated UTF-8 text, calculated values rather than formula text, and sheet 2. These are the choices we made manually in lesson one. We can leave that option string alone for this exercise.

### Check the export and call the converter

Immediately after LibreOffice runs, the script checks:

```powershell
if ($LASTEXITCODE -ne 0) { throw 'Calc export failed.' }
```

**This checks LibreOffice's exit code.** Our generated program has not run yet. A successful LibreOffice export normally returns zero; the value 42 belongs to the program we run later.

The script also requires exactly one CSV in the new export folder. Then it invokes:

```powershell
& "$PSScriptRoot\hex-to-exe.ps1" -Csv $csv[0].FullName -Output $Output
```

This is the converter from lesson one. It checks the byte rows and writes them into the executable. It does not interpret assembly mnemonics or create the Windows headers. Those bytes still come from the workbook.

That call is the end of the build script. There is no command in it to run `program.exe`.

## 6. Inspect the intermediate CSV

Automation has not hidden the intermediate result. Read the export path printed during the build, or list the recent export folders:

```powershell
Get-ChildItem .\artifacts -Directory -Filter 'export-*' |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 3 Name, LastWriteTime
```

Inside the folder for the successful build, look for **assembler-Image.csv**. You can open it in a text editor and find the record with offset **513**, just as in lesson one.

For an input of 9, that record should contain decimal `9` and hex `09`. For 42, it should contain `42` and `2A`.

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

Our workflow is now **edit, save, build, run, inspect**. We have automated the steps we already understand while retaining the spreadsheet and CSV as places to examine the actual machine-code bytes.

## Related files

- [Lesson 1](LESSON-1.md): perform the export and conversion manually.
- [build.ps1](build.ps1): coordinate LibreOffice and the converter.
- [hex-to-exe.ps1](hex-to-exe.ps1): validate the CSV and write the bytes.
- [LibreOffice CSV filter parameters](https://help.libreoffice.org/latest/en-US/text/shared/guide/csv_params.html): reference for the export option string.
