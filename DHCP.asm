;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;    DHCP Client for Menuet
;
;    32bit version by Mike Hibbett
;
;    64bit conversion by Ville Turjanmaa
;
;    Compile with FASM for Menuet
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

use64

    org   0x0

    db    'MENUET64'              ; Header identifier
    dq    0x01                    ; Version
    dq    START                   ; Start of code
    dq    I_END                   ; Size of image
    dq    0x200000                ; Memory for app
    dq    0x1ffff0                ; Rsp
    dq    0x00                    ; Prm 
    dq    0x00                    ; Icon

START:                                   

    ; System font

    mov     rax , 141
    mov     rbx , 1
    mov     rcx , 1
    mov     rdx , 5 shl 32 + 5
    mov     r8  , 9 shl 32 + 12
    int     0x60

    ; Switch to 32bit mode

    mov     rax , 126
    mov     rbx , 1
    int     0x60

  use32

    mov     eax,40                          ; Report events
    mov     ebx,10000111b                   ; Stack 8 + defaults
    int     0x40

    call    draw_window                     

still:
    mov     eax,10                          ; Wait here for event
    int     0x40

    cmp     eax,1                           ; Redraw request 
    jz      red
    cmp     eax,2                           ; Key in buffer 
    jz      key
    cmp     eax,3                           ; Button in buffer 
    jz      button

    jmp     still

red:                         
    call    draw_window
    jmp     still

key:                            
    mov     eax,2               
    int     0x40
    jmp     still

button:                         
    mov     eax,17              
    int     0x40

    ; Close application

    cmp     ah,1                
    jnz     noclose
    ; close socket before exiting
    mov     eax, 53
    mov     ebx, 1
    mov     ecx, [socketNum]
    int     0x40
    mov     eax,0xffffffff      
    int     0x40
  noclose:

    ; Resolve address

    cmp     ah,3               
    jnz     noresolve
    mov     [validresponse],dword 0
    mov     [dhcpClientIP], dword 0
    mov     [dhcpDNSIP], dword 0
    mov     [dhcpSubnet], dword 0
    mov     [dhcpGateway], dword 0
    mov     [tsource],dword t1
    call    draw_info
    call    contactDHCPServer
    jmp     still
  noresolve:

    ; Apply values

    cmp     ah,4               
    jnz     noapply
    mov     [tsource],dword t4
    call    testvalidresponse
    cmp     [validresponse],dword 0
    je      exitapply
    ;
    mov     eax,52
    mov     ebx,3
    mov     ecx,[dhcpClientIP]
    int     0x40
    mov     eax,52
    mov     ebx,11
    mov     ecx,[dhcpGateway]
    int     0x40
    mov     eax,52
    mov     ebx,12
    mov     ecx,[dhcpSubnet]
    int     0x40
    mov     eax,52
    mov     ebx,14
    mov     ecx,[dhcpDNSIP]
    int     0x40
    ;
    mov     [tsource],dword t5
  exitapply:
    call    draw_info
    jmp     still
  noapply:

    jmp     still


parseResponse:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Function
;      parseResponse
;
;   Description
;      extracts the fields ( client IP address and options ) from
;      a DHCP response
;      The values go into
;       dhcpMsgType,dhcpLease,dhcpClientIP,dhcpServerIP,
;       dhcpDNSIP, dhcpSubnet
;      The message is stored in dhcpMsg
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    mov     edx, dhcpMsg

    mov     eax, [edx+16]
    mov     [dhcpClientIP], eax

    ; Scan options

    add     edx, 240        ; Point to first option

pr001:
    ; Get option id
    mov     al, [edx]
    cmp     al, 0xff        ; End of options?
    je      pr_exit

    cmp     al, 53          ; Msg type is a single byte option
    jne     pr002

    mov     al, [edx+2]
    mov     [dhcpMsgType], al
    add     edx, 3
    jmp     pr001           ; Get next option

pr002:
    ; All other (accepted) options are 4 bytes in length
    inc     edx
    movzx   ecx, byte [edx]
    inc     edx             ; point to data

    cmp     al, 54          ; server id
    jne     pr0021
    mov     eax, [edx]      ; All options are 4 bytes, so get it
    mov     [dhcpServerIP], eax
    jmp     pr003

pr0021:
    cmp     al, 51          ; lease
    jne     pr0022
    mov     eax, [edx]      ; All options are 4 bytes, so get it
    mov     [dhcpLease], eax
    jmp     pr003

