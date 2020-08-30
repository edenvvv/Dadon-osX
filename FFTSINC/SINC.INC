
; THIS FILE IS PART OF THE 'SINC RESAMPLING KERNEL' LIBRARY SOURCE CODE
; COPYRIGHT (C) 2008-2010 Akos Mogyorosi <flowwolf>
; FOR DETAILS SEE THE FILE README

  SINC_CONVBUFFSIZE  =  1024

  SINC_TABLE_VERY_HIGH_QUALITY  =  0
  SINC_TABLE_HIGH_QUALITY       =  1
  SINC_TABLE_MEDIUM_QUALITY     =  2
  SINC_TABLE_LOW_QUALITY        =  3
  SINC_TABLE_VERY_LOW_QUALITY   =  4

  SINC_BITS             =  0
  SINC_LENGTH           =  4
  SINC_LENGTH_PER_STEP  =  8
  SINC_STEP             =  12
  SINC_LOWPASS          =  16
  SINC_SHIFT            =  20
  SINC_WINDOW           =  24
  SINC_DEC              =  28
  SINC_TDSIZE           =  32


;------------------------------------------------------------------------------------
;strr infoblock
strr_infoblocksize = 0

macro strrdefine a,b
{
 a = strr_infoblocksize
 strr_infoblocksize = strr_infoblocksize + b
}

macro strralign a
{
 if (strr_infoblocksize and (a-1)) <> 0
 strr_infoblocksize = strr_infoblocksize + a
 strr_infoblocksize = (strr_infoblocksize and ((a-1) xor -1))
 end if
}
;------------------------------------------------------------------------------------
strrdefine  strr_infoblock, 8         ;*infoblock  (unaligned)
strrdefine  strr_wfciface, 8          ;
strrdefine  strr_wfcinfo, 8           ;
strrdefine  strr_sinctable, 8         ;
strrdefine  strr_smchiface, 8         ;
strralign 16
strrdefine  strr_fpummxssestate, 512  ;
strrdefine  strr_buff, 0              ; inbuff/outbuff
;------------------------------------------------------------------------------------


;------------------------------------------------------------------------------------
;smch infoblock
smch_infoblocksize = 0

macro smchdefine a,b
{
 a = smch_infoblocksize
 smch_infoblocksize = smch_infoblocksize + b
}

macro smchalign a
{
 if (smch_infoblocksize and (a-1)) <> 0
 smch_infoblocksize = smch_infoblocksize + a
 smch_infoblocksize = (smch_infoblocksize and ((a-1) xor -1))
 end if
}
;------------------------------------------------------------------------------------
smchdefine  smch_infoblock, 8      ;*infoblock  (unaligned)
smchdefine  smch_sciface, 8        ; sc interface
smchdefine  smch_sincifaces, 48*8  ; sinc interfaces
smchdefine  smch_format, 8         ; format
smchdefine  smch_bufflength, 8     ; bufflength
smchdefine  smch_buff, 16          ;*buff       (aligned/unaligned)
smchdefine  smch_aslist, 48*8      ; aslist
smchalign 16
smchdefine  smch_fpummxssestate, 512
;------------------------------------------------------------------------------------


;------------------------------------------------------------------------------------
;sinc infoblock
sinc_infoblocksize = 0

macro sincdefine a,b
{
 a = sinc_infoblocksize
 sinc_infoblocksize = sinc_infoblocksize + b
}

macro sincalign a
{
 if (sinc_infoblocksize and (a-1)) <> 0
 sinc_infoblocksize = sinc_infoblocksize + a
 sinc_infoblocksize = (sinc_infoblocksize and ((a-1) xor -1))
 end if
}
;------------------------------------------------------------------------------------
sincdefine  sinc_td, SINC_TDSIZE   ; sinc table data
sincdefine  sinc_table, 8          ;*sinc table
sincdefine  sinc_infoblock, 8      ;*sinc infoblock  (unaligned)
sincdefine  sinc_maxconvratio, 8   ; maximum conversion ratio  (double)
sincdefine  sinc_fract, 8          ; fractional part  (double
sincdefine  sinc_buffsize, 8       ; circular buffer size  (in samples)
sincdefine  sinc_buffpos, 8        ; circular buffer pos
sincdefine  sinc_state, 8          ; state
sincdefine  sinc_leading_delay, 8  ; leading delay
sincdefine  sinc_r11, 8            ; interpolation constants
sincdefine  sinc_r13, 8            ;
sincdefine  sinc_r12, 8            ; decimation constant
sincalign 16
sincdefine  sinc_convbuff, SINC_CONVBUFFSIZE*4
sincdefine  sinc_buff, 0           ;circular buffer
;------------------------------------------------------------------------------------
;state
  SINC_ST_LEADING_DELAY  =  1
  SINC_ST_FETCH          =  2
  SINC_ST_DECIMATION     =  4
  SINC_ST_FIRST_START    =  8

;sample formats
  SINC_FORMAT_8B_M          =  (4     )
  SINC_FORMAT_8B_ST_L       =  (4+2+0 )
  SINC_FORMAT_8B_ST_R       =  (4+2+1 )
  SINC_FORMAT_16B_M         =  (8     )
  SINC_FORMAT_16B_ST_L      =  (8+2+0 )
  SINC_FORMAT_16B_ST_R      =  (8+2+1 )
  SINC_FORMAT_32B_M         =  (16    )
  SINC_FORMAT_32B_ST_L      =  (16+2+0)
  SINC_FORMAT_32B_ST_R      =  (16+2+1)
  SINC_FORMAT_FLOAT32_M     =  (32    )
  SINC_FORMAT_FLOAT32_ST_L  =  (32+2+0)
  SINC_FORMAT_FLOAT32_ST_R  =  (32+2+1)
  SINC_TRAILING_DELAY         = -1
  SINC_TRAILING_DELAY_LENGTH  = -2
;------------------------------------------------------------------------------------
;error codes
  SINC_ERR_OK                  =  0
  SINC_ERR_NOT_ENOUGH_MEMORY   = -1
  SINC_ERR_SSE2_NOT_SUPPORTED  = -2
  SINC_ERR_INVALID_FORMAT      = -3
;------------------------------------------------------------------------------------
















