# KDIARY v1.13: Korean diary for the Apple II Plus (K-HANGEUL)

The editor is KEDIT's: since v1.09 both programs assemble the same code from `src/common/` (before that KDIARY had its own copy). Design: `PRD_DIARY.md` (root, not tracked).

Build: `python src/tools/mkdiary.py` (or `build_all.bat`) -> `disk/kdiary/KDIARY.DSK`. Source: `src/common/` (the editor code shared with KEDIT: see its README) and `src/kdiary/` (`kdiary.s` = the start, the editor's entry and exit, the variables,
`shell.s` = password, date, calendar, list, entry files; `shellbss.s`; `gen.py` messages; `build.py`).
Start screens: a splash picture (`art.py`, in segment SPLASH, the last one in the file; the editor's line arrays in BSS lie over it; shown only on the start screens, before the first password is accepted) and the footer `캐플 2026  v1.13` (the version, set by `VERSION` in `gen.py`).

The manual `src/docs/DIARY_MANUAL.md` carries the same version number in its title (check that they agree).

**Version rule:** `<major>.<minor><bug fix>` with two digits after the point (v1.00, v1.50, v1.51). Every change of the program raises it
(`VERSION` in `gen.py`, this title, the HANDOVER entry); minor = a new feature, last digit = a fix.
Boot: HELLO -> KSTART -> `BRUN K-HANGEUL`, `BRUN KDIARY` (load `$4000`, KDIARY.bin 16,445 bytes, variables to `$873C`, text space 3,267 bytes (`$873D`-`$93FF`): an entry needs 1,200).

## Use

0. **Data disk** (first screen): the drive that holds the diary data. RETURN keeps the shown `[S6,D1]` (the DOS default,
   normally the program disk), `D2` = drive 2 of that slot, `S5,D2` = slot 5 drive 2 (DOS 3.3 form; `2` and `62` also work). The password file `PWCHK` and the
   month files are on that disk; a blank DOS 3.3 disk works (first run creates `PWCHK`). A disk error returns to this screen.
   If the data disk has no `PWCHK`: no month files -> asks `Y` before creating a diary there; month files without `PWCHK` -> refused.
   Scenario: programs on disk 1, data on disk 2 (`2`); or everything on disk 1 (RETURN).

1. **First run**: it explains that a forgotten password cannot be recovered, asks for a password (1-16 characters) twice and
   writes `PWCHK`. **Later runs**: the password is asked first (stars). A wrong one shows a message (press a key) and asks again.
2. **Today's date** (`2026-11-14`, years 2001-2099).
3. **Calendar** of the month (the year and month are centred and underlined); `*` = a day has an entry; the line under it shows that day's title. The top line is an inverse bar: date, weekday (`토요일`), `일기`.

| Key | Action |
|---|---|
| left / right (`^B`/`^H`, `^U`) | previous / next day (into the neighbouring month) |
| up / down (`^K`, `^J`) | previous / next week |
| `P` `N` | previous / next month |
| `<` `>` (or `,` `.`) | previous / next year |
| 8 digits (typed as `2026-12-01`) | go to that date (ESC cancels the digits) |
| `T` | back to today |
| RETURN | write the day's entry, or edit it |
| `L` | list of all entries (see below) |
| `D` | delete the day's entry (asks: Y deletes) |
| ESC | command line (inverse bar, own command table `caltab`): `Q` = end, `CHD S6,D2` = change the data disk (password question for it; the top line shows `일기 [S6,D2]`), `LS [disk]` / `목록` = the files of a disk, `?` = help |
| `Q` | end (back to DOS) |

The movement keys are the ones in the `KEYS` map (KEYCFG changes them for both KEDIT and the diary).

4. **List** (`L`): every entry of every month file on the disk (the catalog is read, then the flags of each month: it takes a
   moment). Rows are `2026-11-14  title`, oldest first, 12 to a page; the page starts at the chosen month. Up/down move by entry,
   left/right move one entry as up/down do; `<` `>` (or `,` `.`) a page, 8 digits jump to that date (or the next entry), RETURN opens, ESC goes back. Up to 96 months.
5. **Writing**: KEDIT's editor on screen rows 2-15; row 1 is the top line (an inverse bar: date, weekday, `:`, then the title = the first line of the
   text, redrawn when it changes). ESC opens the command line: `W` save, `Q` leave (refuses if changed: `Q!` leaves anyway),
   `WQ` save and leave, `H` help. All KEDIT edit keys work. The text is limited to **1,200 bytes**; at the limit typing is
   refused (the status bar shows the free bytes). Saving an empty text (if the day had an entry) asks `Y:지움 다른 키:저장 안 함`: Y deletes the entry, any other key keeps the old one.

## Files (on the program disk for now)

- `PWCHK`: 8 bytes, the phrase `KDIARY!!` encrypted with the password. Unlock = decrypt and compare.
- `일기 2026-11` (K-HANGEUL key-letter form), one per month, random access, record length 1 (a record number is a byte
  position). Slot d is at byte d*1280 (high byte d*5). Slot 0: 32 bytes, encrypted: `$5A` then 31 flags. Slot d: 2 bytes
  length (plain) + the text in the editor's form (bit 7 set, Hangul runs Ctrl-K..Ctrl-A, lines end `$8D`), encrypted.
  Only the bytes written take sectors (a month with one short entry is 3 sectors).
- Encryption: byte i of a slot is XORed with `(pw[i mod n] + d*7 + month*3 + year + 29*i) mod 256`. **Not strong
  cryptography.** `src/tools/dverify.py` is an independent Python reader/decrypter used by the tests.

## Not built yet (PRD sections)

Week view (W), year view (Y), search (S); several data disks, the master index `일기디스크`, the per-disk index `일기목록`,
the label `일기표`, disk prompts and formatting a data disk (4.2, 4.3); import from LTM (6); changing the password (9.7).
The data disk is the one chosen on the first screen (or with `CHD` in the calendar). The editor commands E, R, N were removed; `LS` is a calendar command.

## Memory and speed (v0.53)

- Layout: `CODE`, `RODATA`, `SPLASH` in the file; BSS is not in the file and starts where SPLASH starts (`kdiary.cfg`). `start` clears the
  variables from `bss0` (the line arrays `uc ur uf hold u` before it lie over the picture and are not cleared).
- 58 of the busiest variables are in the zero page (the equates near the top of `kdiary.s`): work bytes of Applesoft that the driver, DOS and
  the monitor do not touch. **They are not cleared at the start**: a new one must be set before it is read. Free bytes of that kind are used up.
- Texts with `{x,y}` in `gen.py` carry cursor positions (`puts`); a question ends with the blanks that bring the cursor to the answer's column
  (`getline` starts at the cursor). The month file's name `mname` and `pwname` (KEYS, then PWCHK) are buffers in the program file.
- Helpers worth knowing: `cp3`/`cp2` (copy dates and list positions inside the block at `yy`: keep its order), `sio` (short slot transfers by
  table `siotab`), `catwalk` (catalog walk with a routine for each entry), `tbyte` (next text byte, skips the gap), `rowof`, `topcur`, `drtop`.
- Drawn less: a day move on the calendar redraws two cells, the day and weekday on the top line and the title line only if it changes; a move in
  the list redraws two rows; blanks are not drawn on a screen that was just cleared (`cfresh`); the editor's top line redraws only the title;
  `loadline` copies a line up to the gap or the end of the text without testing for them at every byte.
  The list reads each month's flags from the file's first sector with RWTS (through the track/sector list found in the catalog), not by opening it.

## Tests (MAME, `src/tools/dsession.py`)

`python src/tools/dregress.py run <tag> [KDIARY.bin kdiary.lbl]`, then `cmp <tagA> <tagB>`: eight key scripts (first run, calendar, list, every
editor key and command, a long entry, another key map, ESC commands with two disks, disks without a diary) on two builds; it compares every
screen and every file written, and prints the frames used. For changes that must not change what the program does. The v0.52 binary is kept in
`work/regress/base_bin/` (not tracked). The catalog screens of scenario D differ whenever the size of KDIARY changes (its sector count is shown).

Run in order: test 3 starts from the disk test 2 leaves, test 4 from the one of test 3.
`test_kdiary1.py` first run and calendar (look at `work/sess/d1_sheet.png`); `test_kdiary2.py` write and save;
`test_kdiary3.py` wrong password, reopen and append, a Hangul entry in December, list; `test_kdiary4.py` delete and cancel.
Tests 3 and 4 check the disk with `dverify.py` and print OK or MISMATCH (they exit 0 either way: read the output).
`test_kdiary5.py` (on test 3's disk): the help screen and the status bar after it, the list, page key, date jump (look at `work/sess/d5_sheet.png`).
Passed on the 16K card; test 2 also on the Saturn card (`KEDIT_MAME_ARGS=-sl0 ssram`).

## KDEXPORT v0.31: the converter (a separate program, `export.s`, on the same disk)

`BRUN KDEXPORT` at the DOS prompt (after the diary ended; K-HANGEUL stays in memory). It asks the disk with the diary and the
disk to write on (RETURN / `2` / `62` as above; they may be the same disk or different drives), then the password, and writes
one **plain, not encrypted** text file per month, `DIARY-2026-11` (N-byte text form, entries `2026-11-14` + the text +
blank line). On the PC: `acx -g disk.dsk DIARY-2026-11 out.bin`, then `python nbyte.py decode out.bin out.txt` (UTF-8).
Tests: `test_kdexport.py` (A: all on disk 1, files to disk 2; B: diary on disk 2, files to disk 1), `test_kdiary6.py` (diary data on drive 2).
`src/tools/kdiary_decrypt.py` reads the encrypted month files straight from a `.dsk` image (no export needed).
File manager finding: a WRITE with length field L writes L+1 bytes, a READ with L reads L bytes (`slotio` in shell.s).
