; Shared by KEDIT and KDIARY: a change here changes both programs. See README.md in this folder.
; clear the screen rows A to X-1 and no others, with the driver's own fast clear (the one HOME ends up in): the control
; code Ctrl-L is its CLEARHOME, which clears the rows WNDTOP to WNDBTM-1 (and homes the cursor to the window's top left).
; So the window is set to those rows for the one character, then put back. The rows' own lengths (rowlen) are the
; caller's business, and so is the cursor.
fastclr:
        sta WNDTOP
        stx WNDBTM
        lda #46                 ; (the driver's clear loops move WNDWDTH bytes of a row)
        sta WNDWDTH
        lda #$8C
        jsr putc
        lda #WIDE
        sta WNDWDTH
        lda #16
        sta WNDBTM
        lda #0
        sta WNDTOP
        rts
