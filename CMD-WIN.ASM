;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   M64 terminal+window application example
;
;   Compile with FASM 1.60 or above
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

use64

    org   0x0

    db    'MENUET64'              ; Header identifier
    dq    0x02                    ; CMD + GUI process
    dq    START                   ; Start of code
    dq    image_end               ; Size of image
    dq    0x100000                ; Memory for app
    dq    0xffff0                 ; Rsp
    dq    Param                   ; Prm 
    dq    0x00                    ; Icon

ipc_memory equ 0x080000

START:

    ; Check that process is started from terminal.
    ; If not, we could also continue in GUI only mode.

    cmp   [Param+8],dword 'term'
    je    commandline
    mov   rax , 512
    int   0x60
  commandline:

    mov   rax , 141 ; Enable system font
    mov   rbx , 1
    mov   rcx , 1
    mov   rdx , 5 shl 32 + 5
    mov   r8  , 9 shl 32 + 12
    int   0x60

    call  draw_window

    ; Read terminal parameters and display startup screen

    call  read_terminal_parameters
    call  define_terminal_ipc_area
    call  send_text_to_terminal

still:

    mov   rax , 10          ; Wait here for event
    int   0x60

    test  rax , 1           ; Window redraw
    jnz   window_event_gui
    test  rax , 2           ; Keyboard press
    jnz   key_event_gui
    test  rax , 4           ; Button press
    jnz   button_event_gui

    ;
    ; Keyboard event
    ;
    movzx rax , word [ipc_memory+16+4]
    cmp   rax , 2
    je    key_event

    ;
    ; Button event
    ;
    cmp   rax , 4
    je    button_event

  event_done:

    mov   rax , 16
    mov   [ipc_memory+8],rax
    mov   rax , 0
    mov   [ipc_memory+16],rax

    jmp   still



window_event_gui:

    call  draw_window

    jmp   still



key_event_gui:

    mov   rax , 2          ; Read the key
    int   0x60

    mov   [ipc_memory+16+6+8*0],rbx
    mov   [ipc_memory+16+6+8*1],rcx

    mov   rax , 66
    mov   rbx , 3
    int   0x60

    mov   [ipc_memory+16+6+8*2],rax

    jmp   key_event


key_event:

    mov   rbx , [ipc_memory+16+6+8*0]
    mov   rcx , [ipc_memory+16+6+8*1]
    mov   rdx , [ipc_memory+16+6+8*2] ; shift,cntl etc states

    test  rbx , 1
    jnz   event_done

    cmp   cx , 'En'
    jne   nohalt
    mov   rax , 512
    int   0x60
  nohalt:

    cmp   cx , 'Ba'
    jne   nobackspace
    mov   cl , 8
  nobackspace:

    mov   [string_key],cl

    ; Send text to terminal

    mov   rax , 60
    mov   rbx , 2
    mov   rcx , [termpid]
    mov   rdx , string_key
    mov   r8  , 1
    int   0x60

    cmp   [ipc_memory+8],dword 16
    je    noremoveevent
    mov   rsi , ipc_memory+16+6+8*3
    mov   rdi , ipc_memory+16
    mov   rcx , 100
    cld
    rep   movsb
    sub   [ipc_memory+8],dword 6+8*3
  noremoveevent:

    jmp   event_done


button_event_gui:

    mov   rax , 17
    int   0x60

    mov   [ipc_memory+16+6+8*0],rax
    mov   [ipc_memory+16+6+8*1],rbx
    mov   [ipc_memory+16+6+8*2],rcx

    jmp   button_event

button_event:

    mov   rax , [ipc_memory+16+6+8*0]
    mov   rbx , [ipc_memory+16+6+8*1]
    mov   rcx , [ipc_memory+16+6+8*2]

    ; rax = status
    ; rbx = button id

    cmp   rbx , 0x10000001
    jne   no_application_terminate_button
    mov   rax , 0x200
    int   0x60
  no_application_terminate_button:

    cmp   rbx , 0x102
    jne   no_application_terminate_menu
    mov   rax , 0x200
    int   0x60
  no_application_terminate_menu:

    jmp   event_done



