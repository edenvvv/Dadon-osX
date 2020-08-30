;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Magnify for Menuet64
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

use64

      org   0x0

      db    'MENUET64'         ; 8 byte id
      dq    0x01               ; header version
      dq    START              ; start of code
      dq    I_END              ; size of image
      dq    0x200000           ; memory for app
      dq    0xffff0            ; rsp
      dq    0x0,0x0            ; Parameter, Icon

x_size equ 50
y_size equ 40

START:

    mov   rax , 26
    mov   rbx , 3
    mov   rcx , I_END
    mov   rdx , 256
    int   0x60

    mov   rax ,[I_END+8*8]
    mov   [scanline],rax
    mov   rax ,[I_END+9*8]
    mov   [bytesperpixel],rax

    call  draw_window

still:

    mov   rax , 23
    mov   rbx , 20
    int   0x60

    test  rax , 1b    ; Window redraw
    jnz   red

    test  rax , 10b   ; Key press
    jnz   key

    test  rax , 100b  ; Button press
    jnz   button

    call  draw_magnify

    jmp   still

red:

    call  draw_window
    jmp   still

key:

    mov   rax , 2
    int   0x60

    mov   rax , 512
    int   0x60

    jmp   still

button:

    mov   rax , 17
    int   0x60

    ; rax = status
    ; rbx = button id

    cmp   rbx , 0x10000001
    jne   no_application_terminate
    mov   rax , 512
    int   0x60
  no_application_terminate:

    jmp   still


draw_window:

    mov   rax , 12
    mov   rbx , 1
    int   0x60

    mov   rax , 0                           ; draw window
    mov   rbx , 50 *0x100000000 + 252       ; x start & size
    mov   rcx , 50 *0x100000000 + 230       ; y start & size
    mov   rdx , 1 shl 62+1 shl 32+0xffffff  ; type    & border color  
    mov   r8  , 1b                          ; draw buttons - close,full,minimize
    mov   r9  , 0                           ; 0 or label - asciiz
    mov   r10 , 0                           ; pointer to menu struct or 0
    int   0x60

    ; Left and right lines

    mov   rax , 38
    mov   rbx , 0
    mov   rcx , 0
    mov   rdx , rbx
    mov   r8  , 230
    mov   r9  , 0x848484
    int   0x60
    add   rbx , 50*5+1
    add   rdx , 50*5+1
    int   0x60

    ; Up and Down lines

    mov   rcx , 0
    mov   r9  , 0xe0e0e0
  newup:
    mov   rax , 38
    mov   rbx , 0
    mov   rdx , 280
    mov   r8  , rcx
    int   0x60
    push  rcx
    add   rcx , 40*5 +15
    add   r8  , 40*5 +15
    int   0x60
    pop   rcx
    mov   r8  , rcx
    sub   r9  , 0x0a0a0a
    inc   rcx
    cmp   rcx , 15
    jb    newup

    call  draw_magnify

    mov   rax , 12
    mov   rbx , 2
    int   0x60

    ret


draw_magnify:

    mov   rax , 26
    mov   rbx , 1
    mov   rcx , sys_data
    mov   rdx , 256
    int   0x60

    mov   r14 , 0
    mov   r15 , 0

  newpix:

    mov   rax , 35
    mov   rbx , 1
    mov   rcx , r14
    mov   rdx , r15
    add   rcx , [sys_data+6*8]
    add   rdx , [sys_data+7*8]
    sub   rcx , x_size
    sub   rdx , y_size
    call  getscreenpixel

    push  r14 r15

    imul  r15 , 5
    imul  r14 , 5

    mov   r10 , r15
    imul  r10 , x_size*5
    add   r10 , r14
    imul  r10 , 4

    call  setrow
    call  setrow
    call  setrow
    call  setrow
    call  setrow

    pop   r15 r14

    inc   r14
    cmp   r14 , x_size
    jb    newpix

    mov   r14 , 0

    inc   r15
    cmp   r15 , y_size
    jb    newpix

    mov   rax , 7
    mov   rbx , 1 shl 32 + x_size*5
    mov   rcx , 15 shl 32 + y_size*5
    mov   rdx , 0x100000
    mov   r8  , 0
    mov   r9  , 0x1000000
    mov   r10 , 4
    int   0x60

    ret

setrow:

    mov   [0x100000+r10+4*0],eax
    mov   [0x100000+r10+4*1],eax
    mov   [0x100000+r10+4*2],eax
    mov   [0x100000+r10+4*3],eax
    mov   [0x100000+r10+4*4],eax

    add   r10 , x_size*5*4

    ret


getscreenpixel:

    cmp   rcx , 100000
    jb    rcxfine
    mov   rax , 0xf0f0f0
    ret
  rcxfine:
    cmp   rdx , 100000
    jb    rdxfine
    mov   rax , 0xf0f0f0
    ret
  rdxfine:

    imul  rdx , [scanline]
    imul  rcx , [bytesperpixel]
    add   rdx , rcx
    mov   eax , [gs:rdx]
    and   eax , 0xffffff

    ret


;
; Data
;

scanline:      dq 0x0
bytesperpixel: dq 0x0

sys_data:

I_END:

