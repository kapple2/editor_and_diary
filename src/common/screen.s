; Shared by KEDIT and KDIARY: a change here changes both programs. See README.md in this folder.
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
gotoxy:
.ifdef TOPLINE
        iny                     ; logical row y is screen row y+1 (Y = $FF: the top line)
.endif
        sty CV
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

.ifdef KDIARY                   ; (only the diary's shell uses it)
; blanks from the cursor to the end of the row
toeol:  lda #SCRW
        sec
        sbc CH
        bcs spaces
        rts
.endif
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
.ifdef TOPLINE
        lda #1
        sta WNDTOP              ; the window is the text rows (screen rows 1 to ROWS)
        lda #ROWS+1
.else
        lda #ROWS
.endif
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
.ifdef TOPLINE
        lda #0
        sta WNDTOP
.endif
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
.ifdef TOPLINE
        lda #1
        sta WNDTOP
        lda #ROWS+1
.else
        lda #ROWS
.endif
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
.ifdef TOPLINE
        lda #0
        sta WNDTOP
.endif
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
.ifdef FASTCLR
        cmp #9
        bcc @sp
.ifdef TOPLINE
        iny                     ; (its screen row)
.endif
        tya                     ; a long row: the driver's clear of that one screen row
        tax
        inx
        jsr fastclr
        jmp @sx
@sp:    jsr spaces
@sx:    ldy drr
.else
        jsr spaces
        ldy drr
.endif
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
.ifdef KDIARY                   ; (the diary's bar shows the data disk where KEDIT's shows the file name)
sbdisk: jsr dskstr              ; "[S6,D2]"
        jmp sbstr
.endif
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
.ifdef KDIARY
@nm:    jsr sbdisk              ; the data disk, "[S6,D2]" (the date is on the top line)
.else
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
.endif
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

.ifndef KDIARY                  ; (the diary has its own in shell.s: it paints the top line too)
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
.endif

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

