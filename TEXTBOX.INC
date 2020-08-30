;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Textbox.inc for Menuet64
;
;   Compile with FASM 1.60 or above
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;textbox_descr:
;                  
;    dq    0       ; Type0
;                  ; bit 16 - clear at doubleclick
;                  ; bit 17 - set edit position according to mouse
;                  ; bit 18 - enable utf8 (max 4 byte/char)
;    dq    ?       ; Area X position  
;    dq    ?       ; Area X size
;    dq    ?       ; Area Y position
;    dq    ?       ; Button ID
;    dq    ?       ; Current text length
;    times 80 db 0 ; Text area (zero terminated)
;                  ; Length for ascii - (Area X size/6+1)
;                  ; Length for utf8  - (Area X size/6+1) * 4
;           
;textbox_descr:
;
;    dd    1       ; Type1
;                  ; bit 16 - clear at doubleclick
;                  ; bit 17 - set edit position according to mouse
;                  ; bit 18 - enable utf8 (max 4 byte/char)
;    dd    ?       ; frame color
;    dq    ?       ; Area X position
;    dq    ?       ; Area X size
;    dq    ?       ; Area Y position
;    dq    ?       ; Button ID
;    dq    ?       ; Current text length
;    times 80 db 0 ; Text area (zero terminated)
;                  ; Length for ascii - (Area X size/6+1)
;                  ; Length for utf8  - (Area X size/6+1) * 4
;

use64

read_textbox:

    ;
    ; Check version
    ;
    cmp   [r14],word 2
    jae   textbox_version_fail

    ;
    ; Cursor position in data
    ;
    mov   rbp , [r14+40]

    ;
    ; Cursor equals mouse position
    ;
    test  [r14],dword 1 shl 17
    jz    no_textbox_cursor_set
    mov   rax , 37 
    mov   rbx , 1
    int   0x60
    shr   rax , 32
    sub   rax , [r14+8]
    xor   rdx , rdx
    mov   rbx , 6
    div   rbx
    ; rax cur.pos 
    ; -> rbx/rcx data/cur position
    mov   rbx , 0
  search_textbox_data:
    cmp   rbx , rbp
    jae   tbox_end_reatched
    push  rbp
    mov   rbp , rbx
    call  get_cursor_position
    mov   rcx , rbp
    pop   rbp
    cmp   rcx , rax
    jae   tbox_end_reatched
    add   rbx , 1
    jmp   search_textbox_data
  tbox_end_reatched:
    mov   rbp , rbx
    ;
  no_textbox_cursor_set:

    ;
    ; Clear textbox when selected
    ;
    test  [r14],dword 1 shl 16
    jz    no_textbox_clear

    sub   rsp , 8*8
    mov   rax , 26
    mov   rbx , 1
    mov   rcx , rsp
    mov   rdx , 6*8
    int   0x60
    mov   rax , [rsp+5*8]
    add   rsp , 8*8

    mov   rbx , [previous_textbox_time]
    mov   [previous_textbox_time],rax

    mov   rcx , [previous_textbox_id]
    mov   rdx , [r14+32]
    mov   [previous_textbox_id],rdx

    sub   rax , rbx
    cmp   rax , 50
    ja    no_textbox_clear

    cmp   rcx , rdx
    jne   no_textbox_clear

    mov   rax , [previous_textbox_position]
    cmp   rax , rbp
    jne   no_textbox_clear

    mov   [r14+40],dword 0 ; Clear length
    mov   [r14+48],byte 0  ; Clear text
    mov   rbp , 0

  no_textbox_clear:

    mov   [previous_textbox_position],rbp
    mov   [r14+48+rbp],byte 0

    ;
    ; Read characters to textbox
    ;

  read_more_print:

    call  draw_textbox

    push  rbp
    call  get_cursor_position  ; cursor position in screen
    mov   rax , 38
    mov   rbx , rbp
    imul  rbx , 6
    add   rbx , [r14+8]
    add   rbx , 4
    mov   rcx , [r14+24]
    add   rcx , 2
    mov   rdx , rbx
    mov   r8  , rcx
    add   r8  , 12
    mov   r9  , 0x000000
    int   0x60
    pop   rbp

  read_more_keys:

    ;
    ; Get event
    ;
    mov   rax , 10
    int   0x60

    cmp   rax , 2
    je    continue
    call  draw_textbox
    ret
  continue:

    ;
    ; Get keypress
    ;
    mov   rax , 2
    int   0x60

    ;
    ; Special keys
    ;
    cmp   rbx , 10b
    jne   no_special 

    ;
    ; Home
    ;
    cmp   ecx , 'Home'
    jne   no_textbox_home
    mov   rbp , 0
    jmp   read_more_print
  no_textbox_home:

    ;
    ; End
    ;
    cmp   ecx , 'End '
    jne   no_textbox_end
    mov   rbp , 0
  search_textbox_end:
    cmp   [r14+48+rbp],byte 0
    je    read_more_print
    push  rbp
    call  get_cursor_position
    lea   rcx , [rbp+1]
    pop   rbp
    imul  rcx , 6
    cmp   rcx , [r14+16]
    ja    read_more_print
    add   rbp , 1
    jmp   search_textbox_end
  no_textbox_end:

    ;
    ; Delete
    ;
    mov   r8  , 'Delete  '
    cmp   rcx , r8
    jne   no_delete
    cmp   rbp , [r14+40]
    je    no_delete
    cmp   [r14+48+rbp],byte 11000000b
    jb    noutf8sub3
    inc   rbp
  noutf8sub3:
    inc   rbp
    jmp   backspace
  no_delete:

    ;
    ; Backspace
    ;
    mov   r8  , 'Backspc '
    cmp   rcx , r8 
    jne   no_backspc

  backspace:
    cmp   rbp , 0
    je    read_more_keys

    mov   rbx , 1
    cmp   [r14+48+rbp-2],byte 11000000b
    jb    noutf8sub2
    mov   rbx , 2
  noutf8sub2:

    sub   [r14+40],rbx

    mov   rdi , rbp
    add   rdi , r14
    add   rdi , 48

    mov   rcx , [r14+40]
    sub   rcx , rbp
    add   rcx , rbx
    mov   rsi , rdi
    sub   rdi , rbx
    cld
    rep   movsb 

    sub   rbp , rbx

    mov   rax , [r14+40]
    mov   [r14+48+rax],byte 0
    cmp   rbx , 2
    jne   noclearutf8
    mov   [r14+48+rax+1],byte 0
  noclearutf8:
    jmp   read_more_print
  no_backspc:

    ;
    ; Esc
    ;
    mov   r8  , 'Esc     '
    cmp   rcx , r8
    je    exit_textbox

    ;
    ; Enter
    ;
    mov   r8  , 'Enter   '
    cmp   rcx , r8 
    je    exit_textbox

    ;
    ; Left arrow
    ;
    mov   r8  , 'Left-A  '
    cmp   rcx , r8
    jne   no_left      
    cmp   rbp , 0
    je    read_more_keys
    cmp   [r14+48+rbp-2],byte 11000000b
    jb    noutf8sub
    dec   rbp
    cmp   rbp , 0
    je    read_more_print
  noutf8sub:
    dec   rbp
    jmp   read_more_print
  no_left:

    ;
    ; Right arrow
    ;
    mov   r8  , 'Right-A '
    cmp   rcx , r8
    jne   no_right
    cmp   [r14+48+rbp],byte 0
    je    read_more_keys
    cmp   [r14+48+rbp],byte 11000000b
    jb    noutf8add
    inc   rbp
  noutf8add:
    inc   rbp
    jmp   read_more_print
  no_right:

  no_special:

    ;
    ; Key press, utf8/ascii
    ;
    and   rbx , 1111111111111011b
    cmp   rbx , 0
    jne   read_more_keys

    ; UTF8 key
    cmp   rcx , 0x7f
    jbe   asciikey
    test  [r14],dword 1 shl 18
    jz    read_more_keys
    call  convert_unicode_to_utf8
  asciikey:

    ; Text area width
    mov   rax , [r14+16]
    sub   rax , 6 
    mov   rbx , 6
    xor   rdx , rdx
    div   rbx
    ; Cursor position
    push  rbp
    call  get_cursor_position
    mov   rbx , rbp
    pop   rbp
    ; Enough room ?
    cmp   rax , rbx
    jbe   nomoretext

    ; Search for last used position

    mov   rbx , rax ; max cursor position
    mov   rax , 0
  searchlastused:
    cmp   [r14+48+rax],byte 0
    je    lastusedfound
    add   rax , 1
    push  rbp
    mov   rbp , rax
    call  get_cursor_position
    mov   rsi , rbp
    pop   rbp
    cmp   rsi , rbx
    jae   read_more_keys
    jmp   searchlastused
  lastusedfound:

    ; 1/2 byte character

    mov   rbx , 1
    cmp   rcx , 0x100
    jb    no16bitutf8
    mov   rbx , 2
  no16bitutf8:

    ; Add space for character

    mov   rdi , rbp
    add   rdi , r14
    add   rdi , 48
    ;
    add   [r14+40], rbx
    add   rbp , rbx
    ;
    push  rcx
    push  rdi
    ;
    mov   rcx , rax
    sub   rcx , rbp
    ;
    mov   rsi , rdi
    add   rdi , rbx
    add   rcx , rbx
    ;
    add   rdi , rcx
    add   rsi , rcx
    add   rcx , 1
    ;
    std
    rep   movsb
    cld
    pop   rdi
    pop   rcx

    ; Add character

    mov   [rdi],cl
    cmp   ch , 0
    je    nosethbutf8
    mov   [rdi+1],ch
  nosethbutf8:

    ; If added to last position, add zero

    cmp   rbp , [r14+40]
    jne   noaddutf8end
    mov   [rdi+rbx],byte 0
  noaddutf8end:

  nomoretext:

    jmp   read_more_print

exit_textbox:

    push  rcx
    call  draw_textbox
    pop   rcx

    ret

textbox_version_fail:

    ; Return to application

    ret


convert_unicode_to_utf8:

    cmp   cx , 128
    jb    sevenbitunicode

    ; -> 2 byte unicode, 11 bits

    shl   cx , 2
    shr   cl , 2
    xchg  cl , ch
    add   cx , 0x80c0

  sevenbitunicode:

    ret


get_cursor_position:

    ; In:  rbp -
    ; Out: rbp -

    push  rax rbx

    mov   rax , 0
    mov   rbx , 0

  check_new_cursor_position:

    cmp   rbp , 0
    je    cursor_done_utf8

    cmp   [r14+48+rax],byte 11000000b
    jb    nosubcputf8
    sub   rbp , 1
    cmp   rbp , 0
    je    cursor_done_utf8
    add   rax , 1
  nosubcputf8:
    add   rax , 1

    sub   rbp , 1
    add   rbx , 1

    jmp   check_new_cursor_position

  cursor_done_utf8:

    mov   rbp , rbx

    pop   rbx rax

    ret


draw_textbox:    

    cmp   [r14],word 2
    jae   textbox_version_fail

    mov   rax , [r14+8]
    mov   r15 , [r14+16]

    push  rax

    ; Frames

    mov   rax , 38
    mov   rbx , [r14+8]
    mov   rdx , [r14+16]            
    add   rdx , rbx
    mov   rcx , [r14+24]
    mov   r8  , 16
    add   r8  , rcx
    mov   r9  , 0x202020
    cmp   [r14+0],word 1
    jne   notextboxtype1
    mov   r9d , [r14+4]
  notextboxtype1:
    push  rbx
    mov   rbx , rdx
    int   0x60
    pop   rbx
    push  rdx
    mov   rdx , rbx
    int   0x60
    pop   rdx
    push  rcx
    mov   rcx , r8
    int   0x60
    pop   rcx
    push  r8
    mov   r8  , rcx
    int   0x60
    pop   r8

    ; White

    mov   rax , 13
    mov   rbx , [rsp]
    add   rbx , 1
    shl   rbx , 32
    add   rbx , r15            
    sub   rbx ,  1
    mov   rcx , [r14+24]
    add   rcx , 1
    shl   rcx , 32
    add   rcx , 15
    mov   rdx , 0xffffff
    int   0x60

    ; Text 

    mov   rax , 4
    mov   rbx , r14              
    add   rbx , 48
    mov   rcx ,  25
    mov   rcx , [rsp+0] 
    add   rcx , 4
    mov   rdx , [r14+24]
    add   rdx , 5
    mov   rsi , 0x000000
    mov   r9  , 1 + 1 shl 60
    int   0x60

    ; Button

    mov   rbx , [rsp]
    shl   rbx , 32
    mov   rax , 8
    add   rbx , r15            
    inc   rbx
    mov   rcx , [r14+24]
    shl   rcx , 32
    add   rcx , 17
    mov   rdx , [r14+32]
    mov   r8  , 0
    bts   r8  , 63
    mov   r9  , 0       
    int   0x60

    pop   rax

    ret


;
; Data
;

previous_textbox_position: dq 0x0
previous_textbox_time:     dq 0x0
previous_textbox_id:       dq 0x0







