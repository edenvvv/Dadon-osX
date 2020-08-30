;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Mixer for Menuet64
;
;   Compile with FASM 1.60 or above
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

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

scl equ 20

START:

    mov   rax , 141
    mov   rbx , 1
    mov   rcx , 1
    mov   rdx , 5 shl 32 + 5
    mov   r8  , 9 shl 32 + 12
    int   0x60

    call  read_mixer_values

    call  draw_window       ; At first, draw the window

still:

    mov   rax , 23          ; Wait here for event
    mov   rbx , 2 
    int   0x60

    test  rax , 0x1         ; Window redraw
    jnz   window_event
    test  rax , 0x2         ; Keyboard press
    jnz   key_event
    test  rax , 0x4         ; Button press
    jnz   button_event

    call  read_mixer_values
    call  draw_scrolls

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

    cmp   rbx , 0x105
    jne   no_application_terminate_menu
    mov   rax , 0x200
    int   0x60
  no_application_terminate_menu:

    cmp   rbx , 0x103
    jne   no_button
    mov   al , [micboost]
    add   al , 1
    and   al , 1
    mov   [micboost], al
    call  set_values
    call  draw_scrolls
    mov   rax , 117
    mov   rbx , 1001
    int   0x60
    cmp   rax , 0
    jne   still
    mov   rax , 117
    mov   rbx , 1003
    int   0x60
    mov   rax , 5
    mov   rbx , 100
    int   0x60
    mov   rax , 117
    mov   rbx , 1255
    int   0x60
    jmp   still
  no_button:

    cmp   rbx , 0x102
    jne   no_button2
    mov   rax , 13
    mov   rbx , 10 shl 32 + 220
    mov   rcx , 50 shl 32 + 180-80+38-10
    mov   rdx , 0xf0f0f0
    int   0x60
    mov   rax , 4 
    mov   rbx , text3
    mov   rcx , 22
    mov   rdx , 60
    mov   rsi , 0x0
    mov   r9  , 0x1
  nextline:
    int   0x60
    add   rbx , 36
    add   rdx , 16
    cmp   [rbx],byte '_'
    jne   nextline
    mov   rax , 10
    int   0x60
    call  draw_window
    jmp   still
  no_button2:

    cmp   rbx , 1000
    jb    noscroll
    mov   rax , rbx
    mov   rcx , 1000
    xor   rdx , rdx
    div   rcx
    dec   rax
    imul  rax , 8
    add   rax , sc
    mov  [rax+4*8],rbx
    call  draw_scrolls
    call  set_values
    jmp   still
  noscroll:

    jmp   still


draw_window:

    mov   rax , 0xC                          ; Beginning of window draw
    mov   rbx , 0x1
    int   0x60

    mov   rax , 0x0                          ; Draw window
    mov   rbx , 361 shl 32 + 240             ; x start & size
    mov   rcx , 104 shl 32 + 202+07+scl       ; y start & size
    mov   rdx , 0x0000000000FFFFFF           ; type    & border color  
    mov   r8  , 0x0000000000000001           ; draw flags
    mov   r9  , window_label                 ; 0 or label - asciiz
    mov   r10 , menu_struct                  ; 0 or pointer to menu struct
    int   0x60

    mov   rax , 0x4                          ; Display text
    mov   rbx , text
    mov   rcx , 16
    mov   rdx , 180+scl-4
    mov   rsi , 0x0
    mov   r9  , 0x1
    int   0x60
    add   rcx , 29*6
    mov   rbx , text2
    add   rcx , 3
    int   0x60

    mov   [micboostsave],dword 100
    call  draw_booststate

    mov   rdi , sc
    mov   rax , 0
    mov   rcx , 4
    cld
    rep   stosq

    call  draw_scrolls

    mov   rax , 0xC                          ; End of window draw
    mov   rbx , 0x2
    int   0x60

    ret


draw_booststate:

    mov   rax , [micboost]
    cmp   rax , [micboostsave]
    je    drb

    mov   [micboostsave],rax

    mov   rax , 'OFF '
    mov   rbx , 'OFF)'
    cmp   [micboost],byte 1
    jne   nomicon
    mov   rax , 'ON  '
    mov   rbx , 'ON) '
  nomicon:
    mov   [micbt+8],eax
    mov   [text4+5],ebx

    mov   rax , 13
    mov   rbx , 170 shl 32 + 60
    mov   rcx , (190+scl-4) shl 32 + 16
    mov   rdx , 0xffffff
    int   0x60

    mov   rax , 0x4                          ; Display text
    mov   rbx , text4
    mov   rcx , 16+3+26*6
    cmp   [micboost],byte 1
    jne   noxadd
    add   rcx , 3
  noxadd:
    mov   rdx , 180+14+scl-5
    mov   rsi , 0;x808080
    mov   r9  , 0x1
    int   0x60

  drb:

    ret




draw_scrolls:

    mov   r15 , 0

  newmixer:

    mov   rax , 113
    mov   rbx , 1
    mov   rcx , r15
    imul  rcx , 1000
    add   rcx , 1000
    mov   rdx , 32  
    mov   r8  , r15
    imul  r8  , 8
    add   r8  , sc      
    mov   r14 , [r8+4*8]
    cmp   r14 , [r8]
    je    no_scroll_change
    mov   [r8], r14
    mov   r8  , r14
    mov   r9  , r15
    imul  r9  , 54
    add   r9  , 33
    mov   r10 , 51
    mov   r11 , 117+scl
    int   0x60
  no_scroll_change:

    inc   r15
    cmp   r15 , 3
    jbe   newmixer

    call  draw_booststate

    ret


set_values:

    mov   r15 , 0

  newsetvalue:

    mov   rax , 117
    mov   rbx , 6
    mov   rcx , r15
    mov   r9  , r15
    imul  r9  , 8
    mov   r9  , [sc+r9]
    and   r9  , 0xffff

    mov   r8  , r15 
    inc   r8
    imul  r8  , 1000

    sub   r9  , r8     ; 31-0 -> 0-255,0-255
    imul  r9  , 0x08
    mov   rdx , 0xff
    and   r9  , 0xff
    sub   rdx , r9
    imul  rdx , 0x0101

    cmp   r15 , 3
    jne   nomic
    mov   rax , 117
    mov   rbx , 1006
    mov   rcx , 0
  nomic:

    int   0x60

    inc   r15
    cmp   r15 , 3
    jbe   newsetvalue

    mov   rax , 117
    mov   rbx , 1006
    mov   rcx , 1
    mov   rdx , [micboost]
    and   rdx , 1
    int   0x60

    ret


read_mixer_values:

    mov   r15 , 0

    mov   [micboost],byte 0

  readnext:

    cmp   r15 , 3
    jne   nomic2
    mov   rax , 117
    mov   rbx , 1006
    mov   rcx , 0x1000
    int   0x60
    jmp   testvalue
  nomic2:

    mov   rax , 117
    mov   rbx , 6
    mov   rcx , 0x1000
    add   rcx , r15
    int   0x60

  testvalue:

    cmp   rax , 0
    jne   no_set_values

    mov   rax , rbx  ; 0-255,0-255 -> 31-0
    mov   rbx , 0xff
    and   rax , 0xff 
    sub   rbx , rax
    shr   rbx , 3

    mov   rax , r15
    imul  rax , 1000
    add   rax , 1000
    add   rbx , rax   

    mov   rax , r15
    imul  rax , 8
    add   rax , sc+4*8

    mov   [rax],rbx

    inc   r15
    cmp   r15 , 3
    jbe   readnext

  no_set_values:

    mov   rax , 117
    mov   rbx , 1006
    mov   rcx , 0x1000+1
    int   0x60
    and   rbx , 1
    mov   [micboost],rbx

    ret


;
; Data area
;

window_label:  

    db    'MIXER',0

sc:  

    dq    0x0    ; Values
    dq    0x0 
    dq    0x0 
    dq    0x0 
    dq    1023   ; Change
    dq    2023
    dq    3023
    dq    4023

micboost:     dq 0x0
micboostsave: dq 100

menu_struct:

       dq   0                           ; Version
       dq   0x100                       ; Start value of ID to return (ID+Line)
       db   0,'SETUP',0                 ; ID = 0x100 + 1
       db   1,'Info..',0                ; ID = 0x100 + 4
micbt: db   1,'MicAmp:OFF         ',0   ; ID = 0x100 + 4
       db   1,'-',0                     ; ID = 0x100 + 5
       db   1,'Quit',0                  ; ID = 0x100 + 6
       db   255                         ; End of Menu Struct

text:    db    '  MAIN      CD      WAVE          ',0          
text2:   db    'MIC',0
text3:   db    'MicAmp will be applied when sound  ',0
         db    'recording is started next time.    ',0
         db    'Hardware microphone impedance      ',0
         db    'adjustment may take upto a minute  ',0
         db    'to complete.                       ',0
         db    '_'
text4:   db    '(AMP:OFF)        ',0

image_end:







