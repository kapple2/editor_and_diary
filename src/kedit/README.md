# KEDIT 1.15: a Korean text editor for K-HANGEUL

A full-screen text editor for the Apple II Plus (DOS 3.3, 48K, language card) on the K-HANGEUL 1.2b driver.
It is written entirely in 6502 assembly (ca65). It needs no BASIC program and no K-BASIC.
It edits DOS text files in K-HANGEUL's form (Hangul as Ctrl-K, two-set keys, Ctrl-A).
Design notes: `../../EDITOR-PLAN.md`. It started from KEDIT 1.0 in the LTM project (`proj-apple2-lifetimemgmt/src/kedit`).

## Start

Boot `disk/kedit/KEDIT.dsk`. The disk loads K-HANGEUL and goes straight into the editor.
(`HELLO` is K-HANGEUL's own three-line loader. It runs the exec file `KSTART`: `BRUN K-HANGEUL`, `BRUN KEDIT`.)
From the `]` prompt of any K-HANGEUL disk that holds the file, `BRUN KEDIT` also works.

Quitting returns to the `]` prompt. KEDIT uses BASIC's program memory, so a BASIC program in memory is lost.

## Screen

```
rows 0-14   text (46 columns; English 1 column, a Hangul syllable 2)
row 15      영 ABC 줄 12/39 칸 7 여유 7312 * DIARY        (an inverse bar; or a message, or the `명령:` command line)
```

Status: `한`/`영` = Hangul or English typing, `ABC`/`abc` = case lock, `줄` line/lines, `칸` column, `여유` = bytes of text space still free (live: it changes with every key), `*` = changed
since the last save, then the file name. Long lines wrap onto the next row.

## Keys

| Key | Action |
|---|---|
| Ctrl-B, ← (Ctrl-H), Ctrl-U, → | one character left, right (one syllable in Hangul). Same on every model. II Plus with the Shift key mod: Shift-← deletes backward (as Ctrl-S) |
| Ctrl-K, Ctrl-J | one row up, down (the ↑ ↓ keys of a IIe, and of a PC keyboard in an emulator, send these) |
| Ctrl-O, Ctrl-N | start, end of the line |
| Ctrl-W, Ctrl-Z | one screen up, down |
| Ctrl-T, Ctrl-E | start, end of the file |
| Ctrl-S, DELETE | delete before the cursor, on every model. The Hangul syllable you are typing loses one key at a time (녕 → 녀 → ㄴ); a finished syllable goes whole. `←` only moves left (a PC's Backspace sends `←` in an emulator, so use Ctrl-S) |
| Ctrl-D | delete the character or syllable under the cursor |
| Ctrl-X | delete from the cursor to the end of the line |
| Ctrl-Y | delete the line (it is kept) |
| Ctrl-G | copy the line (kept for Ctrl-P; the text is not changed) |
| Ctrl-P | put the kept line (cut with Ctrl-Y or copied with Ctrl-G) above the cursor line, as often as you like |
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
| `열기 이름` | `E name` | open a file; asks about unsaved changes like `N` (`E!` drops them without asking); a missing file starts a new one |
| `넣기 이름` | `R name` | insert a file at the cursor |
| `찾기 낱말` | `F word`, `/word` | find (Hangul and English; English ignores case); Ctrl-F repeats |
| `줄 N` | `G N`, or just `N` | go to line N |
| `번호` | `NU` | show / hide line numbers |
| `목록 [disk]` | `LS [disk]`, `CAT` | the files on the disk (lock mark, type, sectors, name). At a full page and at the end: Ctrl-K / Ctrl-J choose a row (shown inverse), RETURN opens it (asks about unsaved changes first; a non-text file is refused), ESC goes back to the text, any other key shows the next page (on the last page it goes back) |
| `디스크 S6,D2` | `CHD S6,D2` | the disk (slot, drive) that E, R, W and LS use from now on: DOS 3.3's `S6,D2`, `D2`, `S5` (also `2` = drive 2, `62` = slot 6 drive 2); it shows `디스크 [S6,D2]`. At start it is the DOS default disk. `LS S6,D2` lists that disk and makes it the current one (as in DOS) |
| `정보` | `I` | size of the text and free memory, in bytes |
| `다지움!` | `DA!` | delete the whole text (the file on the disk is not touched until you save) |
| `도움` | `H`, `HELP`, `?` | key and command list |
| `새로` | `N`, `NEW` | new empty text with no name. With unsaved changes it asks `저장할까요? Y:저장 N:버림 다른 키:취소` (Y saves first, and is refused without a file name; N drops the changes; any other key cancels). `N!` drops unsaved changes without asking |

Longer English names also work: `SAVE`, `QUIT`, `OPEN`, `FIND`, `LIST`, `DIR`.

File names may be Hangul (`열기 일기`) or English.

## Limits

- Text up to 7,364 bytes (1.13: rows are cleared with the driver's fast clear, `FASTCLR`; 7,431 in 1.12: the save writes the lines without their trailing spaces and without the empty lines after the last text; 7,755 in 1.11: the Shift keys on the command line; 7,765 in 1.10: the program got smaller; 6,461 in 1.9; 6,718 before CHD, 1.8).
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

- **Source layout (since 2026-11-15):** the editor itself (keys, editing, gap buffer, layout, drawing, command line, search, file manager calls) is in `src/common/` and is shared with KDIARY; `kedit.s` includes it and holds KEDIT's own code (start, file commands, catalog, load and save, variables). A change in `src/common/` changes both programs: see `src/common/README.md`. The split did not change `KEDIT.bin` (1.12: byte for byte the same).
- `python src/kedit/build.py` writes `build/gen.inc` (Korean messages, command table, jamo tables), then assembles
  and links `build/KEDIT.bin` (load address `$4000`). It prints the sizes.
- `python src/tools/mkdisk.py` builds `disk/kedit/KEDIT.dsk` from `disk/khangeul-base.dsk` (DOS 3.3, K-HANGEUL, fonts).
  It first replaces the driver and the fonts on the base image with K-HANGEUL's own build output
  (`..\proj-apple2-korean-high-resolution\DIST-github\src\driver\build\*.bin`, newer than its disk; the project's
  `disk\K-HANGEUL.DSK` is used for a file with no build output) if they differ, and says so. After such an
  update run all the tests on both cards.
- Tests run KEDIT in MAME without a window, on a fresh disk each: `python src/tools/test_kedit1.py` ... `test_kedit13.py`.
  For the Saturn 128K card set `KEDIT_MAME_ARGS=-sl0 ssram` first.
  They compare the saved files byte for byte with the expected text, and leave screenshots in `work/sess/`.
  1 type and save; 2 a real 8 KB file: paging, search, edits, insert, save as; 3 wrap, syllable moves, case, help;
  4 cut/put a line, Ctrl-R, info, Hangul file name, catalog; 5 typing ahead; 6 delete keys (Ctrl-C, Ctrl-Y), Ctrl-X, HELP; 7 Backspace in Hangul;
  11 the catalog (choose and open, asking about unsaved changes), E asking, Ctrl-G and Ctrl-P;
  10 the free bytes on the status bar (against a Ctrl-L redraw) and N with unsaved changes;
  8 one-row scrolling up and down (frames per key, and the screen against a full redraw); 9 safe save (over a file, a locked
  file, a full disk).
- Paths to cc65 and MAME are at the top of `build.py` and `src/tools/session.py`. `disk/nbyte.py` is a copy of
  K-HANGEUL's converter between this text form and UTF-8; the build and the tests use it.

## How it works

- Memory (1.13): code, messages and tables `$4000-$6EFA` (12,027 bytes), variables to `$773B`,
  then the text as a gap buffer up to `HIMEM` (`$9400`): 7,364 bytes. The 38 busiest variables are in the zero page (the equates near the
  top of `kedit.s`): work bytes of Applesoft that the driver, DOS and the monitor do not touch. They are not cleared at the start (BSS is):
  a new one must be set before it is read.
- Comparing two builds: `python src/tools/kregress.py run <tag> [KEDIT.bin kedit.lbl]` runs all the tests with that binary and keeps the screens
  and results, `cmp <tagA> <tagB>` compares them. The status bar shows the free bytes, so to compare builds of different sizes assemble the new
  one with `-D TEXTCAP=<the old text space>` (a test build: see `start`). The catalog screens still differ (KEDIT's own sector count).
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

## The screen width (1.5)

The driver's text screen is 46 columns of 6 pixels, 276 of the 280 pixels of the hi-res page, so 4 pixels at the right
are never drawn by it. KEDIT uses all 46 columns (`SCRW`). The driver wraps after the last column and, on the bottom row
of its window, scrolls; so while KEDIT draws, the window is one column wider than the screen (`WIDE` = 47) and the
driver never wraps; around a scroll it is put back to 46, because the driver's scroll moves `WNDWDTH` bytes of each text
row. On exit it is 46 again. The 4 pixels at the right of the status bar (bits 3-6 of byte 39 of the 12 pixel lines of
row 15) are painted by `barstrip` so that the inverse bar spans the screen; the table of the 12 addresses comes from
`gen.py`. Selecting a catalog row turns the 12 pixel lines of that row over (`invrow`, `hgrline`).

## User-definable keys (1.7)

KEDIT reads its key map from the file `KEYS` at every start (`loadkeys`); the Applesoft program `KEYCFG` writes it.
There is one binary and one disk. (An earlier build of 1.7 had a second binary, `KEDITK`; it was merged into `KEDIT`.)
KEDIT.bin is 12,870 bytes, text space 6,470 in 1.8 (CHD, `LS disk`: 248 bytes; in 1.7 12,624 and 6,718) (1.6: 12,359 and 6,983: the map 32, `helpx` about 55, `loadkeys` about 80,
the lookups, one message).

- **The key map** (`keymap`, 32 bytes inside the program file): for each control code `$00-$1F` the number of the action it runs.
  An action number is the control code that runs it in `ctltab` (`ctltab` is not changed): 2 left, 21 right, 11 up, 10 down,
  15 line start, 14 line end, 23 page up, 26 page down, 20 file start, 5 file end, 19 backspace, 4 delete character,
  24 delete to line end, 25 delete line, 16 paste, 7 copy, 18 undo, 6 find again, 17 case, 9 tab, 12 redraw; 0 = bell.
  Fixed (KEYCFG refuses them): `$01` (Ctrl-A, Hangul switch), `$08` (Ctrl-H, the left arrow, with Shift-delete on a II Plus),
  `$0D` (RETURN), `$1B` (ESC; `dispatch` handles it before the map). `dispatch` does `lda keymap,x` before the `ctltab` jump.
  The ESC command line and the other key reads keep their own raw codes, except `lspick` (the catalog), which maps the key.
- **The key file** `KEYS`: a DOS binary file, 32 bytes, saved by KEYCFG with `BSAVE KEYS,A$300,L32` (so 4 header bytes
  come first). `loadkeys` (called at start, before the first message) opens it with the file manager, reads 36 bytes into `cw`,
  checks the header length is 32 and every number is at most 31, and copies the 32 bytes over `keymap`. Anything wrong
  (no file, wrong length, a number above 31): the map stays the classic one (the identity map in the file) and the start-up
  message is `m_nokeys` instead of `m_hello`. The shipped `KEYS` is the classic map.
- **Help:** `gen.py` writes the help lines with a slot `{n}` (a byte below `$80`, n = the action number) wherever a key is
  named. `helpx` (called from `cmd_h`) copies each line to `cb`, replaces a slot by `^` and the first key whose map entry is n
  (`^-` if none), and shows that. A slot is two characters wide, like `^B`.
- **KEYCFG** (`src/kedit/keycfg.bas`, Applesoft, screens in Hangul; the source is UTF-8 and `mkdisk.py` turns each Hangul run into Ctrl-K, two-set keys, Ctrl-A before `acx -bas`): one screen lists all 22 actions in two columns (11 and 11) with their keys;
  The right and left arrows (Ctrl-U, Ctrl-H; also `N`/`P`, space) move the `>`. A control key is assigned to the marked action, Ctrl-I included (Tab is Ctrl-I on a IIe; `I` also assigns Ctrl-I, for a II Plus). Arrows cannot be assigned: Ctrl-U and Ctrl-H are taken by the moves. `C` clear,
  `R` reset (classic or IJKL), `S` save, `Q` quit. An action that lost its key to another, or has none, is shown in inverse.
  The screen is drawn in full (from `HOME`, top to bottom) only at start and after the reset menu. A key press redraws only the entries whose
  keys or `>` changed, placing each with `POKE 37` (row) and `POKE 36` (column); `VTAB` is not used (under this driver it lands on row n-2).
  Each entry's last drawn state is kept in `E$`, so a key that changes nothing draws nothing. It reads keys
  from `$C000` and also from K-HANGEUL's type-ahead ring (`$942B`, `$942C`, `$95AE`), because the driver takes keys typed
  while it draws. The key map it writes is built in BASIC memory at `$300` (page 3).
- **Disk:** `python src/tools/mkdisk.py` (or `build_all.bat`) builds `disk/kedit/KEDIT.dsk` with `KEYS` (classic), `KEYCFG`, and the rest.
  The IJKL set (Ctrl-I up, J left, K down, L right, Tab on Ctrl-V, redraw on Ctrl-C, Ctrl-B free) is KEYCFG's `R`, `2`.
- **Tests:** `test_kedit12.py` (IJKL `KEYS` put on the disk: the keys, Tab, the free Ctrl-B, the help screen, then a KEYCFG
  session that rewrites `KEYS`) and `test_kedit13.py` (no `KEYS`, a `KEYS` of 20 bytes, a `KEYS` with a number above 31:
  the message, and the classic keys work).
