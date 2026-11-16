; Shared by KEDIT and KDIARY: a change here changes both programs. See README.md in this folder.
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

