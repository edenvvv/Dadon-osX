
; THIS FILE IS PART OF THE 'SINC RESAMPLING KERNEL' LIBRARY SOURCE CODE
; COPYRIGHT (C) 2008-2010 Akos Mogyorosi <flowwolf>
; FOR DETAILS SEE THE FILE README

;------------------------------------------------------------------------------------
; SINC TABLE DATA
align 8

sinc_tables        dq  sinc_table1 , sinc_table2 , sinc_table3
                   dq  sinc_table4 , sinc_table5

sinc_table1        dd  21             ;2048-taps
                   dd  (1 shl 21)
                   dd  2048
                   dd  1024
                   dd  3
                   dd  0
                   dd  80.1106126665397276
                   dd  2

sinc_table2        dd  18             ;1024-taps
                   dd  (1 shl 18)
                   dd  1024
                   dd  256
                   dd  5
                   dd  0
                   dd  80.1106126665397276
                   dd  2

sinc_table3        dd  16             ;512-taps
                   dd  (1 shl 16)
                   dd  512
                   dd  128
                   dd  6
                   dd  0
                   dd  80.1106126665397276
                   dd  2

sinc_table4        dd  15             ;256-taps
                   dd  (1 shl 15)
                   dd  256
                   dd  128
                   dd  7
                   dd  0
                   dd  80.1106126665397276
                   dd  2

sinc_table5        dd  13             ;128-taps
                   dd  (1 shl 13)
                   dd  128
                   dd  64
                   dd  8
                   dd  0
                   dd  80.1106126665397276
                   dd  2
;------------------------------------------------------------------------------------
