; KDIARY shell: password, today's date, month calendar, list, the entry file (one random-access file per month).
;
; Month file "일기 20YY-MM" (file name in K-HANGEUL's key-letter form), opened with record length 1, so a "record
; number" is a byte position. Slot d (0-31) is at byte d*1280 (the high byte of the position is d*5):
;   slot 0: 32 bytes, encrypted: flags[0] = MAGIC, flags[d] = 1 if day d has an entry
;   slot d: 2 bytes length (plain), then the text (the editor's own form: bit 7 set, Hangul runs Ctrl-K..Ctrl-A, lines
;           end with $8D, no CR after the last line), encrypted. Only the bytes written take sectors.
; Encryption: byte i of a slot is XORed with pw[i mod n] + (d*7 + month*3 + year + 29*i) (mod 256). The password
; check file PWCHK holds the phrase below, encrypted the same way with d = month = year = 0.

MAGIC   = $5A
MAXM    = 96                    ; the list: at most this many months
pw1n    = ttn                   ; (the length of the first of the two new passwords, while they are asked)

; offsets in the block of dates and list positions that starts at yy (shellbss.s), for cp3 and cp2
D_CUR   = 0                     ; yy, mo, dy: the chosen date
D_OLD   = 3                     ; the date before a key moved it
D_TODAY = 6
D_SAVE  = 9                     ; the chosen date, kept while the list is shown
D_TG    = 12                    ; the date looked for in the list
D_N     = 15                    ; nm, nd: a position in the list while moving (month index, day)
D_SEL   = 17                    ; lsm, lsdy: the selection
D_TOP   = 19                    ; lpm, lpd: the first row of the page

; copy 3 bytes (a date) or 2 (a list position) inside that block: from offset X to offset Y. Keeps the carry
cp3:    jsr cp1
cp2:    jsr cp1
cp1:    lda yy,x
        sta yy,y
        inx
        iny
        rts

; ---------------------------------------------------------------------------------------------------------------
; the file manager
; ---------------------------------------------------------------------------------------------------------------
; the short transfers: address and length
siotab: .addr flags
        .byte 32
        .addr hold
        .byte 42
        .addr shdr
        .byte 2
        .addr chk
        .byte 8
        .addr chk2
        .byte 8
        .addr cw
        .byte 36
SI_FLAGS = 0
SI_HOLD = 3
SI_HDR  = 6
SI_CHK  = 9
SI_CHK2 = 12
SI_KEYS = 15

; a short positioned read (A = 3) or write (A = 4) at the start of slot X: Y = which (SI_*). Carry set on error
sio:    pha
        lda siotab,y
        sta P3
        lda siotab+1,y
        sta P3+1
        lda siotab+2,y
        sta T1
        lda #0
        sta T2
        pla
; positioned read (A = 3) or write (A = 4) of a range in slot X: P3 = address, T1/T2 = length. Carry set on error
slotio: ldy #0
        .byte $2C               ; (BIT: skips the next instruction)
slot2:  ldy #2                  ; the same, from byte 2 of the slot (the text)
        sty soff
        ldy #0
        sty soff+1
slotoff:
        stx T0                  ; (the byte position is slot * 1280 + soff)
        sta T5
        jsr fmset
        ldy #1
        lda #4                  ; position and range
        sta (P2),y
        lda T0
        asl a
        asl a
        adc T0                  ; slot * 5 = high byte of the byte position (RL = 1); no carry: the slot is 0-31
        adc soff+1
        ldy #3
        sta (P2),y
        dey
        lda soff
        sta (P2),y
        ldy #6
        lda T5                  ; a WRITE of field L writes L+1 bytes (found by test), a READ of L reads L
        lsr a                   ; carry set: a read
        lda T1
        bcs @r
        sec
        sbc #1
@r:     sta (P2),y
        iny
        lda T2
        sbc #0
        sta (P2),y
        iny
        lda P3
        sta (P2),y
        iny
        lda P3+1
        sta (P2),y
        ldx #1
        jmp fmcall

; open the month file of yy/mo, or the file named A/Y: it must exist (carry set if not, A = code)
mopn:   jsr mkname
mopen_r:
        ldx #1
mopx:   jsr setname
        lda #1
        jsr fmset               ; (keeps X)
        jmp fmcall
; open the file named A/Y, created if it is missing
mopen_c:
        ldx #0
        jsr mopx
        bcc @x
        cmp #6                  ; FILE NOT FOUND while creating: it was created
        bne @e
        clc
        rts
@e:     sec
@x:     rts

; the month file's name: the digits of yy and mo go into mname ("일기 20YY-MM", in the program file); A/Y = its address
mkname: lda yy
        ldx #MNPL+2
        jsr @two
        lda mo
        ldx #MNPL+5
        jsr @two
        lda #<mname
        ldy #>mname
        rts
@two:   ldy #$B0
@t:     cmp #10
        bcc @o
        sbc #10
        iny
        bne @t
@o:     ora #$B0
        sta mname+1,x
        tya
        sta mname,x
        rts

; ---------------------------------------------------------------------------------------------------------------
; encryption: XOR cl bytes at P1 with the stream. pw/pwn = the password
; ---------------------------------------------------------------------------------------------------------------
; P1 = A/Y, cl = X (a count below 256). A = 0 on return
cset:   sta P1
        sty P1+1
        stx cl
        lda #0
        sta cl+1
        rts

; the stream of the slot of day A (0: the flags) of the month yy/mo, from its start
crypt:  sta T0
        asl a
        asl a
        asl a
        sec
        sbc T0                  ; day * 7
        clc
        adc mo
        adc mo
        adc mo                  ; + month * 3 (no carry so far: at most 253)
        adc yy
crypt0: sta ca
        lda #0
        sta cj
; continue the stream (ca, cj) for the cl bytes at P1
cryptc: ldx cj
        ldy #0
@l:     lda cl
        bne @g
        dec cl+1
        bmi @x
@g:     dec cl
        lda pw,x
        clc
        adc ca
        eor (P1),y
        sta (P1),y
        lda ca
        clc
        adc #29
        sta ca
        inx
        cpx pwn
        bcc @s
        ldx #0
@s:     iny
        bne @l
        inc P1+1
        bne @l
@x:     stx cj
        rts

; ---------------------------------------------------------------------------------------------------------------
; the month file: flags, titles, entries
; ---------------------------------------------------------------------------------------------------------------
; the flags of the month yy/mo (from the disk; all 0 if there is no file)
loadflags:
        jsr mopn
        bcs zflags
        jsr rdflags
        jmp fmclose

; the file is open: read and decrypt slot 0 into flags (all 0 if it does not look right)
rdflags:
        jsr zflags
        lda #3
        ldx #0
        ldy #SI_FLAGS
        jsr sio
; flags holds slot 0 as it is in the file: decrypt it (all 0 if it does not look right)
flagchk:
        jsr flagcrypt
        lda flags
        cmp #MAGIC
        bne zflags
        ldx #31
@c:     lda flags,x
        cmp #2
        bcs zflags
        dex
        bne @c
        rts
zflags: ldx #31
        lda #0
@z:     sta flags,x
        dex
        bpl @z
        rts
flagcrypt:
        lda #<flags
        ldy #>flags
        ldx #32
        jsr cset
        jmp crypt               ; (A = 0: slot 0)

; the file is open: write flags back. Carry set on error
wrflags:
        lda #MAGIC
        sta flags
        jsr flagcrypt
        lda #4
        ldx #0
        ldy #SI_FLAGS
        jsr sio
        php
        pha
        jsr flagcrypt           ; back to plain
        pla
        plp
        rts

; the file is open: the title (first line, at most 40 bytes) of day X -> tt, ttn
gettitle:
        stx cd
        lda #0                  ; (the cut buffer is free here: the editor is not running)
        sta hold
        sta hold+1
        lda #3
        ldy #SI_HOLD
        jsr sio
        ldx #40
        lda hold+1
        bne @big
        lda hold
        cmp #41
        bcs @big
        tax
@big:   stx ttn
        txa
        beq @x
        lda #<(hold+2)
        ldy #>(hold+2)
        jsr cset
        lda cd
        jsr crypt
        ldx #0
@c:     lda hold+2,x
        cmp #CR
        beq @e
        sta tt,x
        inx
        cpx ttn
        bcc @c
@e:     stx ttn
@x:     rts

; the title of the chosen day -> tt, ttn
readtitle:
        lda #0
        sta ttn
        ldx dy
        lda flags,x
        beq @x
        jsr mopn
        bcs @x
        ldx dy
        jsr gettitle
        jmp fmclose
@x:     rts

; read the entry of the chosen day into the editor's buffer. Carry set: no entry (the buffer is not touched)
readentry:
        jsr mopn
        bcs @no
        lda #0                  ; the length
        sta shdr
        sta shdr+1
        lda #3
        ldx dy
        ldy #SI_HDR
        jsr sio
        lda shdr
        sta T3
        ldx shdr+1
        stx T4
        ora T4
        beq @no0
        lda T3
        cmp #<(MAXTXT+1)
        txa
        sbc #>(MAXTXT+1)
        bcs @no0
        jsr newbuf              ; the text is read into the text space, then decrypted there
        lda #<bufmem
        sta P3
        sta P1
        lda #>bufmem
        sta P3+1
        sta P1+1
        lda T3
        sta T1
        sta cl
        lda T4
        sta T2
        sta cl+1
        lda #3
        ldx dy
        jsr slot2
        jsr fmclose
        lda dy
        jsr crypt
        jsr gotin               ; (T3/T4 = the length)
        clc
        rts
@no0:   jsr fmclose
        sec
@no:    rts

; encrypt (or decrypt) the text in place: the part before the gap, then the part after it
savecrypt:
        lda #<bufmem
        sta P1
        lda #>bufmem
        sta P1+1
        lda pre
        sta cl
        lda pre+1
        sta cl+1
        lda dy
        jsr crypt
        lda gape
        sta P1
        lda gape+1
        sta P1+1
        sec
        lda #<BUFE
        sbc gape
        sta cl
        lda #>BUFE
        sbc gape+1
        sta cl+1
        jmp cryptc

; the editor's save (ESC W): write the text as the entry of the chosen day (no text: the entry is deleted, after a question
; if there was one). The text saved is a trimmed copy (trimtxt): the spaces at the end of each line and the empty lines
; after the last text line are not written. The editor's text is not changed. Carry set: not saved (the text stays)
save:   jsr trimtxt
        lda tlen
        ora tlen+1
        bne @w
        ldx dy                  ; no text: an entry that is there goes, after a question (not again after the D key's)
        lda flags,x
        beq @nod
        lda sure
        bne @nod
        lda #<m_askempty
        ldy #>m_askempty
        jsr barkey
        and #$DF
        cmp #'Y'
        beq @nod
        lda #<m_notsaved
        ldy #>m_notsaved
        jsr setmsg
        sec
        rts
@nod:   jsr mopn                ; no text: delete the entry, if the month has a file
        bcc @go
        jmp @done
@w:     jsr mkname
        jsr mopen_c
        bcc @go
        jmp @err0
@go:    jsr rdflags
        lda tlen
        sta shdr
        lda tlen+1
        sta shdr+1
        lda #4
        ldx dy
        ldy #SI_HDR
        jsr sio
        bcc @h
        jmp @err
@h:     lda tlen
        ora tlen+1
        beq @fl
        jsr crypttrim           ; the copy is encrypted in place (it is not used again)
        lda #<SCR
        sta P3
        lda #>SCR
        sta P3+1
        lda tlen
        sta T1
        lda tlen+1
        sta T2
        lda #4
        ldx dy
        jsr slot2
        bcs @err
@fl:    ldx dy
        lda tlen
        ora tlen+1
        beq @f
        lda #1
@f:     sta flags,x
        jsr wrflags
        bcs @err
        jsr fmclose
@done:  lda #0
        sta modf
        lda #<m_saved
        ldy #>m_saved
        jsr setmsg
        clc
        rts
@err:   pha
        jsr fmclose
        pla
@err0:  jsr dosmsg
        jsr bell
        sec
        rts

; The text in SCR (the copy for the save) and its length tlen: the text without the spaces at the end of each line
; and without the empty lines after the last line with text. A Return stays at the end of each line that has text.
; The gap goes to the end of the text first (the text is then one piece at bufmem); the editor's text is not changed.
SCR     = BUFE                  ; the copy goes in the free memory after the one-entry text buffer
trimtxt:
        lda len
        sta eoff
        lda len+1
        sta eoff+1
        jsr gapto
        lda #<bufmem
        sta P1
        lda #>bufmem
        sta P1+1
        lda #<SCR
        sta P2
        sta tls
        sta tkc
        sta tkp
        lda #>SCR
        sta P2+1
        sta tls+1
        sta tkc+1
        sta tkp+1
        lda #0
        sta tlc
        lda len
        sta cl
        lda len+1
        sta cl+1
@l:     lda cl
        ora cl+1
        bne @more
        jmp @end
@more:  lda cl
        bne @c
        dec cl+1
@c:     dec cl
        ldy #0
        lda (P1),y
        inc P1
        bne @r
        inc P1+1
@r:     cmp #SPC
        beq @sp
        cmp #CR
        beq @cr
        ldy #0                  ; a character of the line: its end is after it
        sta (P2),y
        jsr t2inc
        lda P2
        sta tkc
        lda P2+1
        sta tkc+1
        lda #1
        sta tlc
        jmp @l
@sp:    ldy #0                  ; a space: written, but it is taken back if the line has no character after it
        lda #SPC
        sta (P2),y
        jsr t2inc
        jmp @l
@cr:    lda tlc
        beq @blank
        lda tkc                 ; the line has text: the Return goes right after its last character
        sta P2
        lda tkc+1
        sta P2+1
        jmp @cw
@blank: lda tls                 ; a line of spaces or nothing: it is empty
        sta P2
        lda tls+1
        sta P2+1
@cw:    ldy #0
        lda #CR
        sta (P2),y
        jsr t2inc
        lda P2
        sta tls
        lda P2+1
        sta tls+1
        lda tlc
        beq @nl
        lda P2
        sta tkp
        lda P2+1
        sta tkp+1
        lda #0
        sta tlc
@nl:    jmp @l
@end:   lda tlc                 ; the last line has text but no Return: it ends at its last character
        beq @fin
        lda tkc
        sta tkp
        lda tkc+1
        sta tkp+1
@fin:   sec
        lda tkp
        sbc #<SCR
        sta tlen
        lda tkp+1
        sbc #>SCR
        sta tlen+1
        rts

t2inc:  inc P2
        bne @x
        inc P2+1
@x:     rts

; encrypt the copy (tlen bytes at SCR) with the stream of the chosen day
crypttrim:
        lda #<SCR
        sta P1
        lda #>SCR
        sta P1+1
        lda tlen
        sta cl
        lda tlen+1
        sta cl+1
        lda dy
        jmp crypt

; ---------------------------------------------------------------------------------------------------------------
; screen helpers
; ---------------------------------------------------------------------------------------------------------------
clrscr: lsr tdone               ; (the start screen is gone)
        lda #46
        sta WNDWDTH
        jsr HOME
        lda #SPC                ; the driver clears its screen at the first character after HOME
        jsr putc
        lda #WIDE
        sta WNDWDTH
norm:   lda #$FF                ; normal video
        .byte $2C
inv:    lda #$3F                ; inverse video
        sta INVFLG
        rts

        .include "../common/fastclr.s"

; the top line (screen row 0) is an inverse bar like the status row: topbeg (or topat: from column X), print, topend
topbeg: ldx #0
topat:  ldy #$FF
        jsr gotoxy
        jmp inv
topend: jsr toeol               ; the rest of the bar
topst:  jsr norm
; The driver's 46 columns are 276 pixels wide, the screen is 280. The 4 pixels at the right of a bar are painted here
; (bits 3-6 of the last byte, 39, of each of the 12 pixel lines of the row), so that the bar spans the screen:
; the top line / the status row. The addresses: stripl/striph (gen.py), 12 for the status row, then 12 for the top
topstrip:
        ldx #23
        .byte $2C
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
        bmi @x
        cpx #11
        bne @l
@x:     rts

; underline the "2026년 11월" of the calendar: pixel line 23 (the last line of text row 1), columns 17-27
underline:
        ldy #14
@u:     lda $3D00,y
        ora #$7F
        sta $3D00,y
        iny
        cpy #24
        bcc @u
        rts

; print the zero-terminated string A/Y at the cursor. A byte below $80 in it is a position: column + 1, and the next
; byte is the row + 2 (gen.py writes {x,y})
puts:   sta SEGP
        sty SEGP+1
puts0:  ldy #0
@l:     lda (SEGP),y
        beq @x
        bmi @c
        tax
        dex
        iny
        tya
        pha
        lda (SEGP),y
        tay
        dey
        dey
        jsr gotoxy
        pla
        tay
        iny
        bne @l
@c:     jsr putc
        iny
        bne @l
@x:     rts

; print the zero-terminated string A/Y (putz0: at SEGP), at most X columns; A = columns used
putz:   sta SEGP
        sty SEGP+1
putz0:  ldy #0
@l:     lda (SEGP),y
        beq @e
        iny
        bne @l
@e:     tya
        jmp putstr

; a message on the status row, then a key
barkey: jsr barz
        jmp getkey
; the bar at the bottom: the string A/Y on an inverse row
barz:   sta SEGP
        sty SEGP+1
        jsr inv
        ldx #0
        ldy #STROW
        jsr gotoxy
        ldx #SCRW
        jsr putz0
        jsr toeol
        jsr norm
        jsr barstrip
        lda #0                  ; the editor draws its bar whole
        sta stbg
        sta tdone               ; (the bar may not be the start screen's footer)
        rts

; print A (0-99) as two digits: leading 0 (p2z) or a leading blank (put2)
p2z:    ldx #1
        .byte $2C
put2:   ldx #0
        stx pzf
        ldx #0
@t:     cmp #10
        bcc @o
        sbc #10
        inx
        bne @t
@o:     pha
        txa
        bne @d
        ldy pzf
        beq @b
@d:     ora #$B0
        bne @p
@b:     lda #SPC
@p:     jsr putc
        pla
        ora #$B0
        jmp putc

; "20YY", "20YY-MM-", "20YY-MM-DD"
put20:  lda #'2'|$80
        jsr putc
        lda #'0'|$80
        jsr putc
        lda yy
        jmp p2z
putdate:
        jsr putym
        lda dy
        jmp p2z
putym:  jsr put20
        jsr @h
        lda mo
        jsr p2z
@h:     lda #'-'|$80
        jmp putc

; the top line up to the weekday: "20YY-MM-DD 토요일" (dow1 must be the one of yy/mo)
tophead:
        jsr topbeg
        jsr putym
        jsr putdwd
        lda #<m_yoil
        ldy #>m_yoil
        jmp puts
; "DD", a blank and the weekday name of the chosen day
putdwd: lda dy
        jsr p2z
        lda #SPC
        jsr putc
        jsr dowd
; A = 0-6: print the weekday name
putwd:  tax
        lda wdlo,x
        ldy wdhi,x
        jmp puts
wdlo:   .byte <m_wd0,<m_wd1,<m_wd2,<m_wd3,<m_wd4,<m_wd5,<m_wd6
wdhi:   .byte >m_wd0,>m_wd1,>m_wd2,>m_wd3,>m_wd4,>m_wd5,>m_wd6

; "[S6,D2]" of the data disk: A/Y = the string / printed at the cursor
dskstr: lda dslot
        ora #$B0
        sta dsktxt+2
        lda ddrv
        ora #$B0
        sta dsktxt+5
        lda #<dsktxt
        ldy #>dsktxt
        rts
putdisk:
        jsr dskstr
        jmp puts
dsktxt: .byte $DB,$D3,$B6,$AC,$C4,$B1,$DD,0

; ---------------------------------------------------------------------------------------------------------------
; date arithmetic
; ---------------------------------------------------------------------------------------------------------------
dimtab: .byte 31,28,31,30,31,30,31,31,30,31,30,31
dowt:   .byte 0,3,2,5,0,3,5,1,4,6,2,4

; dim (and A) = the days of the month yy/mo
getdim: ldx mo
        lda dimtab-1,x
        sta dim
        cpx #2
        bne @x
        lda yy
        and #3
        bne @x
        inc dim
@x:     lda dim
        rts

; dow1 = weekday of the 1st (0 = Sunday): (Y + Y/4 + t[mo] + 1) mod 7, Y = yy, less 1 in January and February
getdow1:
        lda yy
        ldx mo
        cpx #3
        bcs @a
        sbc #0                  ; (carry clear: - 1)
@a:     sta T0
        lsr a
        lsr a
        clc
        adc T0
        sec
        adc dowt-1,x
        jsr mod7
        sta dow1
        rts

; A = the weekday (0-6) of day dy
dowd:   lda dow1
        clc
        adc dy
        sbc #0                  ; (carry clear: - 1)
mod7:   cmp #7
        bcc @d
        sbc #7
        bcs mod7
@d:     rts

day_next:
        inc dy
        lda dim
        cmp dy
        bcs mo_x
        lda #1
        sta dy
mo_next:
        inc mo
        lda mo
        cmp #13
        bcc gdclamp
        lda #1
        sta mo
c_yn:   inc yy
        bne gdclamp
day_prev:
        dec dy
        bne mo_x
        jsr mo_prev
        sta dy                  ; (A = dim)
        rts
c_yp:   dec yy
        jmp gdclamp
mo_prev:
        dec mo
        bne gdclamp
        lda #12
        sta mo
        dec yy
; the days of the month, and the day no later than its last one
gdclamp:
        jsr getdim
        cmp dy
        bcs mo_x
        sta dy
mo_x:   rts

; ---------------------------------------------------------------------------------------------------------------
; line input at the cursor: A = longest, X = 1 to show stars, 2 for a date. Carry set: ESC. Text in inb, length inl
; (7-bit ASCII)
; ---------------------------------------------------------------------------------------------------------------
getline:
        sta gmax
        stx gmask
        lda CH
        sta lx
        ldy CV
        dey
        sty ly
        lda #0
        sta inl
@draw:  ldx lx
        ldy ly
        jsr gotoxy
        ldx #0
@d1:    cpx inl
        bcs @d2
        lda inb,x
        ora #$80
        ldy gmask
        dey
        bne @p
        lda #'*'|$80
@p:     jsr putc
        inx
        bne @d1
@d2:    lda #'_'|$80
        jsr putc
        lda #SPC
        jsr putc
@key:   jsr getkey
        cmp #$1B
        beq @x                  ; (carry set)
        cmp #$0D
        bne @k2
        clc
@x:     rts
@k2:    cmp #$08
        beq @bs
        cmp #$13
        beq @bs
        cmp #$7F
        beq @bs
        cmp #$20
        bcc @key
        ldx gmask
        cpx #2                  ; a date: digits only, the hyphens come by themselves (2026- 11- )
        bne @nd
        cmp #'0'
        bcc @key
        cmp #'9'+1
        bcs @key
@nd:    ldx inl
        cpx gmax
        bcs @key
        sta inb,x
        inx
        stx inl
        ldy gmask
        cpy #2
        bne @dj
        cpx #4
        beq @hy
        cpx #7
        bne @dj
@hy:    lda #'-'
        sta inb,x
        inc inl
        bne @dj
@bs:    ldx inl
        beq @key
        dex
        beq @bd
        lda gmask
        cmp #2
        bne @bd
        lda inb-1,x
        cmp #'-'
        bne @bd
        dex
@bd:    stx inl
@dj:    jmp @draw

; ---------------------------------------------------------------------------------------------------------------
; password
; ---------------------------------------------------------------------------------------------------------------
pwtxt:  .byte $D0,$D7,$C3,$C8,$CB               ; PWCHK (start copies it into pwname)
phrase: .byte $CB,$C4,$C9,$C1,$D2,$D9,$A1,$A1   ; KDIARY!!

; the bytes of inb -> pw / pwn, then chk2 = the phrase encrypted with the password (a check value)
setpw:  ldx inl
        stx pwn
@c:     dex
        bmi @k
        lda inb,x
        sta pw,x
        bpl @c                  ; (7-bit characters)
@k:     ldx #7
@p:     lda phrase,x
        sta chk2,x
        dex
        bpl @p
        lda #<chk2
        ldy #>chk2
        ldx #8
        jsr cset
        jmp crypt0              ; (A = 0)

; The splash picture (top 3 rows, delta + RLE coded: see art.py) and its decoder are in the segment SPLASH, the last
; one in the file. The editor's line arrays (BSS) lie over it: it is shown on the start screens only, before the
; first password is accepted (started = 0). Nothing here may be used after that.
        .segment "SPLASH"
        .include "build/splash.inc"
splash: lda #<spdata
        sta P3
        lda #>spdata
        sta P3+1
        lda #0
        sta T4
@ln:    lda T4
        jsr splrow
        lda P2
        sta P1
        lda P2+1
        sta P1+1
        lda T4
        bne @pv
        ldy #SPW-1              ; line 0: cleared, and its own "line above"
        lda #0
@c0:    sta (P1),y
        dey
        bpl @c0
        lda P1
        sta P2
        lda P1+1
        sta P2+1
        jmp @go
@pv:    lda T4
        sec
        sbc #1
        jsr splrow
@go:    ldy #0
@nx:    ldx #0
        lda (P3,x)
        inc P3
        bne @a
        inc P3+1
@a:     cmp #$80
        bcs @run
        eor (P2),y
        sta (P1),y
        iny
        cpy #SPW
        bcc @nx
        bcs @eol
@run:   and #$7F
        tax
@z:     lda (P2),y
        sta (P1),y
        iny
        dex
        bne @z
        cpy #SPW
        bcc @nx
@eol:   inc T4
        lda T4
        cmp #SPH
        bcs @x
        jmp @ln
@x:     rts

; P2 = the hi-res address of byte SPX of pixel line A (0-35): $2000 + (A and 7) * $400 + (A / 8) * $80 + SPX
splrow: pha
        and #7
        asl a
        asl a
        clc
        adc #$20
        sta P2+1
        pla
        lsr a
        lsr a
        lsr a
        tax
        lda #SPX
        clc
        adc spoff,x
        sta P2
        lda P2+1
        clc
        adc spohi,x
        sta P2+1
        rts
spoff:  .byte 0,$80,0,$80,0
spohi:  .byte 0,0,1,1,2
        .segment "CODE"

; the start screens: the picture (at the start only), the greeting, the footer
title_screen:
        lda tdone
        beq @all
        lda #5                  ; the picture, the greeting and the footer are on the screen: only the rows between change
        ldx #15
        jmp fastclr
@all:   jsr clrscr
        lda started
        bne @ns
        jsr splash
@ns:    lda #<s_welcome
        ldy #>s_welcome
        jsr puts
        lda #<m_foot
        ldy #>m_foot
        jsr barz
        inc tdone
        rts

; a password question at the cursor: A = inl (Z set: nothing typed). ESC ends the program, or (changing the data
; disk) leaves pwflow with carry set
getpw:  lda #16
        ldx #1
        jsr getline
        bcs @esc
        lda inl
        rts
@esc:   lda started
        bne @back
        jmp tobasic
@back:  pla
        pla
        rts

; change the data disk to nslot/ndrv (the calendar's ESC command): the password question for that disk (or the new-diary
; questions) as at the start, without the picture. Carry set / the old disk and password are back if it is not done.
swdisk: ldx #18
@c:     lda ddrv,x              ; the old disk and password (ddrv, dslot, pw, pwn) are kept in the cut buffer
        sta hold,x
        dex
        bpl @c
        lda nslot
        sta dslot
        lda ndrv
        sta ddrv
        jsr pwflow
        bcc @x
        ldx #18
@r:     lda hold,x
        sta ddrv,x
        dex
        bpl @r
@x:     rts

; the password of the data disk (or a new diary on it). Carry set: not done (a disk error, another disk wanted, ESC)
pwflow: lda #<pwname
        ldy #>pwname
        jsr mopen_r
        bcc @have
        cmp #6
        beq @new
@derr:  jsr dosmsg
        lda msgp                ; a disk error on the data disk: show it, and ask for the drive again
        ldy msgp+1
        jsr barkey
        sec
        rts
@have:  lda #3
        ldx #0
        ldy #SI_CHK
        jsr sio
        jsr fmclose
@ask:   jsr title_screen
        lda #<s_pwask
        ldy #>s_pwask
        jsr puts
        jsr getpw
        beq @ask
        jsr setpw
        ldx #7
@cmp:   lda chk2,x
        cmp chk,x
        bne @bad
        dex
        bpl @cmp
        clc
        rts
@bad:   lda #<m_pwbad
        ldy #>m_pwbad
        jsr barkey
        jmp @ask

; no password file on this disk: is there a diary at all?
@new:   jsr catscan
        jsr title_screen
        ldx #2
        ldy #5
        jsr gotoxy
        lda lsn
        bne @orph
        jsr putdisk
        lda #<s_new
        ldy #>s_new
        jsr puts
        jsr getkey
        and #$DF
        cmp #'Y'
        beq @first
        sec                     ; another disk: back to the drive question
        rts
@orph:  lda #<s_orph            ; month files but no PWCHK: a new password would make them unreadable: refuse
        ldy #>s_orph
        jsr puts
        lda #<m_anykey
        ldy #>m_anykey
        jsr puts
        jsr getkey
        sec
        rts

; first run: choose a password
@first: jsr title_screen
        lda #<s_first
        ldy #>s_first
        jsr puts
        jsr getpw
        beq @first
        sta pw1n
        tax
@s1:    lda inb-1,x
        sta pw1-1,x
        dex
        bne @s1
        lda #<s_again
        ldy #>s_again
        jsr puts
        jsr getpw
        cmp pw1n
        bne @diff
        tax
@s2:    lda inb-1,x
        cmp pw1-1,x
        bne @diff
        dex
        bne @s2
        jsr setpw
        lda #<pwname
        ldy #>pwname
        jsr mopen_c
        bcs @werr
        lda #4
        ldx #0
        ldy #SI_CHK2
        jsr sio
        php
        pha
        jsr fmclose
        pla
        plp
        bcs @werr
        rts
@werr:  jmp @derr
@diff:  lda #<m_pwdiff
        ldy #>m_pwdiff
        jsr barkey
        jmp @first

; ---------------------------------------------------------------------------------------------------------------
; the data disk's drive: RETURN keeps the shown one (the DOS default), "2" = drive 2 of that slot, "52" = slot 5 drive 2
; ---------------------------------------------------------------------------------------------------------------
askdrive:
        jsr title_screen
        lda #<s_drv
        ldy #>s_drv
        jsr puts
        jsr putdisk             ; "[S6,D1]"
        lda #SPC
        jsr putc
        lda #8
        ldx #0
        jsr getline
        bcc @g
        jmp tobasic
@g:     jsr parsedisk
        bcs @bad
        lda nslot
        beq @s
        sta dslot
@s:     lda ndrv
        beq @ok
        sta ddrv
@ok:    rts
@bad:   jsr cdbad
        jmp askdrive

; The answer to "which disk" (inb/inl): DOS 3.3's "S6,D2" (slot, drive; either part alone is fine: "D2", "S5"), or digits:
; "2" = drive 2, "62" = slot 6 drive 2. nslot / ndrv = 0 when not given. Carry set: not understood.
parsedisk:
        lda #0
        sta nslot
        sta ndrv
        sta ndg
        tax
@l:     cpx inl
        bcs @e
        lda inb,x
        inx
        jsr upcase
        ldy #0
        cmp #'S'
        beq @sd
        iny
        cmp #'D'
        beq @sd
        sec
        sbc #'0'
        cmp #10
        bcs @l                  ; (anything else is skipped)
        ldy ndg
        cpy #2
        bcs @bad
        sta nbd,y
        inc ndg
        bne @l
@sd:    cpx inl                 ; S or D: a digit must follow (Y = 0 slot, 1 drive)
        bcs @bad
        lda inb,x
        sec
        sbc #'0'
        cmp #10
        bcs @bad
        inx
        sta nslot,y
        bcc @l
@e:     ldy ndg
        beq @chk
        lda nbd-1,y             ; digits alone: the last one is the drive, two: slot and drive
        sta ndrv
        dey
        beq @chk
        lda nbd
        sta nslot
@chk:   lda nslot
        cmp #8
        bcs @bad
        lda ndrv
        cmp #3
        bcs @bad
        ora nslot
        bne @r                  ; (carry clear)
        lda inl                 ; neither given: fine only if nothing was typed
        cmp #1
@r:     rts
@bad:   sec
        rts

; ---------------------------------------------------------------------------------------------------------------
; today's date
; ---------------------------------------------------------------------------------------------------------------
; inb (8 digits, inl = 8) -> yy, mo, dy. Carry set if it is not a date from 2001 to 2099
parsedate:
        lda inl
        cmp #8
        bne @bad
        ldx #0
        jsr d2v
        cmp #20
        bne @bad
        jsr d2v
        beq @bad
        sta yy
        jsr d2v
        beq @bad
        cmp #13
        bcs @bad
        sta mo
        jsr d2v
        beq @bad
        sta dy
        jsr getdim
        cmp dy
        bcc @bad
        clc
        rts
@bad:   sec
        rts
; A = the two digits at inb,X (Z set if 0); X moves on
d2v:    lda inb,x
        and #$0F
        sta T0
        asl a
        asl a
        adc T0
        asl a
        sta T0
        inx
        inx
        lda inb-1,x
        and #$0F
        adc T0
        rts

askdate:
        jsr clrscr
        lda #<s_date
        ldy #>s_date
        jsr puts
        lda #10
        ldx #2
        jsr getline
        bcc @g
        jmp tobasic
@g:     ldx #0                  ; keep only the digits (2026-11-14 -> 20261114)
        ldy #0
@l:     cpx inl
        bcs @e
        lda inb,x
        inx
        cmp #'0'
        bcc @l
        cmp #'9'+1
        bcs @l
        sta inb,y
        iny
        bne @l
@e:     sty inl
        jsr parsedate
        bcc @ok
        lda #<m_baddate
        ldy #>m_baddate
        jsr barkey
        jmp askdate
@ok:    ldx #D_CUR
        ldy #D_TODAY
        jmp cp3

; ---------------------------------------------------------------------------------------------------------------
; the shell
; ---------------------------------------------------------------------------------------------------------------
shell:  jsr askdrive
        jsr pwflow
        bcs shell
        inc started             ; (the picture's memory is free now)
        jsr askdate
        jsr calendar
        jmp tobasic

; ---------------------------------------------------------------------------------------------------------------
; the month calendar
; ---------------------------------------------------------------------------------------------------------------
; the top line: date, weekday, the screen's name, the disk
cal_top:
        jsr tophead
        lda #17
        jsr spaces
        lda #<m_title
        ldy #>m_title
        jsr puts
        jsr putdisk             ; "[S6,D2]"
        jmp topst

; draw the cell of day A, selected if cs <> 0. On a cleared screen (cfresh) the blanks are not drawn
drawcell:
        sta cdy
        clc
        adc dow1
        sbc #0                  ; (carry clear: - 1)
        ldy #3
@d:     cmp #7
        bcc @e
        sbc #7
        iny
        bne @d
@e:     sta T0                  ; A = column, Y = row
        asl a
        asl a
        adc T0
        adc #5
        tax
        lda cfresh
        beq @g
        inx
@g:     jsr gotoxy
        lda cfresh
        bne @n
        lda #SPC
        jsr putc
@n:     lda cs
        beq @u
        jsr inv
@u:     lda cdy
        jsr put2
        ldx cdy
        lda flags,x
        bne @st
        lda cs
        bne @sp
        lda cfresh
        bne @x
@sp:    lda #SPC
        .byte $2C
@st:    lda #'*'|$80
        jsr putc
@x:     jmp norm

; the line under the calendar: the title of the chosen day. cist = what the line shows now (0 nothing, 1 "no entry",
; 2 a title), cinl = its columns: only what changes is drawn
cal_info:
        jsr readtitle
        lda ttn
        bne @t
        ldx cist
        dex
        beq @x                  ; it says so already
        jsr @pos
        lda #<m_noentry
        ldy #>m_noentry
        ldx #44
        jsr putz
        ldx #1
        bne @pad
@t:     jsr @pos
        lda #<tt
        sta SEGP
        lda #>tt
        sta SEGP+1
        lda ttn
        ldx #44
        jsr putstr
        ldx #2
@pad:   stx cist
        sta T0
        lda cinl                ; blanks over the rest of what was there
        ldx T0
        stx cinl
        sec
        sbc T0
        bcc @x
        jmp spaces
@pos:   ldx #1
        ldy #10
        jmp gotoxy
@x:     rts

; the whole calendar of the month yy/mo with day dy chosen
cal_full:
        jsr clrscr
        jsr loadflags
        jsr getdim
        jsr getdow1
        jsr cal_top
        jsr caltitle
        jsr underline
        lda #0                  ; the weekday names
        sta wk
@w:     asl a
        asl a
        adc wk
        adc #6
        tax
        ldy #2
        jsr gotoxy
        lda wk
        jsr putwd
        inc wk
        lda wk
        cmp #7
        bcc @w
        lda #1                  ; the cells, on the cleared screen
        sta cfresh
        jsr calcells
        sta cfresh
        sta cist
        sta cinl
        jsr cal_info
        lda #<m_barcal
        ldy #>m_barcal
        jmp barz

; "20YY년 MM월", centred (11 columns); the underline is drawn by cal_full only (it never changes)
caltitle:
        ldx #17
        ldy #0
        jsr gotoxy
        jsr put20
        lda #<m_yr
        ldy #>m_yr
        jsr puts
        lda mo
        jsr put2
        lda #<m_wd1             ; "월"
        ldy #>m_wd1
        jmp puts

; the cells of days 1 to dim (day dy selected); A = cs = 0 at the end
calcells:
        lda #1
        sta wk
@c:     ldx #0
        cmp dy
        bne @n
        inx
@n:     stx cs
        jsr drawcell
        inc wk
        lda wk
        cmp dim
        bcc @c
        beq @c
        lda #0
        sta cs
        rts

; the month or the year changed: draw only what differs. The date and weekday on the top line (always the same width),
; the title, the cells (on the grid, cleared); not the weekday names, the rest of the top line or the bar. cist/cinl are kept, so
; the line under the calendar changes only if its words do
cal_month:
        jsr loadflags
        jsr getdim
        jsr getdow1
        jsr tophead
        jsr norm
        jsr caltitle
        jsr underline           ; (drawing the title erased it)
        lda #4                  ; the grid's six rows are cleared at once (the driver's fast clear), the cells drawn on it
        ldx #10
        jsr fastclr
        lda #1
        sta cfresh
        jsr calcells
        sta cfresh              ; (A = 0)
        jmp cal_info

; ---- the calendar's commands (caltab, made by gen.py): Q, CHD S6,D2, ? ----
ccmd_q: inc cquit
        rts

ccmd_h: jsr clrscr
        lda #<chelptxt
        sta P3
        lda #>chelptxt
        sta P3+1
        lda #$FF                ; the first line is on the top row
@l:     sta T5
        jsr helpx               ; the keys now in use replace the slots {n}
        ldx #0
        ldy T5
        jsr gotoxy
        jsr puts0
        ldx T5
        inx
        txa
        cmp #CHN-1
        bcc @l
        lda #<m_anykey
        ldy #>m_anykey
        jsr barkey
        cmp #$1B                ; ESC at the help: the command line again (any other key: back to the calendar)
        bne @x
        inc cagain
@x:     rts

; the disk answer of a command (cb from argp) -> nslot/ndrv (what was not given: the data disk's). Carry set: not
; understood; inl = 0: none given
getdiskarg:
        ldx #0
        ldy argp
@c:     cpy cbn
        bcs @e
        cpx #16
        bcs @e
        lda cb,y
        and #$7F
        sta inb,x
        inx
        iny
        bne @c
@e:     stx inl
        jsr parsedisk
        bcs @x
        lda nslot
        bne @c1
        lda dslot
        sta nslot
@c1:    lda ndrv
        bne @c2
        lda ddrv
        sta ndrv
@c2:    clc
@x:     rts

; CHD S6,D2 / 디스크 S6,D2: change the data disk
ccmd_chd:
        jsr getdiskarg
        bcs cdbad
        lda inl
        beq cdbad
        lda nslot
        cmp dslot
        bne @ch
        lda ndrv
        cmp ddrv
        beq @x                  ; the disk in use
@ch:    jmp swdisk
@x:     rts
cdbad:  lda #<m_baddrv
        ldy #>m_baddrv
        jmp barkey

; LS S6,D1 / 목록 S6,D1: the catalog of a disk (the data disk if none is named), 13 files to a page
ccmd_ls:
        jsr getdiskarg
        bcs cdbad
        lda ddrv                ; the data disk stays: the catalog is read from the one asked for
        pha
        lda dslot
        pha
        lda nslot
        sta dslot
        lda ndrv
        sta ddrv
        jsr lshead
        lda #0
        sta lsrw
        lda #<lsprint
        ldy #>lsprint
        jsr catwalk
        bmi @out                ; ESC at a full page
        beq @end
        lda #<m_ioerr
        ldy #>m_ioerr
        bne @bar
@end:   lda #<m_anykey
        ldy #>m_anykey
@bar:   jsr barkey
@out:   pla
        sta dslot
        pla
        sta ddrv
        rts

lshead: jsr clrscr
        jsr topbeg
        lda #<m_lshdr
        ldy #>m_lshdr
        jsr puts
        jsr putdisk
        jmp topend

; one catalog entry (P2, lsoff) on the next row: lock, type, sectors, name. Carry set: ESC at a full page
lsprint:
        lda lsrw
        cmp #13
        bcc @go
        lda #<m_lsbar
        ldy #>m_lsbar
        jsr barkey
        cmp #$1B
        bne @pg
        rts                     ; (carry set)
@pg:    jsr lshead
        lda #0
        sta lsrw
@go:    ldx #0
        ldy lsrw
        jsr gotoxy
        ldy lsoff
        iny
        iny
        lda (P2),y              ; type, bit 7 = locked
        sta T0
        lda #SPC
        bit T0
        bpl @u
        lda #'*'|$80
@u:     jsr putc
        lda T0
        and #$7F
        cmp #5
        bcc @t
        lda #3
@t:     tax
        lda lstc,x
        jsr putc
        lda #SPC
        jsr putc
        lda lsoff
        clc
        adc #33
        tay
        lda (P2),y
        sta numv
        iny
        lda (P2),y
        sta numv+1
        jsr utoa
        lda #3
        sec
        sbc numlen
        bcc @np
        jsr spaces
@np:    jsr putnum
        lda #SPC
        jsr putc
        lda lsoff               ; the name, without the blanks after it
        clc
        adc #32
        tay
        ldx #30
@tr:    lda (P2),y
        cmp #SPC
        bne @pl
        dey
        dex
        bne @tr
        beq @pe
@pl:    lda lsoff
        clc
        adc #3
        tay
@pn:    lda (P2),y
        jsr putc
        iny
        dex
        bne @pn
@pe:    inc lsrw
        clc
        rts
lstc:   .byte 'T'|$80,'I'|$80,'A'|$80,'?'|$80,'B'|$80

; the calendar and its keys. Returns when the program ends
calendar:
        lda #0
        sta dgn
@redraw:
        jsr cal_full
@key:   jsr getkey
        pha
        ldx #D_CUR              ; the date before the key
        ldy #D_OLD
        jsr cp3
        pla
        cmp #$1B
        bne @n1
        lda dgn
        beq @cmd
        lda #0                  ; ESC cancels the digits of a date
        sta dgn
        beq @redraw
@cmd:   lda #0                  ; ESC: the command line, as in the editor (the inverse bar); its own commands
        sta han
        sta cquit
        sta cagain
        inc cmode
        lda #SCRW
        sta stlen
        jsr command
        dec cmode
        lda cquit
        bne @quit
        lda cagain              ; (ESC at the help screen: the command line again)
        bne @cmd
        beq @redraw
@n1:    cmp #'0'
        bcc @nd
        cmp #'9'+1
        bcc @digit
@nd:    ldx #0                  ; any other key ends the digits
        stx dgn
        cmp #$0D
        beq @edit
        cmp #$20
        bcs @pr
        tax                     ; a control key: its action number (the key map)
        lda keymap,x
@pr:    cmp #$60
        bcc @f0
        and #$DF
@f0:    ldx #CKN-1
@f:     cmp ckey,x
        beq @mv
        dex
        bpl @f
        cmp #'L'
        beq @list
        cmp #'D'
        beq @del
        cmp #'Q'
        bne @kj
@quit:  rts
@kj:    jmp @key
@edit:  jsr openentry
        jmp @redraw
@list:  jsr cal_list
@rj:    jmp @redraw
@del:   ldx dy
        lda flags,x
        beq @kj
        lda #<m_askdel
        ldy #>m_askdel
        jsr barkey
        and #$DF
        cmp #'Y'
        bne @rj
        jsr newbuf              ; an empty text is saved: the entry goes (asked already: no second question)
        lda #1
        sta sure
        jsr save
        lda #0
        sta sure
        jmp @redraw
@digit: ldy #12
        jsr adddig
        bcc @kj
        lda #13                 ; the echo row (logical row 12)
        ldx #14
        jsr fastclr
        jsr parsedate
        bcc @moved
        jsr @old
        lda #<m_baddate
        ldy #>m_baddate
        jsr barkey
        jmp @redraw
@mv:    jsr @go                 ; a key that moves the date
@moved: lda yy
        beq @oob
        cmp #100
        bcs @oob
        cmp oyy
        bne @mc
        lda mo
        cmp omo
        bne @mc
        lda ody                 ; the same month: only the two cells and the lines change
        jsr drawcell
        inc cs
        lda dy
        jsr drawcell
        dec cs
        ldx #8                  ; the day and the weekday on the top line
        jsr topat
        jsr putdwd
        jsr norm
        jsr cal_info
        jmp @key
@mc:    jsr cal_month           ; another month: only what differs is drawn
        jmp @key
@oob:   jsr @old                ; out of 2001-2099: stay
        jsr bell
        jmp @key
@go:    lda cjhi,x
        pha
        lda cjlo,x
        pha
        rts
@old:   ldx #D_OLD
        ldy #D_CUR
        jsr cp3
        jmp getdim

; the keys that move the date: a key, or the action number of a control key (2 and 8 left, 21 right, 11 up, 10 down)
ckey:   .byte 2, 8, 21, 11, 10, '<', ',', '>', '.', 'P', 'N', 'T'
CKN     = * - ckey
cjlo:   .byte <(day_prev-1), <(day_prev-1), <(day_next-1), <(c_up-1), <(c_dn-1), <(c_yp-1), <(c_yp-1), <(c_yn-1)
        .byte <(c_yn-1), <(mo_prev-1), <(mo_next-1), <(c_today-1)
cjhi:   .byte >(day_prev-1), >(day_prev-1), >(day_next-1), >(c_up-1), >(c_dn-1), >(c_yp-1), >(c_yp-1), >(c_yn-1)
        .byte >(c_yn-1), >(mo_prev-1), >(mo_next-1), >(c_today-1)

c_up:   lda #7                  ; a week
        sta wk
@u:     jsr day_prev
        dec wk
        bne @u
        rts
c_dn:   lda #7
        sta wk
@d:     jsr day_next
        dec wk
        bne @d
        rts
c_today:
        ldx #D_TODAY
        ldy #D_CUR
        jsr cp3
        jmp getdim

; write or edit the entry of the chosen day
openentry:
        jsr readentry
        bcc @e
        jsr newbuf
@e:     jsr getdow1             ; (for the editor's top line: the list may open another month)
        jsr ed_run
        jmp norm

; a digit key (A) of a date typed on the calendar or the list: echoed at column 1 of row Y. Carry set: that was the
; eighth (the digits are in inb, inl = 8)
adddig: ldx dgn
        sta inb,x
        inc dgn
        ldx #1
        jsr gotoxy
        lda #<m_goto            ; "날짜: 2026-11-14" for the digits typed so far
        ldy #>m_goto
        jsr puts
        ldx #0
@sh:    cpx dgn
        bcs @sd
        cpx #4
        beq @h
        cpx #6
        bne @nh
@h:     lda #'-'|$80
        jsr putc
@nh:    lda inb,x
        ora #$80
        jsr putc
        inx
        bne @sh
@sd:    lda #2
        jsr spaces
        lda dgn
        cmp #8
        bcc @x
        sta inl
        lda #0
        sta dgn
@x:     rts

; ---------------------------------------------------------------------------------------------------------------
; the catalog of the data disk (read with RWTS)
; ---------------------------------------------------------------------------------------------------------------
; read track A, sector Y into the file manager's data buffer; P2 = the buffer. Carry set on error.
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
        lda fmbuf+4
        sta P2
        lda fmbuf+5
        sta P2+1
        rts

; walk the catalog: the routine A/Y is called for every file entry ((P2),lsoff = the entry); it stops the walk with
; carry set. On return X (and the flags): 0 the end of the catalog, 1 a disk error, $FF stopped
catwalk:
        sta @call+1
        sty @call+2
        lda #17
        ldy #0
        jsr rdsec               ; the VTOC: it links to the first catalog sector
        bcs @err
@sec:   ldy #1
        lda (P2),y
        beq @end
        pha
        iny
        lda (P2),y
        tay
        pla
        jsr rdsec
        bcs @err
        lda #$0B                ; 7 entries of 35 bytes from $0B
@ent:   sta lsoff
        tay
        lda (P2),y
        beq @end                ; never used: the end of the catalog
        cmp #$FF
        beq @nx                 ; deleted
@call:  jsr $FFFF
        bcs @stop
@nx:    lda lsoff
        clc
        adc #35
        bcc @ent
        bcs @sec
@end:   ldx #0
        rts
@err:   ldx #1
        rts
@stop:  ldx #$FF
        rts

; ---------------------------------------------------------------------------------------------------------------
; the list of all the entries. The month files are found in the catalog (sorted by month); each month keeps a 31-bit
; mask of its days with an entry (4 arrays of MAXM bytes: mk). An entry is (month index, day). The page shows 12 rows.
; ---------------------------------------------------------------------------------------------------------------
bitt:   .byte 1,2,4,8,16,32,64,128
mkbl:   .byte <mk, <(mk+MAXM), <(mk+2*MAXM), <(mk+3*MAXM)
mkbh:   .byte >mk, >(mk+MAXM), >(mk+2*MAXM), >(mk+3*MAXM)

; the months with a file "일기 20YY-MM" -> mty/mtm (sorted), lsn = how many
catscan:
        lda #0
        sta lsn
        lda #<catent
        ldy #>catent
        jmp catwalk

; the catalog entry at (P2),lsoff: if it is a month file, insert it into the sorted months
catent: lda lsoff
        clc
        adc #3
        tay
        ldx #0
@c:     lda (P2),y              ; "일기 20"
        cmp mname,x
        bne @no
        iny
        inx
        cpx #MNPL+2
        bcc @c
        jsr ld2
        bcs @no
        beq @no
        sta tmy
        lda (P2),y
        cmp #'-'|$80
        bne @no
        iny
        jsr ld2
        bcs @no
        beq @no
        cmp #13
        bcs @no
        sta tmm
        lda (P2),y
        cmp #SPC
        bne @no
        ldx lsn
        cpx #MAXM
        bcs @no
@s:     dex
        bmi @put
        lda mty,x
        cmp tmy
        bcc @put
        bne @sh
        lda mtm,x
        cmp tmm
        bcc @put
@sh:    lda mtt,x
        sta mtt+1,x
        lda mts,x
        sta mts+1,x
        lda mty,x
        sta mty+1,x
        lda mtm,x
        sta mtm+1,x
        bpl @s
@put:   inx
        lda tmy
        sta mty,x
        lda tmm
        sta mtm,x
        ldy lsoff               ; where the file's track/sector list is (lsbuild reads the flags through it)
        lda (P2),y
        sta mtt,x
        iny
        lda (P2),y
        sta mts,x
        inc lsn
@no:    clc
        rts
; two digits at (P2),y -> A (Y advances; Z set if 0). Carry set if they are not digits
ld2:    jsr @d
        bcs @x
        sta T0
        asl a
        asl a
        adc T0
        asl a
        sta T0
        jsr @d
        bcs @x
        adc T0
@x:     rts
@d:     lda (P2),y
        iny
        sec
        sbc #$B0
        cmp #10
        rts

; read the flags of every month: the masks; months without an entry are dropped. The flags are the first 32 bytes
; of the file: its first sector is read with RWTS through the track/sector list (found by catscan), which is much
; quicker than opening every file
lsbuild:
        lda #0
        sta lsi
        sta lsj
@l:     ldx lsi
        cpx lsn
        bcc @m
        lda lsj
        sta lsn
        rts
@m:     lda mty,x
        sta yy
        lda mtm,x
        sta mo
        ldy mts,x
        lda mtt,x
        jsr rdsec               ; the track/sector list
        bcs @skip
        ldy #$0D                ; its first pair: the sector with bytes 0-255 of the file
        lda (P2),y
        pha
        dey
        lda (P2),y
        tax
        pla
        tay
        txa
        beq @skip
        jsr rdsec
        bcs @skip
        ldy #31
@cf:    lda (P2),y
        sta flags,y
        dey
        bpl @cf
        jsr flagchk
        ldx #32                 ; day 1 is bit 0 of tmk, day 31 bit 6 of tmk+3
        clc
        bcc @r
@d:     lda flags,x
        lsr a
@r:     rol tmk
        rol tmk+1
        rol tmk+2
        rol tmk+3
        dex
        bne @d
        lda tmk
        ora tmk+1
        ora tmk+2
        ora tmk+3
        beq @skip
        ldx #3
@st:    lda mkbl,x
        sta P1
        lda mkbh,x
        sta P1+1
        ldy lsj
        lda tmk,x
        sta (P1),y
        dex
        bpl @st
        ldx lsi
        lda mty,x
        sta mty,y
        lda mtm,x
        sta mtm,y
        inc lsj
@skip:  inc lsi
        jmp @l

; Z clear if the day nd of month nm has an entry
tstbit: ldx nd
        dex
        txa
        lsr a
        lsr a
        lsr a
        tay
        lda mkbl,y
        sta P1
        lda mkbh,y
        sta P1+1
        txa
        and #7
        tax
        ldy nm
        lda (P1),y
        and bitt,x
        rts

; the entry after (nm, nd) / before it. Carry set if there is none (before the first one: then nm = nd = 0)
nextent:
@d:     inc nd
        lda nd
        cmp #32
        bcc @t
        inc nm
        lda nm
        cmp lsn
        bcs @x
        lda #0
        sta nd
        beq @d
@t:     jsr tstbit
        beq @d
        clc
@x:     rts
preve:
@d:     dec nd
        bne @t
        sec
        lda nm
        beq @x
        dec nm
        lda #32
        sta nd
        bne @d
@t:     jsr tstbit
        beq @d
        clc
@x:     rts

; the first entry on or after (tgy, tgm, tgd) becomes the selection and the top of the page; if there is none, the
; last entry (carry set)
lsfind: ldx #0
@m:     cpx lsn
        bcs @last
        lda mty,x
        cmp tgy
        bcc @nx
        bne @got
        lda mtm,x
        cmp tgm
        bcc @nx
        bne @got
        ldy tgd                 ; that month: from the day
        dey
        tya
        bpl @go
@nx:    inx
        bne @m
@got:   lda #0                  ; a later month: its first entry
@go:    sta nd
        stx nm
        jsr nextent
        bcc lsset
@last:  ldx lsn
        dex
        stx nm
        lda #32
        sta nd
        jsr preve
        sec
; the selection and the top of the page = (nm, nd). Keeps the carry
lsset:  jsr n2s
n2t:    ldx #D_N
        ldy #D_TOP
        bne cpj
n2s:    ldx #D_N
        ldy #D_SEL
        bne cpj
s2n:    ldx #D_SEL
        .byte $2C
t2n:    ldx #D_TOP
        ldy #D_N
cpj:    jmp cp2

; the rows of the page from (lpm, lpd): rm/rd, lsnr = how many (1-12)
fillpage:
        jsr t2n
        ldx #0
@r:     lda nm
        sta rm,x
        lda nd
        sta rd,x
        inx
        stx lsnr
        cpx #12
        bcs @x
        jsr nextent
        ldx lsnr
        bcc @r
@x:     rts

; Z set if row X of the page is the selection
issel:  lda rm,x
        cmp lsm
        bne @x
        lda rd,x
        cmp lsdy
@x:     rts
; carry clear and X = the row of the selection on the page; carry set if it is not on it
selrow: ldx #0
@l:     cpx lsnr
        bcs @x
        jsr issel
        beq @y
        inx
        bne @l
@y:     clc
@x:     rts

; SEGP = the title of row A of the page (lstt + A * 32)
ttlptr: ldx #0
        stx SEGP+1
        asl a
        asl a
        asl a
        asl a
        rol SEGP+1
        asl a
        rol SEGP+1
        adc #<lstt
        sta SEGP
        lda SEGP+1
        adc #>lstt
        sta SEGP+1
        rts

; draw list row A (0-11 of the page). On a cleared screen (cfresh) a row that is not the selection is not padded
ls_row: sta T5
        tax
        ldy rm,x
        lda mty,y
        sta yy
        lda mtm,y
        sta mo
        lda rd,x
        sta dy
        txa
        clc
        adc #2
        tay
        ldx #1
        jsr gotoxy
        ldx T5
        ldy #0
        jsr issel
        bne @n
        iny
        jsr inv
@n:     sty cs
        jsr putdate
        lda #2
        jsr spaces
        lda T5
        jsr ttlptr
        ldx T5
        lda lstl,x
        ldx #32
        jsr putstr
        ldx cs
        bne @pad
        ldx cfresh
        bne @np
@pad:   eor #$FF                ; 33 - the columns of the title
        sec
        adc #33
        jsr spaces
@np:    lda #0
        sta cs
        jmp norm

; read the titles of the rows of the page (several months may be on it)
ls_load:
        lda #$FF
        sta lsop                ; the month whose file is open ($FF: none)
        lda #0
        sta wk
@l:     ldx wk
        cpx lsnr
        bcs @done
        lda rm,x
        cmp lsop
        beq @have
        pha
        jsr @done
        pla
        sta lsop
        tax
        lda mty,x
        sta yy
        lda mtm,x
        sta mo
        jsr mopn
        bcc @have
        lda #$FF
        sta lsop
@have:  lda #0
        sta ttn
        ldx lsop
        inx
        beq @cp0
        ldx wk
        lda rd,x
        tax
        jsr gettitle
@cp0:   lda wk                  ; copy tt (at most 32 bytes) to lstt + wk * 32
        jsr ttlptr
        ldy ttn
        cpy #32
        bcc @c
        ldy #32
@c:     ldx wk
        tya
        sta lstl,x
        beq @nx
@cp:    dey
        lda tt,y
        sta (SEGP),y
        tya
        bne @cp
@nx:    inc wk
        bne @l
@done:  ldx lsop                ; close the open file
        inx
        beq @x
        jmp fmclose
@x:     rts

lsscreen:
        jsr clrscr
        jsr topbeg
        lda #<m_listhdr
        ldy #>m_listhdr
        jsr puts
        jmp topend

cal_list:
        ldx #D_CUR
        ldy #D_SAVE
        jsr cp3
        lda #<m_reading
        ldy #>m_reading
        jsr barz
        jsr catscan
        jsr lsbuild
        lda lsn
        bne lsgo
        lda #<m_nolist
        ldy #>m_nolist
        jsr barkey
ls_exit:
        ldx #D_SAVE
        ldy #D_CUR
        jmp cp3
lsgo:   ldx #D_SAVE             ; start with the chosen month
        ldy #D_TG
        jsr cp2
        lda #1
        sta tgd
        jsr lsfind
        bcc @draw
@bf:    jsr fillpage            ; no entry from then on: show the last page
        lda lsnr
        cmp #12
        bcs @draw
        jsr t2n
        jsr preve
        bcs @draw
        jsr n2t
        jmp @bf
@draw:  jsr fillpage
        jsr lsscreen
        jsr ls_load
        inc cfresh
        lda #0
        sta dgn
        sta wk
@r:     lda wk
        jsr ls_row
        inc wk
        lda wk
        cmp lsnr
        bcc @r
        dec cfresh
        lda #<m_barlist
        ldy #>m_barlist
        jsr barz
@key:   jsr getkey
        cmp #$1B
        beq ls_exit
        cmp #$0D
        bne @k2
        ldx lsm                 ; open the selected entry (the calendar then shows that day)
        lda mty,x
        sta yy
        lda mtm,x
        sta mo
        lda lsdy
        sta dy
        jmp openentry
@k2:    cmp #'0'
        bcc @k3
        cmp #'9'+1
        bcs @k3
        ldy #0                  ; the digits of a date
        jsr adddig
        bcc @key
        jsr parsedate
        bcc @jump
        lda #<m_baddate
        ldy #>m_baddate
        jsr barkey
@dr:    jmp @draw
@jump:  ldx #D_CUR
        ldy #D_TG
        jsr cp3
        jsr lsfind
        bcc @dr
        jmp @bf
@k3:    ldx #0
        stx dgn
        cmp #$20
        bcs @pr
        tax                     ; a control key: its action number
        lda keymap,x
@pr:    cmp #'<'                ; a page: < > (or , .), left / right
        beq @pgup
        cmp #','
        beq @pgup
        cmp #'>'
        beq @pgdn
        cmp #'.'
        beq @pgdn
        cmp #2                  ; left (^B, the left arrow) = up, right (^U, the right arrow) = down
        beq @up
        cmp #8
        beq @up
        cmp #11
        beq @up
        cmp #21
        beq @dn
        cmp #10
        beq @dn
        bne @kj
@pgdn:  jsr t2n
        lda #12
        sta wk
@a:     jsr nextent
        bcs @bell
        dec wk
        bne @a
        beq @set
@pgup:  jsr t2n
        lda #12
        sta wk
@b:     jsr preve
        bcs @short
        dec wk
        bne @b
        beq @set
@short: lda wk
        cmp #12
        beq @bell               ; already at the first entry
        jsr nextent             ; (before the first one: on to it)
@set:   jsr lsset
        jmp @draw
@bell:  jsr bell
@kj:    jmp @key
@up:    jsr @row
        jsr preve
        bcs @bell
        jsr n2s
        jsr selrow
        bcc @two
        jsr n2t                 ; above the page: it becomes the top row
        jmp @draw
@dn:    jsr @row
        jsr nextent
        bcs @bell
        jsr n2s
        jsr selrow
        bcc @two
        jsr t2n                 ; below the page: the top moves down one
        jsr nextent
        jsr n2t
        jmp @draw
@two:   txa                     ; on the page: only the two rows change
        pha
        lda wk
        jsr ls_row
        pla
        jsr ls_row
        jmp @key
@row:   jsr selrow              ; wk = the row of the selection; (nm, nd) = the selection
        stx wk
        jmp s2n

; ---------------------------------------------------------------------------------------------------------------
; the top line of the editor: the date and the title (the first line of the text)
; ---------------------------------------------------------------------------------------------------------------
drawtop:
        lda #<bufmem
        sta P1
        lda #>bufmem
        sta P1+1
        ldx #0
@l:     jsr tbyte
        bcs @e
        cmp #CR
        beq @e
        sta tt,x
        inx
        cpx #40
        bcc @l
@e:     stx ttn
        cpx otlen               ; the same as on the screen?
        bne @draw
@c:     dex
        bmi @same
        lda tt,x
        cmp otl,x
        beq @c
@draw:  lda otlen
        bpl @part
        jsr tophead             ; ($FF) nothing is there yet: the date and the weekday too
        lda #':'|$80            ; "2026-11-14 토요일: title" (the colon, then a blank)
        jsr putc
        lda #1
        jsr spaces
        jmp @ttl
@part:  ldx #19                 ; the title only
        jsr topat
@ttl:   lda #<tt
        sta SEGP
        lda #>tt
        sta SEGP+1
        lda ttn
        ldx #27
        jsr putstr
        sta T0
        lda otcol               ; blanks over the rest of the title that was there
        ldx T0
        stx otcol
        sec
        sbc T0
        bcc @np
        jsr spaces
@np:    jsr topst
        ldx ttn
        stx otlen
        beq @same
@o:     lda tt-1,x
        sta otl-1,x
        dex
        bne @o
@same:  rts