draw_window:

    mov   rax , 12                           ; Beginning of window draw
    mov   rbx , 1
    int   0x60

    mov   rax , 0                            ; Draw window
    mov   rbx , 256 shl 32 + 256             ; X start & size
    mov   rcx , 128 shl 32 + 192             ; Y start & size
    mov   rdx , 0x0000000000FFFFFF           ; Type    & border color
    mov   r8  , 0x0000000000000001           ; Flags (set as 1)
    mov   r9  , window_label                 ; 0 or label - asciiz
    mov   r10 , menu_struct                  ; 0 or pointer to menu struct
    int   0x60

    mov   rax , 4                            ; Display text
    mov   rbx , text                         ; Pointer to text
    mov   rcx , 32                           ; X position
    mov   rdx , 64                           ; Y position
    mov   rsi , 0x000000                     ; Color
    mov   r9  , 1                            ; Font
  newline:
    int   0x60
    add   rdx , 16
    add   rbx , 31
    cmp   [rbx],byte ' '
    jae   newline

    mov   rax , 12                           ; End of window draw
    mov   rbx , 2
    int   0x60

    ret


read_terminal_parameters:

    ; Get Terminal PID

    mov   rdi , Param+8+8+1
    mov   rcx , 0
  newparam:
    movzx rax , byte [rdi]
    sub   rax , 48
    imul  rcx , 10
    add   rcx , rax
    add   rdi , 1
    cmp   rdi , Param+8+15+1
    jbe   newparam
    mov   [termpid],rcx

    ; Get Current Path

    mov   rsi , Param+8+18
    mov   rdi , string_terminal_path
  newsps:
    mov   al , [rsi]
    cmp   al , ' '
    jbe   pathdone
    mov   [rdi],al
    add   rsi , 1
    add   rdi , 1
    jmp   newsps
  pathdone:
    mov   [rdi],byte 0
    ; Save length
    sub   rdi , string_terminal_path
    mov   [pathlen],rdi
    ret


define_terminal_ipc_area:

    ; Define IPC memory

    mov   rax , 60           ; ipc
    mov   rbx , 1            ; define memory area
    mov   rcx , ipc_memory   ; memory area pointer
    mov   rdx , 0
    mov   [rcx],rdx
    mov   rdx , 16
    mov   [rcx+8],rdx
    mov   rdx , 100          ; size of area
    int   0x60

    ; Enable IPC event

    mov   rax , 40
    mov   rbx , 1000111b
    int   0x60

    ret


send_text_to_terminal:

    ; Clear terminal screen

    mov   r15 , 0
  newlineclear:
    mov   rax , r15
    xor   rdx , rdx
    mov   rbx , 10
    div   rbx
    add   al  , 48
    add   dl  , 48
    mov   [string_cursor+3],dl
    mov   [string_cursor+2],al
    mov   rdx , string_cursor
    mov   r8  , string_cursor_end - string_cursor
    call  send_line_to_terminal
    add   r15 , 1
    cmp   r15 , 25
    jb    newlineclear

    ; Send text to terminal

    mov   rdx , string_terminal_1
    mov   r8  , string_terminal_1_end - string_terminal_1
    call  send_line_to_terminal

    ; Send path to terminal

    mov   rdx , string_terminal_path
    mov   r8  , [pathlen]
    call  send_line_to_terminal

    ; Send more text

    mov   rdx , string_terminal_2
    mov   r8  , string_terminal_2_end - string_terminal_2
    call  send_line_to_terminal

    ret


send_line_to_terminal:

    mov   rax , 60
    mov   rbx , 2
    mov   rcx , [termpid]
    int   0x60

    ret


; Data area

window_label:

    db    'CMD-WIN',0     ; Window label

text:

    db    'Keypresses in window          ',0
    db    'redirected to terminal.       ',0
    db    0

menu_struct:               ; Menu Struct

    dq   0                 ; Version

    dq   0x100             ; Start value of ID to return ( ID + Line )

                           ; Returned when menu closes and
                           ; user made no selections.

    db   0,'FILE',0        ; ID = 0x100 + 1
    db   1,'Quit',0        ; ID = 0x100 + 6

    db   0,'HELP',0        ; ID = 0x100 + 7
    db   1,'Contents..',0  ; ID = 0x100 + 8
    db   1,'About..',0     ; ID = 0x100 + 9

    db   255               ; End of Menu Struct

string_cursor:  

    dq    27 + ('[00;00H') shl 8
    times 80 db 32

string_cursor_end:

string_terminal_1: 

    dq    27 + ('[00;00H') shl 8
    db    'Example Terminal application',13,10
    db    'Current path: ',0

string_terminal_1_end:

string_terminal_2:

    db    13,10
    db    'Type a few letters and press Enter',13,10

string_terminal_2_end:       

termpid:    dq 0x0
string_key: dq 0x0
pathlen:    dq 0x0

string_terminal_path: times 200 db 0

Param:  dq  100
        times 100 db 0

image_end:

