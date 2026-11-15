; KEDIT 1.12 - a Korean text editor on K-HANGEUL (Apple II Plus, DOS 3.3, 48K + language card)
;
; BRUN KEDIT. Text is kept exactly as a K-HANGEUL text file holds it (bit 7 set, Hangul runs Ctrl-K .. Ctrl-A,
; lines end with $8D), in a gap buffer from the end of this program up to HIMEM. The screen is drawn by printing to
; the driver (DOS's saved output routine, ($AA53), because a BRUN program runs inside DOS's output hook); keys are
; read directly from $C000 so the driver never shows its cursor. Files are read and written with the DOS 3.3 file
; manager ($3D6), with a free DOS file buffer as its work space. Design notes: EDITOR-PLAN.md.
;
; Memory outside the program block: the line being edited is in the keyboard input buffer ($0200), the status and
; command lines in page 3 ($0300-$03CF). (Not the text page: its screen holes belong to DOS and the slot cards.)
; Nothing else uses them while KEDIT runs, and it leaves more room for text.
;
; Screen: rows 0-14 text, row 15 status (an inverse bar) / command line. Columns 0-44 are used (column 45 is left
; empty so that the driver never wraps or scrolls).

        .setcpu "6502"
        .import __BSS_RUN__, __BSS_SIZE__

KBD     = $C000
KBDSTRB = $C010
BUTN0   = $C061                 ; Open-Apple (IIe and later)
BUTN1   = $C062                 ; Solid-Apple / Option
BUTN2   = $C063
WNDLFT  = $20
WNDWDTH = $21
WNDTOP  = $22
WNDBTM  = $23
CH      = $24
CV      = $25
BASL    = $28
BASH    = $29
INVFLG  = $32
TXTTAB  = $67
VARTAB  = $69
ARYTAB  = $6B
STREND  = $6D
FRETOP  = $6F
HIMEM   = $73
VTAB    = $FC22
HOME    = $FC58
LOCFPL  = $03DC
FMGR    = $03D6
REALOUT = $AA53
DOSDRV  = $AA68
DOSSLOT = $AA6A
TACNT   = $942B                 ; K-HANGEUL 1.2b: keys in its type-ahead ring (it takes keys while it draws),
TAIDX   = $942C                 ; index of the newest one,
TARING  = $95AE                 ; the ring (32 keys)
DOSBUFS = $9D00                 ; DOS: address of the first file buffer (its file name field)
LOCRPL  = $03E3
RWTS    = $03D9

lb      = $0200                 ; the line being edited (256 bytes)
sb      = $0300                 ; status line text (80 bytes)
cb      = $0350                 ; command line (64 bytes)
cw      = $0390                 ; command word (64 bytes, to $03CF)

; zero page: bytes that K-HANGEUL, DOS and the ROM routines used here do not touch
P1      = $10
P2      = $12
P3      = $15
SEGP    = $17
T0      = $19
T1      = $1B
T2      = $1C
T3      = $1D
T4      = $1E
T5      = $1F
nslot   = T4                    ; (used only inside getdiskarg: it calls nothing else)
ndrv    = T5
ndg     = T3
nbd     = T1

; The busiest variables are in the zero page too: bytes that are only work space of Applesoft (which is not running
; while KEDIT runs, and sets them anew before it uses them) and that the driver, DOS and the monitor do not touch.
; They are NOT cleared at the start: every one is set before it is read (start clears cut). pre must be the lowest
; of pre, len, cln, nlines (numld).
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
dirty   = $8D
drln    = $91
msgp    = $93
lnoff   = $95
fl      = $97
cbn     = $99
sbn     = $9A
topr    = $A0
drk     = $A1
modf    = $A2
ib      = $A5
bufe    = $A9
hascr   = $AB
lssel   = $AC
dinrun  = $EB
cut     = $EC
dmode   = $ED
lsoff   = $EE
lsrow   = $EF
stfull  = $FA
stlen   = $FB
fln     = $CE

ROWS    = 15
STROW   = 15
SCRW    = 46                    ; all the driver's columns. The driver would wrap (and at the bottom row scroll) after
WIDE    = 47                    ; the last column, so while KEDIT draws, the window is one column wider than the screen
MAXLN   = 250
CR      = $8D
HK      = $8B
HA      = $81
SPC     = $A0
F_NEEDK = $01
F_HAN   = $80

        .segment "CODE"

; ==========================================================================
; start and exit
; ==========================================================================
start:  cld
        lda #<__BSS_RUN__       ; BSS is not in the file: clear it
        sta P1
        lda #>__BSS_RUN__
        sta P1+1
        ldx #>(__BSS_SIZE__+255)
        ldy #0
        tya
@zb:    sta (P1),y
        iny
        bne @zb
        inc P1+1
        dex
        bne @zb
        tsx
        stx savesp
        lda $FBB3               ; $06 on a IIe, IIc, IIgs
        cmp #$06
        bne @p
        inc iie
@p:     lda BUTN2
        and #$80
        sta shidle
.ifdef TEXTCAP                  ; (a test build: a text space of exactly TEXTCAP bytes, to compare the screens of two
        lda #<(bufmem+TEXTCAP)  ; builds whose sizes differ: the status bar shows the free bytes. See kregress.py)
        sta bufe
        lda #>(bufmem+TEXTCAP)
        sta bufe+1
.else
        lda #0                  ; the text buffer runs from the end of the program (bufmem) to HIMEM
        sta bufe
        lda HIMEM+1
        cmp #$95
        bcc @h
        lda #$94
@h:     sta bufe+1
.endif
        jsr findbuf
        jsr newbuf
        lda TAIDX               ; the ring's index is 0-31 in the driver this was written for
        cmp #$20
        bcc @ta
        inc taoff
@ta:    lda #0                  ; keys typed before KEDIT started are dropped
        sta TACNT
        sta cut
        lda #SCRW               ; (the other variables are zero: BSS was cleared)
        sta tw
        lda #$FF
        sta INVFLG
        lda #0
        sta WNDLFT
        sta WNDTOP
        lda #46
        sta WNDWDTH
        lda #16
        sta WNDBTM
        jsr mkrows
        jsr HOME
        lda #SPC                ; the driver clears its screen at the first character after HOME
        jsr putc
        lda #WIDE
        sta WNDWDTH
        ldx #ROWS
@r:     lda #SCRW
        sta rowlen,x            ; the screen still shows what was there: clear every row once
        dex
        bpl @r
        lda #SCRW
        sta stlen
        lda #1
        sta stfull
        lda DOSDRV              ; the files are on the DOS default disk until CHD / LS names another
        sta ddrv
        lda DOSSLOT
        sta dslot
        jsr loadkeys            ; the key map from the file KEYS; without it the classic keys and a message
        lda #<m_hello
        ldy #>m_hello
        bcc @hm
        lda #<m_nokeys
        ldy #>m_nokeys
@hm:    jsr setmsg
        lda #3
        sta dirty

main:   jsr refresh
        jsr status
        lda cut                 ; (a key cut the redraw short: no cursor yet, the screen is redrawn after the key)
        bne @k
        jsr curon
@k:     jsr getkey
        pha
        lda cut
        bne @k2
        jsr curoff
@k2:    lda comp                ; was a Hangul syllable being typed (or taken apart) at the last key?
        sta compp
        lda #0
        sta comp
        sta msgp+1
        sta keepgoal
        pla
        jsr dispatch
        jmp main

quit:   lda TXTTAB              ; the program sat in BASIC's area: leave an empty program behind (like NEW)
        sta P1
        lda TXTTAB+1
        sta P1+1
        ldy #0
        tya
        sta (P1),y
        iny
        sta (P1),y
        lda P1
        bne @d
        dec P1+1
@d:     dec P1
        ldy #0
        tya
        sta (P1),y
        clc
        lda TXTTAB
        adc #2
        sta VARTAB
        sta ARYTAB
        sta STREND
        lda TXTTAB+1
        adc #0
        sta VARTAB+1
        sta ARYTAB+1
        sta STREND+1
        lda HIMEM
        sta FRETOP
        lda HIMEM+1
        sta FRETOP+1
        lda #$FF
        sta INVFLG
        lda #16
        sta WNDBTM
        lda #46
        sta WNDWDTH
        jsr HOME
        ldx savesp
        txs
        rts

; ==========================================================================
; keys
; ==========================================================================
; Keys typed while the driver was drawing are in its ring: they come first.
getkey: lda TACNT
        bne gkring
        lda KBD
        bpl getkey
gkend:  sta KBDSTRB             ; (the tests: getkey to here is the key wait loop)
        bmi gkgot
gkring: ldx taoff               ; (not the driver this was written for: its ring is left alone)
        bne gknone
        dec TACNT
        lda TAIDX
        sec
        sbc TACNT
        and #$1F
        tax
        lda TARING,x
        bne gkgot
gknone: lda #0
        sta TACNT
        beq getkey
gkgot:  and #$7F
        pha
        lda #0
        sta shift
        lda iie
        bne @e
        lda BUTN2               ; II Plus, Shift key mod: button 2 differs from its level at start-up
        and #$80
        cmp shidle
        beq @n
        bne @s
@e:     lda BUTN0               ; IIe and later: either Apple key is the shift
        ora BUTN1
        bpl @n
@s:     inc shift
@n:     pla
        rts

dispatch:
        cmp #$1B
        bne @a
        jmp command
@a:     cmp #$20
        bcc @ctl
        cmp #$7F
        bne @t
        jmp backsp
@t:     jmp typechar
@ctl:
        tax                     ; user-definable keys: the key map gives the action (the ctltab number) of this key
        lda keymap,x
        asl a
        tax
        lda ctltab+1,x
        pha
        lda ctltab,x
        pha
        rts

ctltab: .addr bell-1, k_han-1, k_left-1, bell-1, k_delf-1, k_end-1, k_findn-1, k_copy-1     ; @ A B C D E F G
        .addr k_lft-1, k_tab-1, k_down-1, k_up-1, k_redraw-1, k_ret-1, k_eol-1, k_bol-1   ; H I J K L M N O
        .addr k_paste-1, k_case-1, k_undo-1, backsp-1, k_top-1, k_right-1, bell-1, k_pgup-1 ; P Q R S T U V W
        .addr k_deol-1, k_delln-1, k_pgdn-1, bell-1, bell-1, bell-1, bell-1, bell-1      ; X Y Z [ \ ] ^ _

; The key map: for each control code $00-$1F, the number of the action it runs (the number of ctltab's entry: a
; key's own code when nothing is moved; 0 = no action, a bell). It is in the program file on purpose: the boot
; EXEC file BLOADs a KEYS file over it (made by KEYCFG, the Applesoft key setup) before KEDITK starts.
; Fixed: ESC ($1B, handled before), RETURN ($0D), Ctrl-A ($01) and Ctrl-H ($08, the left arrow).
keymap: .byte 0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31

bell:   lda #$87
        jmp putc

; $08 (the left arrow; Ctrl-H; a PC's Backspace in an emulator) moves left on every model. Backspace is Ctrl-S
; (ctltab) and DELETE ($7F), on every model. On a II Plus with the Shift key mod, Shift-left also deletes backward
; (gkgot sets the shift flag). A IIe has no such mod here: there Shift does nothing to the left arrow.
k_lft:  lda iie
        bne @l
        lda shift
        beq @l
        jmp backsp
@l:     jmp k_left

k_han:  lda han
        eor #1
        sta han
        rts
k_case: lda lower
        eor #1
        sta lower
        rts
k_redraw:
        lda #1
        sta stfull
        ldx #ROWS
@r:     lda #SCRW
        sta rowlen,x
        dex
        bpl @r
        lda #0
        sta stbg
        lda #3
        sta dirty
        rts
k_tab:  lda #SPC
        jmp inschar

; ==========================================================================
; cursor movement
; ==========================================================================
k_right:
        lda ci
        cmp ni
        bcs @n
        inc ci
        rts
@n:     lda hascr
        beq @x
        jsr nextline
        lda #0
        sta ci
@x:     rts

k_left: lda ci
        beq @p
        dec ci
        rts
@p:     lda ls
        ora ls+1
        beq @x
        jsr prevline
        lda ni
        sta ci
@x:     rts

k_bol:  lda #0
        sta ci
        rts
k_eol:  lda ni
        sta ci
        rts

k_down  = down
k_up    = up

down:   inc keepgoal
        ldx ci
        lda ur,x
        ldx ni
        cmp ur,x
        bcs @nl
        clc
        adc #1
        jmp pick
@nl:    lda hascr
        beq @x
        jsr nextline
        lda #0
        jmp pick
@x:     rts

up:     inc keepgoal
        ldx ci
        lda ur,x
        beq @pl
        sec
        sbc #1
        jmp pick
@pl:    lda ls
        ora ls+1
        beq @x
        jsr prevline
        ldx ni
        lda ur,x
        jmp pick
@x:     rts

; put the cursor on row A of the current line, at the last unit whose column is <= goal
pick:   sta T0
        ldx #0
        stx T1
@l:     lda ur,x
        cmp T0
        bne @nx
        lda uc,x
        cmp goal
        beq @take
        bcs @nx
@take:  stx T1
@nx:    cpx ni
        inx
        bcc @l
        lda T1
        sta ci
        rts

; next / previous line (the current line must be loaded): updates ls, cln and loads the line
nextline:
        sec
        lda ls
        adc lbn                 ; + lbn + 1 (carry set)
        sta ls
        lda ls+1
        adc #0
        sta ls+1
        inc cln
        bne @c
        inc cln+1
@c:     jmp curline

prevline:
        jsr prevls
        lda P3
        sta ls
        lda P3+1
        sta ls+1
        jsr deccln
        jmp curline

; cln - 1 / nlines - 1
deccln: lda cln
        bne @c
        dec cln+1
@c:     dec cln
        rts
decnl:  lda nlines
        bne @d
        dec nlines+1
@d:     dec nlines
        rts

k_pgdn: lda #ROWS-1
        sta pgcnt
@l:     jsr down
        dec pgcnt
        bne @l
        rts
k_pgup: lda #ROWS-1
        sta pgcnt
@l:     jsr up
        dec pgcnt
        bne @l
        rts

k_top:  lda #1
        ldx #0
        beq gotolx

k_end:  lda #$FF                ; (a line number past the last one: gotoline stops at the last line)
        tax
        jsr gotolx
        jmp k_eol

; go to line gtl (gotolx: A/X) (1-based, clamped)
gotolx: sta gtl
        stx gtl+1
gotoline:
        lda #0
        sta ls
        sta ls+1
        sta ci
        sta cln+1
        lda #1
        sta cln
        jsr curline
@l:     lda cln
        cmp gtl
        lda cln+1
        sbc gtl+1
        bcs @x                  ; cln >= target
        lda hascr
        beq @x
        jsr nextline
        jmp @l
@x:     rts

; ==========================================================================
; editing
; ==========================================================================
; Shift + R E Q T W O P (the tense consonants and ㅒ ㅖ) on a Hangul key: T0 (uppercase) -> the shifted key.
; Used by the text (typechar) and by the command line (command), so both type the same letters.
shmap:  lda shift
        beq @x
        ldx #6
@s:     lda T0
        cmp shk,x
        beq @sf
        dex
        bpl @s
        rts
@sf:    lda shv,x
        sta T0
@x:     rts

typechar:                       ; A = key, 7 bits, printable
        sta T0
        lda han
        beq @eng
        lda T0                  ; Hangul mode: letters are keys (upper case)
        jsr upcase
        sta T0
        jsr shmap
@k:     lda T0
        ora #$80
        jsr kcls
        beq @plain
        lda T0
        ora #$80
        jmp inshan
@eng:   lda T0
        jsr upcase
        cmp #'A'
        bcc @plain
        cmp #'Z'+1
        bcs @plain
        ldx lower
        cpx shift
        beq @up
        ora #$20
@up:    sta T0
@plain: lda T0
        ora #$80
        jmp inschar

upcase: cmp #'a'
        bcc @x
        cmp #'z'+1
        bcs @x
        and #$DF
@x:     rts

; insert a Hangul key (A, bit 7 set) at the cursor
inshan: sta ib+1
        jsr ed_begin
        lda #1                  ; a syllable is being typed: Backspace takes its keys one by one
        sta comp
        ldx ci
        ldy u,x
        beq @new
        lda lb-1,y
        cmp #HA
        bne @mid
        dey                     ; right after a run: type into it, before its Ctrl-A
        jmp insone
@mid:   lda uf,x
        and #F_NEEDK
        bne insone              ; inside a run, between syllables
@new:   lda #HK                 ; a new run: Ctrl-K key Ctrl-A
        sta ib
        lda #HA
        sta ib+2
        lda #3
        tax
        bne insgo

; insert a character that is not a Hangul key (A, bit 7 set)
inschar:
        sta ib+1
        jsr ed_begin
        ldx ci
        ldy u,x
        lda uf,x
        and #F_NEEDK
        beq insone
        lda #HA                 ; inside a run: end it, the character, start it again
        sta ib
        lda #HK
        sta ib+2
        lda #3
        ldx #2
        bne insgo
insone: lda ib+1                ; the one byte, at line index Y
        sta ib
        lda #1
        tax
; insert A bytes from ib at line index Y; the cursor then goes X bytes on from the start of its unit
insgo:  stx etgt
        jsr insat
        bcs @f
        ldx ci
        lda u,x
        clc
        adc etgt
        jmp ed_line
@f:     rts

k_ret:  jsr ed_begin
        ldx ci
        ldy u,x
        sty T5
        lda uf,x
        and #F_NEEDK
        beq @plain
        lda #HA
        sta ib
        lda #CR
        sta ib+1
        lda #HK
        sta ib+2
        lda #3
        jsr insat
        bcs @f
        lda #2
        bne @nl
@plain: lda #CR
        sta ib
        lda #1
        jsr insat
        bcs @f
        lda #1
@nl:    clc                     ; the new line starts at ls + the index + A
        adc T5
        adc ls
        sta ls
        bcc @c0
        inc ls+1
@c0:    inc cln
        bne @c
        inc cln+1
@c:     inc nlines
        bne @d
        inc nlines+1
@d:     lda #0
        jmp ed_lines
@f:     rts

backsp: jsr ed_begin
        lda ci
        bne @in
        lda ls                  ; at the start of a line: join it to the previous line
        ora ls+1
        bne @j
        jmp bell
@j:     jsr prevls              ; P3 = start of the previous line
        clc                     ; previous length = ls - 1 - P3
        lda ls
        sbc P3
        sta T5
        clc
        adc lbn
        bcs @long
        cmp #MAXLN+1
        bcc @ok
@long:  jmp bell
@ok:    jsr joinrow             ; where the redraw starts
        lda ls
        sec
        sbc #1
        sta eoff
        lda ls+1
        sbc #0
        sta eoff+1
        lda #1
        jsr delbytes
        lda P3
        sta ls
        lda P3+1
        sta ls+1
        jsr deccln
        jsr decnl
        lda T5
        jmp ed_lines
@in:    lda compp
        bne @cmp
        dec ci                  ; no syllable is being typed: the whole character before the cursor goes
        jmp k_delf
@cmp:   cmp #1
        bne @cn
        ldx ci                  ; first Backspace after typing: compn = keys of the syllable before the cursor
        lda u,x
        sec
        sbc u-1,x
        sta compn
        ldy u-1,x
        lda lb,y
        cmp #HK
        bne @c1
        dec compn
@c1:    ldy u,x
        lda lb-1,y
        cmp #HA
        bne @cn
        dec compn
@cn:    dec compn               ; one key goes; while keys of that syllable are left, the next Backspace does the same
        beq @c0
        lda #2
        sta comp
@c0:    ldx ci
        ldy u,x
        dey                     ; Y = p, the byte before the cursor
        lda lb,y
        cmp #HA
        bne @nha
        cpy #2                  ; after a run: delete its last key
        bcc @one
        lda lb-2,y
        cmp #HK
        bne @one
        dey                     ; the run held one key: remove Ctrl-K key Ctrl-A
        dey
        sty T5
        lda #3
        jsr delat
        lda T5
        jmp ed_line
@one:   dey
        sty T5
        lda #1
        jsr delat
        lda T5
        clc
        adc #1
        jmp ed_line
@nha:   sty T5
        lda #1
        jsr delat
        lda T5
        jmp ed_line

k_delf: jsr ed_begin
        lda ci
        cmp ni
        bcc @unit
        lda hascr               ; at the end of a line: join the next line
        bne @j
        jmp bell
@j:     jsr nextlen             ; nlen = length of the next line
        lda nlen
        clc
        adc lbn
        bcs @long
        cmp #MAXLN+1
        bcc @ok
@long:  jmp bell
@ok:    ldy lbn
        lda #1
        jsr delat
        jsr decnl
        ldx ci
        lda u,x
        jmp ed_lines
@unit:  ldx ci
        lda u,x                 ; s
        sta T2
        sta T5                  ; (kept for the cursor: moving the gap uses T1 and T2)
        sta T3                  ; ks
        lda u+1,x
        sta T4                  ; ke = e
        ldy T2
        lda lb,y
        cmp #HK
        bne @a
        inc T3
@a:     ldy T4
        lda lb-1,y
        cmp #HA
        bne @b
        dec T4
        lda T4
        cmp T3
        bcs @b
        inc T4
@b:     lda T3                  ; whole run (Ctrl-K .. Ctrl-A)? delete s..e
        sec
        sbc T2
        cmp #1
        bne @keys
        ldx ci
        lda u+1,x
        sec
        sbc T4
        cmp #1
        bne @keys
        ldy T2
        lda u+1,x
        sec
        sbc T2
        jmp @del
@keys:  ldy T3
        lda T4
        sec
        sbc T3
@del:   beq @x
        jsr delat
@x:     lda T5
        jmp ed_line

; Ctrl-G: copy the cursor line (Ctrl-P puts it in)
k_copy: jsr holdline
        lda #<m_copied
        ldy #>m_copied
        jmp setmsg

; keep the cursor line (with its CR) for Ctrl-P
holdline:
        ldy lbn
@h:     lda lb,y
        sta hold,y
        dey
        cpy #$FF
        bne @h
        lda lbn
        sta holdn
        lda #1
        sta holdv
        rts

k_delln:
        jsr ed_begin
        jsr holdline
        lda hascr
        beq @last
        ldy #0
        lda lbn
        clc
        adc #1
        jsr delat
        jsr decnl
        lda #0
        jmp ed_lines
@last:  lda lbn
        beq @j
        ldy #0
        jsr delat
        lda #0
        jmp ed_line
@j:     jmp backsp

; Ctrl-X: delete from the cursor to the end of the line
k_deol: jsr ed_begin
        ldx ci
        cpx ni
        bcs @x
        ldy u,x
        sty dcnt
        lda uf,x                ; inside a Hangul run: its Ctrl-A goes too, and is put back
        and #F_NEEDK
        pha
        lda lbn
        sec
        sbc dcnt
        jsr delat
        pla
        beq @d
        jsr curline
        lda #HA
        sta ib
        ldy dcnt
        lda #1
        jsr insat
@d:     lda #$FF
        jmp ed_line
@x:     rts

; ---- delete lines: D [n], DP (to the next empty line), DA! (everything) ----
cmd_d:  jsr argnum
        lda T4
        beq @n
        lda #255
        sta T3
@n:     lda T3
        bne @c
        lda #1
@c:     sta dcnt
@l:     lda hascr
        pha
        jsr k_delln
        pla
        beq @x                  ; that was the last line
        dec dcnt
        bne @l
@x:     rts

cmd_dp: lda lbn
        bne @l
        jmp k_delln             ; on an empty line: that line
@l:     lda hascr
        pha
        jsr k_delln
        pla
        beq @x
        lda lbn
        bne @l
@x:     rts

cmd_da: lda len
        ora len+1
        beq @x
        lda force
        bne @go
        lda #<m_sure
        ldy #>m_sure
        jmp setmsg
@go:    jsr newbuf
        inc modf
        lda #3
        sta dirty
@x:     rts

; Ctrl-P: put the line kept by Ctrl-Y above the cursor line
k_paste:
        lda holdv
        bne @go
        jmp bell
@go:    lda #0
        sta ci
        jsr ed_begin
        jsr lsoff0
        lda #<hold
        sta P3
        lda #>hold
        sta P3+1
        ldx holdn
        inx
        txa
        jsr insbytes
        bcs @x
        inc nlines
        bne @n
        inc nlines+1
@n:     lda #0
        jmp ed_lines
@x:     rts

; Ctrl-R: put the cursor line back as it was before it was edited (again: the edited text comes back)
k_undo: lda ulv
        beq @no
        lda uls
        cmp ls
        bne @no
        lda uls+1
        cmp ls+1
        beq @go
@no:    jmp bell
@go:    lda #0
        sta ci
        lda #1
        sta ulv
        jsr ed_begin
        lda ubn
        beq @cp
        jsr lsoff0
        lda #<ub
        sta P3
        lda #>ub
        sta P3+1
        lda ubn
        jsr insbytes            ; the saved text goes in front of the present text
        bcs @x
@cp:    ldx ubn
        stx T5
        ldy lbn                 ; the present text becomes the saved one
        sty ubn
@c:     lda lb,y
        sta ub,y
        dey
        cpy #$FF
        bne @c
        ldy T5
        lda ubn
        beq @d
        jsr delat               ; and is taken out
@d:     lda #$81
        sta ulv
        lda #0
        jmp ed_line
@x:     rts

lsoff0: lda ls                  ; eoff = start of the cursor line
        sta eoff
        lda ls+1
        sta eoff+1
        rts

; length of the next line (current line loaded, has a CR) -> nlen; reloads the current line
nextlen:
        lda ls
        pha
        lda ls+1
        pha
        sec
        lda ls
        adc lbn
        sta lnoff
        lda ls+1
        adc #0
        sta lnoff+1
        jsr loadline
        lda lbn
        sta nlen
        pla
        sta ls+1
        pla
        sta ls
        jmp curline

; insert A bytes from ib at line index Y (offset ls+Y). Carry set if it does not fit.
insat:  sta T4
        clc
        adc lbn
        bcs @no
        cmp #MAXLN+1
        bcs @no
        jsr yoff
        lda #<ib
        sta P3
        lda #>ib
        sta P3+1
        lda T4
        jmp insbytes
@no:    jsr bell
        sec
        rts

; delete A bytes at line index Y
delat:  sta T4
        jsr yoff
        lda T4
        jmp delbytes

yoff:   tya
        clc
        adc ls
        sta eoff
        lda ls+1
        adc #0
        sta eoff+1
        rts

; before an edit: remember where the cursor line is on the screen (the redraw starts there), and keep the line as
; it is now for Ctrl-R, unless it is already kept (an earlier edit of the same line)
ed_begin:
        lda ulv                 ; (1 = kept; $81 = Ctrl-R was the last edit of it: keep it afresh)
        cmp #1
        bne @sv
        lda uls
        cmp ls
        bne @sv
        lda uls+1
        cmp ls+1
        beq @kept
@sv:    ldy lbn
        sty ubn
@cp:    lda lb,y
        sta ub,y
        dey
        cpy #$FF
        bne @cp
        lda ls
        sta uls
        lda ls+1
        sta uls+1
        lda #1
        sta ulv
@kept:
        ldx ci                  ; the first unit an edit can change: the previous one for plain text,
        lda uf,x                ; three back near Hangul (a syllable's extent depends on the next two keys)
        and #F_NEEDK
        bne @h3
        cpx #0
        beq @z
        lda uf-1,x
        bmi @h3
        cpx #2
        bcc @p1
        lda uf-2,x
        bmi @h3
@p1:    dex
@z:     stx efrom
        jmp @go
@h3:    lda ci
        sec
        sbc #3
        bcs @f0
        lda #0
@f0:    sta efrom
@go:
        ldx ni
        lda ur,x
        sta orows
        lda lbn
        sta olen
        lda ls
        sta P3
        lda ls+1
        sta P3+1
; The screen row that shows the start of the line at offset P3: the redraw starts there (drr, drk, drln, drl).
; Carry set, and edfull = 3, if that line is not on the screen: everything is redrawn
rowof:  ldy #0
@l:     lda sv,y
        beq @n
        lda sl_lo,y
        cmp P3
        bne @n
        lda sl_hi,y
        cmp P3+1
        beq @f
@n:     iny
        cpy #ROWS
        bcc @l
        lda #3
        sta edfull
        rts
@f:     lda #0
        sta edfull
        sty drr
        lda sr,y
        sta drk
        lda sln_lo,y
        sta drln
        lda sln_hi,y
        sta drln+1
        lda P3
        sta drl
        lda P3+1
        sta drl+1
        clc
        rts

; the redraw starts at the previous line (joining lines at the start of a line); P3 = previous line start
joinrow:
        jsr rowof
        bcc @x
        lda P3                  ; the previous line is above the screen: it becomes the top line
        sta topl
        lda P3+1
        sta topl+1
        lda #0
        sta topr
        sec
        lda cln
        sbc #1
        sta topln
        lda cln+1
        sbc #0
        sta topln+1
@x:     rts

; after an edit in one line: A = index of the new cursor position in that line
ed_line:
        jsr edpre
        lda lbn                 ; shift the later rows' line starts by the size change (T0/T1, signed)
        sec
        sbc olen
        sta T0
        ldx #0
        bcs @p
        dex
@p:     stx T1
        ldy drr
        iny
@s:     cpy #ROWS
        bcs @sd
        lda sl_hi,y
        cmp ls+1
        bne @c
        lda sl_lo,y
        cmp ls
@c:     beq @nx
        bcc @nx
        clc
        lda T0
        adc sl_lo,y
        sta sl_lo,y
        lda sl_hi,y
        adc T1
        sta sl_hi,y
        lda snext_hi,y          ; snext moves too (it is the start of a later line)
        and snext_lo,y
        cmp #$FF
        beq @nx
        clc
        lda T0
        adc snext_lo,y
        sta snext_lo,y
        lda snext_hi,y
        adc T1
        sta snext_hi,y
@nx:    iny
        bne @s
@sd:    lda edfull
        bne edfu
        ldx ni
        lda ur,x
        cmp orows
        bne edmore
        lda #1
        sta dmode
        sta dirty
        ldx efrom               ; start at the row of the first unit that can have changed
        cpx ni
        bcc @e1
        ldx ni
@e1:    stx dfrom
        lda ur,x
        sec
        sbc drk
        bcc @e2
        clc
        adc drr
        cmp #ROWS
        bcs @e2
        sta drr
        lda ur,x
        sta drk
        jmp toprows
@e2:    lda #0
        sta dfrom
        beq toprows

; load the cursor line again and put the cursor at line index A
edpre:  sta etgt
        jsr curline
        lda etgt
        jmp snap

; after an edit that changed the number of lines: A = index of the new cursor position in line ls
ed_lines:
        ldx #0                  ; the lines moved: nothing to put back
        stx ulv
        jsr edpre
        lda edfull
        bne edfu
edmore: lda #2                  ; the rows change: redraw to the bottom
        sta dmode
        .byte $2C
edfu:   lda #3                  ; redraw everything
        sta dirty

; if the top row is inside the cursor line and that line got shorter, keep the top row inside it
toprows:
        lda topl
        cmp ls
        bne @x
        lda topl+1
        cmp ls+1
        bne @x
        ldx ni
        lda ur,x
        cmp topr
        bcs @x
        sta topr
        lda #3
        sta dirty
@x:     rts

; ci = first unit at or after line index A
snap:   sta T0
        ldx #0
@l:     lda u,x
        cmp T0
        bcs @f
        inx
        cpx ni
        bcc @l
        beq @l
        ldx ni
@f:     stx ci
        rts

; ==========================================================================
; gap buffer
; ==========================================================================
newbuf: lda #<bufmem
        sta gaps
        lda #>bufmem
        sta gaps+1
        lda bufe
        sta gape
        lda bufe+1
        sta gape+1
        lda #0
        sta pre
        sta pre+1
        sta len
        sta len+1
        sta ls
        sta ls+1
        sta ci
        sta topl
        sta topl+1
        sta topr
        sta modf
        sta cln+1
        sta nlines+1
        sta topln+1
        sta ulv
        lda #1
        sta cln
        sta nlines
        sta topln
        rts

; insert A bytes (1-255) from (P3) at offset eoff. Carry set if memory is full.
insbytes:
        sta T3
        jsr gapto
        sec                     ; room = gape - gaps
        lda gape
        sbc gaps
        sta T1
        lda gape+1
        sbc gaps+1
        bne @ok
        lda T1
        cmp T3
        beq @full               ; keep one byte spare
        bcs @ok
@full:  lda #<m_full
        ldy #>m_full
        jsr setmsg
        jsr bell
        sec
        rts
@ok:    lda gaps
        sta P1
        lda gaps+1
        sta P1+1
        ldy #0
@c:     lda (P3),y
        sta (P1),y
        iny
        cpy T3
        bne @c
        lda T3
        jsr addgaps
        lda #1
        sta modf
        clc
        rts

addgaps:                        ; gaps, pre, len += A
        pha
        clc
        adc gaps
        sta gaps
        bcc @a
        inc gaps+1
@a:     pla
        pha
        clc
        adc pre
        sta pre
        bcc @b
        inc pre+1
@b:     pla
        clc
        adc len
        sta len
        bcc @c
        inc len+1
@c:     rts

; delete A bytes at offset eoff
delbytes:
        sta T3
        jsr gapto
        lda T3
        clc
        adc gape
        sta gape
        bcc @a
        inc gape+1
@a:     sec
        lda len
        sbc T3
        sta len
        bcs @b
        dec len+1
@b:     lda #1
        sta modf
        rts

; move the gap to offset eoff
gapto:  lda eoff
        cmp pre
        bne @ne
        lda eoff+1
        cmp pre+1
        bne @ne
        rts
@ne:    lda eoff
        cmp pre
        lda eoff+1
        sbc pre+1
        bcs @fwd
        sec                     ; backward: n = pre - eoff bytes move from before the gap to its end
        lda pre
        sbc eoff
        sta T1
        lda pre+1
        sbc eoff+1
        sta T2
        lda gaps
        sta P1
        lda gaps+1
        sta P1+1
        lda gape
        sta P2
        lda gape+1
        sta P2+1
        ldy #0
@bl:    lda P1
        bne @b1
        dec P1+1
@b1:    dec P1
        lda P2
        bne @b2
        dec P2+1
@b2:    dec P2
        lda (P1),y
        sta (P2),y
        lda T1
        bne @b3
        dec T2
@b3:    dec T1
        lda T1
        ora T2
        bne @bl
        jmp @done
@fwd:   sec                     ; forward: n = eoff - pre bytes move from after the gap to its start
        lda eoff
        sbc pre
        sta T1
        lda eoff+1
        sbc pre+1
        sta T2
        lda gape
        sta P1
        lda gape+1
        sta P1+1
        lda gaps
        sta P2
        lda gaps+1
        sta P2+1
        ldy #0
@fl:    lda (P1),y
        sta (P2),y
        inc P1
        bne @f1
        inc P1+1
@f1:    inc P2
        bne @f2
        inc P2+1
@f2:    lda T1
        bne @f3
        dec T2
@f3:    dec T1
        lda T1
        ora T2
        bne @fl
        lda P1
        sta gape
        lda P1+1
        sta gape+1
        lda P2
        sta gaps
        lda P2+1
        sta gaps+1
        jmp @set
@done:  lda P1
        sta gaps
        lda P1+1
        sta gaps+1
        lda P2
        sta gape
        lda P2+1
        sta gape+1
@set:   lda eoff
        sta pre
        lda eoff+1
        sta pre+1
        rts

; address of offset P3 -> P1
off2ptr:
        lda P3
        cmp pre
        lda P3+1
        sbc pre+1
        bcs @after
        clc
        lda P3
        adc #<bufmem
        sta P1
        lda P3+1
        adc #>bufmem
        sta P1+1
        rts
@after: sec
        lda P3
        sbc pre
        sta P1
        lda P3+1
        sbc pre+1
        sta P1+1
        clc
        lda P1
        adc gape
        sta P1
        lda P1+1
        adc gape+1
        sta P1+1
        rts

; P3 = the start of the line before the cursor line
prevls: lda ls
        sec
        sbc #1
        sta P3
        lda ls+1
        sbc #0
        sta P3+1
; start of the line that contains offset P3 -> P3
linestart:
@l:     lda P3
        ora P3+1
        beq @x
        lda P3
        bne @d
        dec P3+1
@d:     dec P3
        jsr off2ptr
        ldy #0
        lda (P1),y
        cmp #CR
        bne @l
        inc P3
        bne @x
        inc P3+1
@x:     rts

; load the line that starts at offset lnoff into lb (lbn bytes, lb[lbn] = CR); hascr = 1 if a CR ends it
loadline:
        lda lnoff
        sta P3
        lda lnoff+1
        sta P3+1
        jsr off2ptr
        ldx #0
@seg:   sec                     ; T1 = the bytes from P1 to the gap or to the end of the text (at most 255):
        lda gaps                ; they are copied without looking for the gap at every byte
        sbc P1
        sta T1
        lda gaps+1
        sbc P1+1
        bcc @aft                ; (P1 is after the gap)
        bne @big
        ldy T1
        bne @go
        lda gape                ; at the gap: over it
        sta P1
        lda gape+1
        sta P1+1
        bne @seg
@aft:   sec
        lda bufe
        sbc P1
        sta T1
        lda bufe+1
        sbc P1+1
        bne @big
        ldy T1
        bne @go
        tya                     ; the end of the text: no CR
        beq @d
@big:   lda #255
        sta T1
@go:    ldy #0
@l:     lda (P1),y
        cmp #CR
        beq @cr
        cpx #254
        bcs @s
        sta lb,x
        inx
@s:     iny
        cpy T1
        bne @l
        tya
        clc
        adc P1
        sta P1
        bcc @seg
        inc P1+1
        bne @seg
@cr:    lda #1
@d:     sta hascr
        stx lbn
        lda #CR
        sta lb,x
        rts

; the text byte at P1, which then moves on (it skips the gap). Carry set: the end of the text. Keeps X
tbyte:  lda P1
        cmp gaps
        bne @a
        lda P1+1
        cmp gaps+1
        bne @a
        lda gape
        sta P1
        lda gape+1
        sta P1+1
@a:     lda P1
        cmp bufe
        bne @b
        lda P1+1
        cmp bufe+1
        beq @x                  ; (carry set)
@b:     ldy #0
        lda (P1),y
        inc P1
        bne @c
        inc P1+1
@c:     clc
@x:     rts

; load and lay out the cursor line
curline:
        lda ls
        sta lnoff
        lda ls+1
        sta lnoff+1
        jsr loadline
        jsr layout
        lda ci
        cmp ni
        bcc @x
        lda ni
        sta ci
@x:     rts

; ==========================================================================
; layout of the line in lb: units (a character, or one Hangul syllable) with their column and row
;   u[i]  index in lb where the unit starts (a run's first unit starts at its Ctrl-K)
;   uc[i] column in the text area, ur[i] row of the line, uf[i] F_NEEDK / F_HAN
;   unit ni is the end of the line
; ==========================================================================
layout: lda #<lb
        sta SEGP
        lda #>lb
        sta SEGP+1
        ldx #0
        ldy #0
        stx T1                  ; column
        stx T2                  ; row
        stx T3                  ; inside a run
@next:  cpy lbn
        bcc @go
        jmp @end
@go:    lda lb,y
        cmp #HK
        bne @nk
        sty T4                  ; a run starts here
        iny
        lda #1
        sta T3
        lda lb,y
        cmp #HA
        bne @k1
        iny                     ; empty run: nothing to show
        lda #0
        sta T3
        jmp @next
@k1:    cpy lbn
        bcc @k2
        jmp @end
@k2:    lda #0
        sta T5
        jmp @seg
@nk:    cmp #HA
        bne @nk2
        iny                     ; a stray Ctrl-A
        lda #0
        sta T3
        jmp @next
@nk2:   sty T4
        lda T3
        beq @plain
        lda #F_NEEDK
        sta T5
@seg:   jsr segnext
        sta T0
        cmp #2
        bne @w1
        lda T5
        ora #F_HAN
        sta T5
@w1:    lda lb,y
        cmp #HA
        bne @place
        iny                     ; the run ends with this unit
        lda #0
        sta T3
        jmp @place
@plain: iny
        lda #1
        sta T0
        lda #0
        sta T5
@place: lda T1
        clc
        adc T0
        cmp tw
        beq @fits
        bcc @fits
        lda #0
        sta T1
        inc T2
@fits:  lda T4
        sta u,x
        lda T1
        sta uc,x
        lda T2
        sta ur,x
        lda T5
        sta uf,x
        lda T1
        clc
        adc T0
        sta T1
        inx
        cpx #255
        bcs @end
        jmp @next
@end:   lda T1
        cmp tw
        bcc @e2
        lda #0
        sta T1
        inc T2
@e2:    lda lbn
        sta u,x
        lda T1
        sta uc,x
        lda T2
        sta ur,x
        lda #0
        sta uf,x
        stx ni
        rts

; one syllable from (SEGP),Y (a byte inside a run). Out: Y past it, A = width (2, or 1 for a non-key byte)
; Same rules as two-set input: initial, vowel (+ second vowel), final (+ second final), and a final consonant that
; is followed by a vowel starts the next syllable instead.
segnext:
        stx sgx
        lda (SEGP),y
        jsr kcls
        bne @key
        iny
        lda #1
        jmp @ret
@key:   bmi @vow
        iny                     ; consonant
        lda (SEGP),y
        jsr kcls
        bmi @cv
        jmp @two                ; a consonant alone
@cv:    sta sgv
        iny
        lda (SEGP),y
        jsr kcls
        bpl @fin
        jsr vcomb
        bcc @two                ; a vowel that does not combine: next syllable
        iny
        lda (SEGP),y
        jsr kcls
@fin:   beq @two
        bmi @two
        sta sgc
        jsr canfin
        bcc @two
        iny
        lda (SEGP),y
        jsr kcls
        bmi @back
        beq @two
        sta sgd
        jsr clust
        bcc @two
        iny
        lda (SEGP),y
        jsr kcls
        bpl @two
@back:  dey
@two:   lda #2
@ret:   ldx sgx
        rts
@vow:   sta sgv                 ; a vowel alone (or two that combine)
        iny
        lda (SEGP),y
        jsr kcls
        bpl @two
        jsr vcomb
        bcc @two
        iny
        jmp @two

kcls:   cmp #$A0
        bcc @no
        sec
        sbc #$A0
        tax
        lda ktab,x
        rts
@no:    lda #0
        rts

vcomb:  ldx #NVCOMB-1           ; does sgv + A make one vowel? carry
@l:     cmp vcomb2,x
        bne @n
        pha
        lda sgv
        cmp vcomb1,x
        beq @y
        pla
@n:     dex
        bpl @l
        clc
        rts
@y:     pla
        sec
        rts

canfin: ldx #2                  ; can sgc end a syllable? carry
        lda sgc
@l:     cmp nofin,x
        beq @n
        dex
        bpl @l
        sec
        rts
@n:     clc
        rts

clust:  ldx #NCLUS-1            ; do sgc + sgd make a double final? carry
@l:     lda clus1,x
        cmp sgc
        bne @n
        lda clus2,x
        cmp sgd
        beq @y
@n:     dex
        bpl @l
        clc
        rts
@y:     sec
        rts

; ==========================================================================
; screen
; ==========================================================================
putc:   stx svx
        sty svy
        jsr @o
        ldx svx
        ldy svy
        rts
@o:     jmp (REALOUT)

; X = column, Y = row. BASL/BASH must point at K-HANGEUL's own text buffer row (the ROM's VTAB would point them at
; the text page: the driver then writes there, and a space at $0400 makes it think HOME was used and clear the screen)
gotoxy: sty CV
        stx CH
        lda rowlo,y
        sta BASL
        lda rowhi,y
        sta BASH
        rts

; the driver's row table: 16 rows of 46 bytes from $1980 (stock driver; its $940A stub starts with STA $C080),
; or from $DC2A in the card bank (Saturn arrangement; the stub starts with JSR)
mkrows: lda #<$1980
        sta P1
        lda #>$1980
        sta P1+1
        lda $940A
        cmp #$8D
        beq @s
        lda #<$DC2A
        sta P1
        lda #>$DC2A
        sta P1+1
@s:     ldy #0
@l:     lda P1
        sta rowlo,y
        lda P1+1
        sta rowhi,y
        clc
        lda P1
        adc #46
        sta P1
        bcc @n
        inc P1+1
@n:     iny
        cpy #16
        bcc @l
        rts

; print the digits of numbuf
putnum: ldx #0
@d:     lda numbuf,x
        jsr putc
        inx
        cpx numlen
        bcc @d
        rts

spaces: tax                     ; print A spaces (A may be 0)
        beq @x
@l:     lda #SPC
        jsr putc
        dex
        bne @l
@x:     rts

; number column width: digits of nlines + 1 when line numbers are shown
calcnumw:
        lda #0
        ldx nums
        beq @set
        ldx #nlines-pre
        jsr numld
        jsr utoa
        lda numlen
        clc
        adc #1
@set:   cmp numw
        beq @x
        sta numw
        lda #SCRW
        sec
        sbc numw
        sta tw
        lda #3
        sta dirty
@x:     rts

refresh:
        jsr calcnumw
        jsr curline
        lda #0
        sta tries
        lda dirty
        cmp #3
        bne @part
        lda cut                 ; a redraw that a key cut short: first see where the cursor is now
        bne @vis
        jmp @full
@part:  cmp #0
        beq @vis
        jsr drawfrom
        jsr curline
@vis:   jsr findrow
        bcs @nv
        lda cut
        beq @vok
        jmp @full
@vok:   jmp @ok
@nv:    jsr beforetop
        bcc @below
        lda cut                 ; above the screen. The row just above the top row: scroll down one row
        bne @top
        jsr isprev
        bcs @top
        jsr scroll2
        jsr curline
        jsr findrow
        bcs @top
        jmp @ok
@top:   jsr topcur              ; otherwise the cursor row becomes the top row and the screen is redrawn
        jmp @full
@below: jsr isnext
        bcs @far
        jsr scroll1
        jsr curline
        jsr findrow
        bcc @ok
@far:   jsr setbottom
@full:  lda #0
        sta cut
        sta drr
        jsr drtop
        lda #2
        sta dmode
        inc fulld               ; a key that arrives stops this redraw: the user is paging on
        jsr drawfrom
        dec fulld
        jsr curline
        lda cut
        beq @fd
        lda #3
        sta dirty
        bne @goal
@fd:    jsr findrow
        bcc @ok
        inc tries               ; the top was not valid: start the screen at the cursor line
        lda tries
        cmp #2
        bcs @ok
        jsr topcur
        lda #0
        sta topr
        beq @full
@ok:    lda #0
        sta dirty
@goal:  lda keepgoal
        bne @g
        ldx ci
        lda uc,x
        sta goal
@g:     rts

; the top row of the screen = the cursor's row
topcur: lda ls
        sta topl
        lda ls+1
        sta topl+1
        ldx ci
        lda ur,x
        sta topr
        lda cln
        sta topln
        lda cln+1
        sta topln+1
        rts
; the redraw starts with the top row
drtop:  lda topl
        sta drl
        lda topl+1
        sta drl+1
        lda topr
        sta drk
        lda topln
        sta drln
        lda topln+1
        sta drln+1
        rts

; the screen row of the cursor -> crow, carry clear if it is on the screen
findrow:
        ldx ci
        lda ur,x
        sta T0
        ldy #0
@l:     lda sv,y
        beq @n
        lda sl_lo,y
        cmp ls
        bne @n
        lda sl_hi,y
        cmp ls+1
        bne @n
        lda sr,y
        cmp T0
        beq @f
@n:     iny
        cpy #ROWS
        bcc @l
        sec
        rts
@f:     sty crow
        clc
        rts

; is the cursor row before the top row? carry
beforetop:
        lda ls+1
        cmp topl+1
        bne @c
        lda ls
        cmp topl
        bne @c
        ldx ci
        lda ur,x
        cmp topr
@c:     bcc @y
        clc
        rts
@y:     sec
        rts

; is the cursor row the row just below the screen? carry clear if so
isnext: ldy #ROWS-1
        lda sv,y
        beq @no
        ldx ci
        lda slast,y
        bne @last
        lda sl_lo,y
        cmp ls
        bne @no
        lda sl_hi,y
        cmp ls+1
        bne @no
        lda sr,y
        clc
        adc #1
        cmp ur,x
        bne @no
        clc
        rts
@last:  lda snext_lo,y
        cmp ls
        bne @no
        lda snext_hi,y
        cmp ls+1
        bne @no
        lda ur,x
        bne @no
        clc
        rts
@no:    sec
        rts

; is the cursor row the row just above the top row, and the top row valid? carry clear if so
isprev: lda sv
        beq @no
        ldx ci
        lda topr
        beq @pl
        lda ls                  ; the same line, one row up
        cmp topl
        bne @no
        lda ls+1
        cmp topl+1
        bne @no
        lda ur,x
        clc
        adc #1
        cmp topr
        bne @no
        clc
        rts
@pl:    lda ur,x                ; the last row of the line before the top line
        ldx ni
        cmp ur,x
        bne @no
        sec
        lda ls
        adc lbn                 ; + lbn + 1 (carry set): the start of the next line
        tay
        lda ls+1
        adc #0
        cmp topl+1
        bne @no
        cpy topl
        bne @no
        clc
        rts
@no:    sec
        rts

; scroll the text rows down by one and draw the cursor row at the top. Ctrl-V is K-HANGEUL's own control code for
; this (from Hangeul2): it moves the rows of the window down one, text buffer and pixels, and clears the top row.
scroll2:
        lda #ROWS
        sta WNDBTM
        ldx #0
        ldy #0
        jsr gotoxy
        lda #46                 ; (the driver's own width while it scrolls: it moves WNDWDTH bytes of each text row)
        sta WNDWDTH
        lda #$96
        jsr putc
        lda #WIDE
        sta WNDWDTH
        lda #16
        sta WNDBTM
        ldx rowlen+ROWS         ; (the status row's length is in the last slot)
        ldy #STABN-1            ; the ten row tables are one block: moving the block one byte moves every table
@s:     lda sl_lo-1,y           ; one row down. Slot 0 of each table gets a wrong byte; the row drawn below sets it
        sta sl_lo,y
        dey
        bne @s
        stx rowlen+ROWS
        sty rowlen
        sty drr
        jsr topcur
        jsr drtop
        lda #3                  ; one row only: the rows below it are already on the screen
        sta dmode
        jmp drawfrom

; scroll the text rows up by one (the driver scrolls inside the window) and draw the cursor row at the bottom
scroll1:
        lda #ROWS
        sta WNDBTM
        ldx #0
        ldy #ROWS-1
        jsr gotoxy
        lda #46
        sta WNDWDTH
        lda #CR
        jsr putc
        lda #WIDE
        sta WNDWDTH
        lda #16
        sta WNDBTM
        ldx rowlen+ROWS         ; (the status row's length is in the last slot)
        ldy #0                  ; the ten row tables are one block (see scroll2): every table moves one row up.
@s:     lda sl_lo+1,y           ; The bottom row's slots get wrong bytes; the row drawn below sets them
        sta sl_lo,y
        iny
        cpy #STABN-1
        bcc @s
        stx rowlen+ROWS
        lda #0
        sta rowlen+ROWS-1
        lda sl_lo
        sta topl
        lda sl_hi
        sta topl+1
        lda sr
        sta topr
        lda sln_lo
        sta topln
        lda sln_hi
        sta topln+1
        lda #ROWS-1
        sta drr
        lda ls
        sta drl
        lda ls+1
        sta drl+1
        ldx ci
        lda ur,x
        sta drk
        lda cln
        sta drln
        lda cln+1
        sta drln+1
        lda #1
        sta dmode
        jmp drawfrom

; choose the top so that the cursor row is the bottom row
setbottom:
        jsr topcur
        lda #ROWS-1
        sta sbcnt
@l:     lda sbcnt
        beq @x
        lda topr
        beq @pl
        dec topr
        dec sbcnt
        jmp @l
@pl:    lda topl
        ora topl+1
        beq @x
        lda topl
        sec
        sbc #1
        sta P3
        lda topl+1
        sbc #0
        sta P3+1
        jsr linestart
        lda P3
        sta topl
        sta lnoff
        lda P3+1
        sta topl+1
        sta lnoff+1
        jsr loadline
        jsr layout
        ldx ni
        lda ur,x
        sta topr
        lda topln
        bne @d
        dec topln+1
@d:     dec topln
        dec sbcnt
        jmp @l
@x:     rts

; draw rows from screen row drr: line drl (row drk of it, line number drln). dmode 1: only that line, 2: to the bottom,
; 3: only that row
drawfrom:
@line:  lda drr
        cmp #ROWS
        bcc @go
        rts
@go:    lda drl+1
        cmp #$FF
        bne @ld
        jmp @blank
@ld:    lda drl
        sta lnoff
        lda drl+1
        sta lnoff+1
        jsr loadline
        jsr layout
        ldx ni
        lda ur,x
        sta drows               ; rows - 1
@row:   lda drk
        cmp drows
        beq @r1
        bcc @r1
        jmp @nl
@r1:    lda drr
        cmp #ROWS
        bcc @r2
        rts
@r2:    lda fulld
        beq @r3
        lda TACNT
        bne @cut
        bit KBD
        bpl @r3
@cut:
        ldy drr                 ; a key is waiting: the rows from here are not valid, the next refresh draws them
        lda #0
@ct:    sta sv,y
        iny
        cpy #ROWS
        bcc @ct
        inc cut
        rts
@r3:    jsr drawrow
        lda #0
        sta dfrom
        ldy drr
        lda drl
        sta sl_lo,y
        lda drl+1
        sta sl_hi,y
        lda drk
        sta sr,y
        lda drln
        sta sln_lo,y
        lda drln+1
        sta sln_hi,y
        lda #1
        sta sv,y
        lda #0
        sta slast,y
        lda drk
        cmp drows
        bne @nl1
        lda #1
        sta slast,y
@nl1:   lda #$FF
        sta snext_lo,y
        sta snext_hi,y
        lda hascr
        beq @nn
        sec
        lda drl
        adc lbn
        sta snext_lo,y
        lda drl+1
        adc #0
        sta snext_hi,y
@nn:    inc drr
        inc drk
        lda dmode
        cmp #3
        beq @x
        jmp @row
@nl:    lda dmode
        cmp #1
        beq @x
        lda #0
        sta drk
        lda hascr
        beq @end
        sec
        lda drl
        adc lbn
        sta drl
        lda drl+1
        adc #0
        sta drl+1
        inc drln
        bne @l2
        inc drln+1
@l2:    jmp @line
@end:   lda #$FF
        sta drl
        sta drl+1
        jmp @line
@blank: ldy drr                 ; rows after the end of the text
        lda #0
        sta sv,y
        ldx #0
        jsr gotoxy
        ldy drr
        lda rowlen,y
        jsr spaces
        ldy drr
        lda #0
        sta rowlen,y
        inc drr
        jmp @line
@x:     rts

; draw screen row drr: row drk of the line laid out in lb (line number drln)
drawrow:
        lda #0
        sta dinrun
        ldx dfrom
        beq @whole
        lda ur,x
        cmp drk
        bne @whole
        lda uc,x                ; only from unit dfrom to the end of the row
        clc
        adc numw
        sta dcol
        tax
        ldy drr
        jsr gotoxy
        ldx dfrom
        jmp @f
@whole: ldx #0
        ldy drr
        jsr gotoxy
        lda #0
        sta dcol
        lda nums
        beq @t
        lda drk
        bne @nonum
        lda drln
        sta numv
        lda drln+1
        sta numv+1
        jsr utoa
        lda numw
        sec
        sbc numlen
        sec
        sbc #1
        jsr spaces
        jsr putnum
        lda #SPC
        jsr putc
        jmp @t1
@nonum: lda numw
        jsr spaces
@t1:    lda numw
        sta dcol
@t:     ldx #0
@f:     cpx ni
        bcs @er
        lda ur,x
        cmp drk
        bcc @nx
        bne @er
        jsr putunit
@nx:    inx
        jmp @f
@er:    lda dinrun
        beq @p
        lda #HA
        jsr putc
@p:     ldy drr
        lda rowlen,y
        sec
        sbc dcol
        bcc @np
        beq @np
        jsr spaces
@np:    ldy drr
        lda dcol
        sta rowlen,y
        rts

; print unit X (keeps X): adds its width to dcol, tracks dinrun
putunit:
        lda uf,x
        and #F_NEEDK
        beq @a
        lda dinrun
        bne @a
        lda #HK
        jsr putc
        lda #1
        sta dinrun
@a:     lda u+1,x
        sta T4
        ldy u,x
@l:     cpy T4
        bcs @w
        lda lb,y
        cmp #HK
        bne @b
        lda #1
        sta dinrun
        lda #HK
        bne @o
@b:     cmp #HA
        bne @c
        lda #0
        sta dinrun
        lda #HA
        bne @o
@c:     cmp #$A0
        bcs @o
        lda #'.'|$80
@o:     jsr putc
        iny
        jmp @l
@w:     lda uf,x
        bmi @two
        inc dcol
        rts
@two:   inc dcol
        inc dcol
        rts

curon:  lda #$3F
        sta INVFLG
        jsr curdraw
        lda #$FF
        sta INVFLG
        rts
curoff: lda #$FF
        sta INVFLG
curdraw:
        ldx ci
        lda uc,x
        clc
        adc numw
        tax
        ldy crow
        jsr gotoxy
        lda #0
        sta dinrun
        ldx ci
        cpx ni
        bcs @sp
        jsr putunit
        lda dinrun
        beq @x
        lda #HA
        jmp putc
@sp:    lda #SPC
        jmp putc
@x:     rts

; ---- status line ----
setmsg: sta msgp
        sty msgp+1
        rts

; append the zero-terminated string A/Y to sb
sbstr:  sta P1
        sty P1+1
        ldy #0
@l:     lda (P1),y
        beq @x
        ldx sbn
        sta sb,x
        inc sbn
        iny
        bne @l
@x:     rts
sbch:   stx sbx                 ; keeps X
        ldx sbn
        sta sb,x
        inc sbn
        ldx sbx
        rts
; numv = the 16-bit variable at pre + X (pre, len, eoff, ls, cln, nlines are one block)
numld:  lda pre,x
        sta numv
        lda pre+1,x
        sta numv+1
        rts
; append that variable (sbnx), or numv (sbnum), in decimal to sb
sbnx:   jsr numld
sbnum:  jsr utoa
sbdig:  ldx #0
@l:     lda numbuf,x
        jsr sbch
        inx
        cpx numlen
        bcc @l
        rts

status: lda stbg                ; the row is not an inverse bar (start, redraw, after the command line): paint it all
        bne @bar
        inc stbg
        lda #SCRW
        sta stlen
        lda #1
        sta stfull
@bar:   lda #0
        sta sbn
        lda msgp+1
        beq @st
        lda msgp
        ldy msgp+1
        jsr sbstr
        jmp @show
@st:    lda #<m_eng
        ldy #>m_eng
        ldx han
        beq @e
        lda #<m_han
        ldy #>m_han
@e:     jsr sbstr
        ldy #0
@cs:    lda abc,y
        ldx lower
        beq @cs1
        ora #$20
@cs1:   jsr sbch
        iny
        cpy #3
        bcc @cs
        lda #<m_line
        ldy #>m_line
        jsr sbstr
        ldx #cln-pre
        jsr sbnx
        lda #'/'|$80
        jsr sbch
        ldx #nlines-pre
        jsr sbnx
        lda #<m_col
        ldy #>m_col
        jsr sbstr
        ldx ci
        lda uc,x
        clc
        adc #1
        sta numv
        lda #0
        sta numv+1
        jsr sbnum
        lda #<m_free            ; the bytes that can still be typed
        ldy #>m_free
        jsr sbstr
        jsr freenum
        jsr sbnum
        lda #SPC
        jsr sbch
        lda modf
        beq @nm
        lda #'*'|$80
        jsr sbch
        lda #SPC
        jsr sbch
@nm:    lda fnlen
        bne @fn
        lda #<m_noname
        ldy #>m_noname
        jsr sbstr
        jmp @show
@fn:    ldx #0
@f:     lda fname,x
        stx T5
        jsr sbch
        ldx T5
        inx
        cpx fnlen
        bcc @f
@show:  ldy #0                  ; first byte that differs from what is on the screen
@df:    cpy sbn
        bcs @dfe
        cpy osbn
        bcs @dfe
        lda sb,y
        cmp osb,y
        bne @dfe
        iny
        bne @df
@dfe:   lda #0
        sta stpart
        cpy sbn
        bne @chg
        cpy osbn
        bne @chg
        lda stfull
        bne @chg
        rts                     ; nothing changed
@chg:   lda stfull
        bne @k1
        lda msgp+1              ; (a message is drawn whole)
        bne @k0
        lda sbn
        cmp osbn
        bne @k0
        inc stpart              ; 1: the same length, a partial redraw is possible
        bne @k0
@k1:    ldy #0
@k0:    lda #$3F                ; the status line is inverse
        sta INVFLG
        lda #0
        sta stfull
        sty T1                  ; back to the start of a Hangul run if Y is inside one
        ldy #0
        ldx #0
@rs:    cpy T1
        bcs @rd
        lda sb,y
        cmp #HK
        bne @r1
        sty T2
        ldx #1
@r1:    cmp #HA
        bne @r2
        ldx #0
@r2:    iny
        bne @rs
@rd:    lda sbn                 ; stend = where the drawing stops: at the end,
        sta stend
        txa
        beq @sp
        lda T2
        sta T1
        jmp @nr
@sp:    lda stpart              ; or, when the length is the same and nothing changed inside a Hangul run, only up
        beq @nr                 ; to the last byte that differs (typing changes the column and the free bytes, not
        ldy sbn                 ; the name after them)
@le:    dey
        lda sb,y
        cmp osb,y
        beq @le
        iny
        sty T2
@lr:    cpy sbn                 ; is that byte inside a run? (a Ctrl-A comes before the next Ctrl-K)
        bcs @lo
        lda sb,y
        cmp #HK
        beq @lo
        cmp #HA
        beq @nr
        iny
        bne @lr
@lo:    lda T2
        sta stend
        inc stpart              ; 2: partial
@nr:    lda #<sb                ; columns of sb[0..T1)
        sta SEGP
        lda #>sb
        sta SEGP+1
        lda #1
        sta psdry
        lda T1
        ldx #SCRW
        jsr putstr
        sta T0
        lda #0
        sta psdry
        ldx T0
        ldy #STROW
        jsr gotoxy
        clc
        lda #<sb
        adc T1
        sta SEGP
        lda #>sb
        adc #0
        sta SEGP+1
        lda #SCRW
        sec
        sbc T0
        tax
        lda stend
        sec
        sbc T1
        jsr putstr
        clc
        adc T0
        sta T0
        lda stpart              ; a partial redraw: the rest of the row is as it was
        cmp #2
        beq @keep
        lda stlen
        sec
        sbc T0
        bcc @np
        beq @np
        jsr spaces
@np:    lda T0
        sta stlen
@keep:  lda #$FF
        sta INVFLG
        jsr barstrip
        lda msgp+1              ; after a message the status is drawn whole
        beq @rem
        lda #1
        sta stfull
@rem:
        ldy sbn                 ; remember what is shown
        sty osbn
@cp:    dey
        bmi @x
        lda sb,y
        sta osb,y
        jmp @cp
@x:     rts

abc:    .byte 'A'|$80, 'B'|$80, 'C'|$80

; The driver's 46 columns are 276 pixels wide, the screen is 280. The 4 pixels at the right of the status bar are
; painted here (bits 3-6 of the last byte, 39, of each of the 12 pixel lines of row 15), so that the bar spans the screen.
barstrip:
        ldx #11
@l:     lda stripl,x
        sta P1
        lda striph,x
        sta P1+1
        ldy #0
        lda (P1),y
        ora #$78
        sta (P1),y
        dex
        bpl @l
        rts

; print A bytes of the N-byte string at SEGP, at most X columns, never cutting a syllable. A = columns used
putstr: sta psn
        stx psmax
        lda #0
        sta pscol
        sta psin
        ldy #0
@l:     cpy psn
        bcs @end
        lda (SEGP),y
        cmp #HK
        bne @a
        lda #1
        sta psin
        lda #HK
        jsr psput
        iny
        jmp @l
@a:     cmp #HA
        bne @b
        lda #0
        sta psin
        lda #HA
        jsr psput
        iny
        jmp @l
@b:     lda psin
        beq @c
        sty T4                  ; a syllable
        jsr segnext
        sta T3
        clc
        adc pscol
        cmp psmax
        beq @s1
        bcs @end
@s1:    sta pscol
        sty T3
        ldy T4
@s2:    lda (SEGP),y
        jsr psput
        iny
        cpy T3
        bcc @s2
        jmp @l
@c:     lda pscol
        cmp psmax
        bcs @end
        lda (SEGP),y
        cmp #$A0
        bcs @d
        lda #'.'|$80
@d:     jsr psput
        inc pscol
        iny
        jmp @l
@end:   lda psin
        beq @x
        lda #HA
        jsr psput
@x:     lda pscol
        rts
psput:  ldx psdry
        bne @n
        jmp putc
@n:     rts

; 16-bit numv -> decimal digits in numbuf (bit 7 set), numlen
utoa:   lda #0
        sta numlen
        sta T5                  ; a digit has been written
        ldx #0
@pw:    lda #0
        sta T4
@sub:   lda numv
        cmp p10lo,x
        lda numv+1
        sbc p10hi,x
        bcc @dg
        lda numv
        sbc p10lo,x
        sta numv
        lda numv+1
        sbc p10hi,x
        sta numv+1
        inc T4
        jmp @sub
@dg:    lda T4
        ora T5
        bne @put
        cpx #4
        bne @nx
@put:   lda T4
        ora #'0'|$80
        ldy numlen
        sta numbuf,y
        inc numlen
        lda #1
        sta T5
@nx:    inx
        cpx #5
        bcc @pw
        rts
p10lo:  .byte <10000, <1000, <100, <10, <1
p10hi:  .byte >10000, >1000, >100, >10, >1

; ==========================================================================
; command line (ESC)
; ==========================================================================
command:
        lda #0
        sta cbn
@draw:  lda #$3F                ; the command line stays an inverse bar, like the status line
        sta INVFLG
        ldx #0
        ldy #STROW
        jsr gotoxy
        ldy #0                  ; the prompt (5 columns)
@p:     lda m_cmd,y
        beq @pe
        jsr putc
        iny
        bne @p
@pe:    lda #<cb
        sta SEGP
        lda #>cb
        sta SEGP+1
        lda cbn
        ldx #SCRW-7
        jsr putstr
        clc
        adc #6                  ; prompt and cursor
        sta T0
        lda #$FF                ; the cursor: a normal cell on the inverse bar
        sta INVFLG
        lda #SPC
        jsr putc
        lda #$3F
        sta INVFLG
        lda stlen
        sec
        sbc T0
        bcc @np0
        beq @np0
        jsr spaces
@np0:   lda #$FF
        sta INVFLG
@np:    lda T0
        sta stlen
        lda #1
        sta stfull
        jsr barstrip
@key:   jsr getkey
        cmp #$1B
        bne @k1
        rts                     ; cancel
@k1:    cmp #$0D
        bne @k2
        jmp runcmd
@k2:    cmp #$01
        bne @k3
        jsr k_han
        jmp @key
@k3:    cmp #$08
        beq @bs
        cmp #$13
        beq @bs
        cmp #$18
        beq @bs
        cmp #$7F
        beq @bs
        cmp #$20
        bcc @key
        ldx cbn
        cpx #60
        bcs @key
        sta T0
        lda han
        beq @plain
        lda T0
        jsr upcase
        sta T0
        jsr shmap               ; (Shift + R = ㄲ, as in the text)
        lda T0
        ora #$80
        sta T0
        jsr kcls
        beq @pl2
        ldx cbn                 ; a Hangul key
        beq @newrun
        lda cb-1,x
        cmp #HA
        bne @newrun
        lda #HA
        sta cb,x
        lda T0
        sta cb-1,x
        inc cbn
        jmp @draw
@newrun:
        lda #HK
        sta cb,x
        lda T0
        sta cb+1,x
        lda #HA
        sta cb+2,x
        inx
        inx
        inx
        stx cbn
        jmp @draw
@plain: lda T0
        ora #$80
        sta T0
@pl2:   ldx cbn
        lda T0
        sta cb,x
        inc cbn
        jmp @draw
@bs:    ldx cbn
        bne @bs1
        jmp @key
@bs1:   lda cb-1,x
        cmp #HA
        bne @one
        cpx #3
        bcc @one
        lda cb-3,x
        cmp #HK
        bne @key2
        dex                     ; Ctrl-K key Ctrl-A: remove all three
        dex
        dex
        stx cbn
        jmp @draw
@key2:  lda #HA                 ; remove the key before the Ctrl-A
        sta cb-2,x
        dec cbn
        jmp @draw
@one:   dec cbn
        jmp @draw

; parse cb: command word (cw), force flag ('!'), argument (cb from argp, argn bytes)
runcmd: ldy #0
        jsr skipsp
        cpy cbn
        bcc @w
        rts
@w:     lda #0
        sta cwn
        sta force
        lda cb,y
        cmp #'/'|$80
        bne @nsl
        iny
        sty argp
        jsr argend
        jmp cmd_f
@nsl:   cmp #'0'|$80
        bcc @nd
        cmp #'9'|$80+1
        bcs @nd
        sty argp
        jsr argend
        jmp cmd_g
@nd:    cmp #HK
        bne @eng
        iny                     ; a Korean word: the keys of the first run
@kl:    cpy cbn
        bcs @wd
        lda cb,y
        cmp #HA
        beq @ke
        ldx cwn
        sta cw,x
        inc cwn
        iny
        jmp @kl
@ke:    iny
        jmp @wd
@eng:   cpy cbn                 ; an English word: up to a space or '!'
        bcs @wd
        lda cb,y
        cmp #SPC
        beq @wd
        cmp #'!'|$80
        beq @wd
        and #$7F
        jsr upcase
        ora #$80
        ldx cwn
        sta cw,x
        inc cwn
        iny
        jmp @eng
@wd:    cpy cbn
        bcs @a
        lda cb,y
        cmp #'!'|$80
        bne @a
        inc force
        iny
@a:     jsr skipsp
        sty argp
        jsr argend
        ; look the word up
        lda #<cmdtab
        sta P1
        lda #>cmdtab
        sta P1+1
@t:     ldy #0
        lda (P1),y
        beq @bad
        cmp cwn
        bne @skip
        tax
@c:     iny
        lda (P1),y
        cmp cw-1,y
        bne @skip
        dex
        bne @c
        iny
        lda (P1),y
        sta P2
        iny
        lda (P1),y
        sta P2+1
        jmp (P2)
@skip:  ldy #0
        lda (P1),y
        clc
        adc #3
        adc P1
        sta P1
        bcc @t
        inc P1+1
        jmp @t
@bad:   lda #<m_badcmd
        ldy #>m_badcmd
        jmp setmsg

skipsp: cpy cbn
        bcs @x
        lda cb,y
        cmp #SPC
        bne @x
        iny
        bne skipsp
@x:     rts

argend: lda cbn                 ; argn = bytes from argp to the end, trailing spaces dropped
        sta T0
@l:     lda T0
        cmp argp
        beq @x
        tax
        lda cb-1,x
        cmp #SPC
        bne @x
        dec T0
        jmp @l
@x:     lda T0
        sec
        sbc argp
        sta argn
        rts

; argument -> file name (30 bytes, padded with spaces). Carry set if there is none.
argname:
        lda argn
        bne @y
        sec
        rts
@y:     ldx #0
        ldy argp
@l:     cpx argn
        bcs @pad
        cpx #30
        bcs @pad
        lda cb,y
        and #$7F
        jsr upcase
        ora #$80
        sta fname,x
        iny
        inx
        jmp @l
@pad:   stx fnlen
@p:     cpx #30
        bcs @x
        lda #SPC
        sta fname,x
        inx
        jmp @p
@x:     clc
        rts

cmd_q:  lda modf
        beq @x
        lda force
        bne @x
        lda #<m_unsaved
        ldy #>m_unsaved
        jmp setmsg
@x:     jmp quit

cmd_w:  jsr argname
        jmp save

cmd_wq: jsr argname
        jsr save
        bcs @x
        jmp quit
@x:     rts

cmd_e:  lda argn
        bne @l
        lda #<m_needname
        ldy #>m_needname
        jmp setmsg
@l:     jsr askdiscard
        bcs @x
        jsr keepname
        jsr argname
        jsr load
        bcc @x
        jmp backname
@x:     rts

keepname:
        ldx #29
@s:     lda fname,x
        sta fsave,x
        dex
        bpl @s
        lda fnlen
        sta fsavel
        rts
backname:
        ldx #29
@b:     lda fsave,x
        sta fname,x
        dex
        bpl @b
        lda fsavel
        sta fnlen
        rts

cmd_r:  lda argn
        bne @r
        lda #<m_needname
        ldy #>m_needname
        jmp setmsg
@r:     jsr keepname            ; read the other file under its own name, keep ours
        jsr argname
        jsr readin
        jmp backname

; new text. Unsaved changes: ask. Y saves first (it needs a file name), N drops the changes, any other key goes back
; Unsaved changes? Ask: Y saves first, N drops the changes, any other key cancels. Carry clear: go on (nothing to
; save, or saved, or dropped); carry set: stay (cancelled, or the save failed: the message says why)
askdiscard:
        lda modf
        beq @go
        lda force
        bne @go
        lda #<m_asksave
        ldy #>m_asksave
        jsr setmsg
        jsr status
        jsr getkey
        ldx #0
        stx msgp+1
        and #$5F                ; y = Y
        cmp #'N'
        beq @go
        cmp #'Y'
        bne @stay
        jsr save
        bcc @go
@stay:  sec
        rts
@go:    clc
        rts

; new text
cmd_n:  jsr askdiscard
        bcs @x
        jsr newbuf
        lda #0
        sta fnlen
        lda #3
        sta dirty
@x:     rts


cmd_nu: lda nums
        eor #1
        sta nums
        lda #3
        sta dirty
        rts

cmd_g:  jsr argnum
        lda T3
        ldx T4
        jmp gotolx

argnum: lda #0                  ; decimal argument -> T3/T4
        sta T3
        sta T4
        ldy argp
@l:     cpy cbn
        bcs @go
        lda cb,y
        and #$7F
        cmp #'0'
        bcc @go
        cmp #'9'+1
        bcs @go
        and #$0F
        pha
        lda T3                  ; T3/T4 = T3/T4 * 10 + digit
        sta T1
        lda T4
        sta T2
        asl T3
        rol T4
        asl T3
        rol T4
        clc
        lda T3
        adc T1
        sta T3
        lda T4
        adc T2
        sta T4
        asl T3
        rol T4
        pla
        clc
        adc T3
        sta T3
        bcc @n
        inc T4
@n:     iny
        jmp @l
@go:    rts

cmd_h:  lda #<helptxt
        sta P3
        lda #>helptxt
        sta P3+1
        ldx #0
@l:     stx T5
        jsr helpx
        jsr rowputz
        ldx T5
        inx
        cpx #HELPN
        bcc @l
        jsr rowclr
        jsr pause
        pha
        lda #3
        sta dirty
        pla
        cmp #$1B                ; ESC at the help: the command line; any other key goes back
        bne @x
        jmp command
@x:     rts

; The help line at P3 is copied to cb, and P3 moves on to the next line. A byte below $80 in it is a slot: an action
; number, replaced by "^" and the first key that runs that action ("^-" if none). SEGP then points to cb.
helpx:  ldy #0
        ldx #0
@l:     lda (P3),y
        beq @e
        iny
        cmp #$80
        bcs @c
        stx T4
        ldx #0
@f:     cmp keymap,x
        beq @g
        inx
        cpx #32
        bcc @f
        ldx #$ED                ; none: $ED + $C0 = '-'
@g:     txa
        clc
        adc #$C0
        pha
        ldx T4
        lda #$DE                ; '^'
        sta cb,x
        inx
        pla
@c:     sta cb,x
        inx
        bne @l
@e:     sta cb,x
        tya                     ; the next line starts after the 0
        sec
        adc P3
        sta P3
        bcc @n
        inc P3+1
@n:     lda #<cb
        sta SEGP
        lda #>cb
        sta SEGP+1
        rts

; print the zero-terminated string at SEGP as text row T5
rowputz:
        ldy #0
@l:     lda (SEGP),y
        beq @n
        iny
        bne @l
@n:     tya
; print the A bytes at SEGP as text row T5 (the whole row; it no longer shows text of the file). Keeps T5
rowput: pha
        ldx #0
        ldy T5
        jsr gotoxy
        pla
        ldx #SCRW
        jsr putstr
        ldx T5
        sta T0
        lda rowlen,x
        sec
        sbc T0
        bcc @np
        beq @np
        jsr spaces
@np:    ldx T5
        lda T0
        sta rowlen,x
        lda #0
        sta sv,x
        rts

; clear the text rows from row X down
rowclr: cpx #ROWS
        bcs @x
        stx T5
        lda #0
        jsr rowput
        ldx T5
        inx
        bne rowclr
@x:     rts

; "press a key" on the status line; A = the key
pause:  lda #<m_anykey
        ldy #>m_anykey
        jsr setmsg
        jsr status
        jsr getkey
        pha
        lda #0
        sta msgp+1
        pla
        rts

; numv = the free bytes of the text space
freenum:
        sec
        lda gape
        sbc gaps
        sta numv
        lda gape+1
        sbc gaps+1
        sta numv+1
        lda numv                ; one byte is kept spare
        bne @d
        dec numv+1
@d:     dec numv
        rts

; ---- info: size of the text and free memory ----
cmd_i:  lda #0
        sta sbn
        ldx #len-pre
        jsr sbnx
        lda #<m_bytes
        ldy #>m_bytes
        jsr sbstr
        jsr freenum
        jsr sbnum
sbmsg:  lda #0                  ; show sb as the message
        jsr sbch
        lda #<sb
        ldy #>sb
        jmp setmsg

; the disk named in the command's argument (cb from argp): DOS 3.3's "S6,D2", "D2", "S5", or digits: "2" = drive 2,
; "62" = slot 6 drive 2. It becomes the current disk (ddrv/dslot; what is not named stays). Carry set: not understood.
; argn = 0: no disk named
getdiskarg:
        lda #0
        sta nslot
        sta ndrv
        sta ndg
        sta T0                  ; 0 = no letter yet, 1 = after S, 2 = after D
        ldx argp
@l:     cpx cbn
        bcs @e
        lda cb,x
        inx
        and #$7F
        cmp #'a'
        bcc @u
        cmp #'z'+1
        bcs @u
        and #$DF
@u:     ldy #1
        cmp #'S'
        beq @m
        iny
        cmp #'D'
        bne @d
@m:     sty T0
        bne @l
@d:     sec
        sbc #'0'
        cmp #10
        bcs @l                  ; (anything else is ignored: commas, spaces)
        ldy T0
        beq @bare
        sta nslot-1,y           ; S6 -> nslot, D2 -> ndrv
        lda #0
        sta T0
        beq @l
@bare:  ldy ndg
        cpy #2
        bcs @bad
        sta nbd,y
        inc ndg
        bne @l
@e:     lda ndg
        beq @chk
        cmp #2
        beq @two
        lda nbd
        sta ndrv
        bne @chk
@two:   lda nbd
        sta nslot
        lda nbd+1
        sta ndrv
@chk:   lda nslot
        beq @ds
        cmp #8
        bcs @bad
@ds:    lda ndrv
        beq @ok
        cmp #3
        bcs @bad
@ok:    lda argn                ; (nothing named: fine)
        beq @good
        lda nslot
        ora ndrv
        beq @bad
@good:  lda nslot
        beq @s2
        sta dslot
@s2:    lda ndrv
        beq @d2
        sta ddrv
@d2:    clc
        rts
@bad:   sec
        rts

; CHD S6,D2 (디스크): the disk for E, R, W, LS from now on
cmd_chd:
        jsr getdiskarg
        bcs baddrv
        lda argn
        beq baddrv
        lda #0
        sta sbn
        lda #<m_disk0           ; "디스크 [S6,D2]"
        ldy #>m_disk0
        jsr sbstr
        lda dslot
        ora #$B0
        jsr sbch
        lda #<m_disk1
        ldy #>m_disk1
        jsr sbstr
        lda ddrv
        ora #$B0
        jsr sbch
        lda #']'|$80
        jsr sbch
        jmp sbmsg
baddrv: lda #<m_baddrv
        ldy #>m_baddrv
        jmp setmsg

; ---- catalog: the files of the disk, read with RWTS (VTOC, then the catalog sectors) ----
cmd_ls: jsr getdiskarg          ; LS [S6,D2]: the catalog of that disk (and it is the current disk from now on, as in DOS)
        bcc @go
        jmp baddrv
@go:    lda #0
        sta lsrow
        lda #17
        ldy #0
        jsr rdsec
        bcs @err
@sec:   jsr lsbuf
        ldy #1                  ; link to the next catalog sector
        lda (P2),y
        beq @end
        pha
        iny
        lda (P2),y
        tay
        sty lscur               ; (the catalog is on track 17)
        pla
        jsr rdsec
        bcs @err
        lda #$0B                ; 7 entries of 35 bytes from $0B
@ent:   sta lsoff
        jsr lsbuf
        ldy lsoff
        lda (P2),y
        beq @end                ; never used: the end of the catalog
        cmp #$FF
        beq @nx                 ; deleted
        jsr lsline
        bcs @stop
@nx:    lda lsoff
        clc
        adc #35
        bcc @ent                ; (the 8th would be at $100)
        bcs @sec
@end:   ldx lsrow
        jsr rowclr
        lda #0                  ; the last page: choose a file, or go back
        jsr lspick
@stop:  lda #3
        sta dirty
        rts
@err:   lda #8
        jsr dosmsg
        jmp @stop

; The listed rows are done: choose one with Ctrl-K / Ctrl-J, RETURN opens it, ESC goes back to the text, any other
; key shows the next page (A = 1 if there is one; on the last page it goes back).
; Carry set: stop listing (the text is shown again), clear: go on with the next page.
lspick: sta lsmore
        lda #0
        sta lssel
        lda lsrow
        beq @key                ; (an empty disk: nothing to choose)
@show:  lda #<m_lsask2
        ldy #>m_lsask2
        ldx lsmore
        beq @m
        lda #<m_lsask1
        ldy #>m_lsask1
@m:     jsr setmsg
        jsr status
        ldx lssel
        jsr invrow
@key:   jsr getkey
        pha
        lda lsrow
        beq @k1
        ldx lssel
        jsr invrow              ; the row is normal again on every key
@k1:    ldx #0
        stx msgp+1
        pla
        cmp #$1B
        beq @stop
        cmp #$0D
        beq @open
        cmp #$20
        bcs @nm
        tax
        lda keymap,x            ; the keys that move the cursor up and down also choose
@nm:
        cmp #$0B
        beq @up
        cmp #$0A
        beq @down
        lda lsmore
        beq @stop
        clc                     ; the next page
        rts
@stop:  sec
        rts
@up:    lda lssel
        beq @show
        dec lssel
        bpl @show
@down:  ldx lssel
        inx
        cpx lsrow
        bcs @show
        stx lssel
        bcc @show
@open:  lda lsrow
        beq @stop
        jsr askdiscard
        bcs @stop
        jsr keepname            ; (the name of the text, for if the file cannot be opened)
        ldx lssel
        lda lssec,x
        tay
        lda #17
        jsr rdsec               ; the sector of that entry again
        bcs @stop
        ldx lssel
        ldy lsoffs,x
        jsr lsbuf
        iny
        iny
        iny                     ; the name: 30 bytes from offset 3, as the file manager wants it
        ldx #0
@c:     lda (P2),y
        sta fname,x
        iny
        inx
        cpx #30
        bcc @c
        ldx #30                 ; its length: the spaces at the end do not count
@t:     dex
        bmi @z
        lda fname,x
        cmp #SPC
        beq @t
@z:     inx
        stx fnlen
        jsr load
        bcc @ok
        jsr backname
@ok:    sec
        rts

; the row X (0-14) of the screen shown the other way round: every pixel of its 12 lines turned over
invrow: lda #0
@m:     cpx #0
        beq @g
        clc
        adc #12
        dex
        jmp @m
@g:     sta T0
        lda #12
        sta T3
@l:     lda T0
        jsr hgrline
        ldy #39
@x:     lda (P1),y
        eor #$7F
        sta (P1),y
        dey
        bpl @x
        inc T0
        dec T3
        bne @l
        rts

; P1 = the address of hi-res pixel line A (0-191): $2000 + (y and 7) * $400 + ((y >> 3) and 7) * $80 + (y >> 6) * 40
hgrline:
        sta T1
        and #7
        asl a
        asl a
        ora #$20
        sta P1+1
        lda T1
        lsr a
        lsr a
        lsr a
        and #7
        lsr a                   ; A = block / 2, carry = block and 1
        pha
        lda #0
        ror a
        sta P1
        pla
        clc
        adc P1+1
        sta P1+1
        lda T1
        lsr a
        lsr a
        lsr a
        lsr a
        lsr a
        lsr a
        tax
        lda t40,x
        clc
        adc P1
        sta P1
        bcc @x
        inc P1+1
@x:     rts
t40:    .byte 0, 40, 80

lsbuf:  lda fmbuf+4
        sta P2
        lda fmbuf+5
        sta P2+1
        rts

; one catalog entry (P2),lsoff -> the next text row: lock mark, type, sectors, name.
; Carry set if ESC was pressed when a page was full.
lsline: lda lsrow
        cmp #ROWS
        bcc @go
        lda #1
        jsr lspick
        bcc @pg
        rts
@pg:    lda #0
        sta lsrow
        jsr lsbuf
@go:    ldx lsrow
        lda lscur
        sta lssec,x             ; where to find the entry again
        lda lsoff
        sta lsoffs,x
        lda #0
        sta sbn
        ldy lsoff
        iny
        iny
        lda (P2),y              ; type, bit 7 = locked
        sta T0
        lda #SPC
        bit T0
        bpl @u
        lda #'*'|$80
@u:     jsr sbch
        lda T0
        and #$7F
        ldx #3
@t:     cmp tyv,x
        beq @tf
        dex
        bpl @t
        lda #'?'|$80
        bne @tp
@tf:    lda tyc,x
@tp:    jsr sbch
        lda #SPC
        jsr sbch
        lda lsoff
        clc
        adc #33
        tay
        lda (P2),y              ; sectors
        sta numv
        iny
        lda (P2),y
        sta numv+1
        jsr utoa
        lda #3
        sec
        sbc numlen
        bcc @nz
        beq @nz
        tax
@z:     lda #SPC
        jsr sbch
        dex
        bne @z
@nz:    jsr sbdig
        lda #SPC
        jsr sbch
        lda lsoff               ; the name: 30 bytes, spaces at the end dropped
        clc
        adc #3
        sta T1
        clc
        adc #30
        tay
@tr:    dey
        cpy T1
        bcc @pr
        lda (P2),y
        cmp #SPC
        beq @tr
@pr:    iny
        sty T2
        ldy T1
@nm:    cpy T2
        bcs @out
        lda (P2),y
        jsr sbch
        iny
        bne @nm
@out:   lda #<sb
        sta SEGP
        lda #>sb
        sta SEGP+1
        lda lsrow
        sta T5
        lda sbn
        jsr rowput
        inc lsrow
        clc
        rts

tyv:    .byte 0, 1, 2, 4
tyc:    .byte 'T'|$80, 'I'|$80, 'A'|$80, 'B'|$80

; read track A, sector Y into the sector buffer. Carry set on error.
rdsec:  sta T1
        sty T2
        jsr LOCRPL
        sty P1
        sta P1+1
        lda dslot
        asl a
        asl a
        asl a
        asl a
        ldy #1
        sta (P1),y
        iny
        lda ddrv
        sta (P1),y
        iny
        lda #0                  ; any volume
        sta (P1),y
        iny
        lda T1
        sta (P1),y
        iny
        lda T2
        sta (P1),y
        ldy #8
        lda fmbuf+4
        sta (P1),y
        iny
        lda fmbuf+5
        sta (P1),y
        ldy #$0C
        lda #1                  ; read
        sta (P1),y
        ldy P1
        lda P1+1
        jsr RWTS
        lda #0
        sta $48
        rts

; ==========================================================================
; search
; ==========================================================================
cmd_f:  lda argn
        beq k_findn
        lda #0                  ; the pattern: bytes with their "inside a run" flag, markers dropped
        sta patn
        sta T0
        ldy argp
@l:     cpy cbn
        bcs @done
        lda cb,y
        cmp #HK
        bne @a
        lda #1
        sta T0
        bne @nx
@a:     cmp #HA
        bne @b
        lda #0
        sta T0
        beq @nx
@b:     ldx T0
        bne @c
        jsr fold
@c:     ldx patn
        sta pat,x
        lda T0
        sta patf,x
        inc patn
@nx:    iny
        jmp @l
@done:  ; fall into the search

k_findn:
        lda patn
        bne @go
        rts
@go:    lda ls
        sta fl
        lda ls+1
        sta fl+1
        lda cln
        sta fln
        lda cln+1
        sta fln+1
        lda #0
        sta fwrap
        ldx ci                  ; start after the cursor's unit
        cpx ni
        bcs @nextl
        lda u+1,x
        sta fstart
        jmp @try
@try:   jsr matchline
        bcs @found
@nextl: lda #0
        sta fstart
        lda hascr
        beq @wrap
        sec
        lda fl
        adc lbn
        sta fl
        lda fl+1
        adc #0
        sta fl+1
        inc fln
        bne @ld
        inc fln+1
        jmp @ld
@wrap:  lda fwrap
        bne @nf
        inc fwrap
        lda #0
        sta fl
        sta fl+1
        sta fln+1
        lda #1
        sta fln
@ld:    lda fwrap               ; after wrapping, stop past the starting line
        beq @ld2
        lda fl+1
        cmp ls+1
        bne @c1
        lda fl
        cmp ls
@c1:    beq @ld2
        bcs @nf
@ld2:   lda fl
        sta lnoff
        lda fl+1
        sta lnoff+1
        jsr loadline
        jmp @try
@nf:    lda #<m_notfound
        ldy #>m_notfound
        jsr setmsg
        jmp curline
@found: sty fpos
        lda fl
        sta ls
        lda fl+1
        sta ls+1
        lda fln
        sta cln
        lda fln+1
        sta cln+1
        jsr layout
        ldx #0                  ; the unit that holds the match
@u:     inx
        cpx ni
        beq @u1
        bcs @u1
        lda u,x
        cmp fpos
        beq @u2
        bcc @u
@u1:    dex
@u2:    stx ci
        rts

fold:   cmp #$E1
        bcc @x
        cmp #$FB
        bcs @x
        and #$DF
@x:     rts

; find the pattern in lb at or after index fstart. Carry set and Y = start when found
matchline:
        lda #0
        sta T0                  ; inside a run at s
        ldy #0
@s:     cpy lbn
        bcs @no
        lda lb,y
        cmp #HK
        bne @a
        lda #1
        sta T0
        bne @nx
@a:     cmp #HA
        bne @b
        lda #0
        sta T0
        beq @nx
@b:     cpy fstart
        bcc @nx
        sty T1                  ; try here
        lda T0
        sta T2
        lda #0
        sta pidx
@m:     ldx pidx
        cpx patn
        bcs @yes
        cpy lbn
        bcs @fail
        lda lb,y
        cmp #HK
        bne @m1
        lda #1
        sta T2
        iny
        bne @m
@m1:    cmp #HA
        bne @m2
        lda #0
        sta T2
        iny
        bne @m
@m2:    lda T2
        cmp patf,x
        bne @fail
        lda lb,y
        ldx T2
        bne @m3
        jsr fold
@m3:    ldx pidx
        cmp pat,x
        bne @fail
        inc pidx
        iny
        bne @m
@fail:  ldy T1
@nx:    iny
        jmp @s
@yes:   ldy T1
        sec
        rts
@no:    clc
        rts

; ==========================================================================
; files (DOS 3.3 file manager)
; ==========================================================================
; set up the parameter list: A = call type. Common fields: drive, slot, type 0, name, the three buffers.
fmset:  pha
        jsr LOCFPL
        sty P2
        sta P2+1
        ldy #11
        lda #0
@z:     sta (P2),y              ; clear bytes 1-11
        dey
        bne @z
        pla
        sta (P2),y
        cmp #1
        bne @nr
        ldy #2                  ; OPEN: record length 1, as DOS's own OPEN for a sequential file
        sta (P2),y
@nr:    cmp #2                  ; CLOSE, READ, WRITE: bytes 2-9 are record, offset, length, address
        bcc @nm
        cmp #5
        bcc @buf
@nm:    ldy #5
        lda ddrv                ; the current disk (the DOS default until CHD or LS names another)
        sta (P2),y
        iny
        lda dslot
        sta (P2),y
        ldy #8
        lda fnp
        sta (P2),y
        iny
        lda fnp+1
        sta (P2),y
@buf:   ldy #$11                ; work area, T/S list buffer, data buffer: bytes $0C-$11
@b1:    lda fmbuf-$0C,y
        sta (P2),y
        dey
        cpy #$0C
        bcs @b1
        rts

; the file manager's buffers: a free DOS file buffer (one whose name field is empty; the last one if all are taken,
; which cannot be when KEDIT has just been loaded). After its 30-byte name come the addresses of the work area, the
; T/S list buffer and the data buffer, then the link to the next buffer.
findbuf:
        lda DOSBUFS
        sta P1
        lda DOSBUFS+1
        sta P1+1
@l:     ldy #0
        lda (P1),y
        beq @take
        ldy #$25
        lda (P1),y
        beq @take
        pha
        dey
        lda (P1),y
        sta P1
        pla
        sta P1+1
        bne @l
@take:  ldy #$1E
        ldx #0
@c:     lda (P1),y
        sta fmbuf,x
        iny
        inx
        cpx #6
        bcc @c
        rts

; call the file manager, X = 0 (create the file if it is missing) or 1. A = return code, carry set on error
fmcall: jsr FMGR
        ldy #$0A
        lda (P2),y
        cmp #1
        bcs @e
        clc
@e:     rts

; Read the key map from the file KEYS (written by KEYCFG with BSAVE: 4 header bytes, then the 32 map bytes) into
; keymap. Carry set: no usable file (missing, not 32 bytes, or an action number above 31): the map is left as it is.
loadkeys:
        lda #<keysname
        ldy #>keysname
        jsr setname
        lda #1                  ; OPEN (it is a binary file: its type is not looked at)
        jsr fmset
        ldx #1
        jsr fmcall
        bcs @no
        lda #<cw                ; the 36 bytes are read into cw (64 bytes, not in use yet)
        sta P3
        lda #>cw
        sta P3+1
        lda #36
        sta T1
        lda #0
        sta T2
        jsr fmread              ; (closes the file; on an error it sets a message, which the caller replaces)
        bcs @no
        lda cw+2                ; the header's length field
        cmp #32
        bne @no
        ldx #31
@c:     lda cw+4,x
        cmp #32
        bcs @no
        dex
        bpl @c
        ldx #31
@m:     lda cw+4,x
        sta keymap,x
        dex
        bpl @m
        clc
        rts
@no:    sec
        rts

keysname:
        .byte $CB,$C5,$D9,$D3   ; KEYS, then spaces to 30 bytes
        .res 26,$A0

fmclose:
        lda #2
        jsr fmset
        ldx #1
        jmp fmcall

; read/write a range: A = call type (3 or 4), X = subcode, P3 = address, T1/T2 = length field
fmrange:
        stx fmsub
        jsr fmset
        ldy #1
        lda fmsub
        sta (P2),y
        ldy #6
        lda T1
        sta (P2),y
        iny
        lda T2
        sta (P2),y
        iny
        lda P3
        sta (P2),y
        iny
        lda P3+1
        sta (P2),y
        ldx #1
        jmp fmcall

; DOS error A -> message
dosmsg: ldx #4
@l:     cmp dmc,x
        beq @f
        dex
        bpl @l
        sta numv                ; "disk error N"
        lda #0
        sta numv+1
        sta sbn
        lda #<m_diskerr
        ldy #>m_diskerr
        jsr sbstr
        jsr sbnum
        jmp sbmsg
@f:     lda dml,x
        ldy dmh,x
        jmp setmsg
dmc:    .byte 4, 6, 9, 10, 8
dml:    .byte <m_wprot, <m_nofile, <m_dfull, <m_locked, <m_ioerr
dmh:    .byte >m_wprot, >m_nofile, >m_dfull, >m_locked, >m_ioerr

; the name the next OPEN, DELETE or RENAME works on: A/Y, or fname
realname:
        lda #<fname
        ldy #>fname
setname:
        sta fnp
        sty fnp+1
        rts

; DELETE the file named A/Y. A missing file is fine. Carry set on error (A = code)
fmdel:  jsr setname
        lda #5
        jsr fmset
        ldx #1
        jsr fmcall
        bcc @x
        cmp #6
        beq @ok
        sec
        rts
@ok:    clc
@x:     rts

rmtemp: lda #<tmpname
        ldy #>tmpname
        jmp fmdel

; save the text under fname. Carry set on error.
; The text is first written to the file KEDIT.TMP. Only when that file is whole and closed is the old file deleted and
; KEDIT.TMP renamed, so a disk error while writing leaves the old file as it was. If the disk has no room for both
; (DISK FULL), the old file is deleted first and the text written in its place, as KEDIT did before 1.3.
save:   lda fnlen
        bne @s
        lda #<m_needname
        ldy #>m_needname
        jsr setmsg
        sec
        rts
@s:     jsr gapend              ; no text (only spaces and empty lines): nothing is saved
        jsr wrlast
        bcc @s1
        lda #<m_emptysave
        ldy #>m_emptysave
        jsr setmsg
        sec
        rts
@s1:    lda #<tmpname
        ldy #>tmpname
        jsr writeto
        bcs @tf
        jsr realname            ; the old file goes (locked or write protected: it stays, and the new copy goes)
        jsr fmdel
        bcs @tf
        lda #<tmpname
        ldy #>tmpname
        jsr setname
        lda #9                  ; RENAME KEDIT.TMP: bytes 2-3 of the list are the address of the new name
        jsr fmset
        ldy #2
        lda #<fname
        sta (P2),y
        iny
        lda #>fname
        sta (P2),y
        ldx #1
        jsr fmcall
        bcs @err
@ok:    lda #0
        sta modf
        lda #<m_saved
        ldy #>m_saved
        jsr setmsg
        clc
        rts
@tf:    pha
        jsr rmtemp
        pla
        cmp #9
        bne @err
        jsr realname            ; no room for a second copy
        jsr writeto
        bcc @ok
@err:   jsr dosmsg
        jsr bell
        sec
        rts

tmpname:
        .byte $CB,$C5,$C4,$C9,$D4,$AE,$D4,$CD,$D0       ; "KEDIT.TMP", padded to 30
        .res 21, $A0

; write the text to the file named A/Y (an old file of that name is deleted first). Carry set on error (A = code)
; ---- the trimmed file (save) ----
; The text is written as lines: each line without the spaces at its end, each with its CR. The empty lines after the
; last line with text are not written. The gap must be at the end of the text (gapend). The text is not changed.
; wend = the end of the text; wlast = the end of the last character that is not a space or a CR (= bufmem: none).
gapend: lda len                 ; the gap goes to the end of the text
        sta eoff
        lda len+1
        sta eoff+1
        jsr gapto
        lda #<bufmem
        clc
        adc len
        sta wend
        lda #>bufmem
        adc len+1
        sta wend+1
        rts

; wlast from the text: carry set if there is no character to write (the text is blank)
wrlast: lda #<bufmem
        sta wp
        sta wlast
        lda #>bufmem
        sta wp+1
        sta wlast+1
@l:     jsr wpend
        bcs @x
        jsr wpget
        cmp #SPC
        beq @n
        cmp #CR
        beq @n
        lda wp
        clc
        adc #1
        sta wlast
        lda wp+1
        adc #0
        sta wlast+1
@n:     jsr wpinc
        jmp @l
@x:     lda wlast               ; (carry: clear if there is text)
        cmp #<bufmem
        bne @t
        lda wlast+1
        cmp #>bufmem
        beq @none
@t:     clc
        rts
@none:  sec
        rts

; the lines to the file (carry set: a DOS error, A = its code). T5 = the mode of the next write (4 at the first)
wrtrim: lda #4
        sta T5
        lda #<bufmem
        sta wls
        lda #>bufmem
        sta wls+1
@l2:    lda wls+1               ; the line starts before wlast: otherwise the rest is blank
        cmp wlast+1
        bcc @go
        bne @fin
        lda wls
        cmp wlast
        bcc @go
@fin:   clc
        rts
@go:    lda wls
        sta wp
        sta wce
        lda wls+1
        sta wp+1
        sta wce+1
@sc:    lda wp+1                ; wp >= wlast: the line ends here
        cmp wlast+1
        bcc @in
        bne @ln
        lda wp
        cmp wlast
        bcs @ln
@in:    jsr wpget
        cmp #CR
        beq @ln
        cmp #SPC
        beq @sk
        lda wp                  ; a character: the line's text ends after it
        clc
        adc #1
        sta wce
        lda wp+1
        adc #0
        sta wce+1
@sk:    jsr wpinc
        jmp @sc
@ln:    lda wce+1               ; the text of the line: wls to wce (none when wce = wls)
        cmp wls+1
        bne @gt
        lda wce
        cmp wls
        beq @nt
@gt:    lda wls
        sta P3
        lda wls+1
        sta P3+1
        sec
        lda wce
        sbc wls
        sta T1
        lda wce+1
        sbc wls+1
        sta T2
        lda T1                  ; the length field is the count less one
        bne @c1
        dec T2
@c1:    dec T1
        lda #4
        ldx T5
        jsr fmrange
        bcs @err
        lda #2
        sta T5
@nt:    jsr wrcr                ; the CR of the line
        bcs @err
        jsr wpinc               ; the next line starts after the CR (or after wlast when there is no CR)
        lda wp
        sta wls
        lda wp+1
        sta wls+1
        jmp @l2
@done:  clc
        rts
@err:   sec
        rts

; the CR (the mode of the first write is 3, of the others 1; then 2 for the next)
wrcr:   lda #4
        jsr fmset
        ldy #1
        lda T5
        cmp #4
        beq @c3
        lda #1
        bne @c4
@c3:    lda #3
@c4:    sta (P2),y
        ldy #8
        lda #CR
        sta (P2),y
        ldx #1
        jsr fmcall
        bcs @x
        lda #2
        sta T5
@x:     rts

; wp (a pointer in the text): the byte at wp -> A; wp + 1; wp >= wend (carry set) / wp >= wlast (carry set)
wpget:  lda wp
        sta P1
        lda wp+1
        sta P1+1
        ldy #0
        lda (P1),y
        rts
wpinc:  inc wp
        bne @x
        inc wp+1
@x:     rts
wpend:  lda wp+1
        cmp wend+1
        bne @h
        lda wp
        cmp wend
@h:     rts

writeto:
        jsr fmdel
        bcs @x
        lda #1                  ; OPEN, create it (FILE NOT FOUND here means it was created)
        jsr fmset
        ldx #0
        jsr fmcall
        bcc @w
        cmp #6
        beq @w
        sec
@x:     rts
@w:     jsr gapend              ; the gap to the end: the text is one piece at bufmem
        jsr wrtrim
        bcs @errc
        jmp fmclose
@errc:  pha
        jsr fmclose
        pla
        sec
        rts

; load fname into an empty buffer
load:   jsr fmopen
        bcc @r
        cmp #6
        bne @e
        jsr newbuf              ; a new file
        lda #<m_newfile
        ldy #>m_newfile
        jsr setmsg
        lda #3
        sta dirty
        clc
        rts
@e:     cmp #0
        beq @e2                 ; the message is set already
        jsr dosmsg
@e2:    sec
        rts
@r:     jsr newbuf
        lda #<bufmem
        sta P3
        lda #>bufmem
        sta P3+1
        sec                     ; read at most the whole buffer less one byte
        lda bufe
        sbc #<bufmem
        sta T1
        lda bufe+1
        sbc #>bufmem
        sta T2
        lda T1
        bne @d
        dec T2
@d:     dec T1
        jsr fmread
        bcs @bad
        jsr scanin              ; P3 = bufs, limit T1/T2: n -> T3/T4, lines checked
        bcs @bad
        jsr gotin
        lda #0
        sta modf
        lda #<m_loaded
        ldy #>m_loaded
        jsr setmsg
        lda #3
        sta dirty
        clc
        rts
@bad:   jsr newbuf              ; nothing usable was read: an empty text with no name
        lda #0
        sta fnlen
        lda #3
        sta dirty
        clc
        rts

; insert the file fname at the cursor
readin: jsr fmopen
        bcc @r
        jmp dosmsg
@r:     jsr ed_begin
        ldx ci
        ldy u,x
        jsr yoff
        jsr gapto
        lda gaps
        sta P3
        lda gaps+1
        sta P3+1
        sec
        lda gape
        sbc gaps
        sta T1
        lda gape+1
        sbc gaps+1
        sta T2
        lda T1
        bne @d
        dec T2
@d:     dec T1
        jsr fmread
        bcc @rd1
        jmp @x
@rd1:   jsr scanin
        bcc @rd2
        jmp @x
@rd2:   lda T3                  ; take the bytes in: gaps, pre, len += n
        clc
        adc gaps
        sta gaps
        lda T4
        adc gaps+1
        sta gaps+1
        lda T3
        clc
        adc pre
        sta pre
        lda T4
        adc pre+1
        sta pre+1
        lda T3
        clc
        adc len
        sta len
        lda T4
        adc len+1
        sta len+1
        jsr countlines
        jsr chklines
        bcc @ok
        sec                     ; a line got too long: take the bytes out again
        lda gaps
        sbc T3
        sta gaps
        lda gaps+1
        sbc T4
        sta gaps+1
        sec
        lda pre
        sbc T3
        sta pre
        lda pre+1
        sbc T4
        sta pre+1
        sec
        lda len
        sbc T3
        sta len
        lda len+1
        sbc T4
        sta len+1
        jsr countlines
        lda #<m_longline
        ldy #>m_longline
        jsr setmsg
        jmp @x
@ok:    lda #1
        sta modf
        lda #<m_inserted
        ldy #>m_inserted
        jsr setmsg
@x:     lda #3
        sta dirty
        lda #0
        sta ulv
        jmp curline

fmopen: jsr realname
        lda #1                  ; OPEN an existing text file. Carry set on error (A = code)
        jsr fmset
        ldx #1
        jsr fmcall
        bcs @x
        ldy #7
        lda (P2),y
        and #$7F
        beq @x                  ; text (carry clear)
        jsr fmclose
        lda #<m_notext
        ldy #>m_notext
        jsr setmsg
        lda #0
        sec
@x:     rts

; read the range (P3, length T1/T2) and close. Carry set on error (message set). END OF DATA is the normal end.
fmread: lda P3                  ; clear the destination so that the text always ends with a 0
        sta P1
        lda P3+1
        sta P1+1
        lda T2
        sta T4                  ; whole pages, then T1 bytes
        ldy #0
        tya
@zp:    ldx T4
        beq @zr
@z1:    sta (P1),y
        iny
        bne @z1
        inc P1+1
        dec T4
        jmp @zp
@zr:    cpy T1
        beq @zd
        sta (P1),y
        iny
        jmp @zr
@zd:    sta (P1),y
        lda T1
        pha
        lda T2
        pha
        lda #3
        ldx #4
        jsr fmrange
        bcc @ok
        cmp #5
        beq @ok
        pha
        jsr fmclose
        pla
        jsr dosmsg
        pla
        pla
        sec
        rts
@ok:    jsr fmclose
        pla
        sta T2
        pla
        sta T1
        clc
        rts

; the text read at P3: its length (up to the first 0, at most T1/T2 + 1 bytes) -> T3/T4, a final CR dropped.
; Carry set (message set) if no 0 was found or a line is longer than MAXLN.
scanin: lda P3
        sta P1
        lda P3+1
        sta P1+1
        lda #0
        sta T3
        sta T4
        sta T0                  ; length of the current line
        ldy #0
@l:     lda T3                  ; at the limit: no end found
        cmp T1
        bne @rd
        lda T4
        cmp T2
        bne @rd
        jmp @big
@rd:    lda (P1),y
        beq @end
        cmp #CR
        bne @c
        lda #0
        sta T0
        beq @n
@c:     inc T0
        lda T0
        cmp #MAXLN+1
        bcc @n
        lda #<m_longline
        ldy #>m_longline
        jsr setmsg
        sec
        rts
@n:     inc P1
        bne @n1
        inc P1+1
@n1:    inc T3
        bne @l
        inc T4
        jmp @l
@big:   lda #<m_toobig
        ldy #>m_toobig
        jsr setmsg
        sec
        rts
@end:   lda T3                  ; drop one final CR
        ora T4
        beq @x
        lda P1
        bne @e1
        dec P1+1
@e1:    dec P1
        ldy #0
        lda (P1),y
        cmp #CR
        bne @x
        lda T3
        bne @e2
        dec T4
@e2:    dec T3
@x:     clc
        rts

; a fresh file of T3/T4 bytes at bufs: the gap goes after it
gotin:  clc
        lda #<bufmem
        adc T3
        sta gaps
        lda #>bufmem
        adc T4
        sta gaps+1
        lda T3
        sta pre
        sta len
        lda T4
        sta pre+1
        sta len+1

; nlines = number of CRs + 1
countlines:
        lda #1
        sta nlines
        lda #0
        sta nlines+1
        lda #<bufmem
        sta P1
        lda #>bufmem
        sta P1+1
@l:     jsr tbyte
        bcs @x
        cmp #CR
        bne @l
        inc nlines
        bne @l
        inc nlines+1
        bne @l
@x:     rts

; is every line at most MAXLN bytes? carry set if not
chklines:
        lda #<bufmem
        sta P1
        lda #>bufmem
        sta P1+1
@z:     ldx #0                  ; the length of the line
@l:     jsr tbyte
        bcs @ok
        cmp #CR
        beq @z
        inx
        cpx #MAXLN+1
        bcc @l
        rts                     ; (carry set)
@ok:    clc
        rts

        .segment "RODATA"
        .include "build/gen.inc"

        .segment "BSS"
savesp: .res 1
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
dcol:   .res 1
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
cwn:    .res 1
force:  .res 1
argp:   .res 1
argn:   .res 1
fnlen:  .res 1
lscur:  .res 1                  ; the catalog sector being listed
lsmore: .res 1
lssec:  .res ROWS               ; sector and offset of each listed row
lsoffs: .res ROWS
fnp:    .res 2                  ; the name for the file manager: fname or tmpname
fname:  .res 30
fsave:  .res 30
fsavel: .res 1
fmsub:  .res 1
pgcnt:  .res 1
sbcnt:  .res 1
gtl:    .res 2
nlen:   .res 1
etgt:   .res 1
fpos:   .res 1
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
patn:   .res 1
pidx:   .res 1
pat:    .res 64
patf:   .res 64
fstart: .res 1
fwrap:  .res 1
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
u:      .res 256
fmbuf:  .res 6
ddrv:   .res 1                  ; the current disk
dslot:  .res 1
taoff:  .res 1
dcnt:   .res 1
comp:   .res 1
compp:  .res 1
compn:  .res 1
fulld:  .res 1
holdv:  .res 1
holdn:  .res 1
ulv:    .res 1
wp:     .res 2                  ; the trimmed save (wrtrim): the scan pointer, the line start, the end of the text,
wls:    .res 2                  ; the end of the text written, the end of the line's text
wend:   .res 2
wlast:  .res 2
wce:    .res 2
ubn:    .res 1
uls:    .res 2
ub:     .res 252
hold:   .res 252
uc:     .res 256
ur:     .res 256
uf:     .res 256
bufmem:
