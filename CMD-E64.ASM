;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   M64 terminal application example
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
    ; If not, we could also continue in GUI mode, draw the window etc.

    cmp   [Param+8],dword 'term'
    je    commandline
    mov   rax , 512
    int   0x60
  commandline:

    ; Read terminal parameters and display startup screen

    call  read_terminal_parameters
    call  define_terminal_ipc_area
    call  send_text_to_terminal

still:

    mov   rax , 10          ; Wait here for event
    int   0x60

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

    mov   rdx , string_key
    mov   r8  , 1
    call  send_line_to_terminal

    mov   rsi , ipc_memory+16+6+8*3
    mov   rdi , ipc_memory+16
    mov   rcx , 100
    cld
    rep   movsb
    sub   [ipc_memory+8],dword 6+8*3

    jmp   event_done


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
    mov   rbx , 1000000b
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

