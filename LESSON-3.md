# Lesson 3: console input, arithmetic, and subroutines

[Lesson 1](LESSON-1.md) encoded a fixed instruction sequence and exported a Windows
executable. [Lesson 2](LESSON-2.md) automated the export and conversion. This lesson
uses a new workbook, [console-add.ods](console-add.ods), to assemble an interactive
console program with labels, branches, and subroutines.

The program reads two unsigned decimal numbers, adds them, and prints the result:

```text
Spreadsheet-assembled calculator

First number:  123
Second number: 456

123 + 456 = 579
```

The addition is one instruction. Most of the program reads characters, converts
them to integers, and converts the result back to characters for output.

The workbook contains the assembly source and its instruction encodings. Calc
calculates the offsets, resolves labels, and generates the bytes. Windows provides
the input and output functions. No external assembler, compiler, or linker is
required to build the supplied workbook.

## Build and run it

Use Windows with 32-bit x86 application support and LibreOffice installed at the
same location used in the earlier lessons. This example was developed for an x64
Windows PC. It is a PE32 console program.

1. Open **console-add.ods** in LibreOffice Calc.
2. Press **Ctrl+Shift+F9** to recalculate, then save the ODS workbook.
3. Open PowerShell in the repository folder and build it:

```powershell
.\build.ps1 -Workbook .\console-add.ods -Output .\console-add.exe -ExpectedBytes 3584
```

4. After a successful build, run the executable:

```powershell
.\console-add.exe
```

Enter `123`, press Enter, then enter `456` and press Enter. The result should be
`123 + 456 = 579`. After the program exits, inspect its status:

```powershell
$LASTEXITCODE
```

The expected exit code is `0`. The printed sum is program output; it is not the
process exit code.

Run it from PowerShell so the output remains visible after the executable exits.
If the build reports an error, correct it before running the executable. An older
executable may still exist from a previous successful build.

### Manual CSV export still works

The manual workflow from lesson one also applies. Save the ODS first, select
**Image**, then use **Save As** to export **console-add-image.csv** as Text CSV.
Choose UTF-8, a comma field delimiter, a double quote text delimiter, and calculated
values rather than formulas. Keep the header row.

```powershell
.\hex-to-exe.ps1 -Csv .\console-add-image.csv -Output .\console-add.exe -ExpectedBytes 3584
.\console-add.exe
```

Reopen the ODS for subsequent edits. CSV retains only one sheet's values.

The new `-ExpectedBytes` argument selects the expected image length. Both scripts
still default to 1,536 bytes for lessons one and two. They do not infer the size from
an arbitrary CSV, and the converter still checks every offset and byte before
writing the executable.

## Follow the workbook

The four sheets have distinct jobs:

| Sheet | What it contains |
| --- | --- |
| **Assembler** | Labeled instructions, operands, calculated offsets, resolved values, and emitted bytes. |
| **Image** | Every byte of the executable, ready for CSV export. It remains sheet two for `build.ps1`. |
| **Data** | Prompt strings, storage for numbers and handles, and addresses of imported functions. |
| **Opcodes** | The supported instruction forms and their fixed encoding bytes. |

On **Assembler**, source starts at row 9. Columns A through C are the editable
source. The remaining columns show the assembly calculation:

| Column | Meaning |
| --- | --- |
| A: Label | A name attached to the instruction on that row. Leave it empty when no label is needed. |
| B: Instruction form | An exact form selected from **Opcodes**, such as `CALL label`. |
| C: Operand | A decimal integer, a code label, or a data/import symbol, depending on the form. |
| D: Offset | Instruction position in the code section, starting at zero. |
| E: Length | Fixed byte count plus operand length. |
| F: Value / disp. | The immediate value, absolute address, or signed relative displacement. |
| G: Hex bytes | The instruction bytes in hexadecimal. |
| H through N | The same bytes as individual decimal values. |
| O: Explanation | Notes on the instruction or subroutine. |

The form names describe supported encodings. This workbook does not parse arbitrary
assembly text. For example, enter `MOV EDX,address` in column B and `prompt_first`
in column C. Together they represent:

```asm
mov edx, prompt_first
```

The `address` form loads the address of a symbol. Brackets mean a memory access:

```asm
mov eax, [first]       ; Load the integer stored at first.
mov [first], eax       ; Store EAX in first.
```

Use the exact spelling of the forms in **Opcodes**. Treat labels as case-insensitive
because Calc's lookups are case-insensitive. Each code label must be unique within
Assembler; each data/import symbol must be unique within Data.

### Fixed bytes and x86 instruction prefixes

On **Opcodes**, **Fixed byte 1** through **Fixed byte 6** hold the bytes that stay
the same for a supported instruction form. Calc copies those bytes, then appends
the immediate value, address, or relative displacement when the form needs one.

| Instruction form | Fixed bytes (hex) | What Calc appends |
| --- | --- | --- |
| `PUSH imm32` | `68` | Four-byte immediate value. |
| `CALL label` | `E8` | Four-byte relative displacement. |
| `CALL [import]` | `FF 15` | Four-byte absolute address of the imported function's pointer. |
| `RET` | `C3` | Nothing. |

These are not all *instruction prefixes* in the x86 sense. An x86 prefix is a
specific byte that modifies an instruction, such as `66` for an operand-size
override or `F3` for `REP` on string instructions. The fixed-byte columns can
contain opcodes, ModR/M bytes, and other bytes required by the selected form.
For `FF 15`, `FF` is the opcode and `15` is the ModR/M byte selecting an indirect
call through memory at an absolute address in this 32-bit encoding. Both are
fixed for this form; the address that follows depends on the selected symbol.

The six columns are storage slots for the workbook's encoding table. They do
not represent six categories of x86 prefixes, and a form only uses as many as
its **Fixed size** specifies.

## Labels and relative calls

Find the `CALL label` row whose operand is `write_string`. Calc looks up the row
with `write_string` in column A and retrieves its code offset from column D.

For a near relative call, the displacement is measured from the end of the calling
instruction:

```text
displacement = target offset - (current offset + instruction length)
```

The `CALL rel32` form has the opcode `E8` followed by a four-byte signed
displacement. Forward calls have a positive displacement. Backward calls and jumps
can have a negative displacement.

Calc uses `MOD(value,4294967296)` to express the 32-bit bit pattern as a nonnegative
number, then extracts the bytes in little-endian order. A displacement of `-5`,
for example, has the bit pattern `FFFFFFFB` and is stored as `FB FF FF FF`.

Instruction lengths come from **Opcodes**. Each offset is the preceding offset
plus the preceding length. All branches use fixed-length near forms; the workbook
does not choose between short and near branches. That avoids an iterative layout
problem where changing a branch length moves its own destination.

The internal `CALL label` instruction differs from `CALL [import]`. A call to
`write_string` uses a relative displacement. A call to `WriteFile` uses the absolute
address of an import address table slot. Windows fills that slot with the function's
address when it loads the executable.

## The main program

At `start`, the program obtains the standard input and output handles with
`GetStdHandle`. The constants are `-10` for standard input and `-11` for standard
output. It stores the handles in the Data section for later calls.

The important part of the main sequence is equivalent to this assembly:

```asm
mov edx, prompt_first
call read_number
mov [first], eax

mov edx, prompt_second
call read_number
mov [second], eax

; Other instructions print the operands and separators.
mov eax, [first]
calculate:
add eax, [second]
call print_number
```

The executable stores the first number before reading the second. It also stores
the second so both operands can be printed in the result. Find `calculate` in
column A to locate the addition.

## Subroutine arguments and registers

The internal routines use a small register convention:

| Routine | Input | Result |
| --- | --- | --- |
| `write_string` | EDX points to a NUL-terminated ASCII string. | Writes the string. |
| `read_number` | EDX points to a prompt string. | Returns the integer in EAX. |
| `print_number` | EAX contains an unsigned integer. | Writes its decimal representation. |

All three preserve EBX, ESI, EDI, and EBP. They may change EAX, ECX, EDX, and the
flags. A caller must not expect a value in one of those volatile registers to
survive a call.

