; Shared by KEDIT and KDIARY: a change here changes both programs. See README.md in this folder.
; ==========================================================================
; keys
; ==========================================================================
; Keys typed while the driver was drawing are in its ring: they come first.
getkey: lda TACNT
        bne gkring
        lda KBD
        bpl getkey
gkend:  sta KBDSTRB             ; (the tests: getkey to here is the key wait loop)
        bmi gkgot
gkring: ldx taoff               ; (not the driver this was written for: its ring is left alone)
        bne gknone
        dec TACNT
        lda TAIDX
        sec
        sbc TACNT
        and #$1F
        tax
        lda TARING,x
        bne gkgot
gknone: lda #0
        sta TACNT
        beq getkey
gkgot:  and #$7F
        pha
        lda #0
        sta shift
        lda iie
        bne @e
        lda BUTN2               ; II Plus, Shift key mod: button 2 differs from its level at start-up
        and #$80
        cmp shidle
        beq @n
        bne @s
@e:     lda BUTN0               ; IIe and later: either Apple key is the shift
        ora BUTN1
        bpl @n
@s:     inc shift
@n:     pla
        rts

dispatch:
        cmp #$1B
        bne @a
        jmp command
@a:     cmp #$20
        bcc @ctl
        cmp #$7F
        bne @t
        jmp backsp
@t:     jmp typechar
@ctl:
        tax                     ; user-definable keys: the key map gives the action (the ctltab number) of this key
        lda keymap,x
        asl a
        tax
        lda ctltab+1,x
        pha
        lda ctltab,x
        pha
        rts

ctltab: .addr bell-1, k_han-1, k_left-1, cmd_dp-1, k_delf-1, k_end-1, k_findn-1, k_copy-1     ; @ A B C D E F G
        .addr k_lft-1, k_tab-1, k_down-1, k_up-1, k_redraw-1, k_ret-1, k_eol-1, k_bol-1   ; H I J K L M N O
        .addr k_paste-1, k_case-1, k_undo-1, backsp-1, k_top-1, k_right-1, bell-1, k_pgup-1 ; P Q R S T U V W
        .addr k_deol-1, k_delln-1, k_pgdn-1, bell-1, bell-1, bell-1, bell-1, bell-1      ; X Y Z [ \ ] ^ _

; The key map: for each control code $00-$1F, the number of the action it runs (the number of ctltab's entry: a
; key's own code when nothing is moved; 0 = no action, a bell). It is in the program file on purpose: the boot
; EXEC file BLOADs a KEYS file over it (made by KEYCFG, the Applesoft key setup) before KEDITK starts.
; Fixed: ESC ($1B, handled before), RETURN ($0D), Ctrl-A ($01) and Ctrl-H ($08, the left arrow).
keymap: .byte 0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31

bell:   lda #$87
        jmp putc

; $08 (the left arrow; Ctrl-H; a PC's Backspace in an emulator) moves left on every model. Backspace is Ctrl-S
; (ctltab) and DELETE ($7F), on every model. On a II Plus with the Shift key mod, Shift-left also deletes backward
; (gkgot sets the shift flag). A IIe has no such mod here: there Shift does nothing to the left arrow.
k_lft:  lda iie
        bne @l
        lda shift
        beq @l
        jmp backsp
@l:     jmp k_left

k_han:  lda han
        eor #1
        sta han
        rts
k_case: lda lower
        eor #1
        sta lower
        rts
k_redraw:
.ifdef FASTCLR
        lda #TROW0              ; the text rows are cleared at once (the driver's fast clear): no row needs blanks drawn
        ldx #ROWS+TROW0
        jsr fastclr
        lda #1
        sta stfull
        ldx #ROWS-1
        lda #0
@r:     sta rowlen,x
        dex
        bpl @r
        lda #SCRW               ; (the status row: drawn whole)
        sta rowlen+ROWS
.else
        lda #1
        sta stfull
        ldx #ROWS
@r:     lda #SCRW               ; every row is taken as full: drawing a row blanks the rest of it
        sta rowlen,x
        dex
        bpl @r
.endif
        lda #0
        sta stbg
        lda #3
        sta dirty
        rts
k_tab:  lda #SPC
        jmp inschar

