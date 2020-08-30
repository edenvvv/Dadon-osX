
; THIS FILE IS PART OF THE 'SINC RESAMPLING KERNEL' LIBRARY SOURCE CODE
; COPYRIGHT (C) 2008-2010 Akos Mogyorosi <flowwolf>
; FOR DETAILS SEE THE FILE README

; STREAM RESAMPLING INTERFACE

;sinc_stream_process
;sinc_stream_get_info


;------------------------------------------------------------------------------------
;SINC RESAMPLE STREAM
;IN:   rcx -  sinctable name << 32  +  stream type                            uses: -
;      rdx -  stream param 1
;      r8  -  stream param 2
;      r9  -  in sc format << 32  +  out sc format
;      r10 -  input rate << 32  +  output rate
;      r11 - *output [out]
;
;OUT:  rax -  zero or a valid errorcode
;
;NOTE: this function should be called after obtaining wfcinfo returned by get_info

sinc_stream_process:
                      push   r15, r14, r13, r12, r10, r9, rbp, rdx, rcx, rbx

                      xchg   rcx , r12                     ;r12 -  sinctable name << 32  +  stream type
                      xchg   r9  , r13                     ;r13 -  in sc format << 32  +  out sc format
                      xchg   r10 , r14                     ;r14 -  input rate << 32  +  output rate

                      ;xor    eax , eax  ;all x64 support SSE2
                      ;inc    eax
                      ;push   rbx
                      ;cpuid
                      ;pop    rbx
                      ;bt     edx , 26
                      ;mov    rax , SINC_ERR_SSE2_NOT_SUPPORTED
                      ;jnc    .err
                      mov    ecx , strr_infoblocksize + 16
                      call   memallocz
                      test   rax , rax
                      jnz    .sk10
                      mov    rax , SINC_ERR_NOT_ENOUGH_MEMORY
              .err:
                      pop    rbx, rcx, rdx, rbp, r9, r10, r12, r13, r14, r15
                      ret
             .sk10:
                      mov    rcx , rax
                      test   al  , 15
                      jz     .sk12
                      and    al  , 15 xor -1
                      add    rax , 16
             .sk12:   mov    [rax + strr_infoblock], rcx
                      xchg   rax , rbp                     ;rbp -  strriface
                      fxsave [rbp + strr_fpummxssestate]

                      lea    r10 , [rbp + strr_wfcinfo]    ;wfc init
                      lea    r9  , [rbp + strr_wfciface]
                      mov    ecx , r12d
                      call   wfc_init
                      test   rax , rax
                      jz     .sk14
             .sk13:   xchg   rax , rdx
                      mov    rcx , [rbp + strr_infoblock]
                      call   memfree
                      xchg   rax , rdx
                      fxrstor [rbp + strr_fpummxssestate]
                      jmp    .err
             .sk14:
                      mov    rcx , r12                     ;create sinc filter table
                      shr    rcx , 32
                      lea    rdx , [rbp + strr_sinctable]
                      xor    r8  , r8
                      call   sinc_create
                      test   rax , rax
                      jnz    .sk13

                      lea    rcx , [rbp + strr_smchiface]  ;sinc multi-ch init
                      mov    rdx , [rbp + strr_sinctable]
                      mov    r8  , r13
                      mov    rax , r14
                      cvtsi2sd xmm0 , eax
                      shr    rax , 32
                      cvtsi2sd xmm1 , eax
                      divsd  xmm0 , xmm1
                      movsd  xmm1 , xmm0
                      call   sinc_init_mch
                      test   rax , rax
                      jz     .sk16
             .sk15:   xchg   rax , rdx
                      mov    rcx , [rbp + strr_sinctable]
                      call   sinc_destroy
                      xchg   rax , rdx
                      jmp    .sk13
             .sk16:
                      mov    rcx , [rbp + strr_smchiface]  ;allocate buffer
                      mov    r9  , -2
                      mov    rax , r14
                      cvtsi2sd xmm0 , rax
                      shr    rax , 32
                      cvtsi2sd xmm1 , rax
                      call   sinc_process_mch
                      mov    ecx , SINC_CONVBUFFSIZE       ;compare with trailing delay length
                      cmp    ecx , eax
                      cmovb  ecx , eax
                      mov    eax , r13d
                      mov    edx , eax
                      and    edx , 15
                      shr    eax , 8
                      and    eax , 255
                      imul   eax , edx
                      imul   eax , ecx
                      imul   eax , r14d
                      mov    rcx , r14
                      shr    rcx , 32
                      cqo
                      div    rcx                           ;rax -  outbuffsize
                      mov    rcx , r13
                      shr    rcx , 32
                      mov    edx , ecx
                      shr    edx , 8
                      and    edx , 255
                      and    ecx , 15
                      imul   ecx , edx
                      imul   ecx , SINC_CONVBUFFSIZE       ;rcx -  inbuffsize
                      mov    rbx , rcx                     ;rbx -  inbuffsize
                      lea    rcx , [rcx + rax + 16 + 16]
                      call   memallocz
                      test   rax , rax
                      jnz    .sk18
                      mov    rax , SINC_ERR_NOT_ENOUGH_MEMORY
                      jmp    .sk15
             .sk18:   mov    rcx , rax
                      test   al  , 15
                      jz     .sk19
                      and    al  , 15 xor -1
                      add    rax , 16
             .sk19:   mov    [rbp + strr_buff], rax
                      mov    [rbp + strr_buff + 8], rcx


             .lp20:   mov    rcx , [rbp + strr_wfciface]   ;wfc read
                      mov    rdx , [rbp + strr_buff]
                      mov    r8d , SINC_CONVBUFFSIZE
                      call   wfc_read
                      xchg   rax , r9                      ;r9  -  number of samples read

                      mov    rcx , [rbp + strr_smchiface]  ;sinc multi-ch process
                      mov    rdx , [rbp + strr_buff]
                      lea    r8  , [rdx + rbx]
                      mov    rax , r14
                      cvtsi2sd xmm1 , eax
                      shr    rax , 32
                      cvtsi2sd xmm0 , eax
                      call   sinc_process_mch

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

                      cmp    r9  , SINC_CONVBUFFSIZE
                      jz     .lp20

                      mov    rcx , [rbp + strr_smchiface]  ;get trailing delay
                      mov    rdx , [rbp + strr_buff]
                      lea    r8  , [rdx + rbx]
                      xor    r9  , r9
                      dec    r9
                      mov    rax , r14
                      cvtsi2sd xmm1 , eax
                      shr    rax , 32
                      cvtsi2sd xmm0 , eax
                      call   sinc_process_mch

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

                      mov    rcx , [rbp + strr_smchiface]  ;sinc multi-ch deinit
                      call   sinc_deinit_mch

                      mov    rcx , [rbp + strr_sinctable]  ;destroy table
                      call   sinc_destroy

                      mov    rcx , [rbp + strr_wfciface]   ;wfc deinit
                      call   wfc_deinit

                      mov    rcx , [rbp + strr_buff + 8]   ;free buffer
                      call   memfree

                      fxrstor [rbp + strr_fpummxssestate]

                      mov    rcx , [rbp + strr_infoblock]  ;free infoblock
                      call   memfree

                      xor    eax , eax
                      pop    rbx, rcx, rdx, rbp, r9, r10, r12, r13, r14, r15
                      ret
;------------------------------------------------------------------------------------




;------------------------------------------------------------------------------------
;SINC STREAM RESAMPLING GET INFO
;IN:   rcx -  stream type                                                     uses: -
;      rdx -  stream param 1
;      r8  -  stream param 2
;      r9  -  wfcinfo [out]
;
;OUT:  rax -  zero or a valid errorcode

sinc_stream_get_info:
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
