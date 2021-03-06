;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Audio
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


use64

define B byte
define W word
define D dword
define Q qword


org 0x0

  db  "MENUET64"
  dq  0x01
  dq  _main
  dq  image_end             ;size of image
  dq  stacktop+0x100000*30  ;memory size
  dq  stacktop-16           ;*stack
  dq  0
  dq  0x0

  inwav  equ stacktop
  buffer equ (stacktop+0x400000)
  memm   equ (stacktop+0x800000)

  include "sinc.inc"      ;variable definitions
  include "sc.inc"        ;
  include "stream.inc"    ;
  include "wfc.inc"       ;


;------------------------------------------------------------------------------------
_main:
                      call   draw_window
;------------------------------------------------------------------------------------
still:
                      mov    eax , 10
                      int    0x60

                      test   al  ,1                        ;event handler
                      jnz    event_win
                      test   al  ,2
                      jnz    event_key
                      test   al  ,4
                      jnz    event_button

                      jmp    still
;------------------------------------------------------------------------------------
;WINDOW EVENT
event_win:
                      call   draw_window
                      jmp    still
;------------------------------------------------------------------------------------


;------------------------------------------------------------------------------------
;KEY EVENT
event_key:
                      mov    eax , 2                       ;get key
                      int    0x60
                      jmp    still
;------------------------------------------------------------------------------------


;------------------------------------------------------------------------------------
;BUTTON EVENT
event_button:
                      mov    eax , 17
                      int    0x60
                      test   rax , rax
                      jnz    .end

                      cmp    rbx,0x10000001
                      jnz    .noex
                      mov    eax,512
                      int    0x60
             .noex:
                      cmp    rbx , 100
                      jnz    .end

                      ;define work area
                      mov    rax , 150
                      mov    rbx , 1
                      mov    rcx , memm
                      mov    rdx , 0x100000*20
                      int    0x60

                      ;read file
                      mov    rax , 58
                      mov    rbx , 0
                      mov    rcx , 0
                      mov    rdx , 0x3F0000/512
                      mov    r8  , inwav
                      mov    r9  , inname
                      int    0x60
                      mov    [errcode],byte 0xff
                      cmp    rbx , 0x2c
                      jbe    .endw
                      mov    [errcode],byte 0x00
                      mov    rax , 0x3F0000
                      cmp    rbx , rax
                      cmova  rbx , rax
                      mov    [filesize],rbx

                      ;stream resampling interface follows:

                      mov    eax , 150          ;audio processing syscall
                      mov    ebx , 65           ;65  - Sinc resampling stream get info
                      mov    rcx , STREAM_TYPE_MEM
                      mov    rdx , inwav
                      mov    r8  , [filesize]
                      sub    r8  , 0x2c
                      lea    r9  , [wfcinfos]   ;wfcinfos structure, see "wave format converter"
                      int    0x60
                      test   rax , rax
                      mov    [errcode], rax
                      jnz    .endw

                      mov    eax , 150          ;audio processing syscall
                      mov    ebx , 66           ;66  - Sinc resampling stream process
                      mov    rcx , SINC_TABLE_HIGH_QUALITY shl 32  +  STREAM_TYPE_MEM
                      mov    rdx , inwav
                      mov    r8  , [filesize]
                      sub    r8  , 0x2c
                      mov    r10d, [wfcinfos + WFC_INFO_SCFORMAT] ;the input format must be obtained
                      mov    r9  , r10                            ;and pass it in the high dword
                      shl    r9  , 32                             ;
                      and    r10d, (255 shl 8)                    ;the output format is constructed by
                      or     r10d, SC_FORMAT_16B                  ;using the channel info of the input format
                      or     r9  , r10                            ;and pass it in the low dword
                      mov    r10d, [wfcinfos + WFC_INFO_RATE]     ;r10 - sample rate
                      shl    r10 , 32                             ;high dword - in rate
                      or     r10 , 48000                          ; low dword - out rate
                      lea    r11 , [output]
                      int    0x60
                      test   rax , rax
                      mov    [errcode], rax
                      jnz    .endw

                      lea    rdx , [buffer]                       ;you can calculate the number of bytes
                      sub    rdx , [output]                       ;processed after "stream process"
                      neg    rdx

                      mov    rax , 58                         ;write resampled file (no wav header)
                      mov    rbx , 1
                      mov    r8  , buffer
                      mov    r9  , outname
                      int    0x60

                      inc    D [success]
               .endw:
                      call   draw_window
               .end:
                      jmp    still
;------------------------------------------------------------------------------------








;------------------------------------------------------------------------------------
;DRAW WINDOW
draw_window:
                      mov    eax , 12
                      mov    ebx , 1
                      int    0x60

                      xor    ebx , ebx                     ;define window
                      shl    rbx , 32
                      or     rbx , 400
                      xor    ecx , ecx
                      shl    rcx , 32
                      or     rcx , 200
                      xor    edx , edx
                      mov    r8  , 1
                      lea    r9  , [windowlabel]
                      xor    r10 , r10
                      xor    eax , eax
                      int    0x60

                      mov    rax , 8                       ;draw button
                      mov    rbx , (40 shl 32) + 300
                      mov    rcx , (40 shl 32) + 40
                      mov    edx , 100
                      xor    r8  , r8
                      lea    r9  , [button]
                      int    0x60

                      cmp    D [success],0                 ;write text on success
                      jz     .sk
                      mov    eax , 4
                      mov    rbx , str1
                      mov    rcx , 40
                      mov    rdx , 80
                      mov    r9  , 1
                      mov    rsi , 0x00ff00ff
                      int    0x60
                .sk:
                      mov    eax , 47                      ;display error code
                      mov    ebx , 0x00100100
                      mov    rcx , [errcode]
                      mov    rdx , (40 shl 32) + 100
                      mov    rsi , 0x00ff00ff
                      int    0x60

                      mov    eax , 12
                      mov    ebx , 2
                      int    0x60
                      ret
;------------------------------------------------------------------------------------

align 16

output      dq buffer

windowlabel db "resample ex 2 (stream)",0
button      db "resample from 44khz to 48khz (out3.raw!)",0
str1        db "successful!",0

inname      db "/fd/1/in.wav",0
outname     db "/fd/1/out3.raw",0

image_end:

align 16

success:    dq ?
errcode:    dq ?
filesize:   dq ?
wfcinfos:   times WFC_INFOSIZE dd ?  ;32 bytes

times 4096 db ?
stacktop:





























