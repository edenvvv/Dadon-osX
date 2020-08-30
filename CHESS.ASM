;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;    Chess client for Freechess.org
;
;    Compile with FASM 1.60 or above
;
;    (C) V.Turjanmaa
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

use64

    org   0x0

    db    'MENUET64'              ; Header identifier
    dq    0x01                    ; Version
    dq    START                   ; Start of code
    dq    I_END                   ; Size of image
    dq    0x600000                ; Memory for app
    dq    0x3ffff0                ; Esp
    dq    0x00                    ; Prm 
    dq    0x00                    ; Icon

; I_END   = board_old
; 0x10000 = BMP
; 0x20000 = Window stack position check     

cony    equ  118
dcony   equ  148
statusy equ  178
texts   equ  board_old+80*30
text    equ  texts+80*32*4

cacheimage equ 0x400000
cachestep  equ (150*150*3)

START: 

    call  clear_cache

    ; System font

    mov   rax , 141
    mov   rbx , 1
    mov   rcx , 1
    mov   rdx , 5 shl 32 + 5
    mov   r8  , 9 shl 32 + 12
    int   0x60

    call  chess_setup 
    call  draw_window
   
still:
   
    call  check_for_board
    call  board_changed
    call  draw_board
   
    mov   eax,53
    mov   ebx,6
    mov   ecx,[socket]
    int   0x40
    mov   ebx, [socket_status]
    mov   [socket_status], eax
    cmp   eax, ebx
    je    waitev
    call  display_status
  waitev:

    mov   eax,23                 ; Wait here for event
    mov   ebx,1
    int   0x40
   
    cmp   eax,1                  ; Redraw request
    je    red
    cmp   eax,2                  ; Key in buffer
    je    key
    cmp   eax,3                  ; Button in buffer
    je    button
   
    call  check_mouse

    mov   eax, 53
    mov   ebx, 2
    mov   ecx, [socket]
    int   0x40
    cmp   eax, 0
    jne   read_input
   
    jmp   still


clear_cache:

    mov   rdi , cacheimage
  ccl1:
    mov   [rdi],dword 0
    add   rdi , cachestep
    cmp   rdi , 0x600000-100
    jb    ccl1

    ret  



chess_setup:

    ; Clear data

    mov   rdi , datau_start
    mov   rcx , datau_end - datau_start
    mov   rax , 0
    cld
    rep   stosb

    ; Color map
   
    mov   esi,imagefile+118
    mov   edi,0x10000+18*3
    mov   ebx,0
    mov   ecx,0
  newp:
    xor   eax,eax
    mov   al,[esi]
    and   al,0xf0
    shr   al,4
    shl   eax,2
    mov   eax,[pawn_color+eax]
    mov   [edi+0],eax
    xor   eax,eax
    mov   al,[esi]
    and   al,0x0f
    shl   eax,2
    mov   eax,[pawn_color+eax]
    mov   [edi+3],eax
    add   edi,6
    add   esi,1
    inc   ebx
    cmp   ebx,23
    jbe   newp
    sub   edi,12
    mov   ebx,0
    inc   ecx
    cmp   ecx,275 ; 45*6+5
    jb    newp

    ; Clear text area
   
    mov   eax, '    '
    mov   edi,text
    mov   ecx,80*30 /4
    cld
    rep   stosd

    ret


check_mouse:

    ;  Top of windowing stack 

    mov   rax , 111
    mov   rbx , 1
    int   0x60
    mov   r15 , rax
    mov   rax , 26
    mov   rbx , 1
    mov   rcx , 0x20000  
    mov   rdx , 1024
    int   0x60
    mov   r14 , [0x20000+120]   
    mov   rax , 26
    mov   rbx , 2
    mov   rcx , 0x20000   
    mov   rdx , 1024
    int   0x60
    imul  r14 , 8
    add   r14 , 0x20000       
    cmp  [r14],r15
    jne   mouseret

    ; Connection status

    cmp   [socket_status],dword 4
    jne   mouseret

    ; Mouse buttons pressed

    mov   eax , 37
    mov   ebx , 2
    int   0x40
    mov   [mousebutton],eax
    cmp   eax , 0
    jne   mousedown
    ret
  mousedown:

    mov   rax , 11
    int   0x60
    test  rax , 1
    jz    mousecontinue
    ret
  mousecontinue:

    ; Wait for mouse up

    mov   eax , 5
    mov   ebx , 1
    int   0x40
    mov   eax , 37
    mov   ebx , 2
    int   0x40
    cmp   eax , 0
    jne   mousedown

    ; Get coordinates

    mov   eax , 37
    mov   ebx , 1
    int   0x40

    mov   ebx , eax
    shr   eax , 16
    and   ebx , 0xffff
    sub   eax ,[boardx]
    sub   ebx ,[boardy]
    xor   edx , edx
    mov   ecx ,[boardxs]
    div   ecx

    push  rax

    mov   eax , ebx
    xor   edx , edx
    mov   ecx ,[boardys]
    div   ecx
    mov   ebx , eax

    pop   rax

    ; Check sides

    cmp  [chess_board+80+5],byte '1'
    je    noswitch
    mov   ecx , 8
    sub   ecx , ebx
    mov   ebx , ecx
    jmp   nos2
  noswitch:

    mov   ecx , 8
    sub   ecx , eax
    mov   eax , ecx
    dec   eax
    inc   ebx
  nos2:
    cmp   eax , 7
    ja    mouseret
    cmp   ebx , 8
    ja    mouseret
    cmp   ebx, 0
    je    mouseret

    ; Send to server

    add   eax , 97
    add   ebx , 48
    call  to_server
    mov   eax , ebx
    call  to_server

    cmp   [mousebutton],dword 2
    jne   nomouse13
    mov   al , 13
    call  to_server
  nomouse13:
  mouseret:

    ret         

   
read_input:

    ; Read data
   
    push  rcx
    mov   eax, 53
    mov   ebx, 3
    mov   ecx, [socket]
    int   0x40
    pop   rcx

    call  handle_data

    ; Any data left
   
    push  rcx
    mov   eax, 53
    mov   ebx, 2
    mov   ecx, [socket]
    int   0x40
    pop   rcx
    cmp   eax, 0
    jne   read_input

    call  draw_text
    jmp   still
   
   
check_for_board:

    ; Server sent board
   
    push  rax rbx rcx rdx rsi rdi
    mov   esi,text-80
   news:
    add   esi,80
    cmp   esi,text+80*10
    je    board_not_found
    cmp   [esi+11],dword '----'
    je    cfb1
    jmp   news
   cfb1:
    cmp   [esi+16*80+11],dword '----'
    je    cfb2
    jmp   news
  cfb2:
    cmp   [esi+2*80+11],dword '+---'
    jne   news
    cmp   [esi+4*80+11],dword '+---'
    jne   news
  board_found:
    dec   esi
    mov   edi,chess_board
    mov   ecx,80*18
    cld
    rep   movsb
   
   board_not_found:
   
    pop   rdi rsi rdx rcx rbx rax
    ret
   
drsq:

    ; Draw board square

    push  rax rbx
   
    mov   ecx,ebx
    mov   ebx,eax
    mov   eax,ebx
    add   eax,ecx
   
    imul  ebx,[boardxs]
    add   ebx,[boardx]
    shl   ebx,16
    imul  ecx,[boardys]
    add   ecx,[boardy]
    shl   ecx,16
   
    add   ebx,[boardxs]
    add   ecx,[boardys]
    mov   edx,[sq_black]
    test  eax,1
    jnz   dbl22
    mov   edx,[sq_white]
  dbl22:
   
    mov   eax,13
    int   0x40
   
    pop   rbx rax
    ret





