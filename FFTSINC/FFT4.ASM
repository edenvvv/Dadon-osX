
; COPYRIGHT (C) 2010 Akos Mogyorosi <flowwolf>
; FOR DETAILS SEE THE FILE README

; COMPLEX TO COMPLEX "IN-PLACE" FFT (RADIX-4 DECIMATION IN TIME DECOMPOSITION)

; NOTE:  - decomposition stops at 8- and 16-point FFTs
;        - had taken a look at the pfftw library by Matteo Frigo; codelets are not
;          abstracted or rewritten, only the decomposition had been analysed
;        - "in-place" is currently out-of-place, an auxiliary buffer and
;          permutation tables are used to reorder data
;        - auxiliary buffers can be used for speed-up processing
;          i.e. the user can give a separate auxiliary buffer for each fft4 process

; 12/07/2010:  fixed auxiliary buffer for multi-threading


;global fft4_create
;global fft4_destroy
;global fft4
;global ifft4
                                                                 ;flowwolf 16/05/2010
;------------------------------------------------------------------------------------
;CREATE FFT4 TABLE
;IN:   rcx -  n (max length 2^n)                                              uses: -
;
;OUT:  rax - *table or zero

fft4_create:
                      push   r10, r9, r8, rdi, rsi, rbx, rdx, rcx

                      mov    edx , ecx    ;rdx -  n
                      xor    eax , eax
                      inc    eax
                      shl    eax , cl
                      mov    r8  , rax
                      shr    r8  , 2      ;r8  -  2^(n-2)
                      shl    eax , 3 + 1
                      add    eax , 16 + 4
                      xchg   eax , ecx

                      call   memalloc

                      test   rax , rax
                      jz     .err


                      mov    r9  , rax
                      mov    [rax], edx
                      add    rax , 4
                      test   al  , 15
                      jz     .sk00
                      and    al  , 15 xor -1
                      add    rax , 16
             .sk00:

                      sub    rsp , 128
                      fnsave [rsp]
                      fninit

                      push   r8
                      fild   Q [rsp]
                      pop    r8

                      xor    ecx , ecx    ;create radix-4 decomposition table
             .lp10:   push   rcx
                      fild   Q [rsp]
                      pop    rcx
                      fdiv   st0 , st1
                      fldpi
                      fmulp  st1 , st0
                      fld1
                      fadd   st0 , st0
                      fdivr  st0 , st1
                      fsincos
                      shl    ecx , 5
                      fstp   Q [rax + rcx]
                      fstp   Q [rax + rcx + 8]
                      fsincos
                      fstp   Q [rax + rcx + 16]
                      fstp   Q [rax + rcx + 24]
                      shr    ecx , 5
                      inc    ecx
                      cmp    rcx , r8
                      jnz    .lp10
                      fcomp  st0

                      shl    r8  , 2      ;create permutation tables
                      lea    rdi , [rax + r8*8]
             .lp20:   xor    ecx , ecx
             .lp22:   mov    edx , ecx
                      xor    r10 , r10
                      mov    rsi , r8
             .lp24:   shr    rsi , 2
                      mov    eax , edx
                      and    eax , 3
                      mov    ebx , edx
                      shr    ebx , 2
                      lea    edx , [ebx + 1]
                      dec    esi
                      and    edx , esi
                      inc    esi
                      cmp    al  , 3
                      cmovnz edx , ebx
                      imul   eax , esi
                      add    r10 , rax
                      cmp    esi , 4
                      jnbe   .lp24
                      mov    rax , r10
                      add    rax , rdx
                      stosd
                      inc    ecx
                      cmp    rcx , r8
                      jnz    .lp22
                      shr    r8  , 1
                      cmp    r8  , 1
                      jnz    .lp20
                      sub    rdi , 4
                      inc    eax
                      stosd
                      stosd

                      frstor [rsp]
                      add    rsp , 128
                      xchg   rax , r9
              .err:

                      pop    rcx, rdx, rbx, rsi, rdi, r8, r9, r10
                      ret
;------------------------------------------------------------------------------------




;------------------------------------------------------------------------------------
;DESTROY FFT4 TABLE
;IN:   rcx - *table                                                           uses: -

fft4_destroy:
                      push   rax

                      call   memfree

                      pop    rax
                      ret
;------------------------------------------------------------------------------------




;------------------------------------------------------------------------------------
;COMPLEX TO COMPLEX IN-PLACE forward FFT (RADIX-4 DECIMATION IN TIME)
;IN:   rcx -  n    (length 2^n)                                      uses: xmm0-xmm15
;      rdx - *RI   (interleaved real & imaginary array, double)
;      r8  - *fft4 table
;      r9  - *aux buffer (16-byte aligned  length (2^n)*16 )  or zero
;
;OUT:  RI
;
;NOTE: RI must be aligned on a 16-byte boundary
;
;      elements of RI must be divided by 2^n before calling ifft4

fft4:
                      push   r11, r10, r9, r8, rdx, rcx, rax

                      xor    r10 , r10
                      call   fft4_core

                      pop    rax, rcx, rdx, r8, r9, r10, r11
                      ret
;------------------------------------------------------------------------------------




;------------------------------------------------------------------------------------
;COMPLEX TO COMPLEX IN-PLACE inverse FFT (RADIX-4 DECIMATION IN TIME)
;IN:   rcx -  n    (length 2^n)                                      uses: xmm0-xmm15
;      rdx - *RI   (interleaved real & imaginary array, double)
;      r8  - *fft4 table
;      r9  - *aux buffer (16-byte aligned  length (2^n)*16 )  or zero
;
;OUT:  RI
;
;NOTE: RI must be aligned on a 16-byte boundary

ifft4:
                      push   r11, r10, r9, r8, rdx, rcx, rax

                      xor    r10 , r10
                      inc    r10
                      call   fft4_core

                      pop    rax, rcx, rdx, r8, r9, r10, r11
                      ret
;------------------------------------------------------------------------------------




;------------------------------------------------------------------------------------
;COMPLEX TO COMPLEX IN-PLACE FFT/IFFT (RADIX-4 DECIMATION IN TIME)
;IN:   rcx -  n    (length 2^n)                                      uses: xmm0-xmm15
;      rdx - *RI   (interleaved real & imaginary array, double)
;      r8  - *fft4 table
;      r9  - *aux buffer (16-byte aligned  length (2^n)*16 )  or zero
;      r10 -  0/1  (fft/ifft)
;
;OUT:  RI
;
;NOTE: RI must be aligned on a 16-byte boundary

fft4_core:
                      push   rbp, r15, r14, r13, r12, rdi, rsi, rbx

                      xchg   r9  , r14      ;r14 - *aux buffer  or zero
                      xchg   r10 , r12      ;r12 -  0/1  (fft/ifft)
                      xor    eax , eax
                      inc    eax
                      mov    r9  , rax
                      mov    r13 , rax
                      shl    eax , cl       ;eax -  1<<n
                      mov    esi , ecx      ;esi -  n
                      sub    ecx , [r8]
                      neg    ecx
                      shl    r9  , cl       ;r9  -  1<<(maxlength-n)
                      shl    r9  , 5
                      shl    rax , 2
                      mov    ecx , [r8]
                      shl    r13 , cl       ;r13 -  1<<maxlength
                      xchg   rax , rcx      ;rcx -  1<<(n+2)
                      xchg   rdx , r11      ;r11 -  *RI
                      xchg   rbx , r8       ;rbx -  *fft4 table
                      add    rbx , 4
                      test   bl  , 15
                      jz     .sk00
                      and    bl  , 15 xor -1
                      add    rbx , 16
             .sk00:   lea    r10 , [r11 + rcx*4]

                      test   r14 , r14      ;allocate aux buffer
                      jnz    .sk10
                      push   rcx
                      shl    rcx , 2
                      add    rcx , 16 + 16
                      call   memalloc
                      pop    rcx
                      test   rax , rax
                      jz     .sk60
                      xchg   rax , rbp
             .sk10:
                      cmp    esi , 4
                      jnbe   .sk20
                      test   esi , esi
                      jz     .sk60
                      mov    rax , FFT4_CALL
                      mov    rax , [rax + rsi*8 - 8]
                      mov    rsi , r11
                      mov    rdi , rbp
                      and    rdi , 15 xor -1
                      add    rdi , 16
                      test   r14 , r14
                      cmovnz rdi , r14

                      mov    rdx , r12
                      call   rax
                      jmp    .sk40
             .sk20:
                      shl    r12 , 4
                      mov    rax , FFT4_XORL
                      movapd xmm8 , dqword [rax + r12]
                      movlhps xmm9 , xmm8
                      movhlps xmm9 , xmm8
                      shr    r12 , 4

                      ;radix-4 DIT decomposition

                      ; cosa*sinb + sina*cosb   = add, sin  (linear frequency shifting; where a,b are frequencies)
                      ; cosa*sinb - sina*cosb   = sub,-sin
                      ;-cosa*sinb + sina*cosb   = sub, sin
                      ;-cosa*sinb - sina*cosb   = add,-sin
                      ; cosa*cosb + sina*sinb   = sub, cos
                      ; cosa*cosb - sina*sinb   = add, cos
                      ;-cosa*cosb + sina*sinb   = add,-cos
                      ;-cosa*cosb - sina*sinb   = sub,-cos

                      ;DFT:    R2 =   cos*R1 - sin*I1
                      ;        I2 =   sin*R1 + cos*I1

                      ;a b c d e f g h i j k l m n o p  (real)      example 16-points:
                      ;A B C D E F G H I J K L M N O P  (imaginary)

                      ;0:  a + e + i + m                                     A + E + I + M
                      ;4:  ((a-i) + (E-M))*cos0  +  ((A-I) - (e-m))*sin0     ((A-I) - (e-m))*cos0  -  ((a-i) + (E-M))*sin0
                      ;8:  (a - e + i - m)*cos1  +  (A - E + I - M)*sin1     (A - E + I - M)*cos1  -  (a - e + i - m)*sin1
                      ;12: ((a-i) - (E-M))*cos0  -  ((A-I) + (e-m))*sin0     ((A-I) + (e-m))*cos0  +  ((a-i) - (E-M))*sin0

                      ;where cos0,sin0 (0.5pi) and cos1,sin1 (1pi) are the radix-4 decomposition tables

                      ;n/4 * 13  SIMD additions
                      ;n/4 * 6   SIMD multiplications
                      ;n/4 * 4+5 SIMD shuffles and xors
                      ;n/4 * 8+2 memory accesses
             .lp20:
                      mov    rsi , r11
             .lp22:
                      xor    eax , eax
                      mov    edx , ecx
                      lea    rdi , [rsi + rcx*2]
                      xor    r8  , r8
             .lp24:
                      movapd xmm0 , [rsi + rax]        ;xmm0  A                     a
                      movapd xmm1 , [rsi + rdx]        ;xmm1  E                     e
                      movapd xmm2 , [rdi + rax]        ;xmm2  I                     i
                      movapd xmm3 , [rdi + rdx]        ;xmm3  M                     m
                      movapd xmm4 , xmm0
                      addpd  xmm4 , xmm1
                      addpd  xmm4 , xmm2
                      addpd  xmm4 , xmm3               ;xmm4  A+E+I+M               a+e+i+m
                      movapd [rsi + rax], xmm4
                      movapd xmm4 , xmm0
                      subpd  xmm4 , xmm2               ;xmm4  A-I                   a-i
                      movapd xmm5 , xmm1
                      subpd  xmm5 , xmm3               ;xmm5  E-M                   e-m
                      shufpd xmm5 , xmm5 , 01b         ;xmm5  e-m                   E-M
                      movapd xmm6 , xmm5               ;xmm6  e-m                   E-M
                      xorpd  xmm6 , xmm8               ;xmm6  e-m                   -(E-M)
                      xorpd  xmm5 , xmm9               ;xmm5  -(e-m)                E-M
                      movapd xmm7 , xmm0
                      subpd  xmm7 , xmm1
                      addpd  xmm7 , xmm2
                      subpd  xmm7 , xmm3               ;xmm7  A-E+I-M               a-e+i-m
                      movapd xmm2 , [rbx + r8]         ;xmm2  sin0                  cos0
                      movapd xmm3 , xmm2               ;xmm3                        cos0
                      movlhps xmm3 , xmm3              ;xmm3  cos0                  cos0
                      movhlps xmm2 , xmm2              ;xmm2  sin0                  sin0
                      movapd xmm0 , xmm4               ;xmm0  A-I                   a-i
                      addpd  xmm0 , xmm5               ;xmm0  (A-I)-(e-m)           (a-i)+(E-M)
                      movapd xmm1 , xmm0               ;xmm1  (A-I)-(e-m)           (a-i)+(E-M)
                      mulpd  xmm1 , xmm2               ;xmm1  ((A-I)-(e-m))*sin0    ((a-i)+(E-M))*sin0
                      xorpd  xmm1 , xmm8               ;xmm1  ((A-I)-(e-m))*sin0   -((a-i)+(E-M))*sin0
                      shufpd xmm1 , xmm1 , 01b         ;xmm1 -((a-i)+(E-M))*sin0    ((A-I)-(e-m))*sin0
                      mulpd  xmm0 , xmm3               ;xmm0  ((A-I)-(e-m))*cos0    ((a-i)+(E-M))*cos0
                      addpd  xmm0 , xmm1               ;xmm0  ((A-I)-(e-m))*cos0 - ((a-i)+(E-M))*sin0    ((a-i)+(E-M))*cos0 + ((A-I)-(e-m))*sin0
                      movapd [rsi + rdx], xmm0
                      movapd xmm0 , xmm4               ;xmm0  A-I                   a-i
                      subpd  xmm0 , xmm5               ;xmm0  (A-I)+(e-m)           (a-i)-(E-M)
                      movapd xmm1 , xmm0               ;xmm1  (A-I)+(e-m)           (a-i)-(E-M)
                      mulpd  xmm1 , xmm2               ;xmm1  ((A-I)+(e-m))*sin0    ((a-i)-(E-M))*sin0
                      xorpd  xmm1 , xmm8               ;xmm1  ((A-I)+(e-m))*sin0   -((a-i)-(E-M))*sin0
                      shufpd xmm1 , xmm1 , 01b         ;xmm1 -((a-i)-(E-M))*sin0    ((A-I)+(e-m))*sin0
                      mulpd  xmm0 , xmm3               ;xmm0  ((A-I)+(e-m))*cos0    ((a-i)-(E-M))*cos0
                      subpd  xmm0 , xmm1               ;xmm0  ((A-I)+(e-m))*cos0 + ((a-i)-(E-M))*sin0    ((a-i)-(E-M))*cos0 - ((A-I)+(e-m))*sin0
                      movapd [rdi + rdx], xmm0
                      movapd xmm2 , [rbx + r8 + 16]    ;xmm2  sin1                  cos1
                      movapd xmm3 , xmm2               ;xmm3                        cos1
                      movlhps xmm3 , xmm3              ;xmm3  cos1                  cos1
                      movhlps xmm2 , xmm2              ;xmm2  sin1                  sin1
                      movapd xmm0 , xmm7               ;xmm0  A-E+I-M               a-e+i-m
                      shufpd xmm0 , xmm0 , 01b         ;xmm0  a-e+i-m               A-E+I-M
                      mulpd  xmm7 , xmm3               ;xmm7  (A-E+I-M)*cos1        (a-e+i-m)*cos1
                      mulpd  xmm0 , xmm2               ;xmm0  (a-e+i-m)*sin1        (A-E+I-M)*sin1
                      xorpd  xmm0 , xmm9               ;xmm0 -(a-e+i-m)*sin1        (A-E+I-M)*sin1
                      addpd  xmm0 , xmm7               ;xmm0  (A-E+I-M)*cos1 - (a-e+i-m)*sin1     (a-e+i-m)*cos1 + (A-E+I-M)*sin1
                      movapd [rdi + rax], xmm0
                      add    r8  , r9
                      add    edx , 16
                      add    eax , 16
                      cmp    eax , ecx
                      jnz    .lp24

                      lea    rsi , [rsi + rcx*4]
                      cmp    rsi , r10
                      jnz    .lp22

                      shl    r9  , 2
                      shr    ecx , 2
                      cmp    ecx , 4*16
                      jnbe   .lp20


                      ;8- or 16-point FFTs
                      setz   cl
                      mov    rax , FFT4_CALL
                      mov    rax , [rax + rcx*8 + 16]
                      mov    rdx , r12
                      mov    rsi , r11
                      mov    rdi , rbp
                      and    rdi , 15 xor -1
                      add    rdi , 16
                      test   r14 , r14
                      cmovnz rdi , r14
                      call   rax


                      ;permutation
             .sk40:   mov    rsi , rbp
                      and    rsi , 15 xor -1
                      add    rsi , 16
                      test   r14 , r14
                      cmovnz rsi , r14
                      mov    rdi , r11
                      lea    rbx , [rbx + r13*8]
                      mov    rax , r10
                      sub    rax , r11
                      shr    rax , 4
             .lp42:   cmp    rax , r13
                      jz     .lp40
                      lea    rbx , [rbx + r13*4]
                      shr    r13 , 1
                      jnz    .lp42
             .lp40:   mov    eax , [rbx]
                      shl    eax , 4
                      movapd xmm0 , [rsi + rax]
                      movapd [rdi], xmm0
                      add    rbx , 4
                      add    rdi , 16
                      cmp    rdi , r10
                      jnz    .lp40
             .sk60:

                      test   r14 , r14      ;free aux buffer
                      jnz    .sk62
                      mov    rcx , rbp
                      call   memfree
             .sk62:

                      pop    rbx, rsi, rdi, r12, r13, r14, r15, rbp
                      ret