`CALL` pushes the return address onto the stack. `RET` pops that address and
continues after the call. A routine that saves registers with `PUSH` restores them
with `POP` in reverse order before returning.

Windows' 32-bit API functions use a different argument convention: arguments go
on the stack, right to left, and the called function removes those arguments.
The program uses ordinary `RET` for its own register-argument routines.

## Write a string

`write_string` counts characters until it reaches a zero byte. That zero terminates
the string but is not sent to the console. It then calls `WriteFile`:

```asm
; EDX points to the text. ECX is its byte length.
push ecx              ; Save a private copy of the requested length.
push 0                ; lpOverlapped
push written          ; Address receiving the number of bytes written
push ecx              ; Number of bytes to write
push edx              ; Text buffer
push [stdout]         ; Output handle
call [WriteFile]
pop ecx               ; Recover our private copy, not a Windows argument.
```

The routine checks both the success value and the written byte count. An I/O
failure or short write exits with status `2`. These are small synchronous writes;
this example reports a short write rather than retrying the unwritten portion.

## Read and convert a number

`read_number` prints its prompt and repeatedly requests one byte with `ReadFile`.
With the console's default line-input mode, Windows handles keyboard editing and
waits for Enter. With redirected input, `ReadFile` reads the file or pipe instead.

The accumulator is EBX, the digit count is EDI, and EBP records whether the current
line is invalid. For each ASCII digit:

```text
digit = character - '0'
accumulator = accumulator * 10 + digit
```

The instructions that update the accumulator are:

```asm
sub eax, 48           ; ASCII '0' is 48.
imul ebx, ebx, 10
add ebx, eax
inc edi
```

The accepted input is one through nine decimal digits. Leading zeros are allowed
and count toward the nine-digit limit. The largest input is `999999999`, so the
largest sum is `1999999998`; neither the conversion nor the addition overflows a
32-bit register within that range.

The routine discards carriage-return bytes and uses line feed to end a line. That
accepts both Windows CRLF and LF line endings. A bare CR is not a line terminator
in redirected data. A valid final number can also end at EOF without a newline.

Empty lines, signs, spaces, decimal points, non-digits, and more than nine digits
are rejected. Once a line becomes invalid, the routine consumes the rest of it
before printing an error and repeating the prompt. The next read therefore starts
at a new line, rather than halfway through the rejected input.

EOF before two valid numbers are available exits with status `1`. A closed input
pipe can make `ReadFile` fail with `ERROR_BROKEN_PIPE` instead of returning zero
bytes. The program checks `GetLastError` and treats that condition as EOF. Other
read failures exit with status `2`.

## Convert the result back to decimal

`print_number` starts at the end of a 16-byte buffer and works backward. Each
division by ten gives a quotient and a remainder:

```text
579 / 10 = 57, remainder 9
 57 / 10 =  5, remainder 7
  5 / 10 =  0, remainder 5
```

Adding ASCII `'0'` to each remainder produces the characters `9`, `7`, and `5`.
Writing backward leaves `579` in the buffer in the right order.

```asm
digit_loop:
xor edx, edx          ; Clear the high half of EDX:EAX.
div ebx               ; EBX = 10. Quotient in EAX, remainder in EDX.
add dl, 48
dec edi
mov [edi], dl
test eax, eax
jne digit_loop
```

The loop runs once before checking the quotient. An input of zero therefore emits
the character `0`. The routine passes the completed string to `write_string`.

## Make changes and inspect the bytes

Use a copy of the workbook for these experiments. Recalculate, save, rebuild, and
run after each change.

### Change a prompt

On **Data**, change D9 from `First number:  ` to `A: `. Keep the label
`prompt_first` unchanged. Column E recalculates the string length, later data
offsets move, and instructions referencing those symbols acquire new addresses.

The strings use `<CR>` and `<LF>` as visible tokens for carriage return and line
feed. The formulas expand them and append a zero byte. Use ASCII text for this
exercise. Keep buffer sizes and import definitions unchanged.

### Move the subroutines without editing a displacement

On **Assembler**, find the spare `NOP` rows after the first `ExitProcess` call and
its `INT3` guard. These rows cannot execute in the supplied program.

Change one spare row from `NOP` to `MOV EAX,imm32` and enter `0` as its operand.
The row grows from one byte to five. The subroutines below it move by four bytes.
Inspect a call from the main program to `write_string`: its displacement also
increases by four. Rebuild and check that `123 + 456` still prints `579`.

Calls and jumps entirely within the moved block keep the same displacement because
both their source and destination move by the same amount.

### Rename a subroutine

Change the `print_number` label to `print_decimal`, then change every `CALL label`
operand that names it. The encoding should remain the same because the instructions
have not moved. Leaving a reference to the old name produces a formula error, which
the CSV converter rejects. Duplicate code labels are also rejected.

These exercises use existing rows. Adding rows requires extending the assembler's
bounded lookup ranges and Image references. The supplied workbook has fixed section
capacities; it is not an unrestricted source editor.

## Executable layout

The Image sheet emits a fixed 3,584-byte file:

| Region | File offset | RVA | Reserved bytes |
| --- | --- | --- | --- |
| Headers | `0x000` | Headers | 512 |
| `.text` | `0x200` | `0x1000` | 1,536 |
| `.data` | `0x800` | `0x2000` | 1,024 |
| `.idata` | `0xC00` | `0x3000` | 512 |

The fixed image base is `0x00400000`. The entry point is the first instruction in
`.text`, at virtual address `0x00401000`. Keep `start` at that position.

The data section is writable because the program stores handles, input values, and
formatted output there. The import section names `ExitProcess`, `GetStdHandle`,
`ReadFile`, `WriteFile`, and `GetLastError` from `KERNEL32.dll`.

The headers and import records are supplied as a fixed template. Instruction and
string bytes are calculated. Unused section space is zero-filled. The template
does not contain base relocations or enable ASLR, matching the fixed-address
approach used in lesson one.

## Check the behavior

Try these cases from PowerShell:

| First input | Second input | Expected result |
| --- | --- | --- |
| `0` | `0` | `0 + 0 = 0` |
| `9` | `1` | `9 + 1 = 10` |
| `123` | `456` | `123 + 456 = 579` |
| `000000001` | `000000009` | `1 + 9 = 10` |
| `999999999` | `999999999` | `999999999 + 999999999 = 1999999998` |

Also enter `abc`, `-1`, an empty line, and `1000000000`. Each should print the
input error and repeat the current prompt. Follow the rejected line with a valid
number to check recovery.

To exercise redirected input in PowerShell:

```powershell
"123", "456" | .\console-add.exe
$LASTEXITCODE
```

The program prints the same calculation and returns zero. Redirected input is not
echoed by the console, so the prompts can appear together on one line. That is a
presentation difference from typing at the keyboard.

The local validation covers native Windows execution, boundary values, invalid
input and retries, EOF, redirected I/O, and the workbook's label calculations.
The development checks are separate from the reader's build workflow.

## References

- [Intel software developer manuals](https://www.intel.com/content/www/us/en/developer/articles/technical/intel-sdm.html): Volume 2, instruction entries for `CALL`, `RET`, `Jcc`, `DIV`, and the other forms in Opcodes.
- [Microsoft standard console handles](https://learn.microsoft.com/en-us/windows/console/getstdhandle).
- [Microsoft high-level console input and output](https://learn.microsoft.com/en-us/windows/console/high-level-console-input-and-output-functions).
- [Microsoft ReadFile](https://learn.microsoft.com/en-us/windows/win32/api/fileapi/nf-fileapi-readfile).
- [Microsoft WriteFile](https://learn.microsoft.com/en-us/windows/win32/api/fileapi/nf-fileapi-writefile).
- [Microsoft x86 calling conventions](https://learn.microsoft.com/en-us/cpp/cpp/argument-passing-and-naming-conventions).
- [Microsoft PE format](https://learn.microsoft.com/en-us/windows/win32/debug/pe-format).
