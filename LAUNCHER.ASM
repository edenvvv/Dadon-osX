;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Launcher for Menuet64
;
;   Compile with 64bit FASM
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

use64

        org  0x0
        db   'MENUET64'         ; 8 byte id
        dq   0x01               ; header version
        dq   START              ; start of code
        dq   image_end          ; size of image
        dq   0x100000           ; memory for app
        dq   0xffff0            ; rsp
        dq   Param,0x0          ; I_Param,I_Icon

window_enable  equ  00
delay_count    equ  1 ; 50
delay_time     equ  1 ; 04
applications   equ  04

winxs equ 253

START:

    ; System fonts

    mov   rax , 141
    mov   rbx , 1
    mov   rcx , 1
    mov   rdx , 5 shl 32 + 5
    mov   r8  , 9 shl 32 + 12
    int   0x60

    call  get_sysdir          ; get system directory
    call  make_table          ; form scroll
    call  draw_background     ; draw background and set kbd
    call  draw_window         ; draw window
    call  start_applications  ; start applications

if 0=1

still:

    mov   rax , 11
    int   0x60
    test  rax , 1b       ; Redraw
    jnz   red
    test  rax , 100b     ; Button
    jnz   button
    jmp   still

red:

    call  draw_window
    jmp   still

button:

    mov   rax , 17
    int   0x60

    ; rax = status
    ; rbx = button id

    jmp   still

end if


draw_background:

    ;
    ; Desktop redraw at resolution change
    ;
    cmp   [Param+8],dword 'DESK'
    jne   startdesktop
    mov   rax , 15
    mov   rbx , 1
    int   0x60
    mov   rax , 5
    mov   rbx , 50
    int   0x60
    mov   rax , 15
    mov   rbx , 1
    int   0x60
    mov   rax , 5
    mov   rbx , 50
    int   0x60
    ;
    ; Start only menu and icons
    ;
    ret
  startdesktop:

    ;
    ; Background picture
    ;
    mov   rsi,[app_pointers]
    call  start_app

    mov   rax , 40
    mov   rbx , 10111b
    int   0x60

    mov   rax , 23
    mov   rbx , 100
    int   0x60

    mov   rax , 40
    mov   rbx , 111b
    int   0x60

    ;
    ; Keyboard map
    ;
    mov   rsi,[app_pointers+8]
    call  start_app

    ret


start_applications:

    ;
    ; Launch applications
    ;
    mov   r8  , app_pointers
    mov   rdi , applications

    ; Bgr done
    add   r8  , 8
    dec   rdi

    ; Kbd done
    add   r8  , 8
    dec   rdi

  newlaunch:

    mov   rax , delay_count
    call  start_delay

    mov   rsi,[r8]
    call  start_app

    add   r8 , 8

    dec   rdi
    jnz   newlaunch

    ;
    ; All done, close app
    ;

    mov   rax , delay_count
    call  start_delay

    ; Close 

    mov   rax , 512
    int   0x60


start_app:
;
;   Copy application name to end of sysdir and
;   start with BOOT parameter
;

    push  rsi
    push  rdi

    mov   rdi , [sysdirend]
    mov   rcx , 12
    cld
    rep   movsb

    mov   rax , 256
    mov   rbx , sysdir
    mov   rcx , boot
    int   0x60

    pop   rdi
    pop   rsi

    ret


start_delay:
;
;   Update scroll and make delay after application start
;

    push  rax
    push  rbx
    push  rcx

    mov   rcx , rax

    push  rcx
    call  update_candy
    pop   rcx

  sdl1:

    push  rcx
    call  delay
    call  update_candy
    pop   rcx

    loop  sdl1

    pop   rcx
    pop   rbx
    pop   rax

    ret


if window_enable=0

update_candy:

    ret

end if


if window_enable=1

update_candy:

    cmp   [Param+8],dword 'DESK'
    je    noupdatecandy

    push  rax
    push  rbx
    push  rcx
    push  rdx
    push  r8
    push  r9
    push  r10

    sub   [cstate],dword 1
    and   [cstate],dword 63
   
    mov   rdx, [cstate]
    imul  rdx, 3
    add   rdx, 0x80000+32*3

    mov   rbx, 18*0x100000000 + (winxs-36)
    mov   rcx, 73*0x100000000 + 12
    mov   r8 , 512*3-(winxs-36)*3
    mov   r9 , 0x1000000
    mov   r10, 3

    mov   rax , 7
    int   0x60

    pop   r10
    pop   r9
    pop   r8
    pop   rdx
    pop   rcx
    pop   rbx
    pop   rax

  noupdatecandy:
  
    ret

