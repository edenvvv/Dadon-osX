
; THIS FILE IS PART OF THE 'FFT CONVOLUTION KERNEL' LIBRARY SOURCE CODE
; COPYRIGHT (C) 2010 Akos Mogyorosi <flowwolf>
; FOR DETAILS SEE THE FILE README

; STREAM CONVOLUTION INTERFACE

;fftcv_stream_process
;fftcv_stream_get_info


;------------------------------------------------------------------------------------
;FFT CONVOLUTION STREAM
;IN:   rcx -  max length << 32  +  stream type                                uses: -
;      rdx -  stream param 1
;      r8  -  stream param 2
;      r9  -  in sc format << 32  +  out sc format
;      r10 - *list of fftcvifaces
;      r11 - *output [out]
;
;OUT:  rax -  zero or a valid errorcode
;
;NOTE: this function should be called after obtaining wfcinfo returned by get_info

fftcv_stream_process:
                      push   r15, r14, r13, r12, r10, r9, rbp, rdx, rcx, rbx

                      xchg   rcx , r12                     ;r12 -  max length << 32  +  stream type
                      xchg   r9  , r13                     ;r13 -  in sc format << 32  +  out sc format
                      xchg   r10 , r14                     ;r14 - *list of fftcvifaces

                      xchg   rdx , rbx
                      mov    rcx , r12
                      shr    rcx , 32
                      mov    eax , FFTCV_CONVBUFFSIZE+2
                      cmp    eax , ecx
                      cmovb  eax , ecx
                      sub    eax , 2
                      bsr    ecx , eax
                      inc    ecx
                      xor    eax , eax
                      inc    eax
                      shl    eax , cl
                      add    eax , eax
                      xchg   eax , ecx
                      mov    eax , r13d
                      mov    edx , eax
                      and    edx , 15
                      shr    eax , 8
                      and    eax , 255
                      imul   eax , edx
                      imul   eax , ecx                     ;rax -  outbuffsize

                      mov    rcx , r13
                      shr    rcx , 32
                      mov    edx , ecx
                      shr    edx , 8
                      and    edx , 255
                      and    ecx , 15
                      imul   ecx , edx
                      imul   ecx , FFTCV_CONVBUFFSIZE      ;rcx -  inbuffsize
                      xchg   rdx , rbx
                      mov    rbx , rcx                     ;rbx -  inbuffsize

                      ;xor    eax , eax  ;all x64 support SSE2
                      ;inc    eax
                      ;push   rbx
                      ;cpuid
                      ;pop    rbx
                      ;bt     edx , 26
                      ;mov    rax , FFTCV_ERR_SSE2_NOT_SUPPORTED
                      ;jnc    .err
                      lea    ecx , [ecx + eax + strc_infoblocksize + 16 + 16]
                      call   memallocz
                      test   rax , rax
                      jnz    .sk10
                      mov    rax , FFTCV_ERR_NOT_ENOUGH_MEMORY
              .err:
                      pop    rbx, rcx, rdx, rbp, r9, r10, r12, r13, r14, r15
                      ret
             .sk10:
                      mov    rcx , rax
                      test   al  , 15
                      jz     .sk12
                      and    al  , 15 xor -1
                      add    rax , 16
             .sk12:   mov    [rax + strc_infoblock], rcx
                      xchg   rax , rbp                     ;rbp -  strciface
                      fxsave [rbp + strc_fpummxssestate]

                      lea    r10 , [rbp + strc_wfcinfo]    ;wfc init
                      lea    r9  , [rbp + strc_wfciface]
                      mov    ecx , r12d
                      call   wfc_init
                      test   rax , rax
                      jz     .sk14
             .sk13:   xchg   rax , rdx
                      mov    rcx , [rbp + strc_infoblock]
                      call   memfree
                      xchg   rax , rdx
                      fxrstor [rbp + strc_fpummxssestate]
                      jmp    .err
             .sk14:
                      lea    rcx , [rbp + strc_fmchiface]  ;fftcv multi-ch init
                      mov    rdx , r12
                      shr    rdx , 32
                      mov    r8  , r13
                      call   fftcv_init_mch
                      test   rax , rax
                      jnz    .sk13

                      mov    rcx , [rbp + strc_fmchiface]  ;fftcv multi-ch set coeffs
                      mov    rdx , r14
                      call   fftcv_set_coeffs_mch
                      test   eax , eax
                      jz     .sk16
                      xchg   rax , rdx
                      mov    rcx , [rbp + strc_fmchiface]
                      call   fftcv_deinit
                      xchg   rax , rdx
                      jmp    .sk13
             .sk16:
                      mov    rcx , [rbp + strc_fmchiface]  ;fftcv multi-ch set state
                      mov    rdx , (FFTCV_ST_LEADING_DELAY shl 32)  +  FFTCV_ST_LEADING_DELAY
                      call   fftcv_set_state_mch

             .lp20:   mov    rcx , [rbp + strc_wfciface]   ;wfc read
                      lea    rdx , [rbp + strc_buff]
                      mov    r8d , FFTCV_CONVBUFFSIZE
                      call   wfc_read
                      xchg   rax , r9                      ;r9  -  number of samples read

                      mov    rcx , [rbp + strc_fmchiface]  ;fftcv multi-ch process
                      lea    rdx , [rbp + strc_buff]
                      lea    r8  , [rdx + rbx]
                      call   fftcv_process_mch

                      lea    rcx , [rdx + rbx]
                      mov    rdx , rax
                      mov    r8  , r13
                      shr    r8  , 8
                      and    r8  , 255
                      mov    rax , r13
                      and    rax , 15
                      imul   r8  , rax
                      imul   r8  , rdx
                      ;rcx - *resampled data
                      ;rdx -  number of samples resampled
                      ;r8  -  number of bytes resampled

                      push   rsi , rcx
                      mov    rsi , rcx
                      xchg   rdi , [r11 + 0]
                      mov    rcx , r8
                      shr    rcx , 3
                      rep movsq
                      mov    rcx , r8
                      and    rcx , 7
                      rep movsb
                      xchg   rdi , [r11 + 0]
                      pop    rcx , rsi

                      cmp    r9  , FFTCV_CONVBUFFSIZE
                      jz     .lp20

                      mov    rcx , [rbp + strc_fmchiface]  ;get trailing delay
                      lea    rdx , [rbp + strc_buff]
                      lea    r8  , [rbp + strc_buff + rbx]
                      xor    r9  , r9
                      dec    r9
                      call   fftcv_process_mch

                      lea    rcx , [rdx + rbx]
                      mov    rdx , rax
                      mov    r8  , r13
                      shr    r8  , 8
                      and    r8  , 255
                      mov    rax , r13
                      and    rax , 15
                      imul   r8  , rax
                      imul   r8  , rdx
                      ;rcx - *resampled data
                      ;rdx -  number of samples resampled
                      ;r8  -  number of bytes resampled

                      push   rsi , rcx
                      mov    rsi , rcx
                      xchg   rdi , [r11 + 0]
                      mov    rcx , r8
                      shr    rcx , 3
                      rep movsq
                      mov    rcx , r8
                      and    rcx , 7
                      rep movsb
                      xchg   rdi , [r11 + 0]
                      pop    rcx , rsi

                      mov    rcx , [rbp + strc_fmchiface]  ;fftcv multi-ch deinit
                      call   fftcv_deinit_mch

                      mov    rcx , [rbp + strc_wfciface]   ;wfc deinit
                      call   wfc_deinit

                      fxrstor [rbp + strc_fpummxssestate]

                      mov    rcx , [rbp + strc_infoblock]  ;free infoblock
                      call   memfree

                      xor    eax , eax
                      pop    rbx, rcx, rdx, rbp, r9, r10, r12, r13, r14, r15
                      ret
;------------------------------------------------------------------------------------




;------------------------------------------------------------------------------------
;FFT CONVOLUTION STREAM GET INFO
;IN:   rcx -  stream type                                                     uses: -
;      rdx -  stream param 1
;      r8  -  stream param 2
;      r9  -  wfcinfo [out]
;
;OUT:  rax -  zero or a valid errorcode

fftcv_stream_get_info:
                      push   r10, r9, r8, rdi, rdx, rcx

                      xchg   r9  , rdi

                      push   0
                      mov    r10 , rsp
                      push   0
                      mov    r9  , rsp
                      call   wfc_init
                      pop    rcx
                      pop    r8
                      test   rax , rax
                      jnz    .sk10

                      xor    edx , edx
             .lp10:   mov    eax , [r8 + rdx*4]
                      mov    [rdi + rdx*4], eax
                      inc    edx
                      cmp    edx , WFC_INFOSIZE/4
                      jnz    .lp10

                      call   wfc_deinit
             .sk10:
                      pop    rcx, rdx, rdi, r8, r9, r10
                      ret
;------------------------------------------------------------------------------------
