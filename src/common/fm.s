; Shared by KEDIT and KDIARY: a change here changes both programs. See README.md in this folder.
; ==========================================================================
; files (DOS 3.3 file manager)
; ==========================================================================
; set up the parameter list: A = call type (1 OPEN, 2 CLOSE, 3 READ, 4 WRITE, 5 DELETE, 9 RENAME). Keeps X.
; Common fields: drive, slot, type 0, name, the three buffers.
fmset:  pha
        jsr LOCFPL
        sty P2
        sta P2+1
        ldy #11
        lda #0
@z:     sta (P2),y              ; clear bytes 1-11
        dey
        bne @z
        pla
        sta (P2),y
        cmp #1
        bne @nr
        ldy #2                  ; OPEN: record length 1, as DOS's own OPEN for a sequential file
        sta (P2),y
@nr:    cmp #2                  ; CLOSE, READ, WRITE: bytes 2-9 are record, offset, length, address
        bcc @nm
        cmp #5
        bcc @buf
@nm:    ldy #5
        lda ddrv                ; the current disk (the DOS default until the user names another)
        sta (P2),y
        iny
        lda dslot
        sta (P2),y
        ldy #8
        lda fnp
        sta (P2),y
        iny
        lda fnp+1
        sta (P2),y
@buf:   ldy #$11                ; work area, T/S list buffer, data buffer: bytes $0C-$11
@b1:    lda fmbuf-$0C,y
        sta (P2),y
        dey
        cpy #$0C
        bcs @b1
        rts

; the file manager's buffers: a free DOS file buffer (one whose name field is empty; the last one if all are taken,
; which cannot be when KEDIT has just been loaded). After its 30-byte name come the addresses of the work area, the
; T/S list buffer and the data buffer, then the link to the next buffer.
findbuf:
        lda DOSBUFS
        sta P1
        lda DOSBUFS+1
        sta P1+1
@l:     ldy #0
        lda (P1),y
        beq @take
        ldy #$25
        lda (P1),y
        beq @take
        pha
        dey
        lda (P1),y
        sta P1
        pla
        sta P1+1
        bne @l
@take:  ldy #$1E
        ldx #0
@c:     lda (P1),y
        sta fmbuf,x
        iny
        inx
        cpx #6
        bcc @c
        rts

; call the file manager, X = 0 (create the file if it is missing) or 1. A = return code, carry set on error
fmcall: jsr FMGR
        ldy #$0A
        lda (P2),y
        cmp #1
        bcs @e
        clc
@e:     rts

; Read the key map from the file KEYS (written by KEYCFG with BSAVE: 4 header bytes, then the 32 map bytes) into
; keymap. Carry set: no usable file (missing, not 32 bytes, or an action number above 31): the map is left as it is.
; (The two programs open and read the file in their own ways: the diary through its slot routines in shell.s.)
loadkeys:
.ifdef KDIARY
        lda #<pwname            ; (the name buffer says KEYS at this time)
        ldy #>pwname
        jsr mopen_r             ; (it is a binary file: its type is not looked at)
.else
        lda #<keysname
        ldy #>keysname
        jsr setname
        lda #1                  ; OPEN (it is a binary file: its type is not looked at)
        jsr fmset
        ldx #1
        jsr fmcall
.endif
        bcs @no
.ifdef KDIARY
        lda #3                  ; the 36 bytes are read into cw (64 bytes, not in use yet)
        ldx #0
        ldy #SI_KEYS
        jsr sio
        bcc @ok
        eor #5                  ; (END OF DATA: what was read is checked below)
        beq @ok
        jmp fmclose
@ok:    jsr fmclose
.else
        lda #<cw                ; the 36 bytes are read into cw (64 bytes, not in use yet)
        sta P3
        lda #>cw
        sta P3+1
        lda #36
        sta T1
        lda #0
        sta T2
        jsr fmread              ; (closes the file; on an error it sets a message, which the caller replaces)
        bcs @no
.endif
        lda cw+2                ; the header's length field
        cmp #32
        bne @no
        ldx #31
@c:     lda cw+4,x
        cmp #32
        bcs @no
        dex
        bpl @c
        ldx #31
@m:     lda cw+4,x
        sta keymap,x
        dex
        bpl @m
        clc
        rts
@no:    sec
        rts

.ifdef KDIARY
; the name of the file opened without a month: KEYS at the start, then start puts PWCHK here (30 bytes, with spaces)
pwname: .byte $CB,$C5,$D9,$D3
.else
keysname:
        .byte $CB,$C5,$D9,$D3   ; KEYS, then spaces to 30 bytes
.endif
        .res 26,$A0

fmclose:
        lda #2
        jsr fmset
        ldx #1
        jmp fmcall

.ifndef KDIARY                  ; (the diary reads and writes through its slot routine, sio in shell.s)
; read/write a range: A = call type (3 or 4), X = subcode, P3 = address, T1/T2 = length field
fmrange:
        stx fmsub
        jsr fmset
        ldy #1
        lda fmsub
        sta (P2),y
        ldy #6
        lda T1
        sta (P2),y
        iny
        lda T2
        sta (P2),y
        iny
        lda P3
        sta (P2),y
        iny
        lda P3+1
        sta (P2),y
        ldx #1
        jmp fmcall
.endif

; DOS error A -> message
dosmsg: ldx #4
@l:     cmp dmc,x
        beq @f
        dex
        bpl @l
        sta numv                ; "disk error N"
        lda #0
        sta numv+1
        sta sbn
        lda #<m_diskerr
        ldy #>m_diskerr
        jsr sbstr
        jsr sbnum
        jmp sbmsg
@f:     lda dml,x
        ldy dmh,x
        jmp setmsg
dmc:    .byte 4, 6, 9, 10, 8
dml:    .byte <m_wprot, <m_nofile, <m_dfull, <m_locked, <m_ioerr
dmh:    .byte >m_wprot, >m_nofile, >m_dfull, >m_locked, >m_ioerr

; the name the next OPEN, DELETE or RENAME works on: A/Y (keeps X), or fname
.ifndef KDIARY                  ; (the diary has no file name of its own: its files are the month files)
realname:
        lda #<fname
        ldy #>fname
.endif
setname:
        sta fnp
        sty fnp+1
        rts

