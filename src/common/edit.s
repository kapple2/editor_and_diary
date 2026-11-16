; Shared by KEDIT and KDIARY: a change here changes both programs. See README.md in this folder.
; ==========================================================================
; editing
; ==========================================================================
; Shift + R E Q T W O P (the tense consonants and ㅒ ㅖ) on a Hangul key: T0 (uppercase) -> the shifted key.
; Used by the text (typechar) and by the command line (command), so both type the same letters.
shmap:  lda shift
        beq @x
        ldx #6
@s:     lda T0
        cmp shk,x
        beq @sf
        dex
        bpl @s
        rts
@sf:    lda shv,x
        sta T0
@x:     rts

typechar:                       ; A = key, 7 bits, printable
        sta T0
        lda han
        beq @eng
        lda T0                  ; Hangul mode: letters are keys (upper case)
        jsr upcase
        sta T0
        jsr shmap
@k:     lda T0
        ora #$80
        jsr kcls
        beq @plain
        lda T0
        ora #$80
        jmp inshan
@eng:   lda T0
        jsr upcase
        cmp #'A'
        bcc @plain
        cmp #'Z'+1
        bcs @plain
        ldx lower
        cpx shift
        beq @up
        ora #$20
@up:    sta T0
@plain: lda T0
        ora #$80
        jmp inschar

upcase: cmp #'a'
        bcc @x
        cmp #'z'+1
        bcs @x
        and #$DF
@x:     rts

; insert a Hangul key (A, bit 7 set) at the cursor
inshan: sta ib+1
        jsr ed_begin
        lda #1                  ; a syllable is being typed: Backspace takes its keys one by one
        sta comp
        ldx ci
        ldy u,x
        beq @new
        lda lb-1,y
        cmp #HA
        bne @mid
        dey                     ; right after a run: type into it, before its Ctrl-A
        jmp insone
@mid:   lda uf,x
        and #F_NEEDK
        bne insone              ; inside a run, between syllables
@new:   lda #HK                 ; a new run: Ctrl-K key Ctrl-A
        sta ib
        lda #HA
        sta ib+2
        lda #3
        tax
        bne insgo

; insert a character that is not a Hangul key (A, bit 7 set)
inschar:
        sta ib+1
        jsr ed_begin
        ldx ci
        ldy u,x
        lda uf,x
        and #F_NEEDK
        beq insone
        lda #HA                 ; inside a run: end it, the character, start it again
        sta ib
        lda #HK
        sta ib+2
        lda #3
        ldx #2
        bne insgo
insone: lda ib+1                ; the one byte, at line index Y
        sta ib
        lda #1
        tax
; insert A bytes from ib at line index Y; the cursor then goes X bytes on from the start of its unit
insgo:  stx etgt
        jsr insat
        bcs @f
        ldx ci
        lda u,x
        clc
        adc etgt
        jmp ed_line
@f:     rts

k_ret:  jsr ed_begin
        ldx ci
        ldy u,x
        sty T5
        lda uf,x
        and #F_NEEDK
        beq @plain
        lda #HA
        sta ib
        lda #CR
        sta ib+1
        lda #HK
        sta ib+2
        lda #3
        jsr insat
        bcs @f
        lda #2
        bne @nl
@plain: lda #CR
        sta ib
        lda #1
        jsr insat
        bcs @f
        lda #1
@nl:    clc                     ; the new line starts at ls + the index + A
        adc T5
        adc ls
        sta ls
        bcc @c0
        inc ls+1
@c0:    inc cln
        bne @c
        inc cln+1
@c:     inc nlines
        bne @d
        inc nlines+1
@d:     lda #0
        jmp ed_lines
@f:     rts

backsp: jsr ed_begin
        lda ci
        bne @in
        lda ls                  ; at the start of a line: join it to the previous line
        ora ls+1
        bne @j
        jmp bell
@j:     jsr prevls              ; P3 = start of the previous line
        clc                     ; previous length = ls - 1 - P3
        lda ls
        sbc P3
        sta T5
        clc
        adc lbn
        bcs @long
        cmp #MAXLN+1
        bcc @ok
@long:  jmp bell
@ok:    jsr joinrow             ; where the redraw starts
        lda ls
        sec
        sbc #1
        sta eoff
        lda ls+1
        sbc #0
        sta eoff+1
        lda #1
        jsr delbytes
        lda P3
        sta ls
        lda P3+1
        sta ls+1
        jsr deccln
        jsr decnl
        lda T5
        jmp ed_lines
@in:    lda compp
        bne @cmp
        dec ci                  ; no syllable is being typed: the whole character before the cursor goes
        jmp k_delf
@cmp:   cmp #1
        bne @cn
        ldx ci                  ; first Backspace after typing: compn = keys of the syllable before the cursor
        lda u,x
        sec
        sbc u-1,x
        sta compn
        ldy u-1,x
        lda lb,y
        cmp #HK
        bne @c1
        dec compn
@c1:    ldy u,x
        lda lb-1,y
        cmp #HA
        bne @cn
        dec compn
@cn:    dec compn               ; one key goes; while keys of that syllable are left, the next Backspace does the same
        beq @c0
        lda #2
        sta comp
@c0:    ldx ci
        ldy u,x
        dey                     ; Y = p, the byte before the cursor
        lda lb,y
        cmp #HA
        bne @nha
        cpy #2                  ; after a run: delete its last key
        bcc @one
        lda lb-2,y
        cmp #HK
        bne @one
        dey                     ; the run held one key: remove Ctrl-K key Ctrl-A
        dey
        sty T5
        lda #3
        jsr delat
        lda T5
        jmp ed_line
@one:   dey
        sty T5
        lda #1
        jsr delat
        lda T5
        clc
        adc #1
        jmp ed_line
@nha:   sty T5
        lda #1
        jsr delat
        lda T5
        jmp ed_line

k_delf: jsr ed_begin
        lda ci
        cmp ni
        bcc @unit
        lda hascr               ; at the end of a line: join the next line
        bne @j
        jmp bell
@j:     jsr nextlen             ; nlen = length of the next line
        lda nlen
        clc
        adc lbn
        bcs @long
        cmp #MAXLN+1
        bcc @ok
@long:  jmp bell
@ok:    ldy lbn
        lda #1
        jsr delat
        jsr decnl
        ldx ci
        lda u,x
        jmp ed_lines
@unit:  ldx ci
        lda u,x                 ; s
        sta T2
        sta T5                  ; (kept for the cursor: moving the gap uses T1 and T2)
        sta T3                  ; ks
        lda u+1,x
        sta T4                  ; ke = e
        ldy T2
        lda lb,y
        cmp #HK
        bne @a
        inc T3
@a:     ldy T4
        lda lb-1,y
        cmp #HA
        bne @b
        dec T4
        lda T4
        cmp T3
        bcs @b
        inc T4
@b:     lda T3                  ; whole run (Ctrl-K .. Ctrl-A)? delete s..e
        sec
        sbc T2
        cmp #1
        bne @keys
        ldx ci
        lda u+1,x
        sec
        sbc T4
        cmp #1
        bne @keys
        ldy T2
        lda u+1,x
        sec
        sbc T2
        jmp @del
@keys:  ldy T3
        lda T4
        sec
        sbc T3
@del:   beq @x
        jsr delat
@x:     lda T5
        jmp ed_line

; Ctrl-G: copy the cursor line (Ctrl-P puts it in)
k_copy: jsr holdline
        lda #<m_copied
        ldy #>m_copied
        jmp setmsg

; keep the cursor line (with its CR) for Ctrl-P
holdline:
        ldy lbn
@h:     lda lb,y
        sta hold,y
        dey
        cpy #$FF
        bne @h
        lda lbn
        sta holdn
        lda #1
        sta holdv
        rts

k_delln:
        jsr ed_begin
        jsr holdline
        lda hascr
        beq @last
        ldy #0
        lda lbn
        clc
        adc #1
        jsr delat
        jsr decnl
        lda #0
        jmp ed_lines
@last:  lda lbn
        beq @j
        ldy #0
        jsr delat
        lda #0
        jmp ed_line
@j:     jmp backsp

; Ctrl-X: delete from the cursor to the end of the line
k_deol: jsr ed_begin
        ldx ci
        cpx ni
        bcs @x
        ldy u,x
        sty dcnt
        lda uf,x                ; inside a Hangul run: its Ctrl-A goes too, and is put back
        and #F_NEEDK
        pha
        lda lbn
        sec
        sbc dcnt
        jsr delat
        pla
        beq @d
        jsr curline
        lda #HA
        sta ib
        ldy dcnt
        lda #1
        jsr insat
@d:     lda #$FF
        jmp ed_line
@x:     rts

; ---- delete lines: DP (Ctrl-C: to the next empty line), DA! (everything; ESC command) ----
cmd_dp: lda lbn
        bne @l
        jmp k_delln             ; on an empty line: that line
@l:     lda hascr
        pha
        jsr k_delln
        pla
        beq @x
        lda lbn
        bne @l
@x:     rts

cmd_da: lda len
        ora len+1
        beq @x
        lda force
        bne @go
        lda #<m_sure
        ldy #>m_sure
        jmp setmsg
@go:    jsr newbuf
        inc modf
        lda #3
        sta dirty
@x:     rts

; Ctrl-P: put the line kept by Ctrl-Y above the cursor line
k_paste:
        lda holdv
        bne @go
        jmp bell
@go:    lda #0
        sta ci
        jsr ed_begin
        jsr lsoff0
        lda #<hold
        sta P3
        lda #>hold
        sta P3+1
        ldx holdn
        inx
        txa
        jsr insbytes
        bcs @x
        inc nlines
        bne @n
        inc nlines+1
@n:     lda #0
        jmp ed_lines
@x:     rts

; Ctrl-R: put the cursor line back as it was before it was edited (again: the edited text comes back)
k_undo: lda ulv
        beq @no
        lda uls
        cmp ls
        bne @no
        lda uls+1
        cmp ls+1
        beq @go
@no:    jmp bell
@go:    lda #0
        sta ci
        lda #1
        sta ulv
        jsr ed_begin
        lda ubn
        beq @cp
        jsr lsoff0
        lda #<ub
        sta P3
        lda #>ub
        sta P3+1
        lda ubn
        jsr insbytes            ; the saved text goes in front of the present text
        bcs @x
@cp:    ldx ubn
        stx T5
        ldy lbn                 ; the present text becomes the saved one
        sty ubn
@c:     lda lb,y
        sta ub,y
        dey
        cpy #$FF
        bne @c
        ldy T5
        lda ubn
        beq @d
        jsr delat               ; and is taken out
@d:     lda #$81
        sta ulv
        lda #0
        jmp ed_line
@x:     rts

lsoff0: lda ls                  ; eoff = start of the cursor line
        sta eoff
        lda ls+1
        sta eoff+1
        rts

; length of the next line (current line loaded, has a CR) -> nlen; reloads the current line
nextlen:
        lda ls
        pha
        lda ls+1
        pha
        sec
        lda ls
        adc lbn
        sta lnoff
        lda ls+1
        adc #0
        sta lnoff+1
        jsr loadline
        lda lbn
        sta nlen
        pla
        sta ls+1
        pla
        sta ls
        jmp curline

; insert A bytes from ib at line index Y (offset ls+Y). Carry set if it does not fit.
insat:  sta T4
        clc
        adc lbn
        bcs @no
        cmp #MAXLN+1
        bcs @no
        jsr yoff
        lda #<ib
        sta P3
        lda #>ib
        sta P3+1
        lda T4
        jmp insbytes
@no:    jsr bell
        sec
        rts

; delete A bytes at line index Y
delat:  sta T4
        jsr yoff
        lda T4
        jmp delbytes

yoff:   tya
        clc
        adc ls
        sta eoff
        lda ls+1
        adc #0
        sta eoff+1
        rts

; before an edit: remember where the cursor line is on the screen (the redraw starts there), and keep the line as
; it is now for Ctrl-R, unless it is already kept (an earlier edit of the same line)
ed_begin:
        lda ulv                 ; (1 = kept; $81 = Ctrl-R was the last edit of it: keep it afresh)
        cmp #1
        bne @sv
        lda uls
        cmp ls
        bne @sv
        lda uls+1
        cmp ls+1
        beq @kept
@sv:    ldy lbn
        sty ubn
@cp:    lda lb,y
        sta ub,y
        dey
        cpy #$FF
        bne @cp
        lda ls
        sta uls
        lda ls+1
        sta uls+1
        lda #1
        sta ulv
@kept:
        ldx ci                  ; the first unit an edit can change: the previous one for plain text,
        lda uf,x                ; three back near Hangul (a syllable's extent depends on the next two keys)
        and #F_NEEDK
        bne @h3
        cpx #0
        beq @z
        lda uf-1,x
        bmi @h3
        cpx #2
        bcc @p1
        lda uf-2,x
        bmi @h3
@p1:    dex
@z:     stx efrom
        jmp @go
@h3:    lda ci
        sec
        sbc #3
        bcs @f0
        lda #0
@f0:    sta efrom
@go:
        ldx ni
        lda ur,x
        sta orows
        lda lbn
        sta olen
        lda ls
        sta P3
        lda ls+1
        sta P3+1
; The screen row that shows the start of the line at offset P3: the redraw starts there (drr, drk, drln, drl).
; Carry set, and edfull = 3, if that line is not on the screen: everything is redrawn
rowof:  ldy #0
@l:     lda sv,y
        beq @n
        lda sl_lo,y
        cmp P3
        bne @n
        lda sl_hi,y
        cmp P3+1
        beq @f
@n:     iny
        cpy #ROWS
        bcc @l
        lda #3
        sta edfull
        rts
@f:     lda #0
        sta edfull
        sty drr
        lda sr,y
        sta drk
        lda sln_lo,y
        sta drln
        lda sln_hi,y
        sta drln+1
        lda P3
        sta drl
        lda P3+1
        sta drl+1
        clc
        rts

; the redraw starts at the previous line (joining lines at the start of a line); P3 = previous line start
joinrow:
        jsr rowof
        bcc @x
        lda P3                  ; the previous line is above the screen: it becomes the top line
        sta topl
        lda P3+1
        sta topl+1
        lda #0
        sta topr
        sec
        lda cln
        sbc #1
        sta topln
        lda cln+1
        sbc #0
        sta topln+1
@x:     rts

; after an edit in one line: A = index of the new cursor position in that line
ed_line:
        jsr edpre
        lda lbn                 ; shift the later rows' line starts by the size change (T0/T1, signed)
        sec
        sbc olen
        sta T0
        ldx #0
        bcs @p
        dex
@p:     stx T1
        ldy drr
        iny
@s:     cpy #ROWS
        bcs @sd
        lda sl_hi,y
        cmp ls+1
        bne @c
        lda sl_lo,y
        cmp ls
@c:     beq @nx
        bcc @nx
        clc
        lda T0
        adc sl_lo,y
        sta sl_lo,y
        lda sl_hi,y
        adc T1
        sta sl_hi,y
        lda snext_hi,y          ; snext moves too (it is the start of a later line)
        and snext_lo,y
        cmp #$FF
        beq @nx
        clc
        lda T0
        adc snext_lo,y
        sta snext_lo,y
        lda snext_hi,y
        adc T1
        sta snext_hi,y
@nx:    iny
        bne @s
@sd:    lda edfull
        bne edfu
        ldx ni
        lda ur,x
        cmp orows
        bne edmore
        lda #1
        sta dmode
        sta dirty
        ldx efrom               ; start at the row of the first unit that can have changed
        cpx ni
        bcc @e1
        ldx ni
@e1:    stx dfrom
        lda ur,x
        sec
        sbc drk
        bcc @e2
        clc
        adc drr
        cmp #ROWS
        bcs @e2
        sta drr
        lda ur,x
        sta drk
        jmp toprows
@e2:    lda #0
        sta dfrom
        beq toprows

; load the cursor line again and put the cursor at line index A
edpre:  sta etgt
        jsr curline
        lda etgt
        jmp snap

; after an edit that changed the number of lines: A = index of the new cursor position in line ls
ed_lines:
        ldx #0                  ; the lines moved: nothing to put back
        stx ulv
        jsr edpre
        lda edfull
        bne edfu
edmore: lda #2                  ; the rows change: redraw to the bottom
        sta dmode
        .byte $2C
edfu:   lda #3                  ; redraw everything
        sta dirty

; if the top row is inside the cursor line and that line got shorter, keep the top row inside it
toprows:
        lda topl
        cmp ls
        bne @x
        lda topl+1
        cmp ls+1
        bne @x
        ldx ni
        lda ur,x
        cmp topr
        bcs @x
        sta topr
        lda #3
        sta dirty
@x:     rts

; ci = first unit at or after line index A
snap:   sta T0
        ldx #0
@l:     lda u,x
        cmp T0
        bcs @f
        inx
        cpx ni
        bcc @l
        beq @l
        ldx ni
@f:     stx ci
        rts

