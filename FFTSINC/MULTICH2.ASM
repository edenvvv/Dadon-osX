
; THIS FILE IS PART OF THE 'FFT CONVOLUTION KERNEL' LIBRARY SOURCE CODE
; COPYRIGHT (C) 2010 Akos Mogyorosi <flowwolf>
; FOR DETAILS SEE THE FILE README

; MULTI-CHANNEL INTERFACE

;fftcv_init_mch
;fftcv_deinit_mch
;fftcv_process_mch
;fftcv_set_coeffs_mch
;fftcv_flush_mch
;fftcv_set_state_mch


;------------------------------------------------------------------------------------
;FFT CONVOLUTION INIT MULTI-CHANNEL
;IN:   rcx - *fmchiface [out]                                                 uses: -
;      rdx -  max length
;      r8  -  in sc format << 32  +  out sc format
;
;OUT:  rax -  fftcv_lasterror
;
;NOTE: every successful call to fftcv_init_mch involves a call to fftcv_deinit_mch

fftcv_init_mch:
                      push   r11, r10, r9, rdx, rcx

                      xchg   rcx , r9                      ;r9  - *fmchiface

                      mov    rax , r8                      ;check sc formats
                      shr    rax , 32+8
                      and    rax , 255
                      mov    ecx , r8d
                      shr    ecx , 8
                      and    ecx , 255
                      cmp    ecx , eax
                      mov    rax , FFTCV_ERR_INVALID_FORMAT
                      jnz    .err
                      jecxz  .err
                      cmp    ecx , 48
                      ja     .err

                      ;xor    eax , eax  ;all x64 support SSE2
                      ;inc    eax
                      ;push   rbx
                      ;cpuid
                      ;pop    rbx
                      ;bt     edx , 26
                      ;mov    rax , FFTCV_ERR_SSE2_NOT_SUPPORTED
                      ;jnc    .err
                      mov    ecx , fmch_infoblocksize + 16
                      call   memallocz
                      test   rax , rax
                      jnz    .sk10
             .errm:   mov    rax , FFTCV_ERR_NOT_ENOUGH_MEMORY
              .err:
                      pop    rcx, rdx, r9, r10, r11
                      ret
             .sk10:
                      mov    rcx , rax
                      test   al  , 15
                      jz     .sk12
                      and    al  , 15 xor -1
                      add    rax , 16
             .sk12:   mov    [rax + fmch_infoblock], rcx
                      mov    [rax + fmch_maxlength], rdx
                      mov    [rax + fmch_format], r8

                      mov    [r9], rax

                      ;push   rax rbx
                      ;mov    rbx , [general_info_base]
                      ;imul   rbx , process_info_step
                      ;mov    rbx , [process_info_base+rbx+256]
                      ;sub    rax , rbx
                      ;mov    [r9], rax
                      ;pop    rbx rax

                      xchg   rax , r10                     ;r10 -  fmchiface

                      mov    eax , FFTCV_CONVBUFFSIZE+2    ;allocate buffer
                      cmp    eax , edx
                      cmovb  eax , edx
                      sub    eax , 2
                      bsr    ecx , eax
                      inc    ecx
                      xor    eax , eax
                      inc    eax
                      shl    eax , cl
                      add    eax , eax
                      mov    [r10 + fmch_bufflength], rax
                      mov    rcx , r8
                      shr    rcx , 32+8
                      and    rcx , 255
                      imul   rcx , rax
                      shl    rcx , 2
                      call   memalloc
                      test   rax , rax
                      jnz    .sk14
                      mov    rcx , [r10 + fmch_infoblock]
                      call   memfree
                      jmp    .errm
             .sk14:   mov    rcx , rax
                      test   al  , 15
                      jz     .sk16
                      and    al  , 15 xor -1
                      add    rax , 16
             .sk16:   mov    [r10 + fmch_buff], rax
                      mov    [r10 + fmch_buff + 8], rcx

                      lea    rcx , [r10 + fmch_sciface]    ;init sc
                      mov    rdx , r8
                      shr    rdx , 32+8
                      and    rdx , 255
                      imul   rdx , FFTCV_CONVBUFFSIZE
                      mov    r9d , r8d
                      shr    r9  , 8
                      and    r9  , 255
                      imul   r9  , [r10 + fmch_bufflength]
                      xchg   r9  , r8
                      call   sc_init
                      xchg   r9  , r8
                      test   rax , rax
                      jz     .sk20
                      xchg   rax , rdx
                      mov    rcx , [r10 + fmch_infoblock]
                      call   memfree
                      xchg   rax , rdx
                      jmp    .err
             .sk20:
                      xor    r9  , r9                      ;init fftcv
             .lp22:   lea    rcx , [r10 + fmch_fftcvifaces + r9*8]
                      mov    rdx , [r10 + fmch_maxlength]
                      call   fftcv_init
                      test   rax , rax
                      jz     .sk22
                      xchg   rax , rdx
                      mov    rcx , [r10 + fmch_sciface]
                      call   sc_deinit
                      mov    rcx , [r10 + fmch_infoblock]
                      call   memfree
                      xchg   rax , rdx
                      jmp    .err
             .sk22:   inc    r9
                      mov    rax , r8
                      shr    rax , 32+8
                      and    rax , 255
                      cmp    rax , r9
                      jnz    .lp22

                      xor    eax , eax
                      pop    rcx, rdx, r9, r10, r11
                      ret