draw_pawn:

    ; edi  white/black
    ; esi  pawn position
    ; eax  board x
    ; ebx  board y

    push  rax rbx rcx rdx rsi rdi

    cmp   esi,20
    jne   no_sqd
    call  drsq
    jmp   bgrdone
   no_sqd:

    mov   rdx , rdi ; piece color b/w
    imul  rdx , 6
    add   rdx , rsi ; piece num
    imul  rdx , 2

    mov   rcx , rax
    add   rcx , rbx
    and   rcx , 1   ; bgr color b/w

    add   rdx , rcx

    imul  rdx , cachestep
    add   rdx , cacheimage
    mov   [currentaddress],rdx

    cmp   [changed],byte 1
    je    yesscale
    cmp   [rdx],dword 0
    jne   docurrent
  yesscale:

    ; Change pawn color

    cmp   edi , dword [current_color]
    je    color_fine

    mov   dword [current_color], edi

    ; White

    cmp   edi , 0
    jne   notowhite
    mov   rdi , 0x10000+17*3
  newshift:
    mov   rdx , [rdi]
    shl   rdx , 1
    mov   r8  , 0xfefefe
    and   rdx , r8
    mov   [rdi],dx
    shr   edx , 16
    mov   [rdi+2],dl
    add   rdi , 3
    cmp   rdi , 0x10000+17*3+ 6*44*45*3
    jb    newshift
    jmp   color_fine
  notowhite:

    ; Black

    cmp   edi , 1
    jne   notoblack
    mov   rdi , 0x10000+17*3
  newshift2:
    mov   rdx , [rdi]
    shr   rdx , 1
    mov   r8  , 0x7f7f7f
    and   rdx , r8
    mov   [rdi],dx
    shr   edx , 16
    mov   [rdi+2],dl
    add   rdi , 3
    cmp   rdi , 0x10000+17*3+ 6*44*45*3
    jb    newshift2
    jmp   color_fine
  notoblack:
  color_fine:

    ; Move and add background color

    push  rsi
    mov   rcx , rax
    add   rcx , rbx
    and   rcx , 1
    imul  esi , 44*45*3
    add   esi , 0x10000+18*3
    mov   r15d, esi
    add   r15 , 45*45*3
    mov   rdi , picpos ; 0x500000
  newshift3:
    mov   rdx , [rsi]
    and   rdx , 0xffffff
    cmp   edx , 0x00fe00
    je    yesbgr1
    cmp   edx , 0x007f00
    jne   nobgr1
  yesbgr1:
    mov   edx , [sq_black]
    test  rcx , 1
    jnz   nobgr1
    mov   edx , [sq_white]
  nobgr1:
    mov   [rdi],dx
    shr   edx , 16
    mov   [rdi+2],dl
    add   rsi , 3
    add   edi , 3
    cmp   rsi , r15 ; 0x10000+17*3+ 6*44*45*3
    jb    newshift3
    pop   rsi

    ; Resize

    call  doresize

  docurrent:

    ; Display

    and   rax , 0xffffff
    and   rbx , 0xffffff
    and   rsi , 0xffffff
    imul  eax , [boardxs]
    imul  ebx , [boardys]
    add   eax , [boardx]
    add   ebx , [boardy]
    mov   rcx , rbx
    mov   rbx , rax
    shl   rbx , 32
    shl   rcx , 32
    add   rbx , [boardxs]
    add   rcx , [boardys]
    mov   rax , 7
    mov   rdx , rsi
    mov   r8  , 0
    mov   r10 , 3
    mov   rdx , [currentaddress]
    mov   r9  , 0x1000000
    int   0x60

  bgrdone:

    pop   rdi rsi rdx rcx rbx rax
    ret




doresize:

    push  rax rbx rcx rdx r8 r9 r10 r11 r12 r13 r14 r15 rsi rdi rbp

    mov   rbp , [currentaddress]

    mov   r14 , 44 ; Old size
    mov   r15 , 44

    mov   r10 , [boardxs]  ; New size
    mov   r11 , [boardys]

    mov   r12 , 0
    mov   r13 , 0

  resl1:

    push  rax rcx rdx r8 r9 r10 r11 r12 r13 r14 r15 rsi rdi rbp

    ; Old X

    imul  r12 , r14
    mov   rax , r12
    mov   rbx , r10
    xor   rdx , rdx
    div   rbx
    mov   r12 , rax

    mov   [divider],rdx

    ; Old Y

    imul  r13 , r15
    mov   rax , r13
    mov   rbx , r11
    xor   rdx , rdx
    div   rbx
    mov   r13 , rax

    mov   [divider2],rdx

    mov   rax , r13
    imul  rax , r14
    add   rax , r12
    imul  rax , 3

    add   r12 , 1
    add   r13 , 1
    mov   [copyvalue],byte 0
    ; right line
    cmp   r12 , r14
    jb    ipic2
    mov   [copyvalue],byte 1
    jmp   ipicl1
  ipic2:
    ; bottom line
    cmp   r13 , r15
    jb    ipic3
    mov   [copyvalue],byte 2
    jmp   ipicl1
  ipic3:

    ; X and X+1

    call  calcwithdiv
    mov   [result1+0],bl
    add   rax , 1
    call  calcwithdiv
    mov   [result1+1],bl
    add   rax , 1
    call  calcwithdiv
    mov   [result1+2],bl

    sub   rax , 2
    add   rax , r14
    add   rax , r14
    add   rax , r14

    call  calcwithdiv
    mov   [result2+0],bl
    add   rax , 1
    call  calcwithdiv
    mov   [result2+1],bl
    add   rax , 1
    call  calcwithdiv
    mov   [result2+2],bl

    push  r10
    mov   rax , result1
    sub   rax , picpos ; 0x500000
    mov   rdx , [divider2]
    mov   [divider],rdx
    mov   r10 , r11
    ;
    call  calcwithdiv
    mov   [result3+0],bl
    add   rax , 1
    call  calcwithdiv
    mov   [result3+1],bl
    add   rax , 1
    call  calcwithdiv
    mov   [result3+2],bl
    pop   r10

    mov   ebx , [result3]

  ipicl1:

    pop   rbp rdi rsi r15 r14 r13 r12 r11 r10 r9 r8 rdx rcx rax

    mov   rax , r13
    imul  rax , r10
    add   rax , r12
    imul  rax , 3

    cmp   [copyvalue],byte 1
    jne   nocopy1
    mov   ebx , [rbp+rax-3]
  nocopy1:
    cmp   [copyvalue],byte 2
    jne   nocopy2
    push  rax
    sub   rax , r10
    sub   rax , r10
    sub   rax , r10
    mov   ebx , [rbp+rax]
    pop   rax
  nocopy2:

    mov   [rbp+rax],ebx

    inc   r12
    cmp   r12 , r10
    jb    resl1

    mov   r12 , 0

    inc   r13
    cmp   r13 , r11
    jb    resl1

    pop   rbp rdi rsi r15 r14 r13 r12 r11 r10 r9 r8 rdx rcx rbx rax

    ret




