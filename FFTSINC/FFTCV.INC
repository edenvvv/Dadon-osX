
; THIS FILE IS PART OF THE 'FFT CONVOLUTION KERNEL' LIBRARY SOURCE CODE
; COPYRIGHT (C) 2010 Akos Mogyorosi <flowwolf>
; FOR DETAILS SEE THE FILE README

  FFTCV_CONVBUFFSIZE  =  1024


;------------------------------------------------------------------------------------
;strc infoblock
strc_infoblocksize = 0

macro strcdefine a,b
{
 a = strc_infoblocksize
 strc_infoblocksize = strc_infoblocksize + b
}

macro strcalign a
{
 if (strc_infoblocksize and (a-1)) <> 0
 strc_infoblocksize = strc_infoblocksize + a
 strc_infoblocksize = (strc_infoblocksize and ((a-1) xor -1))
 end if
}
;------------------------------------------------------------------------------------
strcdefine  strc_infoblock, 8         ;*infoblock  (unaligned)
strcdefine  strc_wfciface, 8          ;
strcdefine  strc_wfcinfo, 8           ;
strcdefine  strc_fmchiface, 8         ;
strcalign 16
strcdefine  strc_fpummxssestate, 512  ;
strcdefine  strc_buff, 0              ; inbuff/outbuff
;------------------------------------------------------------------------------------


;------------------------------------------------------------------------------------
;fmch infoblock
fmch_infoblocksize = 0

macro fmchdefine a,b
{
 a = fmch_infoblocksize
 fmch_infoblocksize = fmch_infoblocksize + b
}

macro fmchalign a
{
 if (fmch_infoblocksize and (a-1)) <> 0
 fmch_infoblocksize = fmch_infoblocksize + a
 fmch_infoblocksize = (fmch_infoblocksize and ((a-1) xor -1))
 end if
}
;------------------------------------------------------------------------------------
fmchdefine  fmch_infoblock, 8      ;*infoblock  (unaligned)
fmchdefine  fmch_maxlength, 8      ; max length
fmchdefine  fmch_sciface, 8        ; sc interface
fmchdefine  fmch_fftcvifaces, 48*8 ; fftcv interfaces
fmchdefine  fmch_format, 8         ; format
fmchdefine  fmch_bufflength, 8     ; bufflength
fmchdefine  fmch_buff, 16          ;*buff       (aligned/unaligned)
fmchdefine  fmch_aslist, 48*8      ; aslist
fmchalign 16
fmchdefine  fmch_fpummxssestate, 512
;------------------------------------------------------------------------------------


;------------------------------------------------------------------------------------
;fftcv infoblock
fftcv_infoblocksize = 0

macro fftcvdefine a,b
{
 a = fftcv_infoblocksize
 fftcv_infoblocksize = fftcv_infoblocksize + b
}

macro fftcvalign a
{
 if (fftcv_infoblocksize and (a-1)) <> 0
 fftcv_infoblocksize = fftcv_infoblocksize + a
 fftcv_infoblocksize = (fftcv_infoblocksize and ((a-1) xor -1))
 end if
}
;------------------------------------------------------------------------------------
fftcvdefine  fftcv_infoblock, 8      ;*fftconv infoblock  (unaligned)
fftcvdefine  fftcv_ffttab, 8         ;*ffttab
fftcvdefine  fftcv_convbuff, 8       ;*convbuff
fftcvdefine  fftcv_outbuff, 8        ;*outbuff
fftcvdefine  fftcv_fftbuff, 8        ;*fftbuff
fftcvdefine  fftcv_fftbufffil, 8     ;*fftbuff filter
fftcvdefine  fftcv_fftbufffilc, 8    ;*fftbuff filter coeffs
fftcvdefine  fftcv_auxbuffer,8       ;*aux buffer
fftcvdefine  fftcv_maxlength, 8      ; max filter length
fftcvdefine  fftcv_maxn, 8           ; max n
fftcvdefine  fftcv_max2n, 8          ; max 2^n
fftcvdefine  fftcv_and, 8            ; and
fftcvdefine  fftcv_length, 8         ; filter length
fftcvdefine  fftcv_n, 8              ; n
fftcvdefine  fftcv_2n, 8             ; 2^n
fftcvdefine  fftcv_prevn, 8          ; prev n
fftcvdefine  fftcv_prev2n, 8         ; prev 2^n
fftcvdefine  fftcv_newlength, 8      ; new filter length
fftcvdefine  fftcv_newn, 8           ; new n
fftcvdefine  fftcv_new2n, 8          ; new 2n
fftcvdefine  fftcv_convbuffpos, 8    ; convbuffpos
fftcvdefine  fftcv_state, 8          ; state
fftcvdefine  fftcv_inlen, 8          ; inlen
fftcvdefine  fftcv_outlen, 8         ; outlen
fftcvalign 16
fftcvdefine  fftcv_kbdwin, 16
fftcvdefine  fftcv_expwin, 16
fftcvdefine  fftcv_fpummxssestate,  512
fftcvdefine  fftcv_fpummxssestatec, 512
fftcvdefine  fftcv_area, 0           ;name:        size:
                                     ;
                                     ;convbuff     max2n*4
                                     ;outbuff      max2n*4
                                     ;fftbuff      max2n*8*2
                                     ;fftbufffil   max2n*8*2
                                     ;fftbufffilc  max2n*8*2
                                     ;auxbuffer    max2n*8*2
;------------------------------------------------------------------------------------
;eq
  FFTCV_EQ_64BANDS           =  -1
  FFTCV_EQ_64BANDSV1         =  -3
  FFTCV_EQ_32BANDS           =  -2
  FFTCV_EQ_32BANDSV1         =  -4
  FFTCV_LENGTH_64BANDS       =  16384+1
  FFTCV_LENGTH_64BANDSV1     =  4096+1
  FFTCV_LENGTH_32BANDS       =  8192+1
  FFTCV_LENGTH_32BANDSV1     =  2048+1

;states
  FFTCV_ST_LEADING_DELAY     =  1
  FFTCV_ST_LD_APPLIED        =  2

;attributes
  FFTCV_ATTRIBUTE_KBDWIN     =  -1
  FFTCV_ATTRIBUTE_EXPWIN     =  -2

;wave formats
  FFTCV_FORMAT_8B_M          =  (4     )
  FFTCV_FORMAT_8B_ST_L       =  (4+2+0 )
  FFTCV_FORMAT_8B_ST_R       =  (4+2+1 )
  FFTCV_FORMAT_16B_M         =  (8     )
  FFTCV_FORMAT_16B_ST_L      =  (8+2+0 )
  FFTCV_FORMAT_16B_ST_R      =  (8+2+1 )
  FFTCV_FORMAT_32B_M         =  (16    )
  FFTCV_FORMAT_32B_ST_L      =  (16+2+0)
  FFTCV_FORMAT_32B_ST_R      =  (16+2+1)
  FFTCV_FORMAT_FLOAT32_M     =  (32    )
  FFTCV_FORMAT_FLOAT32_ST_L  =  (32+2+0)
  FFTCV_FORMAT_FLOAT32_ST_R  =  (32+2+1)
  FFTCV_TRAILING_DELAY         = -1
  FFTCV_TRAILING_DELAY_LENGTH  = -2
;------------------------------------------------------------------------------------
;error codes
  FFTCV_ERR_OK                 =  0
  FFTCV_ERR_NOT_ENOUGH_MEMORY  = -11
  FFTCV_ERR_SSE2_NOT_SUPPORTED = -12
  FFTCV_ERR_INVALID_FORMAT     = -13
  FFTCV_ERR_INVALID_OPERATION  = -14
;------------------------------------------------------------------------------------
















