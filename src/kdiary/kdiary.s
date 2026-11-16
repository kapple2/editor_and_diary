; KDIARY - a Korean diary on K-HANGEUL (Apple II Plus, DOS 3.3, 48K + language card)
;
; BRUN KDIARY. This file: the start, the editor's entry and exit for one diary entry, and the variables. The shell
; (password, calendar, list, month files, the save of an entry) is shell.s. The editor itself (keys, movement,
; editing, the gap buffer, layout, drawing, the command line, search, the file manager calls) is in ../common and is
; shared with KEDIT: see ../common/README.md.
;
; Screen: row 0 the top line (date, weekday, title), rows 1-14 text, row 15 status (an inverse bar) / command line.

; ---- what the shared code needs from this program (before the first .include) ----
KDIARY  = 1                     ; the diary's own parts: the calendar's command list, the slot files, "[S6,D2]" on the bar
TOPLINE = 1                     ; screen row 0 is the program's top line: text row y is screen row y+1
FASTCLR = 1                     ; rows are cleared with the driver's fast clear (fastclr in shell.s), not with blanks
.define TXTEND_LO #<BUFE        ; the end of the text space is a constant here: one entry (MAXTXT bytes)
.define TXTEND_HI #>BUFE

        .include "../common/defs.inc"

; The busiest variables are in the zero page too: bytes that are only work space of Applesoft (which is not running
; while KDIARY runs, and sets them anew before it uses them) and that the driver, DOS and the monitor do not touch.
; They are NOT cleared at the start: every one is set before it is read. (pre must be the lowest of pre, len, cln,
; nlines: numld; ndrv follows nslot.)
pre     = $53
len     = $55
ls      = $57
cln     = $59
nlines  = $5B
ci      = $5D
gape    = $61
gaps    = $63
ni      = $65
topl    = $71
numv    = $7F
eoff    = $81
drl     = $86
topln   = $88
lbn     = $8B
drr     = $8C
wk      = $8D
drln    = $91
msgp    = $93
cl      = $95
lnoff   = $97
cbn     = $99
inl     = $9A
topr    = $A0
sbn     = $A1
drk     = $A2
dirty   = $A5
dgn     = $A6
lsn     = $A7
ttn     = $A8
nslot   = $A9
ndrv    = $AA
hascr   = $AB
cs      = $AC
dinrun  = $EB
cut     = $EC
dmode   = $ED
lsoff   = $EE
stlen   = $EF
stfull  = $FA
modf    = $FB
dcol    = $CE
cwn     = $CF

ROWS    = 14                    ; text rows (screen rows 1-14; row 0 is the top line)
STROW   = 14                    ; logical row of the status bar (screen row 15)
MAXTXT  = 1200                  ; the longest entry

        .segment "CODE"

; ==========================================================================
; start and exit
; ==========================================================================
start:  cld
        lda #0                  ; clear the variables (they follow the line arrays, which lie over the start
        tax                     ; picture: see the BSS segment) and the start of the text space
@z:     sta bss0,x
        sta bss0+$100,x
        sta bss0+$200,x
        inx
        bne @z
        lda DOSDRV              ; the data disk is on the DOS default drive until the user chooses another
        sta ddrv
        lda DOSSLOT
        sta dslot
        tsx
        stx savesp
        lda $FBB3               ; $06 on a IIe, IIc, IIgs
        cmp #$06
        bne @p
        inc iie
@p:     lda BUTN2
        and #$80
        sta shidle
        jsr findbuf
        jsr newbuf
        lda TAIDX               ; the ring's index is 0-31 in the driver this was written for
        cmp #$20
        bcc @ta
        inc taoff
@ta:    lda #0                  ; keys typed before KEDIT started are dropped
        sta TACNT
        sta WNDLFT
        sta WNDTOP
        lda #SCRW               ; (the other variables are zero)
        sta tw
        lda #16
        sta WNDBTM
        jsr mkrows
        jsr clrscr
        jsr loadkeys            ; the key map from the file KEYS (without it: the classic keys)
        ldx #4                  ; the name buffer now names the password file
@n:     lda pwtxt,x
        sta pwname,x
        dex
        bpl @n
        jmp shell

; the editor: runs until the entry is left (quit), then returns to the caller of ed_run
ed_run: tsx
        stx edsp
        jsr k_redraw            ; the screen shows something else: the text rows are cleared, the bar is drawn whole
        lda #SCRW
        sta stlen
        lda #27                 ; (the top line: the whole title part is drawn)
        sta otcol
        lda #0
        sta msgp+1
        sta cut
        sta keepgoal
        sta comp
        sta compp
        lda #$FF
        sta otlen
        lda #<m_hello
        ldy #>m_hello
        jsr setmsg

        .include "../common/main.s"
; leave the editor: back to the shell
quit:   ldx edsp
        txs
        rts

        .include "../common/keys.s"
        .include "../common/move.s"
        .include "../common/edit.s"
        .include "../common/gap.s"
        .include "../common/layout.s"
        .include "../common/screen.s"
        .include "../common/command.s"
        .include "../common/search.s"
cmd_q:  lda modf
        beq cmdqx
        lda force
        bne cmdqx
        lda #<m_unsaved
        ldy #>m_unsaved
        jmp setmsg

cmd_wq: jsr save
        bcs cmdwx
cmdqx:  jmp quit
cmdwx:  rts
        .include "../common/cmds.s"
        .include "../common/fm.s"
        .include "../common/count.s"
        .include "shell.s"

        .segment "RODATA"
        .include "build/gen.inc"

        .segment "BSS"
; The line arrays come first: in the program file the start picture (segment SPLASH, the last one in the file) is at
; these addresses. They are not used before the first password is accepted, and the picture is not used after it.
uc:     .res 256
ur:     .res 256
uf:     .res 256
hold:   .res 252
u:      .res 256
; undo (Ctrl-R) and search (Ctrl-F): as in KEDIT (fl and fln are here, not in zero page: $97 is lnoff)
ulv:    .res 1
ubn:    .res 1
uls:    .res 2
ub:     .res 252
fl:     .res 2
fln:    .res 2
fwrap:  .res 1
fstart: .res 1
fpos:   .res 1
pidx:   .res 1
patn:   .res 1
pat:    .res 64
patf:   .res 64
bss0:                           ; start clears 768 bytes from here: the variables, and on into the text space
savesp: .res 1
edsp:   .res 1
        .include "shellbss.s"
iie:    .res 1
shidle: .res 1
shift:  .res 1
goal:   .res 1
keepgoal: .res 1
han:    .res 1
lower:  .res 1
nums:   .res 1
numw:   .res 1
tw:     .res 1
edfull: .res 1
tries:  .res 1
orows:  .res 1
olen:   .res 1
drows:  .res 1
crow:   .res 1
svx:    .res 1
svy:    .res 1
sgx:    .res 1
sgv:    .res 1
sgc:    .res 1
sgd:    .res 1
psn:    .res 1
psmax:  .res 1
pscol:  .res 1
psin:   .res 1
numlen: .res 1
numbuf: .res 6
force:  .res 1
argp:   .res 1
argn:   .res 1
fnp:    .res 2                  ; the name for the file manager
pgcnt:  .res 1
sbcnt:  .res 1
gtl:    .res 2
nlen:   .res 1
etgt:   .res 1
efrom:  .res 1
dfrom:  .res 1
psdry:  .res 1
stend:  .res 1
stpart: .res 1                  ; status: 1 = the length is unchanged, 2 = only the changed part is drawn
stbg:   .res 1
osbn:   .res 1
osb:    .res 80
sbx:    .res 1
rowlo:  .res 16
rowhi:  .res 16
ib:     .res 4
; ten tables, one slot per screen row. scroll1 and scroll2 move them as one block: keep them together, in this order
sl_lo:  .res ROWS+1
sl_hi:  .res ROWS+1
sr:     .res ROWS+1
sln_lo: .res ROWS+1
sln_hi: .res ROWS+1
sv:     .res ROWS+1
slast:  .res ROWS+1
snext_lo: .res ROWS+1
snext_hi: .res ROWS+1
rowlen: .res ROWS+1
STABN   = rowlen + ROWS + 1 - sl_lo
fmbuf:  .res 6
taoff:  .res 1
dcnt:   .res 1
comp:   .res 1
compp:  .res 1
compn:  .res 1
fulld:  .res 1
holdv:  .res 1
holdn:  .res 1
bufmem:
        .assert bufmem - bss0 <= 768, error, "start clears only 768 bytes of variables"
BUFE    = bufmem + MAXTXT       ; the end of the text space (one entry)
