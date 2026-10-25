# Before the assembler existed: bringing up a DSP with Excel

In the early 2000s, I used Microsoft Excel as an assembler while bringing up new digital signal processors.

These processors had their own instruction sets, and we were working before an assembler or compiler port was available. We did not need a complete development environment to begin. We needed enough instructions to do a few specific things: loop, jump, and toggle I/O pins through memory-mapped registers.

We were also writing the supporting software. There was no existing bootloader or memory-dump tool to assume would handle the difficult parts for us.

A spreadsheet was useful because the immediate problem was small and concrete. Take the instruction format, put the required values into the right fields, and produce the bit patterns the processor would execute.

We were trying to get hardware running. Excel was one of the tools that helped us do it.

## Why revisit this now?

I think this makes a useful exercise for engineers starting out today.

Modern development tools do a tremendous amount of work for us. That is valuable, but it can also put several layers between a line of source code and the bytes a processor actually executes.

A spreadsheet makes that relationship visible. You can change a number, inspect the formula, and watch the corresponding instruction bytes change. There is very little room for mystery.

I also wanted to revisit it for myself. I did a lot of x86 work roughly 30 years ago, and some of the executable-file details deserved a refresher.

So I have put together a small teaching project using **LibreOffice Calc**, with a native Windows x86 program as the result.

It is a modern demonstration of the technique, not a reconstruction of the original DSP or its instruction set. I also no longer remember the exact export procedure we used back then. This example makes that step explicit.

## The first program exits with 42

The starting point is deliberately modest: a program that calls Windows' `ExitProcess` function with a number we choose.

The workbook contains a few fixed instruction templates. In the first lesson, we change the operand to 42, and Calc produces these bytes for `PUSH 42`:

```text
68 2A 00 00 00
```

`68` selects the instruction form. The following four bytes contain the number 42 in little-endian order.

The program then calls `ExitProcess` through its import address table. It prints nothing. We run it from PowerShell and inspect the result:

```powershell
.\program.exe
$LASTEXITCODE
```

PowerShell displays:

```text
42
```

Change the spreadsheet input to 9, repeat the export and conversion, and the program returns 9 instead. We tested that on Windows, along with other input values.

It is a small result, but it demonstrates the entire path from a spreadsheet cell to executing machine code.

## What is the “Image” sheet?

Here, *image* means the complete sequence of bytes we will write to the executable file. Each data row in the Image sheet represents one output byte. It is not a screenshot, and it is more than the instruction stream.

Our example has 12 bytes of code, but the complete file is 1,536 bytes:

- 512 bytes for headers and padding.
- 512 bytes for the code section and its padding.
- 512 bytes for import records and their padding.

Those sizes belong to this particular teaching template. The instruction bytes are linked to the calculations on the Assembler sheet. The surrounding executable structure is supplied as a fixed template.

## Why does Windows need PE headers?

**PE means Portable Executable.** The headers describe the target processor, entry point, section layout, and imported functions. They give the Windows loader the information needed to arrange the program in memory. They do not switch the CPU into protected mode.

The file starts with an `MZ` header containing a pointer to the `PE` signature. A section table connects file offsets to relative virtual addresses. Imports let Windows resolve functions such as `ExitProcess`. Microsoft's [PE format reference](https://learn.microsoft.com/en-us/windows/win32/debug/pe-format) documents these structures.

In our specific example, the first instruction is at file offset `0x200`, but its relative virtual address is `0x1000`. With the template's image base of `0x00400000`, execution starts at virtual address `0x00401000`.

That distinction helped me: the position of a byte in the file is not necessarily its address when loaded into memory.

The familiar x86 instruction bytes are still there. We have also supplied the information Windows needs to load and start them. Renaming raw instruction bytes to `.exe` would not supply that information.

## First do the steps manually

The first lesson walks through the full process:

1. Open the ODS workbook in Calc and change the exit-code input.
2. Inspect the instruction formulas and calculated bytes.
3. Save the workbook, then manually export the Image sheet as UTF-8 CSV.
4. Run a small PowerShell converter to write those hex values as actual bytes.
5. Run the executable and check its exit code.

The converter is deliberately separate. Calc performs the instruction encoding; the converter checks the exported rows and writes the byte values to disk.

Saving the text `2A` is not the same as writing the single byte `0x2A`. Making that boundary explicit is part of the exercise.

[Read lesson one: assemble a Windows program with LibreOffice Calc](https://github.com/kg7hf/simple-spreadsheet-assembler/blob/main/LESSON-1.md).

## Then automate the steps we understand

The second lesson introduces `build.ps1`. After we edit and save the workbook, the script opens it in headless LibreOffice, recalculates the formulas, exports the Image sheet, and invokes the same converter.

We still run the generated program ourselves and check its exit code.

That order matters to me. First understand the files and transformations. Then automate the repetitive work without losing sight of what it does.

[Read lesson two: automate the build with PowerShell](https://github.com/kg7hf/simple-spreadsheet-assembler/blob/main/LESSON-2.md).

## Enough tooling to take the next step

This is not a general-purpose x86 assembler. It does not parse arbitrary mnemonics or resolve labels. It begins with fixed instruction templates, visible formulas, and one editable operand.

That limited scope is intentional. During the original DSP bring-up work, we needed enough capability to perform the next hardware experiment. We did not have to finish an entire toolchain before learning something useful about the processor.

The same principle makes a good teaching exercise: choose a small result, make each transformation inspectable, and verify that the hardware does what the bytes say.

The workbook, scripts, and both lessons are available here:

[Simple Spreadsheet Assembler on GitHub](https://github.com/kg7hf/simple-spreadsheet-assembler).

What was the smallest or most unexpected tool you used to get a new piece of hardware running?
