
; COPYRIGHT (C) 2008-2010 Akos Mogyorosi <flowwolf>
; FOR DETAILS SEE THE FILE README

; 14/07/2010 32B format fix
; 26/02/2011 unpcklps fix

; %define  FORMAT_8B_M          (4     )
; %define  FORMAT_8B_ST_L       (4+2+0 )
; %define  FORMAT_8B_ST_R       (4+2+1 )
; %define  FORMAT_16B_M         (8     )
; %define  FORMAT_16B_ST_L      (8+2+0 )
; %define  FORMAT_16B_ST_R      (8+2+1 )
; %define  FORMAT_32B_M         (16    )
; %define  FORMAT_32B_ST_L      (16+2+0)
; %define  FORMAT_32B_ST_R      (16+2+1)
; %define  FORMAT_FLOAT32_M     (32    )
; %define  FORMAT_FLOAT32_ST_L  (32+2+0)
; %define  FORMAT_FLOAT32_ST_R  (32+2+1)

;sampconv_to_internal
;sampconv_from_internal

;------------------------------------------------------------------------------------
;CONVERT SAMPLES TO INTERNAL FORMAT (32-BIT FLOAT)
;IN:   rcx - *in                                                      uses: xmm0-xmm5
;      rdx - *out
;      r8  -  number of samples  or zero
;      r9  -  in format
;
;OUT:  rax -  number of bytes read from "in"

sampconv_to_internal:
                      push   rdi, rsi, rdx, rcx

                      xchg   rcx , rsi                 ;rsi - *in
                      xchg   rdx , rdi                 ;rdi - *out
                      mov    rdx , rsi
                      mov    rcx , r8                  ;rcx -  number of samples
                      test   rcx , rcx
                      jz     .sk60
                      mov    rax , r9                  ;rax -  in format

                      and    eax , 1
                      xorps  xmm4 , xmm4

                      push   r15
                      mov    r15 , sampconv_LR_mask32
                      movlps xmm5 , qword [r15 + rax*8]
                      pop    r15

                      unpcklps xmm5 , xmm5
                      mov    rax , r9
                      test   al  , 4
                      jnz    .sk40
                      test   al  , 8
                      jnz    .sk30
                      test   al  , 16
                      jnz    .sk20


             .sk10:   ;32bit float
                      test   al  , 2                   ;32b float - mono
                      jnz    .sk14
                      mov    eax , ecx
                      shr    ecx , 2
                      jz     .sk12
             .lp10:   movups xmm0 , [rsi]
                      add    rsi  , 16
                      movups [rdi], xmm0
                      add    rdi  , 16
                      loop   .lp10
             .sk12:   and    eax , 3
                      xchg   eax , ecx
                      rep movsd
                      jmp    .sk60

             .sk14:   mov    eax , ecx                 ;32b float - stereo
                      shr    ecx , 1
                      jz     .sk16
             .lp14:   movups xmm0 , [rsi]              ;xmm0  r1    l1    r0    l0
                      shufps xmm0 , xmm0 , 11011000b   ;xmm0  r1    r0    l1    l0
                      andps  xmm0 , xmm5               ;xmm0  r1m   r0m   l1m   l0m
                      movhlps xmm1, xmm0               ;xmm1  x     x     r1m   r0m
                      orps   xmm0 , xmm1               ;xmm0  x     x     r1/l1 r0/l0
                      movlps [rdi], xmm0
                      add    rsi , 16
                      add    rdi , 8
                      loop   .lp14
             .sk16:   and    eax , 1
                      xchg   eax , ecx
                      jz     .sk60
                      movlps xmm0 , [rsi]              ;xmm0  x     x     r0    l0
                      unpcklps xmm0 , xmm0             ;xmm0  r0    r0    l0    l0
                      andps  xmm0 , xmm5               ;xmm0  r0m   r0m   l0m   l0m
                      movhlps xmm1, xmm0               ;xmm1  x     x     r0m   r0m
                      orps   xmm0 , xmm1               ;xmm0  x     x     r0/l0 r0/l0
                      movss  [rdi], xmm0
                      add    rsi , 8
                      jmp    .sk60


             .sk20:   ;32bit
                      test   al  , 2                   ;32b - mono
                      jnz    .sk24
                      mov    eax , ecx
                      shr    ecx , 2
                      jz     .sk22
             .lp20:   movdqu xmm0 , [rsi]
                      add    rsi , 16
                      cvtdq2ps xmm0 , xmm0
                      movups [rdi], xmm0
                      add    rdi , 16
                      loop   .lp20
             .sk22:   and    eax , 3
                      xchg   eax , ecx
                      jz     .sk60
             .lp22:   cvtsi2ss xmm0 , [rsi]
                      add    rsi , 4
                      movss  [rdi], xmm0
                      add    rdi , 4
                      loop   .lp22
                      jmp    .sk60

             .sk24:   mov    eax , ecx                 ;32b - stereo
                      shr    ecx , 1
                      jz     .sk26
             .lp24:   movdqu xmm0 , [rsi]              ;xmm0  r1    l1    r0    l0
                      cvtdq2ps xmm0 , xmm0
                      shufps xmm0 , xmm0 , 11011000b   ;xmm0  r1    r0    l1    l0
                      andps  xmm0 , xmm5               ;xmm0  r1m   r0m   l1m   l0m
                      movhlps xmm1, xmm0               ;xmm1  x     x     r1m   r0m
                      orps   xmm0 , xmm1               ;xmm0  x     x     r1/l1 r0/l0
                      movlps [rdi], xmm0
                      add    rsi , 16
                      add    rdi , 8
                      loop   .lp24
             .sk26:   and    eax , 1
                      xchg   eax , ecx
                      jz     .sk60
                      movlps xmm0 , [rsi]              ;xmm0  x     x     r0    l0
                      cvtdq2ps xmm0 , xmm0
                      unpcklps xmm0 , xmm0             ;xmm0  r0    r0    l0    l0
                      andps  xmm0 , xmm5               ;xmm0  r0m   r0m   l0m   l0m
                      movhlps xmm1, xmm0               ;xmm1  x     x     r0m   r0m
                      orps   xmm0 , xmm1               ;xmm0  x     x     r0/l0 r0/l0
                      movss  [rdi], xmm0
                      add    rsi , 8
                      jmp    .sk60


             .sk30:   ;16bit
                      test   al  , 2                   ;16b - mono
                      jnz    .sk34
                      mov    eax , ecx
                      shr    ecx , 3
                      jz     .sk32
             .lp30:   movdqu xmm0 , [rsi]              ;xmm0  m7 m6 m5 m4 m3 m2 m1 m0
                      movdqa xmm1 , xmm0               ;xmm1  m7 m6 m5 m4 m3 m2 m1 m0
                      punpcklwd xmm0 , xmm0            ;xmm0  m3 m3 m2 m2 m1 m1 m0 m0
                      punpckhwd xmm1 , xmm1            ;xmm1  m7 m7 m6 m6 m5 m5 m4 m4
                      psrad  xmm0 , 16                 ;xmm0  m3    m2    m1    m0
                      psrad  xmm1 , 16                 ;xmm1  m7    m6    m5    m4
                      cvtdq2ps xmm0 , xmm0
                      cvtdq2ps xmm1 , xmm1
                      movdqu [rdi], xmm0
                      movdqu [rdi+16], xmm1
                      add    rsi , 16
                      add    rdi , 32
                      loop   .lp30
             .sk32:   and    eax , 7
                      xchg   eax , ecx
                      jz     .sk60
             .lp32:   xorps  xmm0 , xmm0               ;xmm0  -     -     -     -
                      pinsrw xmm0 , [rsi] , 1          ;xmm0  -     -     -  m0
                      psrad  xmm0 , 16                 ;xmm0  -     -     -     m0
                      cvtdq2ps xmm0 , xmm0
                      movss  [rdi], xmm0
                      add    rsi , 2
                      add    rdi , 4
                      loop   .lp32
                      jmp    .sk60

             .sk34:   mov    eax , ecx                 ;16b - stereo
                      shr    ecx , 2
                      jz     .sk36
             .lp34:   movdqu xmm0 , [rsi]              ;xmm0  r3 l3 r2 l2 r1 l1 r0 l0
                      movdqa xmm1 , xmm0               ;xmm1  r3 l3 r2 l2 r1 l1 r0 l0
                      punpcklwd xmm0 , xmm0            ;xmm0  r1 r1 l1 l1 r0 r0 l0 l0
                      punpckhwd xmm1 , xmm1            ;xmm1  r3 r3 l3 l3 r2 r2 l2 l2
                      psrad  xmm0 , 16                 ;xmm0  r1    l1    r0    l0
                      psrad  xmm1 , 16                 ;xmm1  r3    l3    r2    l2
                      shufps xmm0 ,xmm0 , 11011000b    ;xmm0  r1    r0    l1    l0
                      shufps xmm1 ,xmm1 , 11011000b    ;xmm1  r3    r2    l3    l2
                      andps  xmm0 ,xmm5                ;xmm0  r1m   r0m   l1m   l0m
                      andps  xmm1 ,xmm5                ;xmm1  r3m   r2m   l3m   l2m
                      movhlps xmm2, xmm0               ;xmm2  x     x     r1    r0
                      movhlps xmm3, xmm1               ;xmm3  x     x     r3    r2
                      orps   xmm0 , xmm2               ;xmm0  x     x     r1/l1 r0/l0
                      orps   xmm1 , xmm3               ;xmm1  x     x     r3/l3 r2/l2
                      movlhps xmm0 , xmm1              ;xmm0  r3/l3 r2/l2 r1/l1 r0/l0
                      cvtdq2ps xmm0, xmm0
                      movups [rdi], xmm0
                      add    rsi , 16
                      add    rdi , 16
                      loop   .lp34
             .sk36:   and    eax , 3
                      xchg   eax , ecx
                      jz     .sk60
             .lp36:   movd   xmm0 , [rsi]              ;xmm0  x     x     x     r0 l0
                      punpcklwd xmm0 , xmm0            ;xmm0  x     x     r0 r0 l0 l0
                      psrad  xmm0 , 16                 ;xmm0  x     x     r0    l0
                      punpckldq xmm0 , xmm0            ;xmm0  r0    r0    l0    l0
                      andps  xmm0 , xmm5               ;xmm0  r0m   r0m   l0m   l0m
                      movhlps xmm1, xmm0               ;xmm1  x     x     r0m   r0m
                      orps   xmm0 , xmm1
                      cvtdq2ps xmm0 , xmm0
                      movss  [rdi], xmm0
                      add    rsi , 4
                      add    rdi , 4
                      loop   .lp36
                      jmp    .sk60


             .sk40:   ;8-bit
                      test   al , 2                    ;8b - mono
                      jnz    .sk44
                      mov    eax , 128
                      cvtsi2ss xmm3 , eax
                      shufps xmm3 , xmm3 , 0
                      mov    eax , ecx
                      shr    ecx , 2
                      jz     .sk42
             .lp40:   movss  xmm0 , [rsi]              ;xmm0  - - - - - - - - - - - - 3 2 1 0
                      punpcklbw xmm0 , xmm0            ;xmm0  - - - - - - - - 3 3 2 2 1 1 0 0
                      punpcklwd xmm0 , xmm0            ;xmm0  3 3 3 3 2 2 2 2 1 1 1 1 0 0 0 0
                      psrld  xmm0 , 24                 ;xmm0        3       2       1       0
                      cvtdq2ps xmm0 , xmm0
                      subps  xmm0 , xmm3
                      movups [rdi], xmm0
                      add    rsi , 4
                      add    rdi , 16
                      loop   .lp40
             .sk42:   and    eax , 3
                      xchg   eax , ecx
                      jz     .sk60
             .lp42:   xor    eax , eax
                      lodsb
                      cvtsi2ss xmm0 , eax
                      subss  xmm0 , xmm3
                      movss  [rdi], xmm0
                      add    rdi , 4
                      loop   .lp42
                      jmp    .sk60

             .sk44:   mov    eax , 128                 ;8b - stereo
                      cvtsi2ss xmm3 , eax
                      shufps xmm3 , xmm3 , 0
                      mov    eax , ecx
                      shr    ecx , 2
                      jz     .sk46
             .lp44:   movss  xmm0 , [rsi]              ;xmm0  -- -- -- -- -- -- -- -- -- -- -- -- r1 l1 r0 l0
                      punpcklbw xmm0 , xmm0            ;xmm0  -- -- -- -- -- -- -- -- r1 r1 l1 l1 r0 r0 l0 l0
                      punpcklwd xmm0 , xmm0            ;xmm0  r1 r1 r1 r1 l1 l1 l1 l1 r0 r0 r0 r0 l0 l0 l0 l0
                      psrld  xmm0 , 24                 ;xmm0  -- -- -- r1 -- -- -- l1 -- -- -- r0 -- -- -- l0
                      shufps xmm0 , xmm0 , 11011000b   ;xmm0           r1          r0          l1          l0
                      andps  xmm0 , xmm5
                      movhlps xmm1, xmm0
                      orps   xmm1 , xmm0
                      cvtdq2ps xmm1 , xmm1
                      subps  xmm1 , xmm3
                      movups [rdi], xmm1
                      add    rsi , 4
                      add    rdi , 16
                      loop   .lp44
             .sk46:   and    eax , 3
                      xchg   eax , ecx
                      jz     .sk60
             .lp46:   xor    eax , eax
                      lodsb
                      cvtsi2ss xmm0 , eax
                      lodsb
                      cvtsi2ss xmm1 , eax
                      movlhps xmm0, xmm1
                      andps  xmm0 , xmm5
                      movhlps xmm1, xmm0
                      orps   xmm1 , xmm0
                      subss  xmm1 , xmm3
                      cvtss2si eax, xmm1
                      stosd
                      loop   .lp46

             .sk60:
                      xchg   rax , rsi
                      sub    rax , rdx

                      pop    rcx, rdx, rsi, rdi
                      ret
;------------------------------------------------------------------------------------




;------------------------------------------------------------------------------------
;CONVERT SAMPLES FROM INTERNAL FORMAT
;IN:   rcx - *in                                                      uses: xmm0-xmm5
;      rdx - *out
;      r8  -  number of samples  or zero
;      r9  -  out format
;
;OUT:  rax -  number of bytes written to "out"

sampconv_from_internal:
                      push   rdi, rsi, rdx, rcx

                      xchg   rcx , rsi                 ;rsi - *in
                      xchg   rdx , rdi                 ;rdi - *out
                      mov    rdx , rdi
                      mov    rcx , r8                  ;rcx -  number of samples
                      test   rcx , rcx
                      jz     .sk60
                      mov    rax , r9                  ;rax -  in format
                      and    eax , 8+4+1

                      push   r15
                      mov    r15 , sampconv_LR_mask32
                      movlps xmm4 , qword [r15 + rax*8]
                      movlps xmm5 , qword [r15 + rax*8 + 16]
                      mov    r15 , sampconv_xmm2
                      movaps xmm2 , [r15]
                      movaps xmm3 , [r15 + 16]
                      pop    r15

                      movlhps xmm4 , xmm4
                      movlhps xmm5 , xmm5
                      mov    rax , r9
                      test   al  , 4
                      jnz    .sk40
                      test   al  , 8
                      jnz    .sk30
                      test   al  , 16
                      jnz    .sk20


             .sk10:   ;32bit float
                      test   al  , 2                   ;32b float - mono
                      jnz    .sk14
                      mov    eax , ecx
                      shr    ecx , 2
                      jz     .sk12
             .lp10:   movups xmm0 , [rsi]              ;xmm0  x3    x2    x1    x0
                      add    rsi , 16
                      movups [rdi], xmm0
                      add    rdi , 16
                      loop   .lp10
             .sk12:   and    eax , 3
                      xchg   eax , ecx
                      rep movsd
                      jmp    .sk60

             .sk14:   mov    eax , ecx                 ;32b float - stereo
                      shr    ecx , 2
                      jz     .sk16
             .lp14:   movups xmm0 , [rsi]              ;xmm0  x3    x2    x1    x0
                      movhlps xmm1 , xmm0              ;xmm1  x     x     x3    x2
                      unpcklps xmm0 , xmm0             ;xmm0  x1    x1    x0    x0
                      unpcklps xmm1 , xmm1             ;xmm1  x3    x3    x2    x2
                      movups xmm2 , [rdi]              ;xmm2  R1    L1    R0    L0
                      movups xmm3 , [rdi+16]           ;xmm3  R3    L3    R2    L2
                      andps  xmm0 , xmm4
                      andps  xmm1 , xmm4
                      andps  xmm2 , xmm5
                      andps  xmm3 , xmm5
                      orps   xmm0 , xmm2
                      orps   xmm1 , xmm3
                      movups [rdi], xmm0
                      movups [rdi+16], xmm1
                      add    rsi , 16
                      add    rdi , 32
                      loop   .lp14
             .sk16:   and    eax , 3
                      xchg   eax , ecx
                      jz     .sk60
             .lp16:   movss  xmm0 , [rsi]              ;xmm0  x     x     x     x0
                      unpcklps xmm0 , xmm0             ;xmm0  x     x     x0    x0
                      movlps xmm2 , [rdi]              ;xmm2  x     x     R0    L0
                      andps  xmm0 , xmm4
                      andps  xmm2 , xmm5
                      orps   xmm0 , xmm2
                      movlps [rdi], xmm0
                      add    rsi , 4
                      add    rdi , 8
                      loop   .lp16
                      jmp    .sk60


             .sk20:   ;32bit
                      test   al  , 2                   ;32b - mono
                      jnz    .sk24
                      mov    eax , ecx
                      shr    ecx , 2
                      jz     .sk22
             .lp20:   movups xmm0 , [rsi]              ;xmm0  x3    x2    x1    x0
                      maxps  xmm0 , xmm2
                      minps  xmm0 , xmm3
                      add    rsi , 16
                      cvtps2dq xmm0 , xmm0
                      movdqu [rdi], xmm0
                      add    rdi , 16
                      loop   .lp20
             .sk22:   and    eax , 3
                      xchg   eax , ecx
                      jz     .sk60
             .lp22:   movss  xmm0 , [rsi]
                      add    rsi , 4
                      maxss  xmm0 , xmm2
                      minss  xmm0 , xmm3
                      cvtss2si eax , xmm0
                      stosd
                      loop   .lp22
                      jmp    .sk60

             .sk24:   mov    eax , ecx                 ;32b - stereo
                      shr    ecx , 2
                      jz     .sk26
             .lp24:   movups xmm0 , [rsi]              ;xmm0  x3    x2    x1    x0
                      maxps  xmm0 , xmm2
                      minps  xmm0 , xmm3
                      cvtps2dq xmm0 , xmm0
                      unpcklps xmm0 , xmm0             ;xmm0  x1    x1    x0    x0
                      andps  xmm0 , xmm4
                      movdqu xmm1 , [rdi]              ;xmm1  R1    L1    R0    L0
                      andps  xmm1 , xmm5
                      orps   xmm1 , xmm0
                      movdqu [rdi], xmm1
                      movups xmm0 , [rsi]              ;xmm0  x3    x2    x1    x0
                      maxps  xmm0 , xmm2
                      minps  xmm0 , xmm3
                      cvtps2dq xmm0 , xmm0
                      unpckhps xmm0 , xmm0             ;xmm0  x3    x3    x2    x2
                      andps  xmm0 , xmm4
                      movdqu xmm1 , [rdi + 16]         ;xmm1  R3    L3    R2    L2
                      andps  xmm1 , xmm5
                      orps   xmm1 , xmm0
                      movdqu [rdi + 16], xmm1
                      add    rsi , 16
                      add    rdi , 32
                      loop   .lp24
             .sk26:   and    eax , 3
                      xchg   eax , ecx
                      jz     .sk60
             .lp26:   movss  xmm0 , [rsi]              ;xmm0  x     x     x     x0
                      maxss  xmm0 , xmm2
                      minss  xmm0 , xmm3
                      unpcklps xmm0 , xmm0             ;xmm0  x     x     x0    x0
                      movlps xmm1 , [rdi]              ;xmm2  x     x     R0    L0
                      andps  xmm0 , xmm4
                      andps  xmm1 , xmm5
                      orps   xmm1 , xmm0
                      movlps [rdi], xmm1
                      add    rsi , 4
                      add    rdi , 8
                      loop   .lp26
                      jmp    .sk60


             .sk30:   ;16bit
                      test   al  , 2                   ;16b - mono
                      jnz    .sk34
                      mov    eax , ecx
                      shr    ecx , 2
                      jz     .sk32
             .lp30:   movups xmm0 , [rsi]              ;xmm0  m3    m2    m1    m0
                      cvtps2dq xmm0 , xmm0
                      packssdw xmm0 , xmm0             ;xmm0  m3 m2 m1 m0 m3 m2 m1 m0
                      movq   [rdi], xmm0
                      add    rsi , 16
                      add    rdi , 8
                      loop   .lp30
             .sk32:   and    eax , 3
                      xchg   eax , ecx
                      jz     .sk60
             .lp32:   movss  xmm0 , [rsi]              ;xmm0  x     x     x     x0
                      add    rsi , 4
                      cvtps2dq xmm0 , xmm0
                      packssdw xmm0 , xmm0             ;xmm0  x  x  x  x0 x  x  x  x0
                      movd   eax , xmm0
                      stosw
                      loop   .lp32
                      jmp    .sk60

             .sk34:   mov    eax , ecx                 ;16b - stereo
                      shr    ecx , 2
                      jz     .sk36
             .lp34:   movups xmm0 , [rsi]              ;xmm0  x3    x2    x1    x0
                      cvtps2dq xmm0 , xmm0
                      packssdw xmm0 , xmm0             ;xmm0  x3 x2 x1 x0 x3 x2 x1 x0
                      punpcklwd xmm0, xmm0             ;xmm0  x3 x3 x2 x2 x1 x1 x0 x0
                      movdqu xmm2 , [rdi]              ;xmm1  R3 L3 R2 L2 R1 L1 R0 L0
                      pand   xmm0 , xmm4
                      pand   xmm2 , xmm5
                      por    xmm0 , xmm2
                      movdqu [rdi], xmm0
                      add    rsi , 16
                      add    rdi , 16
                      loop   .lp34
             .sk36:   and    eax , 3
                      xchg   eax , ecx
                      jz     .sk60
             .lp36:   movss  xmm0 , [rsi]              ;xmm0  x     x     x     x0
                      unpcklps xmm0 , xmm0             ;xmm0  x     x     x0    x0
                      cvtps2dq xmm0 , xmm0
                      packssdw xmm0 , xmm0             ;xmm0  x  x  x0 x0 x  x  x0 x0
                      movd   xmm2 , [rdi]              ;xmm2  x     x     x     R0 L0
                      pand   xmm0 , xmm4
                      pand   xmm2 , xmm5
                      por    xmm0 , xmm2
                      movd   [rdi], xmm0
                      add    rsi , 4
                      add    rdi , 4
                      loop   .lp36
                      jmp    .sk60


             .sk40:   ;8-bit
                      test   al  , 2                   ;8b - mono
                      jnz    .sk44
                      mov    eax , 128
                      cvtsi2ss xmm3 , eax
                      shufps xmm3 , xmm3 , 0
                      mov    eax , ecx
                      shr    ecx , 2
                      jz     .sk42
             .lp40:   movups xmm0 , [rsi]              ;xmm0  m3    m2    m1    m0
                      addps  xmm0 , xmm3
                      cvtps2dq xmm0 , xmm0
                      packssdw xmm0 , xmm0             ;xmm0  m3 m2 m1 m0 m3 m2 m1 m0
                      packuswb xmm0 , xmm0             ;xmm0  3 2 1 0 3 2 1 0 3 2 1 0 3 2 1 0
                      movd   [rdi], xmm0
                      add    rsi , 16
                      add    rdi , 4
                      loop   .lp40
             .sk42:   and    eax , 3
                      xchg   eax , ecx
                      jz     .sk60
             .lp42:   movss  xmm0 , [rsi]              ;xmm0  x     x     x     x0
                      addss  xmm0 , xmm3
                      cvtps2dq xmm0 , xmm0
                      packssdw xmm0 , xmm0             ;xmm0  x  x  x  x0 x  x  x  x0
                      packuswb xmm0 , xmm0             ;xmm0  x x x x0 x x x x0 x x x x0 x x x x0
                      movd   eax , xmm0
                      add    rsi , 4
                      stosb
                      loop   .lp42
                      jmp    .sk60

             .sk44:   mov    eax , ecx                 ;8b - stereo
                      shr    ecx , 2
                      jz     .sk46
             .lp44:   movups xmm0 , [rsi]              ;xmm0  x3    x2    x1    x0
                      addps  xmm0 , xmm3
                      cvtps2dq xmm0 , xmm0
                      packssdw xmm0 , xmm0             ;xmm0  x3 x2 x1 x0 x3 x2 x1 x0
                      packuswb xmm0 , xmm0             ;xmm0  3 2 1 0 3 2 1 0 3 2 1 0 3 2 1 0
                      punpcklbw xmm0, xmm0             ;xmm0  3 3 2 2 1 1 0 0 3 3 2 2 1 1 0 0
                      movq   xmm2 , [rdi]              ;xmm2  - - - - - - - - r l r l r l r l
                      pand   xmm0 , xmm4
                      pand   xmm2 , xmm5
                      por    xmm2 , xmm0
                      movq   [rdi], xmm2
                      add    rsi , 16
                      add    rdi , 8
                      loop   .lp44
             .sk46:   and    eax , 3
                      xchg   eax , ecx
                      jz     .sk60
             .lp46:   movss  xmm0 , [rsi]              ;xmm0  x     x     x     x0
                      addss  xmm0 , xmm3
                      unpcklps xmm0 , xmm0             ;xmm0  x     x     x0    x0
                      cvtps2dq xmm0 , xmm0
                      packssdw xmm0 , xmm0             ;xmm0  x  x  x0 x0 x  x  x0 x0
                      packuswb xmm0 , xmm0             ;xmm0  x x y y x x y y x x y y x x y y
                      pinsrw xmm2 , [rdi],0            ;xmm2  - - - - - - - - - - - - - - z z
                      pand   xmm0 , xmm4
                      pand   xmm2 , xmm5
                      por    xmm2 , xmm0
                      movd   eax , xmm2
                      stosw
                      add    rsi , 4
                      add    rdi , 2
                      loop   .lp46

              .sk60:
                      xchg   rax , rdi
                      sub    rax , rdx

                      pop    rcx, rdx, rsi, rdi
                      ret
;------------------------------------------------------------------------------------




;------------------------------------------------------------------------------------
align 16

sampconv_xmm2       dd -2147483904.0, -2147483904.0, -2147483904.0, -2147483904.0
sampconv_xmm3       dd  2147483392.0,  2147483392.0,  2147483392.0,  2147483392.0

sampconv_LR_mask32  dd  -1, 0,         0,-1        ;stereo masks
                    dd   0, 0,        -1, 0
sampconv_LR_mask8   db  -1, 0,-1, 0,-1, 0,-1, 0,   0,-1, 0,-1, 0,-1, 0,-1
                    db   0, 0, 0, 0, 0, 0, 0, 0,  -1, 0,-1, 0,-1, 0,-1, 0
sampconv_LR_mask16  dw  -1, 0,-1, 0,   0,-1, 0,-1
                    dw   0, 0, 0, 0,  -1, 0,-1, 0

;------------------------------------------------------------------------------------
















