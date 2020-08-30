;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Icon for Menuet64
;
;   Compile with FASM 1.60 or above
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

use64

    db    'MENUET64'         ; 8 byte id
    dq    0x01               ; header version
    dq    START              ; start of code
    dq    IMAGE_END          ; size of image
    dq    0x100000           ; memory for app
    dq    0x0ffff0           ; rsp
    dq    Param              ; Param
    dq    0x0                ; Icon

image_invert    equ image_base+10000
icon_background equ image_base+20000
shape_map       equ image_base+40000
background_base equ image_base+60000

winx equ  48
winy equ  61
xp   equ  ((winx-48)/2)
rex  equ  r8
rfx  equ  r9
rgx  equ  r10
rhx  equ  r11
rix  equ  r12
rjx  equ  r13
rkx  equ  r14
rlx  equ  r15

START:

    ; System font
    mov   rax , 141
    mov   rbx , 1
    mov   rcx , 1
    mov   rdx , 5 shl 32 + 5
    mov   r8  , 9 shl 32 + 12
    int   0x60

    ; Get screenid
    sub   rsp , 256
    mov   rax , 111
    mov   rbx , 1
    int   0x60
    mov   rcx , rax
    mov   rax , 9
    mov   rbx , 2
    mov   rdx , rsp
    mov   r8  , 100
    int   0x60
    mov   rax , [rsp+64]
    mov   [screenid],rax
    add   rsp , 256

    ; Window shape
    call  create_shape_map

    ; Spin
    call  get_spin_click

    ; IPC
    mov   rax , 60
    mov   rbx , 1
    mov   rcx , ipcarea
    mov   rdx , 20
    int   0x60

    ; Drag n drop
    mov   rax , 121
    mov   rbx , 1
    mov   rcx , dragndrop
    mov   rdx , 250
    int   0x60
    mov   [dragndrop],byte 0
              
    ; Events
    mov   rax , 40
    mov   rbx , 110111b ; mouse,bgr,..
    int   0x60

    call  get_parameters
    call  load_icon
    call  calculate_icon_background

    mov   rax , 124
    mov   rbx , 4
    mov   rcx , 1
    int   0x60

    call  draw_window

still:

    mov   rax , 23
    mov   rbx , 2
    int   0x60

    cmp   [ipcarea+16],byte 0
    jne   terminate

    cmp   [dragndrop],byte 0
    je    nodnd
    mov   rcx , dragndrop
    jmp   start_app
  nodnd:

  stillevent:

    test  rax , 1b
    jnz   redraw
    test  rax , 10b
    jnz   key_event
    test  rax , 100b
    jnz   readbutton
    test  rax , 10000b
    jnz   read_background
    test  rax , 100000b
    jnz   check_mouse

    jmp   still



check_mouse:

    mov   rax , 37
    mov   rbx , 2
    int   0x60
    cmp   rax , 0
    je    still

 waitmouseup:

    mov   rax , 37
    mov   rbx , 0
    int   0x60
    mov   rbx , rax
    shr   rax , 32
    and   rbx , 0xffff

    mov   rcx , [icon_x]
    mov   rdx , [icon_y]
    cmp   rax , rcx
    jb    exitmouse
    cmp   rbx , rdx
    jb    exitmouse
    add   rcx , winx
    add   rdx , winy
    cmp   rax , rcx
    ja    exitmouse
    cmp   rbx , rdx
    ja    exitmouse

    mov   rcx , rax
    mov   rdx , rbx
    mov   rax , 35
    mov   rbx , 2
    int   0x60
    cmp   rax , [screenid]
    jne   exitmouse

    mov   rax , 5
    mov   rbx , 1
    int   0x60
    mov   rax , 37
    mov   rbx , 2
    int   0x60
    cmp   rax , 0
    jne   waitmouseup

    cmp   [click],byte 0 ; Single click
    jne   nosinglespin
    jmp   dostartapp
  nosinglespin:

    cmp   [click],byte 1 ; Double click, no spin
    jne   nodoublespin
    cmp   [spin],byte 0  
    jne   nodoublespin
    mov   rcx , 00
 waitmousedown:
    mov   rax , 5
    mov   rbx , 1
    int   0x60
    mov   rax , 37
    mov   rbx , 2
    int   0x60
    cmp   rax , 0
    jne   dostartapp
    add   rcx , 1
    cmp   rcx , 50
    jb    waitmousedown
    jmp   still
  nodoublespin:

    cmp   [click],byte 1 ; Double click, spin
    jne   nodoublespin2
    cmp   [spin],byte 1
    jne   nodoublespin2
    mov   rcx , 0  ; Wait mouse down
 waitmousedown2:
    mov   rax , 5
    mov   rbx , 1
    int   0x60
    mov   rax , 37
    mov   rbx , 2
    int   0x60
    cmp   rax , 0
    jne   waitmup
    add   rcx , 1
    cmp   rcx , 50
    jb    waitmousedown2
    jmp   still
  waitmup:
    mov   rcx , 0
  waitmouseup2:
    mov   rax , 5
    mov   rbx , 1
    int   0x60
    mov   rax , 37
    mov   rbx , 2
    int   0x60
    cmp   rax , 0
    je    dostartapp
    add   rcx , 1
    cmp   rcx , 50
    jb    waitmouseup2
    jmp   still
  nodoublespin2:

    jmp   still

    ;

  dostartapp:

    mov   rax , 37
    mov   rbx , 0
    int   0x60
    mov   rbx , rax
    shr   rax , 32
    and   rbx , 0xffff
    mov   rcx , rax
    mov   rdx , rbx
    mov   rax , 35
    mov   rbx , 2
    int   0x60
    cmp   rax , [screenid]
    jne   still

    jmp   button

  readbutton:

    mov   rax , 17
    int   0x60

    ; rax = status
    ; rbx = button id

  button:

    mov   rcx , [app_param]

  start_app:

    mov   rax , 256
    mov   rbx , Param + 50
    int   0x60

    call  spin_icon

    mov   [dragndrop],byte 0

    jmp   exitmouse


exitmouse:

    mov   rax , 5
    mov   rbx , 1
    int   0x60
    mov   rax , 37
    mov   rbx , 2
    int   0x60
    cmp   rax , 0
    jne   exitmouse

    jmp   still


redraw:

    call  draw_window_content ; for faster response

    call  draw_window
    jmp   still

key_event:

    mov   rax , 2
    int   0x60
    jmp   still

terminate:

    mov   rax , 512
    int   0x60

read_background:

    call  calculate_icon_background
    call  draw_window

    jmp   still

create_shape_map:

    mov   rdi , shape_map
    mov   rcx , winx
    imul  rcx , winy
    mov   rax , 1
    cld
    rep   stosb

    mov   rdi , shape_map
    mov   rax , shape_map+winy*winx-1
    mov   rsi , edges
  shapel0:
    cmp   [rsi],byte 0
    je    shapel1
    mov   [rdi],byte 0
    mov   [rax],byte 0
  shapel1:
    inc   rsi
    inc   rdi
    dec   rax
    cmp   rsi , edges+winx*5
    jb    shapel0

    mov   rax , 50
    mov   rbx , 0
    mov   rcx , shape_map
    int   0x60

    ret


get_spin_click:

    ; Read Click
    mov   [click],dword 0
    cmp   [Param+8+2],byte '0'
    jb    clickdone
    movzx rax , byte [Param+8+2]
    sub   rax , 48
    shr   rax , 1
    mov   [click],eax
  clickdone:

    ; Read Spin
    mov   [spin],dword 1
    cmp   [Param+8+3],byte '0'
    jb    spindone
    movzx rax , byte [Param+8+2]
    sub   rax , 48
    and   rax , 1
    mov   [spin],eax
  spindone:

    ret


