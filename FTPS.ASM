;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;    FTP Server for Menuet by Mike Hibbett
;
;    Passive transfer mode, directory select and 
;    login details by V.Turjanmaa
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

macro pusha { push  rax rbx rcx rdx rsi rdi }
macro popa  { pop   rdi rsi rdx rcx rbx rax }

; ftp cmd 21, data on 20

use64

    org   0x0

    db    'MENUET64'              ; Header identifier
    dq    0x01                    ; Version
    dq    START                   ; Start of code
    dq    I_END                   ; Size of image
    dq    0x400000                ; Memory for app
    dq    0x3ffff0                ; Esp
    dq    0x00                    ; Prm 
    dq    0x00                    ; Icon

; Various states of client connection
USER_NONE          equ 0   ; Awaiting a connection
USER_CONNECTED     equ 1   ; User just connected, prompt given
USER_NOUSERNAME    equ 2   ; User gave incorrect username
USER_USERNAME      equ 3   ; User gave username
USER_LOGGED_IN     equ 4   ; User gave password
USER_LOGIN_FAILED  equ 5   ; User login failed

dix  equ  10
diy  equ  134

fileinmax equ (0x3f0000-(text+0x1300+0x4000))

include "textbox.inc"

START:                  ; Start of execution

    mov     rax , 141
    mov     rbx , 1
    mov     rcx , 1
    mov     rdx , 5 shl 32 + 5
    mov     r8  , 9 shl 32 + 12
    int     0x60

    ; Clear the screen memory
    mov     eax, '    '
    mov     edi,text
    mov     ecx,80*30 /4
    cld
    rep     stosd

    ; Clear data
    mov     rdi , buff
    mov     rax , 0
    mov     rcx , I_END-buff
    cld
    rep     stosb

    call    draw_window

    ; Init the receive buffer pointer
    mov     eax, buff
    mov     [buffptr], eax

    ; Init FTP server state machine
    mov     al, USER_NONE
    mov     [state], al

    ; Open the listening socket
    call    connect

still:

    ; Check connection status
    mov     eax,53
    mov     ebx,6               ; Get socket status
    mov     ecx,[CmdSocket]
    int     0x40

    mov     ebx, [CmdSocketStatus]
    mov     [CmdSocketStatus], eax

    cmp     eax, ebx
    je      waitev

    mov     [datastat],dword data_disconnected

    ; If the socket closed by remote host, open it again.
    cmp     eax, 7
    je      con
    ; If socket closed by Reset, open it again
    cmp     eax, 11
    je      con

    ; If a user has just connected, start by outputting welcome msg
    cmp     eax, 4
    jne     noc

    mov     [datastat],dword data_connected

    mov     esi, loginStr0
    mov     edx, loginStr0_end - loginStr0
    call    outputStr

    mov     al, USER_CONNECTED
    mov     [state], al

    jmp     noc

con:
    ; Need to call disconnect, since a remote close does not fully
    ; close the socket
    call    disconnect
    call    connect

    mov     al, USER_NONE
    mov     [state], al

    jmp     noc

noc:
    ; Display the changed connected status

    call    print_data_status

    mov     [timeoutdis],dword 0

waitev:

    mov     eax,23                 ; Wait here for event
    mov     ebx,1                  ; Delay for up to 1s
    int     0x40

    cmp     eax,1                  ; Redraw request
    je      red
    cmp     eax,2                  ; Key in buffer
    je      key
    cmp     eax,3                  ; Button in buffer
    je      button

    ; Any data from the socket?

    mov     eax, 53
    mov     ebx, 2                  ; Get # of bytes in input queue
    mov     ecx, [CmdSocket]
    int     0x40
    cmp     eax, 0
    jne     read_input

    mov     eax , 53
    mov     ebx , 6
    mov     ecx , [CmdSocket]
    int     0x40

    cmp     eax , 4
    jne     notimeout
    inc     dword [timeoutdis]           ; Disconnect after one       
    cmp     [timeoutdis], dword 100*60   ; minute of inactivity
    ja      timeoutdisconnect
  notimeout:

    jmp     still


timeoutdisconnect:

    call    cmdQUIT

    mov     rax , 5
    mov     rbx , 50
    int     0x60

    jmp     con


display_data_count:

    push  rax rbx rcx rdx rsi rdi
    cmp   r15 , 0
    je    notimecheck
    cmp   r15 , [prevdisp]
    je    nonumdisp
    mov   [prevdisp],r15
    sub   rsp , 256
    mov   rax , 26
    mov   rbx , 1
    mov   rcx , rsp
    mov   rdx , 200
    int   0x60
    mov   rax , [rsp+5*8]
    add   rsp , 256
    cmp   rax , [nextdisp]
    jb    nonumdisp
    add   rax , 100
    mov   [nextdisp],rax
  notimecheck:
    mov   rax , 13
    mov   rbx , (dix+58) shl 32 + 6*9
    mov   rcx , 133 shl 32 + 12
    mov   rdx , 0xffffff
    int   0x60
    mov   rcx , r15
    cmp   ecx , 0
    je    nonumdisp
    mov   rax , 47
    mov   rbx , 9*65536
    mov   rdx , (dix+58) shl 32 + 134
    mov   rsi , 0
    int   0x60
  nonumdisp:
    pop   rdi rsi rdx rcx rbx rax

    ret



read_input:

    mov     [timeoutdis],dword 0

    mov     eax, 53
    mov     ebx, 3                  ; Get a byte from socket in bl
    mov     ecx, [CmdSocket]
    int     0x40

    call    ftpRxCmdData            ; Process incoming ftp command

    ; Keep processing data until there is no more to process
    mov     eax, 53
    mov     ebx, 2                  ; Get # of bytes in input queue
    mov     ecx, [CmdSocket]
    int     0x40
    cmp     eax, 0
    jne     read_input

    ; Now redraw the text text field.
    ; Probably not required, since ftp requires no
    ; console i/o.
    ; Leave in for now, for debugging.

    call    draw_text

    cmp     [state],byte USER_LOGIN_FAILED
    je      con

    jmp     still

red:                          ; Redraw window
    call    draw_window
    jmp     still

key:                          ; Key
    mov     eax,2             ; Get but ignore
    int     0x40
    jmp     still

button:

    mov     eax,17
    int     0x40

    cmp     ah , 11
    jne     no_textbox1
    mov     r14 , textbox1
    call    read_textbox
    mov     rax , [textbox1+5*8]
    cmp     rax , 25
    jae     still
    cmp     [textbox1+6*8+rax-1],byte '/'
    je      still
    add     rax ,1
    mov     [textbox1+6*8+rax-1],byte '/'
    mov     [textbox1+5*8],rax
    mov     r14 , textbox1
    call    draw_textbox
    jmp     still
  no_textbox1:

    cmp     ah , 12
    jne     no_textbox2
    mov     r14 , textbox2
    mov     [textbox2+5*8],dword 0
    mov     [textbox2+6*8],dword 0
    call    read_textbox
    mov     rsi , textbox2+5*8
    mov     rdi , string_password
    mov     rcx , 64
    cld
    rep     movsb
    mov     [textbox2+5*8],dword 8
    mov     rax , '********'
    mov     [textbox2+6*8],rax
    mov     rax , 0
    mov     [textbox2+7*8],rax
    mov     r14 , textbox2
    call    draw_textbox
    jmp     still
  no_textbox2:
    cmp     ah , 13
    jne     no_textbox3
    mov     r14 , textbox3
    call    read_textbox
    jmp     still
  no_textbox3:

    cmp     ah,1
    jne     still

    ; Exit button pressed, so close socket and quit
    mov     eax,53
    mov     ebx,8
    mov     ecx,[CmdSocket]
    int     0x40

    ; ... terminate program

    mov     eax,-1
    int     0x40
    jmp     still


draw_window:

    pusha

    mov  eax,12
    mov  ebx,1
    int  0x40

    mov   rax , 141
    mov   rbx , 3
    int   0x60
    and   rax , 0xff
    mov   [fontsize],rax

    mov   rax , 0x0                          ; Draw window
    mov   rbx ,  100*0x100000000+12+80*6
    mov   rcx ,  100*0x100000000+152
    xor   rdx , rdx
    mov   edx , [wcolor]
    mov   r8  , 0x1    
    mov   r9  , window_label          
    mov   r10 , 0 
    int   0x60

    ; Draw status bar

    call  print_data_status

    ; Separator lines

    mov   rax , 38
    mov   rbx , 5
    mov   rcx , 130
    mov   rdx , 5+80*6
    mov   r8  , rcx
    mov   r9  , 0x000000
    int   0x60
    mov   rax , 38
    mov   rbx , 5
    mov   rcx , 146
    mov   rdx , 5+80*6
    mov   r8  , rcx
    mov   r9  , 0x000000
    int   0x60
    mov   rax , 38
    mov   rbx , 5
    mov   rcx , 130
    mov   rdx , rbx
    mov   r8  , 146
    mov   r9  , 0x000000
    int   0x60
    mov   rax , 38
    mov   rbx , 120+6
    mov   rcx , 130
    mov   rdx , rbx
    mov   r8  , 146
    mov   r9  , 0x000000
    int   0x60
    mov   rax , 38
    mov   rbx , 240+6
    mov   rcx , 130
    mov   rdx , rbx
    mov   r8  , 146
    mov   r9  , 0x000000
    int   0x60

    mov   r14 , textbox1
    call  draw_textbox

    mov   r14 , textbox2
    call  draw_textbox

    mov   r14 , textbox3
    call  draw_textbox

    ; Draw the text on the screen, clearing it first
    ; This can go when we loose debuggin info.

    xor  eax,eax
    mov  edi,text+80*30
    mov  ecx,80*30 /4
    cld
    rep  stosd

    call draw_text

    mov  eax,12
    mov  ebx,2
    int  0x40

    popa

    ret



draw_text:

    pusha

    mov  esi,text
    mov  eax,0
    mov  ebx,0
    mov  r15,10

    cmp  [fontsize],dword 10
    jne  nos10
    mov  ebx , 2
    mov  r15 , 9
    mov  esi , text+80*1
  nos10:
    cmp  [fontsize],dword 11
    jne  nos11
    mov  ebx , 5
    mov  r15 , 8
    mov  esi , text+80*2
  nos11:
    cmp  [fontsize],dword 12
    jne  nos12
    mov  ebx , 0
    mov  r15 , 8
    mov  esi , text+80*2
  nos12:

  newletter:

    mov  cl,[esi]
    mov  [esi+30*80],cl

    ; Background

    pusha
    mov     edx, 0xffffff
    mov     ecx, ebx
    add     ecx, 26+2-1
    shl     ecx, 16
    mov     cx, 12
    mov     ebx, eax
    add     ebx, 6
    shl     ebx, 16
    mov     bx, 6
    mov     eax, 13
    int     0x40
    popa

    ; Draw character

    pusha
    mov     ecx, 0x000000  
    push bx
    mov  ebx,eax
    add  ebx,6
    shl  ebx,16
    pop  bx
    add  bx,26+2
    mov  eax,4
    mov  edx,esi
    mov  esi,1
    int  0x40
    popa

  noletter:

    add  esi,1
    add  eax,6
    cmp  eax,80*6
    jb   newletter
    mov  eax,0
    add  ebx,[fontsize]
    inc  ebx
    dec  r15
    cmp  r15,0
    jne  newletter

    popa
    ret



;***************************************************************************
;   Function
;      ftpRxCmdData
;
;   Description
;       Prcoesses incoming command data, calling a handler for each command.
;       Commands are built up in buff before being processed.
;
;   Inputs
;       Character to add in bl
;
;***************************************************************************
ftpRxCmdData:

    ; Quit if we are not connected
    ;( This case shouldn't be necessary, but be safe )
    mov     al, [state]
    cmp     al, USER_NONE
    je      frcd_exit

    ; Store the incoming character
    mov     esi, [buffptr]
    mov     [esi], bl
    inc     esi
    mov     [buffptr], esi

    ; For debugging, show the data coming in
    pusha
    call    printChar
    popa

    ; Do we have an end of line? (LF)
    ; if not, just exit
    cmp     bl, 0x0a
    jne     frcd_exit

    call    draw_text

    ; OK we have a complete command.
    ; Process, and send response
    ; There are a number of states involved in ftp,
    ; to do with logging in.
    ; Login procedure moved to command level
    ; This should be a cmd

    call    findCmd
    mov     eax, dword [cmdPtr]
    cmp     eax, 0
    je      fs002b

    ; Execute quit, user and pass commands without complete login

    cmp     dword [cmdPtr],dword cmdQUIT
    je      docommand
    cmp     dword [cmdPtr],dword cmdUSER
    je      docommand
    cmp     dword [cmdPtr],dword cmdPASS
    je      docommand
    cmp     [state],byte USER_LOGGED_IN
    jne     fs002b
  docommand:

    call    qword [cmdPtr]

  fs002a:
    ; Init the receive buffer pointer
    mov     eax, buff
    mov     [buffptr], eax

    jmp     frcd_exit

  fs002b:
    ; An unsupported command was entered.
    ; Tell user that the command is not supported

    mov     esi, unsupStr
    mov     edx, unsupStr_end - unsupStr
    call    outputStr

    jmp     fs002a

  fs003:
  frcd_exit:
    ret



;***************************************************************************
;   Function
;      outputStr
;
;   Description
;       Sends a string over the 'Command' socket
;
;   Inputs
;       String in esi
;       Length in edx
;
;***************************************************************************
outputStr:

    push    rax rbx
    mov     rax , 5
    mov     rbx , 2
    int     0x60 
    pop     rbx rax

    push    rsi
    push    rdx
    mov     eax,53
    mov     ebx,7
    mov     ecx,[CmdSocket]
    int     0x40
    pop     rdx
    pop     rsi
    
    cmp     eax, 0
    je      os_exit
    
    ; No retry

  os_exit:
    ret


;***************************************************************************
;   Function
;      outputDataStr
;
;   Description
;       Sends a string over the 'Data' socket
;
;   Inputs
;       String in esi
;       Length in edx
;
;***************************************************************************
outputDataStr:

    push    rax rbx rcx rdx rsi rdi r15

    mov     [timeout],byte 0

    mov     r15 , 0

  odsl2:

    ; Get socket status

    mov     eax,53
    mov     ebx,6
    mov     ecx,[DataSocket]
    int     0x40
    cmp     eax , 4
    jne     odsl3

    ; Write to socket

    mov     eax,53
    mov     ebx,17
    mov     ecx,[DataSocket]
    int     0x40
    cmp     rax , 0
    je      ods_exit

    call    check_events

    mov     rax , 105
    mov     rbx , 1
    int     0x60

    add     r15 , 1
    cmp     r15 , 20*1000
    jb      odsl2

  odsl3:

    mov     [timeout],byte 1

  ods_exit:

    pop     r15 rdi rsi rdx rcx rbx rax

    ret



check_events:

    push    rax rbx rcx rdx r8 r9 r10 r11 r12 r13 r14 r15 rsi rdi rbp

    mov     rax , 11
    int     0x60
    test    rax , 1
    jz      cel1
    call    draw_window
  cel1:

    pop     rbp rdi rsi r15 r14 r13 r12 r11 r10 r9 r8 rdx rcx rbx rax

    ret


;***************************************************************************
;   Function
;      printChar
;
;   Description
;       Writes a character to the screen; Used to display the data coming
;       in from the user. Really only useful for debugging.
;
;   Inputs
;       Character in bl
;
;***************************************************************************
printChar:

    ; Beginning of line

    cmp     bl,13                          
    jne     nobol
    mov     ecx,[pos]
    add     ecx,1
  boll1:
    sub     ecx,1
    mov     eax,ecx
    xor     edx,edx
    mov     ebx,80
    div     ebx
    cmp     edx,0
    jne     boll1
    mov     [pos],ecx
    jmp     newdata
  nobol:

    ; Line down

    cmp     bl,10                            
    jne     nolf
  addx1:
    add     [pos],dword 1
    mov     eax,[pos]
    xor     edx,edx
    mov     ecx,80
    div     ecx
    cmp     edx,0
    jnz     addx1
    mov     eax,[pos]
    jmp     cm1
  nolf:

    ; Backspace

    cmp     bl,8                            
    jne     nobasp
    mov     eax,[pos]
    dec     eax
    mov     [pos],eax
    mov     [eax+text],byte 32
    mov     [eax+text+60*80],byte 0
    jmp     newdata
  nobasp:

    ; Character

    cmp     bl,15                           
    jbe     newdata
  putcha:
    mov     eax,[pos]
    mov     [eax+text],bl
    mov     eax,[pos]
    add     eax,1
  cm1:
    mov     ebx,[scroll+4]
    imul    ebx,80
    cmp     eax,ebx
    jb      noeaxz
    mov     esi,text+80
    mov     edi,text
    mov     ecx,ebx
    cld
    rep     movsb
    mov     eax,ebx
    sub     eax,80
  noeaxz:
    mov     [pos],eax
  newdata:
    ret


;***************************************************************************
;   Function
;      disconnect
;
;   Description
;       Closes the command socket
;
;   Inputs
;       None
;
;***************************************************************************
disconnect:
    mov     eax, 53         ; Stack Interface
    mov     ebx,8           ; Close TCP socket
    mov     ecx,[CmdSocket]
    int     0x40
    ret
    


;***************************************************************************
;   Function
;      disconnectData
;
;   Description
;       Closes the data socket
;
;   Inputs
;       None
;
;***************************************************************************
disconnectData:
    ; This delay would be better done by allowing the socket code
    ; to wait for all data to pass through the stack before closing
    pusha
    mov     eax,5
    mov     ebx,200         ; Delay for 2s
    int     0x40
    popa

    mov     eax, 53         ; Stack Interface
    mov     ebx,8           ; Close TCP socket
    mov     ecx,[DataSocket]
    int     0x40

    ; Clear status

    mov     [datastat],dword data_connected
    call    print_data_status

    ret


print_data_status:

    mov   rax , 13
    mov   rbx , dix shl 32 + 19*6
    mov   rcx , (diy-1) shl 32 + 12
    mov   rdx , 0xffffff
    int   0x60

    mov   rax , 4
    mov   rbx , [datastat]
    mov   rcx , dix
    mov   rdx , diy
    mov   r9  , 1
    mov   rsi , 0x000000
    int   0x60

    ret



;***************************************************************************
;   Function
;      connect
;
;   Description
;       Opens the command socket
;
;   Inputs
;       None
;
;***************************************************************************
connect:
    pusha

    mov     eax, 53     ; Stack Interface
    mov     ebx, 5      ; Open TCP socket
    mov     esi, 0      ; No remote IP address
    mov     edx, 0      ; No remote port
    mov     ecx, 21     ; ftp command port id
    mov     edi, 0      ; passive open
    int     0x40
    mov     [CmdSocket], eax

    ; Default to active data mode

    mov     [passivemode],byte 0

    popa

    ret



;***************************************************************************
;   Function
;      connectData
;
;   Description
;       Opens the data socket
;
;   Inputs
;       None
;
;***************************************************************************
connectData:

    pusha

    cmp     [passivemode],byte 1
    je      passiveopen

    mov     eax, 53          ; Stack Interface
    mov     ebx, 5           ; Open TCP socket
    mov     esi, [DataIP]    ; remote IP address
    mov     edx, [DataPort]  ; remote port
    mov     ecx, 20          ; ftp data port id
    mov     edi, 1           ; active open
    int     0x40
    mov     [DataSocket], eax

    jmp     dataopendone

  passiveopen:

    mov     eax, 53              ; Stack Interface
    mov     ebx, 5               ; Open TCP socket
    mov     ecx, [localdataport] ; ftp data port id
    mov     edx, 0               ; remote port
    mov     esi, 0               ; remote IP address
    mov     edi, 0               ; passive open
    int     0x40
    mov     [DataSocket], eax

  dataopendone:

    popa

    ret



;***************************************************************************
;   Function
;      findCmd
;
;   Description
;       Scans the command string for a valid command. The command string
;       is in the global variable buff.
;
;       Returns result in cmdPtr. This will be zero if none found
;
;   Inputs
;       None
;
;***************************************************************************
findCmd:
    ; Setup to return 'none' in cmdPtr, if we find no cmd
    mov     eax, 0
    mov     dword [cmdPtr], eax
    cld
    mov     esi, buff
    mov     edi, CMDList

  fc000:
    cmp     [edi], byte 0   ; Are we at the end of the CMDList?
    je      fc_exit

  fc000a:
    cmpsb

    je      fc_nextbyte

    ; Command is different - move to the next entry in cmd table
    mov     esi, buff

  fc001:
    ; Skip to the next command in the list
    cmp     [edi], byte 0
    je      fc002
    inc     edi
    jmp     fc001
  fc002:
    add     edi, 5
    jmp     fc000

  fc_nextbyte:
    ; Have we reached the end of the CMD text?
    cmp     [edi], byte 0
    je      fc_got      ; Yes - so we have a match
    jmp     fc000a      ; No - loop back

  fc_got:
    ; Copy the function pointer for the selected command
    inc     edi
    mov     eax, [edi]
    mov     dword [cmdPtr], eax

  fc_exit:
    ret



;***************************************************************************
;   Function
;      decStr2Byte
;
;   Description
;       Converts the decimal string pointed to by esi to a byte
;
;   Inputs
;       string ptr in esi
;
;   Outputs
;       esi points to next character not in string
;       eax holds result ( 0..255)
;
;***************************************************************************
decStr2Byte:
    xor     eax, eax
    xor     ebx, ebx
    mov     ecx, 3

  dsb001:
    mov     bl, [esi]

    cmp     bl, '0'
    jb      dsb_exit
    cmp     bl, '9'
    ja      dsb_exit

    imul    eax, 10
    add     eax, ebx
    sub     eax, '0'
    inc     esi
    loop    dsb001

  dsb_exit:
    ret



;***************************************************************************
;   Function
;      parsePortStr
;
;   Description
;       Converts the parameters of the PORT command, and stores them in the
;       appropriate variables.
;
;   Inputs
;       None ( string in global variable buff )
;
;   Outputs
;       None
;
;***************************************************************************
parsePortStr:
    ; skip past the PORT text to get the the parameters. The command format
    ; is
    ; PORT i,i,i,i,p,p,0x0d,0x0a
    ; where i and p are decimal byte values, high byte first.
    xor     eax, eax
    mov     [DataIP], eax
    mov     [DataPort], eax
    mov     esi, buff + 4       ; Start at first space character

  pps001:
    cmp     [esi], byte ' '     ; Look for first non space character
    jne     pps002
    inc     esi
    jmp     pps001

  pps002:
    call    decStr2Byte
    add     [DataIP], eax
    ror     dword [DataIP], 8
    inc     esi
    call    decStr2Byte
    add     [DataIP], eax
    ror     dword [DataIP], 8
    inc     esi
    call    decStr2Byte
    add     [DataIP], eax
    ror     dword [DataIP], 8
    inc     esi
    call    decStr2Byte
    add     [DataIP], eax
    ror     dword [DataIP], 8
    inc     esi
    call    decStr2Byte
    add     [DataPort], eax
    shl     [DataPort], 8
    inc     esi
    call    decStr2Byte
    add     [DataPort], eax

    ret



;***************************************************************************
;   Function
;      sendDir
;
;   Description
;       Transmits the directory listing over the data connection.
;       The data connection is already open.
;
;   Inputs
;       None 
;
;   Outputs
;       None
;
;***************************************************************************
sendDir:

    mov   [timeout],dword 0

    ; Path

    mov   rsi , textbox1+6*8
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

    mov   [fsize],dword 0

  nextdriver:

    mov   rdi , fileret
    mov   rcx , 128
    mov   rax , 0
    cld
    rep   stosb

    mov   rax , 58
    mov   rbx , 3
    mov   rcx , r15
    mov   rdx , 1
    mov   r8  , fileret
    mov   r9  , pathread
    int   0x60

    cmp   rax , 0
    jne   driversread

    test  [fileret+8+256+8+8+8],byte 00011000b
    jnz   nodirectorylabel

    push  rax rbx rcx rdx r8 r9 r10 r11 r12 r13 r14 r15 rsi rdi rbp
    mov   rdi , string_fileinfo
    mov   rax , 32
    mov   rcx , 80
    cld
    rep   stosb
    ;
    mov   rax , '00-00-00'
    mov   [string_fileinfo],rax
    mov   al  , [fileret+8+256+8]
    and   rax  , 63
    mov   rdi , string_fileinfo+1
    call  setnum
    mov   al  , [fileret+8+256+9]
    and   rax  , 63
    mov   rdi , string_fileinfo+4
    call  setnum
    mov   ax  , [fileret+8+256+10]
    and   rax  , 4095
    mov   rdi , string_fileinfo+9
    call  setnum
    ;
    mov   rax , '00:00.00'
    mov   [string_fileinfo+12],rax
    mov   al  , [fileret+8+256+8+8+2]
    and   rax  , 63
    mov   rdi , string_fileinfo+13
    call  setnum
    mov   al  , [fileret+8+256+8+8+1]
    and   rax  , 63
    mov   rdi , string_fileinfo+16
    call  setnum
    mov   al  , [fileret+8+256+8+8+0]
    and   rax  , 63
    mov   rdi , string_fileinfo+19
    call  setnum
    ;
    mov   rax , [fileret+8+256]
    mov   rdi , string_fileinfo+37
    call  setnum
    ;
    mov   rdx , string_fileinfo+40
    mov   rax , fileret+8
  findlen:
    mov   bl , [rax]
    cmp   bl , 32
    jbe   lenfound
    mov   [rdx],bl
    add   rdx, 1
    add   rax, 1
    jmp   findlen
  lenfound:
    mov   [rdx],word 0x0A0D
    add   rdx , 2
    mov   rsi , string_fileinfo
    sub   rdx , string_fileinfo
    call  outputDataStr
    pop   rbp rdi rsi r15 r14 r13 r12 r11 r10 r9 r8 rdx rcx rbx rax  

    add   [fsize],dword 20
    push  r15
    mov   r15d, [fsize]
    call  display_data_count
    pop   r15

    cmp   [timeout],byte 1
    je    driversread

  nodirectorylabel:

    add   r15 , 1
    jmp   nextdriver

  driversread:

    push  r15
    mov   [prevdisp],dword 999999999
    mov   [nextdisp],dword 0
    mov   r15d, [fsize]
    call  display_data_count
    pop   r15

    mov   esi, lf
    mov   edx , 2
    call  outputDataStr

    ret



setnum:

  newnum:
    mov   rbx , 10
    xor   rdx , rdx
    div   rbx
    add   dl , 48
    mov   [rdi],dl
    sub   rdi , 1
    cmp   rax , 0
    jne   newnum

    ret


;***************************************************************************
;   Function
;      setupFilePath
;
;   Description
;       Copies the file name from the input request string into the
;       file descriptor
;
;   Inputs
;       None 
;
;   Outputs
;       None
;
;***************************************************************************
setupFilePath:
    mov     esi, buff + 4       ; Point to (1 before) first character of file
    
    ; Skip any trailing spaces or / character
  sfp001:    
    inc     esi
    cmp     [esi], byte ' '
    je      sfp001
    cmp     [esi], byte '/'
    je      sfp001
    
    ; esi points to start of filename.
    
    ; Copy across the directory path '/'
    ; into the fileinfoblock
    mov     edi , fname
    mov     eax , tbs1
  newdircopy:
    cmp     [eax],byte 13
    jbe     dircopied
    mov     bl , [eax]
    mov     [edi],bl
    add     eax , 1
    add     edi , 1
    jmp     newdircopy
  dircopied:
    mov     [edi],dword 0
    
    ; Copy across the filename
  sfp002:
    cld
    movsb
    cmp     [esi], byte 0x0d
    jne     sfp002
    mov     [edi], byte 0        
    ret




;***************************************************************************
;   Function
;      sendFile
;
;   Description
;       Transmits the requested file over the open data socket
;       The file to send is named in the buff string
;
;   Inputs
;       None 
;
;   Outputs
;       None
;
;***************************************************************************
sendFile:
    call    setupFilePath
    
    ; Init fileblock descriptor, for file read
    xor     eax, eax
    mov     [readblock], eax
    mov     [fileinfoblock], eax ; read cmd
    mov     [fileinfoblock+4], eax ; first block

    ; Now read the file..    
    mov     eax,58
    mov     ebx,fileinfoblock
    int     0x40

    ; Copy across the filesize..
    mov     [fsize], ebx    
    mov     [fsizesave],ebx

    mov     [blocksinbuffer],dword 1

  sf002a:
    mov     edx, 512        ; Assume we are sending a sector
    ; Do we have less than 512 bytes to send?
    cmp     [fsize], dword 512
    ja      sf003
    mov     edx, [fsize]    ; Adjust the amount of data to send
    
  sf003:

    sub     [fsize], edx

    mov     r15d, [fsizesave]
    sub     r15d, [fsize]
    call    display_data_count

    ; Send the block
    mov     esi, text + 0x1300 + 0x4000
    call    outputDataStr

    cmp     [timeout],byte 1
    je      sf_exit
    
    ; Any more to send?
    cmp     [fsize], dword 0
    je      sf_exit
    
    ; Read a bit more of the file
    inc     dword [readblock]  
    mov     eax,[readblock]

    cmp     eax,[blocksinbuffer]
    jb      noreadblock

    mov     [fileinfoblock+4],eax

    push    qword [fileinfoblock+8]
    mov     [fileinfoblock+8],dword (65536/512)
    mov     eax,58
    mov     ebx,fileinfoblock
    int     0x40
    pop     qword [fileinfoblock+8]

    add     [blocksinbuffer],dword (65536/512)
    
    jmp     sf002a

  noreadblock:

    push    rcx rsi rdi
    mov     rdi , text+0x1300+0x4000
    mov     rsi , rdi
    add     rsi , 512
    mov     rcx , 65536+1024
    cld
    rep     movsb
    pop     rdi rsi rcx
                       
    jmp     sf002a
    
  sf_exit:   

    mov     [prevdisp],dword 999999999
    mov     [nextdisp],dword 0
    mov     r15d, [fsizesave]
    sub     r15d, [fsize]
    call    display_data_count

    ret

    

;***************************************************************************
;   Function
;      getFile
;
;   Description
;       Receives the specified file over the open data socket
;       The file to receive is named in the buff string
;
;   Inputs
;       None 
;
;   Outputs
;       None
;
;***************************************************************************
getFile:
    call    setupFilePath
    
    ; init fileblock descriptor, for file write
    xor     eax, eax
    mov     [fsize], eax            ; Start filelength at 0
    mov     [fileinfoblock+4], eax  ; set to 0
    inc     eax
    mov     [fileinfoblock], eax    ; write cmd
    
    ; Read data from the socket until the socket closes
    ; loop
    ;   loop
    ;     read byte from socket
    ;     write byte to file buffer
    ;   until no more bytes in socket
    ; until socket no longer connected
    ; write file to ram

    mov     [timeoutconnection],dword 0

  gf_001:

    call    read_data

    mov     r15d, [fsize]
    call    display_data_count

    cmp     [fsize],dword fileinmax
    jae     filereadoverflow

    cmp     [timeoutconnection],dword 2*60*1000 ; ms
    ja      toread

    ; Check to see if socket closed...
    mov     eax,53
    mov     ebx,6               ; Get socket status
    mov     ecx,[DataSocket]
    int     0x40

    cmp     eax, 4
    jbe     gf_001               ; still open, so just sleep a bit

  toread:

    mov     eax , 5              ; Wait for rest of the packets
    mov     ebx , 50
    int     0x40

    call    read_data            ; Read rest of the packets

    cmp     [fsize],dword fileinmax
    jae     filereadoverflow

    mov     [prevdisp],dword 999999999
    mov     [nextdisp],dword 0
    mov     r15d, [fsize]
    call    display_data_count

    ; Delete the file first
    mov     eax, 2
    mov     [fileinfoblock], eax
    mov     eax,58
    mov     ebx,fileinfoblock
    int     0x40

    ; Write the file
    mov     eax, 1
    mov     [fileinfoblock], eax    ; write cmd
    mov     eax, [fsize]
    mov     [fileinfoblock+8], eax
    mov     eax,58
    mov     ebx,fileinfoblock
    int     0x40

  filereadoverflow:

    ret


read_data:

    cmp     [blocksize],dword 0
    jne     cgetbyte

    call    check_events

    mov     eax, 53
    mov     ebx, 2                  ; Get # of bytes in input queue
    mov     ecx, [DataSocket]
    int     0x40
    cmp     eax, 0
    je      gf_sleep

  cgetbyte:

    call    read_data_block
    
    mov     esi, text + 0x1300 + 0x4000
    add     esi, dword [fsize]
    mov     [esi], bl
    inc     dword [fsize]

    cmp     [fsize],dword fileinmax
    jae     gf_sleep
    
    jmp     read_data

  gf_sleep:

    mov     rax , 105
    mov     rbx , 1
    int     0x60

    inc     qword [timeoutconnection] ; ms

    ret


read_data_block:

    cmp   [blocksize],dword 0
    jne   getblockbyte

    push  rdx
    mov   rax , 53
    mov   rbx , 13
    mov   ecx , [DataSocket]
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


    



;***************************************************************************
;   COMMAND HANDLERS FOLLOW
;
;   These handlers implement the functionality of each supported FTP Command
;
;***************************************************************************

cmdPWD:
    ; OK, show the directory name text
    mov     esi, ramdir
    mov     edx, ramdir_end - ramdir
    call    outputStr

    ; TODO give real directory

    ret

cmdCWD:
    ; Only / is valid for the ramdisk
    cmp     [buff+5], byte 0x0d
    jne     ccwd_000
    
    ; OK, show the directory name text
    mov     esi, chdir
    mov     edx, chdir_end - chdir
    jmp     ccwd_001
    
ccwd_000:
    ; Tell user there is no such directory
    mov     esi, noFileStr
    mov     edx, noFileStr_end - noFileStr

ccwd_001:
    call    outputStr

    ret

cmdQUIT:
    ; The remote end will do the close; We just
    ; say goodbye.
    mov     esi, byeStr
    mov     edx, byeStr_end - byeStr
    call    outputStr
    ret

decodenumber:

    push  rax rbx rcx rdx

    and   rax , 0xff

    mov   rbx , 10
    xor   rdx , rdx
    div   rbx
    add   rdx , 48
    mov   [rdi],dl
    xor   rdx , rdx
    div   rbx
    add   rdx , 48
    mov   [rdi-1],dl
    add   rax , 48
    mov   [rdi-2],al

    pop   rdx rcx rbx rax

    ret

    ;cmdFEAT:
    ;; Send server features
    ;mov     esi, featStr
    ;mov     edx, featStr_end - featStr
    ;call    outputStr
    ;ret

cmdUSER:

    mov     al, USER_NOUSERNAME
    mov     [state], al
    mov     rsi , textbox3+6*8
    mov     rdi , buff+5
  cmdnewtest:
    mov     al  , [rsi]
    mov     bl  , [rdi]
    cmp     al  , 32
    ja      noendtest
    cmp     bl  , 32
    ja      noendtest
    jmp     setuser
  noendtest:
    cmp     al  , bl
    jne     cmdnouser
    add     rsi , 1
    add     rdi , 1
    jmp     cmdnewtest
  setuser:
    mov     al, USER_USERNAME
    mov     [state], al
  cmdnouser:

    mov     esi, loginStr1
    mov     edx, loginStr1_end - loginStr1
    call    outputStr

    ret

cmdPASS:

    cmp     byte [state],byte USER_USERNAME
    jne     cmdpassfail

    mov     rsi , string_password+8
    mov     rdi , buff+5
  cmdnewtest2:
    mov     al  , [rsi]
    mov     bl  , [rdi]
    cmp     al  , 32
    ja      noendtest2
    cmp     bl  , 32
    ja      noendtest2
    jmp     setuser2
  noendtest2:
    cmp     al  , bl
    jne     cmdpassfail
    add     rsi , 1
    add     rdi , 1
    jmp     cmdnewtest2
  setuser2:

    mov     esi, loginStr2
    mov     edx, loginStr2_end - loginStr2
    call    outputStr

    mov     al, USER_LOGGED_IN
    mov     [state], al

    ret

  cmdpassfail:

    mov     esi, loginfail
    mov     edx, loginfail_end - loginfail
    call    outputStr

    mov     al, USER_LOGIN_FAILED
    mov     [state], al

    ret


cmdPASV:

    push  rax rbx rcx rdx rsi rdi

    mov   [passivemode],byte 1
    inc   dword [localdataport]

    ; Open data socket

    call  connectData

    mov   rax , [localdataport]
    and   rax , 0xff
    mov   rdi , localipport+23
    call  decodenumber
    mov   rax , [localdataport]
    shr   rax , 8
    mov   rdi , localipport+19
    call  decodenumber

    mov   rax , 52
    mov   rbx , 1
    int   0x60
    mov   rdi , localipport+03
    call  decodenumber
    shr   rax , 8
    add   rdi , 4
    call  decodenumber
    shr   rax , 8
    add   rdi , 4
    call  decodenumber
    shr   rax , 8
    add   rdi , 4
    call  decodenumber

    ; Send the local port information

    mov   esi, localportStr
    mov   edx, localportStr_end - localportStr
    call  outputStr

    pop   rdi rsi rdx rcx rbx rax

    ret

cmdABOR:

    ; Close port
    call    disconnectData

    mov     esi, abortStr
    mov     edx, abortStr_end - abortStr
    call    outputStr

    ret

cmdPORT:
    ; TODO
    ; Copy the IP and port values to DataIP and DataPort

    call    parsePortStr

    ; Active data mode
    mov     [passivemode],byte 0

    ; Indicate the command was accepted
    mov     esi, cmdOKStr
    mov     edx, cmdOKStr_end - cmdOKStr
    call    outputStr
    ret

cmdnoop:
    ; Indicate the command was accepted
    mov     esi, cmdOKStr
    mov     edx, cmdOKStr_end - cmdOKStr
    call    outputStr
    ret

cmdTYPE:
    ; TODO
    ; Note the type field selected - reject if needed.

    ; Indicate the command was accepted
    mov     esi, cmdOKStr
    mov     edx, cmdOKStr_end - cmdOKStr
    call    outputStr
    ret

cmdsyst:
    ; Indicate the system type
    mov     esi, systStr
    mov     edx, systStr_end - systStr
    call    outputStr
    ret

cmdDELE:
    mov     esi, buff + 4 ; Point to (1 before) first character of file
    mov     edi, fname
    
    ; Skip any trailing spaces or / character
cdd001:    
    inc     esi
    cmp     [esi], byte ' '
    je      cdd001
    cmp     [esi], byte '/'
    je      cdd001

cdd002:
    cld
    movsb
    cmp     [esi], byte 0x0d
    jne     cdd002
    mov     [edi], byte 0        

    ;mov     ebx, fname  ; dele disabled
    ;mov     eax, 32
    ;int     0x40
    
    cmp     eax, 0
    jne     cmdDele_err

    mov     esi, delokStr
    mov     edx, delokStr_end - delokStr
    call    outputStr
    
    jmp     cmdDele_exit
       
cmdDele_err:    
    mov     esi, noFileStr
    mov     edx, noFileStr_end - noFileStr
    call    outputStr
    
cmdDele_exit:
    ret

cmdNLST:
cmdLIST:
    ; Indicate the command was accepted
    mov     esi, startStr
    mov     edx, startStr_end - startStr
    call    outputStr

    ; Connect for active data transfer

    cmp     [passivemode],byte 0
    jne     noactivedata
    call    connectData
  noactivedata:

    mov     [datastat], dword data_sending_list
    call    print_data_status

    ; Wait for socket to establish

    mov     r8 , 0

  cl001:
    ; Wait a bit
    mov     eax,5
    mov     ebx,1                 ; Delay for up 100ms
    int     0x40

    inc     r8
    cmp     r8 , 500
    ja      connectfail

    ; Check connection status
    mov     eax,53
    mov     ebx,6               ; Get socket status
    mov     ecx,[DataSocket]
    int     0x40

    cmp     eax, 4
    jne     cl001

    ; Send directory listing
    call    sendDir

  connectfail:
   
    ; Close port
    call    disconnectData

    mov     esi, endStr
    mov     edx, endStr_end - endStr
    call    outputStr
    ret

cmdRETR:
    ; Indicate the command was accepted
    mov     esi, startStr
    mov     edx, startStr_end - startStr
    call    outputStr

    ; Connect for active data transfer

    cmp     [passivemode],byte 0
    jne     noactivedata2
    call    connectData
  noactivedata2:

    mov     [datastat],dword data_sending
    call    print_data_status

    ; Wait for socket to establish

    mov     r8 , 0

  cr001:
    ; Wait a bit
    mov     eax,5
    mov     ebx,1                 ; Delay for up 100ms
    int     0x40

    inc     r8
    cmp     r8 , 500
    ja      connectfail2

    ; Check connection status
    mov     eax,53
    mov     ebx,6               ; Get socket status
    mov     ecx,[DataSocket]
    int     0x40

    cmp     eax, 4
    jne     cr001

    ; Send data to remote user
    call    sendFile
   
  connectfail2:

    mov   rax , 5
    mov   rbx , 100
    int   0x60

    ; Close port
    call    disconnectData

    mov     esi, endStr
    mov     edx, endStr_end - endStr
    call    outputStr

    ret

cmdSTOR:
    ; Indicate the command was accepted
    mov     esi, storStr
    mov     edx, storStr_end - storStr
    call    outputStr

    ; Connect for active data transfer

    cmp     [passivemode],byte 0
    jne     noactivedata3
    call    connectData
  noactivedata3:

    mov     [datastat],dword data_receiving
    call    print_data_status

    ; Wait for socket to establish

    mov     r8 , 0

  cs001:
    ; Wait a bit
    mov     eax,5
    mov     ebx,1                 ; Delay for up 100ms
    int     0x40

    inc     r8
    cmp     r8 , 500
    ja      connectfail3

    ; Check connection status
    mov     eax,53
    mov     ebx,6               ; Get socket status
    mov     ecx,[DataSocket]
    int     0x40

    cmp     eax, 4
    jne     cs001

    ; Get data file from remote user
    call    getFile

    cmp     [fsize],dword fileinmax
    jb      filereadfine

    mov     esi, fileabortStr
    mov     edx, fileabortStr_end - fileabortStr
    call    outputStr

    mov     rsi , dataabort
  newmessage:
    push    rsi
    mov     bl , [rsi]
    call    printChar
    pop     rsi
    add     rsi , 1
    cmp     [rsi],byte 0
    jne     newmessage

    jmp     connectfail3

  dataabort: db 'Abort, max 0x380000 bytes.',13,10,0

  filereadfine:
   
    mov     esi, endStr
    mov     edx, endStr_end - endStr
    call    outputStr

  connectfail3:

    ; Close port
    call    disconnectData

    ret


;
; Data area
;

data_receiving:     db  'Receiving',0
data_sending:       db  'Sending',0
data_sending_list:  db  'Sending',0
data_disconnected:  db  'Disconnected',0
data_connected:     db  'Connected',0
datastat:           dq  data_disconnected

nextdisp:  dq  0x0
prevdisp:  dq  0x0

blocksinbuffer: dq 0x0

; This is the list of supported commands, and the function to call
; The list end with a NULL.
CMDList:
                    db  'pwd',0
                    dd  cmdPWD

                    db  'PWD',0
                    dd  cmdPWD

                    db  'XPWD',0
                    dd  cmdPWD

                    db  'xpwd',0
                    dd  cmdPWD

                    db  'QUIT',0
                    dd  cmdQUIT

                    db  'quit',0
                    dd  cmdQUIT

                    db  'PORT',0
                    dd  cmdPORT

                    db  'port',0
                    dd  cmdPORT

                    db  'LIST',0
                    dd  cmdLIST

                    db  'list',0
                    dd  cmdLIST

                    db  'NLST',0
                    dd  cmdNLST

                    db  'nlst',0
                    dd  cmdNLST

                    db  'TYPE',0
                    dd  cmdTYPE

                    db  'type',0
                    dd  cmdTYPE

                    db  'syst',0
                    dd  cmdsyst

                    db  'noop',0
                    dd  cmdnoop

                    db  'CWD',0
                    dd  cmdCWD

                    db  'cwd',0
                    dd  cmdCWD

                    db  'RETR',0
                    dd  cmdRETR

                    db  'retr',0
                    dd  cmdRETR

                    db  'DELE',0
                    dd  cmdDELE

                    db  'dele',0
                    dd  cmdDELE

                    db  'stor',0
                    dd  cmdSTOR

                    db  'STOR',0
                    dd  cmdSTOR

                    db  'PASV',0
                    dd  cmdPASV
                    db  'pasv',0
                    dd  cmdPASV

                  ;  db  'FEAT',0
                  ;  dd  cmdFEAT
                  ;  db  'feat',0
                  ;  dd  cmdFEAT

                    db  'USER',0
                    dd  cmdUSER
                    db  'user',0
                    dd  cmdUSER

                    db  'PASS',0
                    dd  cmdPASS
                    db  'pass',0
                    dd  cmdPASS

                    db  'ABOR',0
                    dd  cmdABOR

                    db  'abor',0
                    dd  cmdABOR

                    db  0xff,0xf4,0xff,0xf2,'ABOR',0
                    dd  cmdABOR

                    db  0


localdataport:  dq  16*256
timeout:        dq  0x0
fontsize:       dq  0x0
timeoutdis:     dq  0x0
passivemode:    dq  0x0

timeoutconnection:  dq  0x0

cmdPtr              dq  0
CmdSocket           dd  0x0
CmdSocketStatus     dd  0x0
DataSocket          dd  0x0
DataSocketStatus    dd  0x0
DataPort            dd  0x00
DataIP              dd  0x00
pos                 dd  80 * 9 
scroll              dd  1
                    dd  11
wcolor              dd  0xffffff

window_label:
                    db  'FTP SERVER',0       

contt               db  'Connected'
contlen:
discontt            db  'Disconnected'                    
discontlen:

cmdOKStr:           db  '200 Command OK',0x0d,0x0a
cmdOKStr_end:

loginStr0:          db  '220- ',13,10
                    db  '      Menuet FTP server v0.4',13,10
                    db  '      Username and Password required',13,10
                    db  '      Disconnected after one minute of inactivity',13,10
                    db  '220    ',13,10
loginStr0_end:

loginStr1:          db  '331 Password now required',0x0d,0x0a
loginStr1_end:

loginStr2:          db  '230 You are now logged in.',0x0d,0x0a
loginStr2_end:

byeStr:             db  '221 Bye bye.',0x0d,0x0a                          
byeStr_end:

loginfail:          db  '221 Incorrect login, bye.',0x0d,0x0a
loginfail_end:

systStr:            db  '215 UNIX system type',0x0d,0x0a
systStr_end:

ramdir:             db  '257 "/"',0x0d,0x0a
ramdir_end:

featStr:            db  '211- Features',13,10
                    db  ' PASV',13,10
                    db  '211 End',13,10
featStr_end:

chdir:              db  '200 directory changed to /',0x0d,0x0a
chdir_end:

unsupStr:           db  '500 Unsupported command',0x0d,0x0a
unsupStr_end:

noFileStr:          db  '550 No such file',0x0d,0x0a
noFileStr_end:

delokStr:           db  '500 DELE command disabled  ',0x0d,0x0a
delokStr_end:

startStr:           db  '150 Sending data',0x0d,0x0a                 
startStr_end:

storStr:            db  '150 Connecting for STOR',0x0d,0x0a
storStr_end:

endStr:             db  '226 Transfer OK, Closing connection',0x0d,0x0a
endStr_end:

fileabortStr:       db  '552 Abort, max 0x380000 bytes.',0x0d,0x0a
fileabortStr_end:

abortStr:           db  '225 Abort successful',0x0d,0x0a
abortStr_end:

localportStr:       db  '227 Entering Passive Mode '
localipport:        db  '(000,000,000,000,000,000)',0x0d,0x0a
localportStr_end:

listening:          db 'Listening port 21'  
listeningend:

textbox1:

    dq    0x40000   ; Type0
                    ; bit 16 - clear at doubleclick
                    ; bit 17 - set edit position according to mouse
                    ; bit 18 - enable utf8 (max 4 byte/char)
    dq    6+360     ; X position
    dq    120       ; X size
    dq    130       ; Y position
    dq    11        ; Button ID
    dq    tbe1-tbs1 ; Current text length
  tbs1:
    db    '/fd/1/'  ; text
  tbe1:
    times 96 db 0   ; 

textbox2:

    dq    0x40000   ; Type0
                    ; bit 16 - clear at doubleclick
                    ; bit 17 - set edit position according to mouse
                    ; bit 18 - enable utf8 (max 4 byte/char)
    dq    6+240     ; X position
    dq    120       ; X size
    dq    130       ; Y position
    dq    12        ; Button ID
    dq    tbe2-tbs2 ; Current text length
  tbs2:
    db    '********'; text
  tbe2:
    times 96 db 0   ;

textbox3:

    dq    0x40000   ; Type0
                    ; bit 16 - clear at doubleclick
                    ; bit 17 - set edit position according to mouse
                    ; bit 18 - enable utf8 (max 4 byte/char)
    dq    6+120     ; X position
    dq    120       ; X size
    dq    130       ; Y position
    dq    13        ; Button ID
    dq    tbe3-tbs3 ; Current text length
  tbs3:
    db    'username'; text
  tbe3:
    times 96 db 0   ;


lf: db 13,10

pathread:        times 13*20 db 0
fileret:         times 512 db 0
string_fileinfo: times 100 db 0

string_password: dq  0
                 db  'password'
                 times 128 db 0

 ; This is the buffer used for building up a directory listing line
dirStr:             times 128 db 0

; These are template strings used in building up a directory listing line
tmplStr:            db 'rw-rw-rw-    1 0        0                ',0
timeStr:            db ' Jan 1    2000 ',0


; The following lines define data for reading a directory block
readblock:          dd      0

fileinfoblock:
                    dd      0x00
                    dd      0x00
                    dd      0x01
                    dd      text + 0x1300 + 0x4000   ; data area
                    dd      text + 0x1300            ; work area

fname:              db      '/FD/1/',0

                    times 256 db 0

fsize:              dd      0
fsizesave:          dq      0
                    
; The 'filename' for a directory listing
; dirpath:            db      '/FD/1',0 

state:              dq  0
buffptr:            dq  0
buff:               times 256 db ?  ; Could put this after iend

tcpipblock:         times 68000 db ?
blocksize:          dq ?
blockpos:           dq ?


; Ram use at the end of the application:
; text                  : 2400 bytes for screen memory
; text + 0x1300          : 16KB work area for file access
; text + 0x1300 + 0x4000 : file data area

text:


I_END:































