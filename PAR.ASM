;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Parameters for Menuet64
;
;   Compile with FASM 1.60 or above
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

use64

         org    0x0

         db     'MENUET64'              ; 8 byte id
         dq     0x01                    ; header version
         dq     START                   ; start of code
         dq     IMAGE_END               ; size of image
         dq     0x100000                ; memory for app
         dq     0xffff0                 ; esp
         dq     0x0 , 0x0               ; I_Param , I_Icon

taby     equ  23
buty     equ  40
linesize equ  05
cidx     equ  50

showmax  equ  0

START:

    mov   rdi , cpuid_text-69
    jmp   checke
  newadddot:
    mov   rax , rdi
    add   rax , cidx-2
  adddot:
    mov   [rax],byte '.'
    sub   rax , 2
    cmp   [rax-1],word '  '
    je    adddot
  checke:
  noaddtoem:
    add   rdi , 69
    cmp   [rdi],byte ' '
    je    noaddtoem
    cmp   [rdi],byte 'x'
    jne   newadddot

    mov   rax , 141
    mov   rbx , 1
    mov   rcx , 1
    mov   rdx , 5 shl 32 + 5
    mov   r8  , 9 shl 32 + 12
    int   0x60

    call  draw_window

    call  display_general_data

    ; Window stack numbers

    mov   rdi , wstacknum
    mov   rcx , 1
  wsl1:
    push  rdi rcx
    mov   rcx , 34
    mov   rax , 32
    cld
    rep   stosb
    mov   rax , 0
    stosb
    pop   rcx rdi
    mov   rax , rcx
    mov   rbx , 10
    xor   rdx , rdx
    div   rbx
    add   al , 48
    add   dl , 48
    mov   [rdi+30],al
    mov   [rdi+31],dl
    add   rdi , 35
    inc   rcx
    cmp   rcx , 90
    jb    wsl1

still:

    mov   rax , 23
    mov   rbx , 100
    int   0x60

    test  rax , 1b    ; Window redraw
    jnz   red         
    test  rax , 10b   ; Key press
    jnz   key         
    test  rax , 100b  ; Button press
    jnz   button      

    call  display_general_numbers

    jmp   still

red:

    call  draw_window
    call  display_general_data
    jmp   still

key:

    mov   rax , 2
    int   0x60
    jmp   still

redraw:

    call  display_general_data
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

    cmp   rbx , 1000
    jb    noscroll
    cmp   rbx , 1200
    ja    noscroll
    mov  [scroll_value],rbx
    push  rbx
    call  draw_scroll   
    pop   rbx
    sub   rbx , 1000
    mov  [display_from],rbx
    call  display_general_data
    jmp   still
  noscroll:

    cmp   rbx , 800
    jne   noupdate
    call  display_general_data
    jmp   still
  noupdate:

    mov   [display_from],dword 0
    mov   rcx , rbx
    mov   [dip],rcx
    call  display_general_data
    mov   [scroll_value],dword 1000
    call  draw_scroll

    jmp   still


draw_scroll:

    mov   rax , 113
    mov   rbx , 1
    mov   rcx , 1000
    mov   rdx , 155
    mov   r8  ,[scroll_value]
    mov   r9  , 355-6
    mov   r10 , 45+taby
    mov   r11 , 236+linesize*10
    int   0x60

    ret




draw_window:

    mov   rax , 12
    mov   rbx , 1
    int   0x60

    mov   rax , 141
    mov   rbx , 3
    int   0x60
    and   rax , 0xff
    mov   [fontsize],rax
    mov   rbx , rax
    inc   rbx
    mov   rax , 270 ; 55-38-2
    xor   rdx , rdx
    div   rbx
    mov   [lines],rax

    mov   rax , 0                      
    mov   rbx , 162 shl 32 + 385-6
    mov   rcx , 46  shl 32 + 325 + linesize*10
    mov   rdx , 0   shl 32 + 0xffffff 
    mov   r8 , 1b                          
    mov   r9 , window_label                
    mov   r10 , 0                           
    int   0x60

    call  draw_scroll

    ; Draw area frames

    mov   rax , 38
    mov   rbx , 15
    mov   rcx , 44 + taby
    mov   rdx , 15
    mov   r8  , 282 + taby + linesize*10
    mov   r9  , 0x000000
    int   0x60

    mov   rax , 38
    mov   rbx , 15
    mov   rcx , 44 + taby
    mov   rdx , 367-6
    mov   r8  , 44 + taby
    mov   r9  , 0x000000
    int   0x60

    mov   rax , 38
    mov   rbx , 15
    mov   rcx , 282 + taby + linesize*10
    mov   rdx , 367-6
    mov   r8  , 282 + taby + linesize*10
    mov   r9 , 0x000000
    int   0x60

    buttonw equ 69
    mov   rbx , 15 shl 32 + buttonw
    mov   rcx , buty shl 32 + 18
    mov   rdx , 0x1
    mov   r8  , 0x446688
  newbutton:
    push  rdx
    mov   r9d , [buttonlabel+rdx*8+4]
    mov   edx , [buttonlabel+rdx*8]
    mov   rax , 8
    int   0x60
    pop   rdx
    mov   r10 , buttonw shl 32
    add   rbx , r10
    add   rdx , 1
    cmp   rdx , 5
    jbe   newbutton

    mov   rax , 12
    mov   rbx , 2
    int   0x60

    ret


display_info:

    mov   [disover],byte 0
    mov   rax , [dip]
    sub   rax , 1
    imul  rax , 8
    add   rax , text_pointers
    mov   rax , [rax]
    mov   rcx , [display_from]
    inc   rcx
  diso0:
    cmp   [rax],byte 'x'
    je    diso
    add   rax , 35
    cmp   [dip],byte 5
    jne   noadd36a
    add   rax , 34
  noadd36a:
    loop  diso0
    jmp   diso2
  diso:
    mov   [disover],byte 1
  diso2:

    mov   rax , [dip]
    sub   rax , 1
    imul  rax , 8
    add   rax , text_pointers
    mov   rbx , [rax]
    mov   rax , [display_from]
    mov   rcx , 35
    cmp   [dip],byte 5
    jne   noadd36b
    add   rcx , 34
  noadd36b:
    imul  rax , rcx
    add   rbx , rax
    mov   rax , 4
    mov   rcx , 20+2
    mov   rdx , 50+taby
    mov   r9  , 1
    mov   r15 , 0

  newline_3:

    push  rax
    push  rbx
    push  rcx
    push  rdx
    mov   rax , 13
    mov   rbx , rcx
    shl   rbx , 32
    add   rbx , 208
    cmp   [dip],byte 5
    jne   noadd55
    add   rbx , 116
  noadd55:
    mov   rcx , rdx
    dec   rcx
    shl   rcx , 32
    add   rcx , 12
    mov   rdx , 0xffffff
    int   0x60
    pop   rdx
    pop   rcx
    pop   rbx
    pop   rax

    cmp   [rbx],byte 'x'
    jne   nodover
    mov   [disover],byte 1
  nodover:

    cmp   [disover],byte 1
    je    nodisp
    int   0x60
  nodisp:

    add   rbx , 35
    cmp   [dip],byte 5
    jne   noadd36
    add   rbx , 34
  noadd36:

    add   rdx , [fontsize]
    add   rdx , 1
    add   r15 , 1
    cmp   r15 , [lines] ; 22+linesize
    jbe   newline_3

    ret


display_general_data:

    cmp   [dip],dword 5
    je    docpuid

    mov   rsi , 0x000000
    call  display_info

display_general_numbers:

    cmp   [dip],dword 5
    je    nocpuid

    mov   rax , 26                ; return system info
    mov   rbx , dip
    mov   rbx , [rbx]             ; 1 general - 2 window - 3 boot data
    mov   rcx , system_general    ; - where to return
    mov   rdx , 2048              ; - bytes to return
    int   0x60

    mov   r12 , 230+2;20
    mov   r13 , 1
    mov   r11 , system_general  
    mov   r15 , 0x00
    call  display_system_info

    ret

  docpuid:

    mov   eax , 0
    cpuid
    mov   [maxf],eax
    mov   [cpuid0a+cidx-10],byte ' '
    mov   [cpuid0a+cidx-9],ebx
    mov   [cpuid0a+cidx+4-9],edx
    mov   [cpuid0a+cidx+8-9],ecx

    if showmax=1
    mov   rax , 47
    mov   rbx , 8*65536+256
    mov   rcx , [maxf]
    mov   rdx , 100 shl 32 + 22
    mov   rsi , 0
    int   0x60
    end if

    xor   rax , rax
    xor   rbx , rbx
    xor   rcx , rcx
    xor   rdx , rdx
    cmp   [maxf],dword 1
    jb    noread1
    mov   eax , 1
    cpuid
  noread1:
    mov   r8  , rax
    and   r8  , 1111b
    mov   r9  , cpuid1a+cidx ; _text+69*4+cidx
    mov   r10 , 3
    call  writenum
    mov   r8  , rax
    shr   rax , 4
    and   r8  , 1111b
    add   r9  , 69
    mov   r10 , 3
    call  writenum
    mov   r8  , rax
    shr   rax , 8
    and   r8  , 1111b
    add   r9  , 69
    mov   r10 , 3
    call  writenum
    mov   r8  , rax
    shr   rax , 12
    and   r8  , 11b
    add   r9  , 69
    mov   r10 , 3
    call  writenum
    mov   r8  , rax
    shr   rax , 16
    and   r8  , 1111b
    add   r9  , 69
    mov   r10 , 3
    call  writenum
    mov   r8  , rax
    shr   rax , 20
    and   r8  , 11111111b
    add   r9  , 69
    mov   r10 , 3
    call  writenum

    mov   r8  , rbx
    and   r8  , 11111111b
    mov   r9  , cpuid1b+cidx
    mov   r10 , 3
    call  writenum
    mov   r8  , rbx
    shr   r8  , 8
    and   r8  , 11111111b
    add   r9  , 69
    mov   r10 , 3
    call  writenum
    mov   r8  , rbx
    shr   r8  , 16
    and   r8  , 11111111b
    add   r9  , 69
    mov   r10 , 3
    call  writenum
    mov   r8  , rbx
    shr   r8  , 24
    and   r8  , 11111111b
    add   r9  , 69
    mov   r10 , 3
    call  writenum

    mov   r8  , rdx
    mov   r9  , cpuid1d+cidx
    mov   r10 , 0
  loopl1:
    cmp   r10 , 10
    je    skipl1
    cmp   r10 , 20
    je    skipl1
    call  writeboolean
    add   r9  , 69
  skipl1:
    shr   r8  , 1
    add   r10 , 1
    cmp   r10 , 32
    jb    loopl1

    mov   r8  , rcx
    mov   r9  , cpuid1c+cidx
    mov   r10 , 0
  loopl2:
    cmp   r10 , 16
    je    skipl2
    call  writeboolean
    add   r9  , 69
  skipl2:
    shr   r8  , 1
    add   r10 , 1
    cmp   r10 , 32
    jb    loopl2

    xor   rax , rax
    xor   rbx , rbx
    xor   rcx , rcx
    xor   rdx , rdx
    cmp   [maxf],dword 7
    jb    noread7
    mov   eax , 7
    mov   ecx , 0
    cpuid
  noread7:

    mov   r8  , rbx
    mov   r9  , cpuid70b+cidx ; _text70+cidx
    mov   r10 , 0
  loopl3:
    cmp   r10 , 6
    je    skipl3
    call  writeboolean
    add   r9  , 69
  skipl3:
    shr   r8  , 1
    add   r10 , 1
    cmp   r10 , 32
    jb    loopl3

    mov   r8  , rcx
    mov   r9  , cpuid70c+cidx ; _text70+cidx
    call  writeboolean
    shr   r8  , 1
    add   r9  , 69
    call  writeboolean
    shr   r8  , 1
    add   r9  , 69
    call  writeboolean
    shr   r8  , 1
    add   r9  , 69
    call  writeboolean
    shr   r8  , 1
    add   r9  , 69
    call  writeboolean
    mov   r8  , rcx
    shr   r8  , 14
    add   r9 , 69
    call  writeboolean
    mov   r8  , rcx
    shr   r8  , 22
    add   r9 , 69
    call  writeboolean
    mov   r8  , rcx
    shr   r8  , 30
    add   r9 , 69
    call  writeboolean

    mov   r8  , rdx
    shr   r8  , 2
    mov   r9  , cpuid70d+cidx ; _text70+cidx
    call  writeboolean
    mov   r8  , rdx
    shr   r8  , 3
    add   r9 , 69
    call  writeboolean

    mov   rax , 0x80000000
    cpuid
    mov   [maxf],eax

    if showmax=1
    mov   rax , 47
    mov   rbx , 8*65536+256
    mov   rcx , [maxf]
    mov   rdx , 150 shl 32 + 22
    mov   rsi , 0
    int   0x60
    end if

    xor   rax , rax
    xor   rbx , rbx
    xor   rcx , rcx
    xor   rdx , rdx
    cmp   [maxf],dword 0x80000001
    jb    noread81
    mov   eax , 0x80000001
    cpuid
  noread81:

    mov   r8  , rdx
    mov   r9  , cpuid81d+cidx
    mov   r10 , 0
  loopl4:
    cmp   r10 , 10
    je    skipl4
    cmp   r10 , 18
    je    skipl4
    cmp   r10 , 21
    je    skipl4
    cmp   r10 , 28
    je    skipl4
    call  writeboolean
    add   r9  , 69
  skipl4:
    shr   r8  , 1
    add   r10 , 1
    cmp   r10 , 32
    jb    loopl4

    mov   r8  , rcx
    mov   r9  , cpuid81c+cidx
    mov   r10 , 0
  loopl5:
    cmp   r10 , 14
    je    skipl5
    cmp   r10 , 18
    je    skipl5
    cmp   r10 , 20
    je    skipl5
    cmp   r10 , 25
    je    skipl5
    cmp   r10 , 29
    je    skipl5
    cmp   r10 , 30
    je    skipl5
    cmp   r10 , 31
    je    skipl5
    call  writeboolean
    add   r9  , 69
  skipl5:
    shr   r8  , 1
    add   r10 , 1
    cmp   r10 , 32
    jb    loopl5

    mov   rsi , 0x000000
    call  display_info

  nocpuid:

    ret


writenum:

    push  rax rbx rcx rdx r8 r9 r10

    add   r9 , r10
    sub   r9 , 1
    mov   rax , r8
  wnl1:
    xor   rdx , rdx
    mov   rbx , 10
    div   rbx
    add   dl , 48
    mov   [r9],dl
    sub   r9 , 1

    dec   r10
    jnz   wnl1

    pop   r10 r9 r8 rdx rcx rbx rax

    ret


writeboolean:

    push  r8 r9 r10 r11

    mov   r10 , 'Yes '
    mov   r11 , ' No '
    test  r8  , 1b
    cmovz r10 , r11
    mov   [r9],r10d

    pop   r11 r10 r9 r8

    ret



display_system_info:

    mov   r14 , 23+linesize
    imul  r14 , 8
    add   r14 , r11
    mov   rax , ypos
    mov   rdx , 40+taby
    mov  [rax], rdx

    mov   r10 , 0

  dsil1:

    mov   rbx , r12
    mov   rcx , [ypos]
    add   rcx , 9
    shl   rbx , 32
    shl   rcx , 32
    add   rbx , 110
    add   rcx , 12
    mov   rdx , 0xffffff
    mov   rax , 13
    int   0x60

    cmp   r15 , 0xffffff
    je    noclear
    mov   rax , r11
    mov   rbx ,[display_from]
    imul  rbx , 8
    add   rax , rbx
    mov   rax ,[rax]
    mov   rdi , hex_text + 2
    call  hex_to_ascii
    mov   rax , ypos
    mov   rdx ,[rax]
    add   rdx , [fontsize]
    add   rdx , 1
    mov  [rax], rdx
    mov   rax , 4
    mov   rbx , hex_text
    mov   rcx , r12
    mov   rsi , r15
    mov   r9 , 1
    int   0x60
  noclear:
    add   r11 , 8

    add   r10 , 1
    cmp   r10 , [lines]
    jbe   dsil1

    ret


