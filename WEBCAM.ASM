;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;                                        
;   64 bit Menuet Webcam
;
;   Compile with FASM 1.60 or above
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

data1   equ  image_end+0x100000*01  ; Timestamp data
data4   equ  image_end+0x100000*02  ; Image data time order
data5   equ  image_end+0x100000*03  ; Length data time order
data6   equ  image_end+0x100000*04  ; Decoded image
data8   equ  0x100000*10            ; 7M*4 - Data return, 4k aligned
data9   equ  0x100000*46            ; 1M*4 - Data length return
data10  equ  0x100000*50            ; Save snap / avi - size 16M

scx     equ  3                      ; Scroll x pos
scy     equ  0                      ; Scroll y pos
scl     equ  -9                     ; Scroll length
sct     equ  -3                     ; Scroll text y pos
b3y     equ  1                      ; B3y add 
bys     equ  21                     ; Buttons y add
serverb equ  (141+b3y) shl 32 + bys
clipb   equ  (183+b3y) shl 32 + bys
snapb   equ  (162+b3y) shl 32 + bys
sby     equ  (204+b3y) shl 32 + bys
rby     equ  (225+b3y) shl 32 + bys

packetcount  equ  1024 ; 1024 ; 512 ; /4 = 128buf
buffercount  equ  64
data8mul     equ  (1024*3*8*packetcount)
data9mul     equ  (8*8*packetcount)


use64

    org   0x0

    db    'MENUET64'          ; Header identifier
    dq    0x01                ; Version
    dq    START               ; Start of code
    dq    image_end           ; Size of image
    dq    data10+0x100000*16  ; Memory for app
    dq    image_end           ; Stack
    dq    parameter           ; Prm 
    dq    0x00                ; Icon


turn_camera_on:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Reserves, configures and turns camera on
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    cmp   [camera_state],byte 1
    je    camera_on

    mov   rax , 0
    mov   [prevdatapos],rax
    mov   [fmissed],rax

    ; Camera present ?

    mov   rax , 128
    mov   rbx , 1
    int   0x60
    add   rax , rbx
    cmp   rax , 0
    je    camera_fail

    ; Configuration found ?

    cmp   [sconf],dword 0
    je    camera_fail

    ; Set configuration

    mov   rax , 128
    mov   rbx , 3
    mov   rcx , 1
    mov   rdx , [sconf]
    int   0x60

    ; Start camera

    mov   rax , 128
    mov   rbx , 4
    mov   rcx , 1
    mov   rdx , 1
    int   0x60

    mov   [camera_state],byte 1

  camera_fail:
  camera_on:

    ret


turn_camera_off:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Turns camera off and clears the reservation
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    cmp   [camera_state],byte 0
    je    camera_off

    ; Camera present ?

    mov   rax , 128
    mov   rbx , 1
    int   0x60
    add   rax , rbx
    cmp   rax , 0
    je    camera_off

    ; Stop camera

    mov   rax , 128
    mov   rbx , 4
    mov   rcx , 1
    mov   rdx , 0
    int   0x60

    ; Set configuration 0

    mov   rax , 128
    mov   rbx , 3
    mov   rcx , 1
    mov   rdx , 0
    int   0x60

  camera_off:

    mov   [camera_state],byte 0

    ; Turn off read thread

    mov   r9 , 'STOP'
    mov   [data9-8],r9
    cmp   [thread_running],byte 0
    je    nowaitthreadclose
 waitthreadclose:
    mov   rax , 5
    mov   rbx , 1
    int   0x60
    cmp   [thread_running],byte 1
    je    waitthreadclose
    mov   rax , 5
    mov   rbx , 25
    int   0x60
  nowaitthreadclose:

    ret



server:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Server thread for webcam picture - port 8090
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    mov   [serveronoff],byte 1

    mov   [datasent],dword 0

  server_open:

    ; Open port

    mov   rax , 53
    mov   rbx , 5
    mov   rcx , 8090
    mov   rdx , 0
    mov   rsi , 0
    mov   rdi , 0 ; Passive mode
    int   0x60

    mov   [server_socket],eax

    mov   r15 , 100*30

  server_loop:

    ; Close server port and re-open every 30 seconds

    dec   r15
    jz    timeoutclose

    ;

    mov   rax , 5
    mov   rbx , 1
    int   0x60

    cmp   [serveronoff],byte 2
    je    serveroff

    ; Server status ?

    mov   rax , 53
    mov   rbx , 6
    mov   rcx , [server_socket]
    int   0x60

    cmp   rax , 4
    jne   server_loop

    ; Wait 0.50 seconds

    mov   rax , 5
    mov   rbx , 50
    int   0x60

    mov   [picsend],byte 0

    ; Read all data

  read_server_data:

    mov   rax , 53
    mov   rbx , 3
    mov   rcx , [server_socket]
    int   0x60

    shl   r8  , 8
    mov   r8b , bl

    mov   r9  , 'pmb.egam'
    cmp   r8  , r9
    jne   nopicsend2
    mov   [picsend],byte 1
  nopicsend2:

    cmp   rax , 0
    jne   read_server_data

    ; Wait 0.05 seconds

    mov   rax , 5
    mov   rbx , 5
    int   0x60

    ; Send index htm file

    cmp   [picsend],byte 0
    jne   noindexsend

    mov   rax , 53
    mov   rbx , 7
    mov   rcx , [server_socket]
    mov   rdx , h_i_len-html_header_index
    mov   rsi , html_header_index
    int   0x60

    jmp   nopicsend

  noindexsend:

    ; form picture to data10+

    mov   rax , [resx]
    mov   [sizex],rax
    mov   rax , [resy]
    mov   [sizey],rax
    call  form_picture

    ; send picture - html header

    mov   rax , '00230454' ; 320
    cmp   [resx],dword 160
    jne   nor160
    mov   rax , '00057654' ; 160
  nor160:
    cmp   [resx],dword 640
    jne   nor640
    mov   rax , '00921654' ; 640
  nor640:
    mov   [hsz],rax 

    mov   rax , 53
    mov   rbx , 7
    mov   rcx , [server_socket]
    mov   rdx , h_len-html_header
    mov   rsi , html_header
    int   0x60

    mov   rax , 105
    mov   rbx , 100
    int   0x60

    ; send picture - bmp header

    mov   rax , 53
    mov   rbx , 7
    mov   rcx , [server_socket]
    mov   rdx , 54
    mov   rsi , data10
    int   0x60

    ; send picture - bmp data

    mov   rsi , data10+54

    mov   r15 , 99999
    call  server_stats
    mov   r15 , 0

  newdatasend:

    mov   rax , 53
    mov   rbx , 6
    mov   rcx , [server_socket]
    int   0x60
    cmp   rax , 4
    jne   timeoutclose

    mov   rax , 53
    mov   rbx , 7
    mov   rcx , [server_socket]
    mov   rdx , 160*3
    int   0x60

    ;mov   rax , 105
    ;mov   rbx , 3
    ;int   0x60

    ; If camera is off, display the stats

    call  server_stats ; In:r15

    add   rsi , 160*3

    mov   [datasent],rsi
    sub   [datasent],dword data10+54

    mov   rbx , [resx_resy_3]
    add   rbx , data10+54 

    cmp   rsi , rbx
    jb    newdatasend

  timeoutclose:
  nopicsend:

    mov   rax , 5
    mov   rbx , 5
    int   0x60

    ; close port

    mov   rax , 53
    mov   rbx , 8
    mov   rcx , [server_socket]
    int   0x60

    mov   [datasent],dword 0

    mov   r15 , 99999
    call  server_stats

    ;mov   rax , 5
    ;mov   rbx , 50
    ;int   0x60

    jmp   server_open

  serveroff:

    ; Close port

    mov   rax , 53
    mov   rbx , 8
    mov   rcx , [server_socket]
    int   0x60

    mov   [serveronoff],byte 3

    mov   rax , 512
    int   0x60


server_stats:
;
; In: r15 - counter
;
    cmp   [camera_state],byte 1
    je    nodfps
    inc   r15
    cmp   r15 , 75
    jb    nodfps
    mov   [show_fps],byte 1
    mov   r15 , 0
  nodfps:

    ret



check_parameter:

    cmp   [parameter+8],dword 'PID:'
    jne   cpl99
    mov   rsi , parameter+8+4
    mov   rbx , 0
  cpl00:
    movzx rax , byte [rsi]
    cmp   rax , '0'
    jb    cpl01
    sub   al  , 48
    imul  rbx , 10
    add   rbx , rax
    add   rsi , 1
    jmp   cpl00
  cpl01:
    cmp   rbx , 0
    je    closedirect
    mov   [pid],rbx
    mov   rax , 60
    mov   rbx , 1
    mov   rcx , ipcmem
    mov   rdx , 8
    int   0x60
    call  draw_scroll_values
    ; Send PID
    mov   rax , 111
    mov   rbx , 1
    int   0x60
    mov   [string_pid+4],rax
    mov   rax , 60
    mov   rbx , 2
    mov   rcx , [pid]
    mov   rdx , string_pid
    mov   r8  , 4+8
    int   0x60
  cpl99:

    ret



START:

    call  check_parameter

    mov   rax , 58
    mov   rbx , 0
    mov   rcx , 0
    mov   rdx , (65536*2)/512-10
    mov   r8  , decoder_image
    mov   r9  , picview
    int   0x60
    mov   [decoder_size],rbx

    mov   rax , 141
    mov   rbx , 1
    mov   rcx , 1
    mov   rdx , 5 shl 32 + 5
    mov   r8  , 9 shl 32 + 12
    int   0x60

    call  grey_default

    ; Draw window

    call  draw_window    

    cmp   [pid],dword 0
    jne   ondirect

still:

    cmp   [pid],dword 0
    je    nopidcheck
    call  setpiderror
    cmp   [piderror],dword 0
    je    nope
    mov   rax , 26
    mov   rbx , 1
    mov   rcx , fps_data
    mov   rdx , 1024
    int   0x60
    mov   rcx , [fps_data+5*8]
    cmp   [piderror],rcx
    jb    closedirect
  nope:
    cmp   [ipcmem+16],dword 'STOP'
    je    closedirect
  nopidcheck:

    mov   rax , 123          ; Check for event
    mov   rbx , 1
    int   0x60

    test  rax , 0x1         ; Window redraw
    jnz   window_event
    test  rax , 0x2         ; Keyboard press
    jnz   key_event
    test  rax , 0x4         ; Button press
    jnz   button_event

    call  check_camera_state

    call  read_data

    cmp   [show_fps],byte 1
    jne   nosfps
    call  display_frames_per_second
    mov   [show_fps],byte 0
  nosfps:

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
  closedirect:
    call  turn_camera_off
    call  remove_decoders
    mov   rax , 0x200
    int   0x60
  no_application_terminate_button:

    cmp   rbx , 0x102
    jb    no_stats
    cmp   rbx , 0x103
    ja    no_stats
    sub   rbx , 0x102
    mov   [sta1+1],byte ' '
    mov   [sta2+1],byte ' '
    imul  rbx , 14
    mov   [sta1+1+rbx],byte '>'
    call  fps_background
    call  display_frames_per_second
    jmp   still
  no_stats:

    cmp   rbx , 0x109
    jne   no_application_terminate_menu
    call  turn_camera_off
    call  remove_decoders
    mov   rax , 0x200
    int   0x60
  no_application_terminate_menu:

    cmp   rbx , 0x105
    jb    no_effect
    cmp   rbx , 0x107
    ja    no_effect
    sub   rbx , 0x105
    mov   [eo+1],byte ' '
    mov   [eb+1],byte ' '
    mov   [en+1],byte ' '
    imul  ebx , 18
    mov   [eo+1+rbx],byte '>'
    jmp   still
  no_effect:

    ; Streamtype

    cmp   rbx , 125
    jne   nostreamtypechange

    ; Turn camera off

    call  turn_camera_off
    call  remove_decoders

    ; Turn server off

    cmp   [serveronoff],byte 1
    jne   noserveron3
    mov   [serveronoff],byte 2
    mov   rax , 5
    mov   rbx , 20
    int   0x60
    call  server_button
  noserveron3:

    sub   [streamtype],byte 1
    shr   dword [streamtype],byte 1
    add   [streamtype],byte 1
    and   [streamtype],byte 1
    shl   dword [streamtype],byte 1
    add   [streamtype],byte 1
    call  resolution_buttons
    jmp   still
  nostreamtypechange:

    cmp   rbx , 121
    jb    nomodechange
    cmp   rbx , 123
    ja    nomodechange

    ; Turn camera off

    push  rbx
    call  turn_camera_off
    call  remove_decoders
    pop   rbx

    ; Turn server off

    push  rax rbx
    cmp   [serveronoff],byte 1
    jne   noserveron2
    mov   [serveronoff],byte 2
    mov   rax , 5
    mov   rbx , 20
    int   0x60
    call  server_button
  noserveron2:
    pop   rbx rax

    ;

    cmp   rbx , 123 ; 640 & 800
    jne   screenresxfine
    call  get_data_boot_info
    cmp   [data_boot_info+4*8],dword 800
    jae   screenresxfine
    mov   rax , 4
    mov   rbx , string_screen_req
    mov   rcx , 15+5
    mov   rdx , 49+5
    mov   rsi , 0xffffff
    mov   r9  , 1
    int   0x60
    mov   rax , 5
    mov   rbx , 200
    int   0x60
    call  display_image_yuv
    jmp   still
  screenresxfine:

    mov   r11 , [xpos]

    sub   rbx , 121

    mov   r8 , [xr+rbx*8]
    mov   r9 , [yr+rbx*8]
    mov   r10, [xp+rbx*8]

    cmp   r8 , [resx] ; already selected
    je    still

    mov   [resx],r8
    mov   [resy],r9
    mov   [xpos],r10

    imul  r8 , r9
    mov   r9 , r8
    add   r8 , r9
    mov   [resx_resy_2],r8
    add   r8 , r9
    mov   [resx_resy_3],r8
    add   r8 , r9
    mov   [resx_resy_4],r8

    cmp   r11 , [xpos] ; redraw needed
    jne   redraw
    mov   rax , 13
    mov   rbx , 15 shl 32 + 320
    mov   rcx , 49 shl 32 + 240
    mov   rdx , 0xffffff
    int   0x60
    call  display_image_yuv
    mov   [camera_connection_status],dword 2
    call  check_camera_state
    jmp   still
  redraw:

    mov   rax , 67
    mov   rbx , -1
    mov   rcx , -1

    mov   rdx , [resx]
    cmp   rdx , 320
    jae   rdxfine
    mov   rdx , 320
  rdxfine:
    mov   r8  , [resy]
    cmp   r8  , 240
    jae   r8fine
    mov   r8  , 240
  r8fine:
    add   rdx , 160
    add   r8  , 70

    cmp   r11 , [xpos]
    jae   noupleft
    mov   rbx , 0
    mov   rcx , 0
    mov   r8  , 561 ; 640x480 picture
  noupleft:

    int   0x60

    jmp   still

  nomodechange:

    cmp   rbx , 101
    jne   no_on
  ondirect:

    call  scan_for_configuration
    mov   [sconf],r12

    call  turn_camera_on
    jmp   still
  no_on:

    cmp   rbx , 102
    jne   no_off
    mov   [record_state],byte 0
    cmp   [serveronoff],byte 1
    jne   noserveron
    mov   [serveronoff],byte 2
    mov   rax , 5
    mov   rbx , 20
    int   0x60
  noserveron:
    call  turn_camera_off
    call  remove_decoders
    call  server_button
    jmp   still
  no_off:

    cmp   rbx , 103
    jne   no_snap
    mov   [savepicture],byte 1
    jmp   still
  no_snap:

    cmp   rbx , 104
    jne   no_clip
    cmp   [camera_state], byte 1
    jne   still
    cmp   [resx],dword 320
    je    resolutionfine
    mov   rax , 4
    mov   rbx , string_resolution_320
    mov   rcx , 15+5
    mov   rdx , 49+5
    mov   rsi , 0xffffff
    mov   r9  , 1
    int   0x60
    mov   rax , 5
    mov   rbx , 100
    int   0x60
    call  display_image_yuv
    jmp   still
  resolutionfine:
    mov   [record_state],byte 1
    mov   [record_position], dword data10+1208
    mov   rax , data10+(avi_end-avi_start)
    mov   [record_position],rax
    jmp   still
  no_clip:

    cmp   rbx , 105
    jne   no_server
    cmp   [serveronoff],byte 3
    je    startserver
    mov   [serveronoff],byte 2
  waitmore:
    mov   rax , 5
    mov   rbx , 10
    int   0x60
    call  read_data
    cmp   [serveronoff],byte 2
    je    waitmore
    call  server_button
    jmp   still
  startserver:
    ; Start server thread
    mov   rax , 51
    mov   rbx , 1
    mov   rcx , server
    mov   rdx , server_stack
    int   0x60
    mov   rax , 5
    mov   rbx , 10
    int   0x60
    call  server_button
    jmp   still
  no_server:


    cmp   rbx , 10000
    jb    noscroll1
    cmp   rbx , 11000
    ja    noscroll1
    mov   [scroll_value_1],rbx
    call  draw_scroll_1
    call  draw_scroll_values
    jmp   still
  noscroll1:

    cmp   rbx , 20000
    jb    noscroll2
    cmp   rbx , 21000
    ja    noscroll2
    mov   [scroll_value_2],rbx
    call  draw_scroll_2
    call  draw_scroll_values
    jmp   still
  noscroll2:

    cmp   rbx , 30000
    jb    noscroll3
    cmp   rbx , 31000
    ja    noscroll3
    mov   [scroll_value_3],rbx
    call  draw_scroll_3
    call  draw_scroll_values
    jmp   still
  noscroll3:

    jmp   still




scan_for_configuration:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Configuration for selected resolution
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    mov   r12 , 001b         ; 160x120
    ;
    mov   r14 , 010b
    cmp   [resx],dword 320
    cmove r12 , r14          ; 320x240
    ;
    mov   r14 , 100b
    cmp   [resx],dword 640
    cmove r12 , r14          ; 640x480

    mov   rdx , 1

  newconftest:

    mov   rax , 128
    mov   rbx , 2
    mov   rcx , 1
    int   0x60

    mov   rax , rbx
    shr   rax , 32
    cmp   rax , [streamtype]
    jne   nothistype

    shr   rbx , 16
    and   rbx , 0xff
    cmp   rbx , r12
    je    cfound

  nothistype:

    inc   rdx
    cmp   rdx , 14
    jbe   newconftest

    mov   r12 , 0 ; conf not found
    ret

  cfound:

    mov   r12 , rdx ; conf found
    ret



grey_default:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Grey default picture
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    mov   rdi , data6
    mov   rcx , [resx]
    imul  rcx , [resy]
    imul  rcx , 4
    mov   rax , 0xe0
    cld
    rep   stosb

    ret


get_data_boot_info:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Screen resolution
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    push  rax rbx rcx rdx
    mov   rax , 26
    mov   rbx , 3
    mov   rcx , data_boot_info
    mov   rdx , 8*20
    int   0x60
    pop   rdx rcx rbx rax

    ret



check_camera_state:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Displays text message if camera is disconnected
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    mov   rax , 128
    mov   rbx , 1
    int   0x60
    add   rax , rbx

    cmp   rax , [camera_connection_status]
    je    no_camera_change

    mov   [camera_connection_status],rax

    cmp   [pid],dword 0
    jne   nogrd
    push  rax
    call  grey_default
    call  display_image_yuv
    pop   rax
  nogrd:

    cmp   rax , 0
    jne   camera_connected

    mov   rax , 4
    mov   rbx , string_camera_disconnected
    mov   rcx , 114
    mov   rdx , 162
    mov   rcx , [resx]
    shr   rcx , 1
    add   rcx , 15
    sub   rcx , 62
    mov   rdx , [resy]
    shr   rdx , 1
    add   rdx , 43
    mov   rsi , 0xb8b8b8
    mov   r9  , 1
    int   0x60

  camera_connected:

  no_camera_change:

    ret






check_framerate: ; 1.23.9x

    mov   rax , 26
    mov   rbx , 1
    mov   rcx , fps_data
    mov   rdx , 1024
    int   0x60

    ; Display FPS and adjust display rate delay

    mov   rax , [fps_n]
    cmp   rax , [fps_data+384]
    ja    nofps
    add   rax , 1000
    cmp   rax , [fps_data+384]
    jae   nextfine
    mov   rax , [fps_data+384]
  nextfine:
    mov   [fps_n],rax

    ; If no images displayed during 2sec
    ; then show buffer
    cmp   [frames_per_second],dword 0
    ja    nofrpsz2
    add   [fmissed],dword 1
    cmp   [fmissed],dword 3
    jb    nofrpsz2
    call  display_image_yuv
  nofrpsz2:
    ;
    cmp   [frames_per_second],dword 5
    jae   nofrpsz
    mov   [frames_per_second],dword 5
  nofrpsz:
    ;cmp   [frames_per_second],dword 30
    ;jbe   nofrpst
    ;mov   [frames_per_second],dword 30
    ;nofrpst:
    call  display_frames_per_second
    mov   rbx , [frames_per_second]
    add   rbx , [frames_per_second_missed]
    mov   [framerate],rbx
    mov   [frames_per_second],dword 0
    mov   [frames_per_second_missed],dword 0

  nofps:

    ret



display_frames_per_second:

    cmp   [sta2+1],byte '>'
    jne   nodispstats

    fpsy  equ 24

    call  fps_background
    ;
    mov   rax , 47
    mov   rbx , 6 * 65536
    mov   rcx , [datasent]
    mov   rdx , [fpsx]
    add   rdx , 2+6*5
    shl   rdx , 32
    add   rdx , fpsy+4
    mov   rsi , 0xb0b0b0
    int   0x60
    ;
    mov   rax , 47
    mov   rbx , 2 * 65536
    mov   rcx , [frames_per_second]
    mov   rdx , [fpsx]
    add   rdx , 2+6*16
    shl   rdx , 32
    add   rdx , fpsy+4
    mov   rsi , 0xb0b0b0
    int   0x60
    mov   rax , 47
    mov   rbx , 2 * 65536
    mov   rcx , [frames_per_second]
    add   rcx , [frames_per_second_missed]
    mov   rdx , (fpsx+2+19*6) shl 32 + fpsy+4
    mov   rdx , [fpsx]
    add   rdx , 2+19*6
    shl   rdx , 32
    add   rdx , fpsy+4
    mov   rsi , 0xb0b0b0
    int   0x60
    mov   rax , 0x4                      
    mov   rbx , string_fps
    mov   rcx , [fpsx]
    add   rcx , 2
    mov   rdx , fpsy+4
    mov   rsi , 0xb0b0b0
    mov   r9  , 1
    int   0x60

  nodispstats:

    ret

  fps_background:

    mov   rax , [xpos]
    sub   rax , 8
    mov   [fpsx],rax

    mov   rax , 13
    mov   rbx , [fpsx]
    sub   rbx , 3
    shl   rbx , 32
    add   rbx , 22*6+5
    mov   rcx , fpsy shl 32 + 14
    mov   rdx , 0xe8e8e8
    int   0x60

    ret



read_block:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Starts the read thread
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    cmp   [thread_running],byte 0
    jne   nostartthread

    ; Start thread

    mov   [thread_running],byte 1

    mov   rax , 51
    mov   rbx , 1
    mov   rcx , read_thread
    mov   rdx , thread_stack
    int   0x60

    mov   [prevtsc],dword 0
    mov   [imagestart],dword data1
    mov   [threadpos],dword 0
    mov   [threadposprev],dword 0
    mov   [savepicture],byte 0

  nostartthread:

    ret



read_thread: ; 1.23.9x
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Read data block in a separate thread.
;   Doesn't block main process.
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    mov   rax , 128
    mov   rbx , 5
    mov   rcx , 1

    mov   rdx , data8
    mov   r8  , data9

    mov   r9 , 'REPEAT'
    mov   [r8-8],r9

    mov   r9  , buffercount shl 32 + packetcount/buffercount

    int   0x60

    mov   [thread_running],byte 0

    mov   rax , 512
    int   0x60




get_threadpos: ; 1.23.9x

    push  rax
    movzx rax , byte [data9-1]
    mov   [threadpos],rax
    pop   rax

    ret





read_data: ; 1.23.9x
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Reads and analyzes data blocks from device
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    ;
    ; Camera enabled ?
    ;

    cmp   [camera_state],byte 1
    je    continue_read
    ret
  continue_read:

    ;
    ; Start thread
    ;

    call  read_block

    mov   rax , 5
    mov   rbx , 1
    int   0x60

    mov   rax , 26
    mov   rbx , 1
    mov   rcx , fps_data
    mov   rdx , 1024
    int   0x60

    mov   rax , [fps_data+384]
    cmp   [nextpic],rax
    ja    noframefound

    mov   rax , 1000
    mov   rbx , [framerate]
    add   rbx , 1
    xor   rdx , rdx
    div   rbx
    shr   rax , 1
    add   rax , [fps_data+384]
    mov   [nextpic],rax

    call  check_framerate

    call  get_threadpos
    mov   r8  , [threadpos]
    cmp   r8  , [threadposprev]
    je    noframefound
    mov   [threadposprev],r8

    mov   rdx , data8
    mov   r8  , data9
    mov   [pdata82],rdx  ; data   - 1024*3  4k aligned
    mov   [pdata92],r8   ; length - qword

    ;
    ; Analyze
    ;

    ;
    ; Arrange data to data1+ for faster cache access
    ;

    mov   rsi , [pdata82]
    mov   rdi , data1
  newarr:
    xor   rbx , rbx
    xor   rax , rax
    mov   al  , [rsi]
    cmp   al  , 1+6
    jb    nolenfine
    mov   ebx , [rsi+rax-6]
  nolenfine:
    mov   [rdi],rbx
    add   rsi , 1024*3
    add   rdi , 8
    cmp   rdi , data1+8*packetcount*8
    jb    newarr

    ;
    ; Timestamp order
    ;

    call  get_threadpos
    mov   r8  , [threadpos]
    imul  r8  , packetcount/buffercount
    imul  r8  , 8*8
    add   r8  , data1

    mov   r12 , data4 ; data position
    mov   r10 , data5 ; length position

  newdataorder2:

    ; Search for lowest timestamp count

    mov   rax , 0xfffffffff  ; timestamp

    mov   r11 , [imagestart] ; data1
    mov   r15 , r8 ; data1 + 8*packetcount*8

  lowsearch2:

    ; Timestamp position

    cmp   [r11+7],byte 1 ; used ?
    je    nolowfound2
    cmp   eax , [r11]    ; smaller ?
    jb    nolowfound2
    mov   r14 , r11      ; save position
    mov   eax , [r11]    ; save packet num
  nolowfound2:

    add   r11 , 8
    cmp   r11 , data1+8*packetcount*8
    jne   nowrap
    mov   r11 , data1
  nowrap:

    cmp   r11 , r15
    jne   lowsearch2

    mov   r13 , 0xfffffffff
    cmp   rax , r13
    jae   dataintimeorder2

    mov   rdx , r14
    sub   rdx , data1

    mov   rbx , rdx
    add   rbx , [pdata92]
    mov   [r10],rbx         ; save length position to line
    add   r10 , 8

    imul  rdx , 1024*3/8
    add   rdx , [pdata82]
    mov   [r12], rdx        ; save data position to line
    add   r12  , 8

    mov   [r14+7],byte 1

    jmp   newdataorder2

  dataintimeorder2:
  markdone:

    ; Mark end of list

    mov   [r12+00],dword 0xfffffff
    mov   [r12+08],dword 0xfffffff
    mov   [r12+16],dword 0xfffffff
    mov   [r12+24],dword 0xfffffff

    sub   r12 , 8
    sub   r10 , 8
    mov   [eolistd],r12
    mov   [eolistl],r10

    ;
    ; Search for latest sent images
    ;

    mov   r10 , [eolistd]
    mov   rax , [r10]
    mov   bl  , [rax+1]
    and   rbx , 1 ; toggle

    cmp   [streamtype],dword 3
    jne   noskipcurrentframe

    ; Search beginning of current frame
  newtsl1:
    sub   r10 , 8
    cmp   r10 , data4
    jbe   noframefound
    mov   rax , [r10]
    mov   cl  , [rax+1]
    and   rcx , 1
    cmp   bl  , cl
    je    newtsl1

    ; Search beginning of previous frames

    add   rbx , 1
    and   rbx , 1

  noskipcurrentframe:

  newtsl2:
    sub   r10 , 8
    cmp   r10 , data4
    jbe   noframefound
    mov   rax , [r10]
    mov   cl  , [rax+1]
    and   rcx , 1
    cmp   bl  , cl
    je    newtsl2
    add   r10 , 8

    ;
    ; MJPEG - check 0xffd8 - 0xffd9
    ;
    cmp   [streamtype],byte 3
    jne   no_stream_mjpeg

    push  rbx r10
    mov   r12 , r10
    mov   [framebegin],r12
    call  separate_data
    pop   r10 rbx

    mov   r15 , rdi
    mov   rsi , data6+0x200000-1
  newscc08:
    add   rsi , 1
    cmp   rsi , r15
    jae   newscc99
    cmp   [rsi],word 0xd8ff
    jne   newscc08
    mov   rdi , rsi
  newscc10:
    add   rdi , 1
    cmp   rdi , r15
    jae   newscc99
    cmp   [rdi],word 0xd9ff
    jne   newscc10
    jmp   stream_mjpeg
  newscc99:
    add   rbx , 1
    and   rbx , 1
    sub   r10 , 8
    jmp   newtsl2
  no_stream_mjpeg:

    ;
    ; YUV - get size of data
    ;
    push  rbx r10
    mov   r12 , r10
    mov   [framebegin],r12
    mov   [sizeonly],byte 1
    call  separate_data
    mov   [sizeonly],byte 0
    pop   r10 rbx

    ; YUV - check size

    mov   rax , data6
    add   rax , [resx_resy_4]
    cmp   rdi , rax
    je    framefound
    add   rbx , 1
    and   rbx , 1
    sub   r10 , 8
    jmp   newtsl2
  framefound:

    ; YUV - get data

    push  rbx r10
    mov   r12 , r10
    mov   [framebegin],r12
    call  separate_data
    pop   r10 rbx

    ; YUV - timestamp

    mov   rsi , [r10]
    xor   rax , rax
    xor   rbx , rbx
    mov   al  , [rsi]
    cmp   al  , 1+6
    jb    nolenfine15
    mov   ebx , [rsi+rax-6]
  nolenfine15:
    cmp   [prevtsc],dword 0xf0000000
    jb    nowraptsc
    cmp   rbx , 0x10000000
    ja    nowraptsc
    mov   [prevtsc],dword 0
  nowraptsc:
    cmp   rbx , [prevtsc]
    jbe   noframefound
    mov   [prevtsc],rbx

    jmp   imageready

  noframefound:

    ret

    ;
    ; MJPEG
    ;

  stream_mjpeg:

    ; MJPEG - time stamp

    mov   r11 , [r10]
    xor   rax , rax
    xor   rbx , rbx
    mov   al  , [r11]
    cmp   al  , 1+6
    jb    nolenfine16
    mov   ebx , [r11+rax-6]
  nolenfine16:
    cmp   [prevtsc],dword 0xf0000000
    jb    nowraptsc2
    cmp   rbx , 0x10000000
    ja    nowraptsc2
    mov   [prevtsc],dword 0
  nowraptsc2:
    cmp   rbx , [prevtsc]
    jbe   noframefound
    mov   [prevtsc],rbx

    add   rdi , 2
    mov   r15 , rdi
    sub   r15 , rsi
    mov   [decremove1],rsi
    mov   [decremove2],r15
    push  r10
    call  decode_external
    pop   r10

    cmp   rbp , 0
    je    imageready

    push  r10
    sub   r10 , data4
    add   r10 , data5
    mov   r8  , [r10]
    sub   r8  , data9
    add   r8  , data1
    mov   [imagestart],r8
    pop   r10

    ret

    ;
    ; Display image
    ;

  imageready:

    mov   al , [prevpicturetoggle]
    mov   bl , [picturetoggle]
    cmp   al , bl
    jne   noimageskipped
    inc   dword [frames_per_second_missed]
  noimageskipped:
    mov   [prevpicturetoggle],bl

    push  r10
    sub   r10 , data4
    add   r10 , data5
    mov   r8  , [r10]
    sub   r8  , data9
    add   r8  , data1
    mov   [imagestart],r8
    pop   r10

    call  display_image_yuv

    call  record_picture ; 10-30 fps
    call  record_picture ; 05-09 fps

    cmp   [savepicture],byte 1
    jne   nosavesnap
    mov   [savepicture],byte 0
    call  save_snap
  nosavesnap:

    ret





decode_external:
;
;   In: rsi,r15 - data position,size
;

    cmp   [picviewpid],dword 0
    je    notransformation

    ; IPC area

    mov   rax , 0
    mov   [data6-1168],rax
    mov   rax , 16
    mov   [data6-1168+8],rax
    mov   rax , [resx]
    imul  rax , [resy]
    imul  rax , 4
    sub   rax , 10
    mov   [data6+rax],dword 123123

    ; Define IPC

    mov   rax , 60
    mov   rbx , 1
    mov   rcx , data6-1168
    mov   rdx , 0x200000
    int   0x60

    ;

    sub   rsi , 208

    mov   rdi , rsi
    mov   rax , 0
    mov   rcx , 208
    cld
    rep   stosb
    ;
    ; Data header
    ;
    mov   rdi , rsi
    mov   rax , 1       ; 1=decode image
    stosq               ;
    add   rdi , 8       ; pid
    mov   al  , 1       ; 1=stream_type_mem
    stosq               ;
    add   rdi , 8*2     ; streamparam 1 & 2
    mov   al  , 32+1    ; scanlineformat - 32bpp
    stosq               ;

    ;
    ; Define pid
    ;
    mov   eax , 111
    mov   ebx , 1
    int   0x60
    mov   [rsi+8],rax
    ; header+image size
    mov   r8  , r15
    add   r8  , 208
    mov   [rsi+32],r8d
    ; if_image_backgcolor
    mov   r9 , 0xffffffff
    mov   [rsi+48+64],r9

    ; Send picture

    mov   r10 , 0

  newsendtry:

    mov   rax , 60
    mov   rbx , 2
    mov   rcx , [picviewpid]
    mov   rdx , rsi
    mov   r8  , r15
    add   r8  , 208
    int   0x60

    cmp   rax , 0
    je    sendfine

    mov   rax , 105
    mov   rbx , 1
    int   0x60

    add   r10 , 1
    cmp   r10 , 2000
    jae   notransformation

    jmp   newsendtry

  sendfine:

    mov   rdi , 0

  waitmore2:

    inc   rdi
    cmp   rdi , 1000
    ja    notransformation

    mov   rax , 11
    int   0x60
    cmp   rax , 0
    jne   notransformation

    mov   rax , 105
    mov   rbx , 1
    int   0x60

    mov   rax , [resx]
    imul  rax , [resy]
    imul  rax , 4
    sub   rax , 10

    cmp   [data6+rax],dword 123123
    je    waitmore2

    ; Decoding success ?

    cmp   [data6-1168+56],byte 6
    jne   notransformation

    call  start_decoder

    mov   rbp , 0

    ret

  notransformation:

    call  start_decoder

    mov   rbp , 1

    ret


start_decoder:

    push  rax rbx rcx

    mov   rax , [picviewpid+8]
    mov   rbx , [picviewpid+16]
    xor   rcx , rcx
    mov   [picviewpid+0],rax
    mov   [picviewpid+8],rbx
    mov   [picviewpid+16],rcx

    cmp   [camera_state],byte 1
    jne   stdl1
    cmp   [decoder_size],dword 10
    jbe   stdl1

    mov   rax , 257
    mov   rbx , decoder_image
    mov   rcx , parampw
    int   0x60
    mov   [picviewpid+16],rbx

  stdl1:

    pop   rcx rbx rax

    ret


remove_decoders:

    cmp   [streamtype],byte 3
    jne   rdl99

    mov   rcx , 0
  rdl1:
    push  rcx
    mov   rsi , [decremove1]
    mov   r15 , [decremove2]
    call  decode_external
    pop   rcx
    add   rcx , 1
    cmp   rcx , 6
    jb    rdl1

  rdl99:

    ret





display_number:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Displays scroll values 
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    push  rax rbx rcx rdx rsi

    push  rcx rdx
    mov   rax , 13
    mov   rbx , rdx
    sub   rbx , 2
    mov   rcx , rdx
    sub   rcx , 2
    mov   bx  , 6*3
    shl   rcx , 32
    add   rcx , 11
    mov   rdx , 0xffffff
    int   0x60
    pop   rdx rcx

    mov   rax , 47
    mov   rbx , 3 * 65536 + 0*256
    mov   rsi , 0x000000
    int   0x60

    pop   rsi rdx rcx rbx rax

    ret




