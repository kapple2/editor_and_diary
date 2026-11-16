; KEDIT 1.13 - a Korean text editor on K-HANGEUL (Apple II Plus, DOS 3.3, 48K + language card)
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
;
; The editor itself (keys, movement, editing, the gap buffer, layout, drawing, the command line, search, the file
; manager calls) is in ../common and is shared with KDIARY: see ../common/README.md. This file has what is KEDIT's
; own: the start, the file commands (E R W N LS CHD ...), the catalog, load and save, and the variables.

        .include "../common/defs.inc"

; ---- what the shared code needs from this program ----
; (KEDIT does not define TOPLINE or KDIARY: see ../common/README.md)
FASTCLR = 1                     ; rows are cleared with the driver's fast clear (../common/fastclr.s), not with blanks
.define TXTEND_LO bufe          ; the end of the text space is a variable here: HIMEM, found at the start
.define TXTEND_HI bufe+1
quit    := tobasic              ; leaving the editor ends the program

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
        ldx #ROWS-1             ; (the screen is clear: no text row needs blanks drawn)
        lda #0
@r:     sta rowlen,x
        dex
        bpl @r
        lda #SCRW               ; (the status row: drawn whole)
        sta rowlen+ROWS
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

        .include "../common/main.s"
        .include "../common/keys.s"
        .include "../common/move.s"
        .include "../common/edit.s"
        .include "../common/gap.s"
        .include "../common/layout.s"
        .include "../common/screen.s"
        .include "../common/fastclr.s"
        .include "../common/command.s"
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

        .include "../common/cmds.s"
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

        .include "../common/search.s"
        .include "../common/fm.s"
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

        .include "../common/count.s"
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
