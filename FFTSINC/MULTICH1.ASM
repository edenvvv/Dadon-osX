
; THIS FILE IS PART OF THE 'SINC RESAMPLING KERNEL' LIBRARY SOURCE CODE
; COPYRIGHT (C) 2008-2010 Akos Mogyorosi <flowwolf>
; FOR DETAILS SEE THE FILE README

; MULTI-CHANNEL INTERFACE

;sinc_init_mch
;sinc_deinit_mch
;sinc_process_mch
;sinc_flush_mch


;------------------------------------------------------------------------------------
;SINC INIT MULTI-CHANNEL
;IN:   rcx - *smchiface [out]                                                 uses: -
;      rdx -  sinc table
;      r8  -  in sc format << 32  +  out sc format
;     xmm0 -  max downsampling ratio  (double)
;     xmm1 -  max upsampling ratio  (double)
;
;OUT:  rax -  sinc_lasterror
;
;NOTE: every successful call to sinc_init_mch involves a call to sinc_deinit_mch

sinc_init_mch:
                      push   r12, r11, r10, r9, rdx, rcx

                      xchg   rcx , r9                      ;r9  - *smchiface
                      movq   r11 , xmm0                    ;r11 -  max downsampling ratio
                      movq   r12 , xmm1                    ;r12 -  max upsampling ratio

                      mov    rax , r8                      ;check sc formats
                      shr    rax , 32+8
                      and    rax , 255
                      mov    ecx , r8d
                      shr    ecx , 8
                      and    ecx , 255
                      cmp    ecx , eax
                      mov    rax , SINC_ERR_INVALID_FORMAT
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
                      ;mov    rax , SINC_ERR_SSE2_NOT_SUPPORTED
                      ;jnc    .err
                      mov    ecx , smch_infoblocksize + 16
                      call   memallocz
                      test   rax , rax
                      jnz    .sk10
             .errm:   mov    rax , SINC_ERR_NOT_ENOUGH_MEMORY
              .err:
                      pop    rcx, rdx, r9, r10, r11, r12
                      ret
             .sk10:
                      mov    rcx , rax
                      test   al  , 15
                      jz     .sk12
                      and    al  , 15 xor -1
                      add    rax , 16
             .sk12:   mov    [rax + smch_infoblock], rcx
                      mov    [rax + smch_format], r8
                      mov    [r9], rax
                      xchg   rax , r10                     ;r10 -  smchiface

                      xor    r9  , r9                      ;init sinc
             .lp20:   lea    rcx , [r10 + smch_sincifaces + r9*8]
                      movq   xmm0, r11
                      call   sinc_init
                      test   rax , rax
                      jz     .sk20
             .sk22:   xchg   rax , rdx
                      xor    r9  , r9                      ;(deinit sinc on error)
             .lp24:   mov    rcx , [r10 + smch_sincifaces + r9*8]
                      jrcxz  .sk24
                      call   sinc_deinit
             .sk24:   inc    r9
                      mov    rax , r8
                      shr    rax , 32+8
                      and    rax , 255
                      cmp    rax , r9
                      jnz    .lp24
                      mov    rcx , [r10 + smch_infoblock]  ;(free infoblock on error)
                      call   memfree
                      xchg   rax , rdx
                      jmp    .err
             .sk20:   inc    r9
                      mov    rax , r8
                      shr    rax , 32+8
                      and    rax , 255
                      cmp    rax , r9
                      jnz    .lp20

                      fxsave [r10 + smch_fpummxssestate]   ;allocate buffer
                      mov    rcx , [r10 + smch_sincifaces + 0]
                      mov    r9  , -2
                      mov    rdx , (SINC_FORMAT_FLOAT32_M shl 32)  +  SINC_FORMAT_FLOAT32_M
                      xchg   rdx , r10
                      xor    eax , eax
                      inc    eax
                      cvtsi2sd xmm0 , eax
                      movq   xmm1 , r12
                      call   sinc_process
                      xchg   rdx , r10
                      mov    ecx , SINC_CONVBUFFSIZE
                      cvtsi2sd xmm0 , ecx
                      movq   xmm1 , r12
                      mulsd  xmm1 , xmm0
                      cvtsd2si ecx , xmm1
                      cmp    ecx , eax                     ;compare with trailing delay length
                      cmovb  ecx , eax
                      and    ecx , 15 xor -1
                      add    ecx , 16 + 16
                      mov    [r10 + smch_bufflength], rcx
                      mov    rax , r8
                      shr    rax , 32+8
                      and    rax , 255
                      imul   rcx , rax
                      shl    rcx , 2
                      fxrstor [r10 + smch_fpummxssestate]
                      call   memalloc
                      test   rax , rax
                      jnz    .sk30
                      mov    rax , SINC_ERR_NOT_ENOUGH_MEMORY
                      jmp    .sk22
             .sk30:   mov    rcx , rax
                      test   al  , 15
                      jz     .sk32
                      and    al  , 15 xor -1
                      add    rax , 16
             .sk32:   mov    [r10 + smch_buff], rax
                      mov    [r10 + smch_buff + 8], rcx

                      lea    rcx , [r10 + smch_sciface]    ;init sc
                      mov    rdx , r8
                      shr    rdx , 32+8
                      and    rdx , 255
                      imul   rdx , SINC_CONVBUFFSIZE
                      mov    r9d , r8d
                      shr    r9  , 8
                      and    r9  , 255
                      imul   r9  , [r10 + smch_bufflength]
                      xchg   r9  , r8
                      call   sc_init
                      xchg   r9  , r8
                      test   rax , rax
                      jnz    .sk22

                      xor    eax , eax
                      pop    rcx, rdx, r9, r10, r11, r12
                      ret
;------------------------------------------------------------------------------------




;------------------------------------------------------------------------------------
;SINC DEINIT MULTI-CHANNEL
;IN:   rcx -  smchiface                                                       uses: -
;
;OUT:  rax -  SINC_ERR_OK

sinc_deinit_mch:
                      push   r10, r9, rcx

                      xchg   rcx , r10                     ;r10 -  smchiface

                      mov    rcx , [r10 + smch_sciface]    ;deinit sc
                      call   sc_deinit

                      xor    r9  , r9                      ;deinit sinc
             .lp10:   mov    rcx , [r10 + smch_sincifaces + r9*8]
                      call   sinc_deinit
                      inc    r9
                      mov    rax , [r10 + smch_format]
                      shr    rax , 32+8
                      and    rax , 255
                      cmp    rax , r9
                      jnz    .lp10

                      mov    rcx , [r10 + smch_buff + 8]
                      call   memfree
                      mov    rcx , [r10 + smch_infoblock]
                      call   memfree

                      xor    eax , eax
                      pop    rcx, r9, r10
                      ret
;------------------------------------------------------------------------------------




;------------------------------------------------------------------------------------
;SINC PROCESS MULTI-CHANNEL
;IN:   rcx -  smchiface                                                       uses: -
;      rdx - *in
;      r8  - *out
;      r9  -  number of samples  or -1/-2 for  trailing delay / delay length
;     xmm0 -  input rate  (double)
;     xmm1 -  output rate  (double)
;
;OUT:  rax -  number of samples processed

sinc_process_mch:
                      push   r14, r13, r12, r11, r10, r9, r8, rdi, rsi, rbp, rbx, rdx, rcx

                      xchg   rcx , rbp                     ;rbp -  smchiface
                      xchg   rdx , rsi                     ;rsi - *in
                      xchg   r8  , rdi                     ;rdi - *out
                      xchg   r9  , rbx                     ;rbx -  number of samples
                      xor    r14 , r14                     ;r14 -  number of samples processed

                      cmp    rbx , -2                      ;get trailing delay length
                      jnz    .lp10
                      mov    rcx , [rbp + smch_sincifaces + 0]
                      xor    edx , edx
                      xor    r8  , r8
                      mov    r9  , -2
                      mov    r10 , (SINC_FORMAT_FLOAT32_M shl 32)  +  SINC_FORMAT_FLOAT32_M
                      call   sinc_process
                      jmp    .end

             .lp10:
                      mov    eax , SINC_CONVBUFFSIZE       ;r13 -  actual number of samples
                      mov    r13 , rbx
                      cmp    r13 , -1
                      jz     .sk12
                      cmp    r13 , rax
                      cmova  r13 , rax
                      sub    rbx , r13

                      mov    rcx , [rbp + smch_sciface]    ;convert to internal
                      mov    rdx , rsi
                      xor    r8  , r8
                      mov    r9  , r13
                      mov    r10 , [rbp + smch_format]
                      shr    r10 , 32
                      call   sc_to_internal
                      add    rsi , rax
             .sk12:
                      xor    r12 , r12                     ;1st pass
             .lp12:
                      cmp    r13 , -1
                      jz     .sk14

                      mov    rcx , [rbp + smch_sciface]    ;reassign one channel at a time
                      xor    edx , edx
                      xor    r8  , r8
                      mov    r9  , r13
                      mov    r10 , 0xffffffff00000000
                      and    r10 , [rbp + smch_format]
                      or     r10 , 1 shl 8
                      push   r12
                      mov    r11 , rsp
                      call   sc_reassign
                      add    rsp , 8
             .sk14:
                      mov    rcx , [rbp + smch_sciface]    ;get "output" internal buffer
                      xor    edx , edx
                      push   0
                      mov    r8  , rsp
                      call   sc_get_buff
                      pop    rdx

                      mov    rcx , [rbp + smch_sincifaces + r12*8]
                      mov    r8  , [rbp + smch_bufflength]
                      imul   r8  , r12
                      shl    r8  , 2
                      add    r8  , [rbp + smch_buff]
                      mov    r9  , r13
                      mov    r10 , (SINC_FORMAT_FLOAT32_M shl 32)  +  SINC_FORMAT_FLOAT32_M
                      call   sinc_process

                      mov    rcx , [rbp + smch_format]
                      shr    rcx , 32+8
                      and    rcx , 255
                      inc    r12
                      cmp    r12 , rcx
                      jnz    .lp12

                      xchg   rax , r9                      ;r9  -  number of samples processed


                      xor    r12 , r12                     ;2nd pass
             .lp14:
                      xor    ecx , ecx                     ;init aslist
             .lp16:   mov    D [rbp + smch_aslist + rcx*8], -2
                      mov    [rbp + smch_aslist + rcx*8 +4], ecx
                      mov    eax , [rbp + smch_format]
                      shr    eax , 8
                      and    eax , 255
                      inc    ecx
                      cmp    ecx , eax
                      jnz    .lp16
                      mov    D [rbp + smch_aslist + r12*8], 0

                      mov    rcx , [rbp + smch_sciface]    ;reassign channels
                      mov    rdx , [rbp + smch_bufflength]
                      imul   rdx , r12
                      shl    rdx , 2
                      add    rdx , [rbp + smch_buff]
                      xor    r8  , r8
                      mov    rax , (1 shl 8) shl 32
                      mov    r10d, [rbp + smch_format]
                      or     r10 , rax
                      lea    r11 , [rbp + smch_aslist]
                      call   sc_reassign

                      mov    rcx , [rbp + smch_format]
                      shr    rcx , 32+8
                      and    rcx , 255
                      inc    r12
                      cmp    r12 , rcx
                      jnz    .lp14


                      mov    rcx , [rbp + smch_sciface]    ;change precision
                      xor    edx , edx
                      mov    r8  , [rbp + smch_format]
                      xchg   r8  , r9
                      call   sc_ch_precision
                      xchg   r8  , r9

                      mov    rcx , [rbp + smch_sciface]    ;convert from internal
                      xor    edx , edx
                      mov    r8  , rdi
                      mov    r10d, [rbp + smch_format]
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
;SINC FLUSH BUFFERS MULTI-CHANNEL
;IN:   rcx -  smchiface                                                       uses: -
;
;OUT:  rax -  SINC_ERR_OK

sinc_flush_mch:
                      push   r9, r8, rcx

                      xchg   rcx , r9                      ;r9  -  smchiface

                      xor    r8  , r8
             .lp10:   mov    rcx , [r9 + smch_sincifaces + r8*8]
                      call   sinc_flush
                      mov    rax , [r9 + smch_format]
                      shr    rax , 32+8
                      and    rax , 255
                      inc    r8
                      cmp    r8  , rax
                      jnz    .lp10

                      xor    eax , eax
                      pop    rcx, r8, r9
                      ret
;------------------------------------------------------------------------------------














