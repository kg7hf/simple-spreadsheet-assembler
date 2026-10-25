# Simple Spreadsheet Assembler

An educational project that uses LibreOffice Calc to assemble a small native
Windows x86 program. The repository is
[simple-spreadsheet-assembler](https://github.com/kg7hf/simple-spreadsheet-assembler).
The lessons accompany an [article](ARTICLE.md) about the technique.

Start with [Lesson 1: assemble a Windows program with LibreOffice Calc](LESSON-1.md)
for the full spreadsheet walkthrough, manual CSV export, conversion, and exit-code experiment.
The commands below are a quick reference.

Open **assembler.ods** in Calc. The amber **Assembler.B4** cell is the exit code.
Start with 42. The supported input range for this lesson is whole numbers 0–255.

## Lesson 1: perform each step manually

1. Open **assembler.ods** in LibreOffice Calc and edit **Assembler.B4**.
2. Press **Ctrl+Shift+F9** to recalculate, then save the workbook as ODS to retain its formulas and both sheets.
3. Select the **Image** sheet. Use **File > Save As**, choose **Text CSV**, and save as **image.csv** in this folder. Choose to use the CSV format when prompted.
4. In the CSV export options, use **UTF-8**, a **comma** field delimiter, and a double quote text delimiter. Export calculated values, not formulas. Keep the header row. Only the selected Image sheet belongs in this CSV.
5. Convert the CSV to an executable, then run it from PowerShell:

```powershell
.\hex-to-exe.ps1 -Csv .\image.csv -Output .\program.exe
.\program.exe
$LASTEXITCODE
```

The expected result is `42`. To try `7`, reopen **assembler.ods**, change B4,
and repeat the manual CSV export and conversion. Edit the ODS workbook, not the CSV:
CSV stores values from one sheet and does not retain the assembler's formulas.
The executable prints no text; PowerShell displays its exit code.
If rebuilding reports an error, do not run the previous executable as if it were a new build.

## Lesson 2: automate the same steps

Read [Lesson 2: automate the build with PowerShell](LESSON-2.md) for the guided
walkthrough of the build script, its intermediate files, and its exit-code check.

After completing the manual workflow, use `build.ps1` to automate the Calc export
and hex-to-byte conversion. Open the ODS workbook, change B4, and save it, then run:

```powershell
.\build.ps1
.\program.exe
$LASTEXITCODE
```

The script opens the saved workbook in headless LibreOffice, recalculates it,
exports Image to CSV, and invokes the same `hex-to-exe.ps1` converter used in
lesson one. The resulting executable has the same bytes for the same input.
It does not run the executable; the last two commands remain explicit.
The automation uses a separate LibreOffice profile and retains CSV exports under
`artifacts/`. The spreadsheet still performs the instruction encoding.

## What Calc assembles

This first lesson uses fixed instruction templates, not a general mnemonic parser:

```asm
push 42                  ; 68 2A 00 00 00
call dword [0x00402030]   ; FF 15 30 20 40 00
int3                     ; CC, unreachable guard
```

Calc formulas split the operands into little-endian bytes. `ExitProcess` uses the
32-bit Windows calling convention: the exit code is passed on the stack.
Windows fills the import address table entry at 0x00402030 with the address of
KERNEL32.dll's ExitProcess. That function terminates the process and never returns.

The **Image** sheet contains the entire 1,536-byte PE32 executable: headers,
code and padding, and import records. Its code bytes link to the Assembler sheet.
Headers and import records are supplied as a fixed teaching template. The program
is 32-bit x86, running through Windows' 32-bit application support on this 64-bit PC.
It is a normal Windows executable, not a DOS program or an emulator payload.

## Export boundary

The user opens Calc and manually exports the Image sheet. PowerShell enters the
workflow only after that CSV exists.

`hex-to-exe.ps1` checks row count, sequential offsets, two-digit hex, and agreement
between decimal and hex byte columns, then writes the bytes verbatim. It does not
encode instructions or generate executable headers. No workbook macros, external
assembler, compiler, or linker are needed to rebuild.

`build.ps1` introduces automation in lesson two, after the reader has performed
and understood the individual steps in lesson one.

Changing a file's encoding or extension alone does not convert ASCII hex to those
byte values. This example uses an explicit, inspectable hex-to-byte conversion;
it does not reconstruct the historical early-2000s export method.

## Scope

Only B4 is intended for editing in this first lesson. Instruction labels are
descriptions, not parsed source. Layout, instruction count, imports and addresses
are fixed. The image has no relocations or ASLR, simplifying this initial example.
Changing instruction sizes or addresses requires updating the template too.

## Project layout

The root folder contains the files readers need:

- `assembler.ods`: the Calc workbook used in both lessons.
- `LESSON-1.md` and `LESSON-2.md`: the manual and automated workflows.
- `hex-to-exe.ps1`: the CSV-to-binary converter used in lesson one.
- `build.ps1`: the automation introduced in lesson two.

Local development tools live in `dev/`, including the workbook generator,
test-input generator, and validation notes. That folder is currently excluded from
version control. Readers do not need these tools or Node.js.
Generated exports and local verification evidence live in the Git-ignored `artifacts/`
folder. Generated executables, the manual `image.csv`, and dependency folders are also
ignored. The supplied workbook is versioned as the reader's starting point.

## References

- [Microsoft PE format](https://learn.microsoft.com/en-us/windows/win32/debug/pe-format)
- [Microsoft ExitProcess](https://learn.microsoft.com/en-us/windows/win32/api/processthreadsapi/nf-processthreadsapi-exitprocess)
- [LibreOffice CSV filter parameters](https://help.libreoffice.org/latest/en-US/text/shared/guide/csv_params.html)