pr0022:
    cmp     al, 1           ; subnet mask
    jne     pr0023
    mov     eax, [edx]      ; All options are 4 bytes, so get it
    mov     [dhcpSubnet], eax
    jmp     pr003

pr0023:
    cmp     al, 6           ; dns ip
    jne     pr0024
    mov     eax, [edx]      ; All options are 4 bytes, so get it
    mov     [dhcpDNSIP], eax

pr0024:
    cmp     al, 3           ; gateway ip
    jne     pr003
    mov     eax, [edx]      ; All options are 4 bytes, so get it
    mov     [dhcpGateway], eax

pr003:
    add     edx, ecx
    jmp     pr001

pr_exit:
    ret


buildRequest:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Function
;      buildRequest
;
;   Description
;      Creates a DHCP request packet.
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    ; Clear dhcpMsg to all zeros
    xor     eax,eax
    mov     edi,dhcpMsg
    mov     ecx,512
    cld
    rep     stosb

    mov     edx, dhcpMsg

    mov     [edx], byte 0x01                ; Boot request
    mov     [edx+1], byte 0x01              ; Ethernet
    mov     [edx+2], byte 0x06              ; Ethernet h/w len
    mov     [edx+4], dword 0x11223344       ; xid
    mov     [edx+10], byte 0x80             ; broadcast flag set
    mov     [edx+236], dword 0x63538263     ; magic number

    ; Local MAC address
    push    edx
    ; Select the arp table entry (in edx)
    mov     eax, 53
    mov     ebx, 255
    mov     ecx, 202
    mov     edx, 0
    int     0x40
    ; 4 bytes
    mov     eax, 53
    mov     ebx, 255
    mov     ecx, 204
    int     0x40
    pop     edx
    mov     [edx+7*4+0],eax
    ; 2 bytes
    push    edx
    mov     eax, 53
    mov     ebx, 255
    mov     ecx, 205
    int     0x40
    pop     edx
    mov     [edx+7*4+4],ax

    ; option DHCP msg type
    mov     [edx+240], word 0x0135     ; 53
    mov     al, [dhcpMsgType]
    mov     [edx+240+2], al

    ; option requested IP address
    mov     [edx+240+3], word 0x0432   ; 50
    mov     eax, [dhcpClientIP]
    mov     [edx+240+5], eax

    ; Check which msg we are sending
    cmp     [dhcpMsgType], byte 0x01
    jne     br001

    ; option request list
    mov     [edx+240+9], word 0x0437   ; 55
    mov     [edx+240+11], dword 0x0f060301

    ; "Discover" options
    ; end of options marker
    mov     [edx+240+15], byte 0xff

    mov     [dhcpMsgLen], dword 256
    jmp     br_exit

br001:
    ; "Request" options

    ; server IP
    mov     [edx+240+9], word 0x0436   ; 54
    mov     eax, [dhcpServerIP]
    mov     [edx+240+11], eax

    ; end of options marker
    mov     [edx+240+15], byte 0xff

    mov     [dhcpMsgLen], dword 256

br_exit:
    ret



contactDHCPServer:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Function
;      contactDHCPServer
;
;   Description
;       negotiates settings with a DHCP server
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    ; First, open socket
    mov     eax, 53
    mov     ebx, 0
    mov     ecx, 68                 ; local port dhcp client
    mov     edx, 67                 ; remote port - dhcp server
    mov     esi, 0xffffffff         ; broadcast
    int     0x40

    mov     [socketNum], eax

    ; Setup the first msg we will send
    mov     [dhcpMsgType], byte 0x01 ; DHCP discover
    mov     [dhcpLease], dword 0xffffffff
    mov     [dhcpClientIP], dword 0
    mov     [dhcpServerIP], dword 0

    call    buildRequest

ctr000:
    ; write to socket ( send broadcast request )
    mov     eax, 53
    mov     ebx, 4
    mov     ecx, [socketNum]
    mov     edx, [dhcpMsgLen]
    mov     esi, dhcpMsg
    int     0x40

    ; Setup the DHCP buffer to receive response

    mov     eax, dhcpMsg
    mov     [dhcpMsgLen], eax      ; Used as a pointer to the data

    ; now, we wait for
    ; UI redraw
    ; UI close
    ; or data from remote

ctr001:
    mov     eax,10                 ; wait here for event
    int     0x40

    cmp     eax,1                  ; redraw request ?
    je      ctr003
    cmp     eax,2                  ; key in buffer ?
    je      ctr004
    cmp     eax,3                  ; button in buffer ?
    je      ctr005

    ; Read returned data

    ; Any data in the UDP receive buffer?
    mov     eax, 53
    mov     ebx, 2
    mov     ecx, [socketNum]
    int     0x40

    cmp     eax, 0
    je      ctr001

    ; we have data - this will be the response
  ctr002:
    mov     eax, 53
    mov     ebx, 3
    mov     ecx, [socketNum]
    int     0x40                ; read byte - block (high byte)

    ; Store the data in the response buffer
    mov     eax, [dhcpMsgLen]
    mov     [eax], bl
    inc     dword [dhcpMsgLen]

    mov     eax, 53
    mov     ebx, 2
    mov     ecx, [socketNum]
    int     0x40                ; any more data?

    cmp     eax, 0
    jne     ctr002              ; yes, so get it

    ; depending on which msg we sent, handle the response
    ; accordingly.
    ; If the response is to a dhcp discover, then:
    ;  1) If response is DHCP OFFER then
    ;  1.1) record server IP, lease time & IP address.
    ;  1.2) send a request packet
    ;  2) else exit ( display error )
    ; If the response is to a dhcp request, then:
    ;  1) If the response is DHCP ACK then
    ;  1.1) extract the DNS & subnet fields. Set them in the stack
    ;  2) else exit ( display error )


    cmp     [dhcpMsgType], byte 0x01    ; did we send a discover?
    je      ctr007
    cmp     [dhcpMsgType], byte 0x03    ; did we send a request?
    je      ctr008

    ; should never get here - we only send discover or request
    jmp     ctr006

  ctr007:
    call    parseResponse

    ; Was the response an offer? It should be
    cmp     [dhcpMsgType], byte 0x02
    jne     ctr006                  ; NO - so quit

    ; send request
    mov     [dhcpMsgType], byte 0x03 ; DHCP request
    call    buildRequest
    jmp     ctr000

  ctr008:
    call    parseResponse

    ; Was the response an ACK? It should be
    cmp     [dhcpMsgType], byte 0x05
    jne     ctr006                  ; NO - so quit

    ; Set or display addresses here...

ctr006:
    ; close socket
    mov     eax, 53
    mov     ebx, 1
    mov     ecx, [socketNum]
    int     0x40

    mov     [socketNum], dword 0xFFFF

    mov     [tsource],dword t3
    call    draw_info

    call    testvalidresponse

    ret

ctr003:                         ; Redraw window
    call    draw_window
    jmp     ctr001

ctr004:                         ; Key
    mov     eax,2               ; Just read it and ignore
    int     0x40
    jmp     ctr001

ctr005:                         ; Button
    mov     eax,17              ; Get id
    int     0x40

    ; close socket
    mov     eax, 53
    mov     ebx, 1
    mov     ecx, [socketNum]
    int     0x40

    mov     [socketNum], dword 0xFFFF

    mov     [tsource],dword t2
    call    draw_info

    call    testvalidresponse

    ret


testvalidresponse:

    mov     [validresponse],byte 0
    cmp     [dhcpClientIP],dword 0
    je      novalid
    cmp     [dhcpDNSIP],dword 0
    je      novalid
    cmp     [dhcpSubnet],dword 0
    je      novalid
    cmp     [dhcpGateway],dword 0
    je      novalid
    mov     [validresponse],byte 1
  novalid:

    ret


draw_info:

    mov     esi , [tsource]
    mov     edi , ti
    mov     ecx , 36
    cld
    rep     movsb

    mov     eax , 13
    mov     ebx , 20 shl 16 + 36*6
    mov     ecx , 33 shl 16 + 14*5+8
    mov     edx , 0xffffff
    int     0x40

    mov     eax , 13
    mov     ebx , 20 shl 16 + 36*6
    mov     ecx , 148 shl 16 + 16
    mov     edx , 0xffffff
    int     0x40

    call    draw_window_content

    ret


drawIP:
;
;   Pass in the IP address in edi
;   Row to display in [ya]
;

    mov     ecx, edi
    add     ecx, 4
    mov     edx,[ya]
    add     edx, 127*65536
    mov     esi,0x000000
    mov     ebx,3*65536
  ipdisplay:
    mov     eax,47
    push    ecx
    movzx   ecx,byte [edi]
    int     0x40
    pop     ecx
    add     edx,6*4*65536
    inc     edi
    cmp     edi,ecx
    jb      ipdisplay
    ret


drawDHMS:

    mov     eax,[edi]
    bswap   eax

    mov     esi,dhms
    mov     ecx,16
    mov     edi,text+40*4+17
    cmp     [validresponse],byte 0
    je      nforever
    cmp     eax,0xffffffff
    jne     nforever
    mov     esi,forever
    cld
    rep     movsb
    ret
   nforever:
    cld
    rep     movsb

    mov     ecx,33
    xor     edx,edx
    mov     ebx,60
    div     ebx
    call    displayDHMS
    xor     edx,edx
    div     ebx
    call    displayDHMS
    xor     edx,edx
    mov     ebx,24
    div     ebx
    call    displayDHMS
    mov     edx,eax
    call    displayDHMS

    ret


displayDHMS:

    pusha
    mov     eax,47
    mov     ebx,3*65536
    mov     edx,ecx
    imul    edx,6
    shl     edx,16
    add     edx,1*65536+96
    mov     ecx,[esp+20]
    mov     esi,0x000000
    int     0x40
    popa
    sub     ecx,4
    ret


draw_window:

    mov     eax,12                    
    mov     ebx,1                     
    int     0x40
                                      
    mov     eax,0                      
    mov     ebx,200*65536+256-7
    mov     ecx,80*65536+180           
    mov     edx,0x04ffffff             
    mov     esi,window_label           
    mov     edi,0                      
    int     0x40

    mov     eax,8                     ; Resolve
    mov     ebx,20*65536+103
    mov     ecx,118*65536+19
    mov     edx,3
    mov     esi,0x10557799
    mov     edi,0
    int     0x40

    mov     eax,8                     ; Apply IP values
    mov     ebx,124*65536+103
    mov     ecx,118*65536+19
    mov     edx,4
    mov     esi,0x10557799
    mov     edi,0
    int     0x40

    call    draw_window_content

    mov     eax,12                    
    mov     ebx,2                     
    int     0x40

    ret


draw_window_content:

    ; Pass in the IP address in edi
    ; row to display in [ya]
    mov     edi, dhcpClientIP
    mov     eax, 40
    mov     [ya], eax
    call    drawIP
    mov     edi, dhcpGateway
    mov     eax, 40 + 14
    mov     [ya], eax
    call    drawIP
    mov     edi, dhcpSubnet
    mov     eax, 40 + 28
    mov     [ya], eax
    call    drawIP
    mov     edi, dhcpDNSIP
    mov     eax, 40 + 42
    mov     [ya], eax
    call    drawIP
    mov     edi, dhcpLease
    call    drawDHMS

    ; Screen text
    mov     ebx,25*65536+40
    mov     ecx,0x000000
    mov     edx,text
    mov     esi,40
    cld
  newline:
    mov     eax,4
    int     0x40
    add     ebx,14
    add     edx,40
    cmp     [edx],byte 'x'
    jnz     newline

    ret


;
; Data
;

text:

    db 'Client IP      :    .   .   .           '
    db 'Gateway IP     :    .   .   .           '
    db 'Subnet IP Mask :    .   .   .           '
    db 'DNS IP         :    .   .   .           '
    db 'Lease Time     :    d   h   m   s       '
    db '                                        '
    db '  SEND REQUEST     APPLY VALUES         '
    db '                                        '
ti: db 'Waiting for command                     '
    db 'x <- END MARKER, DONT DELETE            '

t1: db 'Request Sent                            '
t2: db 'Timeout for DHCP respond                '
t3: db 'Respond Received                        '
t4: db 'Invalid values                          '
t5: db 'Values applied (except lease time)      '

ya  dd  0x0

dhms      db   '   d   h   m   s'
forever   db   'No limit        '

window_label:   db  'DHCP CLIENT',0

validresponse:  dq  0
tsource:        dq  0

dhcpMsgType:    db  0
dhcpLease:      dd  0
dhcpClientIP:   dd  0
dhcpServerIP:   dd  0
dhcpDNSIP:      dd  0
dhcpSubnet:     dd  0
dhcpGateway:    dd  0

dhcpMsgLen:     dd  0
socketNum:      dd  0xFFFF
dhcpMsg:

I_END:



