; Shared by KEDIT and KDIARY: a change here changes both programs. See README.md in this folder.

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
.ifdef FASTCLR
        txa
        pha
.ifdef TOPLINE
        inx                     ; (text row X is screen row X+1)
.endif
        txa                     ; the screen rows of text rows X .. ROWS-1: the driver's clear
        ldx #ROWS+TROW0
        jsr fastclr
        pla
        tax
        lda #0
@z:     sta rowlen,x
        sta sv,x
        inx
        cpx #ROWS
        bcc @z
.else
        stx T5
        lda #0
        jsr rowput              ; (an empty row: its old text is blanked)
        ldx T5
        inx
        bne rowclr
.endif
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
.ifdef KDIARY
        lda #1                  ; the bar is drawn whole (the message is longer than the status)
        sta stfull
.endif
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

