;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Audio processing - System call 150
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;use64

macro push [arg]    ;push - pop
{                   ;
 reverse push arg   ;
}                   ;
                    ;
macro pop [arg]     ;
{                   ;
 reverse pop arg    ;
}                   ;

define B byte
define W word
define D dword
define Q qword

align 16

  include "sinc.inc"
  include "stream.inc"
  include "fftcv.inc"
  include "sc.inc"
  include "wfc.inc"

  include "sincdata.asm"
  include "mem.asm"
  include "fft4.asm"
  include "srfft.asm"
  include "sc.asm"
  include "sinc.asm"
  include "stream.asm"
  include "sampconv.asm"
  include "window.asm"
  include "wfc.asm"
  include "fftcv.asm"
  include "multich1.asm"
  include "multich2.asm"
  include "stream1.asm"
  include "stream2.asm"
  include "fftcvd.asm"



system_audio_process:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   System call entry
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    push  rbx rcx rdx r8 r9 r10 r11 r12 r13 r14 r15 rsi rdi rbp

    cmp   rbx , 1
    jb    noscal1
    cmp   rbx , 80
    jae   noscal1

    mov   rax , syscall_audio_functions

    cmp   dword [rax+rbx*8],dword 0
    je    noscal1

    ;
    ; Execute audio function
    ;

    call  qword [rax+rbx*8]

    jmp   noscal2

  noscal1:

    mov   rax , -1

  noscal2:

    pop   rbp rdi rsi r15 r14 r13 r12 r11 r10 r9 r8 rdx rcx rbx

    ret

align 8

syscall_audio_functions:

    dq    0                     ;  00
    dq    audio_memory          ;  01
    dq    0                     ;
    dq    0                     ;
    dq    0                     ;
    dq    0                     ;
    dq    0                     ;
    dq    0                     ;
    dq    0                     ;
    dq    0                     ;
    dq    0                     ;
    dq    fft4_create           ;  11
    dq    fft4_destroy          ;  12
    dq    fft4                  ;  13
    dq    ifft4                 ;  14
    dq    0                     ;
    dq    srfft_dif             ;  16
    dq    isrfft_dif            ;  17
    dq    0                     ;
    dq    0                     ;
    dq    0                     ;
    dq    sc_init               ;  21
    dq    sc_deinit             ;  22
    dq    sc_to_internal        ;  23
    dq    sc_reassign           ;  24
    dq    sc_from_internal      ;  25
    dq    sc_ch_precision       ;  26
    dq    sc_get_buff           ;  27
    dq    0                     ;
    dq    0                     ;
    dq    0                     ;
    dq    fftcv_init            ;  31
    dq    fftcv_deinit          ;  32
    dq    fftcv_calc_coeffs     ;  33
    dq    fftcv_set_coeffs      ;  34
    dq    fftcv_use_coeffs      ;  35
    dq    fftcv_process         ;  36
    dq    fftcv_flush           ;  37
    dq    fftcv_set_state       ;  38
    dq    fftcv_use_complex_coeffs ;  39
    dq    0                     ;
    dq    fftcv_init_mch        ;  41
    dq    fftcv_deinit_mch      ;  42
    dq    fftcv_process_mch     ;  43
    dq    fftcv_set_coeffs_mch  ;  44
    dq    fftcv_flush_mch       ;  45
    dq    fftcv_set_state_mch   ;  46
    dq    fftcv_stream_get_info ;  47
    dq    fftcv_stream_process  ;  48
    dq    0                     ;
    dq    0                     ;
    dq    sinc_create           ;  51
    dq    sinc_destroy          ;  52
    dq    sinc_init             ;  53
    dq    sinc_deinit           ;  54
    dq    sinc_process          ;  55
    dq    sinc_flush            ;  56
    dq    0                     ;
    dq    0                     ;
    dq    0                     ;
    dq    0                     ;
    dq    sinc_init_mch         ;  61
    dq    sinc_deinit_mch       ;  62
    dq    sinc_process_mch      ;  63
    dq    sinc_flush_mch        ;  64
    dq    sinc_stream_get_info  ;  65
    dq    sinc_stream_process   ;  66
    dq    0                     ;
    dq    0                     ;
    dq    0                     ;
    dq    0                     ;
    dq    wfc_init              ;  71
    dq    wfc_deinit            ;  72
    dq    wfc_read              ;  73
    dq    0                     ;
    dq    0                     ;
    dq    0                     ;
    dq    0                     ;
    dq    0                     ;
    dq    0                     ;
    dq    0                     ;  80