hex_to_ascii:

    push  rax
    push  rbx
    push  rcx
    push  rdx
    push  rdi
    push  r8
    push  r9
    add   rdi , 15
    mov   r8 , 16
    mov   r9 , 0
  htal1:
    mov   rdx , 0
    mov   rbx , 16
    div   rbx
    mov   rcx , 65 - 58
    mov   rbx , 10
    cmp   rdx , rbx
    jne   nh10
    add   rdx , rcx
  nh10:
    mov   rbx , 11
    cmp   rdx , rbx
    jne   nh11
    add   rdx , rcx
  nh11:
    mov   rbx , 12
    cmp   rdx , rbx
    jne   nh12
    add   rdx , rcx
  nh12:
    mov   rbx , 13
    cmp   rdx , rbx
    jne   nh13
    add   rdx , rcx
  nh13:
    mov   rbx , 14
    cmp   rdx , rbx
    jne   nh14
    add   rdx , rcx
  nh14:
    mov   rbx , 15
    cmp   rdx , rbx
    jne   nh15
    add   rdx , rcx
  nh15:
    add   rdx , 48
    mov  [rdi], dl
    dec   rdi
    dec   r8
    cmp   r8 , r9
    jne   htal1
    pop   r9
    pop   r8
    pop   rdi
    pop   rdx
    pop   rcx
    pop   rbx
    pop   rax

    ret

;
; Data area
;

text_pointers:

    dq    example_text_3
    dq    window_stack_text
    dq    boot_text
    dq    paging_table_use
    dq    cpuid_text

window_label:    db    'SYSTEM INFO',0
button_text_1:   db    'GENERAL',0
button_text_2:   db    'WSTACK',0
button_text_3:   db    'BOOT',0
button_text_4:   db    'PAGING',0
button_text_5:   db    'CPUID',0

buttonlabel:     dd    0,0
                 dd    1,button_text_1
                 dd    3,button_text_3
                 dd    4,button_text_4
                 dd    2,button_text_2
                 dd    5,button_text_5

hex_text:        db    '0x0000000000000000',0

fontsize:        dq   0
display_from:    dq   0
scroll_value:    dq   1000
ypos:            dq   0
dip:             dq   1
disover:         dq   0
lines:           dq   10
maxf:            dq   0x0

example_text_3:

    db   'Current running process slot . . .',0
    db   'Maximum process slot used  . . . .',0
    db   'Buttons in button list . . . . . .',0
    db   'PID of currently running process .',0
    db   'Background requests 0/1  . . . . .',0
    db   'Uptime in 1/100 seconds  . . . . .',0
    db   'Mouse x position . . . . . . . . .',0
    db   'Mouse y position . . . . . . . . .',0
    db   'Mouse buttons pressed  . . . . . .',0
    db   'Previous mouse x position  . . . .',0
    db   'Previous mouse y position  . . . .',0
    db   'If > uptime, do not draw mouse . .',0
    db   'Mouse picture on/off . . . . . . .',0
    db   'Pressed button ID  . . . . . . . .',0
    db   'Pressed button PID . . . . . . . .',0
    db   'Entries in window stack  . . . . .',0
    db   'Background X size  . . . . . . . .',0
    db   'Background Y size  . . . . . . . .',0
    db   'Background draw type . . . . . . .',0
    db   'Entries in process queue base  . .',0
    db   'Idle time stamp counter increment ',0
    db   'Idle time stamp count / second . .',0
    db   'Time stamp count at previous sec .',0
    db   'Time stamp count / second  . . . .',0
    db   'Window color . . . . . . . . . . .',0
    db   'Close button color . . . . . . . .',0
    db   'Hide button color  . . . . . . . .',0
    db   'Window button color  . . . . . . .',0
    db   'Window menu bar color  . . . . . .',0
    db   'Window menu open color . . . . . .',0
    db   'Round window edges . . . . . . . .',0
    db   '/HD/1/ Port  . . . . . . . . . . .',0
    db   '/HD/1/ Primary/Secondary . . . . .',0
    db   '/HD/1/ Enable  . . . . . . . . . .',0
    db   '/HD/1/ Partition . . . . . . . . .',0
    db   '/HD/1/ Irq . . . . . . . . . . . .',0
    db   '/FD/1/ Enable  . . . . . . . . . .',0
    db   '/FD/1/ Base  . . . . . . . . . . .',0
    db   '/FD/1/ IRQ . . . . . . . . . . . .',0
    db   'Entries in scroll base . . . . . .',0
    db   '/CD/1/ Port  . . . . . . . . . . .',0
    db   '/CD/1/ Primary/Secondary . . . . .',0
    db   '/CD/1/ Enable  . . . . . . . . . .',0
    db   '/CD/1/ IRQ . . . . . . . . . . . .',0
    db   'Window menu text color . . . . . .',0
    db   'Window skinning (0/1=off/on) . . .',0
    db   'Mouse scroll wheel value . . . . .',0
    db   'Amount of ram from config.mnt  . .',0
    db   'Uptime in 1/1000 secs  . . . . . .',0
    db   'Window transparency (0/1=off/on) .',0
    db   'Process start memory . . . . . . .',0
    db   'Transparency A . . . . . . . . . .',0
    db   'Transparency B . . . . . . . . . .',0
    db   'EHCI base  . . . . . . . . . . . .',0
    db   'USB state (0/1/2+=off/on/error)  .',0
    db   'USB device scan count  . . . . . .',0
    db   'USB legacy disable (0/1=off/on)  .',0
    db   'Transparency opacity (0/1/2) . . .',0
    db   'MTRR wbinvd (0/1=off/on) . . . . .',0
    db   'MCE (0/1=off/on) . . . . . . . . .',0
    db   'Window content (0/1=no/yes)  . . .',0
    db   'Window content interval  . . . . .',0
    db   'Socket states  . . . . . . . . . .',0
    db   'EHCI cache method  . . . . . . . .',0
    db   'MTRR delay . . . . . . . . . . . .',0 
    db   'SMP max cpu count  . . . . . . . .',0 
    db   'Mouse int.interval . . . . . . . .',0
    db   'Keyboard int.interval  . . . . . .',0
    db   'Stack send window size . . . . . .',0
    db   'Stack send cache size  . . . . . .',0
    db   'Stack send cache count . . . . . .',0
    db   'Stack send ACK num . . . . . . . .',0
    db   'Stack send ACK cache . . . . . . .',0
    db   'Stack send packet cache pos  . . .',0
    db   'Stack send cache pos . . . . . . .',0
    db   'Stack send cache limit . . . . . .',0
    db   'Stack resendq empty slots  . . . .',0
    db   'Stack debug type . . . . . . . . .',0
    db   'Stack debug data . . . . . . . . .',0
    db   'Mouse movement speed . . . . . . .',0
    db   'Transparency type  . . . . . . . .',0
    db   'MTRR init count  . . . . . . . . .',0
    db   'USB Mouse xy bits  . . . . . . . .',0
    db   'USB Mouse xy mask  . . . . . . . .',0
    db   'xxxxxxxxxxx'

boot_text:

    db   'Bits per pixel . . . . . . . . . .',0
    db   'Vesa video mode  . . . . . . . . .',0
    db   'Mouse port . . . . . . . . . . . .',0
    db   'Vesa 2.0 LFB address . . . . . . .',0
    db   'X resolution . . . . . . . . . . .',0
    db   'Y resolution . . . . . . . . . . .',0
    db   '[unused] . . . . . . . . . . . . .',0
    db   '[unused] . . . . . . . . . . . . .',0
    db   'Scanline length  . . . . . . . . .',0
    db   'Bytes per pixel  . . . . . . . . .',0
    db   'Mouse packet size  . . . . . . . .',0
    db   'Graphics (0/1=vesa/drv)  . . . . .',0
    db   'Bootup pixel count . . . . . . . .',0
    db   'xxxxxxxxxxx'

paging_table_use:

    db   'Paging Table Use (PID)            ',0
    db   'xxxxxxxxxxxx'

cpuid_text:

;   db   '                                                                    ',0
;   db   ' Processor ID (rax=0)                                               ',0
;   db   '                                                                    ',0

cpuid0a:
    db   'CPU vendor                                                          ',0
    db   '                                                                    ',0
;    db   ' Processor Info (rax=1)                                             ',0
;    db   '                                                                    ',0
cpuid1a:
    db   'Stepping                                                            ',0
    db   'Model                                                               ',0
    db   'Family                                                              ',0
    db   'Processor Type                                                      ',0
    db   'Extended Model                                                      ',0
    db   'Extended Family                                                     ',0
    db   '                                                                    ',0
cpuid1b:
    db   'Brand index                                                         ',0
    db   'CLFLUSH line size                                                   ',0
    db   'Max.addr.IDs for processors                                         ',0
    db   'Local APIC id                                                       ',0
    db   '                                                                    ',0
cpuid1c:
    db   'SSE3                                                                ',0
    db   'PCLMULQDQ                                                           ',0
    db   '64bit debug store                                                   ',0
    db   'MONITOR and MWAIT                                                   ',0
    db   'CPL qualified debug store                                           ',0
    db   'Virtual Machine extensions                                          ',0
    db   'Safer mode extensions                                               ',0
    db   'Enhanced SpeedStep                                                  ',0
    db   'Thermal Monitor 2                                                   ',0
    db   'Supplemental SSE3                                                   ',0
    db   'L1 context ID                                                       ',0
    db   'Silicon debug interface                                             ',0
    db   'Fused multiply-add (FMA3)                                           ',0
    db   'CMPXCHG16B                                                          ',0
    db   'Can disable task priority send                                      ',0
    db   'Perfmon & debug capability                                          ',0
    db   'Process context identifiers                                         ',0
    db   'Direct cache access for DMA write                                   ',0
    db   'SSE4.1                                                              ',0
    db   'SSE4.2                                                              ',0
    db   'X2APIC                                                              ',0
    db   'MOVBE                                                               ',0
    db   'POPCNT                                                              ',0
    db   'APIC one-shot operation with TSC                                    ',0
    db   'AES                                                                 ',0
    db   'XSAVE, XRESTOR, XSETBV, XGETBV                                      ',0
    db   'XSAVE enabled by OS                                                 ',0
    db   'Advanced Vector Extensions                                          ',0
    db   'F16C                                                                ',0
    db   'RDRAND                                                              ',0
    db   'Hypervisor                                                          ',0
    db   '                                                                    ',0
cpuid1d:
    db   'Onboard x87 FPU                                                     ',0
    db   'Virtual 8086 mode extensions                                        ',0
    db   'Debugging extensions                                                ',0
    db   'Page Size extension                                                 ',0
    db   'Time Stamp Counter                                                  ',0
    db   'Model-Specific registers                                            ',0
    db   'Physical Address Extension                                          ',0
    db   'Machine check exception                                             ',0
    db   'CMPXCHG8                                                            ',0
    db   'Onboard APIC                                                        ',0
    db   'Sysenter/Sysexit                                                    ',0
    db   'Memory Type Range Registers                                         ',0
    db   'Page global enable in CR4                                           ',0
    db   'Machine check architecture                                          ',0
    db   'Conditional move and FCMOV                                          ',0
    db   'Page attribute table                                                ',0
    db   '36bit page size extension                                           ',0
    db   'Processor serial number                                             ',0
    db   'CLFLUSH                                                             ',0
    db   'Debug store                                                         ',0
    db   'Onboard thermal control MSRs                                        ',0
    db   'MMX instructions                                                    ',0
    db   'FXSAVE, FXRESTOR                                                    ',0
    db   'SSE                                                                 ',0
    db   'SSE2                                                                ',0
    db   'CPU cache self snoop                                                ',0
    db   'Hyper-threading                                                     ',0
    db   'Therm.mon.autom.temp.limit                                          ',0
    db   'IA64 processor emulating x86                                        ',0
    db   'Pending Break enable                                                ',0

;    db   '                                                                    ',0
;    db   ' Extended Features (rax=7,rcx=0)                                    ',0
    db   '                                                                    ',0

cpuid_text70:
cpuid70b:
    db   'Access to base of fs and gs                                         ',0
    db   'IA32_TSC_ADJUST                                                     ',0
    db   'Software guard extensions                                           ',0
    db   'Bit manipulation instruction set 1                                  ',0
    db   'Transactional Sync.Ext.                                             ',0
    db   'Advanced Vector Ext. 2                                              ',0
    db   'Supervisor-mode exec.prev.                                          ',0
    db   'Bit manipulation ins.set 2                                          ',0
    db   'Enhanced rep movsb/stosb                                            ',0
    db   'INVPCID                                                             ',0
    db   'Transact.sync.ext.                                                  ',0
    db   'Platform Quality of Serv. Monitor                                   ',0
    db   'FPU CS,DS depricated                                                ',0
    db   'IntelMPX                                                            ',0
    db   'Platform Quality of Serv.Enf.                                       ',0
    db   'AVX-512 foundation                                                  ',0
    db   'AVX-512 dw and qw                                                   ',0
    db   'RDSEED                                                              ',0
    db   'Intel ADX                                                           ',0
    db   'Supervisor mode acc.prev.                                           ',0
    db   'AVX-512 Integer Fused mul-add                                       ',0
    db   'PCOMMIT                                                             ',0
    db   'CLFLUSHOPT                                                          ',0
    db   'CLWB                                                                ',0
    db   'Intel processor trace                                               ',0
    db   'AVX-512 prefetch                                                    ',0
    db   'AVX-512 exp. & rec.                                                 ',0
    db   'AVX-512 conflict detection                                          ',0
    db   'Intel sha                                                           ',0
    db   'AVX-512 byte and word                                               ',0
    db   'AVX-512 vector length ext.                                          ',0
    db   '                                                                    ',0
cpuid70c:
    db   'PREFETCHWT1                                                         ',0
    db   'AVX-512 vector bit manip. instr.                                    ',0
    db   'User mode instr.prevention                                          ',0
    db   'Mem.protect.keys for userm.pages                                    ',0
    db   'PKU enabled by OS                                                   ',0
    db   'AVX-512 vector pop. count d/q                                       ',0
    db   'Read processor ID                                                   ',0
    db   'SGX launch configuration                                            ',0
    db   '                                                                    ',0
cpuid70d:
    db   'AVX-512 neural network instr.                                       ',0
    db   'AVX-512 multiply acc.single prec.                                   ',0

;    db   '                                                                    ',0
;    db   ' Extended Info (rax=0x80000001)                                     ',0
    db   '                                                                    ',0

cpuid81c:
    db   'LAHF/SAHF in long mode                                              ',0
    db   'Hyperthreading not valid                                            ',0
    db   'Secure Virtual mode                                                 ',0
    db   'Extended APIC space                                                 ',0
    db   'CR8 in 32bit mode                                                   ',0
    db   'Advanced bit manipulation                                           ',0
    db   'SSE4a                                                               ',0
    db   'Misaligned SSE mode                                                 ',0
    db   'PREFETCH,PREFETCHW                                                  ',0
    db   'Os visible workaround                                               ',0
    db   'Instruction based sampling                                          ',0
    db   'XOP instruction set                                                 ',0
    db   'SKINIT/STGI                                                         ',0
    db   'Watchdog timer                                                      ',0
    db   'Light weight profiling                                              ',0
    db   '4 operands fused mul-add                                            ',0
    db   'Translation cache extension                                         ',0
    db   'NodeID MSR                                                          ',0
    db   'Trailing bit manipulation                                           ',0
    db   'Topology extensions                                                 ',0
    db   'Core preformance counter ext.                                       ',0
    db   'NB performance counter ext.                                         ',0
    db   'Data breakpoint extens.                                             ',0
    db   'Performance TSC                                                     ',0
    db   'L2I perf counter ext.                                               ',0
    db   '                                                                    ',0
cpuid_text81:
cpuid81d:
    db   'Onboard x87 FPU                                                     ',0
    db   'Virtual Mode extensions                                             ',0
    db   'Debugging ext.                                                      ',0
    db   'Page size ext.                                                      ',0
    db   'Time stamp counter                                                  ',0
    db   'Model spec.regs.                                                    ',0
    db   'Physical addr.ext.                                                  ',0
    db   'Machine check ext.                                                  ',0
    db   'CMPXCHG8                                                            ',0
    db   'Onboard APIC                                                        ',0
    db   'Syscall/sysret                                                      ',0
    db   'Memory Type Range Registers                                         ',0
    db   'Page global enable bit in CR4                                       ',0
    db   'Machine check architecture                                          ',0
    db   'Conditional move and FCMOV                                          ',0
    db   'Page attribute table                                                ',0
    db   '36bit page size ext.                                                ',0
    db   'Multiprocessor capable                                              ',0
    db   'NX bit                                                              ',0
    db   'Extended MMX                                                        ',0
    db   'MMX                                                                 ',0
    db   'FXSAVE,FXSTOR,CR4 bit 9                                             ',0
    db   'FXSAVE/FXSTOR optimiz.                                              ',0
    db   'Gibibyte pages                                                      ',0
    db   'RDTSCP                                                              ',0
    db   'Long mode                                                           ',0
    db   'Extended 3Dnow!                                                     ',0
    db   '3DNow!                                                              ',0
    db   'xxxxxxxxxxx'


window_stack_text:

    db   'Window Stack Use (PID)            ',0
    db   'xxxxxxxxxxx'


wstacknum:

    times 100 times 35 db ?

system_general:

    times 4096 db ?

IMAGE_END:






