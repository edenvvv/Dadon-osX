;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   64 bit Menuet Driver info  
;
;   Compile with FASM 1.60 or above
;   
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

ystep equ [stepping] ; abs
ypos  equ 72 ; abs
xpos  equ 5  ; rel

use64

    org   0x0

    db    'MENUET64'              ; Header identifier
    dq    0x01                    ; Version
    dq    START                   ; Start of code
    dq    image_end               ; Size of image
    dq    0x100000                ; Memory for app
    dq    0xffff0                 ; Esp
    dq    0x00                    ; Prm 
    dq    0x00                    ; Icon


START:

    mov   rax , 141
    mov   rbx , 1
    mov   rcx , 1
    mov   rdx , 5 shl 32 + 5
    mov   r8  , 9 shl 32 + 12
    int   0x60

    call  draw_window       ; At first, draw the window

still:

    mov   rax , 23          ; Wait here for event
    mov   rbx , 100
    int   0x60

    test  rax , 0x1         ; Window redraw
    jnz   window_event
    test  rax , 0x2         ; Keyboard press
    jnz   key_event
    test  rax , 0x4         ; Button press
    jnz   button_event

    call  draw_drivers

    jmp   still

window_event:

    call  draw_window
    jmp   still

key_event:

    mov   rax , 0x2        ; Read the key and ignore
    int   0x60

    jmp   still

button_event:

    mov   rax , 0x11
    int   0x60

    ; rax = status
    ; rbx = button id

    cmp   rbx , 0x10000001
    jne   no_application_terminate_button
    mov   rax , 0x200
    int   0x60
  no_application_terminate_button:

    cmp   rbx , 0x106
    jne   no_application_terminate_menu
    mov   rax , 0x200
    int   0x60
  no_application_terminate_menu:

    if 0=1
    cmp   rbx , 1000
    jb    noscroll
    cmp   rbx , 1900
    ja    noscroll
    mov   [sc],rbx
    call  draw_scroll
    call  draw_drivers
    jmp   still
  noscroll:
    end if

    jmp   still


draw_window:

    mov   rax , 0xC                          ; Beginning of window draw
    mov   rbx , 0x1
    int   0x60

    mov   rax , 141
    mov   rbx , 3
    int   0x60
    and   rax , 0xff
    sub   rax , 9
    shr   rax , 1
    mov   r12 , rax
    imul  r12 , 18
    add   rax , 9+3
    mov   [stepping],rax

    mov   rax , 0x0                          ; Draw window
    ;mov   rbx , 114 shl 32 + 573+xpos        ; x start & size
    ;mov   rcx , 79 shl 32 + 279              ; y start & size
    mov   rbx , 84 shl 32 + 573+xpos         ; x start & size
    mov   rcx , 47 shl 32 + 279              ; y start & size
    add   rcx , r12
    mov   rdx , 0x0000000000FFFFFF           ; type    & border color  
    mov   r8  , 0x0000000000000001           ; draw flags
    mov   r9  , window_label                 ; 0 or label - asciiz
    mov   r10 , menu_struct                  ; 0 or pointer to menu struct
    int   0x60

    if 0=1
    call  draw_scroll
    end if

    call  draw_drivers

    mov   rax , 0xC                          ; End of window draw
    mov   rbx , 0x2
    int   0x60

    ret



draw_drivers:

    mov   rax , 4
    mov   rbx , infotext
    mov   rcx , 20+xpos
    mov   rdx , 50
    mov   r9  , 1
    mov   rsi , 0x000000
    int   0x60

    mov   rax , 38
    mov   rbx , 20+xpos-3
    mov   rcx , 65
    mov   rdx , 547+xpos+3
    mov   r8  , rcx
    mov   r9  , 0xc6c6c6
    int   0x60

    mov   r14 , 0

  newdriver:

    mov   rax , 13
    mov   rbx , (10+xpos)* 0x100000000 + 542+xpos
    mov   rcx , r14
    imul  rcx , ystep
    add   rcx , ypos
    dec   rcx
    shl   rcx , 32
    add   rcx , 10+2
    mov   rdx , 0xffffff
    int   0x60

    mov   rax , 47
    mov   rbx , 2*65536
    mov   rcx , r14
    add   rcx , [sc]
    sub   rcx , 1000
    inc   rcx
    mov   rdx , r14  
    imul  rdx , ystep
    add   rdx , ypos
    add   rdx , (20+xpos)*65536
    mov   rsi , 0x000000
    int   0x40

    mov   rax , 116
    mov   rbx , 1
    mov   rcx , r14            
    add   rcx , [sc]
    sub   rcx , 1000 
    mov   rdx , driver_type
    mov   r8  , 100
    int   0x60

    cmp   rax , 0
    je    yesdriver

    mov   rax , 4
    mov   rbx , driver_no
    mov   rcx , 20+xpos
    mov   rdx , r14
    imul  rdx , ystep
    add   rdx , ypos
    mov   r9  , 1
    mov   rsi , 0x000000
    int   0x60

    jmp   nodriver

  yesdriver:

    mov   rax , 4
    mov   rbx , driver_type
    mov   rcx , 44+xpos
    mov   rdx , r14
    imul  rdx , ystep
    add   rdx , ypos
    mov   r9  , 1
    mov   rsi , 0x000000
    int   0x60

    mov   rax , 116
    mov   rbx , 2
    mov   rcx , r14
    add   rcx , [sc]
    sub   rcx , 1000
    mov   rdx , driver_type
    mov   r8  , 100
    int   0x60
    mov   rax , 4
    mov   rbx , driver_type
    mov   rcx , 182+xpos
    mov   rdx , r14
    imul  rdx , ystep
    add   rdx , ypos
    mov   r9  , 1
    mov   rsi , 0x000000
    int   0x60

    ; Device status

    mov   rax , 116
    mov   rbx , 5
    mov   rcx , r14
    add   rcx , [sc]
    sub   rcx , 1000
    int   0x60

    mov   rdi , unknown+12
    mov   rax , rbx
  newnum:
    xor   rdx , rdx
    mov   rcx , 10
    div   rcx
    add   dl  , 48
    mov   [rdi],dl
    sub   rdi , 1
    cmp   rdi , unknown+7
    jae   newnum

    mov   rax , 2
    cmp   rbx , rax
    cmova rbx , rax

    imul  rbx , 8
    add   rbx , device_status
    mov   rbx , [rbx]

    mov   rax , 4
    mov   rcx , 278-1*6+xpos
    mov   rdx , r14
    imul  rdx , ystep
    add   rdx , ypos
    mov   r9  , 1
    mov   rsi , 0x000000
    int   0x60

    ;

    mov   r15 , 0

  newn:  

    mov   rax , 116
    mov   rbx , r15
    add   rbx , 3
    mov   rcx , r14
    add   rcx , [sc]
    sub   rcx , 1000
    int   0x60

    mov   rcx , rbx
    mov   rax , 47
    mov   rbx , 12* 65536   
    mov   rdx , r15
    imul  rdx , 78+2*6
    add   rdx , 399-2*6+xpos
    shl   rdx , 16
    mov   dx  , r14w
    imul  dx  , ystep
    add   rdx , ypos
    mov   rbp , 0
    mov   rsi , 0
    mov   rdi , 0
    int   0x40 

    inc   r15
    cmp   r15 , 1
    jbe   newn

  nodriver:

    inc   r14
    cmp   r14 , 16
    jb    newdriver 

    ret


if 0=1
draw_scroll:

    mov   rax , 113
    mov   rbx , 1
    mov   rcx , 1000
    mov   rdx , 49   
    mov   r8  , [sc]
    mov   r9  , 550
    mov   r10 , 69 
    mov   r11 , 190
    int   0x60

    ret

end if



; Data area

window_label:

    db    'DRIVERS',0                      

infotext:

    db    'No  Driver type            Manufacturer   Status             '
    db    'In             Out ',0        

device_status:

    dq    not_init
    dq    working
    dq    unknown
    dq    unknown

not_init:  db    'Not initialized',0
working:   db    'Working properly',0              
unknown:   db    'Error (xxxxxx)',0
driver_no: db    '  ',0                                                           

sc: dq  1000
stepping: dq 0x0

driver_type:

    times 256 db 0

menu_struct:               ; Menu Struct

    dq   0                 ; Version

    dq   0x100             ; Start value of ID to return ( ID + Line )

                           ; Returned when menu closes and
                           ; user made no selections.

    db   0,'FILE',0        ; ID = 0x100 + 1
    db   1,'New',0         ; ID = 0x100 + 2
    db   1,'Open..',0      ; ID = 0x100 + 3
    db   1,'Save..',0      ; ID = 0x100 + 4
    db   1,'-',0           ; ID = 0x100 + 5
    db   1,'Quit',0        ; ID = 0x100 + 6

    db   0,'HELP',0        ; ID = 0x100 + 7
    db   1,'Contents..',0  ; ID = 0x100 + 8
    db   1,'About..',0     ; ID = 0x100 + 9

    db   255               ; End of Menu Struct


image_end:












