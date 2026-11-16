; Shared by KEDIT and KDIARY: a change here changes both programs. See README.md in this folder.
; The editor's main loop and the way back to BASIC.
main:
.ifdef TOPLINE
        jsr drawtop             ; (the program's own line above the text)
.endif
        jsr refresh
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

; end the program: back to BASIC's prompt
tobasic:
        lda TXTTAB              ; the program sat in BASIC's area: leave an empty program behind (like NEW)
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

