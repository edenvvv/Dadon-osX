
; THIS FILE IS PART OF THE 'SAMPLE CONVERTER' LIBRARY SOURCE CODE
; COPYRIGHT (C) 2009-2010 Akos Mogyorosi <flowwolf>
; FOR DETAILS SEE THE FILE README

; SAMPLE CONVERTER  24/06/2010

; 14/07/2010 32B format fix

;sc_init
;sc_deinit
;sc_to_internal
;sc_reassign
;sc_from_internal
;sc_ch_precision
;sc_get_buff


;------------------------------------------------------------------------------------
;SAMPLE CONVERTER INIT
;IN:   rcx - *sciface [out]                                                   uses: -
;      rdx -  (max number of samples * max number of input channels)  or zero
;      r8  -  (max number of samples * max number of output channels)  or zero
;
;OUT:  rax -  sc_lasterror
;
;NOTE: every successful call to sc_init involves a call to sc_deinit

sc_init:
                      push   r10, r9, rdx, rcx

                      xchg   rcx , r9                      ;r9  - *sciface
                      xchg   rdx , r10

                      ;xor    eax , eax  ;all x64 support SSE2
                      ;inc    eax
                      ;push   rbx
                      ;cpuid
                      ;pop    rbx
                      ;bt     edx , 26
                      ;mov    rax , D SC_ERR_SSE2_NOT_SUPPORTED
                      ;jnc    .err
                      mov    ecx , sc_infoblocksize + 16
                      call   memallocz
                      test   rax , rax
                      jnz    .sk10
             .errm:   mov    rax , SC_ERR_NOT_ENOUGH_MEMORY
              .err:
                      pop    rcx, rdx, r9, r10
                      ret
             .sk10:
                      mov    rcx , rax
                      test   al  , 15
                      jz     .sk12
                      and    al  , 15 xor -1
                      add    rax , 16
             .sk12:   mov    [rax + sc_infoblock], rcx     ;sc infoblock  (unaligned)

                      ;push   rax rbx
                      ;mov    rbx , [general_info_base]
                      ;imul   rbx , process_info_step
                      ;mov    rbx , [process_info_base+rbx+256]
                      ;sub    rax , rbx
                      mov    [r9], rax
                      ;pop    rbx rax

                      xchg   rax , r9                      ;r9  -  sciface

                      mov    rax , r10
                      shl    rax , 2
                      test   al  , 15
                      jz     .sk20
                      and    al  , 15 xor -1
                      add    rax , 16
             .sk20:   mov    [r9 + sc_buffsize], eax
                      lea    rax , [rax + r8*4]
                      test   rax , rax
                      jz     .sk22
                      add    rax , 16
                      xchg   rax , rcx
                      call   memallocz
                      test   rax , rax
                      jnz    .sk22
                      mov    rcx , [r9 + sc_infoblock]
                      call   memfree
                      jmp    .errm
             .sk22:
                      mov    [r9 + sc_buff + 8], rax
                      test   al  , 15
                      jz     .sk24
                      and    al  , 15 xor -1
                      add    rax , 16
             .sk24:   mov    [r9 + sc_buff], rax

                      xor    eax , eax
                      pop    rcx, rdx, r9, r10
                      ret
;------------------------------------------------------------------------------------




;------------------------------------------------------------------------------------
;SAMPLE CONVERTER DEINIT
;IN:   rcx -  sciface                                                         uses: -
;
;OUT:  rax -  SC_ERR_OK

sc_deinit:
                      push   rcx
                      mov    rcx , [rcx + sc_buff + 8]
                      call   memfree
                      pop    rcx
                      mov    rcx , [rcx + sc_infoblock]
                      call   memfree
                      xor    eax , eax
                      ret
;------------------------------------------------------------------------------------




;------------------------------------------------------------------------------------
;CONVERT SAMPLES TO INTERNAL FORMAT (32-BIT FLOAT)
;IN:   rcx -  sciface                                                         uses: -
;      rdx - *in
;      r8  - *out  or zero
;      r9  -  number of samples  or zero
;      r10 -  in format
;
;OUT:  rax -  number of bytes read from "in"

sc_to_internal:
                      push   rdi, rsi, rbp, rbx, rdx, rcx

                      xchg   rcx , rbp                 ;rbp -  sciface
                      xchg   rdx , rsi                 ;rsi - *in
                      mov    rdi , r8                  ;rdi - *out or *sc_buff
                      test   rdi , rdi
                      cmovz  rdi , [rbp + sc_buff]
                      mov    rcx , r9                  ;rcx -  number of samples
                      xor    eax , eax
                      test   rcx , rcx
                      jz     .sk80
                      mov    rax , r10                 ;rax -  in format
                      fxsave [rbp + sc_fpummxssestate]

                      mov    ebx , eax
                      shr    ebx , 8
                      and    ebx , 255
                      imul   ecx , ebx

                      test   al  , 128                 ;unsigned mask
                      setnz  bl
                      shl    ebx , 31
                      movd   xmm4 , ebx
                      shufps xmm4 , xmm4 , 0

                      mov    ah  , al
                      and    al  , 15
                      cmp    al  , 1                   ;8bit
                      jnz    .sk20
                      mov    eax , ecx
                      shr    ecx , 4
                      jz     .sk12
             .lp10:   movdqu xmm0 , [rsi]              ;xmm0 HGFEDCBAhgfedcba
                      movdqa xmm1 , xmm0               ;xmm1 HGFEDCBAhgfedcba
                      punpcklbw xmm0 , xmm0            ;xmm0 hhggffeeddccbbaa
                      punpckhbw xmm1 , xmm1            ;xmm1 HHGGFFEEDDCCBBAA
                      movdqa xmm2 , xmm0
                      movdqa xmm3 , xmm1
                      punpcklwd xmm0 , xmm0            ;xmm0 ddddccccbbbbaaaa
                      punpcklwd xmm1 , xmm1            ;xmm1 DDDDCCCCBBBBAAAA
                      punpckhwd xmm2 , xmm2            ;xmm2 hhhhggggffffeeee
                      punpckhwd xmm3 , xmm3            ;xmm3 HHHHGGGGFFFFEEEE
                      pxor   xmm0 , xmm4
                      pxor   xmm1 , xmm4
                      pxor   xmm2 , xmm4
                      pxor   xmm3 , xmm4
                      psrad  xmm0 , 24
                      psrad  xmm1 , 24
                      psrad  xmm2 , 24
                      psrad  xmm3 , 24
                      cvtdq2ps xmm0 , xmm0
                      cvtdq2ps xmm1 , xmm1
                      cvtdq2ps xmm2 , xmm2
                      cvtdq2ps xmm3 , xmm3
                      movdqa [rdi], xmm0
                      movdqa [rdi + 16], xmm2
                      movdqa [rdi + 32], xmm1
                      movdqa [rdi + 48], xmm3
                      add    rsi , 16
                      add    rdi , 64
                      loop   .lp10
             .sk12:   xchg   eax , ecx
                      and    ecx , 15
                      jz     .sk60
             .lp12:   lodsb
                      shl    eax , 24
                      xor    eax , ebx
                      sar    eax , 24
                      cvtsi2ss xmm0 , eax
                      movss  [rdi], xmm0
                      add    rdi , 4
                      loop   .lp12
                      jmp    .sk60

             .sk20:   cmp    al  , 2                   ;16bit
                      jnz    .sk30
                      mov    eax , ecx
                      shr    ecx , 3
                      jz     .sk22
             .lp20:   movdqu xmm0 , [rsi]              ;xmm0 hhggffeeddccbbaa
                      pxor   xmm0 , xmm4
                      movdqa xmm1 , xmm0               ;xmm1 hhggffeeddccbbaa
                      punpcklwd xmm0 , xmm0            ;xmm0 ddddccccbbbbaaaa
                      punpckhwd xmm1 , xmm1            ;xmm1 hhhhggggffffeeee
                      pxor   xmm0 , xmm4
                      pxor   xmm1 , xmm4
                      psrad  xmm0 , 16
                      psrad  xmm1 , 16
                      cvtdq2ps xmm0 , xmm0
                      cvtdq2ps xmm1 , xmm1
                      movdqa [rdi], xmm0
                      movdqa [rdi + 16], xmm1
                      add    rsi , 16
                      add    rdi , 32
                      loop   .lp20
             .sk22:   xchg   eax , ecx
                      and    ecx , 7
                      jz     .sk60
             .lp22:   lodsw
                      shl    eax , 16
                      xor    eax , ebx
                      sar    eax , 16
                      cvtsi2ss xmm0 , eax
                      movss  [rdi], xmm0
                      add    rdi , 4
                      loop   .lp22
                      jmp    .sk60

             .sk30:   cmp    al  , 3                   ;24bit
                      jnz    .sk40
                      mov    eax , ecx
                      shr    ecx , 4
                      jz     .sk32
             .lp30:   movdqu xmm0 , [rsi]              ;xmm0 feeedddcccbbbaaa
                      movdqa xmm3 , xmm0               ;
                      psrldq xmm3 , 12                 ;xmm3 ------------feee
                      movss  xmm1 , xmm0               ;xmm1 ------------baaa
                      pslldq xmm1 , 4                  ;xmm1 --------baaa----
                      psrldq xmm0 , 3                  ;xmm0 ---feeedddcccbbb
                      movss  xmm1 , xmm0               ;xmm1 --------baaacbbb
                      pslldq xmm1 , 4                  ;xmm1 ----baaacbbb----
                      psrldq xmm0 , 3                  ;xmm0 ------feeedddccc
                      movss  xmm1 , xmm0               ;xmm1 ----baaacbbbdccc
                      pslldq xmm1 , 4                  ;xmm1 baaacbbbdccc----
                      psrldq xmm0 , 3                  ;xmm0 ---------feeeddd
                      movss  xmm1 , xmm0               ;xmm1 baaacbbbdccceddd
                      pslldq xmm1 , 1                  ;xmm1 aaacbbbdccceddd-
                      pxor   xmm1 , xmm4
                      psrad  xmm1 , 8                  ;xmm1 aaaabbbbccccdddd
                      cvtdq2ps xmm1 , xmm1
                      shufps xmm1 , xmm1 , 00011011b
                      movdqa [rdi], xmm1
                      movdqu xmm0 , [rsi + 16]         ;xmm0 CCBBBAAAhhhgggff
                      movdqa xmm1 , xmm0               ;
                      pslldq xmm0 , 4                  ;xmm0 BAAAhhhgggff----
                      por    xmm0 , xmm3               ;xmm0 BAAAhhhgggfffeee
                      movdqa xmm3 , xmm1               ;xmm3 CCBBBAAAhhhgggff
                      psrldq xmm3 , 8                  ;xmm3 --------CCBBBAAA
                      movss  xmm1 , xmm0               ;xmm1 ------------feee
                      pslldq xmm1 , 4                  ;xmm1 --------feee----
                      psrldq xmm0 , 3                  ;xmm0 ---BAAAhhhgggfff
                      movss  xmm1 , xmm0               ;xmm1 --------feeegfff
                      pslldq xmm1 , 4                  ;xmm1 ----feeegfff----
                      psrldq xmm0 , 3                  ;xmm0 ------BAAAhhhggg
                      movss  xmm1 , xmm0               ;xmm1 ----feeegfffhggg
                      pslldq xmm1 , 4                  ;xmm1 feeegfffhggg----
                      psrldq xmm0 , 3                  ;xmm0 ---------BAAAhhh
                      movss  xmm1 , xmm0               ;xmm1 feeegfffhgggAhhh
                      pslldq xmm1 , 1                  ;xmm1 eeegfffhgggAhhh-
                      pxor   xmm1 , xmm4
                      psrad  xmm1 , 8                  ;xmm1 eeeeffffgggghhhh
                      cvtdq2ps xmm1 , xmm1
                      shufps xmm1 , xmm1 , 00011011b
                      movdqa [rdi + 16], xmm1
                      movdqu xmm0 , [rsi + 32]         ;xmm0 HHHGGGFFFEEEDDDC
                      movdqa xmm1 , xmm0               ;
                      pslldq xmm0 , 8                  ;xmm0 FEEEDDDC--------
                      por    xmm0 , xmm3               ;xmm0 FEEEDDDCCCBBBAAA
                      movdqa xmm3 , xmm1               ;xmm3 HHHGGGFFFEEEDDDC
                      psrldq xmm3 , 4                  ;xmm3 ----HHHGGGFFFEEE
                      movss  xmm1 , xmm0               ;xmm1 ------------BAAA
                      pslldq xmm1 , 4                  ;xmm1 --------BAAA----
                      psrldq xmm0 , 3                  ;xmm0 ---FEEEDDDCCCBBB
                      movss  xmm1 , xmm0               ;xmm1 --------BAAACBBB
                      pslldq xmm1 , 4                  ;xmm1 ----BAAACBBB----
                      psrldq xmm0 , 3                  ;xmm0 ------FEEEDDDCCC
                      movss  xmm1 , xmm0               ;xmm1 ----BAAACBBBDCCC
                      pslldq xmm1 , 4                  ;xmm1 BAAACBBBDCCC----
                      psrldq xmm0 , 3                  ;xmm0 ---------FEEEDDD
                      movss  xmm1 , xmm0               ;xmm1 BAAACBBBDCCCEDDD
                      pslldq xmm1 , 1                  ;xmm1 AAACBBBDCCCEDDD-
                      pxor   xmm1 , xmm4
                      psrad  xmm1 , 8                  ;xmm1 AAAABBBBCCCCDDDD
                      cvtdq2ps xmm1 , xmm1
                      shufps xmm1 , xmm1 , 00011011b
                      movdqa [rdi + 32], xmm1
                      movdqa xmm0 , xmm3               ;xmm0 ----HHHGGGFFFEEE
                      movss  xmm1 , xmm0               ;xmm1 ------------FEEE
                      pslldq xmm1 , 4                  ;xmm1 --------FEEE----
                      psrldq xmm0 , 3                  ;xmm0 -------HHHGGGFFF
                      movss  xmm1 , xmm0               ;xmm1 --------FEEEGFFF
                      pslldq xmm1 , 4                  ;xmm1 ----FEEEGFFF----
                      psrldq xmm0 , 3                  ;xmm0 ----------HHHGGG
                      movss  xmm1 , xmm0               ;xmm1 ----FEEEGFFFHGGG
                      pslldq xmm1 , 4                  ;xmm1 FEEEGFFFHGGG----
                      psrldq xmm0 , 3                  ;xmm0 -------------HHH
                      movss  xmm1 , xmm0               ;xmm1 FEEEGFFFHGGG-HHH
                      pslldq xmm1 , 1                  ;xmm1 EEEGFFFHGGG-HHH-
                      pxor   xmm1 , xmm4
                      psrad  xmm1 , 8                  ;xmm1 EEEEFFFFGGGGHHHH
                      cvtdq2ps xmm1 , xmm1
                      shufps xmm1 , xmm1 , 00011011b
                      movdqa [rdi + 48], xmm1
                      add    rsi , 48
                      add    rdi , 64
                      dec    rcx
                      jnz    .lp30
             .sk32:   xchg   eax , ecx
                      and    ecx , 15
                      jz     .sk60
             .lp32:   lodsw                            ;--ba
                      shl    eax , 16                  ;ba--
                      lodsb                            ;ba-c
                      ror    eax , 8                   ;cba-
                      xor    eax , ebx
                      sar    eax , 8
                      cvtsi2ss xmm0 , eax
                      movss  [rdi], xmm0
                      add    rdi , 4
                      loop   .lp32
                      jmp    .sk60

             .sk40:   test   ah  , 16                  ;32bit
                      jnz    .sk50
                      mov    eax , ecx
                      shr    ecx , 2
                      jz     .sk42
             .lp40:   movdqu xmm0 , [rsi]              ;xmm0 ddddccccbbbbaaaa
                      pxor   xmm0 , xmm4
                      cvtdq2ps xmm0 , xmm0
                      movdqa [rdi], xmm0
                      add    rsi , 16
                      add    rdi , 16
                      loop   .lp40
             .sk42:   xchg   eax , ecx
                      and    ecx , 3
                      jz     .sk60
             .lp42:   lodsd
                      xor    eax , ebx
                      cvtsi2ss xmm0 , eax
                      movss  [rdi], xmm0
                      add    rdi , 4
                      loop   .lp42
                      jmp    .sk60

             .sk50:   mov    eax , ecx                 ;32bit - float
                      shr    ecx , 2
                      jz     .sk52
             .lp50:   movdqu xmm0 , [rsi]
                      movdqa [rdi], xmm0
                      add    rsi , 16
                      add    rdi , 16
                      loop   .lp50
             .sk52:   xchg   eax , ecx
                      and    ecx , 3
                      rep movsd

             .sk60:   sub    rsi , rdx
                      xchg   rax , rsi
                      fxrstor [rbp + sc_fpummxssestate]
             .sk80:
                      pop    rcx, rdx, rbx, rbp, rsi, rdi
                      ret
