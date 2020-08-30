
; THIS FILE IS PART OF THE 'SINC RESAMPLING KERNEL' LIBRARY SOURCE CODE
; COPYRIGHT (C) 2008-2010 Akos Mogyorosi <flowwolf>
; FOR DETAILS SEE THE FILE README

; SINC RESAMPLING KERNEL  20/06/2010

;sinc_create
;sinc_destroy
;sinc_init
;sinc_deinit
;sinc_process
;sinc_flush


;------------------------------------------------------------------------------------
;CREATE SINC FILTER TABLE
;IN:   rcx -  sinc table name                                                 uses: -
;      rdx - *sinc table [out]
;      r8  - *table size  or zero [out]
;
;OUT:  rax -  sinc_lasterror

sinc_create:
                      push   r11, r10, r9, r8, rdi, rsi, rdx, rcx

                      mov    rax , sinc_tables
                      mov    r10 , [rax + rcx*8]        ;r10 - *sinc table data
                      test   r8  , r8
                      jz     .sk00
                      mov    eax , [r10 + SINC_LENGTH]
                      mov    ecx , [r10 + SINC_DEC]
                      shr    eax , cl
                      add    eax , [r10 + SINC_LENGTH]
                      add    eax , [r10 + SINC_LENGTH_PER_STEP]
                      mov    ecx , [r10 + SINC_STEP]
                      lea    eax , [eax + ecx*4]
                      shl    eax , 2
                      add    eax , 32
                      mov    [r8], rax
             .sk00:   xchg   rdx , r8                           ;r8  -  sinc table [out]

                      ;xor    eax , eax  ;all x64 support SSE2
                      ;inc    eax
                      ;push   rbx
                      ;cpuid
                      ;pop    rbx
                      ;bt     edx , 26
                      ;mov    rax , SINC_ERR_SSE2_NOT_SUPPORTED
                      ;jnc    .err
                      mov    ecx , [r10 + SINC_LENGTH] ;allocate sinc table
                      add    ecx , ecx
                      add    ecx , [r10 + SINC_LENGTH_PER_STEP]
                      mov    eax , [r10 + SINC_STEP]
                      shl    eax , 4
                      lea    ecx , [ecx*4 + eax + 48]  ;  SINC_LENGTH*4+SINC_LENGTH/SINC_STEP*4 + SINC_LENGTH*4+SINC_STEP*4*4 +16 +32
                      call   memallocz
                      test   rax , rax
                      jnz    .noerr
             .errm:   mov    rax , SINC_ERR_NOT_ENOUGH_MEMORY
              .err:
                      pop    rcx, rdx, rsi, rdi, r8, r9, r10, r11
                      ret
            .noerr:
                      mov    [r8], rax
                      test   al  , 15
                      jz     .sk10
                      and    al  , 15 xor -1
                      add    rax , 16
             .sk10:   xchg   rax , rsi                 ;rsi - *sinc table
                      xor    ecx , ecx
             .lp10:   mov    eax , [r10 + rcx]
                      mov    [rsi + rcx], eax
                      add    ecx , 4
                      cmp    ecx , SINC_TDSIZE
                      jnz    .lp10
                      add    rsi , SINC_TDSIZE

                      mov    ecx , [r10 + SINC_LENGTH] ;allocate FFT table
                      shl    ecx , 1+3+1
                      add    ecx , 512 + 16            ;  (SINC_LENGTH*2)*8*2+512+16
                      call   memallocz
                      test   rax , rax
                      jnz    .sk12
                      mov    rcx , [r8]
                      call   memfree
                      jmp    .errm
             .sk12:   mov    r11 , rax                 ;r11 - *FFT table  (unaligned)
                      test   al  , 15
                      jz     .sk14
                      and    al  , 15 xor -1
                      add    rax , 16
             .sk14:   xchg   rax , rdi                 ;rdi - *FFT table

                      mov    eax , [r10 + SINC_LENGTH] ;  (SINC_LENGTH*2)*8*2
                      shl    eax , 1+3+1
                      fxsave [rdi + rax]
                      fninit
                      fild   D [r10 + SINC_LENGTH]
                      fadd   st0 , st0
                      fidivr D [r10 + SINC_STEP]       ;STEP/LENGTH

                      xor    ecx , ecx                 ;frequency response with a slight lowpass
                      mov    edx , [r10 + SINC_LENGTH_PER_STEP]
                      sub    edx , [r10 + SINC_LOWPASS]
                      add    edx , edx
              .lp20:  fst    Q [rdi + rcx*8 + 4*8]
                      neg    rcx
                      mov    eax , [r10 + SINC_LENGTH] ;  (SINC_LENGTH*2)*8*2
                      shl    eax , 1+3+1
                      lea    rax , [rcx*8 + rax - 2*8]
                      fst    Q [rdi + rax]
                      neg    rcx
                      add    ecx , 2
                      cmp    ecx , edx                 ;  ((SINC_LENGTH*2)/SINC_STEP/2-SINC_LOWPASS)*2
                      jnz    .lp20
                      fst    Q [rdi]
                      fstp   Q [rdi + 2*8]

                      mov    ecx , [r10 + SINC_BITS]   ;inverse FFT
                      inc    ecx
                      call   fft4_create
                      test   rax , rax
                      jnz    .sk20
                      jmp    .errm
             .sk20:   mov    rdx , rdi
                      xchg   rax , r8
                      xor    r9  , r9
                      call   ifft4
                      xchg   rcx , r8
                      call   fft4_destroy

                      mov    edx , [r10 + SINC_LENGTH] ;rdx -  SINC_LENGTH
                      add    edx , edx
                      xor    ecx , ecx
             .lp22:   fld    Q [rdi + rcx*8]
                      lea    rax , [rcx*2]             ;  (SINC_LENGTH*2)*4/2
                      lea    rax , [rax + rdx*2]
                      fst    D [rsi + rax]
                      neg    rcx
                      lea    rax , [rcx*2]             ;  (SINC_LENGTH*2)*4/2
                      lea    rax , [rax + rdx*2]
                      fstp   D [rsi + rax]
                      neg    rcx
                      add    ecx , 2
                      cmp    ecx , edx
                      jnz    .lp22

                      dec    edx                       ;create window  (odd length)
                      lea    rcx , [rdi + 4]
                      mov    r8  , (50 shl 32) + 1
                      cvtss2sd xmm0 , [r10 + SINC_WINDOW]
                      call   create_window_kaiser
                      fldz
                      fstp   D [rcx - 4]

                      lea    r8  , [rdi + rdx*4 + 4]   ;create window for decimation  (odd length)
                      xchg   r8  , rdi
                      mov    ecx , edx
                      xor    eax , eax
                      rep stosd
                      xchg   r8  , rdi
                      mov    eax , [r10 + SINC_SHIFT]  ;  (SINC_LENGTH-(SINC_LENGTH-SINC_STEP*(0+SINC_SHIFT*2))/SINC_DEC/2)*4
                      add    eax , eax
                      imul   eax , [r10 + SINC_STEP]
                      sub    eax , [r10 + SINC_LENGTH]
                      neg    eax
                      mov    ecx , [r10 + SINC_DEC]
                      shr    eax , cl
                      mov    r9  , rax                 ;  (SINC_LENGTH-SINC_STEP*(0+SINC_SHIFT*2))/SINC_DEC
                      shr    eax , 1
                      sub    eax , [r10 + SINC_LENGTH]
                      neg    eax
                      shl    eax , 2
                      lea    eax , [edx*4 +4 +4 +eax]
                      lea    rcx , [rdi + rax]
                      mov    r8  , (50 shl 32) + 1
                      xchg   r9  , rdx
                      cvtss2sd xmm0 , [r10 + SINC_WINDOW]
                      call   create_window_kaiser
                      xchg   r9 ,  rdx
                      inc    edx

                      xor    ecx , ecx                 ;window filter table
             .lp24:   fld    D [rsi + rcx*4]
                      fld    st0
                      fmul   D [rdi + rcx*4]
                      fstp   D [rdi + rcx*4]
                      lea    rax, [rdi + rdx*4]
                      fmul   D [rax + rcx*4]
                      fstp   D [rax + rcx*4]
                      inc    ecx
                      cmp    ecx , edx
                      jnz    .lp24
                      shr    edx , 1

                      ;interpolation table
                      xor    ecx , ecx                 ;reorder table for SSE; shift to the right
             .lp30:   xor    eax , eax
             .lp32:   mov    r8d , [r10 + SINC_SHIFT]  ;  SINC_STEP*(1+SINC_SHIFT)
                      inc    r8
                      imul   r8d , [r10 + SINC_STEP]
                      lea    r9  , [rax + rcx]
                      add    r9  , r8
                      mov    r8d , [r10 + SINC_LENGTH] ;  SINC_LENGTH/2*4
                      add    r8  , r8
                      lea    r8  , [r8 + r9*4]
                      fld    D [rdi + r8]
                      fstp   D [rsi]
                      add    rsi , 4
                      add    eax , [r10 + SINC_STEP]
                      cmp    eax , edx
                      jnz    .lp32
                      inc    ecx
                      cmp    ecx , [r10 + SINC_STEP]
                      jnz    .lp30

                      xor    ecx , ecx                 ;one table outside boundary  (interpolation)
             .lp34:   mov    eax , [r10 + SINC_LENGTH]
                      shl    eax , 2
                      neg    rax
                      lea    rax , [rax + rcx*4 +4]
                      fld    D [rsi + rax]
                      fstp   D [rsi + rcx*4]
                      inc    ecx
                      mov    eax , [r10 + SINC_LENGTH_PER_STEP]
                      dec    eax
                      cmp    ecx , eax
                      jnz    .lp34
                      fldz
                      fstp   D [rsi + rcx*4]
                      lea    rsi , [rsi + rcx*4 +4]

                      ;decimation table (not reordered)
                      mov    eax , [r10 + SINC_SHIFT]  ;  (SINC_LENGTH-SINC_STEP*(0+SINC_SHIFT*2)
                      add    eax , eax
                      imul   eax , [r10 + SINC_STEP]
                      sub    eax , [r10 + SINC_LENGTH]
                      neg    eax
                      mov    edx , eax
                      mov    ecx , [r10 + SINC_DEC]
                      shr    eax , cl
                      mov    r9  , rax
                      sub    eax , edx
                      neg    eax                       ;  (SINC_LENGTH-SINC_STEP*(0+SINC_SHIFT*2))/SINC_DEC)
                      shr    eax , 1
                      shl    eax , 2
                      mov    edx , [r10 + SINC_SHIFT]  ;  SINC_LENGTH/2*4+SINC_STEP*(0+SINC_SHIFT)*4
                      imul   edx , [r10 + SINC_STEP]
                      shl    edx , 2
                      add    edx , [r10 + SINC_LENGTH]
                      add    edx , [r10 + SINC_LENGTH]
                      add    edx , eax
                      mov    eax , [r10 + SINC_LENGTH] ;  SINC_LENGTH*2*4
                      shl    eax , 1+2
                      add    eax , edx
                      xchg   rax , r8                  ;  SINC_LENGTH*2*4  + ((SINC_LENGTH-SINC_STEP*(0+SINC_SHIFT*2)) - (SINC_LENGTH-SINC_STEP*(0+SINC_SHIFT*2))/SINC_DEC)/2*4  +  SINC_LENGTH/2*4+SINC_STEP*(0+SINC_SHIFT)*4
                      xchg   rdx , r9                  ;  (SINC_LENGTH-SINC_STEP*(0+SINC_SHIFT*2))/SINC_DEC
                      xor    ecx , ecx
             .lp40:   lea    rax , [rcx*4 + r8]
                      fld    D [rdi + rax]
                      fstp   D [rsi + rcx*4]
                      inc    ecx
                      cmp    ecx , edx
                      jnz    .lp40
                      mov    eax , [r10 + SINC_STEP]   ;for SSE implementation
                      lea    edx , [edx + eax*4]
             .lp42:   fldz
                      fstp   D [rsi + rcx*4]
                      inc    ecx
                      cmp    ecx , edx
                      jnz    .lp42

                      mov    eax , [r10 + SINC_LENGTH]
                      shl    eax , 1+3+1
                      fxrstor [rdi + rax]
                      xchg   rcx , r11                 ;free FFT table
                      call   memfree

                      xor    eax , eax
                      pop    rcx, rdx, rsi, rdi, r8, r9, r10, r11
                      ret
;------------------------------------------------------------------------------------




;------------------------------------------------------------------------------------
;DESTROY SINC FILTER TABLE
;IN:   rcx -  sinc table                                                      uses: -
;
;OUT:  rax -  SINC_ERR_OK

sinc_destroy:
                      call   memfree
                      xor    eax , eax
                      ret
;------------------------------------------------------------------------------------




;------------------------------------------------------------------------------------
;SINC INIT
;IN:   rcx - *sinciface [out]                                                 uses: -
;      rdx -  sinc table
;     xmm0 -  max downsampling ratio  (double)
;
;OUT:  rax -  sinc_lasterror
;
;NOTE: every successful call to sinc_init involves a call to sinc_deinit

sinc_init:
                      push   r11, r10, r9, r8, rdx, rcx

                      xchg   rcx , r8                  ;r8  - *sinciface
                      test   dl  , 15
                      jz     .sk00
                      and    dl  , 15 xor -1
                      add    rdx , 16
             .sk00:   xchg   rdx , r10                 ;r10 - *sinc table data
                      lea    r9  , [r10 + SINC_TDSIZE] ;r9  - *sinc table
                      movq   r11 , xmm0                ;r11 -  max conversion ratio

                      ;xor    eax , eax  ;all x64 support SSE2
                      ;inc    eax
                      ;push   rbx
                      ;cpuid
                      ;pop    rbx
                      ;bt     edx , 26
                      ;mov    rax , SINC_ERR_SSE2_NOT_SUPPORTED
                      ;jnc    .err
                      mov    ecx , 512 + 16
                      call   memalloc
                      test   rax , rax
                      jnz    .sk10
             .errm:   mov    rax , SINC_ERR_NOT_ENOUGH_MEMORY
              .err:
                      pop    rcx, rdx, r8, r9, r10, r11
                      ret
             .sk10:
                      mov    rcx , rax
                      test   al  , 15
                      jz     .sk12
                      and    al  , 15 xor -1
                      add    rax , 16
             .sk12:   fxsave [rax]
                      movq   xmm1 , r11
                      cvtsi2sd xmm0, D [r10 + SINC_LENGTH_PER_STEP]
                      divsd  xmm0 , xmm1
                      cvtsd2si edx , xmm0
                      fxrstor [rax]
                      call   memfree
                      xor    ecx , ecx
                      bsr    ecx , edx
                      xor    eax , eax
                      inc    eax
                      shl    eax , cl
                      cmp    eax , edx
                      lea    edx , [eax*2]
                      cmovnz eax , edx
                      mov    edx , [r10 + SINC_LENGTH_PER_STEP]
                      cmp    edx , eax
                      cmova  eax , edx
                      shl    eax , 2
                      xchg   eax , edx
                      lea    ecx , [edx*4 + sinc_infoblocksize +512 +16]
                      call   memallocz
                      test   rax , rax
                      jz     .errm
                      mov    rcx , rax
                      test   al  , 15
                      jz     .sk14
                      and    al  , 15 xor -1
                      add    rax , 16
             .sk14:   mov    [r8], rax
                      mov    [rax + sinc_infoblock], rcx
                      mov    [rax + sinc_buffsize], edx
                      mov    [rax + sinc_table], r9
                      mov    [rax + sinc_maxconvratio], r11
                      or     D [rax + sinc_state], SINC_ST_FIRST_START

                      xor    ecx , ecx
             .lp16:   mov    edx , [r10 + rcx]
                      mov    [rax + sinc_td + rcx], edx
                      add    ecx , 4
                      cmp    ecx , SINC_TDSIZE
                      jnz    .lp16

                      xor    eax , eax
                      pop    rcx, rdx, r8, r9, r10, r11
                      ret
;------------------------------------------------------------------------------------




;------------------------------------------------------------------------------------
;SINC DEINIT
;IN:   rcx -  sinciface                                                       uses: -
;
;OUT:  rax -  SINC_ERR_OK

sinc_deinit:
                      push   rcx
                      mov    rcx , [rcx + sinc_infoblock]
                      call   memfree
                      pop    rcx
                      xor    eax , eax
                      ret
;------------------------------------------------------------------------------------




;------------------------------------------------------------------------------------
;SINC PROCESS
;IN:   rcx -  sinciface                                                       uses: -
;      rdx - *in
;      r8  - *out
;      r9  -  number of samples  or -1/-2 for  trailing delay / delay length
;      r10 -  in format << 32  +  out format
;     xmm0 -  input rate  (double)
;     xmm1 -  output rate  (double)
;
;OUT:  rax -  number of samples processed

sinc_process:
                      push   r14, r13, r12, r11, r8, rdi, rsi, rbp, rbx, rdx, rcx

                      xchg   rcx , rbp            ;rbp - *sinciface
                      xchg   rdx , rsi            ;rsi - *in
                      xchg   r8  , rbx            ;rbx - *out
                      mov    rdx , r9             ;rdx - number of samples
                      xor    r14 , r14            ;r14 - number of samples processed

                                                  ;r8, r11, r12, r13 - temporary

                      mov    eax , [rbp + sinc_buffsize]
                      fxsave [rbp + sinc_buff + rax*4]

                      cvtsi2sd xmm6 , D [rbp + SINC_STEP]
                      unpcklpd xmm6 , xmm6
                      xor    eax , eax
                      inc    eax
                      cvtsi2sd xmm6 , eax                  ;xmm6  step        1.0
                      divsd  xmm0 , xmm1
                      and    D [rbp + sinc_state], SINC_ST_DECIMATION xor -1
                      comisd xmm0 , xmm6
                      setnbe al
                      imul   eax , SINC_ST_DECIMATION
                      or     [rbp + sinc_state], eax
                      movsd  xmm7 , [rbp + sinc_fract]
                      shufpd xmm7 , xmm0, 00b              ;xmm7  ratio       fract
                      movhlps xmm0, xmm7                   ;xmm0  x           ratio
                      movsd  xmm1 , xmm6
                      addsd  xmm1 , xmm1                   ;xmm1  x           2.0
                      divsd  xmm0 , xmm1                   ;xmm0  x           ratio/2.0
                      test   D [rbp + sinc_state], SINC_ST_FIRST_START
                      jz     .sk10
                      cmp    rdx  , -2
                      jz     .sk10
                      and    D [rbp + sinc_state], SINC_ST_FIRST_START xor -1
                      movsd  xmm7 , xmm0
             .sk10:
                      test   rdx , rdx
                      jz     .end
                      jns    .lp10

                      ;trailing delay (SINC_LENGTH/SINC_STEP/2+SINC_SHIFT+3) / (inrate/outrate)
                      ;  decimation:  (SINC_LENGTH-SINC_STEP*(0+SINC_SHIFT*2))/SINC_DEC/SINC_STEP/2 + 3
                      mov    eax , [rbp + SINC_SHIFT]
                      add    eax , eax
                      imul   eax , [rbp + SINC_STEP]
                      sub    eax , [rbp + SINC_LENGTH]
                      neg    eax
                      mov    ecx , [rbp + SINC_DEC]
                      shr    eax , cl
                      xchg   rdx , r8
                      cdq
                      div    D [rbp + SINC_STEP]
                      xchg   rdx , r8
                      shr    eax , 1
                      add    eax , 3
                      mov    ecx , [rbp + SINC_LENGTH_PER_STEP]
                      shr    ecx , 1
                      add    ecx , [rbp + SINC_SHIFT]
                      add    ecx , 3
                      xchg   eax , ecx

                      cmp    rdx , -1
                      jz     .sk12

                      movhlps xmm1, xmm7                   ;return length
                      cvtsi2sd xmm0 , eax
                      divpd  xmm0 , xmm1
                      cvtsd2si eax , xmm0
                      movhlps xmm0, xmm7
                      comisd xmm0 , xmm6
                      cmova  eax , ecx
                      xchg   rax , r14
                      jmp    .end
             .sk12:
                      movhlps xmm1, xmm7                   ;return trailing delay
                      cvtsi2sd xmm0 , ecx
                      mulsd  xmm0 , xmm1
                      comisd xmm1 , xmm6
                      cvtsd2si ecx , xmm0
                      cmova  eax , ecx
                      xchg   eax , edx

                      lea    rdi , [rbp + sinc_convbuff]   ;clear convbuff if rdx = -1
                      mov    ecx , SINC_CONVBUFFSIZE/2
                      xor    eax , eax
                      rep stosq

             .lp10:   lea    rdi , [rbp + sinc_convbuff]
                      test   rdx , rdx
                      jz     .end

                      ;convert to internal 32-bit
                      mov    ecx , SINC_CONVBUFFSIZE/2
                      mov    eax , ecx
                      cmp    ecx , edx
                      cmova  ecx , edx                     ;rcx -  samples to convert
                      sub    edx , ecx
                      sub    eax , ecx
                      lea    rdi , [rdi + rax*4]
                      xchg   rax , r12
                      cmp    r9  , -1
                      jz     .sk20
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
             .sk20:   xchg   rcx , r12                     ;rcx -  convbuffpos (in)


                      ;SINC processing core
                      push   rbx
                      push   rdx
                      push   rsi

                      mov    rsi , [rbp + sinc_table]      ;rsi - *coeffs
                      mov    eax , [rbp + sinc_buffsize]   ;rax -  and
                      shl    eax , 2
                      dec    eax
                      mov    edx , [rbp + sinc_buffpos]    ;rdx -  buffpos
                      xor    edi , edi                     ;rdi -  zero
                      test   D [rbp + sinc_state], SINC_ST_DECIMATION
                      jnz    .sk50


                      ;- interpolation -
                      mov    r11d, [rbp + SINC_LENGTH_PER_STEP]
                      mov    r13d, [rbp + SINC_SHIFT]
                      add    r13 , r13
                      mov    [rbp + sinc_r11], r11d        ;save interpolation constants
                      mov    [rbp + sinc_r13], r13d

                      addsd  xmm7 , xmm6                   ;fetch
             .lp40:   subsd  xmm7 , xmm6
                      sub    rdx , 16
                      and    rdx , rax
                      movaps xmm0 , [rbp + sinc_buff + rdx]
                      add    rdx , 16
                      and    rdx , rax
                      movss  xmm1 , [rbp + sinc_convbuff + rcx*4]
                      movss  xmm0 , xmm1
                      shufps xmm0 , xmm0 , 00111001b
                      movaps [rbp + sinc_buff + rdx], xmm0
                      add    rdx , 16
                      and    rdx , rax
                      inc    rcx

             .lp42:   movsd  xmm5 , xmm6                   ;xmm5  x           1.0
                      subsd  xmm5 , xmm7                   ;xmm5  x           1.0-f
                      movhlps xmm0, xmm6                   ;xmm0  x           step
                      mulsd  xmm5 , xmm0                   ;xmm5  x           (1.0-f)*step
                      cvttsd2si rbx , xmm5
                      cvtsi2sd xmm0 , rbx
                      subsd  xmm5 , xmm0                   ;xmm5  x           1-f*s
                      cvtsd2ss xmm5 , xmm5                 ;xmm5  x     x     x     1-f*s
                      shufps xmm5 , xmm5 , 0               ;xmm5  1-f*s 1-f*s 1-f*s 1-f*s
                      imul   rbx , r11

                      xchg   rcx , r8
                      mov    r12 , r11
                      shl    r12 , 4
                      sub    rdx , r12
                      and    rdx , rax
                      lea    rcx , [rbx + r11]
                      sub    rcx , r13
                      xorps  xmm0 , xmm0
             .lp44:   movaps xmm1 , [rbp + sinc_buff + rdx]  ;xmm1  a3    a2    a1    a0
                      lea    r12 , [rbx + r11]
                      movaps xmm2 , [rsi + rbx*4]            ;xmm2  x3    x2    x1    x0
                      movaps xmm3 , [rsi + r12*4]
                      subps  xmm3 , xmm2
                      mulps  xmm3 , xmm5
                      addps  xmm3 , xmm2
                      mulps  xmm1 , xmm3
                      addps  xmm0 , xmm1
                      add    rdx , 64
                      and    rdx , rax
                      add    rbx , 4
                      cmp    rbx , rcx
                      jnz    .lp44
                      mov    rcx , r13
                      shl    rcx , 4
                      lea    rcx , [rcx + rax + 1]
                      add    rdx , rcx
                      and    rdx , rax
                      xchg   rcx , r8

                      ;NOTE: buffered store is not faster
                      movhlps xmm1 , xmm0                  ;xmm1  x     x     x3    x2
                      addps  xmm1 , xmm0                   ;xmm1  x     x     x1+x3 x0+x2
                      pshufd xmm0 , xmm1 , 11100001b       ;xmm0  x     x     x0+x2 x1+x3
                      addss  xmm0 , xmm1                   ;xmm0  x     x     x0+x2 x0+x1+x2+x3
                      movss  [rbp + sinc_convbuff + SINC_CONVBUFFSIZE/2*4 + rdi*4], xmm0
                      inc    rdi
                      movhlps xmm5, xmm7                   ;xmm5  x           ratio
                      addsd  xmm7 , xmm5                   ;xmm7  x           f+ratio
                      comisd xmm7 , xmm6
                      setnbe bl
                      cmp    rcx , SINC_CONVBUFFSIZE/2
                      setz   bh
                      add    bh  , bh
                      or     bl  , bh
                      cmp    rdi , SINC_CONVBUFFSIZE/2
                      setz   bh
                      shl    bh  , 2
                      or     bl  , bh
                      jz     .lp42
                      cmp    bl  , 1
                      jz     .lp40
                      cmp    bl  , 2
                      jz     .lp42
                      jmp    .sk60


             .sk50:   ;- decimation -
                      mov    r8d , [rbp + SINC_LENGTH]     ;  (SINC_LENGTH+SINC_LENGTH/SINC_STEP)*4
                      add    r8d , [rbp + SINC_LENGTH_PER_STEP]
                      lea    rsi , [rsi + r8*4]
                      xchg   rax , r12                     ;  (SINC_LENGTH-SINC_STEP*(0+SINC_SHIFT*2))/SINC_DEC/2
                      mov    eax , [rbp + SINC_SHIFT]
                      add    eax , eax
                      imul   eax , [rbp + SINC_STEP]
                      sub    eax , [rbp + SINC_LENGTH]
                      neg    eax
                      xchg   rcx , r8
                      mov    ecx , [rbp + SINC_DEC]
                      shr    eax , cl
                      xchg   rcx , r8
                      shr    eax , 1
                      xchg   rax , r12
                      mov    [rbp + sinc_r12], r12d        ;save decimation constant
                      addsd  xmm7 , xmm6
             .lp50:   or     D [rbp + sinc_state], SINC_ST_FETCH
                      subsd  xmm7 , xmm6
                      sub    rdx , 16
                      and    rdx , rax
                      movaps xmm0 , [rbp + sinc_buff + rdx]
                      add    rdx , 16
                      and    rdx , rax
                      movss  xmm1 , [rbp + sinc_convbuff + rcx*4]
                      movss  xmm0 , xmm1
                      shufps xmm0 , xmm0 , 00111001b
                      movaps [rbp + sinc_buff + rdx], xmm0
                      add    rdx , 16
                      and    rdx , rax
                      inc    rcx
                      cmp    rcx , SINC_CONVBUFFSIZE/2
                      setz   bl
                      comisd xmm7 , xmm6
                      setbe  bh
                      add    bh  , bh
                      or     bl  , bh
                      jz     .lp50
                      cmp    bl  , 1
                      jz     .sk60
                      and    D [rbp + sinc_state], SINC_ST_FETCH xor -1

             .lp52:   mov    r8  , rcx
                      mov    r11 , rdx
                      movhlps xmm5, xmm6                   ;xmm5  x           step
                      movhlps xmm0, xmm7                   ;xmm0  x           ratio
                      divsd  xmm5 , xmm0                   ;xmm5  x           step/ratio
                      lea    rbx , [r12*2]                 ;  (SINC_LENGTH-SINC_STEP*(0+SINC_SHIFT*2))/SINC_DEC
                      cvtsi2sd xmm0 , rbx
                      divsd  xmm0 , xmm5
                      cvttsd2si rbx , xmm0
                      shl    rbx , 4
                      sub    rdx , rbx
                      and    rdx , rax
                      movsd  xmm4 , xmm6                   ;xmm4  x           1.0
                      subsd  xmm4 , xmm7                   ;xmm4  x           1.0-f
                      mulsd  xmm4 , xmm5                   ;xmm4  x           (1.0-f)*s/r
                      mov    rcx , r12                     ;  (SINC_LENGTH-SINC_STEP*(0+SINC_SHIFT*2))/SINC_DEC/2
                      cvtsi2sd xmm0 , rcx                  ;xmm0  x           l/2
                      movsd  xmm1 , xmm0                   ;xmm1  x           l/2
                      divsd  xmm0 , xmm5                   ;xmm0  x           l/2/(step/ratio)
                      cvttsd2si rbx , xmm0
                      dec    rbx
                      cvtsi2sd xmm0 , rbx
                      mulsd  xmm0 , xmm5                   ;xmm0  x           l/2/(step/ratio) * (step/ratio)
                      subsd  xmm1 , xmm0                   ;xmm3  x           l/2 - l/2/(step/ratio) * (step/ratio)
                      addsd  xmm4 , xmm1
                      cvtsd2ss xmm4 , xmm4                 ;xmm4  x     x     x     (1.0-f)*s/r  +  l/2 - l/2/(step/ratio) * (step/ratio)
                      cvtsd2ss xmm5 , xmm5                 ;xmm5  x     x     x     s/r
                      shufps xmm5 , xmm5 , 00000000b       ;xmm5  s/r   s/r   s/r   s/r
                      shufps xmm4 , xmm4 , 10010000b
                      addss  xmm4 , xmm5
                      shufps xmm4 , xmm4 , 10010000b
                      addss  xmm4 , xmm5
                      shufps xmm4 , xmm4 , 10010000b
                      addss  xmm4 , xmm5
                      shufps xmm4 , xmm4 , 00011011b
                      addps  xmm5 , xmm5
                      addps  xmm5 , xmm5

                      add    rcx , rcx
                      xorps  xmm0 , xmm0
             .lp54:   cvttps2dq xmm1 , xmm4
                      movd   ebx , xmm1
                      movlps xmm2 , [rsi + rbx*4]          ;xmm2  x     x     x0_   x0
                      psrldq xmm1 , 4
                      movd   ebx , xmm1
                      movlps xmm3 , [rsi + rbx*4]          ;xmm3  x     x     x1_   x1
                      psrldq xmm1 , 4
                      movd   ebx , xmm1
                      movhps xmm2 , [rsi + rbx*4]          ;xmm2  x2_   x2    x0_   x0
                      psrldq xmm1 , 4
                      movd   ebx , xmm1
                      movhps xmm3 , [rsi + rbx*4]          ;xmm3  x3_   x3    x1_   x1
                      movaps xmm1 , xmm2
                      unpcklps xmm2 , xmm3                 ;xmm2  x1_   x0_   x1    x0
                      unpckhps xmm1 , xmm3                 ;xmm1  x3_   x2_   x3    x2
                      movhlps xmm3 , xmm2                  ;xmm3              x1_   x0_
                      movlhps xmm2 , xmm1                  ;xmm2  x3    x2    x1    x0
                      movsd   xmm1 , xmm3                  ;xmm1  x3_   x2_   x1_   x0_
                      movaps  xmm3 , xmm4
                      cvttps2dq xmm4 , xmm4
                      cvtdq2ps xmm4 , xmm4
                      subps  xmm3 , xmm4
                      addps  xmm4 , xmm3
                      subps  xmm1 , xmm2
                      mulps  xmm1 , xmm3
                      movaps xmm3 , [rbp + sinc_buff + rdx];xmm3  a3    a2    a1    a0
                      addps  xmm1 , xmm2
                      mulps  xmm1 , xmm3
                      addps  xmm0 , xmm1
                      addps  xmm4 , xmm5
                      add    rdx , 64
                      and    rdx , rax
                      cmp    rbx , rcx
                      jb     .lp54
                      subps  xmm0 , xmm1                   ;conditionally mask out the last 4 values
                      subps  xmm4 , xmm5
                      cvtsi2ss xmm2 , rcx
                      shufps xmm2 , xmm2 , 0               ;xmm2  ecx   ecx   ecx   ecx
                      cmpnltps xmm4 , xmm2
                      andps  xmm1 , xmm4
                      addps  xmm0 , xmm1
                      mov    rcx , r8
                      mov    rdx , r11

                      ;NOTE: buffered store is not faster
                      movhlps xmm1, xmm0                   ;xmm1  x     x     x3    x2
                      addps  xmm1 , xmm0                   ;xmm1  x     x     x1+x3 x0+x2
                      pshufd xmm0 , xmm1 , 11100001b       ;xmm0  x     x     x0+x2 x1+x3
                      addss  xmm0 , xmm1                   ;xmm0  x     x     x0+x2 x0+x1+x2+x3
                      movhlps xmm1, xmm7
                      cvtsd2ss xmm1 , xmm1                 ;xmm1  x     x     x     ratio
                      divss  xmm0 , xmm1                   ;xmm0  x     x     x     (x0+x1+x2+x3)/ratio
                      movss  [rbp + sinc_convbuff + SINC_CONVBUFFSIZE/2*4 + rdi*4], xmm0
                      inc    rdi
                      movhlps xmm5, xmm7                   ;xmm5  x           ratio
                      addsd  xmm7 , xmm5                   ;xmm7  x           f+ratio
                      comisd xmm7 , xmm6
                      setnbe bl
                      cmp    rcx , SINC_CONVBUFFSIZE/2
                      setz   bh
                      add    bh  , bh
                      or     bl  , bh
                      cmp    rdi , SINC_CONVBUFFSIZE/2
                      setz   bh
                      shl    bh  , 2
                      or     bl  , bh
                      jz     .lp52
                      cmp    bl  , 1
                      jz     .lp50
                      cmp    bl  , 2
                      jz     .lp52


             .sk60:   ;convert from internal
                      push   rax
                      xor    eax , eax
                      test   D [rbp + sinc_state], SINC_ST_LEADING_DELAY
                      jnz    .sk62

                      ;leading delay  (SINC_LENGTH/SINC_STEP/2+SINC_SHIFT+3) / (inrate/outrate)
                      ;  decimation:  (SINC_LENGTH-SINC_STEP*(0+SINC_SHIFT*2))/SINC_DEC/SINC_STEP/2 + 3
                      xchg   rcx , r12
                      mov    eax , [rbp + SINC_SHIFT]
                      add    eax , eax
                      imul   eax , [rbp + SINC_STEP]
                      sub    eax , [rbp + SINC_LENGTH]
                      neg    eax
                      mov    ecx , [rbp + SINC_DEC]
                      shr    eax , cl
                      xchg   rdx , r8
                      cdq
                      div    D [rbp + SINC_STEP]
                      xchg   rdx , r8
                      shr    eax , 1
                      add    eax , 3
                      mov    ecx , [rbp + SINC_LENGTH_PER_STEP]
                      shr    ecx , 1
                      add    ecx , [rbp + SINC_SHIFT]
                      add    ecx , 3
                      xchg   eax , ecx
                      movhlps xmm1, xmm7
                      cvtsi2sd xmm0 , eax
                      divpd  xmm0 , xmm1
                      cvtsd2si eax , xmm0
                      movhlps xmm0, xmm7
                      comisd xmm0 , xmm6
                      cmova  eax , ecx
                      sub    eax , [rbp + sinc_leading_delay]
                      cmp    eax , edi
                      cmova  eax , edi
                      xchg   rcx , r12
                      add    [rbp + sinc_leading_delay], eax
                      sub    edi , eax
                      jz     .sk63
                      or     D [rbp + sinc_state], SINC_ST_LEADING_DELAY
             .sk62:
                      add    r14 , rdi                     ;rdi -  samples to convert
                      lea    r11 , [rbp + rax*4 + sinc_convbuff + SINC_CONVBUFFSIZE/2*4]
                      mov    r12 , [rsp + 16 +8]
                      mov    r13d, r10d
                      mov    r8  , rdi
                      xchg   rcx , r11
                      xchg   rdx , r12
                      xchg   r9  , r13
                      call   sampconv_from_internal
                      xchg   rcx , r11
                      xchg   rdx , r12
                      xchg   r9  , r13
                      add    [rsp + 16 +8], rax
             .sk63:   pop    rax

                      mov    r11d, [rbp + sinc_r11]        ;reload interpolation constants
                      mov    r13d, [rbp + sinc_r13]
                      mov    r12d, [rbp + sinc_r12]        ;reload decimation constant

                      xor    edi , edi
                      cmp    ecx , SINC_CONVBUFFSIZE/2
                      jz     .sk66
                      test   D [rbp + sinc_state], SINC_ST_DECIMATION
                      jnz    .sk64
                      test   bl  , 1
                      jnz    .lp40
                      jmp    .lp42
             .sk64:   test   bl  , 1
                      jnz    .lp50
                      jmp    .lp52

             .sk66:   test   D [rbp + sinc_state], SINC_ST_DECIMATION
                      jnz    .sk68
                      test   bl  , 1
                      jz     .lp42
                      jmp    .sk69
             .sk68:   test   bl  , 1
                      jz     .lp52
             .sk69:   subsd  xmm7 , xmm6
                      mov    [rbp + sinc_buffpos], edx
                      pop    rsi
                      pop    rdx
                      pop    rbx
                      test   rdx , rdx
                      jnz    .lp10
              .end:
                      movsd  [rbp + sinc_fract], xmm7      ;save fract
                      mov    eax , [rbp + sinc_buffsize]
                      fxrstor [rbp + sinc_buff + rax*4]
                      xchg   rax , r14

                      pop    rcx, rdx, rbx, rbp, rsi, rdi, r8, r11, r12, r13, r14
                      ret
;------------------------------------------------------------------------------------




;------------------------------------------------------------------------------------
;SINC FLUSH BUFFERS
;IN:   rcx -  sinciface                                                       uses: -
;
;OUT:  rax -  SINC_ERR_OK

sinc_flush:
                      push   r8, rdi, rcx

                      xchg   rcx , r8             ;r8  - *sinciface

                      lea    rdi , [r8 + sinc_buff]
                      mov    ecx , [r8 + sinc_buffsize]
                      shr    ecx , 1
                      xor    eax , eax
                      rep stosq
                      mov    [r8 + sinc_buffpos], eax
                      mov    [r8 + sinc_leading_delay], eax
                      mov    D [r8 + sinc_state], SINC_ST_FIRST_START

                      pop    rcx, rdi, r8
                      ret
;------------------------------------------------------------------------------------