calcwithdiv:

    push  rax rcx rdx
    movzx ebx , byte [picpos+rax]
    movzx eax , byte [picpos+rax+3]
    imul  eax , [divider]
    mov   rcx , r10
    sub   ecx , [divider]
    imul  ebx , ecx
    add   eax , ebx
    xor   rdx , rdx
    mov   rbx , r10
    div   ebx
    mov   ebx , eax
    pop   rdx rcx rax
    ret
   
   
board_changed:
   
    push  rax rbx rcx rdx rsi rdi
    mov   eax,0
    mov   esi,chess_board
  bcl1:
    add   eax,[esi]
    add   esi,4
    cmp   esi,chess_board+19*80
    jb    bcl1
    cmp   eax,[checksum]
    je    bcl2
    mov   [changed],1
  bcl2:
    mov   [checksum],eax
    pop   rdi rsi rdx rcx rbx rax
    ret


draw_board:
   
    push  rax rbx rcx rdx rsi rdi
   
    cmp   [changed],1
    jne   no_change_in_board

    mov   [changed],0

    mov   eax,0
    mov   ebx,0
  scan_board:
   
    push  rax rbx
   
    mov   esi,ebx
    imul  esi,2
    imul  esi,80
    add   esi,80
    imul  eax,4
    add   eax,10
    add   esi,eax
    movzx edx,word [chess_board+esi]
    cmp   dx,[board_old+esi]
    je    empty_slot
    mov   ecx,13
  newseek2:
    mov   edi,ecx
    imul  edi,8
    sub   edi,8
    cmp   dx,[edi+pawns]
    je    foundpawn2
    loop  newseek2
    jmp   empty_slot
  foundpawn2:
    mov   esi,[edi+pawns+4]
    mov   edi,0
    cmp   dl,'*'
    jne   nnbb
    mov   edi,1
  nnbb:
    mov   eax,[esp+8]
    mov   ebx,[esp]
    call  draw_pawn
  empty_slot:
    pop   rbx rax
    inc   eax
    cmp   eax,8
    jb    scan_board
    mov   eax,0
    inc   ebx
    cmp   ebx,8
    jb    scan_board

    mov   esi,chess_board
    mov   edi,board_old
    mov   ecx,80*19
    cld
    rep   movsb

    mov   eax,13
    mov   ebx,[boardx]
    sub   ebx,14
    shl   ebx,16
    add   ebx,8
    mov   ecx,[boardy]
    shl   ecx,16
    add   ecx,46*8
    mov   edx,[wcolor]
    int   0x40
    mov   eax,4                    
    mov   ebx,[boardx]
    sub   ebx,14
    shl   ebx,16
    add   ebx,[boardy]
    add   ebx,18
    mov   ecx,[tcolor]
    mov   edx,chess_board+80+5
    mov   esi,3
  db1:
    int   0x40
    add   edx,80*2
    add   ebx,[boardxs]
    cmp   edx,chess_board+80*16
    jb    db1

    mov   eax,13
    mov   ebx,[boardx]
    shl   ebx,16
    add   ebx,8*46
    mov   ecx,[boardys]
    imul  ecx,8
    add   ecx,[boardy]
    add   ecx,8
    shl   ecx,16
    add   ecx,10
    mov   edx,[wcolor]
    int   0x40

    ; Letters

    mov   eax,4                    
    mov   ebx,[boardx]
    add   ebx,3
    shl   ebx,16
    mov   bx,word [boardys]
    imul  bx,8
    add   ebx,[boardy]
    add   ebx,8
    mov   ecx,[tcolor]
    mov   edx,chess_board+80*17+8
    mov   esi,4
  db3:
    int   0x40
    mov   edi,[boardxs]
    shl   edi,16
    add   ebx,edi
    add   edx,4
    cmp   edx,chess_board+80*17+8+4*8
    jb    db3
   
    ; Player times
   
    mov   edi,49 ; 74
    cmp   [chess_board+80+5],byte '1'
    jne   nowww2
    mov   edi,386 ; 371
  nowww2:

    mov   eax,13
    mov   ebx,[columnx]
    add   ebx,55
    shl   ebx,16
    add   ebx,56
    mov   ecx,edi
    dec   ecx
    shl   ecx,16
    add   ecx,10+2
    mov   edx,[wcolor]
    int   0x40
    mov   eax,4
    mov   ebx,[columnx]
    add   ebx,55
    shl   ebx,16
    add   ebx,edi
    mov   ecx,[tcolor]
    mov   edx,chess_board+80*7+59-1
    mov   [edx],byte ' '
    mov   esi,20
    int   0x40

    mov   edi,49
    cmp   [chess_board+80+5],byte '1'
    je    nowww
    mov   edi,386
  nowww:
   
    mov   eax,13
    mov   ebx,[columnx]
    add   ebx,55
    shl   ebx,16
    add   ebx,56
    mov   ecx,edi
    dec   ecx
    shl   ecx,16
    add   ecx,10+2
    mov   edx,[wcolor]
    int   0x40
    mov   eax,4
    mov   ebx,[columnx]
    add   ebx,55
    shl   ebx,16
    add   ebx,edi
    mov   ecx,[tcolor]
    mov   edx,chess_board+80*9+59-1
    mov   [edx],byte ' '
    mov   esi,20
    int   0x40
   
    ; Move #
   
    mov   eax,13
    mov   ebx,[columnx]
    shl   ebx,16
    add   ebx,120
    mov   ecx,199*65536+10+2
    mov   edx,[wcolor]
    int   0x40
    mov   eax,4
    mov   ebx,[columnx]
    shl   ebx,16
    add   ebx,200

    mov   ecx,[tcolor]
    mov   edx,chess_board+80*1+46
    mov   esi,30
    int   0x40
   
  no_change_in_board:
   
    pop   rdi rsi rdx rcx rbx rax
    ret
   
   