;------------------------------------------------------------------------------------




;------------------------------------------------------------------------------------
;REASSIGN CHANNELS
;IN:   rcx -  sciface                                                         uses: -
;      rdx - *in  or zero
;      r8  - *out  or zero
;      r9  -  number of samples or zero
;      r10 -  in format << 32  +  out format
;      r11 - *channel reassignment list  or zero
;
;OUT:  rax -  SC_ERR_OK

sc_reassign:
                      push   rdi, rsi, rbp, rbx, rdx, rcx

                      xchg   rcx , rbp                 ;rbp -  sciface
                      xchg   rdx , rsi                 ;rsi - *in or *sc_buff
                      test   rsi , rsi
                      cmovz  rsi , [rbp + sc_buff]
                      mov    rdi , [rbp + sc_buff]
                      add    rdi , [rbp + sc_buffsize]
                      test   r8  , r8
                      cmovnz rdi , r8                  ;rdi - *out or *sc_buff (2nd half)
                      mov    rcx , r9
                      test   rcx , rcx
                      jz     .sk80
                      fxsave [rbp + sc_fpummxssestate]

                      test   r11 , r11
                      jnz    .sk20
                      mov    rax , r10
                      shr    rax , 32
                      shr    eax , 8
                      and    eax , 255
                      imul   ecx , eax
                      mov    eax , ecx
                      shr    ecx , 2
                      jz     .sk12
             .lp10:   movups xmm0 , [rsi]
                      movups [rdi], xmm0
                      add    rsi , 16
                      add    rdi , 16
                      loop   .lp10
             .sk12:   xchg   eax , ecx
                      and    ecx , 3
                      rep movsd
                      jmp    .sk40
             .sk20:
                      mov    ebx , r10d
                      shr    ebx , 8
                      and    ebx , 255
             .lp20:   xor    edx , edx
             .lp22:   mov    eax , [r11 + rdx*8]
                      cmp    eax , -2
                      jz     .sk22
                      sar    eax , 8
                      movd   xmm0 , eax
                      mov    eax , [r11 + rdx*8]
                      bt     eax , 31
                      adc    eax , 0
                      movss  xmm1 , [rsi + rax*4]
                      andnps xmm0 , xmm1
                      mov    eax , [r11 + rdx*8 + 4]
                      movss  [rdi + rax*4], xmm0
             .sk22:   inc    rdx
                      cmp    rdx , rbx
                      jnz    .lp22

                      mov    rax , r10
                      shr    rax , 32
                      shr    eax , 8
                      and    eax , 255
                      lea    rsi , [rsi + rax*4]
                      mov    eax , r10d
                      shr    eax , 8
                      and    eax , 255
                      lea    rdi , [rdi + rax*4]
                      loop   .lp20
             .sk40:
                      fxrstor [rbp + sc_fpummxssestate]
             .sk80:
                      xor    eax , eax
                      pop    rcx, rdx, rbx, rbp, rsi, rdi
                      ret
