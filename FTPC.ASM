;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   FTP client for Menuet64
;
;   (c) Ville Turjanmaa
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

use64

    org   0x0

    db    'MENUET64'              ; Header identifier
    dq    0x02                    ; Version
    dq    START                   ; Start of code
    dq    image_end               ; Size of image
    dq    0x500000                ; Memory for app
    dq    0xffff0                 ; Esp
    dq    Param                   ; Prm 
    dq    0x00                    ; Icon

include 'dns.inc'

overflow_limit equ 0x3fff00
blines         equ 250

START:

    call  check_terminal

    mov   rax , 141
    mov   rbx , 1
    mov   rcx , 1
    mov   rdx , 5 shl 32 + 5
    mov   r8  , 9 shl 32 + 12
    int   0x60

    mov   rax , 0
    mov   [blocksize],rax
    mov   rax , tcpipblock
    mov   [blockpos],rax

    call  draw_window       ; At first, draw the window

    cmp   [doenter],byte 1
    je    enterpressed

    call  set_help
    call  draw_text

    mov   rsi , string_prompt
    call  add_text


still:

    mov   rax , 123         ; Wait here for event
    mov   rbx , 1
    int   0x60

    test  rax , 0x1         ; Window redraw
    jnz   window_event
    test  rax , 0x2         ; Keyboard press
    jnz   key_event
    test  rax , 0x4         ; Button press
    jnz   button_event

    ;
    ; IPC from terminal
    ;
    cmp   [termpid],dword 0
    je    notermipc
    cmp   [ipc_memory+8],dword 16
    je    notermipc
    cmp   [ipc_memory+16],word 27 + 255 shl 8
    jne   notermipc
    ; Keyboard event
    mov   ax , [ipc_memory+16+4]
    cmp   ax , 2
    jne   notpi2
    mov   rbx , [ipc_memory+16+6+8*0]
    mov   rcx , [ipc_memory+16+6+8*1]
    mov   rdx , [ipc_memory+16+6+8*2]
    push  rbx rcx rdx
    mov   rsi , ipc_memory+16+6+8*3
    mov   rdi , ipc_memory+16
    mov   rcx , 200
    cld
    rep   movsb
    sub   [ipc_memory+8],dword 6+8*3
    pop   rdx rcx rbx
    jmp   overgetkey
  notpi2:
    ; Button event
    cmp   ax , 4
    jne   notpi8
    mov   rax , [ipc_memory+16+6+8*0]
    mov   rbx , [ipc_memory+16+6+8*1]
    mov   rcx , [ipc_memory+16+6+8*2]
    mov   [ipc_memory+8],dword 16
    mov   [ipc_memory+16],dword 0
    jmp   overgetbutton
  notpi8:
  notermipc:

    ;
    ; Read input
    ;
    mov   [read_input_delay],dword 10
    call  read_input

    ;
    ; Connection status
    ;
    cmp   [status],byte 1
    jne   nostatusclosecheck
    mov   rax , 53
    mov   rbx , 6
    mov   rcx , [socket]
    int   0x60
    cmp   rax , 4
    je    nostatusclosecheck
    call  close_connection
    mov   rsi , string_connectionclosed
    call  add_text
    mov   rsi , string_prompt
    call  add_text
    call  draw_text
    jmp   still
  nostatusclosecheck:

    jmp   still


window_event:

    call  draw_window
    jmp   still

key_event:

    mov   rax , 0x2        ; Read the key and ignore
    int   0x60

  overgetkey:

    test  rbx , 1
    jnz   still

    cmp   [vscroll_value],dword (blines+1000-16)
    jb    still

    cmp   ecx , 'Ente'
    je    enterpressed

    cmp   ecx , 'Back'
    jne   noback

    cmp   [cursor],dword 2
    jbe   still  

    mov   al , 8
    call  add_letter

    call  draw_text_lastline
    jmp   still

  noback:  

    cmp   rbx , 0
    jne   still

    mov   rax , [cursor]

    cmp   rax , 2
    jae   nostill
    call  scroll
    jmp   commandexit
  nostill:

    mov   al , cl
    call  add_letter

    call  draw_text_lastline

    jmp   still


set_help:

    mov   rsi , helptext
  shl10:
    mov   al , [rsi]
    push  rsi
    call  add_letter
    pop   rsi
    add   rsi , 1
    cmp   rsi , helptextend
    jb    shl10

    ret


add_text:

  addl10:
    mov   al , [rsi]
    push  rsi
    call  add_letter
    pop   rsi
    add   rsi , 1
    cmp   [rsi], byte 0
    jne   addl10

    call  draw_text

    ret


check_terminal:

    mov   rdi , dataclear
    mov   rcx , datacleare-dataclear
    mov   rax , 0
    cld
    rep   stosb
    mov   [ipc_memory+8],dword 16

    cmp   [Param+8],dword 'term'
    jne   nocommandline

    mov   rax , 200
    mov   rdi , windim
    mov   rcx , 4
    cld
    rep   stosq
    mov   [fontsize],dword 12

    mov   rax , 60           ; ipc
    mov   rbx , 1            ; define memory area
    mov   rcx , ipc_memory   ; memory area pointer
    mov   rdx , 256          ; size of area
    int   0x60

    mov   rdi , Param+8+8+1
    mov   rcx , 0
  newparam:
    movzx rax , byte [rdi]
    sub   rax , 48
    imul  rcx , 10
    add   rcx , rax
    add   rdi , 1
    cmp   rdi , Param+8+15+1
    jbe   newparam
    mov   [termpid],rcx

    mov   rsi , Param+8+18
    mov   rdi , filelocation
  filel0:
    mov   al  , [rsi]
    cmp   al  , 32
    jbe   filel1
    mov   [rdi],al
    add   rdi , 1
    add   rsi , 1
    jmp   filel0
  filel1:
    mov   rax , 0
    stosq

    mov   rsi , Param+8+18
    mov   rdi , string_terminal_path
  newsps:
    mov   al , [rsi]
    cmp   al , ' '
    jbe   pathdone
    mov   [rdi],al
    add   rsi , 1
    add   rdi , 1
    jmp   newsps
  pathdone:
    mov   [rdi],byte 0
    sub   rdi , string_terminal_path
    mov   [string_terminal_len],rdi
    add   rsi , 1

    mov   [doenter],byte 0

    cmp   [rsi],byte ' '
    jb    noopenconn

    mov   rbx , text+81*blines+2

    mov   rax , 'open    '
    mov   [rbx],rax
    mov   rdi , rbx
    add   rdi , 5
  p10:
    mov   al  , [rsi]
    cmp   al  , 32
    jbe   p1r
    mov   [rdi],al
    add   rsi , 1
    add   rdi , 1
    jmp   p10
   p1r:
    mov   [rdi],byte 0

    mov   [doenter],byte 1

  noopenconn:
  nocommandline:

    ret



send_next_port:

    push  rax rbx rcx rdx rsi rdi

    mov   [cursor],dword 0
    call  scroll

    ; Active data connection

    mov   rax , 53
    mov   rbx , 7
    mov   rcx , [socket]
    mov   rdx , pasvstringend - pasvstring
    mov   rsi , pasvstring
    int   0x60

    mov   [read_input_delay],dword 2000
    call  read_input
    call  draw_text

    ; Parse parameters

    cmp   [text+81*(blines-1)],dword '227 '
    jne   nofoundl1

    ; Scan to '('

    mov   rbx , text+81*(blines-1)
  scanl1:
    cmp   [rbx],byte '('
    je    foundl1
    inc   rbx
    cmp   rbx , text+81*blines
    jb    scanl1
    jmp   nofoundl1
  foundl1:

    ; Parameters

    mov   rdi , parameters

  scantoparameter:

    mov   rcx , 0
  scanl3:
    inc   rbx
    ;
    cmp   [rbx],byte 13
    jbe   foundl3
    ;
    cmp   [rbx],byte ')'
    je    foundl3
    cmp   [rbx],byte ','
    je    foundl3
    ;
    cmp   [rbx],byte '0'
    jb    foundl3
    cmp   [rbx],byte '9'
    ja    foundl3
    ;
    movzx rdx , byte [rbx]
    sub   rdx , 48
    imul  rcx , 10
    add   rcx , rdx
    jmp   scanl3
  foundl3:

    mov   [rdi],rcx

    mov   rcx , 0

    add   rdi , 8
    cmp   rdi , parameters+6*8
    jb    scantoparameter

  scandone:

    xor   rcx , rcx
    mov   cl , [parameters+5*8]
    mov   ch , [parameters+4*8]
    mov   [dataport],rcx

    xor   rcx , rcx
    mov   ch , [parameters+3*8]
    mov   cl , [parameters+2*8]
    shl   rcx , 16
    mov   ch , [parameters+1*8]
    mov   cl , [parameters+0*8]
    mov   [dataip],rcx

  nofoundl1:

    pop   rdi rsi rdx rcx rbx rax

    ret



openDataConnection:

    push  rax rbx rcx rdx rsi rdi

    mov   rax , 53
    mov   rbx , 5
    mov   rcx , [datalocalport]         
    mov   rdx , [dataport]
    mov   rsi , [dataip]
    mov   rdi , 1 ; active
    int   0x60

    mov   [socket_data],rax

    mov   rdx , 0
  waitfordataopenc:

    call  check_window_draw

    mov   rax , 105
    mov   rbx , 1
    int   0x60
    inc   rdx
    cmp   rdx , 1000*5 ; 5 sec timeout
    ja    dataopentimeoutc
    mov   rax , 53
    mov   rbx , 6
    mov   rcx , [socket_data]
    int   0x60
    cmp   rax , 4
    jb    waitfordataopenc
    mov   [netresult],byte 0
    jmp   dataopenfine
  dataopentimeoutc:
    mov   [netresult],byte 1
  dataopenfine:

    pop   rdi rsi rdx rcx rbx rax

    mov   [datacount],dword 0

    ret


closedataconnection:

    push  rax rbx rcx rdx rsi rdi

    mov   rax , 53
    mov   rbx , 8
    mov   rcx , [socket_data]
    int   0x60

    pop   rdi rsi rdx rcx rbx rax

    ret


