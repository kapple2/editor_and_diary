; Shared by KEDIT and KDIARY: a change here changes both programs. See README.md in this folder.
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