;------------------------------------------------------------------------------------




;------------------------------------------------------------------------------------
;CONVERT SAMPLES FROM INTERNAL FORMAT
;IN:   rcx -  sciface                                                         uses: -
;      rdx - *in  or zero
;      r8  - *out
;      r9  -  number of samples  or zero
;      r10 -  out format
;
;OUT:  rax -  number of bytes written to "out"

sc_from_internal:
                      push   rdi, rsi, rbp, rbx, rdx, rcx

                      xchg   rcx , rbp                 ;rbp -  sciface
                      mov    rsi , [rbp + sc_buff]
                      add    rsi , [rbp + sc_buffsize]
                      test   rdx , rdx
                      cmovnz rsi , rdx                 ;rsi - *in or *sc_buff (2nd half)
                      mov    rdi , r8                  ;rdi - *out
                      mov    rcx , r9                  ;rcx -  number of samples
                      test   rcx , rcx
                      jz     .sk80
                      mov    rax , r10                 ;rax -  out format
                      fxsave [rbp + sc_fpummxssestate]

                      mov    ebx , eax
                      shr    ebx , 8
                      and    ebx , 255
                      imul   ecx , ebx

                      test   al  , 128                 ;unsigned mask
                      setnz  bl
                      shl    ebx , 31
                      movd   xmm4 , ebx
                      shufps xmm4 , xmm4 , 00000000b

                      mov    ah  , al
                      and    al  , 15
                      cmp    al  , 1                   ;8bit
                      jnz    .sk20
                      packssdw xmm4 , xmm4
                      packsswb xmm4 , xmm4
                      movd   ebx , xmm4
                      mov    eax , ecx
                      shr    ecx , 4
                      jz     .sk12
             .lp10:   movaps xmm0 , [rsi]              ;xmm0 ddddccccbbbbaaaa
                      movaps xmm1 , [rsi + 16]         ;xmm1 hhhhggggffffeeee
                      movaps xmm2 , [rsi + 32]         ;xmm2 DDDDCCCCBBBBAAAA
                      movaps xmm3 , [rsi + 48]         ;xmm3 HHHHGGGGFFFFEEEE
                      cvtps2dq xmm0 , xmm0
                      cvtps2dq xmm1 , xmm1
                      cvtps2dq xmm2 , xmm2
                      cvtps2dq xmm3 , xmm3
                      packssdw xmm0 , xmm1             ;xmm0 hhggffeeddccbbaa
                      packssdw xmm2 , xmm3             ;xmm2 HHGGFFEEDDCCBBAA
                      packsswb xmm0 , xmm2             ;xmm0 HGFEDCBAhgfedcba
                      pxor   xmm0 , xmm4
                      movdqu [rdi], xmm0
                      add    rsi , 64
                      add    rdi , 16
                      loop   .lp10
             .sk12:   xchg   eax , ecx
                      and    ecx , 15
                      jz     .sk60
             .lp12:   cvtss2si eax , [rsi]
                      add    rsi , 4
                      xor    eax , ebx
                      stosb
                      loop   .lp12
                      jmp    .sk60

             .sk20:   cmp    al  , 2                   ;16bit
                      jnz    .sk30
                      packssdw xmm4 , xmm4
                      movd   ebx , xmm4
                      mov    eax , ecx
                      shr    ecx , 3
                      jz     .sk22
             .lp20:   movaps xmm0 , [rsi]              ;xmm0 ddddccccbbbbaaaa
                      movaps xmm1 , [rsi + 16]         ;xmm1 hhhhggggffffeeee
                      cvtps2dq xmm0 , xmm0
                      cvtps2dq xmm1 , xmm1
                      packssdw xmm0 , xmm1             ;xmm0 hhggffeeddccbbaa
                      pxor   xmm0 , xmm4
                      movdqu [rdi], xmm0
                      add    rsi , 32
                      add    rdi , 16
                      loop   .lp20
             .sk22:   xchg   eax , ecx
                      and    ecx , 7
                      jz     .sk60
             .lp22:   cvtss2si eax , [rsi]
                      add    rsi , 4
                      xor    eax , ebx
                      stosw
                      loop   .lp22
                      jmp    .sk60

             .sk30:   cmp    al  , 3                   ;24bit
                      jnz    .sk40
                      xorps  xmm2 , xmm2
                      mov    rax , .max24b
                      movaps xmm5 , [rax]
                      movaps xmm6 , [rax + 16]
                      mov    eax , ecx
                      shr    ecx , 4
                      jz     .sk32
             .lp30:   movaps xmm0 , [rsi]              ;xmm0 ddddccccbbbbaaaa
                      shufps xmm0 , xmm0 , 00011011b   ;xmm0 aaaabbbbccccdddd
                      maxps  xmm0 , xmm5               ;
                      minps  xmm0 , xmm6               ;
                      cvtps2dq xmm0 , xmm0             ;
                      pslld  xmm0 , 8                  ;xmm0 aaa-bbb-ccc-ddd-
                      pxor   xmm0 , xmm4               ;
                      movss  xmm1 , xmm0               ;xmm1 ------------ddd-
                      psrldq xmm0 , 4+1                ;xmm0 -----aaa-bbb-ccc
                      pslldq xmm1 , 3-1                ;xmm1 ----------ddd---
                      movss  xmm2 , xmm0               ;
                      por    xmm1 , xmm2               ;xmm1 ----------dddccc
                      psrldq xmm0 , 4                  ;xmm0 ---------aaa-bbb
                      pslldq xmm1 , 3                  ;xmm1 -------dddccc---
                      movss  xmm2 , xmm0               ;
                      por    xmm1 , xmm2               ;xmm1 -------dddcccbbb
                      psrldq xmm0 , 4                  ;xmm0 -------------aaa
                      pslldq xmm1 , 3                  ;xmm1 ----dddcccbbb---
                      movss  xmm2 , xmm0               ;
                      por    xmm1 , xmm2               ;xmm1 ----dddcccbbbaaa
                      movaps xmm0 , [rsi + 16]         ;xmm0 hhhhggggffffeeee
                      shufps xmm0 , xmm0 , 00011011b   ;xmm0 eeeeffffgggghhhh
                      maxps  xmm0 , xmm5               ;
                      minps  xmm0 , xmm6               ;
                      cvtps2dq xmm0 , xmm0             ;
                      pslld  xmm0 , 8                  ;xmm0 eee-fff-ggg-hhh-
                      pxor   xmm0 , xmm4               ;
                      movss  xmm3 , xmm0               ;xmm3 ------------hhh-
                      psrldq xmm0 , 4+1                ;xmm0 -----eee-fff-ggg
                      pslldq xmm3 , 3-1                ;xmm3 ----------hhh---
                      movss  xmm2 , xmm0               ;
                      por    xmm3 , xmm2               ;xmm3 ----------hhhggg
                      psrldq xmm0 , 4                  ;xmm0 ---------eee-fff
                      pslldq xmm3 , 3                  ;xmm3 -------hhhggg---
                      movss  xmm2 , xmm0               ;
                      por    xmm3 , xmm2               ;xmm3 -------hhhgggfff
                      psrldq xmm0 , 4                  ;xmm0 -------------eee
                      pslldq xmm3 , 3                  ;xmm3 ----hhhgggfff---
                      movss  xmm2 , xmm0               ;
                      por    xmm3 , xmm2               ;xmm3 ----hhhgggfffeee
                      pslldq xmm1 , 4                  ;xmm1 dddcccbbbaaa----
                      movss  xmm1 , xmm3               ;xmm1 dddcccbbbaaafeee
                      shufps xmm1 , xmm1 , 00111001b   ;xmm1 feeedddcccbbbaaa
                      movdqu [rdi], xmm1
                      movaps xmm0 , [rsi + 32]         ;xmm0 DDDDCCCCBBBBAAAA
                      shufps xmm0 , xmm0 , 00011011b   ;xmm0 AAAABBBBCCCCDDDD
                      maxps  xmm0 , xmm5               ;
                      minps  xmm0 , xmm6               ;
                      cvtps2dq xmm0 , xmm0             ;
                      pslld  xmm0 , 8                  ;xmm0 AAA-BBB-CCC-DDD-
                      pxor   xmm0 , xmm4               ;
                      movss  xmm1 , xmm0               ;xmm1 ------------DDD-
                      psrldq xmm0 , 4+1                ;xmm0 -----AAA-BBB-CCC
                      pslldq xmm1 , 3-1                ;xmm1 ----------DDD---
                      movss  xmm2 , xmm0               ;
                      por    xmm1 , xmm2               ;xmm1 ----------DDDCCC
                      psrldq xmm0 , 4                  ;xmm0 ---------AAA-BBB
                      pslldq xmm1 , 3                  ;xmm1 -------DDDCCC---
                      movss  xmm2 , xmm0               ;
                      por    xmm1 , xmm2               ;xmm1 -------DDDCCCBBB
                      psrldq xmm0 , 4                  ;xmm0 -------------AAA
                      pslldq xmm1 , 3                  ;xmm1 ----DDDCCCBBB---
                      movss  xmm2 , xmm0               ;
                      por    xmm1 , xmm2               ;xmm1 ----DDDCCCBBBAAA
                      psrldq xmm3 , 4                  ;xmm3 --------hhhgggff
                      movlhps xmm3 , xmm1              ;xmm3 CCBBBAAAhhhgggff
                      movdqu [rdi + 16], xmm3
                      movaps xmm0 , [rsi + 48]         ;xmm0 HHHHGGGGFFFFEEEE
                      shufps xmm0 , xmm0 , 00011011b   ;xmm0 EEEEFFFFGGGGHHHH
                      maxps  xmm0 , xmm5               ;
                      minps  xmm0 , xmm6               ;
                      cvtps2dq xmm0 , xmm0             ;
                      pslld  xmm0 , 8                  ;xmm0 EEE-FFF-GGG-HHH-
                      pxor   xmm0 , xmm4               ;
                      movss  xmm3 , xmm0               ;xmm3 ------------HHH-
                      psrldq xmm0 , 4+1                ;xmm0 -----EEE-FFF-GGG
                      pslldq xmm3 , 3-1                ;xmm3 ----------HHH---
                      movss  xmm2 , xmm0               ;
                      por    xmm3 , xmm2               ;xmm3 ----------HHHGGG
                      psrldq xmm0 , 4                  ;xmm0 ---------EEE-FFF
                      pslldq xmm3 , 3                  ;xmm3 -------HHHGGG---
                      movss  xmm2 , xmm0               ;
                      por    xmm3 , xmm2               ;xmm3 -------HHHGGGFFF
                      psrldq xmm0 , 4                  ;xmm0 -------------EEE
                      pslldq xmm3 , 3                  ;xmm3 ----HHHGGGFFF---
                      movss  xmm2 , xmm0               ;
                      por    xmm3 , xmm2               ;xmm3 ----HHHGGGFFFEEE
                      psrldq xmm1 , 8                  ;xmm1 ------------DDDC
                      pslldq xmm3 , 4                  ;xmm3 HHHGGGFFFEEE----
                      movss  xmm3 , xmm1               ;xmm3 HHHGGGFFFEEEDDDC
                      movdqu [rdi+32], xmm3
                      add    rsi , 64
                      add    rdi , 48
                      dec    rcx
                      jnz    .lp30
             .sk32:   xchg   eax , ecx
                      and    ecx , 15
                      jz     .sk60
             .lp32:   movss  xmm0 , [rsi]
                      add    rsi,4
                      maxss  xmm0 , xmm5
                      minss  xmm0 , xmm6
                      cvtss2si eax , xmm0
                      shl    eax , 8                   ;cba-
                      xor    eax , ebx
                      shr    eax , 8                   ;-cba
                      stosb
                      shr    eax , 8                   ;--cb
                      stosw
                      loop   .lp32
                      jmp    .sk60

             .sk40:   test   ah  , 16                  ;32bit
                      jnz    .sk50
                      mov    rax , .max32b
                      movaps xmm5 , [rax]
                      movaps xmm6 , [rax + 16]
                      mov    eax , ecx
                      shr    ecx , 2
                      jz     .sk42
             .lp40:   movaps xmm0 , [rsi]              ;xmm0 ddddccccbbbbaaaa
                      maxps  xmm0 , xmm5
                      minps  xmm0 , xmm6
                      cvtps2dq xmm0 , xmm0
                      pxor   xmm0 , xmm4
                      movdqu [rdi], xmm0
                      add    rsi , 16
                      add    rdi , 16
                      loop   .lp40
             .sk42:   xchg   eax , ecx
                      and    ecx , 3
                      jz     .sk60
             .lp42:   movss  xmm0 , [rsi]
                      add    rsi , 4
                      maxss  xmm0 , xmm5
                      minss  xmm0 , xmm6
                      cvtss2si eax , xmm0
                      xor    eax , ebx
                      stosd
                      loop   .lp42
                      jmp    .sk60

             .sk50:   mov    eax , ecx                 ;32bit - float
                      shr    ecx , 2
                      jz     .sk52
             .lp50:   movaps xmm0 , [rsi]
                      movups [rdi], xmm0
                      add    rsi , 16
                      add    rdi , 16
                      loop   .lp50
             .sk52:   xchg   eax , ecx
                      and    ecx , 3
                      rep movsd

             .sk60:   sub    rdi , r8
                      xchg   rax , rdi
                      fxrstor [rbp + sc_fpummxssestate]
             .sk80:
                      pop    rcx, rdx, rbx, rbp, rsi, rdi
                      ret
;------------------------------------------------------------------------------------
align 16

.max24b  dd -8388608.0,-8388608.0,-8388608.0,-8388608.0
.min24b  dd  8388607.0, 8388607.0, 8388607.0, 8388607.0
.max32b  dd -2147483904.0, -2147483904.0, -2147483904.0, -2147483904.0
.min32b  dd  2147483392.0,  2147483392.0,  2147483392.0,  2147483392.0

;------------------------------------------------------------------------------------




;------------------------------------------------------------------------------------
;CHANGE SAMPLE PRECISION
;IN:   rcx -  sciface                                                         uses: -
;      rdx - *inout  or zero
;      r8  -  number of samples  or zero
;      r9  -  in format << 32  +  out format
;
;OUT:  rax -  SC_ERR_OK

sc_ch_precision:
                      push   rsi, rbp, rcx

                      xchg   rcx , rbp                 ;rbp -  sciface
                      mov    rsi , [rbp + sc_buff]
                      add    rsi , [rbp + sc_buffsize]
                      test   rdx , rdx
                      cmovnz rsi , rdx                 ;rsi - *in or *sc_buff (2nd half)
                      mov    rcx , r8                  ;rcx -  number of samples
                      test   rcx , rcx
                      jz     .sk80
                      fxsave [rbp + sc_fpummxssestate]

                      mov    rax , r9
                      shr    rax , 32
                      and    rax , 7
                      push   r15
                      mov    r15 , .maxv
                      mov    rax , [r15 + rax*8]
                      bt     r9  , (4+32)
                      cmovc  rax , [r15 + 64]
                      movq   xmm0 , rax

                      mov    rax , r9
                      and    rax , 7
                      mov    rax , [r15 + rax*8]
                      bt     r9  , 4
                      cmovc  rax , [r15 + 64]
                      pop    r15

                      movq   xmm1 , rax
                      divsd  xmm1 , xmm0
                      cvtsd2ss xmm1 , xmm1
                      shufps xmm1 , xmm1 , 0

                      mov    rax , r9                  ;rax -  format
                      shr    rax , 32+8
                      and    rax , 255
                      imul   ecx , eax

                      mov    eax , ecx
                      shr    ecx , 2
                      jz     .sk12
             .lp10:   movups xmm0 , [rsi]
                      mulps  xmm0 , xmm1
                      movups [rsi], xmm0
                      add    rsi , 16
                      loop   .lp10
             .sk12:   xchg   eax , ecx
                      and    ecx , 3
                      jz     .sk20
             .lp12:   movss  xmm0 , [rsi]
                      mulss  xmm0 , xmm1
                      movss  [rsi], xmm0
                      add    rsi , 4
                      loop   .lp12
             .sk20:
                      fxrstor [rbp + sc_fpummxssestate]
             .sk80:
                      xor    eax , eax
                      pop    rcx, rbp, rsi
                      ret
;------------------------------------------------------------------------------------
align 8

.maxv    dq  0  ,  127.0  ,  32767.0  ,  8388607.0  ,  2147483647.0  ,  0,0,0
.maxf    dq  1.0

;------------------------------------------------------------------------------------




;------------------------------------------------------------------------------------
;GET INTERNAL BUFFERS
;IN:   rcx -  sciface                                                         uses: -
;      rdx - *in buffer [out]
;      r8  - *out buffer [out]
;
;OUT:  rax -  SC_ERR_OK

sc_get_buff:
                      mov    rax , [rcx + sc_buff]

                      ;push   rbx
                      ;mov    rbx , [general_info_base]
                      ;imul   rbx , process_info_step
                      ;mov    rbx , [process_info_base+rbx+256]
                      ;sub    rax , rbx
                      ;pop    rbx

                      test   rdx , rdx
                      jz     .sk10
                      mov    [rdx], rax
             .sk10:   add    rax , [rcx + sc_buffsize]
                      test   r8  , r8
                      jz     .sk12
                      mov    [r8], rax
             .sk12:   xor    eax , eax
                      ret
;------------------------------------------------------------------------------------












