;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   64 bit Menuet Movie player
;
;   Compile with FASM 1.60 or above
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

buttonsize equ 70

use64

    org   0x0

    db    'MENUET64'              ; Header identifier
    dq    0x01                    ; Version
    dq    START                   ; Start of code
    dq    image_end               ; Size of image
    dq    0x100000*10             ; Memory for app
    dq    0xffff0                 ; Rsp
    dq    0x00                    ; Prm 
    dq    0x00                    ; Icon

ipc_size equ 8192000

include "textbox.inc"
include "dns.inc"

; 0x090000 - thread stack
; 0x0A0000 - data return area
; 0x0ffff0 - stack
; 0x100000 - read area


START:

    ; Get system path to filestart
    mov   rax , 112
    mov   rbx , 2
    mov   rcx , string_sysdir
    mov   rdx , 40
    mov   r8  , filestart
    int   0x60
    mov   rax , filestart
  newfns:
    cmp   [rax],byte 0
    je    addfile
    cmp   [rax],byte 'A'
    jb    notolowercase
    cmp   [rax],byte 'Z'
    ja    notolowercase
    add   [rax],byte 32
  notolowercase:
    add   rax , 1
    cmp   rax , filestart+40
    jb    newfns
    mov   rax , filestart
  addfile:
    mov   rbx , 'mplayer'
    mov   [rax],rbx
    add   rax , 7
    sub   rax , filestart
    mov   [filestart-8],rax

    mov   rax , 141         ; Enable system font
    mov   rbx , 1
    mov   rcx , 1
    mov   rdx , 5 shl 32 + 5
    mov   r8  , 9 shl 32 + 12
    int   0x60

    call  draw_window       ; At first, draw the window

still:

    cmp   [ipc_memory+8],dword 16
    je    nofilereceived
    mov   [status],dword string_file
    mov   [prevstatus],dword 0xffffff
    call  draw_status
    mov   [ipc_memory+0],dword 00
    mov   [ipc_memory+8],dword 16
  nofilereceived:

    mov   rax , 5
    mov   rbx , 1
    int   0x60
    cmp   [makedelay],dword 0
    je    nomkdelay
    sub   [makedelay],dword 1
  nomkdelay:

    mov   rax , 11          ; Check for event
    int   0x60

    test  rax , 1           ; Window redraw
    jnz   window_event
    test  rax , 2           ; Keyboard press
    jnz   key_event
    test  rax , 4           ; Button press
    jnz   button_event

    cmp   [playstate],byte 1
    je    doplay

    jmp   still


window_event:

    call  draw_window
    jmp   still


key_event:

    mov   rax , 2          ; Read the key and ignore
    int   0x60

    jmp   still


doplay:

    ;
    ; Delay for next read
    ;
    cmp   [makedelay],dword 0
    jne   still

    ;
    ; Load file
    ;
    cmp   [loadpos],dword ipc_size
    jae   nosp

    cmp   [readprogress],byte 1
    je    draw_progress

    mov   [readprogress],byte 1

    mov   rax , 9
    mov   rbx , 2
    mov   rcx , [pid]
    mov   rdx , 0xA0000
    mov   [rdx+736],dword 0
    mov   r8  , 1024
    int   0x60

    movzx rax , byte [0xa0000+736]
    add   rax , 1
    mov   [targetcpu],rax

    mov   rax , 140
    mov   rbx , 2
    int   0x60
    cmp   [targetcpu],rbx
    jb    tcfine
    mov   [targetcpu],dword 0
  tcfine:

    mov   rdi , 0x100000
    mov   rcx , ipc_size/8
    mov   rax , 0
    cld
    rep   stosq

    mov   rax , 140
    mov   rbx , 3
    mov   rcx , readthread
    cmp   [ipc_memory+16],dword 'http'
    jne   nohttpread
    mov   rcx , readthreadhttp
  nohttpread:
    mov   rdx , 0x90000
    mov   rdi , [targetcpu]
    int   0x60

    jmp   still

  draw_progress:

    mov   rax , 0
    cmp   [sendpos],rax
    jne   noshowpercentage

    mov   rsi , 0x100000+ipc_size
    mov   rax , 48+10
  newpsearch:
    sub   rsi , ipc_size/10
    sub   rax , 1
    cmp   [rsi],dword 0
    jne   foundpercentage
    cmp   rsi , 0x100000
    ja    newpsearch
  foundpercentage:
    add   rax , '0' shl 8
    cmp   [prevstatus],dword string_percentage
    jne   showpercentage
    cmp   ax  , [string_percentage+11]
    je    still
  showpercentage:

    mov   [string_percentage+11],ax
    mov   [prevstatus],dword 0
    mov   [status],dword string_percentage
    call  draw_status

    jmp   still

  noshowpercentage:

    mov   [status],dword string_buffering
    call  draw_status

    jmp   still

  nosp:

    call  check_player_start

    mov   [status],dword string_playing
    call  draw_status

    ; Possible change at check_player_start

    cmp   [makedelay],dword 0
    jne   still

    ;
    ; Send data
    ;
    mov   rax , 60
    mov   rbx , 2
    mov   rcx , [pid]
    mov   rdx , 0x100000
    mov   r8  , ipc_size
    int   0x60

    ; Command success

    cmp   rax , 0
    jne   nosendsuccess
    mov   [loadpos],dword 0
    mov   [restart],byte 0
    mov   [readprogress],dword 0
    jmp   commanddone
  nosendsuccess:

    ; Decoder not found -> restart

    cmp   rax , 1
    jne   norestart
    cmp   [restart],byte 1
    jne   norestart
    mov   [restart],byte 0
    mov   [pid],dword 0
    jmp   commanddone
  norestart:

    ; Decoder ipc full -> wait

    jmp   noeofcheck

  commanddone:

    ; End of file

    mov   rax , [sendpos]
    imul  rax , 512
    mov   rbx , [filesize]
    cmp   rax , rbx
    jb    noeof
    mov   [loadpos],dword 0
    mov   [restart],byte 0
    mov   [readprogress],dword 0
    mov   [playstate],dword 0
    mov   [status],dword string_file
    call  draw_status
    jmp   still
  noeof:

  noeofcheck:

    ;
    ; Decoder scans for packet match
    ;
    mov   [makedelay],dword 100
    cmp   [ipc_memory+16],dword 'http'
    jne   nohttpdelay
    mov   [makedelay],dword 50
  nohttpdelay:

    jmp   still



readthread:

    mov   [readprogress],byte 1

    mov   r15 , 0

    mov   r8  , 0x100000
    mov   rcx , [sendpos]

  rtl1:

    mov   rax , 58
    mov   rbx , 0
    mov   rdx , ipc_size/512/10
    mov   r9  , fileload
    int   0x60
    mov   [filesize],rbx

    cmp   [stopthread],byte 1
    je    rtl2

    add   r8  , ipc_size/10
    add   rcx , ipc_size/512/10

    add   r15 , 1
    cmp   r15 , 10
    jb    rtl1

  rtl2:

    add   [sendpos],dword ipc_size/512
    add   [loadpos],dword ipc_size

    mov   [stopthread],byte 0

    mov   [readprogress],byte 2

    mov   rax , 512
    int   0x60


sendheaderdata:

    push  rax rbx rcx rdx rsi
    mov   rax , 53
    mov   rbx , 7
    mov   rcx , [socket]
    int   0x60
    pop   rsi rdx rcx rbx rax


    ret