separate_data: ; 1.23.9x
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Separates picture data from received packets
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    mov   rdi , data6

    cmp   [streamtype],byte 3
    jne   directcopy
    mov   rdi , data6+0x200000
  directcopy:

  separate_data_2:

    mov   r14 , [framebegin]

    mov   r13 , 0

  testnewline:

    cmp   [r14], dword 0xfffffff
    jae   nothisdata
    cmp   r14 , data4 + 8*8*packetcount
    jae   nothisdata

    mov   r10 , [r14]       ; data content position

    mov   rsi , r14
    add   rsi , data5
    sub   rsi , data4
    mov   rsi , [rsi]       ; data length position

    mov   rcx , [rsi]
    and   rcx , 0xfff
    mov   rbp , rcx

    movzx rdx , byte [r10]
    and   rdx , 0x7f

    cmp   rcx , rdx
    jbe   nothisc

    ;

    mov   rsi , r10
    add   rsi , rdx

    sub   rcx , rdx
    and   rcx , 4096-1

    cmp   rbp , 0
    je    nosett
    cmp   r13 , 0
    jne   nosett
    mov   r13 , [r10+1]
    and   r13 , 1
    add   r13 , 1
  nosett:

    cmp   [streamtype],byte 3
    jne   nodirectcopy
    cld
    rep   movsb
    jmp   noyuv
  nodirectcopy:

    mov   rbp , [r10+1]
    and   rbp , 1
    add   rbp , 1
    cmp   r13 , rbp
    jne   nothisdata

    cmp   [sizeonly],byte 1
    jne   nocalconly
    add   rdi , rcx
    add   rdi , rcx
    jmp   nothisc
  nocalconly:

    shr   rcx , 2

    push  rdx r8 r9 r10

  newdoform:

    cmp   rcx , 0
    je    nomoreform

    ; Effect: none

    cmp   [eo+1],byte '>'
    jne   noeffectoff
    movzx r8  , byte [rsi]
    movzx r9  , byte [rsi+1]
    movzx r10 , byte [rsi+3]
    call  calculate_yuv
    mov   [rdi+0],edx
    movzx r8  , byte [rsi+2]
    movzx r9  , byte [rsi+1]
    movzx r10 , byte [rsi+3]
    call  calculate_yuv
    mov   [rdi+4],edx
    jmp   pixelsdone
  noeffectoff:

    ; Effect: Blur

    cmp   [eb+1],byte '>'
    jne   noeffectblur
    movzx r8  , byte [rsi]
    movzx r9  , byte [rsi+1]
    movzx r10 , byte [rsi+3]
    call  calculate_yuv
    shr   edx , 1
    and   edx , 0x7f7f7f
    shr   dword [rdi],byte 1
    and   dword [rdi],dword 0x7f7f7f
    add   [rdi],edx
    movzx r8  , byte [rsi+2]
    movzx r9  , byte [rsi+1]
    movzx r10 , byte [rsi+3]
    call  calculate_yuv
    shr   edx , 1
    and   edx , 0x7f7f7f
    shr   dword [rdi+4],byte 1
    and   dword [rdi+4],dword 0x7f7f7f
    add   [rdi+4],edx
    jmp   pixelsdone
  noeffectblur:

    ; Effect: Negative

    cmp   [en+1],byte '>'
    jne   noeffectnegative
    movzx r8  , byte [rsi]
    movzx r9  , byte [rsi+1]
    movzx r10 , byte [rsi+3]
    call  calculate_yuv
    not   edx
    mov   [rdi+0],edx
    movzx r8  , byte [rsi+2]
    movzx r9  , byte [rsi+1]
    movzx r10 , byte [rsi+3]
    call  calculate_yuv
    not   edx
    mov   [rdi+4],edx
    jmp   pixelsdone
  noeffectnegative:

  pixelsdone:

    add   rdi , 8
    add   rsi , 4

    sub   rcx , 1
    jmp   newdoform

  nomoreform:

    pop   r10 r9 r8 rdx

    ;

    mov   rcx , [resx_resy_4]
    add   rcx , data6
    cmp   rdi , rcx
    jae   nothisdata

  noyuv:

  nothisc:

    add   r14 , 8

    jmp   testnewline

  nothisdata:

    mov   rax , 0xffffffffffffffff
    mov   [rdi],rax

    sub   r13b, 1
    mov   [picturetoggle],r13b

    ret







display_image_yuv:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Displays image
; 
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    cmp   [pid],dword 0
    je    nosendpic
    cmp   [camera_state],byte 1
    jne   yespiderror
    mov   rax , 111
    mov   rbx , 1
    int   0x60
    mov   r10 , rax
    mov   rax , 60
    mov   rbx , 2
    mov   rcx , [pid]
    mov   rdx , data6-4
    mov   [rdx] , dword 'PIC:'
    mov   [rdx+4+320*4*240],r10
    mov   r8  , 4+320*240*4+8
    int   0x60
    cmp   rax , 0
    jne   yespiderror
    mov   [piderror],dword 0
    ret
  yespiderror:
    call  setpiderror
    ret
  setpiderror:
    cmp   [piderror],dword 0
    jne   nosetpe
    mov   rax , 26
    mov   rbx , 1
    mov   rcx , fps_data
    mov   rdx , 1024
    int   0x60
    mov   rcx , [fps_data+5*8]
    add   rcx , 5*100
    mov   [piderror],rcx
  nosetpe:
    ret
  nosendpic:

    mov   rax , 7
    mov   rbx , 15 shl 32 
    mov   rcx , (49) shl 32
    add   rbx , [resx]
    add   rcx , [resy]
    mov   rdx , data6
    mov   r8  , 0
    mov   r9  , 0x1000000
    mov   r10 , 4
    int   0x60

    inc   dword [frames_per_second]

    ret



calculate_yuv:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   YUV to RGB
;
;   In:  r8,r9,r10 - YUV
;
;   Out: rdx - RGB
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    push  r11 r12 r13

    lea   r9  , [r9-128]
    lea   r10 , [r10-128]

    ; Red
    mov   rdx , r8
    mov   r11 , r10
    add   rdx , r11
    shr   r11 , 2
    add   rdx , r11
    shr   r11 , 1
    add   rdx , r11
    shr   r11 , 2
    add   rdx , r11
    imul  rdx , [scroll_value_1_multiply]
    shr   rdx , 7
    test  rdx , 1111100000000b
    jnz   redlimit
  redlimitret:
    shl   rdx , 8

    ; Green
    mov   r11 , r8
    mov   r12 , r9
    shr   r12 , 2
    mov   r13 , r12
    shr   r12 , 2
    add   r13 , r12
    shr   r12 , 1
    add   r13 , r12
    sub   r11 , r12
    mov   r12 , r10
    shr   r12 , 1
    mov   r13 , r12
    shr   r12 , 2
    add   r13 , r12
    shr   r12 , 1
    add   r13 , r12
    shr   r12 , 1
    add   r13 , 1
    sub   r11 , r13
    imul  r11 , [scroll_value_2_multiply]
    shr   r11 , 7
    test  r11 , 1111100000000b
    jnz   greenlimit
  greenlimitret:
    mov   dl  , r11b
    shl   rdx , 8

    ; Blue
    mov   r12 , r8
    mov   r11 , r9
    add   r12 , r11
    shr   r11 , 1
    add   r12 , r11
    shr   r11 , 1
    add   r12 , r11
    shr   r11 , 4
    add   r12 , r11
    imul  r12 , [scroll_value_3_multiply]
    shr   r12 , 7
    test  r12 , 1111100000000b
    jnz   bluelimit
  bluelimitret:
    mov   dl  , r12b

    pop   r13 r12 r11

    ret


redlimit:
    test   rdx , 1000000000000b
    jnz    redlimit000
    mov    rdx , 255
    jmp    redlimitret
  redlimit000:
    xor    rdx , rdx
    jmp    redlimitret
greenlimit:
    test   r11 , 1000000000000b
    jnz    greenlimit000
    mov    r11 , 255
    jmp    greenlimitret
  greenlimit000:
    xor    r11 , r11
    jmp    greenlimitret
bluelimit:
    test   r12 , 1000000000000b
    jnz    bluelimit000
    mov    r12 , 255
    jmp    bluelimitret
  bluelimit000:
    xor    r12 , r12
    jmp    bluelimitret






form_picture:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Forms BMP picture to data10+
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    ; Header

    mov   rsi , bmpheader
    mov   rdi , data10
    mov   rcx , 54
    cld
    rep   movsb

    mov   rax , [sizex]
    mov   [data10+0x12],eax

    mov   rbx , [sizey]
    mov   [data10+0x16],ebx

    ; Picture data

    mov   rdi , data10+54
    mov   rsi , [sizex]
    imul  rsi , [sizey]
    imul  rsi , 4
    add   rsi , data6
    mov   rcx , 0
  newpicdata:

    sub   rsi , [sizex]
    sub   rsi , [sizex]
    sub   rsi , [sizex]
    sub   rsi , [sizex]

    push  rcx rsi
    mov   rcx , [sizex]
  datamovel1:
    mov   eax , [rsi]
    mov   [rdi],eax
    add   rsi , 4
    add   rdi , 3
    loop  datamovel1
    pop   rsi rcx

    inc   rcx
    cmp   rcx , [sizey]
    jb    newpicdata

    ret


save_snap:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Saves BMP snap
; 
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    push  qword [camera_state]

    mov   rax , 5
    mov   rbx , 10
    int   0x60

    call  turn_camera_off
    call  remove_decoders

    ; Saving BMP text

    mov   rbx , textsaving2
    call  display_text

    mov   rax , [resx]
    mov   [sizex],rax
    mov   rax , [resy]
    mov   [sizey],rax

    ; Form picture to data10+

    call  form_picture

    ; Snap count

    mov   rax , [snapcount]
    xor   rdx , rdx
    mov   rbx , 10
    div   rbx
    mov   [filesave+12],dl
    mov   [filesave+11],al
    add   [filesave+11],word '00'

    ; Delete file if persent

    mov   rax , 58
    mov   rbx , 2
    mov   r9  , filesave
    int   0x60

    ; Save file

    mov   rax , 58
    mov   rbx , 1
    mov   rcx , 0
    mov   rdx , [sizex]
    imul  rdx , [sizey]
    imul  rdx , 3
    add   rdx , 54
    mov   r8  , data10
    mov   r9  , filesave
    int   0x60

    ; Increase snap counter

    inc   dword [snapcount]

    ; Draw button

    call  draw_snap_button

    ; Draw image

    call  display_image_yuv

    pop   rax
    cmp   rax , 1
    jne   noturnbackon
    mov   rax , 5
    mov   rbx , 10
    int   0x60
    call  turn_camera_on
  noturnbackon:

    ret


display_text:

    mov   rax , 0x4    
    mov   rcx , 20
    mov   rdx , 54
    mov   rsi , 0xffffff
    mov   r9  , 0x1
    int   0x60

    ret



record_picture:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Records picture for AVI
; 
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    cmp   [record_state],byte 1
    jne   recl99

    push  rax rbx rcx rdx r8 r9 r10 r11 r12 r13 r14 r15 rsi rdi rbp

    ; 10 fps

    mov   rbx , textrec
    call  display_text

    mov   rax , 26
    mov   rbx , 1
    mov   rcx , fps_data
    mov   rdx , 1024
    int   0x60

    mov   rax , [record_next]
    cmp   rax , [fps_data+384]
    ja    recl2
  setrecn:
    add   rax , 100
    mov   [record_next],rax

    add   rax , 1000
    cmp   rax , [fps_data+384]
    ja    nolate
    mov   rax , [fps_data+384]
    jmp   setrecn
  nolate:

    ;
    ; Save avi
    ;

    mov   rax , [resx_resy_4]
    add   rax , 4*2
    imul  rax , 50
    add   rax , data10+(avi_end-avi_start)

    cmp   [record_position], rax
    jb    recfine
    mov   [record_state],byte 0

    call  display_image_yuv

    ; Saving text

    mov   rbx , textsaving
    call  display_text

    call  save_clip

    call  display_image_yuv

    jmp   recl2

  recfine:

    ;
    ; Record picture
    ;

    call  display_image_yuv

    mov   rax , [record_position]
    sub   rax , data10
    xor   rdx , rdx
    mov   rbx , [resx_resy_4]
    imul  rbx , 10
    div   rbx
    add   rax , 48+1
    mov   [textrec+5],al

    mov   rbx , textrec
    call  display_text

    mov   rdi  , [record_position]
    mov   [rdi], dword '00db'

    mov   rsi, [resx_resy_4]

    mov   [rdi+4], esi

    add   rdi , 8
    mov   rsi , data6
    add   rsi , [resx_resy_4]
    sub   rsi , [resx]
    sub   rsi , [resx]
    sub   rsi , [resx]
    sub   rsi , [resx]
  recl1:

    push  rsi rdi
    mov   rcx , [resx]
    shl   rcx , 2
    cld
    rep   movsb
    pop   rdi rsi

    add   rdi , [resx]
    add   rdi , [resx]
    add   rdi , [resx]
    add   rdi , [resx]

    sub   rsi , [resx]
    sub   rsi , [resx]
    sub   rsi , [resx]
    sub   rsi , [resx]

    cmp   rsi , data6
    jae   recl1

    mov   rsi , [resx_resy_4]
    add   rsi , 8
    add   [record_position],esi

  recl2:

    pop   rbp rdi rsi r15 r14 r13 r12 r11 r10 r9 r8 rdx rcx rbx rax

  recl99:

    ret


save_clip:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Saves AVI clip
; 
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    push  qword [camera_state]

    mov   rax , 5
    mov   rbx , 10
    int   0x60

    call  turn_camera_off
    call  remove_decoders

    ; Header

    mov   rsi , avi_start
    mov   rdi , data10
    mov   rcx , avi_end-avi_start
    cld
    rep   movsb

    ; idx1

    mov   rsi , idx1_start
    mov   rdi , data10 + (avi_end-avi_start) + ((4*2+320*240*4)*50)
    mov   rcx , idx1_end-idx1_start
    cld
    rep   movsb

    ; Filecount

    mov   rax , [clipcount]
    xor   rdx , rdx
    mov   rbx , 10
    div   rbx
    mov   [filesaveavi+12],dl
    mov   [filesaveavi+11],al
    add   [filesaveavi+11],word '00'

    ; Delete file if persent

    mov   rax , 58
    mov   rbx , 2
    mov   r9  , filesaveavi
    int   0x60

    ; Save file

    mov   rax , 58
    mov   rbx , 1
    mov   rcx , 0
    mov   rdx , (avi_end-avi_start)+(4*2+320*240*4)*50+(idx1_end-idx1_start)
    mov   r8  , data10
    mov   r9  , filesaveavi
    int   0x60

    ; Increase snap counter

    inc   dword [clipcount]

    ; Draw button

    call  draw_clip_button

    pop   rax
    cmp   rax , 1
    jne   noturnbackonavi
    mov   rax , 5
    mov   rbx , 10
    int   0x60
    call  turn_camera_on
  noturnbackonavi:

    ret



draw_window:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Draws window
; 
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    cmp   [pid],dword 0
    jne   nowindow

    mov   rax , 0xC     ; Beginning of window draw
    mov   rbx , 0x1
    int   0x60

    ; Draw window

    mov   rax , 0x0                         
    mov   rbx , 162 shl 32 + 480      ;150
    mov   rcx , 098 shl 32 + 310      ;80
    mov   rdx , 0x0000000000FFFFFF            
    mov   r8  , 0x0000000000000001          
    mov   r9  , window_label                
    mov   r10 , menu_struct                 
    int   0x60

    ; Start camera button

    mov   rax , 8
    mov   rbx , [xpos]
    shl   rbx , 32
    add   rbx , 116 
    mov   rcx , (247) shl 32 + 21
    mov   rdx , 101
    mov   r8  , 0
    mov   r9  , string_start_camera
    int   0x60

    ; Stop camera button

    mov   rax , 8
    mov   rbx , [xpos]
    shl   rbx , 32
    add   rbx , 116
    mov   rcx , (247+21) shl 32 + 21
    mov   rdx , 102
    mov   r8  , 0
    mov   r9  , string_stop_camera
    int   0x60

    ; Server button

    call  server_button

    ; Snap picture button

    call  draw_snap_button

    ; Clip button

    call  draw_clip_button

    ; Resolution buttons

    call  resolution_buttons

    ; Display image

    call  display_image_yuv

    ; Display text

    mov   rax , 0x4                      
    mov   rbx , text
    mov   rcx , [xpos]
    add   rcx , 4+scx-6
    mov   rdx , 132+scl+sct
    mov   rsi , 0x0
    mov   r9  , 0x1
  newline:
    int   0x60
    add   rbx , 0x1F
    add   rdx , 13-2
    cmp   [rbx],byte 'x'
    jne   newline

    ; Scrolls

    call  draw_scroll_1
    call  draw_scroll_2
    call  draw_scroll_3
    call  draw_scroll_values

    ; Camera status

    mov   [camera_connection_status],dword 2
    call  check_camera_state

    ; FPS

    call  display_frames_per_second

    mov   rax , 0xC                      
    mov   rbx , 0x2
    int   0x60

  nowindow:

    ret


server_button:

    ; Server button

    mov   rax , 8
    mov   rbx , [xpos]
    shl   rbx , 32
    add   rbx , 116
    mov   rcx , serverb
    mov   rdx , 105
    mov   r8  , 0
    mov   r9  , string_server_off
    cmp   [serveronoff],byte 3
    je    serverl1
    mov   r9  , string_server_on
  serverl1:
    int   0x60

    ret


resolution_buttons:

    ; Resolution buttons

    mov   rax , 8
    mov   rbx , [xpos]
    shl   rbx , 32
    add   rbx , 116/3+1
    mov   rcx , rby
    mov   rdx , 121
    mov   r8  , 0
    mov   r9  , string_res_160
    int   0x60

    mov   rax , 8
    mov   rbx , [xpos]
    add   rbx , 116/3+1
    shl   rbx , 32
    add   rbx , 116/3
    mov   rcx , rby
    mov   rdx , 122
    mov   r8  , 0
    mov   r9  , string_res_320
    int   0x60

    mov   rax , 8
    mov   rbx , [xpos]
    add   rbx , 116/3*2+1
    shl   rbx , 32
    add   rbx , 116/3+1
    mov   rcx , rby
    mov   rdx , 123
    mov   r8  , 0
    mov   r9  , string_res_640
    int   0x60

    ; Streamtype

    mov   rax , 8
    mov   rbx , [xpos]
    shl   rbx , 32
    add   rbx , 116
    mov   rcx , sby
    mov   rdx , 125
    mov   r8  , 0
    mov   r9  , string_stream_yuv422
    cmp   [streamtype],byte 3
    jne   nostr3
    mov   r9  , string_stream_mjpeg
  nostr3:
    int   0x60

    ret


draw_snap_button:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Draws snap button
; 
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    ; Snap count

    mov   rax , [snapcount]
    xor   rdx , rdx
    mov   rbx , 10
    div   rbx
    mov   [string_snap_save+12],dl
    mov   [string_snap_save+11],al
    add   [string_snap_save+11],word '00'

    ; Save snap button

    mov   rax , 8
    mov   rbx , [xpos]
    shl   rbx , 32
    add   rbx , 116
    mov   rcx , snapb
    mov   rdx , 103
    mov   r8  , 0
    mov   r9  , string_snap_save
    int   0x60

    ret


draw_clip_button:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Draws video clip button
; 
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    ; Clip count

    mov   rax , [clipcount]
    xor   rdx , rdx
    mov   rbx , 10
    div   rbx
    mov   [string_clip_save+12],dl
    mov   [string_clip_save+11],al
    add   [string_clip_save+11],word '00'

    ; Save clip button

    mov   rax , 8
    mov   rbx , [xpos]
    shl   rbx , 32
    add   rbx , 116
    mov   rcx , clipb
    mov   rdx , 104
    mov   r8  , 0
    mov   r9  , string_clip_save
    int   0x60

    ret


draw_scroll_values:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Draws scroll RGB values
; 
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    mov   rbx , [scroll_value_1]
    sub   rbx , 10000
    mov   rcx , 200
    sub   rcx , rbx
    call  get_multiplier
    mov   [scroll_value_1_multiply], r8
    mov   rdx , [xpos]
    add   rdx , 4+scx
    shl   rdx , 32
    add   rdx , 140-14+6+scl+sct
    call  display_number

    mov   rbx , [scroll_value_2]
    sub   rbx , 20000
    mov   rcx , 200
    sub   rcx , rbx
    call  get_multiplier
    mov   [scroll_value_2_multiply], r8
    mov   rdx , [xpos]
    add   rdx , 4+7*6+scx
    shl   rdx , 32
    add   rdx , 140-14+6+scl+sct
    call  display_number

    mov   rbx , [scroll_value_3]
    sub   rbx , 30000
    mov   rcx , 200
    sub   rcx , rbx
    call  get_multiplier
    mov   [scroll_value_3_multiply], r8
    mov   rdx , [xpos]
    add   rdx , 4+14*6+scx
    shl   rdx , 32
    add   rdx , 140-14+6+scl+sct
    call  display_number

    ret


get_multiplier:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Multiplier for colour values
; 
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    push  rax rbx rcx rdx

    shl   rcx , 7
    mov   rax , rcx
    xor   rdx , rdx
    mov   rbx , 100
    div   rbx
    mov   r8  , rax

    pop   rdx rcx rbx rax

    ret


draw_scroll_1:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Scroll 1
; 
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    mov   rax , 113
    mov   rbx , 1
    mov   rcx , 10000
    mov   rdx , 201
    mov   r8  , [scroll_value_1]
    mov   r9  , [xpos]
    add   r9  , 7+scx
    mov   r10 , 50+scy
    mov   r11 , 80-12+6+scl+1
    int   0x60

    ret


draw_scroll_2:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Scroll 2
; 
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    mov   rax , 113
    mov   rbx , 1
    mov   rcx , 20000
    mov   rdx , 201
    mov   r8  ,[scroll_value_2]
    mov   r9  , [xpos]
    add   r9  , 7+7*6+scx
    mov   r10 , 50+scy
    mov   r11 , 80-12+6+scl+1
    int   0x60

    ret


draw_scroll_3:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Scroll 3
; 
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    mov   rax , 113
    mov   rbx , 1
    mov   rcx , 30000
    mov   rdx , 201
    mov   r8  ,[scroll_value_3]
    mov   r9  , [xpos]
    add   r9  , 7+14*6+scx
    mov   r10 , 50+scy
    mov   r11 , 80-12+6+scl+1
    int   0x60

    ret


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Data area
; 
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

scroll_value_1: dq 10100
scroll_value_2: dq 20100
scroll_value_3: dq 30100

scroll_value_1_multiply: dq 10100
scroll_value_2_multiply: dq 20100
scroll_value_3_multiply: dq 30100

prevpicturetoggle: dq 0x0
picturetoggle:     dq 0x0

imagestart:  dq data1
savepicture: dq 0x0

nextpic:    dq  0x0
framerate:  dq  0x0

pid:      dq 0x0
piderror: dq 0x0

eolistd:  dq 0x0
eolistl:  dq 0x0
prevtsc:  dq 0x0
sizeonly: dq 0x0

text:

    db    ' xxx%   xxx%   xxx%           ',0
    db    ' Red   Green   Blue           ',0
    db    'x'

string_res_160: db '160',0
string_res_320: db '320',0
string_res_640: db '640',0

string_stream_yuv422: db 'WEBCAM: YUV422',0
string_stream_mjpeg:  db 'WEBCAM: MJPEG ',0

string_pid:   db 'PID:                 '

picsend:      dq 0x0
show_fps:     dq 0x0
fastercount:  dq 0x0

string_start_camera:  db  'START',0
string_stop_camera:   db  'STOP',0
string_snap_save:     db  '/USB/1/SNAPXX.BMP',0
string_clip_save:     db  '/USB/1/CLIPXX.AVI',0

string_server_off:     db  'SERVER: OFF',0
string_server_on:      db  'PORT 8090 OPEN',0
string_resolution_320: db  '320x240 required.',0
string_fps:            db  'Sent:       FPS:  /  ',0
string_screen_req:     db  '800x600 screen resolution required.',0

parameter: dq 250
           times 300 db 0

picview:     db  '\sysdir\picview',0
parampw:     dd  -1,0
picviewpid:  dq  0,0,0,0,0,0,0,0,0
streamtype:  dq  1
prevdatapos: dq  0x0
fmissed:     dq  0x0

decremove1:  dq  0
decremove2:  dq  0

string_camera_disconnected:

    db    'Camera disconnected.',0

read_wait: dq 0x0

pdata82:   dq   data8
pdata92:   dq   data9

scanstart:  dq  0x0
threadpos:  dq  0x0
fps_n:      dq  0x0

ipcmem:     dq  0,16,0,0

threadposprev:      dq 0x0
frames_per_second:  dq 0x0

fpsx:        dq  0x0
record_next: dq  0x0

camera_connection_status:  dq  0x2
frames_per_second_missed:  dq  0x0

xr: dq 160,320,640
yr: dq 120,240,480
xp: dq 346,346,666
cb: dq 001b,010b,100b

serveronoff: dq 3 ; 1=on-2=closing-3=closed

server_socket: dq 0x0

resx: dq 320
resy: dq 240
xpos: dq 346

resx_resy_2: dq 320*240*2
resx_resy_3: dq 320*240*3
resx_resy_4: dq 320*240*4

sconf: dq 0x0
sizex: dq 0x0  
sizey: dq 0x0 

filesaveavi:  db  '/usb/1/clipxx.avi',0
record_state: dq  0x0
clipcount:    dq  0x0
filesave:     db  '/usb/1/snapxx.bmp',0
snapcount:    dq  0x0

textrec:      db 'REC (1/5s)',0
textsaving:   db 'Saving AVI-file, which might take a minute...',0
textsaving2:  db 'Saving BMP-file...',0

record_position: dq data10 + 1208

red:    dq 0x0
green:  dq 0x0
blue:   dq 0x0

framebegin:    dq 0x0

framestart:      dq  0x0
framenumber:     dq  0x0
timedifference:  dq  0x0
headerstart:     dq  0x0
next_update:     dq  0x0
thread_running:  dq  0x0
read_position:   dq  0x0

pre_read_block:          dq  0x1
analyze_block:           dq  0x0
analyze_block_position:  dq  0x0

readon:        dq 0x1
camera_state:  dq 0x0

tsc_base: dq  0x0
fps_next: dq  0x0
fps_add:  dq  34 ; 30fps
tsc_next: dq  0x0

color:      dq   0x0
ypos:       dq   0x0
maxcount:   dq   0x0
framec:     dq   0x0
datapos:    dq   0x0 
savecount:  dq   0x0

framecount:       dq  0x0
currentframe:     dq  0x0
bytesperframe:    dq  0x0
jpgheaders:       dq  0x0
jpgheadersmem:    dq  0x0
bytesperframejpg: dq  0x0
bytespersecond:   dq  0x0
framesinsample:   dq  0x0

data_amount:       dq  0x0
data_valid:        dq  0x0
data_pre:          dq  0x0
data_unavailable:  dq  0x0
datasent:          dq  0x0
decoder_size:      dq  0x0

window_label:

    db    'WEBCAM',0       ; Window label

menu_struct:                  ; Menu Struct

       dq   0                 ; Version

       dq   0x100             ; Start value of ID to return ( ID + Line )
                              ; Returned when menu closes and
                              ; user made no selections.

       db   0,'SETUP',0              

sta1:  db   1,'> Stats Off ',0
sta2:  db   1,'  Stats On  ',0

       db   1,'-',0

eo:    db   1,'> Normal        ',0
eb:    db   1,'  Blur (yuv)    ',0
en:    db   1,'  Negative (yuv)',0

       db   1,'-',0

       db   1,'Quit',0        

       db   255               ; End of Menu Struct


html_header_index:

     db  'HTTP/1.1 200 OK',13,10
     db  'Server: Menuet',13,10
     db  'Connection: close',13,10
     db  'Content-Length: 47',13,10
     db  'Content-Type: text/html',13,10
     db  13,10
     db  '<html><body><img src=image.bmp></body></html>',13,10

h_i_len:



html_header:

     db  'HTTP/1.1 200 OK',13,10
     db  'Server: Menuet',13,10
     db  'Connection: close',13,10
     db  'Content-Length: '
hsz: db  '00230454'
     db  13,10
     db  'Content-Type: image/bmp',13,10,13,10

h_len:


bmpheader:

    db    66   
    db    77
    db    54
    db    12
    db    0
    db    0
    db    0
    db    0
    db    0
    db    0    
    db    54
    db    0
    db    0
    db    0
    db    40
    db    0
    db    0
    db    0
    db    32 ; x
    db    0    
    db    0        
    db    0
    db    32 ; y
    db    0
    db    0
    db    0
    db    1
    db    0
    db    24
    db    0     
    db    0         
    db    0
    db    0
    db    0
    db    0
    db    12
    db    0
    db    0
    db    0
    db    0    
    db    0
    db    0
    db    0
    db    0
    db    0
    db    0
    db    0
    db    0
    db    0
    db    0    
    db    0
    db    0
    db    0
    db    0    

numframes equ 50

avi_start:

    db    'RIFF'
    dd    15361432-8

    db    'AVI '

    db    'LIST'
    dd    l4_end-l4
    l4:
    db    'hdrl'
    dd    'avih'
    dd    0x38     
    dd    100000    ; microseconds between frames
    dd    0x320000  ; maxbytespersec
    dd    0x200     ; paddinggranularity
    dd    0x810     ; flags
    dd    numframes ; total frames
    dd    0x00      ; zero for non-interleaved
    dd    0x01      ; number of streams
    dd    330*240*4 ; suggested buffer size
    dd    320       ; image size x
    dd    240       ; image size y
    dd    0,0,0,0

    db    'LIST'
    dd    l6_end-l6
    l6:
    db    'strl'
    db    'strh'
    dd    0x38
    db    'vids'
    db    'DIB '     ; handler
    dd    0x0        ; flags
    dd    0x0        ; priority and language
    dd    0x0        ; initial frames
    dd    01000000   ; scale 
    dd    10000000   ; rate  
    dd    0x0        ; start
    dd    numframes  ; number of frames
    dd    320*240*4  ; 0x4b008  ; suggested buffer size
    dd    0x0        ; quality
    dd    4          ; sample size
    dd    0x0        ; rect struct
    dd    0x0

    db    'strf' 
    dd    0x28      ; length
    dd    0x28      ; length II
    dd    320       ; width
    dd    240       ; height
    dd    0x200001  ; planes and bitcount
    dd    0x0       ; compression
    dd    320*240*4 ; image size
    dd    0x0       ; xpelspermeter
    dd    0x0       ; ypelspermeter
    dd    0x0       ; clrused
    dd    0x0       ; clrimportant

    l4_end:
    l6_end:

    db    'LIST'
    dd    4+(2*4+320*240*4)*50
    l5:
    db    'movi'

avi_end:

idx1_start:

    db    'idx1'
    dd    indx12-indx11
  indx11:
    db    '00db'
    dd    16
    dd    0x4+(320*240*4+8)*0
    dd    320*240*4
    db    '00db'
    dd    16
    dd    0x4+(320*240*4+8)*1
    dd    320*240*4
    db    '00db'
    dd    16
    dd    0x4+(320*240*4+8)*2
    dd    320*240*4
    db    '00db'
    dd    16
    dd    0x4+(320*240*4+8)*3
    dd    320*240*4
    db    '00db'
    dd    16
    dd    0x4+(320*240*4+8)*4
    dd    320*240*4
    db    '00db'
    dd    16
    dd    0x4+(320*240*4+8)*5
    dd    320*240*4
    db    '00db'
    dd    16
    dd    0x4+(320*240*4+8)*6
    dd    320*240*4
    db    '00db'
    dd    16
    dd    0x4+(320*240*4+8)*7
    dd    320*240*4
    db    '00db'
    dd    16
    dd    0x4+(320*240*4+8)*8
    dd    320*240*4
    db    '00db'
    dd    16
    dd    0x4+(320*240*4+8)*9
    dd    320*240*4

    db    '00db'
    dd    16
    dd    0x4+(320*240*4+8)*10
    dd    320*240*4
    db    '00db'
    dd    16
    dd    0x4+(320*240*4+8)*11
    dd    320*240*4
    db    '00db'
    dd    16
    dd    0x4+(320*240*4+8)*12
    dd    320*240*4
    db    '00db'
    dd    16
    dd    0x4+(320*240*4+8)*13
    dd    320*240*4
    db    '00db'
    dd    16
    dd    0x4+(320*240*4+8)*14
    dd    320*240*4
    db    '00db'
    dd    16
    dd    0x4+(320*240*4+8)*15
    dd    320*240*4
    db    '00db'
    dd    16
    dd    0x4+(320*240*4+8)*16
    dd    320*240*4
    db    '00db'
    dd    16
    dd    0x4+(320*240*4+8)*17
    dd    320*240*4
    db    '00db'
    dd    16
    dd    0x4+(320*240*4+8)*18
    dd    320*240*4
    db    '00db'
    dd    16
    dd    0x4+(320*240*4+8)*19
    dd    320*240*4

    db    '00db'
    dd    16
    dd    0x4+(320*240*4+8)*20
    dd    320*240*4
    db    '00db'
    dd    16
    dd    0x4+(320*240*4+8)*21
    dd    320*240*4
    db    '00db'
    dd    16
    dd    0x4+(320*240*4+8)*22
    dd    320*240*4
    db    '00db'
    dd    16
    dd    0x4+(320*240*4+8)*23
    dd    320*240*4
    db    '00db'
    dd    16
    dd    0x4+(320*240*4+8)*24
    dd    320*240*4
    db    '00db'
    dd    16
    dd    0x4+(320*240*4+8)*25
    dd    320*240*4
    db    '00db'
    dd    16
    dd    0x4+(320*240*4+8)*26
    dd    320*240*4
    db    '00db'
    dd    16
    dd    0x4+(320*240*4+8)*27
    dd    320*240*4
    db    '00db'
    dd    16
    dd    0x4+(320*240*4+8)*28
    dd    320*240*4
    db    '00db'
    dd    16
    dd    0x4+(320*240*4+8)*29
    dd    320*240*4

    db    '00db'
    dd    16
    dd    0x4+(320*240*4+8)*30
    dd    320*240*4
    db    '00db'
    dd    16
    dd    0x4+(320*240*4+8)*31
    dd    320*240*4
    db    '00db'
    dd    16
    dd    0x4+(320*240*4+8)*32
    dd    320*240*4
    db    '00db'
    dd    16
    dd    0x4+(320*240*4+8)*33
    dd    320*240*4
    db    '00db'
    dd    16
    dd    0x4+(320*240*4+8)*34
    dd    320*240*4
    db    '00db'
    dd    16
    dd    0x4+(320*240*4+8)*35
    dd    320*240*4
    db    '00db'
    dd    16
    dd    0x4+(320*240*4+8)*36
    dd    320*240*4
    db    '00db'
    dd    16
    dd    0x4+(320*240*4+8)*37
    dd    320*240*4
    db    '00db'
    dd    16
    dd    0x4+(320*240*4+8)*38
    dd    320*240*4
    db    '00db'
    dd    16
    dd    0x4+(320*240*4+8)*39
    dd    320*240*4

    db    '00db'
    dd    16
    dd    0x4+(320*240*4+8)*40
    dd    320*240*4
    db    '00db'
    dd    16
    dd    0x4+(320*240*4+8)*41
    dd    320*240*4
    db    '00db'
    dd    16
    dd    0x4+(320*240*4+8)*42
    dd    320*240*4
    db    '00db'
    dd    16
    dd    0x4+(320*240*4+8)*43
    dd    320*240*4
    db    '00db'
    dd    16
    dd    0x4+(320*240*4+8)*44
    dd    320*240*4
    db    '00db'
    dd    16
    dd    0x4+(320*240*4+8)*45
    dd    320*240*4
    db    '00db'
    dd    16
    dd    0x4+(320*240*4+8)*46
    dd    320*240*4
    db    '00db'
    dd    16
    dd    0x4+(320*240*4+8)*47
    dd    320*240*4
    db    '00db'
    dd    16
    dd    0x4+(320*240*4+8)*48
    dd    320*240*4
    db    '00db'
    dd    16
    dd    0x4+(320*240*4+8)*49
    dd    320*240*4

  indx12:

idx1_end:

decoder_image:  times (65536*2) db ?

data_boot_info: times 8*30 db ?


fps_data:        

    times 2048 db ?

    ;

    times 1024 db ? ; Stack server

server_stack:

    times 1024 db ? ; Stack read

thread_stack:

    times 1024 db ? ; Stack main

image_end:









