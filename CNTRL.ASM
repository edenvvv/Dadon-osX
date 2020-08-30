;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   64 bit Menuet controls example
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
    dq    0xffff0                 ; Rsp
    dq    0x00                    ; Prm 
    dq    0x00                    ; Icon


START:

    mov   rax , 141         ; Enable system font
    mov   rbx , 1
    mov   rcx , 1
    mov   rdx , 5 shl 32 + 5
    mov   r8  , 9 shl 32 + 12
    int   0x60

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

    mov   rax , 2           ; Read the key and ignore
    int   0x60

    jmp   still

button_event:

    mov   rax , 17                        ; Get data
    int   0x60

    ; rax = status
    ; rbx = button id

    cmp   rbx , 300                       ;  Vertical scroll
    jb    no_vertical_scroll
    cmp   rbx , 319
    ja    no_vertical_scroll
    mov   [button_id],rbx
    call  write_button_id
    mov   [vscroll_value], rbx
    call  draw_vertical_scroll
    jmp   still
  no_vertical_scroll:
                                          
    cmp   rbx , 0x10000001                ; Button - Close application
    jne   no_application_terminate_button
    mov   rax , 512
    int   0x60
  no_application_terminate_button:

    cmp   rbx , 20                        ; Clickme button  
    jne   no_clickme
    mov   [button_id],rbx
    call  write_button_id
    jmp   still
  no_clickme:

    cmp   rbx , 106                       ; Menu - Close application
    jne   no_application_terminate_menu
    mov   rax , 512
    int   0x60
  no_application_terminate_menu:

    cmp   rbx , 100                       ; Menu
    jb    no_menu
    cmp   rbx , 120                     
    ja    no_menu
    mov   [button_id],rbx
    call  write_button_id
    jmp   still
  no_menu:

    jmp   still


write_button_id:

    push  rax rbx rcx rdx rsi r9

    mov   rax , 13
    mov   rbx , 126 shl 32 + 6*11
    mov   rcx , 111 shl 32 + 19
    mov   rdx , 0xe0e0e0
    int   0x60

    mov   rax , 4
    mov   rbx , string_id
    mov   rcx , 130+6
    mov   rdx , 116
    mov   r9  , 1
    mov   rsi , 0x000000
    int   0x60

    mov   rax , 47
    mov   rbx , 3*65536
    mov   rcx , [button_id]
    mov   rdx , 160 shl 32 + 116
    mov   rsi , 0x000000
    int   0x60

    pop   r9 rsi rdx rcx rbx rax

    ret


draw_window:

    mov   rax , 12                        ; Beginning of window draw
    mov   rbx , 1  
    int   0x60

    mov   rax , 0                         ; Draw window
    mov   rbx , 150 shl 32 + 280
    mov   rcx , 90 shl 32 + 219
    mov   rdx , 0xffffff        
    mov   r8  , 1
    mov   r9  , window_label              
    mov   r10 , menu_struct               
    int   0x60

    ; Define button

    mov   rax , 8
    mov   rbx , 020 shl 32 + 65
    mov   rcx , 110 shl 32 + 20
    mov   rdx , 20  
    mov   r8  , 0
    mov   r9  , button_text
    int   0x60

    ; Vertical scroll

    call  draw_vertical_scroll

    ; ID

    call  write_button_id

    mov   rax , 12 
    mov   rbx , 2
    int   0x60

    ret


draw_vertical_scroll:

    ; Vertical scroll

    mov   rax , 113
    mov   rbx , 1
    mov   rcx , 300
    mov   rdx , 20
    mov   r8  , [vscroll_value]
    mov   r9  , 250
    mov   r10 , 50
    mov   r11 , 150
    int   0x60

    ret


;
; Data area
;

window_label:              ; Window label

    db    'EXAMPLE',0     

button_text:               ; Button text

    db    'CLICK ME',0

string_id:

    db    'ID:',0

vscroll_value:             ; Scroll value

    dq    305        

button_id:

    dq    0

menu_struct:               ; Menu Struct

    dq   0                 ; Version

    dq   100               ; Start value of ID to return ( ID + Line )

                           ; Returned when menu closes and
                           ; user made no selections.

    db   0,'FILE',0        ; ID = 100 + 1
    db   1,'New',0         ; ID = 100 + 2
    db   1,'Open..',0      ; ID = 100 + 3
    db   1,'Save..',0      ; ID = 100 + 4
    db   1,'-',0           ; ID = 100 + 5
    db   1,'Quit',0        ; ID = 100 + 6

    db   0,'HELP',0        ; ID = 100 + 7
    db   1,'Contents..',0  ; ID = 100 + 8
    db   1,'About..',0     ; ID = 100 + 9

    db   255               ; End of Menu Struct

image_end:






