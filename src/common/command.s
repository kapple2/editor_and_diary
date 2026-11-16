; Shared by KEDIT and KDIARY: a change here changes both programs. See README.md in this folder.
; ==========================================================================
; command line (ESC)
; ==========================================================================
command:
        lda #0
        sta cbn
@draw:  lda #$3F                ; the command line stays an inverse bar, like the status line
        sta INVFLG
        ldx #0
        ldy #STROW
        jsr gotoxy
        ldy #0                  ; the prompt (5 columns)
@p:     lda m_cmd,y
        beq @pe
        jsr putc
        iny
        bne @p
@pe:    lda #<cb
        sta SEGP
        lda #>cb
        sta SEGP+1
        lda cbn
        ldx #SCRW-7
        jsr putstr
        clc
        adc #6                  ; prompt and cursor
        sta T0
        lda #$FF                ; the cursor: a normal cell on the inverse bar
        sta INVFLG
        lda #SPC
        jsr putc
        lda #$3F
        sta INVFLG
        lda stlen
        sec
        sbc T0
        bcc @np0
        beq @np0
        jsr spaces
@np0:   lda #$FF
        sta INVFLG
@np:    lda T0
        sta stlen
        lda #1
        sta stfull
        jsr barstrip
@key:   jsr getkey
        cmp #$1B
        bne @k1
        rts                     ; cancel
@k1:    cmp #$0D
        bne @k2
        jmp runcmd
@k2:    cmp #$01
        bne @k3
        jsr k_han
        jmp @key
@k3:    cmp #$08
        beq @bs
        cmp #$13
        beq @bs
        cmp #$18
        beq @bs
        cmp #$7F
        beq @bs
        cmp #$20
        bcc @key
        ldx cbn
        cpx #60
        bcs @key
        sta T0
        lda han
        beq @plain
        lda T0
        jsr upcase
        sta T0
        jsr shmap               ; (Shift + R = ㄲ, as in the text)
        lda T0
        ora #$80
        sta T0
        jsr kcls
        beq @pl2
        ldx cbn                 ; a Hangul key
        beq @newrun
        lda cb-1,x
        cmp #HA
        bne @newrun
        lda #HA
        sta cb,x
        lda T0
        sta cb-1,x
        inc cbn
        jmp @draw
@newrun:
        lda #HK
        sta cb,x
        lda T0
        sta cb+1,x
        lda #HA
        sta cb+2,x
        inx
        inx
        inx
        stx cbn
        jmp @draw
@plain: lda T0
        ora #$80
        sta T0
@pl2:   ldx cbn
        lda T0
        sta cb,x
        inc cbn
        jmp @draw
@bs:    ldx cbn
        bne @bs1
        jmp @key
@bs1:   lda cb-1,x
        cmp #HA
        bne @one
        cpx #3
        bcc @one
        lda cb-3,x
        cmp #HK
        bne @key2
        dex                     ; Ctrl-K key Ctrl-A: remove all three
        dex
        dex
        stx cbn
        jmp @draw
@key2:  lda #HA                 ; remove the key before the Ctrl-A
        sta cb-2,x
        dec cbn
        jmp @draw
@one:   dec cbn
        jmp @draw

; parse cb: command word (cw), force flag ('!'), argument (cb from argp, argn bytes)
runcmd: ldy #0
        jsr skipsp
        cpy cbn
        bcc @w
        rts
@w:     lda #0
        sta cwn
        sta force
        lda cb,y
.ifdef KDIARY
        ldx cmode               ; the calendar's commands: words only
        bne @nd
.else                           ; (KEDIT only: /word = F word)
        cmp #'/'|$80
        bne @nsl
        iny
        sty argp
        jsr argend
        jmp cmd_f
.endif
@nsl:   cmp #'0'|$80
        bcc @nd
        cmp #'9'|$80+1
        bcs @nd
        sty argp
        jsr argend
        jmp cmd_g
@nd:    cmp #HK
        bne @eng
        iny                     ; a Korean word: the keys of the first run
@kl:    cpy cbn
        bcs @wd
        lda cb,y
        cmp #HA
        beq @ke
        ldx cwn
        sta cw,x
        inc cwn
        iny
        jmp @kl
@ke:    iny
        jmp @wd
@eng:   cpy cbn                 ; an English word: up to a space or '!'
        bcs @wd
        lda cb,y
        cmp #SPC
        beq @wd
        cmp #'!'|$80
        beq @wd
        and #$7F
        jsr upcase
        ora #$80
        ldx cwn
        sta cw,x
        inc cwn
        iny
        jmp @eng
@wd:    cpy cbn
        bcs @a
        lda cb,y
        cmp #'!'|$80
        bne @a
        inc force
        iny
@a:     jsr skipsp
        sty argp
        jsr argend
        ; look the word up
        lda #<cmdtab
.ifdef KDIARY
        ldx #>cmdtab
        ldy cmode
        beq @sel
        lda #<caltab            ; the calendar has its own list
        ldx #>caltab
@sel:   sta P1
        stx P1+1
.else
        sta P1
        lda #>cmdtab
        sta P1+1
.endif
@t:     ldy #0
        lda (P1),y
        beq @bad
        cmp cwn
        bne @skip
        tax
@c:     iny
        lda (P1),y
        cmp cw-1,y
        bne @skip
        dex
        bne @c
        iny
        lda (P1),y
        sta P2
        iny
        lda (P1),y
        sta P2+1
        jmp (P2)
@skip:  ldy #0
        lda (P1),y
        clc
        adc #3
        adc P1
        sta P1
        bcc @t
        inc P1+1
        jmp @t
@bad:   lda #<m_badcmd
        ldy #>m_badcmd
.ifdef KDIARY
        ldx cmode
        beq @sm
        jmp barkey              ; (on the calendar: the bar and a key)
@sm:    jmp setmsg
.else
        jmp setmsg
.endif

skipsp: cpy cbn
        bcs @x
        lda cb,y
        cmp #SPC
        bne @x
        iny
        bne skipsp
@x:     rts

argend: lda cbn                 ; argn = bytes from argp to the end, trailing spaces dropped
        sta T0
@l:     lda T0
        cmp argp
        beq @x
        tax
        lda cb-1,x
        cmp #SPC
        bne @x
        dec T0
        jmp @l
@x:     lda T0
        sec
        sbc argp
        sta argn
        rts

