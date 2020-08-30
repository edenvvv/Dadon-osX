
; THIS FILE IS PART OF THE 'FFT CONVOLUTION KERNEL' LIBRARY SOURCE CODE
; COPYRIGHT (C) 2010 Akos Mogyorosi <flowwolf>
; FOR DETAILS SEE THE FILE README

;------------------------------------------------------------------------------------
align 8
fftcv__piper180    dq  0.017453292519943296

fftcv_bandindices  dq  fftcv_bandindex64   , ( 14 shl 32) + 64
                   dq  fftcv_bandindex32   , ( 13 shl 32) + 32
                   dq  fftcv_bandindex64v1 , ( 12 shl 32) + 64
                   dq  fftcv_bandindex32v1 , ( 11 shl 32) + 32

;32-bands
fftcv_bandindex32:

  dd 2   , 3                              ;15.625  c g
  dd 4   , 5   , 6                        ;31.25   c e g
  dd 8   , 10  , 12                       ;62.5    c e g
  dd 16  , 20  , 24                       ;125     c e g
  dd 32  , 40  , 48                       ;250     c e g
  dd 64  , 81  , 96                       ;500     c e g
  dd 128 , 161 , 192                      ;1000    c e g
  dd 256 , 323 , 384                      ;2000    c e g
  dd 512 , 645 , 767                      ;4000    c e g
  dd 1024, 1290, 1534                     ;8000    c e g
  dd 2048, 2580, 3069                     ;16000   c e g

;32-bands v1.0
fftcv_bandindex32v1:

  dd    1,  2,  3,  4,   6,  8, 12, 16    ;31.25   c1  c2  g2  c3  g3  c4  g4  c5
  dd   20, 24, 32, 40,  48, 64, 72, 81    ;        e5  g5  c6  e6  g6  c7  d7  e7
  dd   96,128,144,161, 192,256,287,323    ;        g7  c8  d8  e8  g8  c9  d9  e9
  dd  384,456,512,575, 645,767,912,1024   ;        g9  a#9 c10 d10 e10 g10 a#10 c11

;64-bands
fftcv_bandindex64:

  dd 3                                    ;7.8125  g
  dd 4   , 5   , 6   , 7                  ;15.625  c  e  g  a#
  dd 8   , 9   , 10  , 11  , 12  , 14     ;31.25   c  d  e  f  g  a#
  dd 16  , 18  , 20  , 21  , 24  , 29     ;62.5    c  d  e  f  g  a#
  dd 32  , 36  , 40  , 43  , 48  , 57     ;125     c  d  e  f  g  a#
  dd 64  , 72  , 81  , 85  , 96  , 114    ;250     c  d  e  f  g  a#
  dd 128 , 144 , 161 , 171 , 192 , 228    ;500     c  d  e  f  g  a#
  dd 256 , 287 , 323 , 342 , 384 , 456    ;1000    c  d  e  f  g  a#
  dd 512 , 575 , 645 , 683 , 767 , 912    ;2000    c  d  e  f  g  a#
  dd 1024, 1149, 1290, 1367, 1534, 1825   ;4000    c  d  e  f  g  a#
  dd 2048, 2299, 2580, 2734, 3069, 3649   ;8000    c  d  e  f  g  a#
  dd 4096, 4598, 5161, 5468, 6137, 7298   ;16000   c  d  e  f  g  a#

;64-bands v1.0
fftcv_bandindex64v1:

  dd    1,   2,   3,   4,    5,   6,   7,   8  ;15.625  C0   c1   G1   c2   E2   g2   A#2  c3
  dd   10,  12,  14,  16,   20,  24,  29,  32  ;        E3   g3   A#3  c4   E4   g4   A#4  c5
  dd   36,  40,  43,  48,   57,  64,  72,  80  ;        D5   e5   F5   g5   A#5  c6   D6   e6
  dd   85,  96, 114, 128,  136, 144, 152, 161  ;        F6   g6   A#6  c7   C#7  d7   D#7  e7
  dd  171, 192, 228, 256,  271, 287, 304, 323  ;        F7   g7   A#7  c8   C#8  d8   D#8  e8
  dd  342, 384, 456, 512,  542, 575, 609, 645  ;        F8   g8   A#8  c9   C#9  d9   D#9  e9
  dd  683, 767, 861, 912,  967,1024,1085,1149  ;        F9   g9   a9   a#9  h9   c10  c#10 d10
  dd 1218,1290,1367,1534, 1722,1825,1933,2048  ;        d#10 e10  F10  g10  A10  a#10 H10  c11
;------------------------------------------------------------------------------------