analyze:

    ; Remove leading spaces 

  asl0:
    cmp   [command],byte ' '
    jne   asl1
    mov   rdi , command
    mov   rsi , command + 1
    mov   rcx , 250
    cld
    rep   movsb
    jmp   asl0
  asl1:

    ; To uppercase

    mov   rsi , command-1
  al0:
    inc   rsi
    cmp   [rsi],byte ' '
    jbe   al1
    cmp   [rsi],byte 97
    jb    al0
    sub   [rsi],byte 32
    jmp   al0
  al1:

    ; GET -> RETR

    cmp   [command],dword 'GET '
    jne   noget

    mov   rdi , command+1+240
    mov   rsi , command+240
    mov   rcx , 240
    std
    rep   movsb
    cld

    mov   [command],dword 'RETR'

    inc   dword [cursor]

  noget:

    ; LS -> LIST

    cmp   [command], word 'LS'
    jne   nols

    mov   rdi , command+2+240
    mov   rsi , command+240
    mov   rcx , 240
    std
    rep   movsb
    cld

    mov   [command],dword 'LIST'

    add   dword [cursor],2

  nols:

    ; DIR -> LIST

    cmp   [command], word 'DI'
    jne   nodir
    cmp   [command+2], byte 'R'
    jne   nodir

    mov   rdi , command+1+240
    mov   rsi , command+240
    mov   rcx , 240
    std
    rep   movsb
    cld

    mov   [command],dword 'LIST'

    add   dword [cursor],1

  nodir:

    ; FTP -> OPEN

    cmp   [command], word 'FT'
    jne   noftp
    cmp   [command+2], byte 'P'
    jne   noftp

    mov   rdi , command+1+240
    mov   rsi , command+240
    mov   rcx , 240
    std
    rep   movsb
    cld

    mov   [command],dword 'OPEN'

    add   dword [cursor],1

  noftp:

    ; DEL -> DELE

    cmp   [command], dword 'DEL '
    jne   nodel

    mov   rdi , command+1+240
    mov   rsi , command+240
    mov   rcx , 240
    std
    rep   movsb
    cld

    mov   [command],dword 'DELE'

    add   dword [cursor],1

  nodel:

    ; SEND -> STOR

    cmp   [command],dword 'SEND'
    jne   nosend

    mov   [command],dword 'STOR'

  nosend:

    mov   rax , [command]
    and   rax , 0xffffff
    cmp   rax , 'BIN'
    jne   nobin

    mov   rax , 'TYPE I'
    mov   [command],rax

    add   [cursor],dword 3

  nobin:

    mov   rax , [command]
    and   rax , 0xffffff
    cmp   rax , 'CD '           
    jne   nocd

    mov   rdi , command+1+240
    mov   rsi , command+240
    mov   rcx , 240
    std
    rep   movsb
    cld

    mov   [command],dword 'CWD '

    add   [cursor],dword 1

  nocd:

    ret


enterpressed:

    mov   rsi , text+81*blines+2
    mov   rdi , command
    mov   rcx , 200
    cld
    rep   movsb

    ;
    ; Analyze the command
    ;

    call  analyze

    ;
    ; Exit
    ;

    cmp   [command],dword 'EXIT'       
    jne   noexit

    call  scroll

  startexit:
    cmp   [status],byte 0
    je    doexit
    cmp   [cursor],dword 0
    je    noscroll2
    call  scroll
  noscroll2:
    mov   rsi , string_connectionopen
    call  add_text
    jmp   commandexit
  doexit:

    cmp   [status],byte 1
    jne   noclose2

    call  close_connection
    mov   rax , 5 
    mov   rbx , 20
    int   0x60

  noclose2:

    mov   rax , 512
    int   0x60
  noexit:

    ;
    ; Help
    ;
    cmp   [command],dword 'HELP'      
    jne   nohelp
    call  scroll
    call  set_help
    jmp   commandexit
  nohelp:

    ;
    ; Local directory
    ;
    cmp   [command],word 'LC'
    jne   nolcd
    cmp   [command+2],byte 'D'
    jne   nolcd
    ;
    cmp   [command+4],byte 32
    jbe   nosetdir
    mov   rsi , command+4
    mov   rdi , filelocation
  nosetdir11:
    cmp   [rsi],byte 32
    jbe   nosetdir10
    cld
    movsb
    jmp   nosetdir11
  nosetdir10:
    cmp   [rdi-1],byte '/'
    je    nosetdir12
    mov   al , '/'
    cld
    stosb
  nosetdir12:
    mov   rax , 0
    cld
    stosq
    ;
  nosetdir:
    call  scroll
    mov   rsi , filelocationtext
    call  add_text
    call  scroll
    jmp   commandexit
  nolcd:

    ;
    ; Open
    ;

    cmp   [command],dword 'OPEN'     
    jne   noopen

    cmp   [status],byte 1
    jne   doopen
    call  scroll
    call  draw_text
    jmp   commandexit
  doopen:

    cmp   [doenter],byte 1
    je    noscr2
    call  scroll
  noscr2:
    mov   [doenter],byte 0

    mov   rsi , command+5
    call  decode

    cmp   [ip],dword 0
    je    exitopen

    mov   rax , 3
    mov   rbx , 1
    int   0x60
    mov   rcx , rax
    shr   rcx , 16
    and   rcx , 0xff
    add   rcx , 2048 ; local port

    mov   [datalocalport],rcx
    inc   dword [datalocalport]   ; dataport = commandport+1
    mov   rdi , [ip]
    mov   [dataip],rdi            ; same ip by default

    mov   rax , 53
    mov   rbx , 5
    mov   rdx , 21
    mov   rsi , [ip]
    mov   rdi , 1 ; active
    int   0x60

    mov   [socket],rax

    ; Wait for open

    mov   r8  , 0

  wait_for_open:

    inc   r8 
    cmp   r8 , 200
    jb    waitmore ; timeout
  exitopen:

    mov   rsi , string_fail
    call  add_text

    call  draw_text
    jmp   commandexit
  waitmore:

    mov   rax , 5
    mov   rbx , 1
    int   0x60

    mov   rax , 53
    mov   rbx , 6
    mov   rcx , [socket]
    int   0x60
    cmp   rax , 4
    jne   wait_for_open

    mov   [status],byte 1

    ; Read possible response

    mov   [waittext],dword '220 '
    mov   [read_input_delay],dword 2000
    call  read_input
    mov   [waittext],dword 0

    ; Welcome text -> send username / password

    cmp   [text+81*(blines-1)], word '22'
    jne   commandexit
    cmp   [text+81*(blines-1)+2], byte '0'
    jne   commandexit

    mov   rsi , string_username
    call  add_text

    mov   [showtext],byte 1
    call  readstring

    call  scroll

    ; Send username

    mov   rax , 53
    mov   rbx , 7
    mov   rcx , [socket]
    mov   rdx , command_user_end-command_user
    mov   rsi , command_user
    int   0x60
    mov   rax , 53
    mov   rbx , 7
    mov   rcx , [socket]
    mov   rdx , [command_str_len]
    mov   rsi , command_str
    int   0x60
    mov   rax , 53
    mov   rbx , 7
    mov   rcx , [socket]
    mov   rdx , 2
    mov   rsi , command_lf
    int   0x60

    ; Read possible response

    mov   [waittext],dword '331 '
    mov   [read_input_delay],dword 2000
    call  read_input
    mov   [waittext],dword 0

    cmp   [text+81*(blines-1)], word '33'
    jne   commandexit
    cmp   [text+81*(blines-1)+2], byte '1'
    jne   commandexit

    mov   rsi , string_password
    call  add_text

    mov   [showtext],byte 0
    call  readstring

    call  scroll

    ; Send password

    mov   rax , 53
    mov   rbx , 7
    mov   rcx , [socket]
    mov   rdx , command_pass_end-command_pass
    mov   rsi , command_pass
    int   0x60
    mov   rax , 53
    mov   rbx , 7
    mov   rcx , [socket]
    mov   rdx , [command_str_len]
    mov   rsi , command_str
    int   0x60
    mov   rax , 53
    mov   rbx , 7
    mov   rcx , [socket]
    mov   rdx , 2
    mov   rsi , command_lf
    int   0x60

    ; Read possible response

    mov   [waittext],dword '230 '
    mov   [read_input_delay],dword 3000
    call  read_input
    mov   [waittext],dword 0

    jmp   commandexit

  noopen:

    ;
    ; Open data port connection
    ;

    mov   rax , [cursor]
    sub   rax , 2
    mov   [command+rax],word 13+256*10       

    mov   rax , 53
    mov   rbx , 7
    mov   rcx , [socket]
    mov   rdx , [cursor]

    cmp   rdx , 2
    jg    nocommandexit
    call  scroll
    jmp   commandexit
  nocommandexit:
    cmp   [status],byte 0
    jne   commandfine2
    call  scroll
    call  draw_text
    jmp   commandexit
  commandfine2:

    mov   rsi , command       

    cmp   [rsi],dword 'STOR'
    je    openc
    cmp   [rsi],dword 'LIST'
    je    openc
    cmp   [rsi],dword 'RETR'
    jne   noretr1
  openc:

    ; Port to use

    call  send_next_port

    push  rax rbx
    mov   rax , 5
    mov   rbx , 25
    int   0x60
    pop   rbx rax

    ; Send the actual command to server

    int   0x60

    push  rax rbx 
    mov   rax , 5
    mov   rbx , 25
    int   0x60
    pop   rbx rax

    ; Open data connection

    call  openDataConnection

    cmp   [netresult],byte 0
    jne   exitopen

    jmp   commandsent

  noretr1:

    ;
    ; Send the actual command to server
    ;

    int   0x60

  commandsent:

    ;
    ; Quit
    ;

    cmp   [command],dword 'QUIT'
    jne   noquit
    call  scroll
    mov   [waittext],dword '221 '
    mov   [read_input_delay],dword 1000
    call  read_input
    mov   [waittext],dword 0
    mov   rax , 5 
    mov   rbx , 25
    int   0x60
    call  close_connection
    jmp   commandexit 
  noquit:

    ;
    ; List
    ;

    cmp   [command],dword 'LIST'
    jne   nodolist

    mov   [print],byte 1

    mov   [cursor],dword 0
    call  scroll

    mov   r8 , 0

  waitfordataend2:

    mov   rax , 5
    mov   rbx , 1
    int   0x60

    inc   r8
    cmp   r8 , 20*10 ; 10 sec timeout
    ja    timeout2

    push  r8
    mov   [read_input_delay],dword 20
    call  read_input
    mov   [read_input_delay],dword 20
    call  read_input_data
    pop   r8

    mov   rax , 53
    mov   rbx , 6
    mov   rcx , [socket_data]
    int   0x60
    cmp   rax , 4
    jbe   waitfordataend2

  timeout2:

    call  closedataconnection

    ; Do not save input

    mov   [print],byte 0

    mov   [waittext],dword '226 '
    mov   [read_input_delay],dword 1000
    call  read_input
    mov   [waittext],dword 0

    call  scroll 

    jmp   commandexit

  nodolist:

    ;
    ; Retr
    ;

    cmp   [command],dword 'RETR'       
    jne   noretr

    mov   r8 , 0
    mov   r9 , 0x100000

  waitfordataend:

    push  r9
    push  r8
    mov   [read_input_delay],dword 00
    call  read_input
    mov   [read_input_delay],dword 20
    call  read_input_data
    pop   r8
    pop   r9

    cmp   r9 , [datacount]
    je    nozero
    mov   r8 , 0
    mov   r9 , [datacount]
  nozero:

    cmp   [datacount],dword overflow_limit-10
    ja    overflow

    ; Timeout

    inc   r8
    cmp   r8 , (1000*10) / 20
    ja    timeout

    ; Transfer complete

    cmp   [text+81*(blines-1)],dword '226 '
    jne   waitfordataend

    mov   [read_input_delay],dword 500
    call  read_input_data

    call  closedataconnection

    mov   [read_input_delay],dword 500
    call  read_input

    call  savefile

    call  scroll 

    jmp   commandexit

  overflow:

    mov   rsi , string_overflow
    call  add_text
    call  draw_text

    jmp   nofilesave

  timeout:

    mov   rsi , string_timeout
    call  add_text
    call  draw_text

  nofilesave:

    call  closedataconnection

    mov   [read_input_delay],dword 2000
    call  read_input

    call  scroll

    jmp   commandexit

  noretr:

    ;
    ; Stor
    ;

    cmp   [command],dword 'STOR'      
    jne   nostor

    call  openfile

    mov   [blocksinbuffer],dword 1
    mov   [readblock],dword 1

    ; Size fine

    mov   r8 , 0

    mov   r9  , 0
    mov   r10 , [datacount]

  waitfordataopen:

    mov   rax , 5
    mov   rbx , 1
    int   0x60

    mov   rax , 53
    mov   rbx , 6
    mov   rcx , [socket_data]
    int   0x60

    inc   r8
    cmp   r8 , 100*10
    ja    timeout3

    cmp   rax , 4  
    jne   waitfordataopen

  send_data_loop:

    mov   [read_input_delay],dword 0

    push  r9 r10

    call  read_input

    pop   r10 r9

    ; Send file in 512 byte chunks

    mov   r11 , r10
    sub   r11 , r9
    mov   rdx , 512
    cmp   r11 , 512
    jae   rdxfine
    mov   rdx , r11
  rdxfine:

    mov   rax , 53
    mov   rbx , 7
    mov   rcx , [socket_data]
    mov   rsi , 0x100000 
    int   0x60

    cmp   eax , 0
    jne   displayfail

    add   r9  , rdx
    cmp   r9  , r10
    je    timeout3

    ; Read more file

    push  rax rbx rcx rdx rsi rdi r8 r9

    mov   rdi , 0x100000
    mov   rsi , rdi
    add   rsi , 512
    mov   rcx , 65536+1024
    cld
    rep   movsb

    sub   [blocksinbuffer],dword 1
    cmp   [blocksinbuffer],dword 0
    jne   noreadfile
    mov   rax , 58
    mov   rbx , 0
    mov   rcx , [readblock]
    mov   rdx , 65536/512
    mov   r8  , 0x100000
    mov   r9  , filename
    int   0x60
    mov   [blocksinbuffer],dword 65536/512
    add   [readblock],dword 65536/512
  noreadfile:

    pop   r9 r8 rdi rsi rdx rcx rbx rax

    ; Connection open

    mov   rax , 53
    mov   rbx , 6
    mov   rcx , [socket_data]
    int   0x60
    cmp   rax , 4
    je    send_data_loop  

    jmp   timeout3

  displayfail:

    mov   rsi , string_fail
    call  add_text

  timeout3:

    mov   rax , 5
    mov   rbx , 50
    int   0x60

    call  closedataconnection

    mov   [waittext],dword '226 '
    mov   [read_input_delay],dword 2000
    call  read_input
    mov   [waittext],dword 0

    call  scroll 

    jmp   commandexit

  nostor:

    ;
    ; Other commands
    ;

    call  scroll

    mov   [waittext],dword '200 '
    mov   [read_input_delay],dword 2000
    call  read_input
    mov   [waittext],dword 0

  commandexit:

    mov   rsi , string_prompt
    call  add_text

    call  draw_text

    jmp   still



readstring:

    mov   [command_str_len],dword 0

  readmore:

    ; Terminal
    cmp   [termpid],dword 0
    je    notermparam
    cmp   [ipc_memory+8],dword 16
    je    notermparam
    cmp   [ipc_memory+16],word 27 + 255 shl 8
    jne   notermparam
    ; Keyboard event
    mov   ax , [ipc_memory+16+4]
    cmp   ax , 2
    jne   notpi3
    mov   rbx , [ipc_memory+16+6+8*0]
    mov   rcx , [ipc_memory+16+6+8*1]
    mov   rdx , [ipc_memory+16+6+8*2]
    mov   [ipc_memory+8],dword 16
    mov   [ipc_memory+16],dword 0
    jmp   ipc_message_2 ; overgetkey
  notpi3:
    mov   [ipc_memory+8],dword 16
    mov   [ipc_memory+16],dword 0
  notermparam:

    mov   rax , 123
    mov   rbx , 1
    int   0x60

    test  rax , 1
    jz    nownd
    call  draw_window
    jmp   readmore
  nownd:

    test  rax , 2
    jz    readmore

    mov   rax , 2
    int   0x60

  ipc_message_2:

    test  rbx , 1
    jnz   readmore

    cmp   cx , 'En'
    je    readover

    cmp   cx , 'Ba'
    jne   nobackspace
    cmp   [command_str_len],dword 0
    je    readmore
    dec   dword [command_str_len]
    mov   rax , [command_str_len]
    mov   [command_str+rax],byte 0

    cmp   [showtext],byte 1
    jne   noshowtext1

    mov   rsi , string_8
    call  add_text

    call  draw_text

  noshowtext1:

    jmp   readmore

  nobackspace:

    cmp   rbx , 0
    jne   readmore

    mov   rax , [command_str_len]
    cmp   rax , 50
    ja    readmore

    mov   [command_str+rax],cl
    mov   [command_str+rax+1],byte 0

    cmp   [showtext],byte 1
    jne   noshowtext2
    mov   al , cl
    call  add_letter
    call  draw_text_lastline
  noshowtext2:

    inc   dword [command_str_len]

    jmp   readmore

  readover:

    ret



