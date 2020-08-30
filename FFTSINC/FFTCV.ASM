
; THIS FILE IS PART OF THE 'FFT CONVOLUTION KERNEL' LIBRARY SOURCE CODE
; COPYRIGHT (C) 2010 Akos Mogyorosi <flowwolf>
; FOR DETAILS SEE THE FILE README

; FFT CONVOLUTION KERNEL  19/06/2010

;fftcv_init
;fftcv_deinit
;fftcv_calc_coeffs
;fftcv_set_coeffs
;fftcv_use_coeffs
;fftcv_use_complex_coeffs
;fftcv_process
;fftcv_flush
;fftcv_set_state
;fftcv_set_attribute


;------------------------------------------------------------------------------------
;FFT CONVOLUTION INIT
;IN:   rcx - *fftcviface                                                      uses: -
;      rdx -  max length
;
;OUT:  rax -  fftcv_lasterror
;
;NOTE: every successful call to fftcv_init involves a call to fftcv_deinit

fftcv_init:
                      push   r10, r9, r8, rdx, rcx

                      xchg   rcx , r8                      ;r8  - *fftcviface

                      lea    rax , [rdx - 2]
                      bsr    rcx , rax
                      inc    rcx
                      inc    rcx
                      xor    eax , eax
                      inc    eax
                      shl    eax , cl
                      imul   eax , 4 +4 +8*2 +8*2 +8*2 +8*2
                      xchg   rcx , r9

                      ;xor    eax , eax  ;all x64 support SSE2
                      ;inc    eax
                      ;push   rbx
                      ;cpuid
                      ;pop    rbx
                      ;bt     edx , 26
                      ;mov    rax , FFTCV_ERR_SSE2_NOT_SUPPORTED
                      ;jnc    .err
                      lea    ecx , [eax + fftcv_infoblocksize + 16 + 16]
                      call   memallocz


                      test   rax , rax
                      jnz    .sk10
             .errm:   mov    rax , FFTCV_ERR_NOT_ENOUGH_MEMORY
              .err:
                      pop    rcx, rdx, r8, r9, r10
                      ret
             .sk10:
                      mov    rcx , rax
                      test   al  , 15
                      jz     .sk12
                      and    al  , 15 xor -1
                      add    rax , 16
             .sk12:   mov    [rax + fftcv_infoblock], rcx

                      mov    [r8], rax

                      ;push   rax rbx
                      ;mov    rbx , [general_info_base]
                      ;imul   rbx , process_info_step
                      ;mov    rbx , [process_info_base+rbx+256]
                      ;sub    rax , rbx
                      ;mov    [r8], rax
                      ;pop    rbx rax

                      xchg   rax , r10                     ;r10 -  fftcviface
                      xchg   rcx , r9

                      mov    [r10 + fftcv_maxlength], edx
                      xor    eax , eax
                      inc    eax
                      shl    eax , cl
                      mov    [r10 + fftcv_maxn], ecx
                      mov    [r10 + fftcv_max2n], eax

                      lea    rdx , [r10 + fftcv_area]      ;buffers
                      mov    [r10 + fftcv_convbuff], rdx
                      lea    rdx , [rdx + rax*4]
                      mov    [r10 + fftcv_outbuff], rdx
                      lea    rdx , [rdx + rax*4]
                      mov    [r10 + fftcv_fftbuff], rdx
                      lea    rdx , [rdx + rax*8]
                      lea    rdx , [rdx + rax*8]
                      mov    [r10 + fftcv_fftbufffil], rdx
                      lea    rdx , [rdx + rax*8]
                      lea    rdx , [rdx + rax*8]
                      mov    [r10 + fftcv_fftbufffilc], rdx
                      lea    rdx , [rdx + rax*8]
                      lea    rdx , [rdx + rax*8]
                      mov    [r10 + fftcv_auxbuffer], rdx

                      call   fft4_create

                      test   rax , rax
                      jnz    .sk14
                      mov    rcx , [r10 + fftcv_infoblock]
                      call   memfree
                      jmp    .errm
             .sk14:   mov    [r10 + fftcv_ffttab], rax

                      mov    rax , 4.71238898038468986
                      mov    [r10 + fftcv_kbdwin + 0], rax
                      mov    [r10 + fftcv_kbdwin + 8], rax
                      mov    rax , 1.0
                      mov    [r10 + fftcv_expwin + 0], rax
                      mov    [r10 + fftcv_expwin + 8], rax

                      xor    eax , eax
                      pop    rcx, rdx, r8, r9, r10
                      ret
;------------------------------------------------------------------------------------




;------------------------------------------------------------------------------------
;FFT CONVOLUTION DEINIT
;IN:   rcx -  fftcviface                                                      uses: -
;
;OUT:  rax -  FFTCV_ERR_OK

fftcv_deinit:
                      push   rbp, rcx

                      xchg   rcx , rbp                     ;rbp -  fftcviface

                      mov    rcx , [rbp + fftcv_ffttab]
                      call   fft4_destroy
                      mov    rcx , [rbp + fftcv_infoblock]
                      call   memfree

                      xor    eax , eax
                      pop    rcx, rbp
                      ret
;------------------------------------------------------------------------------------




;------------------------------------------------------------------------------------
;FFT CONVOLUTION CALCULATE COEFFICIENTS
;IN:   rcx -  fftcviface                                                      uses: -
;      rdx -  n (fft length 2^n) << 32  +  numbands
;      r8  - *bandindices
;      r9  - *bandgains
;      r10 - *phasetab
;
;OUT:  rax -  FFTCV_ERR_OK

fftcv_calc_coeffs:
                      push   r11, r8, rdi, rsi, rbp, rdx, rcx

                      xchg   rcx , rbp                     ;rbp -  fftcviface
                      xchg   r10 , r11                     ;r11 - *phasetab
                      mov    rdi , [rbp + fftcv_fftbufffilc]
                      fxsave [rbp + fftcv_fpummxssestatec]

                      test   edx , edx
                      jns    .sk00
                      not    edx
                      shl    edx , 4
                      mov    rax , fftcv_bandindices
                      mov    r8  , [rax + rdx]
                      mov    rdx , [rax + rdx + 8]
             .sk00:
                      xor    r10 , r10                     ;r10 -  2^n
                      inc    r10
                      mov    rcx , rdx
                      shr    rcx , 32
                      shl    r10 , cl
                      inc    ecx
                      mov    [rbp + fftcv_newn], ecx
                      lea    rax , [r10 + 1]
                      mov    [rbp + fftcv_newlength], eax
                      lea    rax , [r10 * 2]
                      mov    [rbp + fftcv_new2n], eax

                      cvtss2sd xmm4 , [r11]                ;xmm4   y0
                      unpcklpd xmm4 , xmm4
                      cvtss2sd xmm4 , [r9]                 ;xmm4   y0
                      movapd xmm5 , xmm4                   ;xmm5   y1
                      movapd xmm6 , xmm4                   ;xmm6   y2
                      xor    eax , eax
                      inc    eax
                      cvtsi2sd xmm9 , eax                  ;xmm9   1
                      unpcklpd xmm9 , xmm9
                      inc    eax
                      cvtsi2sd xmm0 , eax
                      xorpd  xmm14, xmm14                  ;xmm14  bias
                      movsd  xmm15, xmm9
                      subsd  xmm15, xmm9                   ;tension = 1.0
                      divsd  xmm15, xmm0                   ;xmm15  (1-tension)/2
                      unpcklpd xmm15, xmm15
                      xor    ecx , ecx
             .lp10:   lea    eax , [edx-2]
                      cmp    eax , ecx
                      cmova  eax , ecx
                      cvtss2sd xmm7 , [r11 + rax*4 + 4]    ;xmm7   y2  y3
                      unpcklpd xmm7 , xmm7
                      cvtss2sd xmm7 , [r9 + rax*4 + 4]     ;xmm7   y2  y3
                      movapd xmm3 , xmm5                   ;
                      subpd  xmm3 , xmm4                   ;xmm1   (y1 - y0)
                      movapd xmm1 , xmm9                   ;
                      addpd  xmm1 , xmm14                  ;xmm3   (1 + bias)
                      mulpd  xmm1 , xmm3                   ;xmm3   (y1 - y0) * (1 + bias)
                      mulpd  xmm1 , xmm15                  ;xmm3   (y1 - y0) * (1 + bias) * (1-tension)/2
                      movapd xmm3 , xmm6                   ;
                      subpd  xmm3 , xmm5                   ;xmm0   (y2 - y1)
                      movapd xmm0 , xmm9                   ;
                      subpd  xmm0 , xmm14                  ;xmm3   (1 - bias)
                      mulpd  xmm0 , xmm3                   ;xmm3   (y2 - y1) * (1 - bias)
                      mulpd  xmm0 , xmm15                  ;xmm3   (y2 - y1) * (1 - bias) * (1-tension)/2
                      addpd  xmm0 , xmm1
                      movapd xmm3 , xmm6                   ;
                      subpd  xmm3 , xmm5                   ;xmm2   (y2 - y1)
                      movapd xmm2 , xmm9                   ;
                      addpd  xmm2 , xmm14                  ;xmm3   (1 + bias)
                      mulpd  xmm2 , xmm3                   ;xmm3   (y2 - y1) * (1 + bias)
                      mulpd  xmm2 , xmm15                  ;xmm3   (y2 - y1) * (1 + bias) * (1-tension)/2
                      movapd xmm3 , xmm7                   ;
                      subpd  xmm3 , xmm6                   ;xmm1   (y3 - y2)
                      movapd xmm1 , xmm9                   ;
                      subpd  xmm1 , xmm14                  ;xmm3   (1 - bias)
                      mulpd  xmm1 , xmm3                   ;xmm3   (y3 - y2) * (1 - bias)
                      mulpd  xmm1 , xmm15                  ;xmm3   (y3 - y2) * (1 - bias) * (1-tension)/2
                      addpd  xmm1 , xmm2
                      xor    eax , eax
                      test   ecx , ecx
                      cmovnz eax , [r8 + rcx*4 - 4]
                      mov    rsi , r10
                      shr    esi , 1
                      inc    esi
                      cmp    ecx , edx
                      cmovnz esi , [r8 + rcx*4]
                      sub    esi , eax                     ;rsi -  dist
                      jz     .sk12
                      cvtsi2sd xmm12 , esi
                      movsd  xmm11, xmm9
                      divsd  xmm11, xmm12                  ;xmm11  1/dist
                      unpcklpd xmm11 , xmm11
                      xorpd  xmm12, xmm12                  ;xmm12  0
             .lp12:   xorpd  xmm8 , xmm8                   ;xmm8   0
                      movapd xmm2 , xmm12                  ;
                      mulpd  xmm2 , xmm12                  ;
                      movapd xmm3 , xmm2                   ;xmm2   x^2
                      mulpd  xmm3 , xmm12                  ;xmm3   x^3
                      movapd xmm10, xmm3                   ;
                      addpd  xmm10, xmm3                   ;
                      subpd  xmm10, xmm2                   ;
                      subpd  xmm10, xmm2                   ;
                      subpd  xmm10, xmm2                   ;
                      addpd  xmm10, xmm9                   ;
                      mulpd  xmm10, xmm5                   ;xmm10  (2*x^3 - 3*x^2 + 1) * y1
                      addpd  xmm8 , xmm10
                      movapd xmm10, xmm3                   ;
                      subpd  xmm10, xmm2                   ;
                      subpd  xmm10, xmm2                   ;
                      addpd  xmm10, xmm12                  ;
                      mulpd  xmm10, xmm0                   ;xmm10  (x^3 - 2*x^2 + x) * xmm0
                      addpd  xmm8 , xmm10
                      movapd xmm10, xmm3                   ;
                      subpd  xmm10, xmm2                   ;
                      mulpd  xmm10, xmm1                   ;xmm10  (x^3 - x^2) * xmm1
                      addpd  xmm8 , xmm10
                      xorpd  xmm10, xmm10                  ;
                      subpd  xmm10, xmm3                   ;
                      subpd  xmm10, xmm3                   ;
                      addpd  xmm10, xmm2                   ;
                      addpd  xmm10, xmm2                   ;
                      addpd  xmm10, xmm2                   ;
                      mulpd  xmm10, xmm6                   ;xmm10  (-2*x^3 + 3*x^2) * y2
                      addpd  xmm8 , xmm10
                      addpd  xmm12, xmm11
                      movapd [rdi], xmm8
                      add    rdi , 16
                      dec    esi
                      jnz    .lp12
             .sk12:   movapd xmm4 , xmm5
                      movapd xmm5 , xmm6
                      movapd xmm6 , xmm7
                      inc    ecx
                      cmp    ecx , edx
                      jbe    .lp10

                      fninit                               ;phase shift
                      fld    Q [fftcv__piper180]     ;p
                      mov    rsi , [rbp + fftcv_fftbufffilc]
                      mov    rcx , r10
                      shr    rcx , 1
                      inc    rcx
             .lp24:   fld    Q [rsi]
                      fld    Q [rsi + 8]                   ;phase mag p
                      fmul   st0 , st2                     ;phase*p mag p
                      fsincos                              ;cos sin mag p
                      fmul   st0 , st2
                      fstp   Q [rsi]
                      fmulp  st1 , st0
                      fstp   Q [rsi + 8]
                      add    rsi , 16
                      loop   .lp24

                      lea    rsi , [rdi - 32]              ;negative
                      mov    rcx , r10
                      shr    ecx , 1
                      dec    ecx
                      mov    al  , 0x80
                      movd   xmm1 , eax
                      pslldq xmm1 , 15
             .lp20:   movapd xmm0 , [rsi]
                      xorpd  xmm0 , xmm1
                      movapd [rdi], xmm0
                      sub    rsi , 16
                      add    rdi , 16
                      loop   .lp20

                      mov    rcx , rdx                     ;inverse FFT
                      shr    rcx , 32
                      mov    rdi , [rbp + fftcv_fftbufffilc]
                      mov    r8  , [rbp + fftcv_ffttab]
                      xor    r9  , r9
                      xchg   rdx , rdi
                      call   ifft4
                      xchg   rdx , rdi

                      mov    rcx , r10                     ;create window
                      shl    rcx , 4
                      lea    rcx , [rdi + rcx]
                      lea    rax , [r10 + 1]
                      mov    r8  , (50 shl 32) + 0+2
                      movlpd xmm0 , [rbp + fftcv_kbdwin + 8]
                      xchg   rax , rdx
                      call   create_window_kaiser
                      xchg   rax , rdx
                      lea    rcx , [rcx + r10*2]
                      mov    r8  , (50 shl 32) + 1+2
                      movlpd xmm0 , [rbp + fftcv_kbdwin + 0]
                      xchg   rax , rdx
                      call   create_window_kaiser
                      xchg   rax , rdx

                      mov    rcx , r10                     ;exp
                      shl    rcx , 4
                      lea    rcx , [rdi + rcx]
                      mov    rsi , r10
                      shr    rsi , 1
                      lea    r8  , [rcx + rsi*4 + 4]
                      fninit
                      fld    Q [rbp + fftcv_expwin + 0]
                      fld    Q [rbp + fftcv_expwin + 8]
                      xor    eax , eax
             .lp30:   fld    D [rcx + rax*4]
                      fldz
                      fcomip st1
                      jz     .sk30
                      fld    st1
                      fyl2x
                      fld1
                      fld    st1
                      fprem
                      f2xm1
                      faddp  st1 , st0
                      fscale
                      fstp   D [rcx + rax*4]
             .sk30:   fld    D [r8  + rax*4]
                      fldz
                      fcomip st1
                      jz     .sk32
                      fld    st3
                      fyl2x
                      fld1
                      fld    st1
                      fprem
                      f2xm1
                      faddp  st1 , st0
                      fscale
                      fstp   D [r8  + rax*4]
             .sk32:   fcompp
                      inc    eax
                      cmp    eax , esi
                      jnz    .lp30
                      fcompp

                      mov    rsi , rcx
                      mov    rcx , r10                     ;normalize, window and reorder
                      shr    rcx , 2
                      or     rax , -1
                      movq   xmm4 , rax
                      neg    rax
                      cvtsi2sd xmm5 , rax
                      cvtsi2sd xmm6 , r10
                      divsd  xmm5 , xmm6
             .lp40:   movapd xmm0 , [rdi]
                      movapd xmm1 , [rdi + 16]
                      movapd xmm2 , [rdi + r10*8]
                      movapd xmm3 , [rdi + r10*8 + 16]
                      andpd  xmm0 , xmm4
                      mulsd  xmm0 , xmm5
                      andpd  xmm1 , xmm4
                      mulsd  xmm1 , xmm5
                      andpd  xmm2 , xmm4
                      mulsd  xmm2 , xmm5
                      andpd  xmm3 , xmm4
                      mulsd  xmm3 , xmm5
                      movlps xmm6 , [rsi]
                      movlps xmm7 , [rsi + r10*2]
                      cvtps2pd xmm6 , xmm6
                      cvtps2pd xmm7 , xmm7
                      mulsd  xmm0 , xmm6
                      mulsd  xmm2 , xmm7
                      unpckhpd xmm6 , xmm6
                      unpckhpd xmm7 , xmm7
                      mulsd  xmm1 , xmm6
                      mulsd  xmm3 , xmm7
                      movapd [rdi], xmm2
                      movapd [rdi + 16], xmm3
                      movapd [rdi + r10*8], xmm0
                      movapd [rdi + r10*8 + 16], xmm1
                      add    rsi , 8
                      add    rdi , 32
                      loop   .lp40

                      mov    rcx , r10                     ;zero extend
                      mov    rsi , [rbp + fftcv_fftbufffilc]
                      movapd xmm0 , [rsi]
             .lp44:   movapd [rdi + r10*8], xmm0
                      xorpd  xmm0 , xmm0
                      add    rdi , 16
                      loop   .lp44

                      mov    rcx , rdx                     ;forward FFT
                      shr    rcx , 32
                      inc    rcx
                      mov    r8  , [rbp + fftcv_ffttab]
                      xor    r9  , r9
                      xchg   rdx , rsi
                      call   fft4
                      xchg   rdx , rsi

                      xchg   r10 , r11
                      fxrstor [rbp + fftcv_fpummxssestatec]

                      xor    eax , eax
                      pop    rcx, rdx, rbp, rsi, rdi, r8, r11
                      ret
;------------------------------------------------------------------------------------




;------------------------------------------------------------------------------------
;FFT CONVOLUTION SET COEFFICIENTS
;IN:   rcx -  fftcviface src                                                  uses: -
;      rdx -  fftcviface dst
;
;OUT:  rax -  fftcv_lasterror

fftcv_set_coeffs:
                      push   r8, rdi, rsi

                      mov    rax , [rcx + fftcv_maxn]
                      cmp    rax , [rdx + fftcv_maxn]
                      mov    rax , FFTCV_ERR_INVALID_OPERATION
                      jb     .err

                      xchg   rcx , r8                      ;r8  -  fftcviface src
                      fxsave [r8 + fftcv_fpummxssestatec]

                      mov    rsi , [r8  + fftcv_fftbufffilc]
                      mov    rdi , [rdx + fftcv_fftbufffil]
                      mov    rcx , [r8  + fftcv_new2n]

             .lp10:   movapd xmm0 , [rsi]
                      movapd [rdi], xmm0
                      add    rsi , 16
                      add    rdi , 16
                      loop   .lp10

                      mov    rax , [r8  + fftcv_newn]
                      mov    [rdx + fftcv_n], rax
                      mov    rax , [r8  + fftcv_new2n]
                      mov    [rdx + fftcv_2n], rax
                      mov    rax , [r8  + fftcv_newlength]
                      mov    [rdx + fftcv_length], rax

                      mov    eax , [rdx + fftcv_prevn]
                      test   eax , eax
                      cmovz  eax , [rdx + fftcv_n]
                      mov    [rdx + fftcv_prevn],eax
                      mov    eax , [rdx + fftcv_prev2n]
                      test   eax , eax
                      cmovz  eax , [rdx + fftcv_2n]
                      mov    [rdx + fftcv_prev2n],eax

                      fxrstor [r8 + fftcv_fpummxssestatec]
                      xchg   rcx , r8

                      xor    eax , eax
              .err:   pop    rsi, rdi, r8
                      ret
;------------------------------------------------------------------------------------




;------------------------------------------------------------------------------------
;FFT CONVOLUTION USE COEFFICIENTS
;IN:   rcx -  fftcviface                                                      uses: -
;      rdx - *impulse
;      r8  -  (length << 32)  +  in format
;
;OUT:  rax -  fftcv_lasterror

fftcv_use_coeffs:
                      push   r9, r8, rdi, rsi, rbp, rdx

                      xchg   rcx , rbp                     ;rbp -  fftcviface
                      fxsave [rbp + fftcv_fpummxssestatec]

                      mov    r9d , r8d                     ;r9  -  in format
                      shr    r8  , 32                      ;r8  -  length
                      cmp    r8d , [rbp + fftcv_maxlength]
                      mov    rax , FFTCV_ERR_INVALID_OPERATION
                      ja     .err

                      lea    rax , [r8 - 2]
                      bsr    rcx , rax
                      inc    rcx
                      xor    eax , eax
                      inc    eax
                      shl    eax , cl
                      inc    eax
                      inc    ecx
                      mov    [rbp + fftcv_newn], ecx
                      mov    [rbp + fftcv_newlength], eax
                      lea    ecx , [eax*2 - 2]
                      mov    [rbp + fftcv_new2n], ecx

                      mov    rcx , rdx                     ;convert to internal
                      mov    rdx , [rbp + fftcv_max2n]
                      shl    rdx , 3
                      add    rdx , [rbp + fftcv_fftbufffilc]
                      call   sampconv_to_internal

                      lea    rdi , [rdx + r8*4]            ;zero fix
                      xorps  xmm4 , xmm4
                      movups [rdi], xmm4

                      mov    rsi , rdx                     ;-> double
                      mov    rdi , [rbp + fftcv_fftbufffilc]
                      mov    rcx , r8
                      shr    rcx , 2
                      inc    rcx
             .lp10:   movaps xmm0 , [rsi]                  ;xmm0  d  c  b  a
                      movhlps xmm2 , xmm0                  ;xmm2  x  x  d  c
                      cvtps2pd xmm0 , xmm0                 ;xmm0     b     a
                      cvtps2pd xmm2 , xmm2                 ;xmm2     d     c
                      movapd xmm1 , xmm0                   ;xmm1     b     a
                      movapd xmm3 , xmm2                   ;xmm3     d     c
                      unpcklpd xmm0 , xmm4                 ;xmm0     -     a
                      unpckhpd xmm1 , xmm4                 ;xmm1     -     b
                      unpcklpd xmm2 , xmm4                 ;xmm2     -     c
                      unpckhpd xmm3 , xmm4                 ;xmm3     -     d
                      movapd [rdi], xmm0
                      movapd [rdi + 16], xmm1
                      movapd [rdi + 32], xmm2
                      movapd [rdi + 48], xmm3
                      add    rsi , 16
                      add    rdi , 64
                      loop   .lp10

                      mov    rdi , r8                       ;zero expand
                      shl    rdi , 4
                      add    rdi , [rbp + fftcv_fftbufffilc]
                      mov    ecx , [rbp + fftcv_new2n]
                      sub    rcx , r8
             .lp12:   movapd [rdi], xmm4
                      add    rdi , 16
                      loop   .lp12

                      mov    ecx , [rbp + fftcv_newn]       ;forward FFT
                      mov    rdx , [rbp + fftcv_fftbufffilc]
                      mov    r8  , [rbp + fftcv_ffttab]
                      xor    r9  , r9
                      call   fft4

                      mov    rdi , rdx                      ;normalize
                      mov    ecx , [rbp + fftcv_new2n]
                      cvtsi2sd xmm2 , rcx
                      xor    eax , eax
                      inc    eax
                      cvtsi2sd xmm1 , eax
                      divsd  xmm1 , xmm2
                      unpcklpd xmm1 , xmm1
             .lp20:   movapd xmm0 , [rdi]
                      mulpd  xmm0 , xmm1
                      movapd [rdi], xmm0
                      add    rdi , 16
                      loop   .lp20

                      xor    eax , eax
              .err:   fxsave [rbp + fftcv_fpummxssestatec]
                      xchg   rcx , rbp

                      pop    rdx, rbp, rsi, rdi, r8, r9
                      ret
;------------------------------------------------------------------------------------




;------------------------------------------------------------------------------------
;FFT CONVOLUTION USE COMPLEX COEFFICIENTS
;IN:   rcx -  fftcviface                                                      uses: -
;      rdx - *RI   (interleaved real & imaginary array, double)
;      r8  -  fft length n
;
;OUT:  rax -  fftcv_lasterror

fftcv_use_complex_coeffs:
                      push   rdi, rsi, rbp, rcx

                      xchg   rcx , rbp                     ;rbp -  fftcviface

                      mov    rax , [rbp + fftcv_maxn]
                      cmp    rax , r8
                      mov    rax , FFTCV_ERR_INVALID_OPERATION
                      jb     .err

                      fxsave [rbp + fftcv_fpummxssestate]

                      mov    rcx , r8
                      xor    eax , eax
                      inc    eax
                      shl    eax , cl
                      mov    [rbp + fftcv_newn], rcx
                      mov    [rbp + fftcv_new2n], rax
                      shr    rax , 1
                      inc    rax
                      mov    [rbp + fftcv_newlength], rax

                      mov    rsi , rdx
                      mov    rdi , [rbp + fftcv_fftbufffilc]
                      mov    rcx , [rbp + fftcv_new2n]

             .lp10:   movapd xmm0 , [rsi]
                      movapd [rdi], xmm0
                      add    rsi , 16
                      add    rdi , 16
                      loop   .lp10

                      fxrstor [rbp + fftcv_fpummxssestate]

                      xor    eax , eax
              .err:   pop    rcx, rbp, rsi, rdi
                      ret
;------------------------------------------------------------------------------------




;------------------------------------------------------------------------------------
;FFT CONVOLUTION PROCESS
;IN:   rcx -  fftcviface                                                      uses: -
;      rdx - *in
;      r8  - *out
;      r9  -  number of samples  or -1/-2 for  trailing delay / delay length
;      r10 -  in format << 32  +  out format
;
;OUT:  rax -  number of samples processed

