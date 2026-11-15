; KDEXPORT: converts the KDIARY diary (encrypted, random access, one file per month) into plain sequential text files,
; one per month, "DIARY-2026-11", in K-HANGEUL's N-byte text form (bit 7 set, Hangul runs Ctrl-K .. Ctrl-A, lines end
; with $8D), so that they can be taken off the disk with AppleCommander (acx -g) and converted to UTF-8 on a PC
; with nbyte.py (decode). The files are NOT encrypted: keep the disk safe.
;
; BRUN KDEXPORT (after the diary has ended: K-HANGEUL stays in memory). It asks where the diary data is (drive, or
; slot + drive), where to write the files (the same or another disk), and the password. Both disks may be the same:
; two DOS file buffers are used, one for the month file being read and one for the file being written.
;
; Text of the diary is read with the DOS 3.3 file manager ($3D6), the catalog with RWTS, exactly as KDIARY does
; (see shell.s there for the file layout and the encryption).

        .setcpu "6502"

KBD     = $C000
KBDSTRB = $C010
REALOUT = $AA53                 ; DOS's saved output routine (a BRUN program runs inside DOS's output hook)
TXTTAB  = $67
VARTAB  = $69
ARYTAB  = $6B
STREND  = $6D
FRETOP  = $6F
HIMEM   = $73
INVFLG  = $32
WNDBTM  = $23
WNDWDTH = $21
HOME    = $FC58
TACNT   = $942B                 ; K-HANGEUL's type-ahead ring, as in kdiary.s
TAIDX   = $942C
TARING  = $95AE
DOSBUFS = $9D00
DOSDRV  = $AA68
DOSSLOT = $AA6A
LOCFPL  = $03DC
LOCRPL  = $03E3
FMGR    = $03D6
RWTS    = $03D9

P1      = $10
P2      = $12
P3      = $15
SEGP    = $17
T0      = $19
T1      = $1B
T2      = $1C
T3      = $1D
T4      = $1E
T5      = $1F

CR      = $8D
SPC     = $A0
MAGIC   = $5A
MAXTXT  = 1200
MAXM    = 96

        .segment "CODE"

start:  cld
        tsx
        stx savesp
        lda TAIDX               ; (the driver's ring is used only when it is the 0-31 kind)
        cmp #$20
        bcc @ta
        inc taoff
@ta:    lda DOSDRV
        sta ddrv
        sta odrv
        lda DOSSLOT
        sta dslot
        sta oslot
        lda #<m_banner
        ldy #>m_banner
        jsr puts
        lda #<m_hint
        ldy #>m_hint
        jsr puts
        lda #<m_data
        ldy #>m_data
        jsr puts
        lda #<ddrv
        sta P3
        lda #>ddrv
        sta P3+1
        jsr askdisk
        lda #<m_out
        ldy #>m_out
        jsr puts
        lda #<odrv
        sta P3
        lda #>odrv
        sta P3+1
        jsr askdisk
@pw:    jsr askpw
        jsr checkpw
        bcc @ok
        lda #<m_bad
        ldy #>m_bad
        jsr puts
        jmp @pw
@ok:    jsr catscan
        lda lsn
        bne @go
        lda #<m_none
        ldy #>m_none
        jsr puts
        jmp quit
@go:    lda #0
        sta lsi
        sta ecount
        sta ecount+1
        sta efiles
@m:     ldx lsi
        cpx lsn
        bcs @done
        lda mty,x
        sta yy
        lda mtm,x
        sta mo
        jsr exmonth
        bcs @fail
        inc lsi
        jmp @m
@done:  lda #<m_done1
        ldy #>m_done1
        jsr puts
        lda ecount
        sta numv
        lda ecount+1
        sta numv+1
        jsr prdec
        lda #<m_done2
        ldy #>m_done2
        jsr puts
        lda efiles
        sta numv
        lda #0
        sta numv+1
        jsr prdec
        lda #<m_done3
        ldy #>m_done3
        jsr puts
        lda #0
        sta lsi
@nm:    lda lsi
        cmp efiles
        bcs @nd
        tax
        lda exi,x
        tax
        lda mty,x
        sta yy
        lda mtm,x
        sta mo
        jsr mknames
        lda #SPC
        jsr cout
        lda #SPC
        jsr cout
        ldx #0
@pn2:   lda oname,x
        stx T3
        jsr cout
        ldx T3
        inx
        cpx #13
        bcc @pn2
        jsr crout
        inc lsi
        bne @nm
@nd:    jmp quit
@fail:  lda #<m_stop
        ldy #>m_stop
        jsr puts
quit:   lda #<m_anykey
        ldy #>m_anykey
        jsr puts
        jsr getkey
        lda TXTTAB              ; the program sat in BASIC's area: leave an empty program behind (like NEW), as KDIARY does
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

; ---------------------------------------------------------------------------------------------------------------
; screen and keys
; ---------------------------------------------------------------------------------------------------------------
; print the zero-terminated ASCII string A/Y
puts:   sta SEGP
        sty SEGP+1
        ldy #0
@l:     lda (SEGP),y
        beq @x
        ora #$80
        jsr cout
        iny
        bne @l
@x:     rts

cout:   jmp (REALOUT)

crout:  lda #CR
        jmp cout

; print numv (16 bits) in decimal
prdec:  lda #0
        sta T4                  ; a digit has been printed
        ldx #4
@d:     lda #'0'|$80
        sta T5
@s:     lda numv
        sec
        sbc dlo,x
        tay
        lda numv+1
        sbc dhi,x
        bcc @p
        sta numv+1
        sty numv
        inc T5
        bne @s
@p:     lda T5
        cmp #'0'|$80
        bne @pr
        lda T4
        bne @pr
        cpx #0
        bne @n
@pr:    inc T4
        lda T5
        jsr cout
@n:     dex
        bpl @d
        rts
dlo:    .byte <1,<10,<100,<1000,<10000
dhi:    .byte >1,>10,>100,>1000,>10000

; the driver's ring first, then the keyboard (see kdiary.s getkey)
getkey: lda TACNT
        bne gkring
        lda KBD
        bpl getkey
gkend:  sta KBDSTRB
        bmi gkgot
gkring: ldx taoff
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
        rts

; line input into inb (inl = length, at most 16), A = 1: show stars. RETURN ends it
getline:
        sta gmask
        lda #0
        sta inl
@k:     jsr getkey
        cmp #$0D
        beq @e
        cmp #$08
        beq @bs
        cmp #$7F
        beq @bs
        cmp #$20
        bcc @k
        ldx inl
        cpx #16
        bcs @k
        sta inb,x
        inc inl
        ldy gmask
        beq @p
        lda #'*'
@p:     ora #$80
        jsr cout
        jmp @k
@bs:    lda inl
        beq @k
        dec inl
        lda #$88
        jsr cout
        lda #SPC
        jsr cout
        lda #$88
        jsr cout
        jmp @k
@e:     jmp crout

; ask for a disk: P3 = its drive byte (the slot byte follows 2 bytes later: ddrv, dslot / odrv, oslot are 1 byte apart
; in the order drive, slot). RETURN keeps the shown one; "2" = drive 2 of the same slot; "52" = slot 5, drive 2.
askdisk:
@a:     lda #<m_cur0            ; "[S6,D1]"
        ldy #>m_cur0
        jsr puts
        ldy #1
        lda (P3),y              ; slot
        ora #$B0
        jsr cout
        lda #<m_cur1
        ldy #>m_cur1
        jsr puts
        ldy #0
        lda (P3),y              ; drive
        ora #$B0
        jsr cout
        lda #']'|$80
        jsr cout
        lda #<m_prompt
        ldy #>m_prompt
        jsr puts
        lda #0
        jsr getline
        jsr parsedisk
        bcs @bad
        ldy #0
        lda ndrv
        beq @nd0
        sta (P3),y
@nd0:   iny
        lda nslot
        beq @ok
        sta (P3),y
@ok:    lda #<m_slot            ; show what was understood: "슬롯 6, 드라이브 2"
        ldy #>m_slot
        jsr puts
        ldy #1
        lda (P3),y
        ora #$B0
        jsr cout
        lda #<m_drive
        ldy #>m_drive
        jsr puts
        ldy #0
        lda (P3),y
        ora #$B0
        jsr cout
        jmp crout
@bad:   lda #<m_baddisk
        ldy #>m_baddisk
        jsr puts
        jmp @a

askpw:  lda #<m_pw
        ldy #>m_pw
        jsr puts
        lda #1
        jsr getline
        lda inl
        beq askpw
        sta pwn
        ldx #0
@c:     lda inb,x
        cmp #'a'
        bcc @s
        cmp #'z'+1
        bcs @s
        and #$DF                ; the II Plus types capitals
@s:     sta pw,x
        inx
        cpx inl
        bcc @c
        rts

; The answer to "which disk" (inb/inl): DOS 3.3's "S6,D2" (slot, drive; either part alone is fine: "D2", "S5"), or digits:
; "2" = drive 2, "62" = slot 6 drive 2. nslot / ndrv = 0 when not given. Carry set: not understood.
parsedisk:
        lda #0
        sta nslot
        sta ndrv
        sta ndg
        tax
@l:     cpx inl
        bcs @e
        lda inb,x
        inx
        cmp #'a'
        bcc @u
        cmp #'z'+1
        bcs @u
        and #$DF
@u:     cmp #'S'
        beq @s
        cmp #'D'
        beq @d
        cmp #'0'
        bcc @l
        cmp #'9'+1
        bcs @l
        sec
        sbc #'0'
        ldy ndg
        cpy #2
        bcs @bad
        sta nbd,y
        inc ndg
        jmp @l
@s:     jsr @dig
        bcs @bad
        sta nslot
        jmp @l
@d:     jsr @dig
        bcs @bad
        sta ndrv
        jmp @l
@dig:   cpx inl
        bcs @nd
        lda inb,x
        sec
        sbc #'0'
        cmp #10
        bcs @nd
        inx
        clc
        rts
@nd:    sec
        rts
@e:     lda ndg
        beq @chk
        cmp #2
        beq @two
        lda nbd
        sta ndrv
        jmp @chk
@two:   lda nbd
        sta nslot
        lda nbd+1
        sta ndrv
@chk:   lda nslot
        beq @ds
        cmp #8
        bcs @bad
@ds:    lda ndrv
        beq @ok
        cmp #3
        bcs @bad
@ok:    lda inl
        beq @good
        lda nslot
        ora ndrv
        beq @bad
@good:  clc
        rts
@bad:   sec
        rts

; ---------------------------------------------------------------------------------------------------------------
; the file manager (a copy of kdiary.s with two disks: the data disk, and the output disk)
; ---------------------------------------------------------------------------------------------------------------
; use the data disk / output disk and its file buffers for the next call
usedata:
        lda ddrv
        sta fdrv
        lda dslot
        sta fslt
        ldx #5
@c:     lda fmbi,x
        sta fmbuf,x
        dex
        bpl @c
        rts
useout: lda odrv
        sta fdrv
        lda oslot
        sta fslt
        ldx #5
@c:     lda fmbo,x
        sta fmbuf,x
        dex
        bpl @c
        rts

; set up the parameter list: A = call type
fmset:  pha
        jsr LOCFPL
        sty P2
        sta P2+1
        ldy #0
        pla
        sta (P2),y
        iny
        lda #0
@z:     sta (P2),y
        iny
        cpy #12
        bcc @z
        ldy #0
        lda (P2),y
        cmp #1
        bne @nr
        ldy #2
        lda #1
        sta (P2),y
@nr:    cmp #2
        beq @buf
        cmp #3
        beq @buf
        cmp #4
        beq @buf
        ldy #5
        lda fdrv
        sta (P2),y
        iny
        lda fslt
        sta (P2),y
        ldy #8
        lda fnp
        sta (P2),y
        iny
        lda fnp+1
        sta (P2),y
@buf:   ldy #$0C
        ldx #0
@b1:    lda fmbuf,x
        sta (P2),y
        iny
        inx
        cpx #6
        bcc @b1
        rts

fmcall: jsr FMGR
        ldy #$0A
        lda (P2),y
        sta ferr
        cmp #1
        bcs @e
        clc
@e:     rts

fmclose:
        lda #2
        jsr fmset
        ldx #1
        jmp fmcall

setname:
        sta fnp
        sty fnp+1
        rts

; DELETE the file named A/Y (a missing file is fine)
fmdel:  jsr setname
        lda #5
        jsr fmset
        ldx #1
        jsr fmcall
        bcc @x
        cmp #6
        beq @ok
        sec
        rts
@ok:    clc
@x:     rts

; OPEN the file named A/Y; X = 1: it must exist, X = 0: it is created if missing. Carry set on error (A = code)
fmopen: jsr setname
        lda #1
        jsr fmset
        ldx fcreate
        jsr fmcall
        bcc @x
        ldx fcreate
        bne @e
        cmp #6
        beq @ok
@e:     sec
        rts
@ok:    clc
@x:     rts

; positioned read (A = 3) or write (A = 4) of a range in slot X at byte soff: P3 = address, T1/T2 = length.
; A write of field L writes L+1 bytes, a read of L reads L (found by test), so a write sends length - 1.
slotio: ldy #0
        sty soff
        sty soff+1
slotoff:
        stx T0
        sta sop
        jsr fmset
        ldy #1
        lda #4
        sta (P2),y
        lda T0
        asl a
        asl a
        clc
        adc T0
        clc
        adc soff+1
        ldy #3
        sta (P2),y
        dey
        lda soff
        sta (P2),y
        ldy #6
        lda sop
        cmp #4
        beq @w
        lda T1
        sta (P2),y
        iny
        lda T2
        jmp @l
@w:     lda T1
        sec
        sbc #1
        sta (P2),y
        iny
        lda T2
        sbc #0
@l:     sta (P2),y
        iny
        lda P3
        sta (P2),y
        iny
        lda P3+1
        sta (P2),y
        ldx #1
        jmp fmcall

clrbufs:
        ldx #5
        lda #0
@z:     sta fmbi,x
        sta fmbo,x
        dex
        bpl @z
        rts

; a free DOS file buffer that is not one in use here (fmbi, fmbo) -> fmbuf
findbuf:
        lda DOSBUFS
        sta P1
        lda DOSBUFS+1
        sta P1+1
@l:     ldy #0
        lda (P1),y
        beq @chk
        ldy #$25
        lda (P1),y
        beq @chk
@nx:    ldy #$24
        lda (P1),y
        pha
        iny
        lda (P1),y
        sta P1+1
        pla
        sta P1
        jmp @l
@chk:   ldy #$1E                ; its work area is not one of ours
        lda (P1),y
        cmp fmbi
        bne @n1
        iny
        lda (P1),y
        cmp fmbi+1
        beq @nx
@n1:    ldy #$1E
        lda (P1),y
        cmp fmbo
        bne @take
        iny
        lda (P1),y
        cmp fmbo+1
        beq @nx
@take:  ldy #$1E
        ldx #0
@c:     lda (P1),y
        sta fmbuf,x
        iny
        inx
        cpx #6
        bcc @c
        rts

; ---------------------------------------------------------------------------------------------------------------
; the password check file and the encryption
; ---------------------------------------------------------------------------------------------------------------
pwname: .byte $D0,$D7,$C3,$C8,$CB               ; PWCHK
        .res 25,$A0
phrase: .byte $CB,$C4,$C9,$C1,$D2,$D9,$A1,$A1   ; KDIARY!!

; carry clear: the password is right (PWCHK on the data disk holds the phrase encrypted with it)
checkpw:
        jsr clrbufs
        jsr findbuf
        ldx #5
@c:     lda fmbuf,x
        sta fmbi,x
        dex
        bpl @c
        jsr usedata
        lda #<pwname
        ldy #>pwname
        ldx #1
        stx fcreate
        jsr fmopen
        bcc @r
        lda #<m_nopw
        ldy #>m_nopw
        jsr puts
        jmp quit
@r:     lda #<chk
        sta P3
        lda #>chk
        sta P3+1
        lda #8
        sta T1
        lda #0
        sta T2
        lda #3
        ldx #0
        jsr slotio
        jsr fmclose
        ldx #7
@m:     lda phrase,x
        sta chk2,x
        dex
        bpl @m
        lda #<chk2
        sta P1
        lda #>chk2
        sta P1+1
        lda #8
        sta cl
        lda #0
        sta cl+1
        sta cy
        sta cm
        sta cd
        jsr crypt
        ldx #7
@x:     lda chk2,x
        cmp chk,x
        bne @bad
        dex
        bpl @x
        clc
        rts
@bad:   sec
        rts

; XOR cl bytes at P1 with the stream of (cy, cm, cd) and the password; cryptc continues the stream
crypt:  lda cd
        asl a
        asl a
        asl a
        sec
        sbc cd                  ; day * 7
        sta ca
        lda cm
        asl a
        clc
        adc cm                  ; month * 3
        clc
        adc ca
        clc
        adc cy
        sta ca
        lda #0
        sta cj
        lda cl
        ora cl+1
        bne @go
        rts
@go:    ldy #0
@l:     ldx cj
        lda pw,x
        clc
        adc ca
        eor (P1),y
        sta (P1),y
        lda ca
        clc
        adc #29
        sta ca
        inx
        cpx pwn
        bcc @s
        ldx #0
@s:     stx cj
        iny
        bne @n
        inc P1+1
@n:     lda cl
        bne @d
        dec cl+1
@d:     dec cl
        lda cl
        ora cl+1
        bne @l
        rts

; ---------------------------------------------------------------------------------------------------------------
; the months: the catalog of the data disk (RWTS), as in KDIARY
; ---------------------------------------------------------------------------------------------------------------
rdsec:  sta T1
        sty T2
        jsr LOCRPL
        sty P1
        sta P1+1
        lda dslot
        asl a
        asl a
        asl a
        asl a
        ldy #1
        sta (P1),y
        iny
        lda ddrv
        sta (P1),y
        iny
        lda #0
        sta (P1),y
        iny
        lda T1
        sta (P1),y
        iny
        lda T2
        sta (P1),y
        ldy #8
        lda fmbuf+4
        sta (P1),y
        iny
        lda fmbuf+5
        sta (P1),y
        ldy #$0C
        lda #1
        sta (P1),y
        ldy P1
        lda P1+1
        jsr RWTS
        lda #0
        sta $48
        rts

lsbuf:  lda fmbuf+4
        sta P2
        lda fmbuf+5
        sta P2+1
        rts

catscan:
        jsr clrbufs
        lda #0
        sta lsn
        jsr findbuf
        lda #17
        ldy #0
        jsr rdsec
        bcs @x
@sec:   jsr lsbuf
        ldy #1
        lda (P2),y
        beq @x
        pha
        iny
        lda (P2),y
        tay
        pla
        jsr rdsec
        bcs @x
        jsr lsbuf
        lda #$0B
@ent:   sta lsoff
        tay
        lda (P2),y
        beq @x
        cmp #$FF
        beq @nx
        jsr catent
@nx:    lda lsoff
        clc
        adc #35
        bcc @ent
        bcs @sec
@x:     rts

catent: ldx #0
        lda lsoff
        clc
        adc #3
        tay
@c:     lda (P2),y
        cmp mnpre,x
        bne @no
        iny
        inx
        cpx #MNPL
        bcc @c
        lda (P2),y
        cmp #'2'|$80
        bne @no
        iny
        lda (P2),y
        cmp #'0'|$80
        bne @no
        iny
        jsr ld2
        bcs @no
        cmp #1
        bcc @no
        sta tmy
        lda (P2),y
        cmp #'-'|$80
        bne @no
        iny
        jsr ld2
        bcs @no
        cmp #1
        bcc @no
        cmp #13
        bcs @no
        sta tmm
        lda (P2),y
        cmp #SPC
        bne @no
        jmp insertm
@no:    rts
ld2:    lda (P2),y
        sec
        sbc #$B0
        cmp #10
        bcs @bad
        sta T0
        asl a
        asl a
        clc
        adc T0
        asl a
        sta T0
        iny
        lda (P2),y
        sec
        sbc #$B0
        cmp #10
        bcs @bad
        clc
        adc T0
        iny
        clc
        rts
@bad:   sec
        rts

insertm:
        lda lsn
        cmp #MAXM
        bcs @x
        tax
@s:     txa
        beq @put
        dex
        lda mty,x
        cmp tmy
        bcc @put1
        bne @sh
        lda mtm,x
        cmp tmm
        bcc @put1
@sh:    lda mty,x
        sta mty+1,x
        lda mtm,x
        sta mtm+1,x
        jmp @s
@put1:  inx
@put:   lda tmy
        sta mty,x
        lda tmm
        sta mtm,x
        inc lsn
@x:     rts

; ---------------------------------------------------------------------------------------------------------------
; one month: read the flags, write "DIARY-20YY-MM" with the entries. Carry set: stop (a disk error)
; ---------------------------------------------------------------------------------------------------------------
; mname = the month file's name (the key-letter name of "일기", a space, 20YY-MM), oname = "DIARY-20YY-MM"
mknames:
        ldx #29
        lda #SPC
@c:     sta mname,x
        sta oname,x
        dex
        bpl @c
        ldx #MNPL-1
@p:     lda mnpre,x
        sta mname,x
        dex
        bpl @p
        ldx #5
@o:     lda onpre,x
        sta oname,x
        dex
        bpl @o
        lda #'2'|$80            ; "2026-11" after "DIARY-" (oname) and after the key-letter name (mname)
        sta mname+MNPL
        sta oname+6
        lda #'0'|$80
        sta mname+MNPL+1
        sta oname+7
        lda yy
        jsr twodig              ; -> T1 T2 (tens, ones)
        lda T1
        sta mname+MNPL+2
        sta oname+8
        lda T2
        sta mname+MNPL+3
        sta oname+9
        lda #'-'|$80
        sta mname+MNPL+4
        sta oname+10
        lda mo
        jsr twodig
        lda T1
        sta mname+MNPL+5
        sta oname+11
        lda T2
        sta mname+MNPL+6
        sta oname+12
        rts
onpre:  .byte 'D'|$80,'I'|$80,'A'|$80,'R'|$80,'Y'|$80,'-'|$80

; A (0-99) -> T1 = tens digit, T2 = ones digit (ASCII, bit 7 set)
twodig: ldx #0
@t:     cmp #10
        bcc @o
        sbc #10
        inx
        bne @t
@o:     ora #$B0
        sta T2
        txa
        ora #$B0
        sta T1
        rts

exmonth:
        jsr mknames
        jsr clrbufs             ; a month: the input file's buffers first
        jsr findbuf
        ldx #5
@c:     lda fmbuf,x
        sta fmbi,x
        dex
        bpl @c
        jsr usedata
        lda #<mname
        ldy #>mname
        ldx #1
        stx fcreate
        jsr fmopen
        bcc @op
        jmp @skip               ; no such file: skip it
@op:    lda #<flags
        sta P3
        lda #>flags
        sta P3+1
        lda #32
        sta T1
        lda #0
        sta T2
        lda #3
        ldx #0
        jsr slotio
        lda #<flags
        sta P1
        lda #>flags
        sta P1+1
        lda #32
        sta cl
        lda #0
        sta cl+1
        sta cd
        lda mo
        sta cm
        lda yy
        sta cy
        jsr crypt
        lda flags
        cmp #MAGIC
        bne @none
        ldx #31
        lda #0
@cnt:   ora flags,x
        dex
        bne @cnt
        and #1
        bne @have
@none:  jsr usedata
        jsr fmclose
        clc
        rts
@have:  jsr findbuf             ; the output file: another buffer
        ldx #5
@c2:    lda fmbuf,x
        sta fmbo,x
        dex
        bpl @c2
        jsr useout
        lda #<oname
        ldy #>oname
        jsr fmdel
        bcs @oerr
        lda #<oname
        ldy #>oname
        ldx #0
        stx fcreate
        jsr fmopen
        bcs @oerr
        lda #4
        sta wsub                ; the first write positions at the start
        lda #<m_file
        ldy #>m_file
        jsr puts
        ldx #0
@pn:    lda oname,x
        stx T3
        jsr cout
        ldx T3
        inx
        cpx #13
        bcc @pn
        jsr crout
        lda #1
        sta eday
@day:   ldx eday
        lda flags,x
        beq @nd
        jsr exday
        bcs @derr
@nd:    inc eday
        lda eday
        cmp #32
        bcc @day
        jsr useout
        jsr fmclose
        jsr usedata
        jsr fmclose
        ldx efiles
        lda lsi
        sta exi,x
        inc efiles
        clc
        rts
@derr:  pha
        jsr useout
        jsr fmclose
        jsr usedata
        jsr fmclose
        pla
        jmp @err
@oerr:  pha
        jsr usedata
        jsr fmclose
        pla
@err:   jsr pdoserr
        sec
        rts
@skip:  clc
        rts

; the entry of day eday: read, decrypt, write "20YY-MM-DD", CR, the text, CR, CR. Carry set: error (A = code)
exday:  lda #<shdr
        sta P3
        lda #>shdr
        sta P3+1
        lda #0
        sta shdr
        sta shdr+1
        lda #2
        sta T1
        lda #0
        sta T2
        jsr usedata
        lda #3
        ldx eday
        jsr slotio
        bcs @r
        lda shdr
        ora shdr+1
        bne @n
        clc
        rts
@r:     rts
@n:     lda shdr+1
        cmp #>(MAXTXT+1)
        bcc @ok
        bne @sk2
        lda shdr
        cmp #<(MAXTXT+1)
        bcc @ok
@sk2:   clc
        rts
@ok:    lda #<(ebuf+11)
        sta P3
        sta P1
        lda #>(ebuf+11)
        sta P3+1
        sta P1+1
        lda shdr
        sta T1
        sta cl
        lda shdr+1
        sta T2
        sta cl+1
        lda #2
        sta soff
        lda #0
        sta soff+1
        lda #3
        ldx eday
        jsr slotoff
        bcs @r
        lda eday
        sta cd
        lda mo
        sta cm
        lda yy
        sta cy
        jsr crypt
        ldx #0                  ; the date line
        lda #'2'|$80
        sta ebuf,x
        lda #'0'|$80
        sta ebuf+1
        lda yy
        jsr twodig
        lda T1
        sta ebuf+2
        lda T2
        sta ebuf+3
        lda #'-'|$80
        sta ebuf+4
        sta ebuf+7
        lda mo
        jsr twodig
        lda T1
        sta ebuf+5
        lda T2
        sta ebuf+6
        lda eday
        jsr twodig
        lda T1
        sta ebuf+8
        lda T2
        sta ebuf+9
        lda #CR
        sta ebuf+10
        lda #<(ebuf+11)         ; after the text: CR CR
        clc
        adc shdr
        sta P1
        lda #>(ebuf+11)
        adc shdr+1
        sta P1+1
        ldy #0
        lda #CR
        sta (P1),y
        iny
        sta (P1),y
        lda shdr                ; length = 11 + text + 2
        clc
        adc #13
        sta T1
        lda shdr+1
        adc #0
        sta T2
        lda #<ebuf
        sta P3
        lda #>ebuf
        sta P3+1
        jsr useout
        jsr wrseq
        bcc @w1
        rts
@w1:    inc ecount
        bne @x
        inc ecount+1
@x:     clc
        rts
@skip:  clc
        rts

; write T1/T2 bytes at P3 to the output file: the first call positions at record 0 (subcode 4), the next ones go on (2)
wrseq:  lda #4
        jsr fmset
        ldy #1
        lda wsub
        sta (P2),y
        lda #2
        sta wsub
        ldy #6
        lda T1
        sec
        sbc #1
        sta (P2),y
        iny
        lda T2
        sbc #0
        sta (P2),y
        iny
        lda P3
        sta (P2),y
        iny
        lda P3+1
        sta (P2),y
        ldx #1
        jmp fmcall

; "DISK ERROR n"
pdoserr:
        cmp #10
        bne @n10
        lda #<m_locked          ; FILE LOCKED (e.g. an old DIARY-... on the output disk is locked)
        ldy #>m_locked
        jmp puts
@n10:   cmp #4
        bne @n4
        lda #<m_wprot
        ldy #>m_wprot
        jmp puts
@n4:    cmp #9
        bne @n9
        lda #<m_dfull
        ldy #>m_dfull
        jmp puts
@n9:    pha
        lda #<m_err
        ldy #>m_err
        jsr puts
        pla
        sta numv
        lda #0
        sta numv+1
        jsr prdec
        jmp crout

; ---------------------------------------------------------------------------------------------------------------
        .include "build/export_gen.inc"

        .segment "BSS"
savesp: .res 1
taoff:  .res 1
nslot:  .res 1
ndrv:   .res 1
ndg:    .res 1
nbd:    .res 2
ddrv:   .res 1                  ; data disk: drive, slot (askdisk needs this order)
dslot:  .res 1
odrv:   .res 1                  ; output disk: drive, slot
oslot:  .res 1
fdrv:   .res 1
fslt:   .res 1
fcreate: .res 1
ferr:   .res 1
fnp:    .res 2
fmbuf:  .res 6
fmbi:   .res 6
fmbo:   .res 6
soff:   .res 2
sop:    .res 1
inb:    .res 20
inl:    .res 1
gmask:  .res 1
pw:     .res 16
pwn:    .res 1
chk:    .res 8
chk2:   .res 8
cy:     .res 1
cm:     .res 1
cd:     .res 1
ca:     .res 1
cj:     .res 1
cl:     .res 2
numv:   .res 2
yy:     .res 1
mo:     .res 1
lsn:    .res 1
lsi:    .res 1
lsoff:  .res 1
tmy:    .res 1
tmm:    .res 1
ecount: .res 2
efiles: .res 1
exi:    .res MAXM               ; the month indexes that were written
eday:   .res 1
wsub:   .res 1
shdr:   .res 2
flags:  .res 32
mname:  .res 30
oname:  .res 30
mty:    .res MAXM
mtm:    .res MAXM
ebuf:   .res 11 + MAXTXT + 2
