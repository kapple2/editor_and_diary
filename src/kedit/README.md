# KEDIT 1.4: a Korean text editor for K-HANGEUL

A full-screen text editor for the Apple II Plus (DOS 3.3, 48K, language card) on the K-HANGEUL 1.2b driver.
It is written entirely in 6502 assembly (ca65). It needs no BASIC program and no K-BASIC.
It edits DOS text files in K-HANGEUL's form (Hangul as Ctrl-K, two-set keys, Ctrl-A).
Design notes: `../../EDITOR-PLAN.md`. It started from KEDIT 1.0 in the LTM project (`proj-apple2-lifetimemgmt/src/kedit`).

## Start

Boot `disk/KEDIT.dsk`. The disk loads K-HANGEUL and goes straight into the editor.
(`HELLO` is K-HANGEUL's own three-line loader. It runs the exec file `KSTART`: `BRUN K-HANGEUL`, `BRUN KEDIT`.)
From the `]` prompt of any K-HANGEUL disk that holds the file, `BRUN KEDIT` also works.

Quitting returns to the `]` prompt. KEDIT uses BASIC's program memory, so a BASIC program in memory is lost.

## Screen

```
rows 0-14   text (45 columns; English 1 column, a Hangul syllable 2)
row 15      영 ABC 줄 12/39 칸 7 여유 7312 * DIARY        (an inverse bar; or a message, or the `명령:` command line)
```

Status: `한`/`영` = Hangul or English typing, `ABC`/`abc` = case lock, `줄` line/lines, `칸` column, `여유` = bytes of text space still free (live: it changes with every key), `*` = changed
since the last save, then the file name. Long lines wrap onto the next row.

## Keys

| Key | Action |
|---|---|
| Ctrl-B, → | one character left, right (one syllable in Hangul). On a IIe ← also moves left |
| Ctrl-K, Ctrl-J | one row up, down (the ↑ ↓ keys of a IIe, and of a PC keyboard in an emulator, send these) |
| Ctrl-O, Ctrl-N | start, end of the line |
| Ctrl-W, Ctrl-Z | one screen up, down |
| Ctrl-T, Ctrl-E | start, end of the file |
| ← (Backspace on a PC) | II Plus: delete before the cursor. The Hangul syllable you are typing loses one key at a time (녕 → 녀 → ㄴ); a finished syllable goes whole. IIe: DELETE does this |
| Ctrl-D | delete the character or syllable under the cursor |
| Ctrl-X | delete from the cursor to the end of the line |
| Ctrl-Y | delete the line (it is kept) |
| Ctrl-P | put the kept line above the cursor line (undoes Ctrl-Y; also moves or copies a line) |
| Ctrl-R | put the cursor line back as it was before you edited it; Ctrl-R again brings the edit back |
| Ctrl-A | Hangul / English typing |
| Ctrl-Q | case lock (English) |
| Shift | the other case, and in Hangul the tense consonants with R E Q T W and ㅒ ㅖ with O P. II Plus: needs the Shift key mod (`$C063`). IIe and later: hold an Apple key (Open-Apple or Solid-Apple) instead |
| Return | new line |
| Ctrl-F | find the next match again |
| Ctrl-L | redraw the screen |
| ESC | command line: `명령:` on the last row, which stays an inverse bar |

You can type ahead. A key pressed while the screen is being redrawn stops the redraw, so several page keys in a row
draw the screen once.

## Commands (ESC, type, Return; ESC again cancels)

| Korean | English | |
|---|---|---|
| `저장 [이름]` | `W [name]` | save (under a new name if given) |
| `끝` | `Q` | quit (refused if there are unsaved changes) |
| `끝!` | `Q!` | quit without saving |
| `저장끝` | `WQ`, `X` | save and quit |
| `열기 이름` | `E name` | open a file (`E!` drops unsaved changes); a missing file starts a new one |
| `넣기 이름` | `R name` | insert a file at the cursor |
| `찾기 낱말` | `F word`, `/word` | find (Hangul and English; English ignores case); Ctrl-F repeats |
| `줄 N` | `G N`, or just `N` | go to line N |
| `번호` | `NU` | show / hide line numbers |
| `목록` | `LS`, `CAT` | the files on the disk (lock mark, type, sectors, name); ESC stops at a full page |
| `정보` | `I` | size of the text and free memory, in bytes |
| `지움 [N]` | `D [N]` | delete the cursor line, or N lines from it |
| `문단지움` | `DP` | delete the paragraph: from the cursor line to the next empty line |
| `모두지움!` | `DA!` | delete the whole text (the file on the disk is not touched until you save) |
| `도움` | `H`, `HELP`, `?` | key and command list |
| `새` | `N`, `NEW` | new empty text with no name. With unsaved changes it asks `저장할까요? Y:저장 N:버림 다른 키:취소` (Y saves first, and is refused without a file name; N drops the changes; any other key cancels). `N!` drops unsaved changes without asking |

Longer English names also work: `SAVE`, `QUIT`, `OPEN`, `FIND`, `LIST`, `DIR`.

File names may be Hangul (`열기 일기`) or English.

## Limits

- Text up to 7,644 bytes.
- A line holds at most 250 bytes; a file with a longer line is refused.
- The saved file always ends its last line with Return.
- Ctrl-R covers the edits of one line. Joining, splitting or deleting lines cannot be undone, except a cut line (Ctrl-P).
- Saving writes the text to `KEDIT.TMP` first, then deletes the old file and renames `KEDIT.TMP`, so a disk error while
  writing leaves the old file whole. If the disk has no room for both copies (DISK FULL), the old file is deleted first
  and the text written in its place, as in 1.2. A locked file is refused and stays as it was. Do not name a text `KEDIT.TMP`.
- Not tested: anything on a IIe or later, the Apple-key shift in particular (this MAME has no IIe ROM); real hardware;
  an I/O error in the middle of a save (the emulator cannot produce one).
- Ctrl-J and Ctrl-K are tested by putting the key code into the driver's type-ahead ring (the `K` step of
  `session.lua`), because MAME's keyboard types Ctrl-J as Return. Every other key in the tests comes in the normal way
  (KEDIT reading `$C000`).
- Not built: replace, search backward, a big buffer on the Saturn card.

## Building and testing

- `python src/kedit/build.py` writes `build/gen.inc` (Korean messages, command table, jamo tables), then assembles
  and links `build/KEDIT.bin` (load address `$4000`). It prints the sizes.
- `python src/tools/mkdisk.py` builds `disk/KEDIT.dsk` from `disk/khangeul-base.dsk` (DOS 3.3, K-HANGEUL, fonts).
  It first replaces the driver and the fonts on the base image with those on the K-HANGEUL project's disk
  (`..\proj-apple2-korean-high-resolution\DIST-github\disk\K-HANGEUL.DSK`) if they differ, and says so. After such an
  update run all the tests on both cards.
- Tests run KEDIT in MAME without a window, on a fresh disk each: `python src/tools/test_kedit1.py` ... `test_kedit10.py`.
  For the Saturn 128K card set `KEDIT_MAME_ARGS=-sl0 ssram` first.
  They compare the saved files byte for byte with the expected text, and leave screenshots in `work/sess/`.
  1 type and save; 2 a real 8 KB file: paging, search, edits, insert, save as; 3 wrap, syllable moves, case, help;
  4 cut/put a line, Ctrl-R, info, Hangul file name, catalog; 5 typing ahead; 6 delete commands, Ctrl-X, HELP; 7 Backspace in Hangul;
  10 the free bytes on the status bar (against a Ctrl-L redraw) and N with unsaved changes;
  8 one-row scrolling up and down (frames per key, and the screen against a full redraw); 9 safe save (over a file, a locked
  file, a full disk).
- Paths to cc65 and MAME are at the top of `build.py` and `src/tools/session.py`. `disk/nbyte.py` is a copy of
  K-HANGEUL's converter between this text form and UTF-8; the build and the tests use it.

## How it works

- Memory: code, messages and tables `$4000-$6DD2` (11,731 bytes), variables to `$7623`,
  then the text as a gap buffer up to `HIMEM` (`$9400`).
- Work areas outside that block, so that the text gets the room: the line being edited is in the keyboard input
  buffer (`$0200`), the status and command lines in page 3 (`$0300-$03CF`). The file manager works in a free DOS file
  buffer instead of buffers of its own. The text page is not used: its screen holes belong to DOS and the slot cards.
- Screen: every character goes through DOS's saved output routine `($AA53)` to the driver. The cursor is positioned by
  setting `CH`, `CV` and `BASL/BASH` to the driver's own text row (`$1980 + 46 × row`; `$DC2A` on the Saturn card).
  Only what changed is redrawn. Scrolling one row uses the driver's scroll inside a window of rows 0-14: a Return printed
  on row 14 scrolls up (`scroll1`), and Ctrl-V (`$96`) printed with the cursor in the window scrolls down and clears row 0
  (`scroll2`). Ctrl-V is K-HANGEUL's own control code ("move the screen down one line" in its manual, from Hangeul2). The
  ten per-row tables (`sl_lo` ... `rowlen`) are moved as one block of memory, so they must stay together and in order.
- Keys are read from `$C000`, so the driver never draws its cursor. The driver takes keys that arrive while it
  draws into its own ring (`$942B` count, `$942C` index, `$95AE` 32 keys); KEDIT reads that ring first.
  These three addresses and the row table are the only driver addresses used; they are those of K-HANGEUL 1.2b.
- Files: DOS 3.3 file manager (`$3D6`); read as one range, written as the two halves of the gap buffer. `save` calls
  `writeto` (KEDIT.TMP), `fmdel` (the old file), then RENAME (file manager call 9; 6 is CATALOG).
  The catalog is read with RWTS (`$3D9`).