readthreadhttp:

    mov   rax , 0
    cmp   [sendpos],rax
    jne   nosetfilesize
    mov   rax , 0x100000*8092 ; 8Gb as default
    mov   [filesize],rax
  nosetfilesize:

    mov   [readprogress],byte 1

    mov   rcx , [localport]
    add   [localport],dword 1
    mov   rax , 53
    mov   rbx , 5
    mov   rdx , [queryport]
    mov   esi , [queryip]
    mov   rdi , 1
    int   0x60
    mov   [socket],rax

  waitforopen:
    mov   rax , 105
    mov   rbx , 1
    int   0x60
    mov   rax , 53
    mov   rbx , 6
    mov   rcx , [socket]
    int   0x60
    cmp   [stopthread],byte 1
    je    senddata
    cmp   rax , 4
    jne   waitforopen

    ;
    ; Clear socket
    ;
    mov   rax , 53
    mov   rbx , 13
    mov   rcx , [socket]
    mov   rdx , 0x100000
    int   0x60

    ;
    ; Send request and filename
    ;

    mov   rdx , lene0-lens0
    mov   rsi , lens0
    call  sendheaderdata

    mov   rax , fileload+4+1+2-1
  fpos:
    add   rax , 1
    cmp   [rax],byte '/'
    je    ffound
    cmp   [rax],byte ' '
    jbe   nofilepresent
    jmp   fpos
  ffound:

    mov   rsi , rax
    add   rsi , 1

    mov   rdx , 0
  flen:
    add   rdx , 1
    add   rax , 1
    cmp   [rax],byte ' '
    ja    flen
    sub   rdx , 1
    cmp   rdx , 0
    je    nofilepresent

    mov   rdx , rdx
    mov   rsi , rsi
    call  sendheaderdata

  nofilepresent:

    ;
    ; Send byterange
    ;

    mov   rdx , lene1-lens1
    mov   rsi , lens1
    call  sendheaderdata

    mov   rax , [sendpos]
    imul  rax , 512
    mov   rdi , rbstring+50
  newdiv:
    mov   rbx , 10
    xor   rdx , rdx
    div   rbx
    add   dl  , 48
    mov   [rdi],dl
    sub   rdi , 1
    cmp   rax , 0
    jne   newdiv
    add   rdi , 1

    mov   rdx , rbstring+50
    sub   rdx , rdi
    add   rdx , 1
    mov   rsi , rdi
    call  sendheaderdata

    ;
    ; Send hostname
    ;

    mov   rdx , lene2-lens2
    mov   rsi , lens2
    call  sendheaderdata

    mov   rax , fileload+4+1+2-1
  fpos2:
    add   rax , 1
    cmp   [rax],byte '/'
    je    ffound2
    cmp   [rax],byte ':'
    je    ffound2
    cmp   [rax],byte ' '
    jbe   ffound2
    jmp   fpos2
  ffound2:

    mov   rdx , rax
    sub   rdx , fileload+4+1+2
    mov   rcx , [socket]
    mov   rsi , fileload+4+1+2
    call  sendheaderdata

    mov   rdx , lene3-lens3
    mov   rsi , lens3
    call  sendheaderdata

    ;
    ; Read header
    ;

    mov   r10 , 0

    mov   r11 , 0
    mov   [headerline+3],dword 0

  headerwait:

    cmp   [stopthread],byte 1
    je    senddata

    mov   rax , 53
    mov   rbx , 2
    mov   rcx , [socket]
    int   0x60

    cmp   rax , 0
    je    noreadh

    mov   rax , 53
    mov   rbx , 3
    mov   rcx , [socket]
    int   0x60
    shl   r10  , 8
    mov   r10b , bl

    cmp   r10w , 0x0A0A
    je    headerdone
    cmp   r10w , 0x0D0D
    je    headerdone
    cmp   r10d, 0x0A0D0A0D
    je    headerdone
    cmp   r10d, 0x0D0A0D0A
    je    headerdone

    ; Content-Length

    mov   rax , 0
    cmp   [sendpos],rax
    jne   headerwait
    cmp   bl , 13
    ja    noheaderlf
    mov   r11 , 0
    mov   rax , 'tent-Len'
    cmp   [headerline+3],rax
    je    yescontentlength
    mov   rax , 'tent-len'
    cmp   [headerline+3],rax
    je    yescontentlength
    mov   rax , 'TENT-LEN'
    cmp   [headerline+3],rax
    je    yescontentlength
    mov   [headerline+3],dword 0
    jmp   headerwait
  yescontentlength:
    mov   [headerline+3],dword 0
    mov   rax , headerline+10
    mov   rbx , 0
  findcllen:
    cmp   [rax],byte '-' ; negative value ?
    je    headerwait
    cmp   [rax],byte 13
    jbe   headerwait
    cmp   [rax],byte '9'
    ja    nocllen
    cmp   [rax],byte '0'
    jb    nocllen
    jmp   clfound
  nocllen:
    add   rax , 1
    jmp   findcllen
  clfound:
    movzx rcx , byte [rax]
    cmp   rcx , '0'
    jb    docl
    cmp   rcx , '9'
    ja    docl
    imul  rbx , 10
    sub   rcx , 48
    add   rbx , rcx
    add   rax , 1
    jmp   clfound
  docl:
    mov   [filesize],rbx
    jmp   headerwait
  noheaderlf:

    and   r11 , 63
    mov   [headerline+r11],bl
    add   r11 , 1

    jmp   headerwait

  noreadh:

    mov   rax , 105
    mov   rbx , 1
    int   0x60

    jmp   headerwait

  headerdone:

    ;
    ; Read data
    ;

    mov   r15 , 0x100000
    mov   r14 , 0

  readmore:

    cmp   [stopthread],byte 1
    je    senddata

    mov   rax , 53
    mov   rbx , 13
    mov   rcx , [socket]
    mov   rdx , r15
    int   0x60
    add   r15 , rax

    mov   rax , 105
    mov   rbx , 1
    int   0x60

    mov   rax , 53
    mov   rbx , 6
    mov   rcx , [socket]
    int   0x60
    cmp   rax , 4
    jne   senddata

    cmp   r15 , 0x100000+ipc_size
    jb    readmore

  senddata:

    ; Close connection

    mov   rax , 53
    mov   rbx , 8
    mov   rcx , [socket]
    int   0x60

    add   [sendpos],dword ipc_size/512
    add   [loadpos],dword ipc_size

    mov   [readprogress],byte 2
    mov   [stopthread],byte 0

    mov   rax , 512
    int   0x60




update_scroll_position:

    ; Calculate new scroll position
    mov   rax , [filesize]
    mov   rbx , 512*100
    xor   rdx , rdx
    div   rbx
    cmp   rax , 0
    je    noupdatescroll
    mov   rbx , rax
    mov   rax , [sendpos]
    xor   rdx , rdx
    div   rbx
    mov   rbx , 99
    cmp   rax , rbx
    cmova rax , rbx
    add   rax , 300
    cmp   rax , [scroll_value]
    je    noupdatescroll
    ;
    mov   [scroll_value],rax
    call  draw_scroll
    ;
  noupdatescroll:

    ret



check_player_start:

    ;
    ; Start player
    ;
    cmp   [pid],dword 0
    jne   noplayerstart

    mov   rax , 256
    mov   rbx , filestart
    mov   rcx , ipcm
    int   0x60
    mov   [pid],rbx

    mov   [makedelay],dword 12 ; 1.2s delay before data

  noplayerstart:

    ret



button_event:

    mov   rax , 17
    int   0x60

    ; rax = status
    ; rbx = button id

    cmp   rbx , 0x10000001
    jne   no_application_terminate_button
    mov   rax , 0x200
    int   0x60
  no_application_terminate_button:

    cmp   rbx , 0x105
    jne   no_application_terminate_menu
    mov   rax , 0x200
    int   0x60
  no_application_terminate_menu:

    cmp   rbx , 0x102
    jne   no_decoder_start
    mov   [pid],dword 0
    call  check_player_start
    jmp   still
  no_decoder_start:

    cmp   rbx , 0x103
    jne   no_mixer_start
    mov   rax , 256
    mov   rbx , audiostart
    mov   rcx , 0
    int   0x60
    jmp   still
  no_mixer_start:

    cmp   rbx , 300                       ;  Vertical scroll 300-319
    jb    no_vertical_scroll
    cmp   rbx , 400
    ja    no_vertical_scroll
  scroll:
    mov   [scroll_value], rbx
    call  draw_scroll
    call  send_stop
    mov   [stopthread],byte 1
    ; New read position
  waitforstop:
    mov   rax , 5
    mov   rbx , 2
    int   0x60
    cmp   [readprogress],dword 1
    je    waitforstop
    ; If no thread was running
    mov   [stopthread],byte 0
    ; Calculate new position
    mov   rax , [filesize]
    mov   rbx , 100*512
    xor   rdx , rdx
    div   rbx
    mov   rbx , [scroll_value]
    sub   rbx , 300
    imul  rax , rbx
    mov   [sendpos],rax
    mov   [loadpos],dword 0
    ; Start player if needed
    mov   [restart],byte 1
    mov   rax , 5
    mov   rbx , 20
    int   0x60
    jmp   still
  no_vertical_scroll:

    cmp   rbx , 20
    jne   nofileopen
    mov   [playstate],byte 0
    call  send_stop
    mov   [restart],byte 1
    mov   [ipc_memory+0],dword 00
    mov   [ipc_memory+8],dword 16
    mov   rax , 0
    mov   [sendpos],rax
    call  dialog_open
    jmp   still
  nofileopen:

    cmp   rbx , 21
    jne   nohttpopen
    mov   rax , 1
    call  displaywindowtext
    mov   rax , 'http://'
    mov   [text3],rax
    mov   [prevstatus],dword 0
    call  draw_status
    mov   r14 , textbox2
    call  draw_textbox
    mov   r14 , textbox2
    call  read_textbox
    cmp   cx , 'Es'
    je    nocopytextbox
    mov   rax , 'http://'
    mov   [fileload],rax
    mov   rsi , textbox2+6*8
    mov   rdi , fileload+7
    mov   rcx , 50
    cld
    rep   movsb
  nocopytextbox:
    mov   rax , 8
    mov   rbx , 10 shl 32 + 100
    mov   rcx , 10 shl 32 + 100
    mov   rdx , 12
    mov   r8  , 1 shl 59
    mov   r9  , 0
    int   0x60
    mov   rax , 0
    call  displaywindowtext
    mov   rax , 'Status:'
    mov   [text3],rax
    mov   [prevstatus],dword 0
    call  draw_status
    jmp   still
  nohttpopen:

    cmp   rbx , 22
    jne   noplayon
    cmp   [ipc_memory+16],byte '/'
    je    yesplayon
    cmp   [ipc_memory+16],dword 'http'
    je    yesplayon
    jmp   noplayon
  yesplayon:
    cmp   [ipc_memory+16],dword 'http'
    jne   nofindip
    mov   rsi , fileload+4+1+2
    mov   rdi , queryip
    mov   [queryport],dword 80
    call  get_ip
  nofindip:
    mov   [playstate],byte 1
    mov   rbx , 300
    jmp   scroll
  noplayon:

    cmp   rbx , 23
    jne   noplayoff
    mov   [stopthread],byte 1
    cmp   [readprogress],byte 1
    jne   nostopping
    mov   [status],dword string_stopping
    call  draw_status
  nostopping:
    call  send_stop
  waitthreadstop:
    mov   rax , 5
    mov   rbx , 1
    int   0x60
    cmp   [readprogress],byte 1
    je    waitthreadstop
    mov   [stopthread],byte 0
    mov   [restart],byte 1
    mov   rax , 0
    mov   [loadpos],rax
    mov   [sendpos],rax
    mov   [playstate],byte 0
    mov   [status],dword fileload
    call  draw_status
    jmp   still
  noplayoff:

    cmp   rbx , 11
    jne   no_textbox1
    mov   r14 , textbox1
    call  read_textbox
    jmp   still
  no_textbox1:

    jmp   still


send_stop:

    cmp   [pid],dword 0
    je    nostop

    mov   rax , 60
    mov   rbx , 2
    mov   rcx , [pid]
    mov   rdx , string_stop
    mov   r8  , 4
    int   0x60

  nostop:

    ret


dialog_open:

    mov   [parameter],byte '['

    ; Get my PID

    mov   rax , 111
    mov   rbx , 1
    int   0x60

    mov   rdi , parameter + 6
  newdec:
    mov   rbx , 10
    xor   rdx , rdx
    div   rbx
    add   rdx , 48
    mov  [rdi], dl
    dec   rdi
    cmp   rdi , parameter + 1
    jg    newdec

    ; Start fbrowser

    mov   rax , 256
    mov   rbx , file_search
    mov   rcx , parameter
    int   0x60

    ; Define IPC memory

    mov   rax , 60           ; ipc
    mov   rbx , 1            ; define memory area
    mov   rcx , ipc_memory   ; memory area pointer
    mov   rdx , 100          ; size of area
    int   0x60

    ret


draw_window:

    mov   rax , 12                           ; Beginning of window draw
    mov   rbx , 1
    int   0x60

    mov   rax , 0                            ; Draw window
    mov   rbx , 160 shl 32 + buttonsize*4+51 ; X start & size
    mov   rcx , 85 shl 32 + 153+18*4         ; Y start & size
    mov   rdx , 0x0000000000f8f8f8           ; Type    & border color  
    mov   r8  , 0x0000000000000001           ; Flags (set as 1)
    mov   r9  , window_label                 ; 0 or label - asciiz
    mov   r10 , menu_struct                  ; 0 or pointer to menu struct
    int   0x60

    mov   rax , 4                            ; Display text
    mov   rbx , text1                        ; Pointer to text
    mov   rcx , 25                           ; X position
    mov   rdx , 58                           ; Y position
    mov   rsi , 0x000000                     ; Color
    mov   r9  , 1                            ; Font
    int   0x60

    mov   rax , 0
    call  displaywindowtext

    mov   [prevstatus],dword 0xffffff
    call  draw_status

    ; Define button
    mov   rax , 8
    mov   rbx , 025 shl 32 + buttonsize
    mov   rcx , 110 shl 32 + 20
    mov   rdx , 20
    mov   r8  , 0
    mov   r9  , button_text_1
    int   0x60
    mov   r10 , rbx
    shl   r10 , 32
    add   rbx , r10
    inc   rdx
    mov   r9  , button_text_2
    int   0x60
    inc   rdx
    add   rbx , r10
    mov   r9  , button_text_3
    int   0x60
    inc   rdx
    add   rbx , r10
    mov   r9  , button_text_4
    int   0x60

    ; Scroll

    call  draw_scroll

    mov   r14 , textbox1
    call  draw_textbox

    mov   rax , 12
    mov   rbx , 2
    int   0x60

    ret



