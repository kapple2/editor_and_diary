; Shared by KEDIT and KDIARY (see README.md in this folder): the addresses of the ROM, DOS 3.3 and K-HANGEUL that the
; editor uses, the memory outside the program that it works in, and its constants. No code.

        .setcpu "6502"
        .import __BSS_RUN__, __BSS_SIZE__

KBD     = $C000
KBDSTRB = $C010
BUTN0   = $C061                 ; Open-Apple (IIe and later)
BUTN1   = $C062                 ; Solid-Apple / Option
BUTN2   = $C063
WNDLFT  = $20
WNDWDTH = $21
WNDTOP  = $22
WNDBTM  = $23
CH      = $24
CV      = $25
BASL    = $28
BASH    = $29
INVFLG  = $32
TXTTAB  = $67
VARTAB  = $69
ARYTAB  = $6B
STREND  = $6D
FRETOP  = $6F
HIMEM   = $73
VTAB    = $FC22
HOME    = $FC58
LOCFPL  = $03DC
FMGR    = $03D6
REALOUT = $AA53
DOSDRV  = $AA68
DOSSLOT = $AA6A
TACNT   = $942B                 ; K-HANGEUL 1.2b: keys in its type-ahead ring (it takes keys while it draws),
TAIDX   = $942C                 ; index of the newest one,
TARING  = $95AE                 ; the ring (32 keys)
DOSBUFS = $9D00                 ; DOS: address of the first file buffer (its file name field)
LOCRPL  = $03E3
RWTS    = $03D9

lb      = $0200                 ; the line being edited (256 bytes)
sb      = $0300                 ; status line text (80 bytes)
cb      = $0350                 ; command line (64 bytes)
cw      = $0390                 ; command word (64 bytes, to $03CF)

; zero page: bytes that K-HANGEUL, DOS and the ROM routines used here do not touch
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

; ---- constants of the editor ----
.ifdef TOPLINE
TROW0   = 1                     ; the screen row of text row 0 (row 0 is the program's top line)
.else
TROW0   = 0
.endif
SCRW    = 46                    ; all the driver's columns. The driver would wrap (and at the bottom row scroll) after
WIDE    = 47                    ; the last column, so while the editor draws, the window is one column wider than the screen
MAXLN   = 250                   ; the longest line (bytes)
CR      = $8D
HK      = $8B                   ; Ctrl-K: a Hangul run starts
HA      = $81                   ; Ctrl-A: it ends
SPC     = $A0
F_NEEDK = $01
F_HAN   = $80