check_window_draw:

    push  rax rbx rcx rdx r8 r9 r10 r11 r12 r13 r14 r15 rsi rdi rbp

    mov   rax , 11
    int   0x60
    test  rax , 1
    jz    nowindowdraw
    call  draw_window
  nowindowdraw:

    pop   rbp rdi rsi r15 r14 r13 r12 r11 r10 r9 r8 rdx rcx rbx rax

    ret


close_connection:        

    cmp   [status],byte 1
    jne   noclose

    mov   rax , 53
    mov   rbx , 8 
    mov   rcx , [socket]
    int   0x60

  noclose:

    mov   [status],byte 0

    ret


decode:

    mov   rdi , ip
    call  get_ip

    ret


read_input:

    mov   r8  , 0 

  read_more_1:

    call  check_window_draw

    mov   rax , 53
    mov   rbx , 2
    mov   rcx , [socket]
    int   0x60

    cmp   rax , 0
    jne   read_more  

    inc   r8
    cmp   r8 , [read_input_delay]
    ja    read_end

    mov   rax , 105
    mov   rbx , 1
    int   0x60

    jmp   read_more_1

  read_more:

    mov   rax , 53
    mov   rbx , 3
    mov   rcx , [socket]
    int   0x60

    push  rax
    mov   al , bl
    call  add_letter
    pop   rax

    cmp   bl , 13
    ja    nowtcheck
    mov   ecx , [waittext]
    cmp   ecx , 0
    je    nowtcheck
    cmp   [text+81*(blines-1)],ecx
    jne   nowtcheck
    mov   r8 , [read_input_delay]
    sub   r8 , 250
  nowtcheck:

    cmp   rax , 0
    jne   read_more

    jmp   read_more_1

  read_end:

    ret



read_input_data:

    mov   r8  , 0 

  data_read_more_1:

    call  check_window_draw

    cmp   [blocksize],dword 0
    jne   data_read_more  

    mov   rax , 53
    mov   rbx , 2
    mov   rcx , [socket_data]
    int   0x60

    cmp   rax , 0
    jne   data_read_more  

    inc   r8
    cmp   r8 , [read_input_delay]
    ja    data_read_end

    mov   rax , 105
    mov   rbx , 1
    int   0x60

    jmp   data_read_more_1

  data_read_more:

    call  read_data_block

    mov   rdx , [datacount]
    mov   [0x100000+rdx],bl
    inc   qword [datacount]

    cmp   rdx , overflow_limit
    ja    data_overflow

    cmp   [print],byte 1
    jne   noprint2
    push  rax
    mov   al , bl
    call  add_letter
    pop   rax
  noprint2:

    cmp   rax , 0
    jne   data_read_more

    jmp   data_read_more_1

  data_read_end:

    ret

  data_overflow:

    ret


read_data_block:

    cmp   [blocksize],dword 0
    jne   getblockbyte

    push  rdx
    mov   rax , 53
    mov   rbx , 13
    mov   ecx , [socket_data]
    mov   rdx , tcpipblock
    int   0x60
    pop   rdx

    mov   [blocksize],rax
    mov   [blockpos],dword tcpipblock

    cmp   rax , 0
    je    noreadblockbyte

  getblockbyte:

    mov   rbx , [blockpos]
    mov   bl  , [rbx]
    and   rbx , 0xff

    inc   dword [blockpos]
    dec   dword [blocksize]

    mov   rax , [blocksize]

  noreadblockbyte:

    ret



savefile:

    call  set_filename

    mov   rax , 58
    mov   rbx , 2
    mov   r9  , filename
    int   0x60

    mov   rax , 58
    mov   rbx , 1
    mov   rcx , 0
    mov   rdx , [datacount]
    mov   r8  , 0x100000
    mov   r9  , filename
    int   0x60

    ret


openfile:

    call  set_filename

    mov   rax , 58
    mov   rbx , 0
    mov   rcx , 0 
    mov   rdx , 1
    mov   r8  , 0x100000
    mov   r9  , filename
    int   0x60

    mov   [datacount],rbx

    ret

set_filename:

    mov   rdi , filename
    mov   rsi , filelocation
  sfl6:
    cmp   [rsi],byte 13
    jbe   sfl5
    cld
    movsb
    jmp   sfl6
  sfl5:

    mov   rsi , command + 2
  sfl1:
    inc   rsi 
    cmp   rsi , command+250
    ja    sfl2
    cmp   [rsi-1],byte ' '
    ja    sfl1

  sfl11:
    cmp   [rsi],byte 32
    jbe   sfl2
    cld
    movsb
    jmp   sfl11

  sfl2:
    mov   [rdi],byte 0

    ret



add_letter:

    cmp   [termpid],dword 0
    je    nosendtoterm
    push  rax
    mov   [sendstr],al
    mov   rax , 60
    mov   rbx , 2
    mov   rcx , [termpid]
    mov   rdx , sendstr
    mov   r8  , 1
    int   0x60
    pop   rax
    ; Add letter also to local text area
  nosendtoterm:

    cmp   al , 8
    jne   nobackspace3
    sub   [cursor],dword 1
    mov   rax , [cursor]
    mov   [text+blines*81+rax],byte ' '
    ret
  nobackspace3:

    cmp   al , 13
    jne   noscroll
    ;
    mov   rdi , text
    mov   rsi , text+81
    mov   rcx , 81*blines+1
    cld
    rep   movsb
    mov   rdi , text+81*blines
    mov   rcx , 81
    mov   rax , 0
    cld
    rep   stosb
    mov   [cursor],dword 0
    call  draw_text
    ret
  noscroll:

    cmp   al , 19
    jb    noprint

    mov   rbx , [cursor]

    cmp   rbx , 80
    jb    noscr  
    push  rax     
    call  scroll
    pop   rax      
    mov   rbx , 0
  noscr:

    mov   [text+81*blines+rbx],al

    inc   dword [cursor]

  noprint:

    ret




scroll:

    mov   rsi , string_lf
    call  add_text

    ret



draw_text_lastline:

    mov   [lastline],byte 1
    call  draw_text
    mov   [lastline],byte 0
    ret


draw_text:

    cmp   [termpid],dword 0
    jne   nodrawtext

    cmp   [windim+2*8],dword 100
    jb    nodrawtext
    cmp   [windim+3*8],dword 100
    jb    nodrawtext

    mov   rax , 4
    mov   rbx , [vscroll_value]
    sub   rbx , 1000
    imul  rbx , 81
    add   rbx , text
    mov   rcx , 6
    mov   rdx , 48
    mov   rsi , 0x000000
    mov   r9  , 1
    mov   r10 , 17

    mov   r15 , 10

    cmp   [fontsize],dword 10
    jne   nofont10
    add   rbx , 81
    dec   r10
    mov   r15 , 11
    mov   rdx , 40+3
  nofont10:
    cmp   [fontsize],dword 11
    jne   nofont11
    add   rbx , 81*2
    dec   r10
    dec   r10
    mov   r15 , 12
    mov   rdx , 40
  nofont11:
    cmp   [fontsize],dword 12
    jne   nofont12
    add   rbx , 81*3
    dec   r10
    dec   r10
    dec   r10
    mov   r15 , 13
    mov   rdx , 40-1
  nofont12:

    mov   [line_height],r15
    mov   [line_begin],rdx

    ; Lines to display
    push  rax rbx rcx rdx
    mov   rax , [windim+3*8]
    sub   rax , 50+5
    xor   rdx , rdx
    div   r15
    mov   r10 , rax
    mov   [lines_to_display],r10
    pop   rdx rcx rbx rax

    push  rax
    mov   rbx , [vscroll_value]
    sub   rbx , 1000
    imul  rbx , 81
    add   rbx , text
    mov   rax , [lines_to_display]
    sub   rax , 17
    imul  rax , 81
    sub   rbx , rax
    pop   rax

    ; Linelength
    push  rax rbx rcx rdx
    mov   rax , [windim+2*8]
    sub   rax , 12+13
    xor   rdx , rdx
    mov   rbx , 6
    div   rbx
    cmp   rax , 80
    jbe   linelenfine
    mov   rax , 80
  linelenfine:
    mov   [line_length],rax
    pop   rdx rcx rbx rax

  newt:

    cmp   [lastline],byte 1
    jne   nolastlinedisplay
    cmp   r10 , 1
    jne   skiplines
  nolastlinedisplay:

    push  rax rbx rcx rdx

    mov   rax , 13
    mov   rbx , rcx
    mov   rcx , rdx
    mov   rdx , 0xffffff

    dec   rcx

    shl   rbx , 32
    shl   rcx , 32

    mov   rax , [line_length]
    imul  rax , 6
    add   rbx , rax

    add   rcx , 1
    add   rcx , [fontsize]

    mov   rax , 13
    int   0x60

    pop   rdx rcx rbx rax

    cmp   rbx , text
    jb    skiplines

    push  r14
    mov   r14 , [line_length]
    push  qword [rbx+r14]
    mov   [rbx+r14],byte 0
    int   0x60
    pop   qword [rbx+r14]
    pop   r14

  skiplines:

    add   rbx , 81
    add   rdx , r15
    dec   r10
    jnz   newt

    call  draw_cursor

  nodrawtext:

    ret


draw_cursor:

    cmp   [vscroll_value],dword (blines+1000-16)
    jb    nodrcursor

    cmp   [termpid],dword 0
    jne   nodrcursor

    cmp   [windim+2*8],dword 100
    jb    nodrcursor
    cmp   [windim+3*8],dword 100
    jb    nodrcursor

    mov   rax , 38
    mov   rbx , [cursor]
    imul  rbx , 6
    add   rbx , 6

    mov   rcx , [lines_to_display]
    sub   rcx , 1
    imul  rcx , [line_height]
    add   rcx , [line_begin]
    sub   rcx , 1

    mov   rdx , rbx
    mov   r8  , rcx
    add   r8  , [fontsize]
    mov   r9  , 0x000000
    int   0x60

  nodrcursor:

    ret



button_event:

    mov   rax , 0x11
    int   0x60

  overgetbutton:

    cmp   rbx , 1000                       ;  Vertical scroll
    jb    no_vertical_scroll
    cmp   rbx , 2500
    ja    no_vertical_scroll
    mov   [vscroll_value], rbx
    call  draw_vertical_scroll
    call  draw_text
    jmp   still
  no_vertical_scroll:

    ; rax = status
    ; rbx = button id

    cmp   rbx , 0x10000001
    je    startexit
    cmp   rbx , 0x102
    je    startexit

    jmp   still



draw_window:

    mov   rax , 200
    mov   rdi , windim
    mov   rcx , 4
    cld
    rep   stosq

    mov   [fontsize],dword 12

    cmp   [termpid],dword 0
    jne   dwl99

    mov   rax , 0xC                          ; Beginning of window draw
    mov   rbx , 0x1
    int   0x60

    mov   rax , 141
    mov   rbx , 3
    int   0x60
    and   rax , 0xff
    mov   [fontsize],rax

    mov   rax , 0x0                             ; Draw window
    mov   rbx , 0x0000006000000000+12+80*6+13   ; x start & size
    mov   rcx , 0x0000006000000000+50+13*14     ; y start & size
    mov   rdx , 0x0000000000FFFFFF              ; type    & border color  
    mov   r8  , 0x0000000000000001              ; draw flags
    mov   r9  , window_label                    ; 0 or label - asciiz
    mov   r10 , menu_struct                     ; 0 or pointer to menu struct
    int   0x60

    call  get_window_dimensions

    call  draw_vertical_scroll

    call  draw_text

    mov   rax , 0xC                          ; End of window draw
    mov   rbx , 0x2
    int   0x60

  dwl99:

    ret


draw_vertical_scroll:

    cmp   [termpid],dword 0
    jne   nodrawscroll

    cmp   [windim+2*8],dword 100
    jb    nodrawscroll
    cmp   [windim+3*8],dword 100
    jb    nodrawscroll

    ; Vertical scroll

    mov   rax , 113
    mov   rbx , 1
    mov   rcx , 1000
    mov   rdx , (blines-15)
    mov   r8  , [vscroll_value]
    mov   r9  , [windim+2*8]
    sub   r9  , 13+5
    mov   r10 , 38
    mov   r11 , [windim+3*8]
    sub   r11 , 44
    int   0x60

  nodrawscroll:

    ret


get_window_dimensions:

    mov   rax , 111
    mov   rbx , 1
    int   0x60
    mov   rcx , rax
    mov   rax , 9
    mov   rbx , 2
    mov   rdx , windim
    mov   r8  , 8*4
    int   0x60

    ret


;
; Data area
;

window_label:

    db    'FTP CLIENT',0  ; Window label

windim:  dq 0,0,0,0,0,0
command: times 256 db 0

status:    dq  0x0
fontsize:  dq  9
cursor:    dq  2
datacount: dq  0
print:     dq  0
netresult: dq  0
dataport:  dq  16*256
dataip:    dq  192+168 shl 8+123 shl 16+123 shl 24

termpid:     dq 0
doenter:     dq 0
str13:       db 13
str10:       db 10
sendstr:     db 0
string_lf:   db 13,10,0
string_8:    db 8,0

string_fail:     db  'Fail.',13,10,0
string_username: db  'Username: ',0
string_password: db  'Password: ',0
string_prompt:   db  '> ',0
string_overflow: db  'Overflow.',13,10,0
string_timeout:  db  'Timeout.',13,10,0

string_connectionopen:    db 'Connection open.',13,10,0
string_connectionclosed:  db 'Connection closed.',13,10,0

socket:      dq 0x0
socket_data: dq 0x0

datalocalport:  dq 0x0
parameters:     dq 0,0,0,0,0,0,0,0
ip:             db 0,0,0,0 ; kept
                db 0,0,0,0 ; together

read_input_delay:  dq  1000
waittext:          dq  0x0
blocksinbuffer:    dq  0x0
readblock:         dq  0x0
lastline:          dq  0x0
lines_to_display:  dq  0x0
line_height:       dq  0x0
line_begin:        dq  0x0
line_length:       dq  0x0
vscroll_value:     dq  (blines+1000-16)

filelocationtext:  db  'Local directory: '
filelocation:      db  '/fd/1/'
                   times 256 db 0
filename:          db '/fd/1/'
                   times 256 db 0

pasvstring:        db 'PASV',13,10
pasvstringend:
command_user:      db 'USER '
command_user_end:
command_pass:      db 'PASS '
command_pass_end:
command_lf:        db 13,10
command_str:       times 128 db 0
command_str_len:   dq 0x0
showtext:          dq 0x0

Param: dq 100
       times 120 db 0

helptext:

    db    13,10
    db    'open [server] - Open connection',13,10
    db    'user [name]   - Send username  ',13,10
    db    'pass [psw]    - Send password  ',13,10
    db    'ls [opt]      - Show directory listing   ',13,10
    db    'bin           - Set transfer mode to Binary',13,10
    db    'get [file]    - Get file       ',13,10
    db    'send [file]   - Send file      ',13,10
    db    'cd [dir]      - Change server directory  ',13,10
    db    'lcd [dir]     - Change local directory   ',13,10
    db    'dele [file]   - Delete file from server  ',13,10
    db    'quit          - Close connection',13,10
    db    'help          - Help            ',13,10
    db    'exit          - Close ftp client  ',13,10
    db    13,10

helptextend:

menu_struct:               ; Menu Struct

    dq   0                 ; Version
    dq   0x100             ; Start value of ID to return ( ID + Line )
    db   0,'FILE',0        ; ID = 0x100 + 1
    db   1,'Quit',0        ; ID = 0x100 + 2
    db   255               ; End of Menu Struct

dataclear:
ipc_memory: times 300 db ?
string_terminal_path: times 200 db ?
string_terminal_len: dq ?
datacleare:

tcpipblock:   times 68000 db ?
blocksize:    dq ?
blockpos:     dq ?

text:

image_end:













































