;------------------------------------------------------------------------------------




;_fft16
;_fft8
;_fft4
;_fft2

;------------------------------------------------------------------------------------
;16-POINT FFTs  (USES RADIX-4 DIT TO DECOMPOSE THE 16-POINT FFT INTO 4-POINT FFTs)
;IN:   rdx -  0/1  (fft/ifft)                                        uses: xmm0-xmm15
;      rsi - *RI
;      rdi - *RI aux
;      r10 - *RI + (2^n)*16
;
;OUT:  RI

_fft16:
                      shl    rdx , 4
                      mov    rax , FFT4_XORL
                      movapd xmm12 , dqword [rax + rdx]
                      movapd xmm13 , dqword [FFT4_0_38]
                      movapd xmm14 , dqword [FFT4_0_70]
                      movapd xmm15 , dqword [FFT4_0_92]

                      ;n/16 * 72  SIMD additions
                      ;n/16 * 12  SIMD multiplications
                      ;n/16 * 10 + 17 SIMD shuffles and xors
                      ;n/16 * 64  memory accesses
             .lp10:
                      ;0:  a + e + i + m                                     A + E + I + M
                      ;4:  ((a-i) + (E-M))*1     +  ((A-I) - (e-m))*0        ((A-I) - (e-m))*1     -  ((a-i) + (E-M))*0
                      ;8:  (a - e + i - m)*1     +  (A - E + I - M)*0        (A - E + I - M)*1     -  (a - e + i - m)*0
                      ;13: ((a-i) - (E-M))*1     -  ((A-I) + (e-m))*0        ((A-I) + (e-m))*1     +  ((a-i) - (E-M))*0

                      ;1:  a + e + i + m                                     A + E + I + M
                      ;5:  ((a-i) + (E-M))*0.92  +  ((A-I) - (e-m))*0.38     ((A-I) - (e-m))*0.92  -  ((a-i) + (E-M))*0.38
                      ;9:  (a - e + i - m)*0.7   +  (A - E + I - M)*0.7      (A - E + I - M)*0.7   -  (a - e + i - m)*0.7
                      ;14: ((a-i) - (E-M))*0.92  -  ((A-I) + (e-m))*0.38     ((A-I) + (e-m))*0.92  +  ((a-i) - (E-M))*0.38

                      ;2:  a + e + i + m                                     A + E + I + M
                      ;6:  ((a-i) + (E-M))*0.7   +  ((A-I) - (e-m))*0.7      ((A-I) - (e-m))*0.7   -  ((a-i) + (E-M))*0.7
                      ;10: (a - e + i - m)*0     +  (A - E + I - M)*1        (A - E + I - M)*0     -  (a - e + i - m)*1
                      ;15: ((a-i) - (E-M))*0.7   -  ((A-I) + (e-m))*0.7      ((A-I) + (e-m))*0.7   +  ((a-i) - (E-M))*0.7

                      ;3:  a + e + i + m                                     A + E + I + M
                      ;7:  ((a-i) + (E-M))*0.38  +  ((A-I) - (e-m))*0.92     ((A-I) - (e-m))*0.38  -  ((a-i) + (E-M))*0.92
                      ;11: (a - e + i - m)*-0.7  +  (A - E + I - M)*0.7      (A - E + I - M)*-0.7  -  (a - e + i - m)*0.7
                      ;12: ((a-i) - (E-M))*0.38  -  ((A-I) + (e-m))*0.92     ((A-I) + (e-m))*0.38  +  ((a-i) - (E-M))*0.92

                      ;radix-4 DIT decomposition
                      movapd xmm0 , [rsi]              ;xmm0  A                     a
                      movapd xmm1 , [rsi + 64]         ;xmm1  E                     e
                      movapd xmm2 , [rsi + 128]        ;xmm2  I                     i
                      movapd xmm3 , [rsi + 192]        ;xmm3  M                     m
                      movapd xmm4 , xmm0
                      addpd  xmm4 , xmm2               ;xmm4  A+I                   a+i
                      movapd xmm5 , xmm1
                      addpd  xmm5 , xmm3               ;xmm5  E+M                   e+m
                      subpd  xmm0 , xmm2               ;xmm0  A-I                   a-i
                      subpd  xmm1 , xmm3               ;xmm1  E-M                   e-m
                      shufpd xmm1 , xmm1, 01b          ;xmm1  e-m                   E-M
                      xorpd  xmm1 , xmm12              ;xmm1  e-m                   -(E-M)
                      movapd xmm2 , xmm4
                      subpd  xmm2 , xmm5               ;xmm2  A+I-E-M               a+i-e-m
                      addpd  xmm4 , xmm5               ;xmm4  A+I+E+M               a+i+e+m
                      movapd xmm3 , xmm0
                      addpd  xmm3 , xmm1               ;xmm3  (A-I)+(e-m)           (a-i)-(E-M)
                      subpd  xmm0 , xmm1               ;xmm0  (A-I)-(e-m)           (a-i)+(E-M)
                      movapd [rsi], xmm4
                      movapd [rsi + 64], xmm0
                      movapd [rsi + 128], xmm2
                      movapd [rsi + 192], xmm3
                      movapd xmm0 , [rsi + 16]         ;xmm0  A                     a
                      movapd xmm1 , [rsi + 64 + 16]    ;xmm1  E                     e
                      movapd xmm2 , [rsi + 128 + 16]   ;xmm2  I                     i
                      movapd xmm3 , [rsi + 192 + 16]   ;xmm3  M                     m
                      movapd xmm4 , xmm0
                      addpd  xmm4 , xmm2               ;xmm4  A+I                   a+i
                      movapd xmm5 , xmm1
                      addpd  xmm5 , xmm3               ;xmm5  E+M                   e+m
                      subpd  xmm0 , xmm2               ;xmm0  A-I                   a-i
                      subpd  xmm1 , xmm3               ;xmm1  E-M                   e-m
                      shufpd xmm1 , xmm1, 01b          ;xmm1  e-m                   E-M
                      xorpd  xmm1 , xmm12              ;xmm1  e-m                   -(E-M)
                      movapd xmm2 , xmm4
                      subpd  xmm2 , xmm5               ;xmm2  A+I-E-M               a+i-e-m
                      mulpd  xmm2 , xmm14              ;xmm2  0.7(A+I-E-M)          0.7(a+i-e-m)
                      addpd  xmm4 , xmm5               ;xmm4  A+I+E+M               a+i+e+m
                      movapd xmm3 , xmm0
                      addpd  xmm3 , xmm1               ;xmm3  (A-I)+(e-m)           (a-i)-(E-M)
                      subpd  xmm0 , xmm1               ;xmm0  (A-I)-(e-m)           (a-i)+(E-M)
                      movlhps xmm1, xmm3
                      movhlps xmm1, xmm3               ;xmm1  (a-i)-(E-M)           (A-I)+(e-m)
                      xorpd   xmm1, xmm12              ;xmm1  (a-i)-(E-M)          -((A-I)+(e-m))
                      movlhps xmm5, xmm0
                      movhlps xmm5, xmm0               ;xmm5  (a-i)+(E-M)           (A-I)-(e-m)
                      xorpd   xmm5, xmm12              ;xmm5  (a-i)+(E-M)          -((A-I)-(e-m))
                      mulpd  xmm3 , xmm15              ;xmm3  0.92((A-I)+(e-m))     0.92((a-i)-(E-M))
                      mulpd  xmm0 , xmm15              ;xmm0  0.92((A-I)-(e-m))     0.92((a-i)+(E-M))
                      mulpd  xmm1 , xmm13              ;xmm1  0.38((a-i)-(E-M))    -0.38((A-I)+(e-m))
                      mulpd  xmm5 , xmm13              ;xmm5  0.38((a-i)+(E-M))    -0.38((A-I)-(e-m))
                      addpd  xmm3 , xmm1
                      subpd  xmm0 , xmm5
                      movlhps xmm1, xmm2
                      movhlps xmm1, xmm2               ;xmm1  0.7(a+i-e-m)          0.7(A+I-E-M)
                      xorpd  xmm1 , xmm12              ;xmm1  0.7(a+i-e-m)         -0.7(A+I-E-M)
                      subpd  xmm2 , xmm1
                      movapd [rsi + 16], xmm4
                      movapd [rsi + 64 + 16], xmm0
                      movapd [rsi + 128 + 16], xmm2
                      movapd [rsi + 192 + 16], xmm3
                      movapd xmm0 , [rsi + 32]         ;xmm0  A                     a
                      movapd xmm1 , [rsi + 64 + 32]    ;xmm1  E                     e
                      movapd xmm2 , [rsi + 128 + 32]   ;xmm2  I                     i
                      movapd xmm3 , [rsi + 192 + 32]   ;xmm3  M                     m
                      movapd xmm4 , xmm0
                      addpd  xmm4 , xmm2               ;xmm4  A+I                   a+i
                      movapd xmm5 , xmm1
                      addpd  xmm5 , xmm3               ;xmm5  E+M                   e+m
                      subpd  xmm0 , xmm2               ;xmm0  A-I                   a-i
                      subpd  xmm1 , xmm3               ;xmm1  E-M                   e-m
                      shufpd xmm1 , xmm1, 01b          ;xmm1  e-m                   E-M
                      xorpd  xmm1 , xmm12              ;xmm1  e-m                   -(E-M)
                      movapd xmm2 , xmm4
                      subpd  xmm2 , xmm5               ;xmm2  A+I-E-M               a+i-e-m
                      xorpd  xmm2 , xmm12              ;xmm2  A+I-E-M              -(a+i-e-m)
                      shufpd xmm2 , xmm2, 01b          ;xmm2  -(a+i-e-m)            A+I-E-M
                      addpd  xmm4 , xmm5               ;xmm4  A+I+E+M               a+i+e+m
                      movapd xmm3 , xmm0
                      addpd  xmm3 , xmm1               ;xmm3  (A-I)+(e-m)           (a-i)-(E-M)
                      mulpd  xmm3 , xmm14              ;xmm3  0.7((A-I)+(e-m))      0.7((a-i)-(E-M))
                      subpd  xmm0 , xmm1               ;xmm0  (A-I)-(e-m)           (a-i)+(E-M)
                      mulpd  xmm0 , xmm14              ;xmm0  0.7((A-I)-(e-m))      0.7((a-i)+(E-M))
                      movlhps xmm1, xmm3
                      movhlps xmm1, xmm3               ;xmm1  0.7((a-i)-(E-M)       0.7((A-I)+(e-m))
                      xorpd   xmm1, xmm12              ;xmm1  0.7((a-i)-(E-M)      -0.7((A-I)+(e-m))
                      movlhps xmm5, xmm0
                      movhlps xmm5, xmm0               ;xmm5  0.7((a-i)+(E-M)       0.7((A-I)-(e-m))
                      xorpd   xmm5, xmm12              ;xmm5  0.7((a-i)+(E-M)      -0.7((A-I)-(e-m))
                      addpd  xmm3 , xmm1
                      subpd  xmm0 , xmm5
                      movapd [rsi + 32], xmm4
                      movapd [rsi + 64 + 32], xmm0
                      movapd [rsi + 128 + 32], xmm2
                      movapd [rsi + 192 + 32], xmm3
                      movapd xmm0 , [rsi + 48]         ;xmm0  A                     a
                      movapd xmm1 , [rsi + 64 + 48]    ;xmm1  E                     e
                      movapd xmm2 , [rsi + 128 + 48]   ;xmm2  I                     i
                      movapd xmm3 , [rsi + 192 + 48]   ;xmm3  M                     m
                      movapd xmm4 , xmm0
                      addpd  xmm4 , xmm2               ;xmm4  A+I                   a+i
                      movapd xmm5 , xmm1
                      addpd  xmm5 , xmm3               ;xmm5  E+M                   e+m
                      subpd  xmm0 , xmm2               ;xmm0  A-I                   a-i
                      subpd  xmm1 , xmm3               ;xmm1  E-M                   e-m
                      shufpd xmm1 , xmm1, 01b          ;xmm1  e-m                   E-M
                      xorpd  xmm1 , xmm12              ;xmm1  e-m                   -(E-M)
                      movapd xmm2 , xmm4
                      subpd  xmm2 , xmm5               ;xmm2  A+I-E-M               a+i-e-m
                      mulpd  xmm2 , xmm14              ;xmm2  0.7(A+I-E-M)          0.7(a+i-e-m)
                      addpd  xmm4 , xmm5               ;xmm4  A+I+E+M               a+i+e+m
                      movapd xmm3 , xmm0
                      addpd  xmm3 , xmm1               ;xmm3  (A-I)+(e-m)           (a-i)-(E-M)
                      subpd  xmm0 , xmm1               ;xmm0  (A-I)-(e-m)           (a-i)+(E-M)
                      movlhps xmm1, xmm3
                      movhlps xmm1, xmm3               ;xmm1  (a-i)-(E-M)           (A-I)+(e-m)
                      xorpd   xmm1, xmm12              ;xmm1  (a-i)-(E-M)          -((A-I)+(e-m))
                      movlhps xmm5, xmm0
                      movhlps xmm5, xmm0               ;xmm5  (a-i)+(E-M)           (A-I)-(e-m)
                      xorpd   xmm5, xmm12              ;xmm5  (a-i)+(E-M)          -((A-I)-(e-m))
                      mulpd  xmm3 , xmm13              ;xmm3  0.38((A-I)+(e-m))     0.92((a-i)-(E-M))
                      mulpd  xmm0 , xmm13              ;xmm0  0.38((A-I)-(e-m))     0.92((a-i)+(E-M))
                      mulpd  xmm1 , xmm15              ;xmm1  0.92((a-i)-(E-M))    -0.38((A-I)+(e-m))
                      mulpd  xmm5 , xmm15              ;xmm5  0.92((a-i)+(E-M))    -0.38((A-I)-(e-m))
                      addpd  xmm3 , xmm1
                      subpd  xmm0 , xmm5
                      movapd xmm1 , xmm2               ;xmm1  0.7(A+I-E-M)          0.7(a+i-e-m)
                      xorpd  xmm1 , xmm12              ;xmm1  0.7(A+I-E-M)         -0.7(a+i-e-m)
                      shufpd xmm1 , xmm1, 01b          ;xmm1 -0.7(a+i-e-m)          0.7(A+I-E-M)
                      subpd  xmm1 , xmm2
                      movapd [rsi + 48], xmm4
                      movapd [rsi + 64 + 48], xmm0
                      movapd [rsi + 128 + 48], xmm1
                      movapd [rsi + 192 + 48], xmm3

                      ;4-point FFTs
                      xor    ecx , ecx
             .lp12:   movapd xmm0 , [rsi + rcx]        ;xmm0  A           a
                      movapd xmm1 , [rsi + rcx + 16]   ;xmm1  B           b
                      movapd xmm2 , [rsi + rcx + 32]   ;xmm2  C           c
                      movapd xmm3 , [rsi + rcx + 48]   ;xmm3  D           d
                      movapd xmm4 , xmm0
                      addpd  xmm4 , xmm2               ;xmm4  A+C         a+c
                      movapd xmm5 , xmm1
                      addpd  xmm5 , xmm3               ;xmm5  B+D         b+d
                      subpd  xmm0 , xmm2               ;xmm0  A-C         a-c
                      subpd  xmm1 , xmm3               ;xmm1  B-D         b-d
                      shufpd xmm1 , xmm1, 01b          ;xmm1  b-d         B-D
                      xorpd  xmm1 , xmm12              ;xmm1  b-d         -(B-D)
                      movapd xmm3 , xmm4
                      subpd  xmm3 , xmm5               ;xmm6  A+C-B-D     a+c-b-d
                      addpd  xmm4 , xmm5               ;xmm4  A+C+B+D     a+c+b+d
                      movapd xmm2 , xmm0
                      addpd  xmm2 , xmm1               ;xmm2  (A-C)+(b-d) (a-c)-(B-D)
                      subpd  xmm0 , xmm1               ;xmm0  (A-C)-(b-d) (a-c)+(B-D)
                      movapd [rdi + rcx], xmm4
                      movapd [rdi + rcx + 16], xmm0
                      movapd [rdi + rcx + 32], xmm3
                      movapd [rdi + rcx + 48], xmm2
                      add    rcx , 64
                      cmp    rcx , 256
                      jnz    .lp12

                      add    rsi , 256
                      add    rdi , 256
                      cmp    rsi , r10
                      jnz    .lp10

                      ret
;------------------------------------------------------------------------------------




;------------------------------------------------------------------------------------
;8-POINT FFTs  (USES RADIX-4 DIT TO DECOMPOSE THE 8-POINT FFT INTO 2-POINT FFTs)
;IN:   rdx -  0/1  (fft/ifft)                                        uses: xmm0-xmm15
;      rsi - *RI
;      rdi - *RI aux
;      r10 - *RI + (2^n)*16
;
;OUT:  RI

_fft8:
                      shl    rdx , 4
                      mov    rax , FFT4_XORL
                      movapd xmm14, dqword [rax + rdx]
                      movapd xmm15, dqword [FFT4_0_70]

                      ;n/8 * 26  SIMD additions
                      ;n/8 * 2   SIMD multiplications
                      ;n/8 * 3+5 SIMD shuffles and xors
                      ;n/8 * 16  memory accesses
             .lp10:
                      ;0:  a + c + e + g                              A + C + E + G
                      ;2:  ((a-e) + (C-G))*1  +  ((A-E) - (c-g))*0    ((A-E) - (c-g))*1  -  ((a-e) + (C-G))*0
                      ;4:  (a - c + e - g)*1  +  (A - C + E - G)*0    (A - C + E - G)*1  -  (a - c + e - g)*0
                      ;7:  ((a-e) - (C-G))*1  -  ((A-E) + (c-g))*0    ((A-E) + (c-g))*1  +  ((a-e) - (C-G))*0

                      ;1:  b + d + f + h                              B + D + F + H
                      ;3:  ((b-f) + (D-H))*0.7+  ((B-F) - (d-h))*0.7  ((B-F) - (d-h))*0.7-  ((b-f) + (D-H))*0.7
                      ;5:  (b - d + f - h)*0  +  (B - D + F - H)*1    (B - D + F - H)*0  -  (b - d + f - h)*1
                      ;6:  ((b-f) - (D-H))*0.7-  ((B-F) + (d-h))*0.7  ((B-F) + (d-h))*0.7+  ((b-f) - (D-H))*0.7

                      movapd xmm0 , [rsi]              ;xmm0  A                     a
                      movapd xmm1 , [rsi + 16]         ;xmm1  B                     b
                      movapd xmm2 , [rsi + 32]         ;xmm2  C                     c
                      movapd xmm3 , [rsi + 48]         ;xmm3  D                     d
                      movapd xmm4 , [rsi + 64]         ;xmm4  E                     e
                      movapd xmm5 , [rsi + 80]         ;xmm5  F                     f
                      movapd xmm6 , [rsi + 96]         ;xmm6  G                     g
                      movapd xmm7 , [rsi + 112]        ;xmm7  H                     h
                      movapd xmm8 , xmm0               ;xmm8  A                     a
                      addpd  xmm8 , xmm4               ;xmm8  A+E                   a+e
                      movapd xmm9 , xmm2               ;xmm9  C                     c
                      addpd  xmm9 , xmm6               ;xmm9  C+G                   c+g
                      movapd xmm10, xmm1               ;xmm10 B                     b
                      addpd  xmm10, xmm5               ;xmm10 B+F                   b+f
                      movapd xmm11, xmm3               ;xmm11 D                     d
                      addpd  xmm11, xmm7               ;xmm11 D+H                   d+h
                      movapd xmm12, xmm8               ;xmm12 A+E                   a+e
                      addpd  xmm12, xmm9               ;xmm12 A+E+C+G               a+e+c+g
                      movapd xmm13, xmm10              ;xmm13 B+F                   b+f
                      addpd  xmm13, xmm11              ;xmm13 B+F+D+H               b+f+d+h
                      subpd  xmm8 , xmm9               ;xmm8  A+E-C-G               a+e-c-g
                      subpd  xmm10, xmm11              ;xmm10 B+F-D-H               b+f-d-h
                      xorpd  xmm10, xmm14              ;xmm10 B+F-D-H              -(b+f-d-h)
                      shufpd xmm10, xmm10, 01b         ;xmm10 b+f-d-h               B+F-D-H
                                                       ;free: xmm9, xmm11
                      movapd xmm9 , xmm12
                      addpd  xmm12, xmm13
                      subpd  xmm9 , xmm13              ;free: xmm11, xmm13    used: xmm9, xmm12
                      movapd xmm11, xmm8
                      addpd  xmm8 , xmm10
                      subpd  xmm11, xmm10              ;free: xmm10, xmm13    used: xmm8, xmm9, xmm11, xmm12
                      subpd  xmm0 , xmm4               ;xmm0  A-E                   a-e
                      subpd  xmm2 , xmm6               ;xmm2  C-G                   c-g
                      shufpd xmm2 , xmm2, 01b          ;xmm2  c-g                   C-G
                      xorpd  xmm2 , xmm14              ;xmm2  c-g                   -(C-G)
                      subpd  xmm1 , xmm5               ;xmm1  B-F                   b-f
                      subpd  xmm3 , xmm7               ;xmm3  D-H                   d-h
                      shufpd xmm3 , xmm3, 01b          ;xmm3  d-h                   D-H
                      xorpd  xmm3 , xmm14              ;xmm3  d-h                   -(D-H)
                                                       ;free: xmm4-xmm7, xmm8, xmm10, xmm12, xmm13    used: xmm9, xmm11
                      movapd xmm4 , xmm0
                      subpd  xmm0 , xmm2               ;xmm0  (A-E)-(c-g)           (a-e)+(C-G)
                      addpd  xmm2 , xmm4               ;xmm2  (A-E)+(c-g)           (a-e)-(C-G)
                      movapd xmm4 , xmm1
                      subpd  xmm1 , xmm3               ;xmm1  (B-F)-(d-h)           (b-f)+(D-H)
                      mulpd  xmm1 , xmm15              ;xmm1  0.7((B-F)-(d-h))      0.7((b-f)+(D-H))
                      addpd  xmm3 , xmm4               ;xmm3  (B-F)+(d-h)           (b-f)-(D-H)
                      mulpd  xmm3 , xmm15              ;xmm3  0.7((B-F)+(d-h))      0.7((b-f)-(D-H))
                      movlhps xmm4, xmm1
                      movhlps xmm4, xmm1               ;xmm4  0.7((b-f)+(D-H))      0.7((B-F)-(d-h))
                      xorpd   xmm4, xmm14              ;xmm4  0.7((b-f)+(D-H))     -0.7((B-F)-(d-h))
                      movlhps xmm5, xmm3
                      movhlps xmm5, xmm3               ;xmm5  0.7((b-f)-(D-H))      0.7((B-F)+(d-h))
                      xorpd   xmm5, xmm14              ;xmm5  0.7((b-f)-(D-H))     -0.7((B-F)+(d-h))
                      subpd   xmm1, xmm4               ;xmm1  0.7((B-F)-(d-h)) - 0.7((b-f)+(D-H))    0.7((b-f)+(D-H)) + 0.7((B-F)-(d-h))
                      addpd   xmm3, xmm5               ;xmm3  0.7((B-F)+(d-h)) + 0.7((b-f)-(D-H))    0.7((b-f)-(D-H)) - 0.7((B-F)+(d-h))
                      movapd  xmm4, xmm0
                      addpd   xmm0, xmm1
                      subpd   xmm4, xmm1
                      movapd  xmm5, xmm2
                      addpd   xmm2, xmm3
                      subpd   xmm5, xmm3
                      movapd [rdi], xmm12
                      movapd [rdi + 16], xmm9
                      movapd [rdi + 32], xmm0
                      movapd [rdi + 48], xmm4
                      movapd [rdi + 64], xmm8
                      movapd [rdi + 80], xmm11
                      movapd [rdi + 96], xmm2
                      movapd [rdi + 112], xmm5
                      add    rsi , 128
                      add    rdi , 128
                      cmp    rsi , r10
                      jnz    .lp10

                      ret
;------------------------------------------------------------------------------------




;------------------------------------------------------------------------------------
;4-POINT FFTs
;IN:   rdx -  0/1  (fft/ifft)                                         uses: xmm0-xmm8
;      rsi - *RI
;      rdi - *RI aux
;      r10 - *RI + (2^n)*16
;
;OUT:  RI

_fft4:
                      shl    rdx , 4
                      mov    rax , FFT4_XORL
                      movapd xmm8 , dqword [rax + rdx]

                      ;n/4 * 8  SIMD additions
                      ;n/4 * 1+1 SIMD shuffle and xor
                      ;n/4 * 8  memory accesses
             .lp10:
                      ;0:  a + b + c + d       A + B + C + D
                      ;1:  (a-c) + (B-D)       (A-C) - (b-d)
                      ;2:  a - b + c - d       A - B + C - D
                      ;3:  (a-c) - (B-D)       (A-C) + (b-d)

                      movapd xmm0 , [rsi]              ;xmm0  A           a
                      movapd xmm1 , [rsi + 16]         ;xmm1  B           b
                      movapd xmm2 , [rsi + 32]         ;xmm2  C           c
                      movapd xmm3 , [rsi + 48]         ;xmm3  D           d
                      movapd xmm4 , xmm0
                      addpd  xmm4 , xmm2               ;xmm4  A+C         a+c
                      movapd xmm5 , xmm1
                      addpd  xmm5 , xmm3               ;xmm5  B+D         b+d
                      subpd  xmm0 , xmm2               ;xmm0  A-C         a-c
                      subpd  xmm1 , xmm3               ;xmm1  B-D         b-d
                      shufpd xmm1 , xmm1, 01b          ;xmm1  b-d         B-D
                      xorpd  xmm1 , xmm8               ;xmm1  b-d         -(B-D)
                      movapd xmm6 , xmm4
                      subpd  xmm6 , xmm5               ;xmm6  A+C-B-D     a+c-b-d
                      addpd  xmm4 , xmm5               ;xmm4  A+C+B+D     a+c+b+d
                      movapd xmm2 , xmm0
                      addpd  xmm2 , xmm1               ;xmm2  (A-C)+(b-d) (a-c)-(B-D)
                      subpd  xmm0 , xmm1               ;xmm0  (A-C)-(b-d) (a-c)+(B-D)
                      movapd [rdi], xmm4
                      movapd [rdi + 16], xmm0
                      movapd [rdi + 32], xmm6
                      movapd [rdi + 48], xmm2
                      add    rsi , 64
                      add    rdi , 64
                      cmp    rsi , r10
                      jnz    .lp10

                      ret
;------------------------------------------------------------------------------------




;------------------------------------------------------------------------------------
;2-POINT FFTs
;IN:   rdx -  0/1  (fft/ifft)                                         uses: xmm0-xmm2
;      rsi - *RI
;      rdi - *RI aux
;      r10 - *RI + (2^n)*16
;
;OUT:  RI

_fft2:
                      ;n/2 * 2  SIMD additions
                      ;n/2 * 4  memory accesses
             .lp10:
                      ;0:  a + b               A + B
                      ;1:  a - b               A - B

                      movapd xmm0 , [rsi]
                      movapd xmm1 , [rsi + 16]
                      movapd xmm2 , xmm0
                      subpd  xmm2 , xmm1
                      addpd  xmm0 , xmm1
                      movapd [rdi], xmm0
                      movapd [rdi + 16], xmm2
                      add    rsi , 32
                      add    rdi , 32
                      cmp    rsi , r10
                      jnz    .lp10

                      ret
;------------------------------------------------------------------------------------








;------------------------------------------------------------------------------------
align 16

FFT4_XORL   dq  0x8000000000000000   , 0
FFT4_XORH   dq  0                    , 0x8000000000000000
FFT4_0_38   dq  0.382683432365089772 , 0.382683432365089772
FFT4_0_70   dq  0.707106781186547524 , 0.707106781186547524
FFT4_0_92   dq  0.923879532511286756 , 0.923879532511286756
FFT4_CALL   dq  _fft2, _fft4, _fft8, _fft16

;------------------------------------------------------------------------------------
