fftcv_process:
                      push   r12, r11, r8, rdi, rsi, rbp, rbx, rdx, rcx

                      xchg   rcx , rbp                     ;rbp -  fftcviface
                      xchg   rdx , rsi                     ;rsi - *in
                      xchg   r8  , rbx                     ;rbx - *out
                      mov    rdx , r9                      ;rdx -  number of samples
                      xor    r12 , r12                     ;r12 -  number of samples processed

                      fxsave [rbp + fftcv_fpummxssestate]

                      mov    ecx , [rbp + fftcv_length]
                      dec    ecx
                      shr    ecx , 1
                      neg    ecx
                      xor    eax , eax
                      test   D [rbp + fftcv_state], FFTCV_ST_LEADING_DELAY
                      setnz  al
                      imul   eax , ecx
                      test   rdx , rdx
                      cmovns eax , edx
                      add    [rbp + fftcv_inlen], eax      ;total input len
             .lp10:
             .lp12:   mov    edi , [rbp + fftcv_convbuffpos]
                      shl    edi , 2
                      add    rdi , [rbp + fftcv_convbuff]
                      test   rdx , rdx
                      jz     .end
                      jns    .sk10
                      mov    eax , [rbp + fftcv_length]
                      dec    eax
                      shr    eax , 1
                      cmp    rdx , -2
                      cmovz  r12 , rax
                      jz     .end
                      mov    ecx , [rbp + fftcv_2n]        ;clear convbuff if rdx=-1
                      sub    ecx , [rbp + fftcv_convbuffpos]
                      xor    eax , eax
                      rep stosd
                      jmp    .sk12
             .sk10:
                      ;convert to internal 32-bit
                      mov    ecx , [rbp + fftcv_2n]
                      inc    ecx
                      sub    ecx , [rbp + fftcv_length]
                      sub    ecx , [rbp + fftcv_convbuffpos]
                      cmp    ecx , edx
                      cmova  ecx , edx                     ;ecx -  samples to convert
                      sub    edx , ecx
                      mov    r11 , r10
                      shr    r11 , 32
                      xchg   r9  , r11
                      mov    r8  , rcx
                      xchg   rcx , rsi
                      xchg   rdx , rdi
                      call   sampconv_to_internal
                      xchg   rcx , rsi
                      xchg   rdx , rdi
                      xchg   r9  , r11
                      add    rsi , rax
                      add    ecx , [rbp + fftcv_convbuffpos]
                      mov    [rbp + fftcv_convbuffpos], ecx
                      mov    eax , [rbp + fftcv_2n]
                      inc    eax
                      sub    eax , [rbp + fftcv_length]
                      cmp    eax , ecx
                      jnz    .lp12
             .sk12:

                      ;FFT CONVOLUTION CORE
                      xchg   rsi , r11
                      and    D [rbp + fftcv_convbuffpos], 0


                      ;-> double and store in fftbuff
                      xorps  xmm0 , xmm0
                      or     eax , -1
                      movd   xmm4 , eax
                      shufps xmm4 , xmm4 , 11100000b
                      mov    rdi , [rbp + fftcv_fftbuff]   ;rdi - *fftbuff
                      mov    eax , [rbp + fftcv_2n]
                      inc    eax
                      sub    eax , [rbp + fftcv_length]
                      mov    ecx , eax
                      and    ecx , 3 xor -1
                      lea    rdi , [rdi + rax*8]
                      lea    rdi , [rdi + rax*8]
                      sub    ecx , [rbp + fftcv_2n]
                      neg    ecx
             .lp20:   movapd [rdi], xmm0
                      add    rdi , 16
                      loop   .lp20
                      mov    rsi , [rbp + fftcv_convbuff]  ;rsi - *convbuff
                      mov    rdi , [rbp + fftcv_fftbuff]   ;rdi - *fftbuff
                      mov    ecx , eax                     ;rcx -  inlen
                      shr    ecx , 2
             .lp22:   movaps xmm0 , [rsi]                  ;xmm0  d  c  b  a
                      cvtps2pd xmm1 , xmm0                 ;xmm1     b     a
                      movhlps xmm0, xmm0
                      cvtps2pd xmm2 , xmm0                 ;xmm2     d     c
                      movhlps xmm0, xmm1                   ;xmm0           b
                      movhlps xmm3, xmm2                   ;xmm3           d
                      andps  xmm1 , xmm4
                      andps  xmm0 , xmm4
                      andps  xmm2 , xmm4
                      andps  xmm3 , xmm4
                      movapd [rdi], xmm1
                      movapd [rdi + 16], xmm0
                      movapd [rdi + 32], xmm2
                      movapd [rdi + 48], xmm3
                      add    rsi , 16
                      add    rdi , 64
                      loop   .lp22
                      and    eax , 3
                      xchg   eax , ecx
                      jz     .sk24
             .lp24:   cvtsi2sd xmm0 , [rsi]
                      movapd [rdi], xmm0
                      add    rsi,4
                      add    rdi,16
                      loop   .lp24
             .sk24:

                      ;forward FFT
                      mov    rdi , [rbp + fftcv_fftbuff]   ;rdi - *fftbuff
                      mov    ecx , [rbp + fftcv_n]
                      mov    r8  , [rbp + fftcv_ffttab]
                      xchg   rdx , rdi
                      mov    rax , [rbp + fftcv_auxbuffer]
                      xchg   rax , r9
                      call   fft4
                      xchg   rax , r9
                      xchg   rdx , rdi


                      ;normalize
                      mov    ecx , [rbp + fftcv_2n]
                      xor    eax , eax
                      inc    eax
                      cvtsi2sd xmm0 , ecx
                      cvtsi2sd xmm1 , eax
                      divsd  xmm1 , xmm0
                      unpcklpd xmm1 , xmm1
             .lp30:   movapd xmm0 , [rdi]
                      mulpd  xmm0 , xmm1
                      movapd [rdi], xmm0
                      add    rdi , 16
                      loop   .lp30


                      ;complex multiply
                      ;
                      ;x   = a + Ai
                      ;y   = b + Bi
                      ;x*y = (a + Ai) * (b + Bi)
                      ;    = ab + aBi + bAi + ABi^2  / i=sqrt(-1)  i^2=-1
                      ;    = ab - AB + i(aB + bA)
                      mov    rsi , [rbp + fftcv_fftbuff]   ;rsi - *fftbuff
                      mov    rdi , [rbp + fftcv_fftbufffil];rdi - *fftbufffil
                      mov    ecx , [rbp + fftcv_2n]
                      mov    eax , 0x80000000
                      movd   xmm3 , eax
                      shufps xmm3 , xmm3 , 11100001b
             .lp32:   movapd xmm0 , [rsi]                  ;xmm0     A     a
                      movapd xmm1 , [rdi]                  ;xmm1     B     b
                      movapd xmm2 , xmm1
                      shufpd xmm2 , xmm2 , 01b             ;xmm2     b     B
                      mulpd  xmm2 , xmm0                   ;xmm2     Ab    aB
                      mulpd  xmm1 , xmm0                   ;xmm1     AB    ab
                      movapd xmm0 , xmm2                   ;xmm0           aB
                      movhlps xmm2, xmm1                   ;xmm2     Ab    AB
                      movlhps xmm1, xmm0                   ;xmm1     aB    ab
                      xorpd  xmm2 , xmm3                   ;xmm2     Ab   -AB
                      addpd  xmm2 , xmm1                   ;xmm2   Ab+aB  ab-AB
                      movapd [rsi], xmm2
                      add    rsi , 16
                      add    rdi , 16
                      loop   .lp32


                      ;inverse FFT
                      mov    rdi , [rbp + fftcv_fftbuff]   ;rdi - *fftbuff
                      mov    ecx , [rbp + fftcv_n]
                      mov    r8  , [rbp + fftcv_ffttab]
                      xchg   rdx , rdi
                      mov    rax , [rbp + fftcv_auxbuffer]
                      xchg   rax , r9
                      call   ifft4
                      xchg   rax , r9
                      xchg   rdx , rdi


                      ;clear one half of outbuff
                      mov    edi , [rbp + fftcv_and]
                      xor    edi , -1
                      and    edi , [rbp + fftcv_max2n]
                      add    edi , edi
                      add    rdi , [rbp + fftcv_outbuff]   ;rdi - *outbuff
                      mov    ecx , [rbp + fftcv_prev2n]
                      shr    ecx , 2 + 1
                      xorpd  xmm0 , xmm0
             .lp34:   movapd [rdi], xmm0
                      add    rdi , 16
                      loop   .lp34


                      ;apply transient window in case of different n's
                      mov    ecx , [rbp + fftcv_prev2n]
                      shr    ecx , 2
                      mov    eax , [rbp + fftcv_prev2n]    ;((p2n+2n)/2 - 2n)/2
                      add    eax , [rbp + fftcv_2n]
                      shr    eax , 1
                      sub    eax , [rbp + fftcv_2n]
                      sar    eax , 1
                      jz     .sk36
                      mov    edi , eax
                      neg    edi
                      shl    edi , 3 + 1
                      add    rdi , [rbp + fftcv_fftbuff]
                      mov    esi , ecx
                      shl    esi , 2
                      add    rsi , [rbp + fftcv_outbuff]
                      test   eax , eax
                      cmovns ecx , eax
                      cmovns rdi , rsi
                      mov    eax , 1
                      js     .sk38
                      cvtsi2ss xmm0 , ecx                  ;'long to short' transient
                      cvtsi2ss xmm1 , eax
                      cvtsi2ss xmm2 , eax
                      divss  xmm2 , xmm0
                      shufps xmm2 , xmm2 , 0
                      shufps xmm1 , xmm1 , 0
                      subss  xmm1 , xmm2
                      shufps xmm1 , xmm1 , 11100000b
                      subss  xmm1 , xmm2
                      shufps xmm1 , xmm1 , 11010000b
                      subss  xmm1 , xmm2
                      shufps xmm1 , xmm1 , 00011011b
                      addps  xmm2 , xmm2
                      addps  xmm2 , xmm2
                      shr    ecx , 2
             .lp36:   movaps xmm0 , [rdi]
                      mulps  xmm0 , xmm1
                      subps  xmm1 , xmm2
                      movaps [rdi], xmm0
                      add    rdi , 16
                      loop   .lp36
                      jmp    .sk36
             .sk38:   cvtsi2sd xmm1 , ecx                  ;'short to long' transient
                      cvtsi2sd xmm2 , eax
                      divsd  xmm2 , xmm1
                      unpcklpd xmm2 , xmm2
                      xorpd  xmm1 , xmm1
             .lp38:   movapd xmm0 , [rdi]
                      mulpd  xmm0 , xmm1
                      addpd  xmm1 , xmm2
                      movapd [rdi], xmm0
                      add    rdi , 16
                      loop   .lp38
             .sk36:

                      ;-> single and add to outbuff

                      ;first half  (handles overlapping of different n's)
                      xor    eax , eax
                      mov    edi , [rbp + fftcv_prev2n]    ;((p2n+2n)/2 - 2n)/2
                      add    edi , [rbp + fftcv_2n]
                      shr    edi , 1
                      sub    edi , [rbp + fftcv_2n]
                      sar    edi , 1
                      mov    esi , edi
                      cmovs  edi , eax
                      shl    edi , 2
                      mov    ecx , [rbp + fftcv_and]
                      and    ecx , [rbp + fftcv_max2n]
                      add    ecx , ecx
                      add    edi , ecx
                      add    rdi , [rbp + fftcv_outbuff]   ;rdi - *outbuff
                      mov    ecx , [rbp + fftcv_2n]
                      shr    ecx , 1
                      neg    esi
                      cmovs  esi , eax
                      sub    ecx , esi
                      shr    ecx , 2
                      shl    esi , 3 + 1
                      add    rsi , [rbp + fftcv_fftbuff]   ;rsi - *fftbuff
             .lp40:   movapd xmm0 , [rsi]                  ;xmm0     x     a
                      movapd xmm1 , [rsi + 16]             ;xmm1     x     b
                      movapd xmm2 , [rsi + 32]             ;xmm2     x     c
                      movapd xmm3 , [rsi + 48]             ;xmm3     x     d
                      movlhps xmm0, xmm1                   ;xmm0     b     a
                      movlhps xmm2, xmm3                   ;xmm2     d     c
                      cvtpd2ps xmm0 , xmm0                 ;xmm0  -  -  b  a
                      cvtpd2ps xmm2 , xmm2                 ;xmm2  -  -  d  c
                      movlhps xmm0, xmm2                   ;xmm0  d  c  b  a
                      movaps xmm1 , [rdi]
                      addps  xmm1 , xmm0
                      movaps [rdi], xmm1
                      add    rsi , 64
                      add    rdi , 16
                      loop   .lp40

                      ;second half
                      mov    edi , [rbp + fftcv_and]
                      xor    edi , -1
                      and    edi , [rbp + fftcv_max2n]
                      add    edi , edi
                      add    rdi , [rbp + fftcv_outbuff]   ;edi - *outbuff
                      mov    ecx , [rbp + fftcv_2n]
                      shr    ecx , 1
                      shr    ecx , 2
             .lp42:   movapd xmm0 , [rsi]                  ;xmm0     x     a
                      movapd xmm1 , [rsi + 16]             ;xmm1     x     b
                      movapd xmm2 , [rsi + 32]             ;xmm2     x     c
                      movapd xmm3 , [rsi + 48]             ;xmm3     x     d
                      movlhps xmm0, xmm1                   ;xmm0     b     a
                      movlhps xmm2, xmm3                   ;xmm2     d     c
                      cvtpd2ps xmm0 , xmm0                 ;xmm0  -  -  b  a
                      cvtpd2ps xmm2 , xmm2                 ;xmm2  -  -  d  c
                      movlhps xmm0, xmm2                   ;xmm0  d  c  b  a
                      movaps xmm1 , [rdi]
                      addps  xmm1 , xmm0
                      movaps [rdi], xmm1
                      add    rsi , 64
                      add    rdi , 16
                      loop   .lp42


                      ;end of FFT CONVOLUTION core
                      xchg   rsi , r11


                      ;convert from internal
                      mov    eax , [rbp + fftcv_prev2n]
                      add    eax , [rbp + fftcv_2n]
                      shr    eax , 1 + 1
                      mov    ecx , [rbp + fftcv_outlen]
                      add    ecx , eax
                      mov    eax , [rbp + fftcv_inlen]
                      add    eax , [rbp + fftcv_length]
                      dec    eax
                      cmp    ecx , eax
                      cmova  ecx , eax
                      mov    eax , ecx
                      sub    ecx , [rbp + fftcv_outlen]
                      mov    [rbp + fftcv_outlen], eax
                      xchg   rcx , r8                      ;r8  - samples to convert
                      mov    ecx , [rbp + fftcv_and]
                      and    ecx , [rbp + fftcv_max2n]
                      shl    ecx , 1
                      add    rcx , [rbp + fftcv_outbuff]   ;rcx - *outbuff
                      test   D [rbp + fftcv_state], FFTCV_ST_LEADING_DELAY or FFTCV_ST_LD_APPLIED
                      jpe    .sk44
                      or     D [rbp + fftcv_state], FFTCV_ST_LD_APPLIED
                      mov    eax , [rbp + fftcv_length]
                      dec    eax
                      shr    eax , 1
                      lea    rcx , [rcx + rax*4]
                      sub    r8  , rax
             .sk44:   mov    r11d, r10d
                      xchg   r9  , r11
                      xchg   rdx , rbx
                      call   sampconv_from_internal
                      xchg   rdx , rbx
                      xchg   r9  , r11
                      add    rbx , rax
                      add    r12 , r8                      ;update number of samples processed
                      xor    D [rbp + fftcv_and], -1       ;alternate
                      mov    eax , [rbp + fftcv_n]
                      mov    [rbp + fftcv_prevn], eax
                      mov    eax , [rbp + fftcv_2n]
                      mov    [rbp + fftcv_prev2n], eax
                      test   rdx , rdx
                      jnle   .lp12
                      jns    .end
                      mov    eax , [rbp + fftcv_inlen]
                      add    eax , [rbp + fftcv_length]
                      dec    eax
                      cmp    eax , [rbp + fftcv_outlen]
                      ja     .lp10
              .end:
                      fxrstor [rbp + fftcv_fpummxssestate]
                      xchg   rax , r12
                      pop    rcx, rdx, rbx, rbp, rsi, rdi, r8, r11, r12
                      ret
;------------------------------------------------------------------------------------




;------------------------------------------------------------------------------------
;FFT CONVOLUTION FLUSH BUFFERS
;IN:   rcx -  fftcviface                                                      uses: -
;
;OUT:  rax -  FFTCV_ERR_OK

fftcv_flush:
                      push   rdi, rbp

                      xchg   rcx , rbp                     ;rbp -  fftcviface

                      xor    eax , eax
                      mov    [rbp + fftcv_convbuffpos], eax
                      and    D [rbp + fftcv_state], FFTCV_ST_LD_APPLIED xor -1
                      mov    [rbp + fftcv_inlen], eax
                      mov    [rbp + fftcv_outlen], eax

                      mov    rdi , [rbp + fftcv_outbuff]   ;clear outbuff
                      mov    ecx , [rbp + fftcv_max2n]
                      shr    ecx , 1
                      rep stosq

                      xchg   rcx , rbp

                      pop    rbp, rdi
                      ret
;------------------------------------------------------------------------------------




;------------------------------------------------------------------------------------
;FFT CONVOLUTION SET STATE
;IN:   rcx -  fftcviface                                                      uses: -
;      rdx -  statemask << 32  +  state
;
;OUT:  rax -  FFTCV_ERR_OK

;FFT CONVOLUTION SET ATTRIBUTE
;IN:   rcx -  fftcviface                                                      uses: -
;      rdx -  attribute
;      r8  - *value
;
;OUT:  rax -  FFTCV_ERR_OK

fftcv_set_state:
fftcv_set_attribute:
                      mov    rax , rdx
                      test   rax , rax
                      js     .sk10
                      shr    rax , 32
                      not    eax
                      and    [rcx + fftcv_state], eax
                      or     [rcx + fftcv_state], edx

                      xor    eax , eax
                      ret
             .sk10:
                      cmp    rax , FFTCV_ATTRIBUTE_KBDWIN
                      jz     .sk22
                      push   Q [r8  + 0]
                      pop    Q [rcx + fftcv_expwin + 0]
                      push   Q [r8  + 8]
                      pop    Q [rcx + fftcv_expwin + 8]
                      ret
             .sk22:
                      push   Q [r8  + 0]
                      pop    Q [rcx + fftcv_kbdwin + 0]
                      push   Q [r8  + 8]
                      pop    Q [rcx + fftcv_kbdwin + 8]
                      ret
;------------------------------------------------------------------------------------


