displaywindowtext:

    push  rax
    mov   rax , 13
    mov   rbx , 25 shl 32 + buttonsize*4+1
    mov   rcx , 141 shl 32 + 18*3
    mov   rdx , 0xf8f8f8
    int   0x60
    pop   rax

    cmp   rax , 0
    jne   showhttptext

    mov   rax , 4                            ; Display text
    mov   rbx , text11                       ; Pointer to text
    mov   rcx , 25                           ; X position
    mov   rdx , 145                          ; Y position
    mov   rsi , 0x000000                     ; Color
    mov   r9  , 1                            ; Font
    int   0x60
    mov   rax , 4                            ; Display text
    mov   rbx , text2                        ; Pointer to text
    mov   rcx , 25                           ; X position
    mov   rdx , 145+18                       ; Y position
    mov   rsi , 0x000000                     ; Color
    mov   r9  , 1                            ; Font
    int   0x60
    mov   rax , 4                            ; Display text
    mov   rbx , text21                       ; Pointer to text
    mov   rcx , 25                           ; X position
    mov   rdx , 145+18*2                     ; Y position
    mov   rsi , 0x000000                     ; Color
    mov   r9  , 1                            ; Font
    int   0x60

    ret

  showhttptext:

    mov   rax , 4                            ; Display text
    mov   rbx , texth1                       ; Pointer to text
    mov   rcx , 25                           ; X position
    mov   rdx , 144                          ; Y position
    mov   rsi , 0x000000                     ; Color
    mov   r9  , 1                            ; Font
    int   0x60
    mov   rax , 4                            ; Display text
    mov   rbx , texth2                       ; Pointer to text
    mov   rcx , 25                           ; X position
    mov   rdx , 144+18                       ; Y position
    mov   rsi , 0x000000                     ; Color
    mov   r9  , 1                            ; Font
    int   0x60
    mov   rax , 4                            ; Display text
    mov   rbx , texth3                       ; Pointer to text
    mov   rcx , 25                           ; X position
    mov   rdx , 144+18*2                     ; Y position
    mov   rsi , 0x000000                     ; Color
    mov   r9  , 1                            ; Font
    int   0x60

    ret




draw_status:

    mov   rax , [status]
    cmp   rax , [prevstatus]
    je    nostatdraw

    mov   rax , 13
    mov   rbx , 25 shl 32 + buttonsize*4+1
    mov   rcx , 194 shl 32 + 18
    mov   rdx , 0xf8f8f8
    int   0x60

    mov   rax , 4                            ; Display text
    mov   rbx , text3                        ; Pointer to text
    mov   rcx , 25                           ; X position
    mov   rdx , 145+18*3                     ; Y position
    mov   rsi , 0x000000                     ; Color
    mov   r9  , 1                            ; Font
    int   0x60

    push  qword [fileload+36]
    mov   [fileload+36],dword '..'
    mov   rax , 4                            ; Display text
    mov   rbx , [status]                     ; Pointer to text
    mov   rcx , 25+6*8                       ; X position
    mov   rdx , 145+18*3                     ; Y position
    mov   rsi , 0x000000                     ; Color
    mov   r9  , 1                            ; Font
    int   0x60
    pop   qword [fileload+36]

    mov   rax , [status]
    mov   [prevstatus],rax

  nostatdraw:

    call  update_scroll_position

    ret


draw_scroll:

    ; Scroll

    mov   rax , 113
    mov   rbx , 2
    mov   rcx , 300
    mov   rdx , 100
    mov   r8  , [scroll_value]
    mov   r9  , 85
    mov   r10 , 25
    mov   r11 , buttonsize*4
    int   0x60

    ret


;
; Data area
;

filesize:   dq  0x0
loadpos:    dq  0x0
sendpos:    dq  0x0
pid:        dq  0x0
playstate:  dq  0x0
restart:    dq  0x0
makedelay:  dq  0x0

status:       dq  string_file
prevstatus:   dq  0x0
readprogress: dq  0x0 ; 0/1/2=start/running/stopped
targetcpu:    dq  0x0

ipcm:         db  'IPC2',0
string_stop:  db  'STOP',0

textbox1:

    dq    0         ; Type
    dq    70        ; X position
    dq    buttonsize*4-45
    dq    53        ; Y position
    dq    11        ; Button ID
    dq    1         ; Current text length
  filestart:
    times 65 db 0

textbox2:

    dq    0         ; Type
    dq    69        ; X position
    dq    buttonsize*4-44 ; X size
    dq    194       ; Y position
    dq    12        ; Button ID
    dq    0         ; Current text length
    times 100 db 0
                   
scroll_value:   dq  300
button_text_1:  db  'FILE',0
button_text_2:  db  'NET',0
button_text_3:  db  'PLAY',0
button_text_4:  db  'STOP',0
window_label:   db  'MOVIE PLAYER',0
file_search:    db  '\sysdir\FBROWSER   ',0
parameter:      db  '[000000]',0
audiostart:     db  '\sysdir\MIXER',0
string_sysdir:  db  'system_directory',0

text1:  db  'Decoder',0
text21: db  'Decoder: MediaPlayer (0.90-)',0
text11: db  'Video Support: MPEG-2 (720x576,720x480)',0
text2:  db  'Audio Support: MP3 (112-224kbps)',0
text3:  db  'Status:',0,0,0,0,0

texth1: db  'Address examples:',0
texth2: db  'http://192.168.1.24:8180/movie.mpg',0
texth3: db  'http://movieserver/moviefiles/movie.mpg',0

string_playing:    db  'Playing',0
string_buffering:  db  'Buffering',0
string_percentage: db  'Buffering (xx%)',0
string_stopping:   db  'Stopping',0

ipaddr:     db  192,168,1,24,0,0,0,0
socket:     dq  0
localport:  dq  12345
stopthread: dq  0x0
rbstring:   times 100 db ' '
headerline: times 80 db 0

lens0:
    db   'GET /'
lene0:

lens1:
    db  ' HTTP/1.1',13,10
    db  'Range: bytes='
lene1:

lens2:
    db  '-',13,10
    db  'Host: '
lene2:

lens3:
    db  13,10
    db  'Connection: Close',13,10
    db  13,10,13,10
lene3:


menu_struct:               ; Menu Struct

    dq   0                 ; Version
    dq   0x100             ; Start value of ID to return ( ID + Line )
                           ; Returned when menu closes and
                           ; user made no selections.

    db   0,'FILE',0           ; ID = 0x100 + 1
    db   1,'Start Decoder',0  ; ID = 0x100 + 2
    db   1,'Audio Mixer',0    ; ID = 0x100 + 2
    db   1,'-',0              ; ID = 0x100 + 6
    db   1,'Quit',0           ; ID = 0x100 + 6

    db   255               ; End of Menu Struct


ipc_memory:

    dq  0x0    ; lock - 0=unlocked , 1=locked
    dq  16     ; first free position from ipc_memory

string_file:
fileload:

    db  'No movie file (.mpg) selected.'

    times 110 db 0


image_end:


