;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   64 bit Menuet freeform and transparency example
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
    dq    0x200000                ; Memory for app
    dq    0x7fff0                 ; Rsp
    dq    0x00                    ; Prm 
    dq    0x00                    ; Icon

; 0x07fff0 - stack
; 0x080000 - image
; 0x100000 - freeform bytemap (256x256 bytes)
;            (0=bgr pixel,1=visible pixel,2=transparent pixel)

START:

    mov   rax , 26
    mov   rbx , 3
    mov   rcx , 0x40000
    mov   rdx , 256
    int   0x60

    call  calculate_image

    call  define_freeform

    call  draw_window       ; At first, draw the window

still:

    mov   rax , 10          ; Wait here for event
    int   0x60

    test  rax , 1           ; Window redraw
    jnz   window_event
    test  rax , 2           ; Keyboard press
    jnz   key_event
    test  rax , 4           ; Button press
    jnz   button_event

    jmp   still

window_event:

    call  draw_window

    jmp   still

key_event:

    mov   rax , 2          ; Read the key and ignore
    int   0x60

    mov   rax , 0x200
    int   0x60

    jmp   still

button_event:

    mov   rax , 17
    int   0x60

    ; rax = status
    ; rbx = button id

    mov   rax , 0x200
    int   0x60

    jmp   still


calculate_image:

    ; Image (256x256)

    mov   rdi , 0x080000
    mov   rax , 0x000001
    mov   rbx , 0
  newpix:
    push  rax
    mov   rcx , rax
    shr   rcx , 2
    and   rcx , 0x3f3f3f
    sub   rax , rcx
    mov   [rdi],eax
    pop   rax
    add   rax , 0x0100
    add   rdi , 3
    add   rbx , 1
    cmp   rdi , 0x080000+256*256*3
    jb    newpix

    ret


decode_external:

    ; PNG image

    mov   rax , 256
    mov   rbx , runpng
    mov   rcx , param
    int   0x60

    push  rbx

    ; Draw.asm IPC area at 6 MB

    mov   rax , 0
    mov   [0x180000-32],rax
    mov   rax , 16
    mov   [0x180000-24],rax
    mov   [0x180000],dword 123123

    ; Define IPC

    mov   rax , 60
    mov   rbx , 1
    mov   rcx , 0x180000-32
    mov   rdx , 0x80000
    int   0x60

    ; My PID

    mov   rax , 111
    mov   rbx , 1
    int   0x60
    mov   [0x160000-8],rax

    ; Send picture

    mov   rbp , 0

  newsendtry:

    mov   rax , 5
    mov   rbx , 1
    int   0x60

    mov   rax , 60
    mov   rbx , 2
    pop   rcx
    mov   rdx , 0x160000-8
    mov   r8  , 8192
    int   0x60

    cmp   rax , 0
    je    sendsuccess

    add   rbp , 1
    cmp   rbp , 25
    jb    newsendtry

  sendsuccess:

    mov   rdi , 0

  waitmore:

    inc   rdi
    cmp   rdi , 100*60*2 ; 2 minute timeout
    ja    notransformation

    mov   rax , 5
    mov   rbx , 1
    int   0x60

    cmp   [0x180000],dword 123123
    je    waitmore

  notransformation:

    ret




define_freeform:

    ; Load file (256x256)

    mov   rax , 58
    mov   rbx , 0
    mov   rcx , 0
    mov   rdx , -1
    mov   r8  , 0x160000
    mov   r9  , filename
    int   0x60

    call  decode_external

    ; Create transparency bytemap from loaded image

    mov   r8  , 0x180000
    mov   rsi , 0x100000
    mov   rdi , 0x080000
    mov   r9  , 1
  newconv:

    mov   cl  , [r8]

    ; Set window pixel to visible or transparent

    mov   al  , 2
    mov   bl  , 1
    cmp   cl  , 0
    cmovnz rax , rbx
    mov   [rsi],al

    ; Set transparent areas to single color

    cmp   al  , 2
    jne   noredremove
    mov   byte [rdi+0],byte 0x40
    mov   byte [rdi+1],byte 0x30
    mov   byte [rdi+2],byte 0x20
    ; Window move area
    cmp   rdi , 0x080000+256*23*3
    jae   noredremove
    mov   byte [rdi+0],byte 0x1
    mov   byte [rdi+1],byte 0x1
    mov   byte [rdi+2],byte 0x1
  noredremove:

    ; Next bit

    add   rdi , 3
    add   rsi , 1

    ; Next byte

    add   r8  , 3
    cmp   rsi , 0x100000+256*256
    jbe   newconv

    ; Visible button area

    mov   rdi , 0x100000+5*256+5
    mov   rax , 1
  newbuttonbgr:
    push  rdi
    mov   rcx , 14
    cld
    rep   stosb
    pop   rdi
    add   rdi , 256
    cmp   rdi , 0x100000+19*256+5
    jb    newbuttonbgr

    ; Give pointer to freeform data

    mov   rax , 50
    mov   rbx , 0
    mov   rcx , 0x100000
    int   0x60

    ret



draw_window:

    mov   rax , 12                           ; Beginning of window draw
    mov   rbx , 1
    int   0x60

    mov   rax , 0                            ; Draw window
    mov   rbx , [0x40000+8*4]
    sub   rbx , 322
    shl   rbx , 32
    add   rbx , 256                          ; X start & size
    mov   rcx , 43 shl 32 + 256             ; Y start & size
    mov   rdx , 0x4000000100FFFFFF           ; Type    & border color  
    mov   r8  , 0x0000000000000001           ; Flags (set as 1)
    mov   r9  , window_label                 ; 0 or label - asciiz
    mov   r10 , 0                            ; 0 or pointer to menu struct
    int   0x60

    mov   rax , 7
    mov   rbx , 0 shl 32 + 256
    mov   rcx , 0 shl 32 + 256
    mov   rdx , 0x080000
    mov   r8  , 0
    mov   r9  , 0x1000000
    mov   r10 , 3
    int   0x60

    mov   rax , 8
    mov   rbx , 5 shl 32 + 14
    mov   rcx , 5 shl 32 + 14
    mov   rdx , 10
    mov   r8  , 0
    mov   r9  , 0
    int   0x60

    mov   rax , 12                           ; End of window draw
    mov   rbx , 2
    int   0x60

    ret

;
; Data area
;

window_label:  db  'FREEFORM',0
filename:      db  '\sysdir\shape.png',0
runpng:        db  '\sysdir\pngview',0
param:         db  'PARAM',0

image_end:

