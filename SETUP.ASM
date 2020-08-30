;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;            
;   Drivers, background, skin for Menuet
;
;   Compile with FASM 1.60 or above
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

use64

    org   0x0

    db    'MENUET64'              ; Header identifier
    dq    0x01                    ; Version
    dq    START                   ; Start of code
    dq    image_end               ; Size of image
    dq    0x200000                ; Memory for app
    dq    0x1ffff0                ; Esp
    dq    0x00                    ; Prm 
    dq    0x00                    ; Icon

include 'textbox.inc'

yadd equ 00

START:

    call  add_system_path

    mov   rax , 141
    mov   rbx , 1
    mov   rcx , 1
    mov   rdx , 5 shl 32 + 5
    mov   r8  , 9 shl 32 + 12
    int   0x60

    ; IPC

    mov   rax , 60
    mov   rbx , 1
    mov   rcx , ipc_memory
    mov   rdx , 100
    int   0x60

    call  draw_window       ; At first, draw the window

still:

    mov   rax , 23          ; Wait here for event
    mov   rbx , 10
    int   0x60

    test  rax , 0x1         ; Window redraw
    jnz   window_event
    test  rax , 0x2         ; Keyboard press
    jnz   key_event
    test  rax , 0x4         ; Button press
    jnz   button_event

    cmp   [ipc_memory+16],byte 0
    je    still

    mov   rdi , [waiting]
    imul  rdi , (textbox2-textbox1)
    add   rdi , textbox1+48
    mov   rax , rdi
    mov   rsi , ipc_memory+16
    mov   rcx , 48
    cld
    rep   movsb

    mov   rcx , 0 
    dec   rcx
  nextlen:
    inc   rcx
    cmp   [ipc_memory+16+rcx],byte 0
    jne   nextlen
    mov   [rax-8],rcx

    mov   r14 , [waiting]
    imul  r14 , 8
    mov   r14 , [textbox_list+r14]
    call  draw_textbox  

    mov   [waiting],dword 0 
    mov   [ipc_memory+16],byte 0
    mov   [ipc_memory+8],dword 16

    jmp   still

window_event:

    call  draw_window
    jmp   still

key_event:

    mov   rax , 0x2        ; Read the key and ignore
    int   0x60

    cmp   rbx , 0
    je    still

    jmp   still


button_event:

    mov   rax , 0x11
    int   0x60

    cmp   rbx , 121
    jne   noautomatedscan
    call  scan_drivers
    jmp   still
  noautomatedscan:

    cmp   rbx , 0x102
    jne   noinfo
    call  show_help
    jmp   still
  noinfo:

    cmp   rbx , 21
    jb    no_read_textbox
    cmp   rbx , 29
    ja    no_read_textbox
    sub   rbx , 21
    imul  rbx , 8
    mov   r14 , [textbox_list+rbx]
    call  read_textbox
    jmp   still
  no_read_textbox:

    cmp   rbx , 31
    jb    no_browse
    cmp   rbx , 39
    ja    no_browse
    sub   rbx , 31
    mov   [waiting],rbx
    mov   rax , 111
    mov   rbx , 1
    int   0x60
    mov   rdi , parameter+6
  newdec:
    mov   rbx , 10
    xor   rdx , rdx
    div   rbx
    add   rdx , 48
    mov   [rdi],dl
    dec   rdi
    cmp   rdi , parameter + 1
    jg    newdec
    mov   rax , 256
    mov   rbx , file_search
    mov   rcx , parameter
    int   0x60
    jmp   still
  no_browse:

    cmp   rbx , 0x10000001
    jne   no_application_terminate_button
    mov   rax , 512
    int   0x60
  no_application_terminate_button:

    cmp   rbx , 0x103                   ; Driver states
    jne   no_application_driver_states
    mov   rax , 256
    mov   rbx , string_unzip
    mov   rcx , string_param
    int   0x60
    jmp   still
  no_application_driver_states:

    cmp   rbx , 0x105                   ; Menu
    jne   no_application_terminate_menu
    mov   rax , 0x200
    int   0x60
  no_application_terminate_menu:

    ; Load new background

    cmp   rbx , 15+1
    jne   no_new_background
    mov   rsi , textbox6+48
    mov   rdi , param+1
    mov   rcx , 50
    cld
    rep   movsb
    mov   rax , 256
    mov   rbx , draw
    mov   rcx , param
    int   0x60
    jmp   still
  no_new_background:

    ; Load new skin

    cmp   rbx , 14+1
    jne   no_new_skin  
    mov   rax , 120
    mov   rbx , 1
    mov   rcx , textbox5+48
    int   0x60
    mov   rax , 120
    mov   rbx , 2
    mov   rcx , 1
    int   0x60
    mov   rax , 120
    mov   rbx , 3
    int   0x60
    jmp   still
  no_new_skin:

    ; Load new driver

    cmp   rbx , 11
    jb    no_new_driver
    cmp   rbx , 13+1
    ja    no_new_driver
    mov   rcx , rbx
    sub   rcx , 11
    imul  rcx , 8
    mov   rcx , [textbox_list+rcx]
    add   rcx , 48
    mov   rax , 116
    mov   rbx , 101
    mov   rdx , 1
    int   0x60
  no_new_driver:

    jmp   still


add_system_path:

    ; Get system path to filestart
    mov   rax , 112
    mov   rbx , 2
    mov   rcx , string_sysdir
    mov   rdx , 64
    mov   r8  , string_return
    int   0x60

    mov   rdi , textbox1+6*8
    call  add_sysdir
    mov   rdi , textbox2+6*8
    call  add_sysdir
    mov   rdi , textbox3+6*8
    call  add_sysdir
    mov   rdi , textbox4+6*8
    call  add_sysdir
    mov   rdi , textbox5+6*8
    call  add_sysdir
    mov   rdi , textbox6+6*8
    call  add_sysdir
    mov   rdi , textbox7+6*8
    call  add_sysdir

    ret


add_sysdir:

    mov   r15 , rdi

    mov   rax , 0
  newfns:
    cmp   [string_return+rax],byte 0
    je    addfile
    add   rax , 1
    cmp   rax , 64
    jb    newfns
    mov   rax , 0
  addfile:

    add   [r15-8],rax

    mov   r8 , [rdi]
    mov   r9 , [rdi+8]
    add   rdi , rax
    mov   [rdi],r8
    mov   [rdi+8],r9

    mov   rsi , string_return
    mov   rdi , r15
    mov   rcx , rax
    cld
    rep   movsb

    ret



show_help:

    mov   rax , 38
    mov   rbx , 14 
    mov   rcx , 44 
    mov   rdx , 14+412
    mov   r8  , 44+157+40
    mov   r9  , 0x808080
    push  rbx
    mov   rbx , rdx
    int   0x60
    pop   rbx
    push  rdx
    mov   rdx , rbx
    int   0x60
    pop   rdx
    push  rcx
    mov   rcx , r8
    int   0x60
    pop   rcx
    push  r8
    mov   r8  , rcx
    int   0x60
    pop   r8

    mov   rax , 13
    mov   rbx , 15 shl 32 + 410
    mov   rcx , 45 shl 32 + 155+40
    mov   rdx , 0xf8f8f8
    int   0x60

    mov   rdx , rcx
    mov   rcx , rbx
    shr   rdx , 32
    add   rdx , 10+20
    shr   rcx , 32
    add   rcx , 10+20
    mov   rax , 4
    mov   rbx , info_text
    mov   rsi , 0x000000
    mov   r9  , 1
  newtextinfo:
    int   0x60
    add   rdx , 14
    add   rbx , itl-info_text
    cmp   [rbx],byte 0
    jne   newtextinfo

  noclose:
    mov   rax , 10
    int   0x60
    test  rax , 001b
    jnz   closeinfo
    mov   rax , 0x11
    int   0x60
    cmp   rbx , 0x104
    je    yescloseapp
    cmp   rbx , 0x10000001
    je    yescloseapp
    jmp   nocloseapp
  yescloseapp:
    mov   rax , 512
    int   0x60
  nocloseapp:
    mov   rax , 0x2
    int   0x60
    cmp   rax , 1
    je    noclose
    call  draw_window
    ret
  closeinfo:
    call  draw_window
    call  draw_window
    ret


scan_drivers:

    mov   [drivercount],dword 9999
    call  display_drivercount
    mov   [drivercount],dword 0

    ; Read PCI table

    cmp   [pciscandone],byte 1
    je    nopciscan
    mov   [pciscandone],byte 1
    mov   rdx , 0
    mov   rcx , 0x000000 ; bus,dev,num
  newpcientry:
    mov   rax , 115
    mov   rbx , 1
    int   0x60
    mov   [pcilist+rdx],eax
    add   rcx , 0x000100
    add   rdx , 4
    cmp   rdx , 8*1024
    jb    newpcientry
  nopciscan:

    mov   [drivercount],dword 0
    mov   [starpos],dword 0

    ; Path

    mov   rsi , textbox7+6*8
    mov   r14 , pathread
  newdirstr:
    mov   rdi , r14
    mov   rax , '        '
    mov   [rdi],rax
    mov   [rdi+8],rax
  newcurdir:
    mov   al , [rsi]
    mov   [rdi],al
    cmp   [rsi+1],byte '/'
    je    dirend
    cmp   [rsi+1],byte 32
    jbe   pathend
    add   rsi , 1
    add   rdi , 1
    jmp   newcurdir
  dirend:
    cmp   [rsi+2],byte 32
    jbe   pathend
    add   rsi , 1
    add   r14 , 1+8+1+3
    jmp   newdirstr
  pathend:
    mov   rax , 0
    mov   [rdi+1],rax
    mov   [rdi+1+8],rax

    ; Scan files

    mov   r15 , 1 ; skip '..'

  nextdriver:

    mov   rax , 58
    mov   rbx , 3
    mov   rcx , r15
    mov   rdx , 1
    mov   r8  , fileret
    mov   r9  , pathread
    int   0x60

    cmp   rax , 0
    jne   driversread

    mov   rsi , pathread
    mov   rdi , fileread
  newpc:
    mov   al  , [rsi]
    cmp   al , 0
    je    nonewpathcopy
    mov   [rdi],al
    add   rsi , 1
    add   rdi , 1
    jmp   newpc
  nonewpathcopy:
    mov   al , '/'
    stosb
    mov   rsi , fileret+8
  newpc2:
    mov   al  , [rsi]
    cmp   al , 32
    jbe   nonewfilecopy
    mov   [rdi],al
    add   rsi , 1
    add   rdi , 1
    jmp   newpc2
  nonewfilecopy:
    mov   rax , 0
    stosq
    mov   rax , 0
    stosq
    mov   rax , 0
    stosq

    ;mov   rax , 13
    ;mov   rbx , 20 shl 32 + 400
    ;mov   rcx , 40 shl 32 + 12
    ;mov   rdx , 0xf0f0f0f0
    ;int   0x60
    ;mov   rax , 4
    ;mov   rbx , fileread
    ;mov   rcx , 20
    ;mov   rdx , 40
    ;mov   rsi , 0x000000
    ;mov   r9  , 1
    ;int   0x60

    mov   [fileblock],dword 0

    mov   rax , 58
    mov   rbx , 0
    mov   rcx , 0
    mov   rdx , 1
    mov   r8  , fileblock
    mov   r9  , fileread
    int   0x60

    cmp   rax , 0
    jne   nodriverfile

    ; Driver file ?

    mov   rax , 'MENUET64'
    cmp   [fileblock],rax
    jne   nodriverfile
    mov   rax , 0x100
    cmp   [fileblock+8],rax
    jb    nodriverfile
    mov   rax , 0x103
    cmp   [fileblock+8],rax
    ja    nodriverfile

    ;mov   rax , 5
    ;mov   rbx , 100
    ;int   0x60

    mov   r12 , [fileblock+8]

    mov   rsi , fileblock+5*8
  newpcitest:
    cmp   [rsi],dword 0
    je    nomatchingdriver
    ; Scan thru PCI IDs
    mov   eax , [rsi]
    mov   rdi , pcilist
  newpcitest2:
    cmp   rdi , pcilist+8*1024
    jae   nextslot
    cmp   eax , [rdi]
    je    drivermatch
    add   rdi , 4
    jmp   newpcitest2
  nextslot:
    add   rsi , 4
    jmp   newpcitest
  drivermatch:
    ;
    ;mov   rax , 5
    ;mov   rbx , 100
    ;int   0x60
    ;
    add   [drivercount],dword 1
    ;
    sub   r12 , 0x100
    mov   rdi , [textb+r12*8]
    mov   r11 , rdi
    mov   r10 , [texty+r12*8]
    mov   [starpos+r10],byte 1

    ; Length
    mov   rsi , fileread
    mov   rcx , 0
  newdrivermove:
    mov   al , [rsi]
    cmp   al , ' '
    je    nomoved
    mov   [rdi],al
    add   rdi , 1
    add   rcx , 1
  nomoved:
    add   rsi , 1
    cmp   al , 0
    jne   newdrivermove
    sub   rcx , 1
    mov   [r11-8],rcx

  nomatchingdriver:
  nodriverfile:

    add   r15 , 1
    jmp   nextdriver

  driversread:

    call  draw_textboxes
    call  display_drivercount

    ; >>

    mov   r10 , 0
    mov   r11 , 0
  newstar:
    push  r11
    mov   rsi , 0
    add   r11 , 1
    and   r11 , 1
    sub   rsi , r11
    and   rsi , 0xffffff
    pop   r11
    cmp   [starpos+r10],byte 0
    jne   nowhite
    mov   rsi , 0xffffff
  nowhite:
    call  display_star
    add   r10 , 1
    cmp   r10 , 3
    jbe   newstar
    ;
    cmp   [drivercount],dword 0
    je    noposition
    ;
    mov   rax , 5
    mov   rbx , 20
    int   0x60
    mov   r10 , 0
    add   r11 , 1
    cmp   r11 , 4
    jb    newstar
    ;
  noposition:

    ret


display_star:

    push  rax rbx rcx rdx r9

    mov   rax , 4
    mov   rbx , string_star
    mov   rcx , 8
    mov   rdx , r10
    imul  rdx , 50
    add   rdx , 70
    mov   r9  , 1
    int   0x60

    pop   r9 rdx rcx rbx rax

    ret



display_drivercount:

    mov   rax , 13
    mov   rbx , 260 shl 32 + 27*6
    mov   rcx , 248  shl 32 + 14
    mov   rdx , 0xffffff
    int   0x60

    mov   al , [drivercount]
    add   al , 48
    mov   [string_found+6],al

    mov   rax , 4
    mov   rbx , string_found
    cmp   [drivercount],dword 9999
    jne   nosetsearching
    mov   rbx , string_search
  nosetsearching:
    mov   rcx , 260
    mov   rdx , 250
    mov   rsi , 0x000000
    mov   r9  , 1
    int   0x60

    ret



draw_window:

    mov   rax , 0xC                          ; Beginning of window draw
    mov   rbx , 0x1
    int   0x60

    mov   rax , 0x0                          ; Draw window
    mov   rbx , 143*0x100000000+443          ; x start & size
    mov   rcx , 29*0x100000000+355+yadd+53   ; y start & size
    mov   rdx , 0x0000000000ffffff           ; type    & border color  
    mov   r8  , 0x0000000000000001           ; draw flags
    mov   r9  , window_label                 ; 0 or label - asciiz
    mov   r10 , menu_struct                  ; 0 or pointer to menu struct
    int   0x60

    ; Browse

    mov   rax , 8
    mov   rbx , 255 * 0x100000000 + 80
    mov   rcx , (65+yadd) * 0x100000000 + 17
    mov   rdx , 31
    mov   r8  , 0
    mov   r9  , browse
    mov   r10 , 50  * 0x100000000
  newbrowse:
    int   0x60
    add   rcx , r10
    cmp   rdx , 34
    jne   noadd1
    add   rcx , r10
  noadd1:
    inc   rdx
    cmp   rdx , 35+1
    jbe   newbrowse 

    ; Apply

    mov   rax , 8
    mov   rbx , 340* 0x100000000 +  80
    mov   rcx , (65+yadd)  * 0x100000000 + 17
    mov   rdx , 11
    mov   r8  , 0x0
    mov   r9  , apply
    mov   r10 , 50  * 0x100000000
  newapply:
    int   0x60
    add   rcx , r10
    cmp   rdx , 14
    jne   noadd2
    add   rcx , r10
  noadd2:
    inc   rdx
    cmp   rdx , 15+1
    jbe   newapply

    call  draw_textboxes

    mov   rax , 4
    mov   rbx , text
    mov   rcx , 20
    mov   rdx , 50+yadd
    mov   rsi , 0x000000
    mov   r9  , 1
  newtext:
    int   0x60
    add   rdx , 50
    add   rbx , 24
    cmp   rbx , text+24*7
    jb    newtext

    ; Automated scan

    mov   rax , 8
    mov   rbx , 255 * 0x100000000 + 165
    mov   rcx , (65+50*4) * 0x100000000 + 17
    mov   rdx , 121
    mov   r8  , 0
    mov   r9  , string_start_scan
    int   0x60

    mov   rax , 12
    mov   rbx , 2
    int   0x60

    ret


draw_textboxes:

    mov   r14 , textbox1
    call  draw_textbox
    mov   r14 , textbox2
    call  draw_textbox
    mov   r14 , textbox3
    call  draw_textbox
    mov   r14 , textbox4
    call  draw_textbox
    mov   r14 , textbox5
    call  draw_textbox
    mov   r14 , textbox6
    call  draw_textbox
    mov   r14 , textbox7
    call  draw_textbox

    ret

;
; Data area
;

textbox1:

    dq    0
    dq    20
    dq    230
    dq    65+yadd
    dq    21
    dq    13
    db    'DRIVER/I8254X'
    times (90-13) db 0

textbox2:

    dq    0
    dq    20
    dq    230
    dq    115+yadd
    dq    22
    dq    15
    db    'DRIVER/INTELHDA'
    times (90-15) db 0

textbox3:

    dq    0
    dq    20
    dq    230
    dq    165+yadd
    dq    23
    dq    10
    db    'DRIVER/GRX'
    times (90-10) db 0

textbox4:

    dq    0
    dq    20
    dq    230
    dq    215+yadd
    dq    24
    dq    13
    db    'DRIVER/MPU401'
    times (90-13) db 0

textbox5:

    dq    0
    dq    20 
    dq    230
    dq    315+yadd
    dq    25
    dq    8
    db    'SKIN.BMP'
    times (90-8) db 0

textbox6:

    dq    0
    dq    20       ; X start
    dq    230      ; X size
    dq    365+yadd ; Y start 
    dq    26       ; Button ID
    dq    7        ; Text length
    db    'BGR.JPG'
    times (90-7) db 0

textbox7:

    dq    0
    dq    20
    dq    230
    dq    265+yadd ; Y start
    dq    27
    dq    6
    db    'DRIVER'
    times (90-6) db 0
     

window_label:

    db    'SETUP',0                       

apply:

    db   'APPLY',0           

browse:

    db   'BROWSE',0

string_start_scan:

    db   'AUTOM. DRIVER SEARCH',0

draw:   db '\sysdir\DRAW',0
param:  db 'B'
        times 256 db 0

textbox_list:  dq textbox1,textbox2,textbox3,textbox4,textbox5,textbox6
               dq textbox7
file_search:   db '\sysdir\FBROWSER',0
parameter:     db '[000000]',0
waiting:       dq 0x0
mainscreen:    dq 0x0
starpos:       dq 0x0
drivercount:   dq 0x0
string_found:  db "Found X matching drivers.",0
string_star:   db '>>',0
pciscandone:   dq 0
string_search: db "Searching..",0
string_sysdir: db 'system_directory',0
string_unzip:  db '\sysdir\unzip',0
string_param:  db '\sysdir\drv.zip',0


textb: dq textbox1+6*8,textbox2+6*8,textbox4+6*8,textbox3+6*8
texty: dq 0,1,3,2


text:
    db   'Network driver         ',0
    db   'Audio driver           ',0
    db   'Graphics driver        ',0
    db   'Midi driver            ',0
    db   'Driver search directory',0
    db   'Window skinning        ',0
    db   'Background picture     ',0

info_text:
    db   'With Setup you can define drivers and graphics.    ',0
itl:
    db   '                                                   ',0
    db   'Apply  - Load and activate drivers and graphics.   ',0
    db   'Browse - Open a file browse dialog-box.            ',0
    db   '                                                   ',0
    db   'Automated driver search scans for matches          ',0
    db   'between local PCI-devices and installed drivers.   ',0
    db   'If a match is found, it moves the drivers filename ',0
    db   'to corresponding location. Press Apply to load and ',0
    db   'activate the driver.                               ',0

    db   0


menu_struct:               ; Menu Struct

    dq   0                 ; Version
    dq   0x100             ; Start value of ID to return ( ID + Line )
                           ; Returned when menu closes and
                           ; user made no selections.
    db   0,'FILE',0             ; ID = 0x100 + 1
    db   1,'Setup info..',0     ; ID = 0x100 + 2
    db   1,'Driver states..',0  ; ID = 0x100 + 2
    db   1,'-',0                ; ID = 0x100 + 3
    db   1,'Quit',0        ; ID = 0x100 + 4
    db   255               ; End of Menu Struct

ipc_memory:

    dq   0x0
    dq   16
    times 100 db 0

string_return: times 128 db ?

pathread:      times 13*20 db ?
fileread:      times 512 db ?
fileret:       times 512 db ?
fileblock:     times 1024 db ?
pcilist:       times 9*1024 db ?

image_end:






















































