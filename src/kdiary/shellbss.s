; KDIARY shell variables (included into the BSS segment of kdiary.s)
; One block of dates and list positions: cp3 / cp2 copy inside it by offset (D_* in shell.s). Keep the order.
yy:     .res 1                  ; the chosen date: year - 2000 (1-99), month, day
mo:     .res 1
dy:     .res 1
oyy:    .res 1                  ; the date before a key moved it
omo:    .res 1
ody:    .res 1
tyy:    .res 1                  ; today
tmo:    .res 1
tdy:    .res 1
sy:     .res 1                  ; the chosen date, saved while the list is shown
smo:    .res 1
sdy:    .res 1
tgy:    .res 1                  ; the date looked for in the list
tgm:    .res 1
tgd:    .res 1
nm:     .res 1                  ; a position in the list while moving (month index, day)
nd:     .res 1
lsm:    .res 1                  ; the selection
lsdy:   .res 1
lpm:    .res 1                  ; the first row of the page
lpd:    .res 1

dim:    .res 1                  ; days in the month
dow1:   .res 1                  ; weekday of the 1st (0 = Sunday)
cdy:    .res 1
cfresh: .res 1                  ; drawing on a screen that was just cleared: blanks need not be drawn
cist:   .res 1                  ; the title line of the calendar: 0 empty, 1 "no entry", 2 a title
cinl:   .res 1                  ; and its columns
pzf:    .res 1                  ; two-digit numbers: pad with 0 (1) or a blank (0)
ndg:    .res 1
nbd:    .res 2
; the data disk and the password: swdisk keeps and restores these 19 bytes as one block
ddrv:   .res 1                  ; the data disk: drive and slot
dslot:  .res 1
pw:     .res 16
pwn:    .res 1
; encryption
cd:     .res 1                  ; the day of a title being read
ca:     .res 1                  ; the stream: its value and the place in the password
cj:     .res 1
; input line
inb:    .res 20
gmax:   .res 1
gmask:  .res 1
lx:     .res 1
ly:     .res 1
chk:    .res 8
chk2:   .res 8
; month file
shdr:   .res 2
tlen:   .res 2                  ; the length of the trimmed copy for the save (trimtxt)
tls:    .res 2                  ; the copy: the start of the line being copied, the end of its text, the end of the copy
tkc:    .res 2
tkp:    .res 2
tlc:    .res 1                  ; the line being copied has a character                  ; the length field of a slot
soff:   .res 2                  ; byte offset inside the slot for slotoff
flags:  .res 32                 ; flags[0] = magic, flags[1..31] = 1 if the day has an entry
tt:     .res 40                 ; a title
pw1     = tt                    ; (the first of the two new passwords, while they are asked)
otl:    .res 40                 ; the title on the top line of the editor,
otlen:  .res 1                  ; its bytes ($FF: the top line is not drawn yet)
otcol:  .res 1                  ; and its columns
; list of all the entries
cmode:  .res 1                  ; the command line is the calendar's (own commands)
cquit:  .res 1
cagain: .res 1                  ; ESC at the calendar's help: the command line again
tdone:   .res 1                 ; the start screen's picture, greeting and footer are on the screen (title_screen)
sure:    .res 1                  ; the delete of the calendar (D) has been asked: save does not ask again
started: .res 1                 ; the first password was accepted: no picture any more, ESC at a password goes back
lsi:    .res 1
lsj:    .res 1
lsop:   .res 1
lsrw:   .res 1
lsnr:   .res 1                  ; rows on the page
tmy:    .res 1
tmm:    .res 1
tmk:    .res 4
rm:     .res 12
rd:     .res 12
lstl:   .res 12
; the arrays of the list live in the text space (it is not used while the list is shown): 1152 bytes of its 1200
lstt    = bufmem                ; 12 titles of 32 bytes
mty     = bufmem+384            ; the months with entries: year, month, and the masks of their days
mtm     = bufmem+384+MAXM
mk      = bufmem+384+2*MAXM
mtt     = bufmem+384+6*MAXM     ; the track and the sector of each month file's track/sector list
mts     = bufmem+384+7*MAXM
