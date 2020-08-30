
; THIS FILE IS COPYRIGHT (C)  6/04/2011 Akos Mogyorosi <flowwolf>
; last modified:              7/10/2012
;
; COMPLEX TO COMPLEX IN-PLACE CONJUGATE-PAIR SPLIT-RADIX FFT (RADICES 2-4 DECIMATION IN FREQUENCY)

;global srfft_dif     ;forward transform, decimation in freq
;global isrfft_dif    ;inverse transform, decimation in freq
;global srfft_bitrev  ;bit reversal

;%define dqword


;------------------------------------------------------------------------------------
;COMPLEX TO COMPLEX IN-PLACE SPLIT-RADIX FFT (RADICES 2-4 DECIMATION IN FREQUENCY)
;IN:   rcx -  n    (length n)                                        uses: xmm0-xmm15
;      rdx - *RI   (interleaved real & imaginary array, double)
;
;OUT:  RI
;
;NOTE: RI must be aligned on a 16-byte boundary
;
;      elements of RI should be divided by n before passing them to isrfft

align 16
srfft_dif:
                      push   r11, r10, r9, r8, rdi, rsi, rbx, rax
                                                           ;rcx -  length
                      xchg   rdx , rsi                     ;rsi - *RI
                      xor    edx , edx                     ;rdx -  0
                      xor    r11 , r11                     ;r11 -  0
                      call   _SRFFT_decomp_DIF
                      call   srfft_bitrev
                      xchg   rdx , rsi

                      pop    rax, rbx, rsi, rdi, r8, r9, r10, r11

                      ret
;------------------------------------------------------------------------------------




;------------------------------------------------------------------------------------
;COMPLEX TO COMPLEX IN-PLACE SPLIT-RADIX FFT (RADICES 2-4 DECIMATION IN FREQUENCY)
;IN:   rcx -  n    (length n)                                        uses: xmm0-xmm15
;      rdx - *RI   (interleaved real & imaginary array, double)
;
;OUT:  RI
;
;NOTE: RI must be aligned on a 16-byte boundary
;
;      elements of RI should be divided by n before passing them to isrfft

align 16
isrfft_dif:
                      push   r11, r10, r9, r8, rdi, rsi, rbx, rax
                                                           ;rcx -  length
                      xchg   rdx , rsi                     ;rsi - *RI
                      mov    edx , 16                      ;rdx -  16
                      xor    r11 , r11                     ;r11 -  0
                      call   _SRFFT_decomp_DIF
                      call   srfft_bitrev
                      xchg   rdx , rsi

                      pop    rax, rbx, rsi, rdi, r8, r9, r10, r11

                      ret
;------------------------------------------------------------------------------------








;------------------------------------------------------------------------------------
;RECURSIVE IN-PLACE BIT-REVERSAL                    uses: r10,r9,r8,rdi,rax xmm0-xmm9
;IN:   rsi - *RI
;      rcx -  length
;
;OUT:  RI

srfft_bitrev:
                      push   r11

                      xor    eax , eax
                      inc    eax
                      call   srfft_bitrev_s

                      pop    r11
                      ret
;------------------------------------------------------------------------------------
;IN:   rsi - *RI                                        uses: r10,r9,r8,rdi xmm0-xmm7
;      rcx -  length
;      rax -  stride
;      rbx -  pos     (unused)

srfft_bitrev_s:
                      push   rsi , rbx , rcx , rax

                      cmp    rcx , 16
                      jbe    .sk10

                      shr    rcx , 2
                      add    rax , rax
                      call   srfft_bitrev_s

                      lea    r8  , [rcx*2 + 1]
                      imul   r8  , rax
                      shl    r8  , 4-1
                      add    rsi , r8
                      call   srfft_bitrev_s

                      lea    r8  , [rcx*2 + 1]
                      imul   r8  , rax
                      shl    r8  , 4-1
                      sub    rsi , r8
                      lea    rsi , [rsi + rax*8]
                      lea    rbx , [rcx*2 - 1]
                      imul   rbx , rax
                      shr    rbx , 1
                      call   srfft_bitrev_n

                      pop    rax , rcx , rbx , rsi
                      ret
             .sk10:
                      mov    r9  , rax            ;r9  -  s*16 (t1)
                      shl    r9  , 4

                      cmp    rcx  , 4
                      jae    .sk20
                      pop    rax , rcx , rbx , rsi
                      ret
             .sk20:
                      cmp    rcx  , 8             ;4
                      jae    .sk30
                      lea    rdi  , [rsi + r9*2]
                      add    rsi  , r9
                      movapd xmm0 , [rsi]
                      movapd xmm1 , [rdi]
                      movapd [rsi], xmm1
                      movapd [rdi], xmm0
                      pop    rax , rcx , rbx , rsi
                      ret
             .sk30:
                      cmp    rcx  , 16
                      jae    .sk40               ;8
                      lea    r10  , [r9*3]
                      lea    rdi  , [rsi + r10]
                      add    rsi  , r9
                      movapd xmm0 , [rsi]
                      movapd xmm1 , [rdi]
                      add    rsi  , r10
                      add    rdi  , r10
                      movapd xmm2 , [rsi]
                      movapd xmm3 , [rdi]
                      movapd [rsi], xmm0
                      movapd [rdi], xmm1
                      sub    rsi  , r10
                      sub    rdi  , r10
                      movapd [rsi], xmm2
                      movapd [rdi], xmm3
                      pop    rax , rcx , rbx , rsi
                      ret
             .sk40:
                      lea    rdi  , [rsi + r9]    ;16
                      lea    r10  , [r9*4]        ;r10 -  t1*4
                      movapd xmm1 , [rdi]
                      add    rsi  , r10
                      add    rdi  , r10
                      movapd xmm2 , [rsi]
                      movapd xmm3 , [rdi]
                      add    rsi  , r10
                      add    rdi  , r10
                      movapd xmm4 , [rsi]
                      movapd [rsi], xmm1
                      add    rsi  , r10
                      add    rdi  , r10
                      movapd xmm5 , [rsi]
                      movapd xmm6 , [rdi]
                      sub    rsi  , r9
                      sub    rsi  , r9
                      sub    rdi  , r9
                      sub    rdi  , r9
                      movapd xmm7 , [rsi]
                      movapd xmm0 , [rdi]
                      movapd [rsi], xmm3
                      movapd [rdi], xmm6
                      sub    rsi  , r10
                      sub    rdi  , r10
                      movapd xmm1 , [rdi]
                      sub    rsi  , r10
                      sub    rdi  , r10
                      movapd xmm3 , [rsi]
                      movapd xmm6 , [rdi]
                      movapd [rsi], xmm2
                      movapd [rdi], xmm5
                      lea    rsi  , [rsi + r9*2]
                      lea    rdi  , [rdi + r9*2]
                      movapd [rsi], xmm3
                      movapd [rdi], xmm7
                      lea    rsi  , [rsi + r9*8]
                      lea    rdi  , [rdi + r9*8]
                      movapd [rsi], xmm6
                      movapd [rdi], xmm0
                      lea    r10  , [r9*3]
                      add    r10  , r10
                      lea    rsi  , [rsi + r9*2]
                      sub    rdi  , r10
                      movapd xmm2 , [rsi]
                      movapd [rsi], xmm1
                      movapd [rdi], xmm2
                      sub    rdi  , r10
                      movapd [rdi], xmm4
                      pop    rax , rcx , rbx , rsi
                      ret
;------------------------------------------------------------------------------------
;IN:   rsi - *RI                                   uses: r11,r10,r9,r8,rdi, xmm0-xmm9
;      rcx -  length
;      rax -  stride
;      rbx -  m

srfft_bitrev_n:
                      push   rsi , rbx , rcx , rax

                      cmp    rcx , 16
                      jbe    .sk10

                      shr    rcx , 2
                      add    rax , rax
                      call   srfft_bitrev_n

                      lea    r8  , [rcx*2 + 1]
                      imul   r8  , rax
                      shl    r8  , 4-1
                      add    rsi , r8
                      call   srfft_bitrev_n

                      lea    r8  , [rcx*2 + 1]
                      imul   r8  , rax
                      shl    r8  , 4-1
                      sub    rsi , r8
                      lea    rsi , [rsi + rax*8]
                      lea    r8  , [rcx*2 - 1]
                      imul   r8  , rax
                      shr    r8  , 1
                      add    rbx , r8
                      call   srfft_bitrev_n

                      lea    r8  , [rax*8]
                      sub    rsi , r8
                      lea    r8  , [rcx*2]
                      imul   r8  , rax
                      shl    r8  , 4-1
                      add    rsi , r8
                      lea    r8  , [rcx*2 - 1]
                      imul   r8  , rax
                      shr    r8  , 1
                      sub    rbx , r8
                      sub    rbx , r8
                      call   srfft_bitrev_n

                      pop    rax , rcx , rbx , rsi
                      ret
             .sk10:
                      mov    r9  , rax            ;r9  -  s*16 (t1)
                      shl    r9  , 4
                      mov    r10 , rbx            ;r10 -  m*16 (t2)
                      shl    r10 , 4

                      cmp    rcx , 8
                      jae    .sk30
                      pop    rax , rcx , rbx , rsi
                      ret
             .sk30:
                      cmp    rcx , 16             ;8
                      jae    .sk40
                      lea    r11  , [r9*4]        ;r11 -  t1*4
                      lea    rdi  , [rsi + r9]
                      movapd xmm0 , [rsi]
                      movapd xmm1 , [rdi]
                      add    rsi  , r11
                      add    rdi  , r11
                      movapd xmm2 , [rsi]
                      movapd xmm3 , [rdi]
                      add    rsi  , r10
                      add    rdi  , r10
                      movapd xmm4 , [rsi]
                      movapd xmm5 , [rdi]
                      movapd [rsi], xmm1
                      movapd [rdi], xmm3
                      sub    rsi  , r11
                      sub    rdi  , r11
                      movapd xmm6 , [rsi]
                      movapd xmm7 , [rdi]
                      movapd [rsi], xmm0
                      movapd [rdi], xmm2
                      sub    rsi  , r10
                      sub    rdi  , r10
                      movapd [rsi], xmm6
                      movapd [rdi], xmm4
                      add    rsi  , r11
                      add    rdi  , r11
                      movapd [rsi], xmm7
                      movapd [rdi], xmm5
                      sub    rsi  , r9
                      sub    rsi  , r9
                      sub    rdi  , r9
                      sub    rdi  , r9
                      movapd xmm0 , [rsi]
                      movapd xmm1 , [rdi]
                      add    rsi  , r11
                      add    rdi  , r11
                      movapd xmm2 , [rsi]
                      movapd xmm3 , [rdi]
                      add    rsi  , r10
                      add    rdi  , r10
                      movapd xmm4 , [rsi]
                      movapd xmm5 , [rdi]
                      movapd [rsi], xmm1
                      movapd [rdi], xmm3
                      sub    rsi  , r11
                      sub    rdi  , r11
                      movapd xmm6 , [rsi]
                      movapd xmm7 , [rdi]
                      movapd [rsi], xmm0
                      movapd [rdi], xmm2
                      sub    rsi  , r10
                      sub    rdi  , r10
                      movapd [rsi], xmm6
                      movapd [rdi], xmm4
                      add    rsi , r11
                      add    rdi , r11
                      movapd [rsi], xmm7
                      movapd [rdi], xmm5
                      pop    rax , rcx , rbx , rsi
                      ret
             .sk40:
                      lea    rdi  , [rsi + r9]    ;16
                      lea    r11  , [r9*8]        ;r11 -  t1*8
                      movapd xmm0 , [rsi]
                      movapd xmm1 , [rdi]
                      add    rsi  , r11
                      add    rdi  , r11
                      movapd xmm2 , [rsi]
                      movapd xmm3 , [rdi]
                      add    rsi  , r10
                      add    rdi  , r10
                      movapd xmm4 , [rsi]
                      movapd xmm5 , [rdi]
                      movapd [rsi], xmm1
                      movapd [rdi], xmm3
                      sub    rsi  , r11
                      sub    rdi  , r11
                      movapd xmm6 , [rsi]
                      movapd xmm7 , [rdi]
                      movapd [rsi], xmm0
                      movapd [rdi], xmm2
                      sub    rsi  , r10
                      sub    rdi  , r10
                      movapd [rsi], xmm6
                      movapd [rdi], xmm4
                      add    rsi  , r11
                      add    rdi  , r11
                      movapd [rsi], xmm7
                      movapd [rdi], xmm5
                      sub    rsi  , r9
                      sub    rsi  , r9
                      sub    rdi  , r9
                      sub    rdi  , r9
                      movapd xmm0 , [rsi]
                      movapd xmm1 , [rdi]
                      add    rsi  , r11
                      add    rdi  , r11
                      movapd xmm2 , [rsi]
                      movapd xmm3 , [rdi]
                      add    rsi  , r10
                      add    rdi  , r10
                      movapd xmm4 , [rsi]
                      movapd xmm5 , [rdi]
                      movapd [rsi], xmm1
                      movapd [rdi], xmm3
                      sub    rsi  , r11
                      sub    rdi  , r11
                      movapd xmm6 , [rsi]
                      movapd xmm7 , [rdi]
                      movapd [rsi], xmm0
                      movapd [rdi], xmm2
                      sub    rsi  , r10
                      sub    rdi  , r10
                      movapd [rsi], xmm6
                      movapd [rdi], xmm4
                      add    rsi  , r11
                      add    rdi  , r11
                      movapd [rsi], xmm7
                      movapd [rdi], xmm5
                      sub    rsi  , r9
                      sub    rsi  , r9
                      sub    rdi  , r9
                      sub    rdi  , r9

                      movapd xmm0 , [rsi]
                      movapd xmm1 , [rdi]
                      sub    rsi  , r11
                      sub    rdi  , r11
                      movapd xmm2 , [rsi]
                      movapd xmm3 , [rdi]
                      add    rsi  , r10
                      add    rdi  , r10
                      movapd xmm4 , [rsi]
                      movapd xmm5 , [rdi]
                      add    rsi  , r11
                      add    rdi  , r11
                      mov    r11  , r9            ;r11 -  t1*10
                      imul   r11  , 10
                      movapd xmm6 , [rsi]
                      movapd xmm7 , [rdi]
                      sub    rsi  , r11
                      sub    rdi  , r11
                      movapd xmm8 , [rsi]
                      movapd xmm9 , [rdi]
                      lea    r11  , [r9*8]        ;r11 -  t1*8
                      movapd [rsi], xmm2
                      movapd [rdi], xmm0
                      sub    rsi  , r10
                      sub    rdi  , r10
                      movapd xmm0 , [rsi]
                      movapd xmm2 , [rdi]
                      movapd [rsi], xmm4
                      movapd [rdi], xmm6
                      add    rsi  , r11
                      add    rdi  , r11
                      movapd xmm4 , [rsi]
                      movapd xmm6 , [rdi]
                      movapd [rsi], xmm5
                      movapd [rdi], xmm7
                      add    rsi  , r10
                      add    rdi  , r10
                      movapd xmm5 , [rsi]
                      movapd xmm7 , [rdi]
                      lea    r11  , [r9*3]        ;r11 -  t1*6
                      add    r11  , r11
                      movapd [rsi], xmm3
                      movapd [rdi], xmm1
                      sub    rsi  , r11
                      sub    rdi  , r11
                      movapd [rsi], xmm0
                      movapd [rdi], xmm4
                      sub    rsi  , r10
                      sub    rdi  , r10
                      movapd [rsi], xmm8
                      movapd [rdi], xmm5
                      lea    rsi , [rsi + r9*8]
                      lea    rdi , [rdi + r9*8]
                      movapd [rsi], xmm9
                      movapd [rdi], xmm7
                      add    rsi , r10
                      add    rdi , r10
                      movapd [rsi], xmm2
                      movapd [rdi], xmm6
                      pop    rax , rcx , rbx , rsi
                      ret
;------------------------------------------------------------------------------------
















;------------------------------------------------------------------------------------
;DECIMATION IN FREQUENCY

;_SRFFT_decomp_DIF
;_SRFFT16_DIF
;_SRFFT8_DIF
;_SRFFT4_DIF
;_SRFFT2_DIF








;------------------------------------------------------------------------------------
;RECURSIVE IN-PLACE SPLIT-RADIX DIF DECOMPOSITOR
;IN:   rdx -  0/16  (fft/ifft)                    uses: r10,r9,r8,rbx,rax, xmm0-xmm15
;      rsi - *RI
;      rcx -  length
;      r11 -  0/1   x
;
;OUT:  RI

align 16
_SRFFT_decomp_DIF:
                      push   rsi , rcx , r11

                      bsr    rax , rcx
                      test   rax , rax
                      jz     .end
                      cmp    rax , 5
                      jae    .sk20
                      mov    r8  , SRFFT_DIF_CALL
                      mov    rax , [r8 + rax*8 - 8]
                      call   rax
                      jmp    .end
             .sk20:
                      mov    r8    , SRFFT_XORL
                      mov    r9    , SRFFT_SINCOS
                      mov    r10   , SRFFT_1_0
                      shl    rax , 4
                      movapd xmm14 , dqword [r10]
                      movapd xmm12 , dqword [r8 + 0]
                      movapd xmm15 , dqword [r8 + rdx]
                      movapd xmm13 , dqword [r9 + rax - 5*16]

                      lea    r8  , [rcx*4]
                      lea    r9  , [rcx*8]
                      lea    r10 , [r8*3]
                      mov    rax , rcx
                      shr    rax , 2 + 1
                      xchg   rax , rcx
                      mov    rbx , rsi

                      xor    r11 , 1
                      dec    r11
                      and    r11 , r9

             .lp20:   movapd xmm0  , [rbx]                 ;xmm0   A             a
                      movapd xmm1  , [rbx + 16]            ;xmm1   B             b
                      movapd xmm2  , [rbx + r8]            ;xmm2   C             c
                      movapd xmm3  , [rbx + r8  + 16]      ;xmm3   D             d
                      movapd xmm4  , [rbx + r9]            ;xmm4   E             e
                      movapd xmm5  , [rbx + r9  + 16]      ;xmm5   F             f
                      movapd xmm6  , [rbx + r10]           ;xmm6   G             g
                      movapd xmm7  , [rbx + r10 + 16]      ;xmm7   H             h
                      ;radix-2
                      movapd xmm8  , xmm0
                      addpd  xmm8  , xmm4                  ;xmm8   A+E           a+e
                      movapd xmm9  , xmm2
                      addpd  xmm9  , xmm6                  ;xmm9   C+G           c+g
                      ;radix-4
                      subpd  xmm2  , xmm6                  ;xmm2   C-G           c-g
                      subpd  xmm0  , xmm4                  ;xmm0   A-E           a-e
                      movapd xmm10 , xmm2
                      shufpd xmm10 , xmm10 , 01b           ;xmm10  c-g           C-G
                      xorpd  xmm10 , xmm15                 ;xmm10-+(c-g)       +-(C-G)
                      xorpd  xmm2  , xmm15                 ;xmm2 -+(C-G)       +-(c-g)
                      shufpd xmm2  , xmm2  , 01b           ;xmm2 +-(c-g)       -+(C-G)
                      addpd  xmm2  , xmm0                  ;xmm2   (A-E)+-(c-g)   (a-e)-+(C-G)
                      addpd  xmm0  , xmm10                 ;xmm0   (A-E)-+(c-g)   (a-e)+-(C-G)
                      ;
                      movapd xmm10 , xmm14
                      movapd xmm11 , xmm14
                      unpcklpd xmm10 , xmm10               ;xmm10  c             c
                      unpckhpd xmm11 , xmm11               ;xmm11  s             s
                      mulpd  xmm10 , xmm2                  ;xmm10  cy            cx
                      mulpd  xmm2  , xmm11                 ;xmm2   sy            sx
                      shufpd xmm2  , xmm2 , 01b            ;xmm2   sx            sy
                      xorpd  xmm2  , xmm15                 ;xmm2 -+sx          +-sy
                      addpd  xmm2  , xmm10                 ;xmm2   cy-+sx        cx+-sy
                      movapd xmm10 , xmm14
                      movapd xmm11 , xmm14
                      unpcklpd xmm10 , xmm10               ;xmm10  c             c
                      unpckhpd xmm11 , xmm11               ;xmm11  s             s
                      mulpd  xmm10 , xmm0                  ;xmm10  cy            cx
                      mulpd  xmm0  , xmm11                 ;xmm0   sy            sx
                      xorpd  xmm0  , xmm15                 ;xmm0 -+sy          +-sx
                      shufpd xmm0  , xmm0 , 01b            ;xmm0 +-sx          -+sy
                      addpd  xmm0  , xmm10                 ;xmm0   cy+-sx        cx-+sy
                      ;4 points: xmm8, 9, 2, 0    free: xmm4, 6

                      movapd xmm11 , xmm14                 ;advance cos/sin
                      unpcklpd xmm14 , xmm14               ;xmm14  c             c
                      unpckhpd xmm11 , xmm11               ;xmm11  s             s
                      mulpd  xmm11 , xmm13                 ;xmm11  sy            sx
                      shufpd xmm11 , xmm11 , 01b           ;xmm11  sx            sy
                      xorpd  xmm11 , xmm12                 ;xmm11  sx           -sy
                      mulpd  xmm14 , xmm13                 ;xmm14  cy            cx
                      addpd  xmm14 , xmm11                 ;xmm14  cy+sx         cx-sy

                      add    rbx   , r11

                      ;radix-2
                      movapd xmm4  , xmm1
                      addpd  xmm4  , xmm5                  ;xmm4   B+F           b+f
                      movapd xmm6  , xmm3
                      addpd  xmm6  , xmm7                  ;xmm6   D+H           d+h
                      ;radix-4
                      subpd  xmm3  , xmm7                  ;xmm3   D-H           d-h
                      subpd  xmm1  , xmm5                  ;xmm1   B-F           b-f
                      movapd xmm10 , xmm3
                      shufpd xmm10 , xmm10 , 01b           ;xmm10  d-h           D-H
                      xorpd  xmm10 , xmm15                 ;xmm10-+(d-h)       +-(D-H)
                      xorpd  xmm3  , xmm15                 ;xmm3 -+(D-H)       +-(d-h)
                      shufpd xmm3  , xmm3  , 01b           ;xmm3 +-(d-h)       -+(D-H)
                      addpd  xmm3  , xmm1                  ;xmm3   (B-F)+-(d-h)   (b-f)-+(D-H)
                      addpd  xmm1  , xmm10                 ;xmm1   (B-F)-+(d-h)   (b-f)+-(D-H)
                      ;

                      movapd [rbx], xmm8
                      movapd [rbx + 16], xmm4
                      movapd [rbx + r8], xmm9
                      movapd [rbx + r8 + 16], xmm6

                      movapd xmm10 , xmm14
                      movapd xmm11 , xmm14
                      unpcklpd xmm10 , xmm10               ;xmm10  c             c
                      unpckhpd xmm11 , xmm11               ;xmm11  s             s
                      mulpd  xmm10 , xmm3                  ;xmm10  cy            cx
                      mulpd  xmm3  , xmm11                 ;xmm3   sy            sx
                      shufpd xmm3  , xmm3 , 01b            ;xmm3   sx            sy
                      xorpd  xmm3  , xmm15                 ;xmm3 -+sx          +-sy
                      addpd  xmm3  , xmm10                 ;xmm3   cy-+sx        cx+-sy
                      movapd xmm10 , xmm14
                      movapd xmm11 , xmm14
                      unpcklpd xmm10 , xmm10               ;xmm10  c             c
                      unpckhpd xmm11 , xmm11               ;xmm11  s             s
                      mulpd  xmm10 , xmm1                  ;xmm10  cy            cx
                      mulpd  xmm1  , xmm11                 ;xmm1   sy            sx
                      xorpd  xmm1  , xmm15                 ;xmm1 -+sy          +-sx
                      shufpd xmm1  , xmm1 , 01b            ;xmm1 +-sx          -+sy
                      addpd  xmm1  , xmm10                 ;xmm1   cy+-sx        cx-+sy
                      ;4 points: xmm4, 6, 3, 1    free: xmm5, 7

                      sub    rbx   , r11
                      sub    rbx   , r11

                      movapd xmm11 , xmm14                 ;advance cos/sin
                      unpcklpd xmm14 , xmm14               ;xmm14  c             c
                      unpckhpd xmm11 , xmm11               ;xmm11  s             s
                      mulpd  xmm11 , xmm13                 ;xmm11  sy            sx
                      shufpd xmm11 , xmm11 , 01b           ;xmm11  sx            sy
                      xorpd  xmm11 , xmm12                 ;xmm11  sx           -sy
                      mulpd  xmm14 , xmm13                 ;xmm14  cy            cx
                      addpd  xmm14 , xmm11                 ;xmm14  cy+sx         cx-sy

                      movapd [rbx + r9], xmm2
                      movapd [rbx + r9 + 16], xmm3
                      movapd [rbx + r10], xmm0
                      movapd [rbx + r10 + 16], xmm1

                      add    rbx , r11
                      add    rbx , 32

                      dec    rcx
                      jnz    .lp20
                      xchg   rax , rcx


                      test   r11 , r11  ;x
                      jz     .sk60

                      ;radix-4
                      shr    rcx , 2
                      xor    r11 , r11
                      bsr    rax , rcx
                      cmp    rax , 5
                      jae    .sk50
                      mov    r8  , SRFFT_DIF_CALL
                      mov    rax , [r8 + rax*8 - 8]
                      call   rax
                      jmp    .sk52
             .sk50:   call   _SRFFT_decomp_DIF
             .sk52:   lea    rsi , [rsi + rcx*8]
                      lea    rsi , [rsi + rcx*8]

                      ;radix-4
                      xor    r11 , r11
                      inc    r11
                      bsr    rax , rcx
                      cmp    rax , 5
                      jae    .sk54
                      mov    r8  , SRFFT_DIF_CALL
                      mov    rax , [r8 + rax*8 - 8]
                      call   rax
                      jmp    .sk56
             .sk54:   call   _SRFFT_decomp_DIF
             .sk56:   lea    rsi , [rsi + rcx*8]
                      lea    rsi , [rsi + rcx*8]

                      ;radix-2
                      add    rcx , rcx
                      xor    r11 , r11
                      inc    r11
                      bsr    rax , rcx
                      cmp    rax , 5
                      jae    .sk58
                      mov    r8  , SRFFT_DIF_CALL
                      mov    rax , [r8 + rax*8 - 8]
                      call   rax
                      jmp    .end
             .sk58:   call   _SRFFT_decomp_DIF

                      pop    r11 , rcx , rsi
                      ret

             .sk60:
                      ;radix-2
                      shr    rcx , 1
                      xor    r11 , r11
                      bsr    rax , rcx
                      cmp    rax , 5
                      jae    .sk40
                      mov    r8  , SRFFT_DIF_CALL
                      mov    rax , [r8 + rax*8 - 8]
                      call   rax
                      jmp    .sk42
             .sk40:   call   _SRFFT_decomp_DIF
             .sk42:   lea    rsi , [rsi + rcx*8]
                      lea    rsi , [rsi + rcx*8]

                      ;radices-4
                      shr    rcx , 1
                      xor    r11 , r11
                      bsr    rax , rcx
                      cmp    rax , 5
                      jae    .sk44
                      mov    r8  , SRFFT_DIF_CALL
                      mov    rax , [r8 + rax*8 - 8]
                      call   rax
                      lea    rsi , [rsi + rcx*8]
                      lea    rsi , [rsi + rcx*8]
                      bsr    rax , rcx
                      xor    r11 , r11
                      inc    r11
                      mov    r8  , SRFFT_DIF_CALL
                      mov    rax , [r8 + rax*8 - 8]
                      call   rax
                      jmp    .end
             .sk44:   call   _SRFFT_decomp_DIF
                      lea    rsi , [rsi + rcx*8]
                      lea    rsi , [rsi + rcx*8]
                      xor    r11 , r11
                      inc    r11
                      call   _SRFFT_decomp_DIF

              .end:
                      pop    r11 , rcx , rsi
                      ret
;------------------------------------------------------------------------------------








;------------------------------------------------------------------------------------
;16-POINT DIF FFT  (USES SPLIT-RADIX DIF DECOMPOSITION)
;IN:   rdx -  0/16  (fft/ifft)                                  uses: rax, xmm0-xmm15
;      rsi - *RI
;      r11 -  0/1   x
;
;OUT:  RI

align 16
_SRFFT16_DIF:
                      mov    rax   , SRFFT_XORL
                      mov    r8    , SRFFT_0_70
                      movapd xmm15 , dqword [rax + rdx]
                      movapd xmm14 , dqword [r8]

                      ;72      SIMD additions
                      ;12      SIMD multiplications
                      ;17 + 17 SIMD shuffles and xors
                      ;48 + 6  memory accesses

                      ;radix-2 decomposition of 16 points
                      movapd xmm0  , [rsi]                 ;xmm0   A           a
                      movapd xmm1  , [rsi + 16]            ;xmm1   B           b
                      movapd xmm2  , [rsi + 32]            ;xmm2   C           c
                      movapd xmm3  , [rsi + 48]            ;xmm3   D           d
                      movapd xmm4  , [rsi + 64]            ;xmm4   E           e
                      movapd xmm5  , [rsi + 80]            ;xmm5   F           f
                      movapd xmm6  , [rsi + 96]            ;xmm6   G           g
                      movapd xmm7  , [rsi + 112]           ;xmm7   H           h
                      addpd  xmm0  , [rsi + 128]           ;xmm0   A+I         a+i
                      addpd  xmm1  , [rsi + 128 + 16]      ;xmm1   B+J         b+j
                      addpd  xmm2  , [rsi + 128 + 32]      ;xmm2   C+K         c+k
                      addpd  xmm3  , [rsi + 128 + 48]      ;xmm3   D+L         d+l
                      addpd  xmm4  , [rsi + 128 + 64]      ;xmm4   E+M         e+m
                      addpd  xmm5  , [rsi + 128 + 80]      ;xmm5   F+N         f+n
                      addpd  xmm6  , [rsi + 128 + 96]      ;xmm6   G+O         g+o
                      addpd  xmm7  , [rsi + 128 + 112]     ;xmm7   H+P         h+p

                      ;8-point fft

                      ;radix-2 decomposition of 8 points
                      movapd xmm8  , xmm0                  ;xmm8   A+E = W    a+e = w
                      addpd  xmm8  , xmm4
                      movapd xmm9  , xmm1                  ;xmm9   B+F = X    b+f = x
                      addpd  xmm9  , xmm5
                      movapd xmm10 , xmm2                  ;xmm10  C+G = Y    c+g = y
                      addpd  xmm10 , xmm6
                      movapd xmm11 , xmm3                  ;xmm11  D+H = Z    d+h = z
                      addpd  xmm11 , xmm7

                      ;        w + x + y + z    W + X + Y + Z
                      ;        (w-y) + (X-Z)    (W-Y) - (x-z)
                      ;        w - x + y - z    W - X + Y - Z
                      ;        (w-y) - (X-Z)    (W-Y) + (x-z)

                      ;4-point fft
                      movapd xmm12 , xmm8
                      addpd  xmm12 , xmm10                 ;xmm12  W+Y         w+y
                      movapd xmm13 , xmm9
                      addpd  xmm13 , xmm11                 ;xmm13  X+Z         x+z
                      subpd  xmm8  , xmm10                 ;xmm8   W-Y         w-y
                      subpd  xmm9  , xmm11                 ;xmm9   X-Z         x-z
                      shufpd xmm9  , xmm9  , 01b           ;xmm9   x-z         X-Z
                      xorpd  xmm9  , xmm15                 ;xmm9 -+(x-z)     +-(X-Z)
                      movapd xmm10 , xmm12
                      subpd  xmm10 , xmm13                 ;xmm10  W+Y-X-Z     w+y-x-z
                      addpd  xmm12 , xmm13                 ;xmm12  W+Y+X+Z     w+y+x+z
                      movapd xmm11 , xmm8
                      addpd  xmm11 , xmm9                  ;xmm11  (W-Y)-+(x-z) (w-y)+-(X-Z)
                      subpd  xmm8  , xmm9                  ;xmm8   (W-Y)+-(x-z) (w-y)-+(X-Z)

                      ;xmm12, 8, 10, 11

            ;0:  ((a-e) + (C-G))*1  +  ((A-E) - (c-g))*0    ((A-E) - (c-g))*1  -  ((a-e) + (C-G))*0
            ;1:  ((b-f) + (D-H))*0.7+  ((B-F) - (d-h))*0.7  ((B-F) - (d-h))*0.7-  ((b-f) + (D-H))*0.7

            ;2:  ((a-e) - (C-G))*1  -  ((A-E) + (c-g))*0    ((A-E) + (c-g))*1  +  ((a-e) - (C-G))*0
            ;3:  ((b-f) - (D-H))*0.7-  ((B-F) + (d-h))*0.7  ((B-F) + (d-h))*0.7+  ((b-f) - (D-H))*0.7

                      ;radix-4 decompositions of 8 points
                      subpd  xmm0  , xmm4                  ;xmm0   A-E                 a-e
                      subpd  xmm1  , xmm5                  ;xmm1   B-F                 b-f
                      subpd  xmm2  , xmm6                  ;xmm2   C-G                 c-g
                      xorpd  xmm2  , xmm15                 ;xmm2 -+(C-G)             +-(c-g)
                      shufpd xmm2  , xmm2 , 01b            ;xmm2 +-(c-g)             -+(C-G)
                      subpd  xmm3  , xmm7                  ;xmm3   D-H                 d-h
                      xorpd  xmm3  , xmm15                 ;xmm3 -+(D-H)             +-(d-h)
                      shufpd xmm3  , xmm3 , 01b            ;xmm3 +-(d-h)             -+(D-H)
                      movapd xmm4  , xmm0
                      subpd  xmm4  , xmm2                  ;xmm4   (A-E)+-(c-g)         (a-e)-+(C-G)
                      addpd  xmm0  , xmm2                  ;xmm0   (A-E)-+(c-g)         (a-e)+-(C-G)
                      movapd xmm5  , xmm1
                      subpd  xmm5  , xmm3                  ;xmm5   (B-F)-+(d-h)         (b-f)+-(d-h)
                      mulpd  xmm5  , xmm14                 ;xmm5   ((B-F)-+(d-h))*0.7   ((b-f)+-(d-h))*0.7
                      addpd  xmm1  , xmm3                  ;xmm1   (B-F)+-(d-h)         (b-f)-+(d-h)
                      mulpd  xmm1  , xmm14                 ;xmm1   ((B-F)+-(d-h))*0.7   ((b-f)-+(d-h))*0.7

                      movapd xmm2  , xmm1
                      xorpd  xmm2  , xmm15
                      shufpd xmm2  , xmm2 , 01b
                      addpd  xmm2  , xmm1
                      movapd xmm3  , xmm5
                      shufpd xmm3  , xmm3 , 01b
                      xorpd  xmm3  , xmm15
                      addpd  xmm3  , xmm5

                      ;2-point ffts
                      movapd xmm13 , xmm0
                      subpd  xmm13 , xmm2
                      addpd  xmm0  , xmm2
                      movapd xmm15 , xmm4
                      subpd  xmm15 , xmm3
                      addpd  xmm4  , xmm3
                      movapd xmm9  , xmm0
                      movapd xmm14 , xmm4


                      ;end of 8-point fft

                      mov    r8    , r11
                      imul   r8    , 240
                      mov    r9    , r11
                      imul   r9    , 208
                      mov    r10   , r11
                      imul   r10   , 160
                      mov    rax   , r11
                      shl    rax   , 6
                      add    rax   , 64

                      movapd xmm0  , [rsi]                 ;xmm0   A                   a
                      movapd xmm1  , [rsi + 16]            ;xmm1   B                   b
                      movapd xmm2  , [rsi + 32]            ;xmm2   C                   c
                      movapd xmm3  , [rsi + 48]            ;xmm3   D                   d
                      movapd xmm4  , [rsi + 64]            ;xmm4   E                   e
                      movapd xmm5  , [rsi + 80]            ;xmm5   F                   f
                      movapd xmm6  , [rsi + 96]            ;xmm6   G                   g
                      movapd xmm7  , [rsi + 112]           ;xmm7   H                   h
                      subpd  xmm0  , [rsi + 128]           ;xmm0   A-I                 a-i
                      subpd  xmm1  , [rsi + 128 + 16]      ;xmm1   B-J                 b-j
                      subpd  xmm2  , [rsi + 128 + 32]      ;xmm2   C-K                 c-k
                      subpd  xmm3  , [rsi + 128 + 48]      ;xmm3   D-L                 d-l
                      subpd  xmm4  , [rsi + 128 + 64]      ;xmm4   E-M                 e-m
                      subpd  xmm5  , [rsi + 128 + 80]      ;xmm5   F-N                 f-n
                      subpd  xmm6  , [rsi + 128 + 96]      ;xmm6   G-O                 g-o
                      subpd  xmm7  , [rsi + 128 + 112]     ;xmm7   H-P                 h-p

                      movapd [rsi + r8  + 0]  , xmm12
                      movapd [rsi + r9  + 16] , xmm10
                      movapd [rsi + r10 + 32] , xmm8
                      movapd [rsi + r10 + 48] , xmm11
                      movapd [rsi + rax + 0]  , xmm9
                      movapd [rsi + rax + 16] , xmm13
                      movapd [rsi + rax + 32] , xmm15
                      movapd [rsi + rax + 48] , xmm14

                      mov    r8    , SRFFT_XORL
                      mov    r9    , SRFFT_0_38
                      mov    r10   , SRFFT_0_92
                      mov    rax   , SRFFT_0_70
                      movapd xmm15 , dqword [r8 + rdx]
                      movapd xmm12 , dqword [r9]
                      movapd xmm13 , dqword [r10]
                      movapd xmm14 , dqword [rax]

            ;0:  ((a-i) + (E-M))*1     +  ((A-I) - (e-m))*0        ((A-I) - (e-m))*1     -  ((a-i) + (E-M))*0
            ;1:  ((b-j) + (F-N))*0.92  +  ((B-J) - (f-n))*0.38     ((B-J) - (f-n))*0.92  -  ((b-j) + (F-N))*0.38
            ;2:  ((c-k) + (G-O))*0.7   +  ((C-K) - (g-o))*0.7      ((C-K) - (g-o))*0.7   -  ((c-k) + (G-O))*0.7
            ;3:  ((d-l) + (H-P))*0.38  +  ((D-L) - (h-p))*0.92     ((D-L) - (h-p))*0.38  -  ((d-l) + (H-P))*0.92

            ;4:  ((a-i) - (E-M))*1     -  ((A-I) + (e-m))*0        ((A-I) + (e-m))*1     +  ((a-i) - (E-M))*0
            ;5:  ((b-j) - (F-N))*0.92  -  ((B-J) + (f-n))*0.38     ((B-J) + (f-n))*0.92  +  ((b-j) - (F-N))*0.38
            ;6:  ((c-k) - (G-O))*0.7   -  ((C-K) + (g-o))*0.7      ((C-K) + (g-o))*0.7   +  ((c-k) - (G-O))*0.7
            ;7:  ((d-l) - (H-P))*0.38  -  ((D-L) + (h-p))*0.92     ((D-L) + (h-p))*0.38  +  ((d-l) - (H-P))*0.92

                      ;radix-4 decompositions of 16 points
                      xorpd  xmm4  , xmm15                 ;xmm4 -+(E-M)             +-(e-m)
                      xorpd  xmm5  , xmm15                 ;xmm5 -+(F-N)             +-(f-n)
                      xorpd  xmm6  , xmm15                 ;xmm6 -+(G-O)             +-(g-o)
                      xorpd  xmm7  , xmm15                 ;xmm7 -+(H-P)             +-(h-p)
                      shufpd xmm4  , xmm4 , 01b            ;xmm4 +-(e-m)             -+(E-M)
                      shufpd xmm5  , xmm5 , 01b            ;xmm5 +-(f-n)             -+(F-N)
                      shufpd xmm6  , xmm6 , 01b            ;xmm6 +-(g-o)             -+(G-O)
                      shufpd xmm7  , xmm7 , 01b            ;xmm7 +-(h-p)             -+(H-P)
                      movapd xmm8  , xmm0
                      subpd  xmm8  , xmm4                  ;xmm8   (A-I)-+(e-m)        (a-i)+-(E-M)
                      addpd  xmm0  , xmm4                  ;xmm0   (A-I)+-(e-m)        (a-i)-+(E-M)
                      movapd xmm9  , xmm1
                      subpd  xmm9  , xmm5                  ;xmm9   (B-J)-+(f-n)        (b-j)+-(F-N)
                      addpd  xmm1  , xmm5                  ;xmm1   (B-J)+-(f-n)        (b-j)-+(F-N)
                      movapd xmm10 , xmm2
                      subpd  xmm10 , xmm6                  ;xmm10  (C-K)-+(g-o)        (c-k)+-(G-O)
                      addpd  xmm2  , xmm6                  ;xmm2   (C-K)+-(g-o)        (c-k)-+(G-O)
                      mulpd  xmm10 , xmm14                 ;xmm10  ((C-K)-+(g-o))*0.7  ((c-k)+-(G-O))*0.7
                      mulpd  xmm2  , xmm14                 ;xmm2   ((C-K)+-(g-o))*0.7  ((c-k)-+(G-O))*0.7
                      movapd xmm11 , xmm3
                      subpd  xmm11 , xmm7                  ;xmm11  (D-L)-+(h-p)        (d-l)+-(H-P)
                      addpd  xmm3  , xmm7                  ;xmm3   (D-L)+-(h-p)        (d-l)-+(H-P)
                      ;free: xmm4-xmm7

                      movapd xmm4  , xmm13
                      mulpd  xmm4  , xmm1                  ;xmm4   cy                  cx
                      mulpd  xmm1  , xmm12                 ;xmm1   sy                  sx
                      xorpd  xmm1  , xmm15                 ;xmm1 -+sx                +-sy
                      shufpd xmm1  , xmm1 , 01b            ;xmm1 +-sy                -+sx
                      addpd  xmm1  , xmm4                  ;xmm1   cy+-sx              cx-+sy
                      movapd xmm5  , xmm2                  ;xmm5   vy                  vx
                      xorpd  xmm5  , xmm15                 ;xmm5 -+vy                +-vx
                      shufpd xmm5  , xmm5 , 01b            ;xmm5 +-vx                -+vy
                      addpd  xmm2  , xmm5                  ;xmm2   vy+-vx              vx+-vy
                      movapd xmm4  , xmm12
                      mulpd  xmm4  , xmm3                  ;xmm4   cy                  cx
                      mulpd  xmm3  , xmm13                 ;xmm3   sy                  sx
                      xorpd  xmm3  , xmm15                 ;xmm3 -+sx                +-sy
                      shufpd xmm3  , xmm3 , 01b            ;xmm3 +-sy                -+sx
                      addpd  xmm3  , xmm4                  ;xmm3   cy+-sx              cx-+sy
                      ;4 points: xmm0-xmm3

                      movapd xmm4  , xmm13
                      mulpd  xmm4  , xmm9                  ;xmm4   cy                  cx
                      mulpd  xmm9  , xmm12                 ;xmm9   sy                  sx
                      shufpd xmm9  , xmm9 , 01b            ;xmm9 +-sy                -+sx
                      xorpd  xmm9  , xmm15                 ;xmm9 -+sx                +-sy
                      addpd  xmm9  , xmm4                  ;xmm9   cy+-sx              cx-+sy
                      movapd xmm5  , xmm10                 ;xmm5   vy                  vx
                      shufpd xmm5  , xmm5 , 01b            ;xmm5 +-vx                -+vy
                      xorpd  xmm5  , xmm15                 ;xmm5 -+vy                +-vx
                      addpd  xmm10 , xmm5                  ;xmm10  vy+-vx              vx+-vy
                      movapd xmm4  , xmm12
                      mulpd  xmm4  , xmm11                 ;xmm4   cy                  cx
                      mulpd  xmm11 , xmm13                 ;xmm11  sy                  sx
                      shufpd xmm11 , xmm11, 01b            ;xmm11+-sy                -+sx
                      xorpd  xmm11 , xmm15                 ;xmm11-+sx                +-sy
                      addpd  xmm11 , xmm4                  ;xmm11  cy+-sx              cx-+sy
                      ;4 points: xmm8-xmm11

                      ;4-point ffts
                      movapd xmm4  , xmm0
                      addpd  xmm4  , xmm2                  ;xmm4   A+C          a+c
                      movapd xmm5  , xmm1
                      addpd  xmm5  , xmm3                  ;xmm5   B+D          b+d
                      subpd  xmm0  , xmm2                  ;xmm0   A-C          a-c
                      subpd  xmm1  , xmm3                  ;xmm1   B-D          b-d
                      shufpd xmm1  , xmm1 , 01b            ;xmm1   b-d          B-D
                      xorpd  xmm1  , xmm15                 ;xmm1 -+(b-d)      +-(B-D)
                      movapd xmm6  , xmm4
                      subpd  xmm6  , xmm5                  ;xmm6   A+C-B-D      a+c-b-d
                      addpd  xmm4  , xmm5                  ;xmm4   A+C+B+D      a+c+b+d
                      movapd xmm2  , xmm0
                      addpd  xmm2  , xmm1                  ;xmm2   (A-C)-+(b-d) (a-c)+-(B-D)
                      subpd  xmm0  , xmm1                  ;xmm0   (A-C)+-(b-d) (a-c)-+(B-D)

                      mov    r8    , r11
                      xor    r8    , 1
                      shl    r8    , 7

                      movapd xmm12 , xmm8
                      addpd  xmm12 , xmm10                 ;xmm12  A+C          a+c
                      movapd xmm13 , xmm9
                      addpd  xmm13 , xmm11                 ;xmm13  B+D          b+d
                      subpd  xmm8  , xmm10                 ;xmm8   A-C          a-c
                      subpd  xmm9  , xmm11                 ;xmm9   B-D          b-d
                      shufpd xmm9  , xmm9 , 01b            ;xmm9   b-d          B-D
                      xorpd  xmm9  , xmm15                 ;xmm9 -+(b-d)      +-(B-D)
                      movapd xmm14 , xmm12
                      subpd  xmm14 , xmm13                 ;xmm14  A+C-B-D      a+c-b-d
                      addpd  xmm12 , xmm13                 ;xmm12  A+C+B+D      a+c+b+d
                      movapd xmm10 , xmm8
                      addpd  xmm10 , xmm9                  ;xmm10  (A-C)-+(b-d) (a-c)+-(B-D)
                      subpd  xmm8  , xmm9                  ;xmm8   (A-C)+-(b-d) (a-c)-+(B-D)

                      movapd [rsi + r8] , xmm4
                      movapd [rsi + r8 + 16] , xmm6
                      movapd [rsi + r8 + 32] , xmm0
                      movapd [rsi + r8 + 48] , xmm2
                      movapd [rsi + r8 + 64] , xmm8
                      movapd [rsi + r8 + 80] , xmm10
                      movapd [rsi + r8 + 96] , xmm14
                      movapd [rsi + r8 + 112] , xmm12

                      ret
;------------------------------------------------------------------------------------




;------------------------------------------------------------------------------------
;8-POINT DIF FFT  (USES SPLIT-RADIX DIF DECOMPOSITION)
;IN:   rdx -  0/16  (fft/ifft)                               uses: rax,r8, xmm0-xmm15
;      rsi - *RI
;      r11 -  0/1   x
;
;OUT:  RI

align 16
_SRFFT8_DIF:
                      mov    rax   , SRFFT_XORL
                      mov    r8    , SRFFT_0_70
                      movapd xmm15 , dqword [rax + rdx]
                      movapd xmm14 , dqword [r8]

                      ;26     SIMD additions
                      ;2      SIMD multiplications
                      ;5+5    SIMD shuffles and xors
                      ;16 + 2 memory accesses

                      movapd xmm0  , [rsi]                 ;xmm0   A           a
                      movapd xmm1  , [rsi + 16]            ;xmm1   B           b
                      movapd xmm2  , [rsi + 32]            ;xmm2   C           c
                      movapd xmm3  , [rsi + 48]            ;xmm3   D           d
                      movapd xmm4  , [rsi + 64]            ;xmm4   E           e
                      movapd xmm5  , [rsi + 80]            ;xmm5   F           f
                      movapd xmm6  , [rsi + 96]            ;xmm6   G           g
                      movapd xmm7  , [rsi + 112]           ;xmm7   H           h

                      ;radix-2 decomposition of 8 points
                      movapd xmm8  , xmm0                  ;xmm8   A+E = W    a+e = w
                      addpd  xmm8  , xmm4
                      movapd xmm9  , xmm1                  ;xmm9   B+F = X    b+f = x
                      addpd  xmm9  , xmm5
                      movapd xmm10 , xmm2                  ;xmm10  C+G = Y    c+g = y
                      addpd  xmm10 , xmm6
                      movapd xmm11 , xmm3                  ;xmm11  D+H = Z    d+h = z
                      addpd  xmm11 , xmm7

                      ;        w + x + y + z    W + X + Y + Z
                      ;        (w-y) + (X-Z)    (W-Y) - (x-z)
                      ;        w - x + y - z    W - X + Y - Z
                      ;        (w-y) - (X-Z)    (W-Y) + (x-z)

                      ;4-point fft
                      movapd xmm12 , xmm8
                      addpd  xmm12 , xmm10                 ;xmm12  W+Y          w+y
                      movapd xmm13 , xmm9
                      addpd  xmm13 , xmm11                 ;xmm13  X+Z          x+z
                      subpd  xmm8  , xmm10                 ;xmm8   W-Y          w-y
                      subpd  xmm9  , xmm11                 ;xmm9   X-Z          x-z
                      shufpd xmm9  , xmm9  , 01b           ;xmm9   x-z          X-Z
                      xorpd  xmm9  , xmm15                 ;xmm9 -+(x-z)      +-(X-Z)
                      movapd xmm10 , xmm12
                      subpd  xmm10 , xmm13                 ;xmm10  W+Y-X-Z      w+y-x-z
                      addpd  xmm12 , xmm13                 ;xmm12  W+Y+X+Z      w+y+x+z
                      movapd xmm11 , xmm8
                      addpd  xmm11 , xmm9                  ;xmm11  (W-Y)-+(x-z) (w-y)+-(X-Z)
                      subpd  xmm8  , xmm9                  ;xmm8   (W-Y)+-(x-z) (w-y)-+(X-Z)

                      ;xmm12, 8, 10, 11

            ;0:  ((a-e) + (C-G))*1  +  ((A-E) - (c-g))*0    ((A-E) - (c-g))*1  -  ((a-e) + (C-G))*0
            ;1:  ((b-f) + (D-H))*0.7+  ((B-F) - (d-h))*0.7  ((B-F) - (d-h))*0.7-  ((b-f) + (D-H))*0.7

            ;2:  ((a-e) - (C-G))*1  -  ((A-E) + (c-g))*0    ((A-E) + (c-g))*1  +  ((a-e) - (C-G))*0
            ;3:  ((b-f) - (D-H))*0.7-  ((B-F) + (d-h))*0.7  ((B-F) + (d-h))*0.7+  ((b-f) - (D-H))*0.7

                      ;radix-4 decompositions of 8 points
                      subpd  xmm0  , xmm4                  ;xmm0   A-E                 a-e
                      subpd  xmm1  , xmm5                  ;xmm1   B-F                 b-f
                      subpd  xmm2  , xmm6                  ;xmm2   C-G                 c-g
                      xorpd  xmm2  , xmm15                 ;xmm2 -+(C-G)             +-(c-g)
                      shufpd xmm2  , xmm2 , 01b            ;xmm2 +-(c-g)             -+(C-G)
                      subpd  xmm3  , xmm7                  ;xmm3   D-H                 d-h
                      xorpd  xmm3  , xmm15                 ;xmm3 -+(D-H)             +-(d-h)
                      shufpd xmm3  , xmm3 , 01b            ;xmm3 +-(d-h)             -+(D-H)
                      movapd xmm4  , xmm0
                      subpd  xmm4  , xmm2                  ;xmm4   (A-E)+-(c-g)         (a-e)-+(C-G)
                      addpd  xmm0  , xmm2                  ;xmm0   (A-E)-+(c-g)         (a-e)+-(C-G)
                      movapd xmm5  , xmm1
                      subpd  xmm5  , xmm3                  ;xmm5   (B-F)-+(d-h)         (b-f)+-(d-h)
                      mulpd  xmm5  , xmm14                 ;xmm5   ((B-F)-+(d-h))*0.7   ((b-f)+-(d-h))*0.7
                      addpd  xmm1  , xmm3                  ;xmm1   (B-F)+-(d-h)         (b-f)-+(d-h)
                      mulpd  xmm1  , xmm14                 ;xmm1   ((B-F)+-(d-h))*0.7   ((b-f)-+(d-h))*0.7

                      movapd xmm2  , xmm1
                      xorpd  xmm2  , xmm15
                      shufpd xmm2  , xmm2 , 01b
                      addpd  xmm2  , xmm1
                      movapd xmm3  , xmm5
                      shufpd xmm3  , xmm3 , 01b
                      xorpd  xmm3  , xmm15
                      addpd  xmm3  , xmm5

                      ;2-point ffts
                      movapd xmm5  , xmm0
                      subpd  xmm5  , xmm2
                      addpd  xmm0  , xmm2
                      movapd xmm6  , xmm4
                      subpd  xmm6  , xmm3
                      addpd  xmm4  , xmm3

                      mov    r8    , r11
                      imul   r8    , 112
                      mov    r9    , r11
                      imul   r9    , 80
                      add    r9    , 16
                      mov    r10   , r11
                      shl    r10   , 5
                      mov    rax   , r11
                      xor    rax   , 1
                      shl    rax   , 6

                      movapd [rsi + r8]  , xmm12
                      movapd [rsi + r9]  , xmm10
                      movapd [rsi + r10 + 32] , xmm8
                      movapd [rsi + r10 + 48] , xmm11
                      movapd [rsi + rax + 0]  , xmm0
                      movapd [rsi + rax + 16] , xmm5
                      movapd [rsi + rax + 32] , xmm6
                      movapd [rsi + rax + 48] , xmm4

                      ret
;------------------------------------------------------------------------------------




;------------------------------------------------------------------------------------
;4-POINT DIF FFT
;IN:   rdx -  0/16  (fft/ifft)                               uses: rax,r8, xmm0-xmm15
;      rsi - *RI
;      r11 -  0/1   x
;
;OUT:  RI

align 16
_SRFFT4_DIF:
                      mov    rax   , SRFFT_XORL
                      movapd xmm15 , dqword [rax + rdx]

                      mov    rax   , r11
                      shl    rax   , 5
                      lea    r8    , [rsi + 32]

                      ;8   SIMD additions
                      ;0   SIMD multiplications
                      ;1+1 SIMD shuffles and xors
                      ;8   memory accesses

                      ;0:  a + b + c + d       A + B + C + D
                      ;1:  (a-c) + (B-D)       (A-C) - (b-d)
                      ;2:  a - b + c - d       A - B + C - D
                      ;3:  (a-c) - (B-D)       (A-C) + (b-d)

                      movapd xmm0  , [rsi]                 ;xmm0   A            a
                      movapd xmm1  , [rsi + 16]            ;xmm1   B            b
                      movapd xmm2  , [rsi + 32]            ;xmm2   C            c
                      movapd xmm3  , [rsi + 48]            ;xmm3   D            d
                      movapd xmm4  , xmm0
                      addpd  xmm4  , xmm2                  ;xmm4   A+C          a+c
                      movapd xmm5  , xmm1
                      addpd  xmm5  , xmm3                  ;xmm5   B+D          b+d
                      subpd  xmm0  , xmm2                  ;xmm0   A-C          a-c
                      subpd  xmm1  , xmm3                  ;xmm1   B-D          b-d
                      shufpd xmm1  , xmm1 , 01b            ;xmm1   b-d          B-D
                      xorpd  xmm1  , xmm15                 ;xmm1 -+(b-d)      +-(B-D)

                      add    rsi   , rax
                      sub    r8    , rax

                      movapd xmm6  , xmm4
                      subpd  xmm6  , xmm5                  ;xmm6   A+C-B-D      a+c-b-d
                      addpd  xmm4  , xmm5                  ;xmm4   A+C+B+D      a+c+b+d
                      movapd xmm2  , xmm0
                      addpd  xmm2  , xmm1                  ;xmm2   (A-C)-+(b-d) (a-c)+-(B-D)
                      subpd  xmm0  , xmm1                  ;xmm0   (A-C)+-(b-d) (a-c)-+(B-D)
                      movapd [rsi + 0]  , xmm4
                      movapd [rsi + 16] , xmm6
                      movapd [r8  + 0]  , xmm0
                      movapd [r8  + 16] , xmm2

                      sub    rsi   , rax

                      ret
;------------------------------------------------------------------------------------




;------------------------------------------------------------------------------------
;2-POINT DIF FFT
;IN:   rdx -  0/16  (fft/ifft)                               uses: rax,r8, xmm0-xmm15
;      rsi - *RI
;      r11 -  0/1   x
;
;OUT:  RI

align 16
_SRFFT2_DIF:
                      ;2   SIMD additions
                      ;0   SIMD multiplications
                      ;0+0 SIMD shuffles and xors
                      ;4   memory accesses

                      mov    rax   , r11
                      shl    rax   , 4
                      lea    r8    , [rsi + 16]

                      ;0:  a + b               A + B
                      ;1:  a - b               A - B

                      movapd xmm0  , [rsi]
                      movapd xmm1  , [rsi + 16]
                      movapd xmm2  , xmm0
                      subpd  xmm2  , xmm1

                      add    rsi   , rax
                      sub    r8    , rax

                      addpd  xmm0  , xmm1
                      movapd [rsi] , xmm0
                      movapd [r8]  , xmm2

                      sub    rsi   , rax

                      ret
;------------------------------------------------------------------------------------
















;------------------------------------------------------------------------------------
;[section .data align=16]
align 16

SRFFT_1_0       dq  1.0                  , 0.0
SRFFT_XORL      dq  0x8000000000000000   , 0
                dq  0                    , 0x8000000000000000

SRFFT_0_38      dq  0.382683432365089772 ,  0.382683432365089772
SRFFT_0_70      dq  0.707106781186547524 ,  0.707106781186547524
SRFFT_0_92      dq  0.923879532511286756 ,  0.923879532511286756

SRFFT_SINCOS    dq  0.980785280403230449 , -0.195090322016128268  ;5  sincos(-pi/2*1/(l/4))
                dq  0.995184726672196886 , -0.098017140329560602  ;
                dq  0.998795456205172393 , -0.049067674327418014  ;
                dq  0.99969881869620422  , -0.024541228522912288  ;
                dq  0.999924701839144541 , -0.012271538285719926  ;
                dq  0.999981175282601143 , -0.006135884649154475  ;
                dq  0.999995293809576172 , -0.003067956762965976  ;
                dq  0.99999882345170191  , -0.001533980186284766  ;
                dq  0.999999705862882219 , -0.000766990318742705  ;
                dq  0.999999926465717851 , -0.000383495187571396  ;
                dq  0.999999981616429294 , -0.000191747597310703  ;
                dq  0.999999995404107313 , -0.000095873799095977  ;16
                dq  0.999999998851026828 , -0.000047936899603067  ;
                dq  0.999999999712756707 , -0.000023968449808418  ;
                dq  0.999999999928189177 , -0.00001198422490507   ;
                dq  0.999999999982047294 , -0.000005992112452642  ;
                dq  0.999999999995511824 , -0.000002996056226335  ;
                dq  0.999999999998877956 , -0.000001498028113169  ;
                dq  0.999999999999719489 , -0.000000749014056585  ;
                dq  0.999999999999929872 , -0.000000374507028292  ;24

SRFFT_DIF_CALL  dq  _SRFFT2_DIF, _SRFFT4_DIF, _SRFFT8_DIF, _SRFFT16_DIF

;__SECT__
;------------------------------------------------------------------------------------