get_parameters:

    ; Do we have parameters

    cmp   [Param+8],word 'xx'
    jne   yespar
    mov   rax , 512
    int   0x60
  yespar:

    ; Get sysdata
    mov   rax , 26
    mov   rbx , 3
    mov   rcx , IMAGE_END
    mov   rdx , 256
    int   0x60
    ; X
    mov   rax , [IMAGE_END+4*8]
    mov  [graphics_x],rax
    ; Y
    mov   rax , [IMAGE_END+5*8]
    mov  [graphics_y],rax
    ; Zero terminate icon label string
    mov  [18+Param+8], byte 0
    ; Zero terminate icon image string
    mov  [40+Param+8], byte 0
    ; Zero terminate path/app string after last used position
    mov   rdi , 44+Param+8
   mzl:
    inc   rdi
    cmp   [rdi],byte ' '
    ja    mzl
    mov   [rdi],byte 0
    ; Do we have a parameter after path/app ?
    mov   [app_param],dword 0
    cmp   [rdi+1],byte 32
    jbe   noparameter
    cmp   [rdi+1],byte '-'
    je    noparameter
    inc   rdi
    mov   [app_param],rdi
    ; Zero terminate app parameter
    mov   rax , rdi
    add   rax , 256
   mzl2:
    inc   rdi
    cmp   rdi , rax
    ja    mzl3
    cmp  [rdi], byte '-'
    je    mzl3
    cmp  [rdi], byte ' '
    ja    mzl2
  mzl3:
    mov  [rdi], byte 0
  noparameter:

    ; X position
    mov   rbx , [Param+8]
    and   rbx , 0xff
    sub   rbx , 65
    cmp   rbx , 4   ; 0..4,5..9
    jbe   xlower
    sub   rbx , 5
    mov   rax , 4
    sub   rax , rbx
    mov   rbx , rax
    imul  rbx , 70
    add   rbx , 20+48
    mov   rax , [graphics_x]
    sub   rax , rbx
    mov   rbx , rax
    sub   rbx , xp
    jmp   setx
  xlower:
    imul  rbx , 70
    add   rbx , 20-xp
  setx:
    mov  [icon_x],rbx

    ; Y position
    mov   rcx , [Param+8+1]
    and   rcx , 0xff
    sub   rcx , 65
    call  get_menu_position
    cmp   rcx , 4   ; 0..4,5..9
    jbe   ylower
    sub   rcx , 5
    mov   rax , 4
    sub   rax , rcx
    mov   rcx , rax
    imul  rcx , 70
    add   rcx , 74
    mov   rax , [graphics_y]
    sub   rax , rcx
    mov   rcx , rax
    cmp   [position],byte 1 
    jne   nopos11
    sub   rcx , 30
  nopos11:
    jmp   sety
  ylower:
    imul  rcx , 70
    add   rcx , 55
    cmp   [position],byte 1 
    jne   nopos1
    sub   rcx , 40
  nopos1:
  sety:
    mov  [icon_y],rcx

    ret


get_menu_position:

    push  rax rbx rcx rdx r8 r9 r10 r11 r12 r13 r14 r15 rsi rdi rbp

    mov     rax , 112
    mov     rbx , 1
    mov     rcx , main_menu_position
    mov     rdx , 0
    mov     r8  , 0
    int     0x60
    and     bl , 1
    mov     [position],bl

    pop   rbp rdi rsi r15 r14 r13 r12 r11 r10 r9 r8 rdx rcx rbx rax

    ret


spin_icon:

    cmp   [spin],byte 1
    jne   nospinicon

    mov   rbp , spindata
  newspin:
    push  rbp
    call  icon_delay
    mov   rax , 7            ; draw image
    mov   rbx , [rbp+0]      ; x start & size
    mov   rcx , [rbp+8]      ; y start & size
    mov   rdx , [rbp+16]     ; first pixel location
    mov   rex , [rbp+24]     ; scanline difference
    mov   rfx , 0x000000     ; tansparency color
    mov   rgx , [rbp+32]     
    int   0x60
    pop   rbp
    add   rbp , 8*5
    cmp   rbp , spindataend
    jb    newspin

  nospinicon:

    ret



icon_delay:

    mov   rax , 5
    mov   rbx , 4
    int   0x60
    mov   rax , 7                           ; draw image
    mov   rbx , 0 *0x100000000 + winx       ; x start & size
    mov   rcx , 0 *0x100000000 + 38         ; y start & size
    mov   rdx , icon_background             ; first pixel location
    mov   rex , 0                           ; scanline difference
    mov   rfx , 0x1000000                   ; tansparency color
    mov   rgx , 3                           ; pixel alignment
    int   0x60

    ret


draw_window:

    mov   rax , 12
    mov   rbx , 1
    int   0x60

    ; X position
    mov   rbx , [icon_x]
    shl   rbx , 32
    ; Y position
    mov   rcx , [icon_y]
    shl   rcx , 32
    mov   rax , 0                                    ; draw window
    add   rbx , winx                                 ; x start & size
    add   rcx , winy                                 ; y start & size
    mov   rdx , 1 shl 61 + 1*0x100000000 + 0xffffff  ; type 1=no draw
    mov   rex , 1b                                   ; 
    mov   rfx , 0                                    ; 0 or label
    mov   rgx , 0                                    ; 0 or pointer to menu
    int   0x60

    call  draw_window_content ; for faster response

    mov   rax , 12
    mov   rbx , 2
    int   0x60

    ret



draw_window_content:

    ; Get configuration parameter
    mov   rax , 112
    mov   rbx , 2
    mov   rcx , string_icon_font
    mov   rdx , 0
    mov   r8  , 0xfffff
    int   0x60
    mov   [fonttype],rbx

    ; Draw icon background
    mov   rax , 7                           ; draw image
    mov   rbx , 0 *0x100000000 + winx       ; x start & size
    mov   rcx , 0 *0x100000000 + winy       ; y start & size
    mov   rdx , icon_background             ; first pixel location
    mov   rex , 0                           ; scanline difference
    mov   rfx , 0x1000000                   ; tansparency color
    mov   rgx , 3                           ; pixel alignment
    int   0x60

    ; Draw icon
    mov   rax , 7                           ; draw image
    mov   rbx , (xp+8) *0x100000000 + 32    ; x start & size
    mov   rcx , 6 *0x100000000 + 32         ; y start & size
    mov   rdx , image_base + 54 + 32*31*3   ; first pixel location
    mov   rex , -32*3 *2                    ; scanline difference
    mov   rfx , 0x000000                    ; tansparency color
    mov   rgx , 3
    int   0x60

    ; Search icon name length

    mov   r15 , Param + 8 + 5
    dec   r15
    mov   r14 , 0
  inl1:
    inc   r15
    cmp   [r15],byte 0xC0
    jb    noutf8
    add   r14 , 1
  noutf8:
    cmp   [r15], byte 32
    ja    inl1
    mov   [r15], byte 0
    sub   r15 , Param + 8 + 5
    sub   r15 , r14

    ; Length to X pixels

    imul  r15 , 3
    and   r15 , 0x1f

    call  adjust_string

    ; Black text
    mov   rax , 4                          
    mov   rbx , icon_text
    mov   rcx , (xp+26)
    sub   rcx , r15
    mov   rdx , 47
    mov   rsi , 0x000000
    mov   rfx , 1 + 1 shl 60
    int   0x60

    ; White text
    mov   rax , 4                          
    mov   rbx , icon_text
    mov   rcx , (xp+25)
    sub   rcx , r15
    mov   rdx , 46
    mov   rsi , 0xffffff
    mov   rfx , 1 + 1 shl 60
    int   0x60

    ret


adjust_string:

    push  rcx rsi rdi

    mov   rsi , Param + 8 + 5
    mov   rdi , icon_text
    mov   rcx , 8+8
    cld
    rep   movsb

    cmp   [fonttype],dword 0
    je    nofadjust

    mov   rsi , icon_text
    cmp   [rsi],byte 0
    je    nofadjust

    cmp   [fonttype],dword 1
    jne   noftype1
    inc   rsi
    cmp   [rsi],byte 0
    je    nofadjust
  noftype1:

  newadjust:

    cmp   [rsi],byte 0
    je    nofadjust
    cmp   [rsi],byte 'A'
    jb    noadj
    cmp   [rsi],byte 'Z'+3
    ja    noadj
    add   [rsi],byte 32
  noadj:
    inc   rsi
    cmp   rsi , icon_text+8
    jbe   newadjust

  nofadjust:

    pop   rdi rsi rcx

    ret


load_icon:

    mov   rfx , Param+8+20       ; name pointer
    mov   rax , 58               ; FileSYS
    mov   rbx , 0                ; Read
    mov   rcx , 0                ; first block to read
    mov   rdx , -1               ; blocks to read
    mov   rex , image_base       ; return pointer
    int   0x60

    ; 8bit file
    cmp   [image_base+28],byte 8
    jne   no8bitimage
    mov   rsi , image_base
    mov   rdi , image_base+5000
    mov   rcx , 5000
    cld
    rep   movsb
    mov   esi , image_base+5000
    add   esi , [esi+10]
    mov   rdi , image_base+54
  new8bitconv:
    movzx rax , byte [esi]
    imul  rax , 4
    mov   eax , [image_base+5000+54+eax]
    mov   [rdi],eax
    add   rsi , 1
    add   rdi , 3
    cmp   rdi , image_base+54+32*32*3
    jb    new8bitconv
  no8bitimage:

    mov   rsi , image_base
    mov   rdi , image_invert
    mov   rcx , 5000
    cld
    rep   movsb

    mov   rdi , image_invert
    mov   rcx , 32*32*3+200

  newpix:

    mov   rax ,[rdi]
    and   rax , 0xffffff
    shr   rax , 1
    and   rax , 0x7f7f7f
    mov  [rdi], ax
    shr   rax , 16
    mov  [rdi+2], al

    add   rdi , 3

    loop  newpix

    ret


get_background_pixel:

    ; rbx-x, rax-y

    cmp   rax , [currentline]
    je    getpix

    push  rbx

    mov   [currentline],rax

    mov   rcx , rax     ; source

    mov   rax , 15
    mov   rbx , 12      ; get background
    mov   rdx , [bgr_x] ; bytes to return
    imul  rdx , 3
    mov   rex , background_line
    int   0x60

    pop   rbx

  getpix:

    mov   rcx , [background_line+rbx]
    and   rcx , 0xffffff

    ret


calculate_icon_background:

    mov   [currentline],dword 88888

    ; Background size

    mov   rax , 15
    mov   rbx , 13
    int   0x60

    mov   rbx , rax
    shr   rax , 32
    and   rbx , 0xfffffff
    mov   [bgr_x],rax
    mov   [bgr_y],rbx

    mov   rax , 0
    mov   rbx , 0
    mov   rlx , icon_background

  newbpix:

    push  rax
    push  rbx

    add   rax , [icon_x]
    add   rbx , [icon_y]

    mov   rcx ,[bgr_x]
    imul  rax , rcx
    mov   rdx , 0

    mov   rcx ,[graphics_x]
    div   rcx     
    mov   rcx , 3
    imul  rax , rcx

    push  rax

    mov   rax , rbx
    mov   rcx ,[bgr_y]
    imul  rax , rcx
    mov   rdx , 0

    mov   rcx ,[graphics_y]
    div   rcx      
    mov   rcx , 3
    imul  rax , rcx

    mov   rcx ,[bgr_x]

    imul  rax , rcx ; y

    pop   rbx ; x

    call  get_background_pixel

    mov   [rlx], ecx

    mov   rsi , [rsp+8]
    mov   rdi , [rsp+0]
    cmp   rdi , 5
    jae   noedge
    imul  rdi , winx
    add   rdi , rsi
    cmp   [rdi+edges],byte 1
    je    nodarken
  noedge:

    mov   rsi , [rsp+8]
    mov   rdi , [rsp+0]
    cmp   rdi , (winy-1)-5
    jbe   noedge2
    mov   rax , (winy-1)
    sub   rax , rdi
    mov   rdi , rax
    imul  rdi , winx
    add   rdi , rsi
    cmp   [rdi+edges],byte 1
    je    nodarken
  noedge2:

    mov   r8  , 16 ; Full bgr
    cmp   [Param+11],byte '-'
    je    fullbgr
    mov   r8  , 16
    movzx rax , byte [Param+11]
    sub   rax , 48
    sub   r8  , rax 
  fullbgr:

    xor   rax , rax
    mov   al , cl
    imul  rax , r8
    shr   rax , 4
    mov   [rlx+0],al

    shr   rcx , 8

    xor   rax , rax
    mov   al , cl
    imul  rax , r8
    shr   rax , 4
    mov   [rlx+1],al

    shr   rcx , 8

    xor   rax , rax
    mov   al , cl
    imul  rax , r8
    shr   rax , 4
    mov   [rlx+2],al

  nodarken:

    pop   rbx
    pop   rax

    add   rlx , 3

    add   rax , 1
    cmp   rax , winx
    jb    newbpix

    mov   rax , 0

    add   rbx , 1
    cmp   rbx , winy
    jb    newbpix

    ret


;
; Data area
;

app_param:    dq   0x0
icon_x:       dq   0x0
icon_y:       dq   0x0
bgr_x:        dq   0x0
bgr_y:        dq   0x0
graphics_x:   dq   640
graphics_y:   dq   480
fonttype:     dq   0x0
spin:         dq   0x1
click:        dq   0x0
color_black:  dd   0x000000
position:     dq   0x0
screenid:     dq   0x0
currentline:  dq   999999

edges:

    db    1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    times (winx-48) db 0
    db    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1
    db    1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    times (winx-48) db 0
    db    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1
    db    1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    times (winx-48) db 0
    db    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1
    db    1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    times (winx-48) db 0
    db    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1
    db    1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    times (winx-48) db 0
    db    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1

spindata:

    dq (xp+16) *0x100000000 + 16   ; x start & size
    dq  6 *0x100000000 + 32        ; y start & size
    dq image_base + 54 + 32*31*3   ; first pixel location
    dq -32*3 *2                    ; scanline difference
    dq  6

    dq (xp+20) *0x100000000 + 8    ; x start & size
    dq 6 *0x100000000 + 32         ; y start & size
    dq image_base + 54 + 32*31*3   ; first pixel location
    dq -32*3 *2                    ; scanline difference
    dq 12                          ; pixel alignment

    dq (xp+20) *0x100000000 + 8     ; x start & size
    dq  6 *0x100000000 + 32         ; y start & size
    dq  image_invert + 51 + 32*32*3 ; first pixel location
    dq  0                           ; scanline difference
    dq -12

    dq (xp+16) *0x100000000 + 16   ; x start & size
    dq 6 *0x100000000 + 32         ; y start & size
    dq image_invert + 51 + 32*32*3 ; first pixel location
    dq  0                          ; scanline difference
    dq -6                          ; pixel alignment

    dq (xp+8) *0x100000000 + 32     ; x start & size
    dq  6 *0x100000000 + 32         ; y start & size
    dq  image_invert + 51 + 32*32*3 ; first pixel location
    dq  0                           ; scanline difference
    dq  -3                          ; pixel alignment

    dq (xp+16) *0x100000000 + 16    ; x start & size
    dq 6 *0x100000000 + 32          ; y start & size
    dq image_invert + 51 + 32*32*3  ; first pixel location
    dq 0                            ; scanline difference
    dq  -6                          ; pixel alignment

    dq (xp+20) *0x100000000 + 8     ; x start & size
    dq  6 *0x100000000 + 32         ; y start & size
    dq  image_invert + 51 + 32*32*3 ; first pixel location
    dq  0                           ; scanline difference
    dq  -12                         ; pixel alignment

    dq (xp+20) *0x100000000 + 8     ; x start & size
    dq  6 *0x100000000 + 32         ; y start & size
    dq  image_base + 54 + 32*31*3   ; first pixel location
    dq  -32*3 *2                    ; scanline difference
    dq  12

    dq (xp+16) *0x100000000 + 16    ; x start & size
    dq  6 *0x100000000 + 32         ; y start & size
    dq  image_base + 54 + 32*31*3   ; first pixel location
    dq  -32*3 *2                    ; scanline difference
    dq  6                           ; pixel alignment

    dq (xp+8) *0x100000000 + 32     ; x start & size
    dq 6 *0x100000000 + 32          ; y start & size
    dq image_base + 54 + 32*31*3    ; first pixel location
    dq  -32*3 *2                    ; scanline difference
    dq 3                            ; pixel alignment

spindataend:


ipcarea:

    dq    0
    dq    16
    times 20 db 0

string_icon_font:

    db    'icon_font           ',0

main_menu_position: 

    db    'main_menu_position',0

Param:    

    dq  88
    db  '   - SETUP        '
    db  '- \sysdir\HD.BMP      '
    db  '- \sysdir\unzip \sysdir\setup.zip    '
    db  '-',13,10
    dq    0,0,0,0,0,0,0,0,0

IMAGE_END:  db 123
            times 2048 db ?

dragndrop:  times  256 db ?
savedir:    times   60 db ?
newfile:    times  256 db ?
icon_text:  times  256 db ?

background_line: times 65536 db ?

image_base:
















