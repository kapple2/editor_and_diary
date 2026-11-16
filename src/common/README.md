# src/common: the editor code shared by KEDIT and KDIARY

KDIARY's editor began as a copy of KEDIT's. Since 2026-11-15 the code that both programs use is here, once.
`src/kedit/kedit.s` and `src/kdiary/kdiary.s` `.include` these files; each program is still assembled into its own
binary (`KEDIT.bin`, `KDIARY.bin`), so sharing costs no memory.

**A change in this folder changes both programs.** After one, build both and run both test sets (below).

## The files

| File | What is in it |
|---|---|
| `defs.inc` | Addresses of the ROM, DOS 3.3 and K-HANGEUL, the work memory outside the program, the constants (`TROW0` = the screen row of text row 0, from `TOPLINE`). No code |
| `main.s` | The main loop (`main`), the way back to BASIC (`tobasic`) |
| `keys.s` | Reading keys (`getkey`), the key map and `dispatch`, small key actions, `k_redraw` |
| `move.s` | Cursor movement |
| `edit.s` | Typing, Hangul input, backspace and delete, lines (join, split, cut, copy, paste), the command `DA` (`cmd_da`), the line keys Ctrl-C (`cmd_dp`) and Ctrl-Y (`k_delln`), undo (`k_undo`), `ed_begin` / `ed_line` / `ed_lines` |
| `gap.s` | The gap buffer: `newbuf`, `insbytes`, `delbytes`, `gapto`, line loading |
| `layout.s` | The layout of the line being edited (units, columns, rows) |
| `screen.s` | Drawing: `putc`, `gotoxy`, `refresh`, scrolling, `drawfrom`, the status bar |
| `command.s` | The command line (ESC) and `runcmd` |
| `cmds.s` | Commands both programs have: `NU`, `G`, `H` (help), `I`; `rowput`, `rowclr`, `pause` |
| `search.s` | Find: `cmd_f`, `k_findn`, `matchline` |
| `fm.s` | DOS 3.3 file manager calls: `fmset`, `fmcall`, `findbuf`, `fmclose`, `loadkeys`, `dosmsg`, `setname` |
| `count.s` | `gotin`, `countlines` |
| `fastclr.s` | `fastclr`: clear some screen rows with the driver's own clear (Ctrl-L with the window set to those rows) |

Each program includes the files in its own order (the order of the code in the binary), with its own code between
them. KEDIT's own code: the start, the file commands, the catalog, load and save. KDIARY's own code: the start,
`shell.s` (password, calendar, list, month files, the save of an entry).

## What a program gives the shared code

Defined in the program's `.s` file **before the first `.include`**:

| Name | KEDIT | KDIARY | Meaning |
|---|---|---|---|
| `TXTEND_LO`, `TXTEND_HI` (`.define`) | `bufe`, `bufe+1` | `#<BUFE`, `#>BUFE` | The end of the text space: a variable (HIMEM) in KEDIT, a constant (one entry) in KDIARY |
| `TOPLINE` | not defined | defined | Screen row 0 is the program's own top line: text row y is screen row y+1, and the main loop calls `drawtop` |
| `FASTCLR` | defined (since 1.13) | defined | Rows are cleared with the driver's fast clear (`fastclr.s`) instead of with blanks. Both programs define it now; the other branch is the old way |
| `KDIARY` | not defined | defined | The diary's own parts: the calendar's command list (`cmode`, `caltab`), the slot files (`sio`, `mopen_r`, `pwname`), `[S6,D2]` on the bar; without it KEDIT's: the file name on the bar, `fmrange`, `realname`, `barstrip`, `/word` |

Also from the program: the zero-page and BSS variables (their addresses differ: each program's file has its own
list), `ROWS` / `STROW`, the routine `quit` (leave the editor: KEDIT ends the program, KDIARY returns to its shell),
`save`, the tables from its `gen.py` (`build/gen.inc`: messages, help, `cmdtab`).

A new difference between the programs: prefer a setting like the ones above over a new `.ifdef KDIARY`.

## Checking a change

- `python src/kedit/build.py` and `python src/kdiary/build.py` (or `build_all.bat`): both must assemble.
- A change that should not change a program: its binary must be byte for byte the same as before (keep a copy and
  `cmp`). This is how the split itself was checked: `KEDIT.bin` did not change at all.
- Otherwise: the KEDIT tests (`src/tools/test_kedit*.py`) and the diary tests (`test_kdiary*.py`,
  `python src/tools/dregress.py`). Run one MAME test at a time: they share a snapshot folder.

Not shared (yet): the two `gen.py` (messages, help text, tables), KDEXPORT (`src/kdiary/export.s`, which has its own
copies of `findbuf`, `fmopen` and `parsedisk`), the zero-page and BSS lists.
