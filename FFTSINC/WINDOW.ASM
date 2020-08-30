
; COPYRIGHT (C) 2008-2010 Akos Mogyorosi <flowwolf>
; FOR DETAILS SEE THE FILE README

; last updated:  4/03/2011

; symmetrical around zero:  bits:  0  -  inverse
;                                  1  -  normal
;                                  2  -  only left-half generated

;------------------------------------------------------------------------------------
;CREATE KAISER-BESSEL WINDOW
;IN:   rcx - *window                                                    uses: st0-st7
;      rdx -  width
;      r8  -  iteration << 32  +  symmetrical around zero
;     xmm0 -  half the time-bandwidth product  (double)
;
;OUT:  window

create_window_kaiser:
                      push   r10, r9, rdi, rcx, rax

                      xchg   rcx , rdi                 ;rdi - *window
                      movq   rax , xmm0
                      mov    r9  , r8
                      shr    r9  , 32
                      push   rax                       ;RSP  B
                      push   rdx                       ;RSP  width B

                      fninit
                      xor    ecx , ecx
             .lp10:   fld    Q [rsp+8]                 ;B
                      lea    rax , [rdx - 1]
                      neg    rax
                      lea    rax , [rax + rcx*2]
                      lea    r10 , [rcx*2]
                      bt     r8  , 0
                      cmovnc rax , r10

                      ;-(N-1)/2 <= n <= (N-1)/2   otherwise 0

                      push   rax                       ;RSP  rax width B
                      fld1
                      fisubr D [rsp+8]                 ;N-1 B
                      fidivr D [rsp]                   ;2n/(N-1) B
                      fmul   st0 , st0                 ;(2n/(N-1))^2 B
                      fld1                             ;1 (2n/(N-1))^2 B
                      fsubr  st1 , st0                 ;1 1-(2n/(N-1))^2 B
                      fdivrp st1 , st0                 ;1/(1-(2n/(N-1))^2) B
                      fsqrt                            ;sqrt(1-(2n/(N-1))^2) B
                      fmul   st0 , st1                 ;x B
                      pop    rax

                      xor    eax , eax
                      fld1                             ;i x B
                      fld    st1                       ;x i x B
                      fmul   st0 , st0                 ;x^2 i x B
                      fld1                             ;1 x^2 i x B
                      fadd   st0 , st0                 ;2 x^2 i x B
                      fadd   st0 , st0                 ;4 x^2 i x B
                      fld    st0                       ;4 4 x^2 i x B
                      fmul   st0 , st0                 ;16 4 x^2 i x B
                      fld    st0                       ;16 16 4 x^2 i x B
                      fadd   st0 , st2                 ;20 16 4 x^2 i x B
             .lp12:   fld    st3                       ;x^2 20 16 4 x^2 i x B
                      fdiv   st0 , st3                 ;x^2/4 20 16 4 x^2 i x B
                      faddp  st5 , st0                 ;20 16 4 x^2 i x B
                      fld    st1                       ;16 20 16 4 x^2 i x B
                      fmulp  st3 , st0                 ;20 16 16*4 x^2 i x B
                      fld    st5                       ;x 20 16 16*4 x^2 i x B
                      fmul   st4 , st0
                      fmulp  st4 , st0                 ;20 16 16*4 x^4 i x B
                      fadd   st1 , st0                 ;20 20+16 16*4 x^4 i x B
                      fld1
                      fadd   st0 , st0
                      fadd   st0 , st0
                      fadd   st0 , st0
                      faddp  st1 , st0                 ;28 20+16 16*4 x^4 i x B
                      inc    rax
                      cmp    rax , r9
                      jnz    .lp12
                      fcompp
                      fcompp                           ;i x B
                      fxch                             ;x i B
                      fcomp  st0                       ;i B
                      fxch                             ;x i

                      ;2nd
                      mov    r10 , r9
                      add    r10 , r10
                      fld1                             ;i2 x i
                      fld    st1                       ;x i2 x i
                      fmul   st0 , st0                 ;x^2 i2 x i
                      fld1                             ;1 x^2 i2 x i
                      fadd   st0 , st0                 ;2 x^2 i2 x i
                      fadd   st0 , st0                 ;4 x^2 i2 x i
                      fld    st0                       ;4 4 x^2 i2 x i
                      fmul   st0 , st0                 ;16 4 x^2 i2 x i
                      fld    st0                       ;16 16 4 x^2 i2 x i
                      fadd   st0 , st2                 ;20 16 4 x^2 i2 x i
             .lp14:   fld    st3                       ;x^2 20 16 4 x^2 i2 x i
                      fdiv   st0 , st3                 ;x^2/4 20 16 4 x^2 i2 x i
                      faddp  st5 , st0                 ;20 16 4 x^2 i2 x i
                      fld    st1                       ;16 20 16 4 x^2 i2 x i
                      fmulp  st3 , st0                 ;20 16 16*4 x^2 i2 x i
                      fld    st5                       ;x 20 16 16*4 x^2 i2 x i
                      fmul   st4 , st0
                      fmulp  st4 , st0                 ;20 16 16*4 x^4 i2 x i
                      fadd   st1 , st0                 ;20 20+16 16*4 x^4 i2 x i
                      fld1
                      fadd   st0 , st0
                      fadd   st0 , st0
                      fadd   st0 , st0
                      faddp  st1 , st0                 ;28 20+16 16*4 x^4 i2 x i
                      inc    rax
                      cmp    rax , r10
                      jnz    .lp14
                      fcompp
                      fcompp                           ;i2 x i
                      fxch                             ;x i2 i
                      fcomp  st0                       ;i2 i
                      fdivrp  st1 , st0                ;i2/i

                      fstp   D [rdi + rcx*4]
                      inc    ecx
                      lea    eax , [ecx*2]
                      cmp    eax , edx
                      jb     .lp10

                      bt     r8  , 1
                      jc     .sk20
                      mov    eax , edx
                      and    eax , 1
                      neg    rax
                      lea    rax , [rax + rcx -1]
             .lp20:   fld    D [rdi + rax*4]
                      fstp   D [rdi + rcx*4]
                      dec    rax
                      inc    ecx
                      cmp    ecx , edx
                      jnz    .lp20
             .sk20:

                      add    rsp , 16
                      pop    rax, rcx, rdi, r9, r10
                      ret
;------------------------------------------------------------------------------------

















