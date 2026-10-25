---
title: "Before the assembler existed: bringing up a DSP with Excel"
published: false
cover_image: https://raw.githubusercontent.com/kg7hf/simple-spreadsheet-assembler/main/images/spreadsheet-assembler-cover.png
description: "From DSP bring-up with Excel to a native Windows executable built with LibreOffice Calc."
tags: assembly, programming, tutorial, windows
---

Here is a story from DSP bring-up in the early 2000s.

I used Excel when I was bringing up new digital signal processors that had their own instruction sets. The tools were still being developed. We did not want or need a full assembler for those first tests. We needed enough to do a few things: loop, jump, and toggle I/O pins controlled by memory-mapped registers.

We were writing the debugger. The team down the hall was writing the assembler and disassemblers. In the building across town, another team was writing the Verilog for the DSP ASICs.

The spreadsheet calculated instruction words from the fields in the instruction set. That let us prepare the small bring-up programs while the assembler was still being developed.

## A spreadsheet assembler for the PC

I wanted to turn that experience into an exercise for engineers starting out today. I also wanted to revisit the executable format. I did a lot of x86 work roughly 30 years ago, and I needed a refresher on some of those details.

I built this example with LibreOffice Calc. It produces a native Windows x86 executable. The workbook uses fixed instruction templates and an editable operand. It does not parse arbitrary assembly source or resolve labels.

This version uses CSV and a simple script to convert hex values into bytes. That is close to what I remember doing during the DSP work. The original export may have used commas or spaces between values; the process was the same. This example uses x86 instructions in place of the original DSP instruction set.

## Set the exit code

The program calls Windows' `ExitProcess` function with the value entered in cell B4. For an input of 42, Calc produces these bytes for `PUSH 42`:

```text
68 2A 00 00 00
```

`68` selects the instruction form. The following four bytes contain 42 in little-endian order.

![Calc Assembler sheet with B4 set to 42 and the decimal and hexadecimal instruction bytes](https://raw.githubusercontent.com/kg7hf/simple-spreadsheet-assembler/f3361d84f32964f3dbaea858b97785bdbd22ff62/images/lesson1-img1.png)

*The Assembler sheet. B4 contains 42; the first instruction encodes as 68 2A 00 00 00. The capture was taken after Save As CSV, so the title reads image.csv. Use assembler.ods for further edits.*

The next instruction calls `ExitProcess` through the import address table. The program prints nothing. PowerShell reports its exit code.

## What the Image sheet contains

The Image sheet contains the complete sequence of bytes written to the executable file. Each data row represents one byte. The instruction bytes link to the calculations on the Assembler sheet. The Windows headers and import records come from a fixed template.

This template has 12 bytes of code in a 1,536-byte file. Headers, import records, and section padding account for the remaining space.

![Calc Image sheet showing the instruction bytes at file offsets 512 through 523](https://raw.githubusercontent.com/kg7hf/simple-spreadsheet-assembler/f3361d84f32964f3dbaea858b97785bdbd22ff62/images/lesson1-img2.png)

*The code starts at worksheet row 514, file offset 512. Column B is decimal; column C is hex. At row 515, the adjacent values 42 and 2A represent the same byte.*

## What PE headers do

**PE means Portable Executable.** Its headers describe the target processor, entry point, section layout, and imported functions. Windows uses this information to load the program. The headers do not switch the CPU into protected mode.

The file starts with an `MZ` header containing a pointer to the `PE` signature. The section table connects file offsets to relative virtual addresses. The import records identify functions such as `ExitProcess`. Microsoft's [PE format reference](https://learn.microsoft.com/en-us/windows/win32/debug/pe-format) documents the structures.

In this template, the first instruction is at file offset `0x200`. Its relative virtual address is `0x1000`. With the fixed image base of `0x00400000`, execution starts at virtual address `0x00401000`.

The file offset and loaded address are different. The headers describe that mapping. Renaming raw instruction bytes to `.exe` would not supply it.

## Export and run it manually

The first lesson covers each step:

1. Open the ODS workbook and set the exit-code input.
2. Inspect the formulas and calculated instruction bytes.
3. Save the workbook, then export the Image sheet as UTF-8 CSV.
4. Run `hex-to-exe.ps1` to convert the exported hex values into bytes.
5. Run the executable and check `$LASTEXITCODE`.

Calc performs the instruction encoding. The converter checks the CSV rows and writes the bytes. The text `2A` becomes one byte with value `0x2A`.

The transcripts use `C:\work\simple-spreadsheet-assembler` as the example folder. Paths are shortened for readability; `export-<id>` represents the build's unique export directory.

```text
PS C:\work\simple-spreadsheet-assembler> .\hex-to-exe.ps1 -Csv .\image.csv -Output .\program.exe
Wrote 1536 bytes to C:\work\simple-spreadsheet-assembler\program.exe
PS C:\work\simple-spreadsheet-assembler> .\program.exe
PS C:\work\simple-spreadsheet-assembler> $LASTEXITCODE
42
```

*Manual conversion and execution on Windows. The converter writes program.exe. The next command runs it. $LASTEXITCODE reports 42.*

[Lesson one: assemble a Windows program with LibreOffice Calc](https://github.com/kg7hf/simple-spreadsheet-assembler/blob/main/LESSON-1.md) walks through the workbook, export options, and executable layout.

## Automate the export and conversion

The second lesson introduces `build.ps1`. It loads the saved workbook in headless LibreOffice, recalculates the formulas, exports Image, and invokes the same converter.

The executable is still run separately. In the run below, the saved workbook input was 7. The resulting program returned 7.

```text
PS C:\work\simple-spreadsheet-assembler> .\build.ps1
convert C:\work\simple-spreadsheet-assembler\assembler.ods as a Calc document using filter : Text - txt - csv (StarCalc):44,34,76,1,,0,false,true,false,false,false,2
Writing sheet Image -> C:\work\simple-spreadsheet-assembler\artifacts\export-<id>\assembler-Image.csv
Wrote 1536 bytes to C:\work\simple-spreadsheet-assembler\program.exe
PS C:\work\simple-spreadsheet-assembler> .\program.exe
PS C:\work\simple-spreadsheet-assembler> $LASTEXITCODE
7
```

*Automated build with an input of 7. The CSV remains available under artifacts. The final commands run the executable and read its exit code.*

[Lesson two: automate the build with PowerShell](https://github.com/kg7hf/simple-spreadsheet-assembler/blob/main/LESSON-2.md) explains the script and its intermediate files.

## Start with the instructions needed for the test

During DSP bring-up, the immediate goal was to exercise the hardware. A few instruction encodings were enough to start. The rest of the tooling could follow as it was needed.

This example follows that approach. Change an operand, inspect the bytes, and check the result on Windows. The workbook and CSV leave the intermediate values available for inspection.

The source and both lessons are in [Simple Spreadsheet Assembler on GitHub](https://github.com/kg7hf/simple-spreadsheet-assembler).

Questions about the instruction encoding, file format, or export steps are welcome.