handle_data:

    cmp   bl,13          
    jne   nobol
    mov   ecx,[pos]
    add   ecx,1
  boll1:
    sub   ecx,1
    mov   eax,ecx
    xor   edx,edx
    mov   ebx,80
    div   ebx
    cmp   edx,0
    jne   boll1
    mov   [pos],ecx
    call  check_for_board
    jmp   newdata
  nobol:
   
    cmp   bl,10        
    jne   nolf
   addx1:
    add   [pos],dword 1
    mov   eax,[pos]
    xor   edx,edx
    mov   ecx,80
    div   ecx
    cmp   edx,0
    jnz   addx1
    mov   eax,[pos]
    jmp   cm1
  nolf:
   
    cmp   bl,9       ; Tab
    jne   notab
    add   [pos],dword 8
    jmp   newdata
  notab:
   
    cmp   bl,8       ; Backspace
    jne   nobasp
    mov   eax,[pos]
    dec   eax
    mov   [pos],eax
    mov   [eax+text],byte 32
    mov   [eax+text+60*80],byte 0
    jmp   newdata
   nobasp:
   
    cmp   bl,15      ; Character
    jbe   newdata
    mov   eax,[pos]
    mov   [eax+text],bl
    mov   eax,[pos]
    add   eax,1
  cm1:
    mov   ebx,[scroll+4]
    imul  ebx,80
    cmp   eax,ebx
    jb    noeaxz
    mov   esi,text+80
    mov   edi,text
    mov   ecx,ebx
    cld
    rep   movsb
    mov   eax,ebx
    sub   eax,80
  noeaxz:
    mov   [pos],eax
  newdata:
    ret
   

red: 

    call  draw_window

    cmp   [winx],dword 550
    jb    resizew
    cmp   [winy],dword 470
    jb    resizew
    jmp   nowresize
  resizew:
    mov   rax , 67
    mov   rbx , -1
    mov   rcx , -1
    mov   rdx , 550
    mov   r8  , 470
    int   0x60
  nowresize:

    jmp   still

   
key: 

    mov   eax,2          
    int   0x40
    mov   ebx, [socket_status]
    cmp   ebx, 4         
    jne   still          
    shr   eax,8
  modem_out:
    call  to_server
    jmp   still
   

button:                       

    mov   eax,17
    int   0x40

    cmp   ah,1                
    jne   noclose
    mov   eax,53
    mov   ebx,8
    mov   ecx,[socket]
    int   0x40
    mov   eax,-1
    int   0x40
  noclose:
   
    cmp   ah, 4   ; Connect
    jne   notcon
    mov   eax, [socket_status]
    cmp   eax, 4
    je    still
    call  connect
    jmp   still
  notcon:

    cmp   ah,5    ; Disconnect
    jne   notdiscon
    call  disconnect
    jmp   still
  notdiscon:

    jmp   still
   
   
