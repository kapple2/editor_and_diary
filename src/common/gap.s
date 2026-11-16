; Shared by KEDIT and KDIARY: a change here changes both programs. See README.md in this folder.
; ==========================================================================
; gap buffer
; ==========================================================================
newbuf: lda #<bufmem
        sta gaps
        lda #>bufmem
        sta gaps+1
        lda TXTEND_LO           ; (the end of the text space: the program's file says what it is)
        sta gape
        lda TXTEND_HI
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
        sta ulv                 ; (a new text: nothing for Ctrl-R to put back)
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
        lda TXTEND_LO
        sbc P1
        sta T1
        lda TXTEND_HI
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
        cmp TXTEND_LO
        bne @b
        lda P1+1
        cmp TXTEND_HI
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

