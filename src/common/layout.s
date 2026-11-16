; Shared by KEDIT and KDIARY: a change here changes both programs. See README.md in this folder.
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