to_server:

    push  rax rbx rcx rdx rsi rdi

    push  ax
    mov   [tx_buff], al
    mov   edx , 1
    cmp   al ,13
    jne   no13
    mov   edx , 2
  no13:
    mov   eax,53
    mov   ebx,7
    mov   ecx,[socket]
    mov   esi, tx_buff
    int   0x40
    pop   bx
    mov   al ,[echo]
    push  bx
    call  handle_data
    pop   bx
    cmp   bl , 13
    jne   seret2 
    mov   bl , 13
    call  handle_data
  seret2:
    call  draw_text
  seret:
    mov   eax , 5
    mov   ebx , 10
    int   0x40

    pop   rdi rsi rdx rcx rbx rax
    ret
   
   
disconnect:

    mov   eax,53
    mov   ebx,8
    mov   ecx,[socket]
    int   0x40
    ret
   

connect:

    push  rax rbx rcx rdx rsi rdi
   
    mov    ecx, 1000  
  getlp:
    inc    ecx
    push   rcx
    mov    eax, 53
    mov    ebx, 9
    int    0x40
    pop    rcx
    cmp    eax, 0    
    jz     getlp     
   
    mov    eax,53
    mov    ebx,5
    mov    esi,dword [ip_address]
    movzx  edx,word [port]     
    mov    edi,1      
    int    0x40
    mov    [socket], eax
   
    pop   rdi rsi rdx rcx rbx rax
   
    ret


board_size:

    mov   [boardx],dword 45
    mov   [boardy],dword 45

    mov   rax , 111
    mov   rbx , 1
    int   0x60
    sub   rsp , 256
    mov   rcx , rax
    mov   rax , 9
    mov   rbx , 2
    mov   rdx , rsp
    mov   r8  , 32
    int   0x60
    mov   rax , [rsp+16]
    mov   rbx , [rsp+24]
    mov   [winx],rax
    mov   [winy],rbx
    add   rsp , 256

    mov   r8  , rax
    shl   r8  , 32
    add   r8  , rbx
    cmp   r8  , [curwsize]
    je    noclearcache
    mov   [curwsize],r8
    call  clear_cache
  noclearcache:

    sub   rax , [boardx]
    sub   rax , 150
    shr   rax , 3
    sub   rbx , [boardy]
    sub   rbx , 70
    shr   rbx , 3
    cmp   rax , rbx
    cmova rax , rbx
    mov   [boardxs],rax
    mov   [boardys],rax

    ; Board end -> board to window center

    mov   rax , [boardxs]
    imul  rax , 8
    add   rax , [boardx]
    add   rax , 23
    add   rax , 145
    mov   r15 , [winx]
    sub   r15 , rax
    shr   r15 , 1
    cmp   r15 , 0x80000
    ja    noaddbrd
    add   [boardx],r15
  noaddbrd:

    mov   rax , [boardxs]
    imul  rax , 8
    add   rax , [boardx]
    add   rax , 23
    mov   [columnx],rax

    mov   rax , [boardys]
    imul  rax , 8
    add   rax , [boardy]
    add   rax , 23
    mov   [columny],rax

    ret



; Window definitions and draw
   
draw_window:
   
    push  rax rbx rcx rdx rsi rdi
   
    mov   eax,12
    mov   ebx,1
    int   0x40

    mov   rax , 0x0
    mov   rbx , 88*0x100000000 + 624
    mov   rcx , 30*0x100000000 + 503
    xor   rdx , rdx
    mov   edx , [wcolor]
    mov   r8  , 0x1        
    mov   r9  , window_label              
    mov   r10 , 0
    int   0x60

    call  board_size

    cmp   [winx],dword 550
    jb    nowindowdraw
    cmp   [winy],dword 470
    jb    nowindowdraw

    call  display_status
   
    mov   eax,8                ; Connect
    mov   ebx,[columnx]
    shl   ebx,16
    add   ebx,77

    mov   ecx,(cony-1)*65536+15+2
    mov   esi,[wbutton]
    mov   edx,4
    int   0x40
    mov   eax,4                ; Button text
    mov   ebx,[columnx]
    add   ebx,6
    shl   ebx,16
    add   ebx,cony+4
    mov   ecx,0x000000
    mov   edx,cont
    mov   esi,conlen-cont
    int   0x40   
   
    mov   eax,8                ; Disconnect
    mov   ebx,[columnx]
    shl   ebx,16
    add   ebx,77
    mov   ecx,(dcony-1)*65536+15+2
    mov   edx,5
    mov   esi,[wbutton]
    int   0x40
    mov   eax,4                ; Button text
    mov   ebx,[columnx]
    add   ebx,4
    shl   ebx,16
    add   ebx,dcony+4
    mov   ecx,0x000000  
    mov   edx,dist
    mov   esi,dislen-dist
    int   0x40   

    xor   eax,eax
    mov   edi,text+80*30
    mov   ecx,80*30 /4
    cld
    rep   stosd
   
    call  draw_text

    mov   rax , 141
    mov   rbx , 3
    int   0x60
    mov   r15 , rax
    and   r15 , 0xff
    inc   r15
    mov   r14 , 12
    cmp   r15 , r14
    cmova r15 , r14
   
    mov   eax,4
    mov   ebx,[columnx]
    shl   ebx,16
    add   ebx,215
    mov   ecx,[tcolor]
    mov   edx,quick_start
    mov   esi,30
  prqs:
    int   0x40
    add   ebx,r15d
    add   edx,30
    cmp   [edx],byte 'x'
    jne   prqs

    mov   eax,4
    mov   ebx,[columnx]
    shl   ebx,16
    add   ebx,49
    mov   ecx,[tcolor]
    mov   edx,text_opponent
    mov   esi,30
    int   0x40
    mov   eax,4
    mov   ebx,[columnx]
    shl   ebx,16
    add   ebx,386
    mov   ecx,[tcolor]
    mov   edx,text_you
    mov   esi,30
    int   0x40

    ; Board redraw

    mov   edi,board_old
    mov   ecx,80*19
    mov   al,0
    cld
    rep   stosb
    mov   [changed],1

  nowindowdraw:
   
    mov   eax,12
    mov   ebx,2
    int   0x40
   
    pop   rdi rsi rdx rcx rbx rax
   
    ret
   
   
display_status:
   
    push  rax rbx rcx rdx rsi rdi
   
    mov   eax, 13
    mov   ebx,[columnx]
    shl   ebx,16
    add   ebx,80
    mov   ecx, statusy*65536 + 16
    mov   edx, [wcolor]
    int   0x40
   
    mov   esi,contlen-contt   ; Display connected status
    mov   edx, contt
    mov   eax, [socket_status]
    cmp   eax, 4                     
    je    pcon
    mov   esi,discontlen-discontt
    mov   edx, discontt
  pcon:
    mov   eax,4                      
    mov   ebx,[columnx]
    shl   ebx,16
    add   ebx,statusy+2
    mov   ecx,[tcolor]
    int   0x40
   
    pop   rdi rsi rdx rcx rbx rax
    ret


draw_text:
   
    mov   esi,text+80*24
    mov   edi,texts+80*3
   
  dtl1:

    jmp   add_text  ; Display all lines

    ;cmp   [esi],dword 'fics'
    ;je    add_text
    ;sub   esi,80
    ;cmp   esi,text
    ;jge   dtl1

  dtl2:

    mov   eax,13
    mov   ebx,10*65536
    add   ebx,[winx]
    sub   ebx,20
    mov   ecx,420*65536+40
    mov   ecx,[columny]
    shl   ecx,16
    add   ecx,40
    mov   edx,[wtcom]
    int   0x40
    mov   eax,4
    mov   ebx,10*65536 ; +421
    add   ebx,[columny]
    add   ebx,1
    mov   ecx,[wtxt]
    mov   edx,texts
    mov   esi,80

  dtl3:

    int   0x40
    add   edx,80
    add   ebx,12
    cmp   edx,texts+6*80
    jb    dtl3
    ret
   
  add_text:

    push  rax rbx rcx rdx rsi rdi
    cld
    mov   ecx,80
    rep   movsb
    pop   rdi rsi rdx rcx rbx rax
   
    sub   esi,80
    sub   edi,80
    cmp   edi,texts
    jb    dtl2
   
    jmp   dtl1
   
   
read_string:
   
    mov   edi,string
    mov   eax,'_'
    mov   ecx,[string_length]
    inc   ecx
    cld
    rep   stosb
    call  print_text
   
    mov   edi,string
  f11:
    mov   eax,10
    int   0x40
    cmp   eax,2
    jne   read_done
    mov   eax,2
    int   0x40
    shr   eax,8
    cmp   eax,13
    je    read_done
    cmp   eax,8
    jnz   nobsl
    cmp   edi,string
    jz    f11
    sub   edi,1
    mov   [edi],byte '_'
    call  print_text
    jmp   f11
  nobsl:
    cmp   eax,dword 31
    jbe   f11
    cmp   eax,dword 95
    jb    keyok
    sub   eax,32
  keyok:
    mov   [edi],al
    call  print_text
   
    inc   edi
    mov   esi,string
    add   esi,[string_length]
    cmp   esi,edi
    jnz   f11
   
  read_done:
   
    call  print_text
    ret
   
   
print_text:
   
    push  rax rbx rcx rdx rsi rdi
   
    mov   eax,13
    mov   ebx,[string_x]
    shl   ebx,16
    add   ebx,[string_length]
    imul  bx,6
    mov   ecx,[string_y]
    shl   ecx,16
    mov   cx,8
    mov   edx,[wcolor]
    int   0x40
   
    mov   eax,4
    mov   ebx,[string_x]
    shl   ebx,16
    add   ebx,[string_y]
    mov   ecx,[tcolor]
    mov   edx,string
    mov   esi,[string_length]
    int   0x40
   
    pop   rdi rsi rdx rcx rbx rax
    ret

;
; Data area
;

currentaddress: dq  0x0
curwsize:       dq  0x0
string_length   dd  16
string_x        dd  200
string_y        dd  60
mousebutton     dd  0x0
checksum        dd  0x0
changed         db  0x1
tx_buff         db  0, 10
ip_address      db  167,114,65,195 ; 69,36,243,188-oldaddr
port            dw  5000         
echo            db  1
socket          dd  0x0
socket_status   dd  0x0
pos             dd  80 * 22
scroll          dd  1
                dd  24
   
wbutton         dd  0x336688
wtcom           dd  0x336688
wtxt            dd  0xffffff
wcolor          dd  0xf0f0f0
tcolor          dd  0x000000
sq_black        dd  0x336688
sq_white        dd  0xffffff

current_color:  dq  0 ; 0 white - 1 black
string          db  '________________'

winx:      dq 0x0
winy:      dq 0x0
divider:   dq 0x0
divider2:  dq 0x0
result1:   db 0,0,0
result2:   db 0,0,0
result3:   db 0,0,0
copyvalue: dq 0x0


window_label:  db  'FREECHESS.ORG CLIENT',0
setipt         db  '               .   .   .'
setiplen:
setportt       db  '     '
setportlen:
cont           db  '  Connect'
conlen:
dist           db  ' Disconnect'
dislen:
contt          db  'Connected'
contlen:
discontt       db  'Disconnected'
discontlen:
   
text_opponent:
   
    db  'Opponent                      '

quick_start:
   
    db  'Quick start:                  '
    db  '                              '
    db  '1 Connect                     '
    db  '2 login: guest                '
    db  '3 fics% seek 10 0             '
    db  '  - seek for a game           '
    db  '  - wait                      '
    db  '4 Play eg. e7e5               '
    db  '  or Mouse L/R                '
    db  '5 aics% resign                '
    db  '  - quit game                 '
    db  '6 Disconnect                  '
    db  'x'
   
text_you:
   
    db  'You                           '
   
    db  'x'

imagefile:

     file "chess.bmp"
   
pawn_color:
   
     dd  0x000000
     dd  0x222222
     dd  0x444444
     dd  0xf0f0f0
     dd  0xc0c0c0
     dd  0xa0a0a0
     dd  0xa0a0a0
     dd  0x707070
     dd  0xb0b0b0
     dd  0xc0c0c0
     dd  0xd0d0d0
     dd  0xd8d8d8
     dd  0xe0e0e0
     dd  0xe8e8e8
     dd  0x00ff00
     dd  0xffffff

yst      dd  150
textx    equ 10
ysts     equ 410

boardx:  dq 45
boardy:  dq 45

boardxs: dq 45
boardys: dq 44

columnx: dq 0x0
columny: dq 0x0
   
pawns:
   
    dd '*P  ',5
    dd '*K  ',3
    dd '*Q  ',4
    dd '*R  ',0
    dd '*N  ',1
    dd '*B  ',2
   
    dd '    ',20
   
    dd 'P   ',5
    dd 'K   ',3
    dd 'Q   ',4
    dd 'R   ',0
    dd 'N   ',1
    dd 'B   ',2
   
row   dd  0x0
col   dd  0x0

chess_board:
   
    times  80    db 0
    db '     8    *R  *N  *B  *Q  *K  *B  *N  *R'
    db '                                        '
    times  80  db 0
    db '     7    *P  *P  *P  *P  *P  *P  *P  *P'
    db '                                        '
    times  80  db 0
    db '     6                                  '
    db '                                        '
    times  80  db 0
    db '     5                                  '
    db '                                        '
    times  80  db 0
    db '     4                                  '
    db '                                        '
    times  80  db 0
    db '     3                                  '
    db '                                        '
    times  80  db 0
    db '     2    P   P   P   P   P   P   P   P '
    db '                                        '
    times  80      db 0
    db '     1    R   N   B   Q   K   B   N   R '
    db '                                        '
    times  80      db 0
    db '          a   b   c   d   e   f   g   h '
    db '                                        '

picpos: times 3*50*50 db ?

datau_start: ; part of the chess_board

    times  80*20 db ?

datau_end:
   
board_old:
   
I_END:
   
   
   






