; Shared by KEDIT and KDIARY: a change here changes both programs. See README.md in this folder.
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