end if

delay:

    push  rax rbx

    mov   rax , 105
    mov   rbx , delay_time
    int   0x60

    if window_enable=1
    mov   rax , 11
    int   0x60
    test  rax , 1
    jz    nodrawwin
    call  draw_window
  nodrawwin:
    end if

    pop   rbx rax

    ret


get_sysdir:

    mov   rdi , sysdir
    mov   rax , 0
    mov   rcx , 500
    cld
    rep   stosb

    mov   rax , 112
    mov   rbx , 1
    mov   rcx , sys_parameter
    mov   rdx , 256
    mov   r8  , sysdir
    int   0x60

    mov   rsi , sysdir
  newsearch:
    inc   rsi
    cmp  [rsi],byte 0
    jne   newsearch

    mov  [sysdirend],rsi

    ret
 

if window_enable=0

make_table:

    ret

end if


if window_enable=1
   
make_table:
   
    mov  rdi,0x80000
    mov  eax,0xffffff
   
    mov  ecx,12
  newgg:
    push rcx
    mov  ecx,512
   newg:
    mov  [ebp+edi],eax
    add  edi,3
    loop newg
    sub  eax,0x040404                                                          
    pop  rcx
    loop newgg
   
    mov  edi,0x80000+64*3
    mov  eax,0x808890
   
    mov  ecx,12
  newgg2:
    push rcx
    mov  ecx,32
  newg2:
    mov  r10 , 0
    call addeax
    mov  r10 , 64
    call addeax
    mov  r10 , 128
    call addeax
    mov  r10 , 192
    call addeax
    mov  r10 , 256
    call addeax
    mov  r10 , 256+64
    call addeax
    mov  r10 , 256+128
    call addeax
    mov  r10 , 256+192
    call addeax

    add  edi,3
    loop newg2
    sub  eax,0x040404
    pop  rcx
    add  edi,3+224*3+256*3
    loop newgg2 
  
    ret

addeax:

    push  rax
    imul  r10 , 3
    add   r10 , rbp
    add   r10 , rdi
    mov   [r10],ax
    shr   rax , 16
    mov   [r10+2],al
    pop   rax
    ret

end if
   

if window_enable=0

draw_window:

    ret

end if


if window_enable=1

draw_window:

    cmp   [Param+8],dword 'DESK'
    je    nodrawwindow

    push  rax rbx rcx rdx r8 r9 r10 r11 r12 r13 r14 r15 rsi rdi rbp

    mov   rax , 12
    mov   rbx , 1
    int   0x60

    mov   rax , 26
    mov   rbx , 3
    mov   rcx , image_end
    mov   rdx , 30*8
    int   0x60

    ; Middle of screen

    mov   rbx , [image_end+0x20]
    shr   rbx , 1
    sub   rbx , winxs/2
    shl   rbx , 32
    add   rbx , winxs

    mov   rcx , [image_end+0x28]
    shr   rcx , 1
    sub   rcx , 160 -0
    shl   rcx , 32
    add   rcx , 103

    mov   rax , 0                           ; draw window
    mov   rdx , 0*0x100000000+0xffffff      ; type, border color  
    mov   r8  , 1b                          ; draw buttons 
    mov   r9  , window_label                ; zero or pointer to win label
    mov   r10 , 0                           ; zero or pointer to menu struct
    int   0x60

    mov   rax , 4
    mov   rbx , string_desktop
    mov   rcx , (winxs+1-20*6)/2
    mov   rdx , 48
    mov   r9  , 1
    mov   rsi , 0x000000
    int   0x60

    call  update_candy

    mov   rax , 12
    mov   rbx , 2
    int   0x60

    pop   rbp rdi rsi r15 r14 r13 r12 r11 r10 r9 r8 rdx rcx rbx rax

  nodrawwindow:

    ret

end if


;
; Data area
;

window_label:    db   'LAUNCHER',0
string_desktop:  db   'Setting up desktop..',0
sys_parameter:   db   'system_directory',0
cstate:          dq   0x0
sysdirend:       dq   0x0

Param:   dq   8
         dq   0

bgr2x2:  db  0x0,0x0,0x0
         db  0x0,0x0,0x0
         db  0x0,0x0,0x0
         db  0x0,0x0,0x0

app_pointers:   dq    app_string_1
                dq    app_string_2
                dq    app_string_3
                dq    app_string_4
app_string_1:   db    'BGR        ',0
app_string_2:   db    'KBDMAP     ',0
app_string_3:   db    'MENU       ',0
app_string_4:   db    'DESKTOP    ',0
boot:           db    'BOOT',0

sysdir: times 512 db ?

image_end:











