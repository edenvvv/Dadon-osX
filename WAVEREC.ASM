;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   64 bit Menuet audio recorder
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
    dq    0x100000*60             ; Memory for app
    dq    0x0ffff0                ; Rsp
    dq    0x00                    ; Prm 
    dq    0x00                    ; Icon


include "textbox.inc"

wavelocation equ  0x100000
icolor       equ  0xd0d0d0
clearbuff    equ  0x080000

START:

    mov   rax , 141         ; Enable system font
    mov   rbx , 1
    mov   rcx , 1
    mov   rdx , 5 shl 32 + 5
    mov   r8  , 9 shl 32 + 12
    int   0x60

    call  draw_window       ; At first, draw the window

still:

    mov   rax , 23          ; Wait here for event
    mov   rbx , 10
    int   0x60

    test  rax , 0x1         ; Window redraw
    jnz   window_event
    test  rax , 0x2         ; Keyboard press
    jnz   key_event
    test  rax , 0x4         ; Button press
    jnz   button_event

    ; Save progress display

    cmp   [thread_command],byte 1
    jne   nodispth
    cmp   rbp , [threadposition]
    je    nodispth
    mov   rbp , [threadposition]
    push  rbp ; not saved during other fns.
    call  draw_location
    mov   rax , [threadposition]
    sub   rax , 0x100000
    imul  rax , 100
    mov   rbx , [writebuffer]
    and   rbx , 0xfff0000
    sub   rbx , 0x100000
    add   rbx , 1
    xor   rdx , rdx
    div   rbx
    mov   rcx , rax
    mov   rax , 47
    mov   rbx , 2*65536
    mov   rdx , 190 shl 32 + 66
    mov   rsi , 0xffffff
    int   0x60
    mov   rax , 4
    mov   rbx , string_p
    mov   rcx , 190+6*2
    mov   rdx , 66
    mov   r9  , 1
    mov   rsi , 0xffffff
    int   0x60
    pop   rbp
  nodispth:
    ; Clear display
    cmp   [thread_command],byte 3
    jne   nodispth2
    call  draw_location
    mov   [thread_command],byte 0
  nodispth2:

    jmp   still


window_event:

    call  draw_window
    jmp   still         

key_event:

    mov   rax , 0x2        ; Read the key and ignore
    int   0x60
    jmp   still        



thread_write:

    mov   r15 , wavelocation

  twl5:

    mov   [threadposition],r15

    mov   r14 , r15
    add   r14 , 65536
    cmp   r14 , [writebuffer]
    jae   twl10

    mov   rax , 58
    mov   rbx , 4
    mov   rcx , 0
    mov   rdx , 65536
    mov   r8  , r15
    mov   r9  , string_filename
    int   0x60

    add   r15 , rdx

    mov   rax , 5
    mov   rbx , 1
    int   0x60

    cmp   [thread_command],byte 1
    je    twl5

  twl10:

    mov   [thread_command],byte 3

    mov   rax , 512
    int   0x60




recordaudio:

    call  check_input_device

    cmp   [cardhz],dword 0
    je    recordsongret

    mov   r14 , 0            ; current playbuffer

    mov   rdi , wavelocation
    mov   rsi , waveheader
    mov   rcx , waveheaderend-waveheader
    cld
    rep   movsb

    mov   r15 , rdi ; start wave position
    mov   [writebuffer],r15

    ; Record command

    mov   rax , 117
    mov   rbx , 1003
    int   0x60

  waitmore:

    ; Get current recordbuffer (0/1)

    mov   rax , 117
    mov   rbx , 1004
    int   0x60

    cmp   rbx , r14
    jne   nowantedblock

    ; Copy data from nonactive recordbuffer (0/1)

    mov   rax , 117
    mov   rbx , 1002
    mov   rcx , r15 ; wave position
    mov   rdx , r14 ; playbuffer  
    add   rdx , 1
    and   rdx , 1
    int   0x60

    add   r15 , 16384

    add   r14 , 1
    and   r14 , 1

  nowantedblock:

    mov   [writebuffer],r15

    push  r14 r15 
    mov   rax , r15
    sub   rax , wavelocation
    mov   rbx , 48000*4
    xor   rdx , rdx
    div   rbx
    mov   [filelength],rax
    add   rax , 1000
    cmp   [sc],rax
    je    nodrw2
    mov   [sc],rax
    call  draw_location
  nodrw2:
    pop   r15 r14

    cmp   r15 , wavelocation+48000*4*300
    jae   audiodone

    mov   rax , 23
    mov   rbx , 1
    int   0x60
    cmp   rax , 0
    je    waitmore
    test  rax , 1
    jz    nodrawwin
    push  r14 r15
    call  draw_window
    pop   r15 r14
    jmp   waitmore
  nodrawwin:

  audiodone:

    ; Stop recording at button press

    mov   rax , 117
    mov   rbx , 1005
    int   0x60

    ; Free device

    mov   rax , 117
    mov   rbx , 1255
    int   0x60

    mov   [sc],dword 1000
    call  draw_scroll
    call  draw_info
    call  draw_location

  recordsongret:

    ret


playaudio:

    call  check_output_device

    cmp   [cardhz],dword 0
    je    playsongret

    call  clear_buffers

    mov   r14 , 0            ; current playbuffer
    mov   r15 , wavelocation ; start wave position

    cmp   [filelength],dword 0
    je    addzero
    mov   rax , [writebuffer]
    sub   rax , 0x100000
    mov   rbx , [sc]
    sub   rbx , 1000
    imul  rax , rbx
    mov   rbx , [filelength]
    xor   rdx , rdx
    div   rbx
    add   r15 , rax
  addzero:
    and   r15 , 0xfffffff-3
    add   r15 , 44 ; header

    ; Play command

    mov   rax , 117
    mov   rbx , 3
    int   0x60

  waitmoreplay:

    ; Get current playbuffer (0/1)

    mov   rax , 117
    mov   rbx , 4
    int   0x60

    cmp   rbx , r14
    jne   nowantedblockplay

    ; Give data for nonactive playbuffer (0/1)

    mov   rax , 117
    mov   rbx , 2
    mov   rcx , r15 ; wave position
    mov   rdx , r14 ; playbuffer
    add   rdx , 1
    and   rdx , 1
    int   0x60

    add   r15 , 16384

    add   r14 , 1
    and   r14 , 1

  nowantedblockplay:

    push  r14 r15
    mov   rax , r15
    sub   rax , wavelocation
    mov   rbx , 48000*4
    xor   rdx , rdx
    div   rbx
    add   rax , 1000
    cmp   [sc],rax
    je    nodrw
    mov   [sc],rax
    call  draw_location
    call  draw_scroll
  nodrw:
    pop   r15 r14

    cmp   r15 , [writebuffer] ; wavelocation+20*16384
    jae   audiodoneplay

    mov   rax , 23
    mov   rbx , 1
    int   0x60
    cmp   rax , 0
    je    waitmoreplay
    test  rax , 1
    jz    nodrawwinplay
    push  r14 r15
    call  draw_window
    pop   r15 r14
    jmp   waitmoreplay

  audiodoneplay:

    mov   [sc],dword 1000

  nodrawwinplay:

    ; Stop playing at button press

    mov   rax , 117
    mov   rbx , 5
    int   0x60

    ; Free device

    mov   rax , 117
    mov   rbx , 255
    int   0x60

    call  draw_scroll
    call  draw_info
    call  draw_location

  playsongret:

    ret



clear_buffers:

    mov   rdi , clearbuff
    mov   rcx , 65536
    mov   rax , 0
    cld
    rep   stosb

    mov   rax , 117
    mov   rbx , 2
    mov   rcx , clearbuff
    mov   rdx , 0
    int   0x60

    mov   rax , 117
    mov   rbx , 2
    mov   rcx , clearbuff
    mov   rdx , 1
    int   0x60

    ret



check_output_device:

    ; Device available

    mov   rax , 117
    mov   rbx , 1
    int   0x60
    cmp   rax , 0
    jne   device_not_available

    ; Audio format

    mov   rax , 117
    mov   rbx , 7
    mov   rcx , 0
    int   0x60

    mov   rdx , 0xffffffffff shl 24
    mov   rcx , rbx
    and   rcx , rdx
    mov   rdx , 0x4000010210 shl 24
    cmp   rcx , rdx ; buffer 16384 : sign extended lsb : 2 channel : 16bit/ch
    jne   not_supported_output

    mov  [cardhz],bx
    ret

  not_supported_output:
  device_not_available:

    mov   rax , 4
    mov   rbx , unsupported
    mov   rcx , 30
    mov   rdx , 55
    mov   r9  , 1
    mov   rsi , 0x000000
    int   0x60

    mov   rax , 23
    mov   rbx , 125
    int   0x60

    mov   rax , 4
    mov   rbx , unsupported
    mov   rcx , 30
    mov   rdx , 55
    mov   r9  , 1
    mov   rsi , 0xffffff
    int   0x60

    mov   [cardhz],dword 0
    ret




check_input_device:

    ; Device available

    mov   rax , 117
    mov   rbx , 1001
    int   0x60
    cmp   rax , 0
    jne   device_not_available_input

    ; Audio format 

    mov   rax , 117
    mov   rbx , 1007
    mov   rcx , 0
    int   0x60

    mov   rdx , 0xffffffffff shl 24
    mov   rcx , rbx
    and   rcx , rdx
    mov   rdx , 0x4000010210 shl 24
    cmp   rcx , rdx ; buffer 16384 : sign extended lsb : 2 channel : 16bit/ch
    jne   not_supported_input

    mov   [cardhz],bx
    call  draw_info

    ret

  not_supported_input:
  device_not_available_input:

    mov   rax , 4
    mov   rbx , unsupported
    mov   rcx , 30
    mov   rdx , 55
    mov   r9  , 1
    mov   rsi , 0x000000
    int   0x60

    mov   rax , 23
    mov   rbx , 125
    int   0x60

    mov   rax , 4
    mov   rbx , unsupported
    mov   rcx , 30
    mov   rdx , 55
    mov   r9  , 1
    mov   rsi , 0xffffff
    int   0x60

    mov   [cardhz],dword 0
    ret



button_event:

    mov   rax , 0x11
    int   0x60

    ; rax = status
    ; rbx = button id

    cmp   rbx , 1            ; Record audio
    jne   no_record
    call  recordaudio
    jmp   still
  no_record:

    cmp   rbx , 2            ; Stop audio
    jne   no_stop
    mov   [thread_command],byte 2
    jmp   still
  no_stop:

    cmp   rbx , 3            ; Save audio
    jne   no_save
    mov   rax , 58
    mov   rbx , 0
    mov   rcx , 0
    mov   rdx , 1
    mov   r8  , clearbuff
    mov   r9  , string_filename
    int   0x60
    cmp   rax , 0
    jne   startsave
    mov   rax , 4
    mov   rbx , string_exists
    mov   rcx , 22
    mov   rdx , 176
    mov   r9  , 1
    mov   rsi , 0x000000
    int   0x60
    mov   rax , 10
    int   0x60
    test  rax , 10b
    jnz   check2
  cancel:
    mov   rax , 4
    mov   rbx , string_exists
    mov   rcx , 22
    mov   rdx , 176
    mov   r9  , 1
    mov   rsi , 0xffffff
    int   0x60
    jmp   still
  check2:
    mov   rax , 0x2        ; Read the key and ignore
    int   0x60
    cmp   rcx , '2'
    jne   cancel
    ; Overwrite
    call  draw_window
    mov   rax , 58
    mov   rbx , 2
    mov   rcx , 0
    mov   rdx , 0
    mov   r8  , clearbuff
    mov   r9  , string_filename
    int   0x60
  startsave:
    cmp   [writebuffer],dword wavelocation
    je    still
    ; Start write thread
    mov   [thread_command],byte 1
    mov   rax , 51
    mov   rbx , 1
    mov   rcx , thread_write
    mov   rdx , thread_stack
    int   0x60
    jmp   still
  no_save:

    cmp   rbx , 4            ; Record audio
    jne   no_play
    call  playaudio
    jmp   still
  no_play:

    cmp   rbx , 11
    jne   no_textbox1
    mov   r14 , textbox1
    call  read_textbox
    jmp   still
  no_textbox1:

    cmp   rbx , 1000
    jb    no_scroll
    cmp   rbx , 1999
    ja    no_scroll
    mov   [sc],rbx
    call  draw_scroll
    call  draw_location
    jmp   still
  no_scroll:

    cmp   rbx , 0x10000001   ; Close button
    je    terminate_program
    cmp   rbx , 0x102        ; Menu selection
    je    terminate_program

    jmp   still


terminate_program:

    cmp   [thread_command],dword 1
    jne   doterm
    mov   [thread_command],byte 2
    jmp   still
  doterm:
    mov   rax , 512
    int   0x60


draw_window:

    mov   rax , 0xC                          ; Beginning of window draw
    mov   rbx , 0x1
    int   0x60

    mov   rax , 0x0                          ; Draw window
    mov   rbx , 300 shl 32 + 241           ; x start & size
    mov   rcx , 60 shl 32 + 193            ; y start & size
    mov   rdx , 0x0000000000FFFFFF           ; type    & border color  
    mov   r8  , 0x0000000000000001           ; draw flags
    mov   r9  , window_label                 ; 0 or label - asciiz
    mov   r10 , menu_struct                  ; 0 or pointer to menu struct
    int   0x60

    call  draw_location
    call  draw_scroll
    call  draw_info

    mov   rax , 8
    mov   rbx , 20 * 0x100000000 + 50
    mov   rcx , 124 * 0x100000000 + 20
    mov   rdx , 1
    mov   r8  , 0
    mov   r9  , button1
    int   0x60
    mov   rax , 8
    mov   rbx , 70 * 0x100000000 + 50
    mov   rcx , 124 * 0x100000000 + 20
    mov   rdx , 2
    mov   r8  , 0
    mov   r9  , button2
    int   0x60
    mov   rax , 8
    mov   rbx , 120 * 0x100000000 + 50
    mov   rcx , 124  * 0x100000000 + 20
    mov   rdx , 4
    mov   r8  , 0
    mov   r9  , button4
    int   0x60
    mov   rax , 8
    mov   rbx , 170 * 0x100000000 + 50
    mov   rcx , 124  * 0x100000000 + 20
    mov   rdx , 3
    mov   r8  , 0
    mov   r9  , button3
    int   0x60

    mov   r14 , textbox1
    call  draw_textbox

    mov   rax , 0xC
    mov   rbx , 0x2
    int   0x60

    ret



draw_scroll:

    mov   rax , 113
    mov   rbx , 2
    mov   rcx , 1000
    mov   rdx , [filelength]
    add   rdx , 1
    mov   r8  , [sc]
    mov   r9  , 100
    mov   r10 , 20
    mov   r11 , 200
    int   0x60

    ret


draw_location:

    mov   rax , 13
    mov   rbx ,120 * 0x100000000 + 100
    mov   rcx , 50 * 0x100000000 + 40
    mov   rdx , 0x000000
    int   0x60

    ; Seconds

    mov   rax , [sc]
    sub   rax , 1000
    xor   rdx , rdx
    mov   rbx , 10
    div   rbx
    push  rax
    mov   r8  , rdx
    mov   r13 , 140+25
    mov   r14 , 65
    call  cdnumber
    pop   rax
    xor   rdx , rdx
    mov   rbx , 10
    div   rbx
    mov   r8  , rax
    mov   r13 , 116+25
    mov   r14 , 65
    push  rdx
    call  cdnumber
    pop   r8
    mov   r13 , 128+25
    mov   r14 , 65
    call  cdnumber

    ret

cdnumber:

    shl   r13 , 32
    shl   r14 , 32

    imul  r8  , 7
    add   r8  , lines
    mov   r9  , coord
    mov   r10 , 7
  newline2:
    cmp  [r8], byte 1
    jne   nonewline
    mov   rax , 13
    mov   rbx , [r9]
    mov   rcx , [r9+8]
    mov   rdx , 0xffffff
    add   rbx , r13
    add   rcx , r14
    int   0x60
  nonewline:
    inc   r8
    add   r9 , 16
    dec   r10
    jnz   newline2

    ret


draw_info:

    mov   rax , 13
    mov   rbx , 20 * 0x100000000 + 100
    mov   rcx , 50 * 0x100000000 +  40
    mov   rdx , 0x000000
    int   0x60

    mov   rax , 4
    mov   rbx , text
    mov   rcx , 42
    mov   rdx , 61
    mov   r9  , 1
    mov   rsi , icolor
    int   0x60
    add   rbx , 6
    mov   rdx , 72
    int   0x60

    mov   rax , 47
    mov   rbx , 5*65536
    mov   rcx , [filehz]
    mov   rdx , 82*65536+61
    mov   rsi , icolor
    mov   rdi , 0
    int   0x40

    mov   rax , 47
    mov   rbx , 5*65536
    mov   rcx , [cardhz]
    mov   rdx , 82*65536+72
    mov   rsi , icolor
    mov   rdi , 0
    int   0x40

    ret



;
; Data area
;

lines:  db  1,1,1,0,1,1,1
        db  0,0,1,0,0,1,0
        db  1,0,1,1,1,0,1
        db  1,0,1,1,0,1,1
        db  0,1,1,1,0,1,0
        db  1,1,0,1,0,1,1
        db  1,1,0,1,1,1,1
        db  1,0,1,0,0,1,0
        db  1,1,1,1,1,1,1
        db  1,1,1,1,0,1,1

coord:  dq  1  * 0x100000000 + 8
        dq  0  * 0x100000000 + 1
        dq  0  * 0x100000000 + 1
        dq  1  * 0x100000000 + 4
        dq  9  * 0x100000000 + 1
        dq  1  * 0x100000000 + 4
        dq  1  * 0x100000000 + 8
        dq  5  * 0x100000000 + 1
        dq  0  * 0x100000000 + 1
        dq  6  * 0x100000000 + 4
        dq  9  * 0x100000000 + 1
        dq  6  * 0x100000000 + 4
        dq  1  * 0x100000000 + 8
        dq  10 * 0x100000000 + 1

textbox1:

    dq    0x40000   ; Type0
                    ; bit 16 - clear at doubleclick
                    ; bit 17 - set edit position according to mouse
                    ; bit 18 - enable utf8 (max 4 byte/char)
    dq    22        ; X position
    dq    198       ; X size
    dq    156       ; Y position
    dq    11        ; Button ID
    dq    16        ; Current text length
string_filename: 
    db    '/usb/1/audio.wav'
    times 96 db 0   ; Text

window_label: db  'WAVE RECORDER',0
button1:      db  'RECORD',0                          
button2:      db  'STOP',0
button3:      db  'SAVE',0
button4:      db  'PLAY',0
unsupported:  db  'Unable to detect audio.',0
string_exists:db  'File exists,1=Cancel,2=Overwrite?',0
recording:    db  'Recording..',0
text:         db  'File:',0,'Card:',0
string_p:     db '%',0

cardhz:       dq  0x0
multiplier:   dq  0x0
blockwait:    dq  0x0
filehz:       dq  48000
sc:           dq  1000
filelength:   dq  300

writebuffer:    dq wavelocation
thread_command: dq 0x0
threadposition: dq 0x0

waveheader:

    db    'RIFF'             ; Chunk1
    dd    48000*4*60*60+36
    dd    'WAVE'
    dd    'fmt '             ; Chunk2
    dd    16
    dw    1
    dw    2
    dd    48000
    dd    48000*2*2
    dw    4
    dw    16
    dd    'data'             ; Chunk3
    dd    48000*4*60*60      ; 1 hour

waveheaderend:


menu_struct:               ; Menu Struct

    dq   0                 ; Version
    dq   0x100             ; Start value of ID to return ( ID + Line )
                           ; Returned when menu closes and
                           ; user made no selections.
    db   0,'FILE',0        ; ID = 0x100 + 1
    db   1,'Quit',0        ; ID = 0x100 + 2
    db   255               ; End of Menu Struct

                 times 100 dq ?
thread_stack:    times 100 dq ?


sine: times 3600 dq ?

image_end:


