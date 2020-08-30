;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Menuet64 calculator
;
;   Compile with FASM 1.60 or above
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

xpos  equ 20
ypos  equ 80

xsize equ 37
ysize equ 23

constant equ 0

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

    mov   rdi , cleardata
    mov   rcx , cleardataend-cleardata
    mov   al , 0
    cld
    rep   stosb

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


add_to_history:

    mov   rax , [historycount]
    add   rax , 1
    mov   [historycount],rax
    mov   [historypos],rax
    sub   rax , 1
    mov   rdi , rax
    imul  rdi , 1024
    add   rdi , 0x100000
    mov   rsi , string_screen
    mov   rcx , 1020
    cld
    rep   movsb

    ret


add_to_history_current:

    mov   rdi , [historycount]
    imul  rdi , 1024
    add   rdi , 0x100000
    mov   rsi , string_screen
    mov   rcx , 1020
    cld
    rep   movsb

    mov   rax ,[historycount]
    mov   [historypos],rax

    ret


historycount:   dq 0x0
historypos:     dq 0x0
cursorposition: dq 0x0

key_event:

    mov   rax , 2          ; Read the key
    int   0x60

    test  rbx , 1
    jnz   still

    cmp   cx , 'Es'
    jne   noesc
    call  clear_string_screen
    call  add_to_history_current
    call  print_screen_string
    jmp   still
  noesc:

    cmp   cx , 'Up'
    jne   nouparrow
    mov   [cursorposition],dword 0
    cmp   [historycount],dword 0
    je    still
    mov   rax , [historypos]
    cmp   rax , 0
    je    nosubhistpos
    sub   rax , 1
  nosubhistpos:
  dohistory:
    mov   [historypos],rax
    imul  rax , 1024
    mov   rdi , string_screen
    mov   rsi , rax
    add   rsi , 0x100000
    mov   rcx , 1020
    cld
    rep   movsb
    call  print_screen_string
    jmp   still
  nouparrow:

    cmp   cx , 'Do'
    jne   nodownarrow
    mov   [cursorposition],dword 0
    cmp   [historycount],dword 0
    je    still
    mov   rax , [historypos]
    cmp   rax , [historycount]
    jae   noaddhistpos
    add   rax , 1
  noaddhistpos:
    jmp   dohistory
  nodownarrow:

    cmp   cx , 'Le'
    jne   noleftarrow
    add   [cursorposition],dword 1
    call  print_screen_string
    jmp   still
  noleftarrow:

    cmp   cx , 'Ri'
    jne   norightarrow
    cmp   [cursorposition],dword 0
    je    still
    sub   [cursorposition],dword 1
    call  print_screen_string
    jmp   still
  norightarrow:

    cmp   cx , 'En'
    je    calculate

    cmp   cx , 'Ba'
    jne   nobackspace
    mov   al , 8
    call  add_to_screen
    jmp   still
  nobackspace:

    cmp   cx , 'De'
    jne   nodelete
    cmp   [cursorposition],dword 0
    je    still
    sub   [cursorposition],dword 1
    mov   al , 8
    call  add_to_screen
    jmp   still
  nodelete:

    push  rbx
    mov   rax , 66
    mov   rbx , 3
    int   0x60
    pop   rbx
    cmp   rax , 0
    je    noctrldown
    cmp   cl , 'z'
    jne   noz
    mov   al , '"'
    call  add_to_screen
    jmp   still
  noz:
    cmp   cl , 'x'
    jne   nox
    mov   al , '!'
    call  add_to_screen
    mov   al , '#'
    call  add_to_screen
    jmp   still
  nox:
  noctrldown:

    test  rbx , 10b
    jnz   still

    cmp   cl , ' '
    je    still

    mov   al , cl
    call  add_to_screen

    jmp   still

button_event:

    mov   rax , 17
    int   0x60

    ; rax = status
    ; rbx = button id

    cmp   rbx , 0x10000001
    jne   no_application_terminate_button
    mov   rax , 0x200
    int   0x60
  no_application_terminate_button:

    if constant=1
    cmp   rbx , 0x105
    jb    noconstant
    cmp   rbx , 0x105+5
    ja    noconstant
    sub   rbx , 0x105
    imul  rbx , 20
    mov   rsi , rbx
    add   rsi , string_constants
  newaddc:
    mov   al  , [rsi]
    cmp   al  , 0
    je    still
    push  rsi
    call  add_to_screen
    pop   rsi
    add   rsi , 1
    jmp   newaddc
  noconstant:  
    cmp   rbx , 0x105+5+2
    jne   no_application_terminate_menu
    mov   rax , 0x200
    int   0x60
  no_application_terminate_menu:
    end if

    if constant=0
    cmp   rbx , 0x105
    jne   no_application_terminate_menu
    mov   rax , 0x200
    int   0x60
  no_application_terminate_menu:
    end if


    cmp   rbx , 0x103
    jne   noexample
    mov   [calcpressed],byte 0
    call  clear_string_screen
    mov   rsi , string_example
  moreexa:
    mov   al  , [rsi]
    push  rsi
    call  add_to_screen
    pop   rsi
    add   rsi , 1
    cmp   [rsi],byte 0
    jne   moreexa
    jmp   still
  noexample:

    cmp   rbx , 0x102
    jne   noinfo
    mov   rax , 13
    mov   rbx , (xpos+xsize+54-10) shl 32 + 6*(string_info_length-string_info-1)+10
    mov   rcx , (ypos+14-10) shl 32 + 12*7
    mov   rdx , 0xf0f0f0
    int   0x60
    mov   rax , 4
    mov   rbx , string_info
    mov   rcx , xpos+xsize+54
    mov   rdx , ypos+12
    mov   rsi , 0
    mov   r9  , 1
  newinfo:
    int   0x60
    add   rbx , string_info_length-string_info
    add   rdx , 12
    cmp   [rbx],byte 0
    jne   newinfo
    mov   rax , 10
    int   0x60
    mov   rax , 2          ; Read key
    int   0x60
    call  draw_window
    jmp   still
  noinfo:


    ; Buttons

    cmp   rbx , 300
    jne   nodelbutton
    mov   [calcpressed],byte 0
    call  clear_string_screen
    call  print_screen_string
    jmp   still
  nodelbutton:

    cmp   rbx , 301
    jne   nobackbutton
    mov   al , 8
    call  add_to_screen
    jmp   still
  nobackbutton:

    cmp   rbx , 100
    jb    nocalcbutton
    cmp   rbx , 200
    ja    nocalcbutton

    mov   rsi , buttons
    mov   rdx , 100
  newbutton2:
    add   rsi , 2
    cmp   rdx , rbx
    je    buttonfound
    sub   rsi , 1
  norsiz2:
    add   rsi , 1
    cmp   [rsi],byte 0
    jne   norsiz2
    add   rsi , 1
    add   rdx , 1
    cmp   [rsi], dword 0
    jne   newbutton2
    jmp   still
  buttonfound:
    mov   rax , [rsi]

    cmp   ax ,'HE' 
    jne   nohex
    cmp   [numtype],byte 16
    je    still
    mov   rsi , string_screen
    mov   rdi , numr10
    call  decimaltofloat
    mov   [numtype],byte 16
    mov   rdi , string_screen
    call  convert_to_string
    call  truncate_string_screen
    call  print_screen_string
    jmp   still
  nohex:

    cmp   ax ,'DE' 
    jne   nodec
    cmp   [numtype],byte 10
    je    still
    mov   rsi , string_screen
    mov   rdi , numr10
    call  decimaltofloat
    mov   [numtype],byte 10
    mov   rdi , string_screen
    call  convert_to_string
    call  truncate_string_screen
    call  print_screen_string
    jmp   still
  nodec:

    cmp   ax ,'BI' 
    jne   nobin
    cmp   [numtype],byte 2
    je    still
    mov   rsi , string_screen
    mov   rdi , numr10
    call  decimaltofloat
    mov   [numtype],byte 2
    mov   rdi , string_screen
    call  convert_to_string
    call  truncate_string_screen
    call  print_screen_string
    jmp   still
  nobin:

    cmp   ax , 'M<'
    jne   notomem
    mov   rsi , string_screen
    mov   rdi , string_memory
    mov   rcx , 300
    cld
    rep   movsb
    jmp   still
  notomem:

    cmp   ax , 'M>'
    jne   notoscreen
    mov   rsi , string_memory
    mov   rdi , string_screen
  newmemmove:
    cld
    lodsb
    cmp   al , 0
    je    still
    push  rsi rdi
    call  add_to_screen
    pop   rdi rsi
    jmp   newmemmove
  notoscreen:

    cmp   [calcpressed],byte 1
    jne   noclearcalcp
    cmp   ah , '^'
    je    clearcalcpr
    cmp   al , '+'
    je    clearcalcpr
    cmp   al , '-'
    je    clearcalcpr
    cmp   al , '/'
    je    clearcalcpr
    cmp   al , '*'
    je    clearcalcpr
    cmp   al , '='
    je    still
    call  clear_string_screen
  clearcalcpr:
    mov   [calcpressed],byte 0
  noclearcalcp:

    cmp   ax , '-/'
    jne   nominusplus
    mov   rsi , string_screen
  mpl9:
    cmp   [rsi],byte 0
    je    mpl10
    add   rsi , 1
    jmp   mpl9
  mpl10:
    sub   rsi , 1
  mpl15:
    cmp   [rsi],byte '.'
    je    mpl11
    cmp   [rsi],byte '0'
    jb    mpl12
    cmp   [rsi],byte 'F' ; '9'
    ja    mpl12
  mpl11:
    sub   rsi , 1
    jmp   mpl15
  mpl12:
    cmp   [rsi],byte '-'
    jne   noremoveminus
    mov   [rsi],byte '+'
    call  print_screen_string
    jmp   still
  noremoveminus:
    cmp   [rsi],byte '+'
    jne   noremoveplus
    mov   [rsi],byte '-'
    call  print_screen_string
    jmp   still
  noremoveplus:
    add   rsi , 1
    push  rsi
    mov   rdi , rsi
    add   rdi , 1
    mov   rcx , 100
    add   rdi , rcx
    add   rsi , rcx
    inc   rcx
    std
    rep   movsb
    cld
    pop   rsi
    mov   [rsi],byte '-'
    call  print_screen_string
    jmp   still
  nominusplus:

    cmp   ax , 'PI'
    jne   nopi
    mov   [numtype],dword 10
    mov   rax , '3.141592'
  newpi:
    push  rax
    call  add_to_screen
    pop   rax
    shr   rax , 8
    cmp   rax , 0
    jne   newpi
    mov   rax , '6535898';13dec
  newpi2:
    push  rax
    call  add_to_screen
    pop   rax
    shr   rax , 8
    cmp   rax , 0
    jne   newpi2
    jmp   still
  nopi:

    cmp   ax , ' E'
    jne   noe
    mov   [numtype],dword 10
    mov   rax , '2.718281'
  newe:
    push  rax
    call  add_to_screen
    pop   rax
    shr   rax , 8
    cmp   rax , 0
    jne   newe
    mov   rax , '8284590';13dec
  newe2:
    push  rax
    call  add_to_screen
    pop   rax
    shr   rax , 8
    cmp   rax , 0
    jne   newe2
    jmp   still
  noe:

    cmp   ah , '^'
    jne   nopowsign
    shr   rax , 8
    and   rax , 0xff
  nopowsign:

    cmp   ah , 0
    jne   noaddnumletter
    cmp   al , '='
    je    calculate
    cmp   [numtype],byte 16
    je    no16check
    cmp   al , 'A'
    jb    no16check
    cmp   al , 'F'
    ja    no16check
    jmp   still
  no16check:
    cmp   [numtype],byte 2
    jne   no2check
    cmp   al , '1'
    ja    still
  no2check:
    call  add_to_screen
    jmp   still
  noaddnumletter:

    ; Add sin,cos,tan,.. to the beginning of value

    cmp   [string_screen],byte 0
    je    notobeginning
    mov   rsi , string_screen
  stsl0:
    add   rsi , 1
    cmp   [rsi],byte 0
    je    stsl1
    cmp   [rsi],byte '.'
    je    stsl0
    cmp   [rsi],byte '0'
    jb    stsl10
    cmp   [rsi],byte 'F'
    ja    stsl10
    jmp   stsl0
  stsl1:
    mov   rsi , string_screen
    call  add_to_screen_reg_pos
    jmp   calculate
    ;call  calculate
    ;mov   [calcpressed],byte 0
    jmp   still
  stsl10:
  notobeginning:

    ; Add sin,cos,tan to end of string

    call  add_to_screen_reg
    jmp   still

  nocalcbutton:

    jmp   still



calculate:

    call  add_to_history
    mov   [cursorposition],dword 0

  calculate_loop:

    ;mov   [calcpressed],byte 1

    ; Remove double negative signs

    mov   rsi , string_screen
  newnegs:
    cmp   [rsi],byte 0
    je    nodneg
    mov   bx  , [rsi]
    cmp   bx  , '--'
    jne   nodoubleneg
    cmp   [rsi-1],byte '0'
    jb    remo
    cmp   [rsi-1],byte 'F' ; '9'
    ja    remo
    push  rsi
    mov   rdi , rsi
    add   rsi , 1
    mov   rcx , 100
    cld
    rep   movsb
    pop   rsi
    mov   [rsi],byte '+'
    jmp   continue
  remo:
    mov   rdi , rsi
    add   rsi , 2
    mov   rcx , 100
    cld
    rep   movsb
    jmp   continue
  nodoubleneg:
    add   rsi , 1
    jmp   newnegs
  nodneg:

    ; Remove double positive signs

    mov   rsi , string_screen
  newposs:
    cmp   [rsi],byte 0
    je    nodpos
    mov   bx  , [rsi]
    cmp   bx  , '++'
    jne   nodoublepos
    cmp   [rsi-1],byte '0'
    jb    remopos
    cmp   [rsi-1],byte 'F' ; '9'
    ja    remopos
    push  rsi
    mov   rdi , rsi
    add   rsi , 1
    mov   rcx , 100
    cld
    rep   movsb
    pop   rsi
    jmp   continue
  remopos:
    mov   rdi , rsi
    add   rsi , 2
    mov   rcx , 100
    cld
    rep   movsb
    jmp   continue
  nodoublepos:
    add   rsi , 1
    jmp   newposs
  nodpos:

    ; Convert +- to -

    mov   rsi , string_screen
  newpns:
    cmp   [rsi],byte 0
    je    nopns
    mov   bx  , [rsi]
    cmp   bx  , '+-'
    jne   nopns2
    mov   rdi , rsi
    add   rsi , 1
    mov   rcx , 100
    cld
    rep   movsb
    jmp   continue
  nopns2:
    add   rsi , 1
    jmp   newpns
  nopns:

    ; Search for internal ()

    mov   r11 , string_screen
  newsfb:
    cmp   [r11],byte ')'
    je    endsf
    cmp   [r11],byte 0
    je    endsf
    add   r11 , 1
    jmp   newsfb
  endsf:
    mov   r10 , r11
    sub   r10 , 1
  newbeg:
    cmp   [r10],byte '('
    je    begsf
    cmp   [r10],byte 0
    je    begsf
    sub   r10 , 1
    jmp   newbeg
  begsf:
    ;
    ; Analyze between r10 - r11
    ;
    ; Search for sin,cos,tan,..
    ;
    mov   rax , r11
  analyzebetween3:
    mov   rbx , [rax]
    and   rbx , 0xffffff
    cmp   [rax-1],byte 'a'
    je    arc
    cmp   rbx , 'cos'
    jne   nocos
    mov   rbx , 0
    mov   rsi , 3
    jmp   dosincostan
  nocos:
    cmp   rbx , 'sin'
    jne   nosin
    mov   rbx , 1
    mov   rsi , 3
    jmp   dosincostan
  nosin:
    cmp   rbx , 'tan'
    jne   notan
    mov   rbx , 3
    mov   rsi , 3
    jmp   dosincostan
  notan:
  arc:
    mov   ebx , [eax]
    cmp   ebx , 'acos'
    jne   noacos
    mov   rbx , 6
    mov   rsi , 4
    jmp   dosincostan
  noacos:
    cmp   ebx , 'asin'
    jne   noasin
    mov   rbx , 7
    mov   rsi , 4
    jmp   dosincostan
  noasin:
    cmp   ebx , 'atan'
    jne   noatan
    mov   rbx , 4
    mov   rsi , 4
    jmp   dosincostan
  noatan:
    cmp   [rax+1],dword 'xp!#'
    jne   noexp10
    mov   rbx , 12
    mov   rsi , 5
    jmp   dosincostan
  noexp10:
    cmp   [rax],dword 'exp"'
    jne   noexp2
    mov   rbx , 11
    mov   rsi , 4
    jmp   dosincostan
  noexp2:
    cmp   [rax],word 'ex'
    jne   noexp
    mov   rbx , 10
    mov   rsi , 3
    jmp   dosincostan
  noexp:
    cmp   [rax+1],dword 'og!#'
    jne   nolog10
    mov   rbx , 15
    mov   rsi , 5
    jmp   dosincostan
  nolog10:
    cmp   [rax],dword 'log"'
    jne   nolog2
    mov   rbx , 14
    mov   rsi , 4
    jmp   dosincostan
  nolog2:
    cmp   [rax],word 'lo'
    jne   nolog
    cmp   [rax-1],byte 'i'
    je    nolog
    mov   rbx , 13
    mov   rsi , 3
    jmp   dosincostan
  nolog:
    cmp   [rax],dword 'ilog'
    jne   noilogb
    mov   rbx , 19
    mov   rsi , 5
    jmp   dosincostan
  noilogb:
    cmp   [rax],dword 'cbrt'
    jne   nocbrt
    mov   rbx , 9
    mov   rsi , 4
    jmp   dosincostan
  nocbrt:
    cmp   [rax],word 'sq'
    jne   nosqr
    mov   rbx , 9999
    mov   rsi , 3
    jmp   dosincostan
  nosqr:
    cmp   [rax],word 'in'
    jne   noint
    cmp   [rax+2],byte 't'
    jne   noint
    mov   [skipdec],byte 1
    mov   rbx , 9998
    mov   rsi , 3
    jmp   dosincostan
  noint:

    jmp   nosincostan

  dosincostan:
    push  rax
    push  rbx
    add   rsi , rax
    mov   rdi , numr10
    push  rbx
    call  decimaltofloat ; out: [floatend]
    pop   r15
    ; int
    cmp    r15 , 9998
    jne    nointf
    mov    [skipdec],byte 0
    pop    rbx
    jmp    sqrdone
  nointf:
    ; sqr
    cmp    r15 , 9999
    jne    nosqrf
    movsd  xmm0 , [numr10]
    sqrtpd xmm0 , xmm0
    movsd  [numr10],xmm0
    pop    rbx
    jmp    sqrdone
  nosqrf:
    ; sin,cos,tan,..
    movsd     xmm0 , [numr10]  ;sin,cos,tan,..
    unpcklpd  xmm0 , xmm0
    mov       eax  , 151
    pop       rbx
    int       0x60
    movapd    dqword [numr10], xmm0
  sqrdone:
    pop   rbx
    sub   rbx , 1
    call  inserttoscreen
    jmp   continue

  nosincostan:

    sub   rax , 1
    cmp   rax , r10
    jae   analyzebetween3
    ;
    ; search '^'
    ;
    mov   rax , r10
  analyzebetween4:
    cmp   [rax],byte '^'
    jne   nopower
    push  r10 r11
    call  scan2numbers ; out:rbx=num beginning
    pop   r11 r10
    push  rax rbx
    movsd     xmm0 , [numr10] ;pow
    unpcklpd  xmm0 , xmm0
    movsd     xmm1 , [numr11]
    unpcklpd  xmm1 , xmm1
    mov       eax  , 151
    mov       ebx  , 8
    int       0x60
    movapd    dqword [numr10], xmm0
    pop   rbx rax
    call  inserttoscreen
    jmp   continue
  nopower:
    add   rax , 1
    cmp   rax , r11
    jb    analyzebetween4
    ;
    ; search '*' and '/'
    ;
    mov   rax , r10
  analyzebetween:
    cmp   [rax],byte '*'
    jne   nomultiplication
    push  r10 r11
    call  scan2numbers ; out:rbx=num beginning
    pop   r11 r10
    movsd  xmm0 , [numr10]
    movsd  xmm1 , [numr11]
    mulpd  xmm0,xmm1
    movsd  [numr10],xmm0
    call  inserttoscreen
    jmp   continue
  nomultiplication:
    cmp   [rax],byte '/'
    jne   nodivision
    call  scan2numbers
    movsd  xmm0 , [numr10]
    movsd  xmm1 , [numr11]
    divpd  xmm0,xmm1
    movsd  [numr10],xmm0
    call  inserttoscreen
    jmp   continue
  nodivision:
    add   rax , 1
    cmp   rax , r11
    jb    analyzebetween
    ;
    ; search '+' and '-'
    ;
    mov   rax , r10
  analyzebetween2:
    cmp   [rax],byte '+'
    jne   noaddition
    cmp   [rax-1],byte '0'
    jb    noaddition
    cmp   [rax-1],byte 'F' ; '9'
    ja    noaddition
    push  r10 r11
    call  scan2numbers ; out:rbx=num beginning
    pop   r11 r10
    movsd  xmm0 , [numr10]
    movsd  xmm1 , [numr11]
    addpd  xmm0,xmm1
    movsd  [numr10],xmm0
    call  inserttoscreen
    jmp   continue
  noaddition:
    cmp   [rax],byte '-'
    jne   nosubtraction
    cmp   [rax-1],byte '0'
    jb    nosubtraction
    cmp   [rax-1],byte 'F' ; '9'
    ja    nosubtraction
    call  scan2numbers
    movsd  xmm0 , [numr10]
    movsd  xmm1 , [numr11]
    subpd  xmm0,xmm1
    movsd  [numr10],xmm0
    call  inserttoscreen
    jmp   continue
  nosubtraction:
    add   rax , 1
    cmp   rax , r11
    jb    analyzebetween2

    ; +./* not found ? -> remove parenthesis

    cmp   [r10],byte '('
    jne   nopars
    cmp   [r11],byte ')'
    jne   nopars
    mov   rdi , r10
    mov   rsi , r10
    add   rsi , 1
    mov   rcx , 100
    cld
    rep   movsb
    mov   rdi , r11
    sub   rdi , 1
    mov   rsi , r11
    mov   rcx , 100
    cld
    rep   movsb
    jmp   continue
  nopars:

    ; Result

    call  truncate_string_screen
    call  add_to_history_current
    call  print_screen_string

    jmp   still

  continue:

    mov   rax , 66
    mov   rbx , 3
    int   0x60
    cmp   rax , 0
    je    calculate_loop

    mov   [calcpressed],byte 0

    call  add_to_history_current
    call  print_screen_string

    jmp   still



truncate_string_screen:

    mov   rdi , 14
    cmp   [numtype],byte 2
    jne   notr2
    mov   rdi , 14*4
  notr2:
    cmp   [numtype],byte 16
    jne   notr16
    mov   rdi , 140/16
  notr16:

    mov   rsi , string_screen
    mov   r15 , string_rounding
    mov   rax , 0
    mov   rbx , 0
  anl0:
    cmp   [rsi],byte 0
    je    anl1
    mov   [r15],byte '0'
    cmp   [rsi],byte '.'
    jne   anl2
    mov   [r15],byte '.'
    mov   rbx , 1
    jmp   anl5
  anl2:
    add   rax , 1
  anl5:
    cmp   rax , rdi
    jbe   lenfine
    cmp   rbx , 0
    je    lenfine
    cmp   [rsi-1],byte '.'
    jne   noremdot
    sub   rsi , 1
    jmp   markend
  noremdot:
    ; Rounding
    movzx rcx , byte [numtype]
    shr   rcx , 1
    add   rcx , 48
    mov   [r15],rcx
    push  rsi
    mov   rsi , string_screen
    mov   rdi , numr10
    call  decimaltofloat
    mov   rsi , string_rounding
    mov   rdi , numr11
    call  decimaltofloat
    movsd  xmm0 , [numr10]
    movsd  xmm1 , [numr11]
    cmp    [string_screen],byte '-'
    jne    noroundneg
    subpd  xmm0,xmm1
    jmp    rounddone
  noroundneg:
    addpd  xmm0,xmm1
  rounddone:
    movsd  [numr10],xmm0
    mov   rdi , string_screen
    call  convert_to_string
    pop   rsi
    ; Remove zeroes from end
  newzs:
    cmp   [rsi-1],byte '.'
    je    removedot
    cmp   [rsi-1],byte '0'
    jne   markend
    sub   rsi , 1
    jmp   newzs
  removedot:
    sub   rsi , 1
  markend:
    mov   [rsi],dword 0
    jmp   truncated
  lenfine:
    add   rsi , 1
    add   r15 , 1
    jmp   anl0
  anl1:
  truncated:

    ret



inserttoscreen:

; In: rbx

    mov   rdi , string_convert
    push  r10 r11 rbx
    call  convert_to_string ; out:r13=len
    pop   rbx r11 r10
    ; delete
    mov   rdi , rbx
    add   rdi , 1
    mov   rsi , [floatend]
    mov   rcx , 100
    cld
    rep   movsb
    sub   r13 , 1
    ; make room
    mov   rdi , rbx
    add   rdi , 1
    add   rdi , r13
    mov   rsi , rbx
    add   rsi , 1
    mov   rcx , 100 ;
    add   rdi , rcx
    add   rsi , rcx
    add   rcx , 1
    std
    rep   movsb
    cld
    ; copy value
    mov   rsi , string_convert
    mov   rdi , rbx
    add   rdi , 1
    mov   rcx , r13
    cld
    rep   movsb

    ret


clear_string_screen:

    push  rax rcx rdi
    mov   rdi , string_screen
    mov   rcx , 300
    mov   al  , 0
    cld
    rep   stosb
    pop   rdi rcx rax
    ret



scan2numbers:

    mov   rbx , rax
  scanbeg:
    sub   rbx , 1
    cmp   [rbx],byte '.'
    je    scanbeg
    cmp   [rbx],byte '0'
    jb    scanbegend
    cmp   [rbx],byte 'F' ; '9'
    ja    scanbegend
    jmp   scanbeg
  scanbegend:
    cmp   [rbx],byte '-'
    jne   nosubm
    sub   rbx , 1
  nosubm:
    mov   rsi , rbx
    add   rsi , 1
    mov   rdi , numr10
    push  rax rbx
    call  decimaltofloat
    pop   rbx rax
    mov   rsi , rax
    add   rsi , 1
    mov   rdi , numr11
    push  rax rbx
    call  decimaltofloat
    pop   rbx rax

    ret



convert_to_string:

; in: rdi , numr10

    ; clear destination

    push  rdi
    mov   rcx , 100
    mov   rax , 0
    cld
    rep   stosb
    mov   rdi , string_temp
    mov   rcx , 300
    mov   rax , 0
    cld
    rep   stosb
    pop   rdi

    ; exponent

    mov  rax , [numr10+0]
    shr  rax , 64-1-11
    and  rax , 11111111111b
    mov  r15 , rax

    ; exponent zero

    mov  rbx , 0         
    mov  r12 , [numr10+0]
    cmp  r15 , 0
    je   noch

    ; mantissa

    mov  rbx , [numr10+0]
    shl  rbx , 11+1
    shr  rbx , 32-16-4

    ; add 1

    mov  rcx , 0x10000000000000
    add  rbx , rcx

    ; exponent=1023

    cmp  r15 , 1023
    jne  @f
    mov  r12 , 1
  @@:

    ; exponent>1023

    cmp  r15 , 1023
    jbe  @f
    mov  r12 , rbx
    mov  rcx , r15
    sub  rcx , 1023
    shl  rbx , cl
    mov  dl  , 32+16+4
    sub  dl  , cl
    mov  cl  , dl
    shr  r12 , cl
    mov  rcx , 0xfffffffffffff
    and  rbx , rcx
  @@:

    ; exponent<1023

    cmp  r15 , 1023
    jae  @f
    mov  r12 , 0
    mov  rcx , 1023
    sub  rcx , r15
    shr  rbx , cl
  @@:

  noch:

    mov  rcx , rbx

    ;
    ; Decimal
    ;

    mov  r10 , 0
    mov  rbp , string_temp+200
    mov  rbx , 0xfffffffffffff
    and  rcx , rbx

  newnum:

    imul rcx , [numtype]

    push rcx

    mov  rbx , rcx
    shr  rbx , 32+16+4

    cmp  [numtype],byte 10
    ja   nonumt10
    add  bl , 48
    mov  [rbp],byte bl
    add  rbp , 1
  nonumt10:
    cmp  [numtype],byte 16
    jne  nonumt16
    add  bl , 48
    cmp  bl , '9'
    jbe  blff
    add  bl , 'A'-'9'-1
  blff:
    mov  [rbp],byte bl
    add  rbp , 1
  nonumt16:

    pop rcx
    mov rbx , 0xfffffffffffff
    and rcx , rbx

    cmp rcx , 0
    je  nonewnum

    add r10 , 1
    cmp r10 , 16
    jb  newnum

  nonewnum:

    mov  r13 , rbp

    mov  rbp , string_temp+200-1

    mov [rbp],byte '.'
    sub  rbp , 1

    ;
    ; Integer
    ;

    mov  r10 , 0

  newnum2:

    push rdx
    mov  rax , r12
    mov  rdx , 0
    mov  rbx , [numtype]
    div  rbx
    mov  r12 , rax
    mov  rcx , rdx
    pop  rdx

    cmp  [numtype],byte 10
    ja   @f
    add  cl , 48
    mov  [rbp],byte cl
    sub  rbp , 1
  @@:
    cmp  [numtype],byte 16
    jne  lab1
    add  cl , 48
    cmp  cl , '9'
    jbe  lab2
    add  cl , 'A'-'9'-1
  lab2:
    mov  [rbp],byte cl
    sub  rbp , 1
  lab1:

    mov  rbx , 6 shl 32
    sub  rdx , rbx

    cmp  r12 , 0
    je   nonewnum2

    add  r10 , 1
    cmp  r10 , 80
    jb   newnum2

  nonewnum2:

    ; Sign

    mov  rcx , [numr10+0]
    shr  rcx , 63
    test rcx , 1
    jz   nonegative
    mov  [rbp],byte '-'
    sub  rbp , 1
  nonegative:

    mov  rsi , rbp
    add  rsi , 1
    mov  rcx , 100
    cld
    rep  movsb

    sub  r13 , rbp ; ret len

    ret


decimaltofloat:

    ;
    ; Int to float
    ;
    mov   [sign],byte 0
    cmp   [rsi],byte '-'
    jne   nonegativesign
    mov   [sign],byte 1
    add   rsi , 1
  nonegativesign:
    cmp   [rsi],byte '+'
    jne   nopositivesign
    add   rsi , 1
  nopositivesign:

    mov   r15 , 0
  nextint:
    movzx rbx , byte [rsi]
    cmp   rbx , '0'
    jb    intreaddone
    cmp   [numtype],byte 2
    jne   lab105
    cmp   rbx , '1'
    ja    intreaddone
  lab105:
    cmp   [numtype],byte 10
    jne   lab100
    cmp   rbx , '9'
    ja    intreaddone
  lab100:
    cmp   [numtype],byte 16
    jne   lab101
    cmp   rbx , 'F'
    ja    intreaddone
    cmp   rbx , '9'
    jbe   lab102
    sub   rbx , 'A'-'9'-1
  lab102:
  lab101:
    imul  r15 , [numtype]
    sub   rbx , 48
    add   r15 , rbx
    add   rsi , 1
    jmp   nextint
  intreaddone:
    mov   [floatend],rsi

    ; int
    cmp   [skipdec],byte 1
    jne   nohalfcheck
    cmp   [rsi],byte '.'
    jne   nohalfcheck
    movzx rax , byte [numtype]
    shr   rax , 1
    add   rax , 48
    cmp   [rsi+1],al
    jb    nohalfcheck
    add   r15 , 1
  nohalfcheck:

    add   rsi , 1

    mov   rax , r15
    mov   r13 , 0
  checkint:
    cmp   rax , 0
    je    intdone
    shr   rax , 1
    add   r13 , 1
    jmp   checkint
  intdone:
    sub   r13, 1
    mov   cl , 52
    sub   cl , r13b
    shl   r15, cl
    mov   rcx , 0x000fffffffffffff
    and   r15 , rcx

    ; Over 51 bits ?
    cmp   r13 , 1000
    jae   nosz
    mov   rax , 0
    cmp   r13 , 51
    ja    setzero
  nosz:

    ;
    ; Fraction to float
    ;
    mov   rax , 0
    cmp   [rsi-1],byte '.'
    jne   nofraction
    cmp   [skipdec],byte 1
    je    fraction2

    mov   rdx , 100000000000000000
    cmp   [numtype],byte 2
    jne   lab1105
    mov   rdx , 0x1000000000000 shr 1
  lab1105:
    cmp   [numtype],byte 16
    jne   lab1106
    mov   rdx , 0x1000000000000 shr 4
  lab1106:

  newdec:
    movzx rbx , byte [rsi]
    cmp   rbx , '0'
    jb    nomoredec
    cmp   [numtype],byte 2
    jne   lab1102
    cmp   rbx , '1'
    ja    nomoredec
  lab1102:
    cmp   [numtype],byte 10
    jne   lab110
    cmp   rbx , '9'
    ja    nomoredec
  lab110:
    cmp   [numtype],byte 16
    jne   lab114
    cmp   rbx , 'F'
    ja    nomoredec
    cmp   rbx , '9'
    jbe   lab112
    sub   rbx , 'A'-'9'-1
  lab112:
  lab114:
    imul  rax , [numtype]
    sub   rbx , 48
    add   rax , rbx
    add   rsi , 1
    push  rax rbx rcx
    mov   rax , rdx
    mov   rbx , [numtype]
    xor   rdx , rdx
    div   rbx
    mov   rdx , rax
    pop   rcx rbx rax
    cmp   rdx , 0
    je    newdecdone
    jmp   newdec
  nomoredec:
    imul  rdx , [numtype]
    imul  rax , rdx
  newdecdone:

  fraction2:

    ; In case decimal is longer than encoding
  moredecs:
    movzx rbx , byte [rsi]
    cmp   rbx , '0'
    jb    nomoredec3
    cmp   rbx , 'F'
    ja    nomoredec3
    add   rsi , 1
    jmp   moredecs
  nomoredec3:

    mov   [floatend],rsi

  nofraction:

    ; Int and decimal zero

    cmp   r13 , 1000
    jb    nointdeczero
    cmp   r15 , 0
    jne   nointdeczero
    cmp   rax , 0
    jne   nointdeczero
    mov   rax , 0
    jmp   setzero
  nointdeczero:

    ; Integer part is zero?

    mov   r12 , 5000 ; dec exponent
    mov   r9  , 0
  newstart:
    mov   r10 , 0
    mov   rbx , 1000000000000000000
    cmp   [numtype],byte 2
    jne   lab1108
    mov   rbx , 0x1000000000000
  lab1108:
    cmp   [numtype],byte 16
    jne   lab1107
    mov   rbx , 0x1000000000000
  lab1107:
    mov   rcx , 0
  getmorebits:
    shl   rax , 1
    cmp   rax , rbx
    jb    noone
    sub   rax , rbx
    shl   rcx , 1
    add   rcx , 1
    cmp   r13 , 1000
    jb    nodecz1
    cmp   r12 , 1000
    jb    nodecz1
    mov   r12 , r9
    add   r12 , 1
    jmp   newstart
  nodecz1:
    jmp   onedone
  noone:
    shl   rcx , 1
    add   rcx , 0
  onedone:
    mov   r11 , 52
    cmp   r13 , 1000
    ja    nor13sub
    sub   r11 , r13
  nor13sub:
    add   r9  , 1
    add   r10 , 1
    cmp   r10 , r11
    jae   bitsdone
    jmp   getmorebits
  bitsdone:
    mov   rax , 1023
    cmp   r13 , 1000
    ja    noaddr13
    add   rax , r13 ; int exp
  noaddr13:
    cmp   r12 , 1000
    ja    nosubr12
    sub   rax , r12 ; dec exp
  nosubr12:
    shl   rax , 52
    add   rax , rcx
    add   rax , r15

    mov   r15 , [sign]
    shl   r15 , 63
    add   rax , r15

  setzero:

    mov   [rdi],rax

    ret


add_to_screen_reg_pos:

  atsrpl10:

    cmp   al , 0
    je    atsrpl99

    push  rsi
    mov   rdi , rsi
    add   rdi , 1
    mov   rcx , 100
    add   rsi , rcx
    add   rdi , rcx
    add   rcx , 1
    std
    rep   movsb
    cld
    pop   rsi

    call  get_screen_value

    mov   [rsi],byte al
    shr   rax , 8
    add   rsi , 1
    jmp   atsrpl10

  atsrpl99:

    ret


get_screen_value:

    cmp   al , 'A'
    jb    noadd32
    cmp   al , 'Z'
    ja    noadd32
    add   al , 32
  noadd32:

    ret

          

add_to_screen_reg:

  ats2l0:
    push  rax
    call  get_screen_value
    call  add_to_screen
    pop   rax
    shr   rax , 8
    cmp   al  , 0
    jne   ats2l0
    ret


add_to_screen:

    mov   rsi , string_screen
  atsl0:
    cmp   [rsi],byte 0
    je    atsl1
    add   rsi , 1
    jmp   atsl0
  atsl1:
    sub   rsi , [cursorposition]
    ; Delete
    cmp   al , 8
    jne   nodel
    cmp   rsi , string_screen
    jbe   atsl99
    push  rcx rsi rdi
    mov   rdi , rsi
    sub   rdi , 1
    mov   rcx , 100
    cld
    rep   movsb
    pop   rdi rsi rcx
    jmp   atsl99
  nodel:
    ; Insert
    ; Make room
    push  rcx rsi rdi
    mov   rdi , rsi
    add   rdi , 1
    mov   rcx , 100
    add   rdi , rcx
    add   rsi , rcx
    add   rcx , 1
    std
    rep   movsb
    cld
    pop   rdi rsi rcx

    mov   [rsi],al
;    mov   [rsi+1],dword 0

  atsl99:

    call  add_to_history_current
    call  print_screen_string

    ret


print_screen_string:

    stlen equ 46

    mov   r12 , xpos+xsize+53+stlen*6
    mov   r13 , ypos-24
    mov   r14 , string_screen
    call  print_line

    cmp   [cursorposition],r15
    jbe   cpfine
    mov   [cursorposition],r15
  cpfine:

    mov   rax , 38
    mov   rbx , xpos+xsize*10-5
    mov   rcx , [cursorposition]
    imul  rcx , 6
    sub   rbx , rcx
    cmp   [cursorposition],dword 0
    jne   noadd2
    add   rbx , 3
  noadd2:
    mov   rdx , rbx
    mov   rcx , ypos-24-3     -1
    mov   r8  , ypos-24-3+12  +1
    mov   r9  , 0xc0c0c0
    int   0x60

    ret



print_line:

    mov   rax , 13
    mov   rbx , (xpos+xsize+53-1) shl 32 + 6*stlen+5
    mov   rcx , r13 ; (ypos-24-4) shl 32 + 15
    sub   rcx , 4
    shl   rcx , 32
    add   rcx , 15
    mov   rdx , 0xffffff
    int   0x60

    cmp   [string_screen],byte 0
    jne   pssl20
    mov   rdx , 6
    mov   rbx , string_zero
    mov   [cursorposition],dword 0
    jmp   pssl30
  pssl20:

    mov   rbx , r14 ; string_screen-1
    sub   rbx , 1
    mov   rdx , -6
    mov   r15 , 0
  pssl0:
    add   r15 , 1
    add   rbx , 1
    add   rdx , 6
    cmp   [rbx],byte 0
    jne   pssl0
    cmp   r15 , stlen+1
    jbe   curpfine
    mov   r15 , stlen+1
  curpfine:
    sub   r15 , 1
    mov   r8  , r14
    add   r8  , stlen
    cmp   rbx , r8 ; string_screen+stlen
    jb    pssl1
    sub   rbx , stlen
    mov   rdx , 6*stlen
    jmp   pssl2
  pssl1:
    mov   rbx , r14 ; string_screen
  pssl2:

  pssl30:

    mov   rax , 4
    mov   rcx , r12 ; xpos+xsize+53+stlen*6
    sub   rcx , rdx
    mov   rdx , r13 ; ypos-24
    mov   rsi , 0
    mov   r9  , 1
  pssl80:
    mov   r10b , [rbx]
    cmp   r10b , 0
    je    pssl99
    push  rbx rdx
    cmp   r10b , '!'
    jne   noc1
    mov   r10b , '1'
    add   rdx , 3
  noc1:
    cmp   r10b , '"'
    jne   noc2
    mov   r10b , '2'
    add   rdx , 3
  noc2:
    cmp   r10b , '#'
    jne   noc0
    mov   r10b , '0'
    add   rdx , 3
  noc0:
    mov   [string_char],r10b
    mov   rbx , string_char
    int   0x60
    pop   rdx rbx
    add   rcx , 6
    add   rbx , 1
    jmp   pssl80
  pssl99:

    ret


draw_window:

    mov   rax , 12                           ; Beginning of window draw
    mov   rbx , 1
    int   0x60

    mov   rax , 0                                ; Draw window
    mov   rbx , 178 shl 32 + xpos*2+xsize*10+1   ; X start & size
    mov   rcx , 97 shl 32 + ypos+xpos+ysize*5+1  ; Y start & size
    mov   rdx , 0x0000000000FFFFFF               ; Type    & border color
    mov   r8  , 0x0000000000000001               ; Flags (set as 1)
    mov   r9  , window_label                     ; 0 or label - asciiz
    mov   r10 , menu_struct                      ; 0 or pointer to menu struct
    int   0x60

    mov   rax , 38
    mov   rbx , xpos+xsize*2+10
    mov   rcx , ypos-30
    mov   rdx , xpos+xsize*10
    mov   r8  , ypos-30+18
    mov   r9  , 0xc0c0c0
    push  r8
    mov   r8  , rcx
    int   0x60
    pop   r8
    push  rcx
    mov   rcx , r8
    int   0x60
    pop   rcx
    push  rbx
    mov   rbx , rdx
    int   0x60
    pop   rbx
    push  rdx
    mov   rdx , rbx
    int   0x60
    pop   rdx

    call  print_screen_string

    mov   rsi , buttons
    mov   rdx , 100
  newbutton:
    mov   rax , 8
    movzx rbx , byte [rsi]
    imul  rbx , xsize
    movzx rcx , byte [rsi+1]
    imul  rcx , ysize
    add   rbx , xpos
    add   rcx , ypos
    shl   rbx , 32
    shl   rcx , 32
    add   rbx , xsize
    add   rcx , ysize
    mov   r8  , 0
    mov   r9  , rsi
    add   r9  , 2
    cmp   [r9],byte '='
    jne   nodouble
    shl   bl , 1
  nodouble:
    push  qword [r9]
    mov   r15 , r9
  newset:
    cmp   [r15],byte 0
    je    nonewset
    cmp   [r15],byte '!'
    jne   nosetto1
    mov   [r15],byte '1'
  nosetto1:
    cmp   [r15],byte '"'
    jne   nosetto2
    mov   [r15],byte '2'
  nosetto2:
    cmp   [r15],byte '#'
    jne   nosetto0
    mov   [r15],byte '0'
  nosetto0:
    add   r15 , 1
    jmp   newset
  nonewset:
    int   0x60
    pop   qword [r9]

    add   rsi , 2

  norsiz:
    add   rsi , 1
    cmp   [rsi],byte 0
    jne   norsiz

    add   rsi , 1
    add   rdx , 1

    cmp   [rsi],dword 0
    jne   newbutton

    mov   rax , 8
    mov   rbx , xpos
    mov   rcx , ypos-30-1
    shl   rbx , 32
    shl   rcx , 32
    add   rbx , xsize
    add   rcx , ysize-5+2
    mov   rdx , 300
    mov   r8  , 0
    mov   r9  , button_c
    int   0x60
    mov   rax , 8
    mov   rbx , xpos+xsize
    mov   rcx , ypos-30-1
    shl   rbx , 32
    shl   rcx , 32
    add   rbx , xsize
    add   rcx , ysize-5+2
    mov   rdx , 301
    mov   r8  , 0
    mov   r9  , button_back
    int   0x60

    mov   rax , 12                           ; End of window draw
    mov   rbx , 2
    int   0x60

    ret


;
; Data area
;

window_label:

    db    'CALC',0     ; Window label

button_c:     db 'C',0
button_back:  db '<',0

buttons:

    db    0,0,'A',0
    db    1,0,'B',0
    db    2,0,'C',0
    db    3,0,'D',0
    db    4,0,'E',0
    db    5,0,'F',0
    db    6,0,'BIN',0
    db    7,0,'DEC',0
    db    8,0,'HEX',0
    db    9,0,'(',0

    db    0,1,'7',0
    db    1,1,'8',0
    db    2,1,'9',0
    db    3,1,'+',0
    db    4,1,'SIN',0
    db    5,1,'SQR',0
    db    6,1,'ASIN',0
    db    7,1,'LOG',0
    db    8,1,'LOG!#',0
    db    9,1,')',0

    db    0,2,'4',0
    db    1,2,'5',0
    db    2,2,'6',0
    db    3,2,'-',0
    db    4,2,'COS',0
    db    5,2,'INT',0
    db    6,2,'ACOS',0
    db    7,2,'LOG"',0
    db    8,2,'ILOGB',0
    db    9,2,'M<',0

    db    0,3,'1',0
    db    1,3,'2',0
    db    2,3,'3',0
    db    3,3,'/',0
    db    4,3,'TAN',0
    db    5,3,'PI',0
    db    6,3,'ATAN',0
    db    7,3,' E ',0
    db    8,3,'CBRT',0
    db    9,3,'M>',0

    db    0,4,'-/+',0
    db    1,4,'0',0
    db    2,4,'.',0
    db    3,4,'*',0
    db    4,4,'X^Y',0
    db    5,4,'EXP',0
    db    6,4,'EXP"',0
    db    7,4,'EXP!#',0
    db    8,4,'=',0

    dd    0

if constant=1
string_constants:

    db    '2.7182818284590',0,'    '       ; Eulers
    db    '96485.33289',0,'        '       ; Faraday
    db    '3.1415926535898',0,'    '       ; Pi
    db    '299792458',0,'          '       ; Speed of Light
    db    '340.27',0,'             '       ; Speed of Sound
    db    '9.80665',0,'            '       ; Standard Gravity
end if

string_zero: db '0',0

string_example: db '2*(2+3)^3+sin(-3.1*-2)/2',0
string_example_end:

string_info:
              db  'Arrows up/down    - Scan History ',0
string_info_length:
              db  'Arrows left/right - Edit formula ',0
              db  'Ctrl-z/x - Log,Exp base 2/10     ',0
              db  '                                 ',0
              db  'To display stepped calculation   ',0
              db  "results, press '=' with ctrl-key.",0
              db  0

numtype: dq 10

menu_struct:               ; Menu Struct

    dq   0                 ; Version

    dq   0x100             ; Start value of ID to return ( ID + Line )
                           ; Returned when menu closes and
                           ; user made no selections.
    db   0,'FILE',0        ; ID = 0x100 + 1
    db   1,'Info..',0
    db   1,'Example..',0   ; ID = 0x100 + 2
    db   1,'-',0           ; ID = 0x100 + 5
    if constant=1
    db   1,'Eulers number',0
    db   1,'Faradays constant',0
    db   1,'Pi',0
    db   1,'Speed of Light',0
    db   1,'Speed of Sound',0
    db   1,'Standard Gravity',0
    db   1,'-',0           ; ID = 0x100 + 5
    end if
    db   1,'Quit',0        ; ID = 0x100 + 6

    db   255               ; End of Menu Struct

cleardata:

align 64

numr10: dq ?,?
numr11: dq ?,?

                dq ?            ; together
string_screen:  times 300 db ?  ; atleast 300
string_memory:  times 300 db ?  ; atleast 300

string_rounding: times 300 db ?
string_convert:  times 300 db ?
string_temp:     times 300 db ?

floatend: dq ?
skipdec:  dq ?
stepped:  dq ?
sign:     dq ?

calcpressed: dq ?
string_char: db ?,?

cleardataend:


image_end:
                    

              