;------------------------------------------------------------------------------------




;------------------------------------------------------------------------------------
;FFT CONVOLUTION DEINIT MULTI-CHANNEL
;IN:   rcx -  fmchiface                                                       uses: -
;
;OUT:  rax -  FFTCV_ERR_OK

fftcv_deinit_mch:
                      push   r10, r9, rcx

                      xchg   rcx , r10                     ;r10 -  fmchiface

                      mov    rcx , [r10 + fmch_sciface]    ;deinit sc
                      call   sc_deinit

                      xor    r9  , r9                      ;deinit fftcv
             .lp10:   mov    rcx , [r10 + fmch_fftcvifaces + r9*8]
                      call   fftcv_deinit
                      inc    r9
                      mov    rax , [r10 + fmch_format]
                      shr    rax , 32+8
                      and    rax , 255
                      cmp    rax , r9
                      jnz    .lp10

                      mov    rcx , [r10 + fmch_buff + 8]
                      call   memfree
                      mov    rcx , [r10 + fmch_infoblock]
                      call   memfree

                      xor    eax , eax
                      pop    rcx, r9, r10
                      ret
;------------------------------------------------------------------------------------




;------------------------------------------------------------------------------------
;FFT CONVOLUTION PROCESS MULTI-CHANNEL
;IN:   rcx -  fmchiface                                                       uses: -
;      rdx - *in
;      r8  - *out
;      r9  -  number of samples  or -1/-2 for  trailing delay / delay length
;
;OUT:  rax -  number of samples processed

fftcv_process_mch:
                      push   r14, r13, r12, r11, r10, r9, r8, rdi, rsi, rbp, rbx, rdx, rcx

                      xchg   rcx , rbp                     ;rbp -  fmchiface
                      xchg   rdx , rsi                     ;rsi - *in
                      xchg   r8  , rdi                     ;rdi - *out
                      xchg   r9  , rbx                     ;rbx -  number of samples
                      xor    r14 , r14                     ;r14 -  number of samples processed

                      cmp    rbx , -2                      ;get trailing delay length
                      jnz    .lp10
                      mov    rcx , [rbp + fmch_fftcvifaces + 0]
                      xor    edx , edx
                      xor    r8  , r8
                      mov    r9  , -2
                      mov    r10 , (FFTCV_FORMAT_FLOAT32_M shl 32)  +  FFTCV_FORMAT_FLOAT32_M
                      call   fftcv_process
                      jmp    .end

             .lp10:
                      mov    eax , FFTCV_CONVBUFFSIZE       ;r13 -  actual number of samples
                      mov    r13 , rbx
                      cmp    r13 , -1
                      jz     .sk12
                      cmp    r13 , rax
                      cmova  r13 , rax
                      sub    rbx , r13

                      mov    rcx , [rbp + fmch_sciface]    ;convert to internal
                      mov    rdx , rsi
                      xor    r8  , r8
                      mov    r9  , r13
                      mov    r10 , [rbp + fmch_format]
                      shr    r10 , 32
                      call   sc_to_internal
                      add    rsi , rax
             .sk12:
                      xor    r12 , r12                     ;1st pass
             .lp12:
                      cmp    r13 , -1
                      jz     .sk14

                      mov    rcx , [rbp + fmch_sciface]    ;reassign one channel at a time
                      xor    edx , edx
                      xor    r8  , r8
                      mov    r9  , r13
                      mov    r10 , 0xffffffff00000000
                      and    r10 , [rbp + fmch_format]
                      or     r10 , 1 shl 8
                      push   r12
                      mov    r11 , rsp
                      call   sc_reassign
                      add    rsp , 8
             .sk14:
                      mov    rcx , [rbp + fmch_sciface]    ;get "output" internal buffer
                      xor    edx , edx
                      push   0
                      mov    r8  , rsp
                      call   sc_get_buff
                      pop    rdx ; ?!?!?!?!?!?

                      mov    rcx , [rbp + fmch_fftcvifaces + r12*8]
                      mov    r8  , [rbp + fmch_bufflength]
                      imul   r8  , r12
                      shl    r8  , 2
                      add    r8  , [rbp + fmch_buff]
                      mov    r9  , r13
                      mov    r10 , (FFTCV_FORMAT_FLOAT32_M shl 32)  +  FFTCV_FORMAT_FLOAT32_M
                      call   fftcv_process

                      mov    rcx , [rbp + fmch_format]
                      shr    rcx , 32+8
                      and    rcx , 255
                      inc    r12
                      cmp    r12 , rcx
                      jnz    .lp12

                      xchg   rax , r9                      ;r9  -  number of samples processed


                      xor    r12 , r12                     ;2nd pass
             .lp14:
                      xor    ecx , ecx                     ;init aslist
             .lp16:   mov    D [rbp + fmch_aslist + rcx*8], -2
                      mov    [rbp + fmch_aslist + rcx*8 +4], ecx
                      mov    eax , [rbp + fmch_format]
                      shr    eax , 8
                      and    eax , 255
                      inc    ecx
                      cmp    ecx , eax
                      jnz    .lp16
                      mov    D [rbp + fmch_aslist + r12*8], 0

                      mov    rcx , [rbp + fmch_sciface]    ;reassign channels
                      mov    rdx , [rbp + fmch_bufflength]
                      imul   rdx , r12
                      shl    rdx , 2
                      add    rdx , [rbp + fmch_buff]
                      xor    r8  , r8
                      mov    rax , (1 shl 8) shl 32
                      mov    r10d, [rbp + fmch_format]
                      or     r10 , rax
                      lea    r11 , [rbp + fmch_aslist]
                      call   sc_reassign

                      mov    rcx , [rbp + fmch_format]
                      shr    rcx , 32+8
                      and    rcx , 255
                      inc    r12
                      cmp    r12 , rcx
                      jnz    .lp14


                      mov    rcx , [rbp + fmch_sciface]    ;change precision
                      xor    edx , edx
                      mov    r8  , [rbp + fmch_format]
                      xchg   r8  , r9
                      call   sc_ch_precision
                      xchg   r8  , r9

                      mov    rcx , [rbp + fmch_sciface]    ;convert from internal
                      xor    edx , edx
                      mov    r8  , rdi
                      mov    r10d, [rbp + fmch_format]
                      call   sc_from_internal
                      add    rdi , rax
                      add    r14 , r9                      ;update number of samples processed

                      test   rbx , rbx
                      jnle   .lp10

                      xchg   rax , r14
              .end:   pop    rcx, rdx, rbx, rbp, rsi, rdi, r8, r9, r10, r11, r12, r13, r14
                      ret
;------------------------------------------------------------------------------------




;------------------------------------------------------------------------------------
;FFT CONVOLUTION SET COEFFICIENTS MULTI-CHANNEL
;IN:   rcx -  fmchiface                                                       uses: -
;      rdx - *list of fftcvifaces
;
;OUT:  rax -  fftcv_lasterror

fftcv_set_coeffs_mch:
                      push   r10, r9, r8

                      xchg   rcx , r9                      ;r9  -  fmchiface
                      xchg   rdx , r10                     ;r10 - *list of fftcvifaces

                      xor    ecx , ecx                     ;check list
                      mov    rax , FFTCV_ERR_INVALID_OPERATION
                      mov    rdx , [r10]
                      test   rdx , rdx
                      jz     .err
                      mov    rdx , [rdx + fftcv_newn]
             .lp00:   mov    r8  , [r10 + rcx*8]
                      test   r8  , r8
                      jz     .err
                      cmp    rdx , [r8  + fftcv_newn]
                      jnz    .err
                      mov    r8  , [r9  + fmch_format]
                      shr    r8  , 32+8
                      and    r8  , 255
                      inc    rcx
                      cmp    rcx , r8
                      jnz    .lp00
             .sk00:
                      xor    r8  , r8
             .lp10:   mov    rcx , [r10 + r8*8]
                      mov    rdx , [r9  + fmch_fftcvifaces + r8*8]
                      call   fftcv_set_coeffs
                      test   rax , rax
                      jnz    .err
                      mov    rcx , [r9  + fmch_format]
                      shr    rcx , 32+8
                      and    rcx , 255
                      inc    r8
                      cmp    r8  , rcx
                      jnz    .lp10

                      xor    eax , eax
              .err:
                      xchg   rcx , r9
                      xchg   rdx , r10
                      pop    r8, r9, r10
                      ret
;------------------------------------------------------------------------------------




;------------------------------------------------------------------------------------
;FFT CONVOLUTION FLUSH BUFFERS MULTI-CHANNEL
;IN:   rcx -  fmchiface                                                       uses: -
;
;OUT:  rax -  FFTCV_ERR_OK

fftcv_flush_mch:
                      push   r9, r8, rcx

                      xchg   rcx , r9                      ;r9  -  fmchiface

                      xor    r8  , r8
             .lp10:   mov    rcx , [r9 + fmch_fftcvifaces + r8*8]
                      call   fftcv_flush
                      mov    rax , [r9 + fmch_format]
                      shr    rax , 32+8
                      and    rax , 255
                      inc    r8
                      cmp    r8  , rax
                      jnz    .lp10

                      xor    eax , eax
                      pop    rcx, r8, r9
                      ret
;------------------------------------------------------------------------------------




;------------------------------------------------------------------------------------
;FFT CONVOLUTION SET STATE MULTI-CHANNEL
;IN:   rcx -  fmchiface                                                       uses: -
;      rdx -  statemask << 32  +  state
;
;OUT:  rax -  FFTCV_ERR_OK

fftcv_set_state_mch:
                      push   r9, r8, rcx

                      xchg   rcx , r9                      ;r9  -  fmchiface

                      xor    r8  , r8
             .lp10:   mov    rcx , [r9 + fmch_fftcvifaces + r8*8]
                      call   fftcv_set_state
                      mov    rax , [r9 + fmch_format]
                      shr    rax , 32+8
                      and    rax , 255
                      inc    r8
                      cmp    r8  , rax
                      jnz    .lp10

                      xor    eax , eax
                      pop    rcx, r8, r9
                      ret
;------------------------------------------------------------------------------------














