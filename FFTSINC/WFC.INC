
; THIS FILE IS PART OF THE 'WAVE FORMAT CONVERTER' LIBRARY SOURCE CODE
; COPYRIGHT (C) 2010 Akos Mogyorosi <flowwolf>
; FOR DETAILS SEE THE FILE README

  WFC_INFO_FORMAT       =  0
  WFC_INFO_FORMAT_TAG   =  4
  WFC_INFO_CHANNELS     =  8
  WFC_INFO_RATE         =  12
  WFC_INFO_BITSPERSAMP  =  16
  WFC_INFO_SAMPSIZE     =  20
  WFC_INFO_SCFORMAT     =  24
  WFC_INFO_SIZE         =  28
  WFC_INFOSIZE          =  32

;------------------------------------------------------------------------------------
;wfc infoblock
wfc_infoblocksize = 0

macro wfcdefine a,b
{
 a = wfc_infoblocksize
 wfc_infoblocksize = wfc_infoblocksize + b
}

macro wfcalign a
{
 if (wfc_infoblocksize and (a-1)) <> 0
 wfc_infoblocksize = wfc_infoblocksize + a
 wfc_infoblocksize = (wfc_infoblocksize and ((a-1) xor -1))
 end if
}
;------------------------------------------------------------------------------------
wfcdefine  wfc_infoblock,  8      ;*wfciface
wfcdefine  wfc_lasterror, 4       ;
wfcdefine  wfc_streamtype, 4      ;
wfcdefine  wfc_streamparam1, 8    ;
wfcdefine  wfc_streamparam2, 8    ;
wfcdefine  wfc_streambuff, 8      ;
wfcdefine  wfc_streamfileptr, 8   ;
wfcdefine  wfc_streambuffsize, 8  ;
wfcdefine  wfc_rsi, 8             ;
wfcdefine  wfc_r14, 8             ;
wfcdefine  wfc_info, WFC_INFOSIZE
;------------------------------------------------------------------------------------
  WFC_FORMAT_RAW  =  0
  WFC_FORMAT_WAV  =  1

  WFC_FORMAT_TAG_PCM         =  1
  WFC_FORMAT_TAG_IEEE_FLOAT  =  3
;------------------------------------------------------------------------------------
;error codes
  WFC_ERR_OK                  =  0
  WFC_ERR_NOT_ENOUGH_MEMORY   = -40
  WFC_ERR_SSE2_NOT_SUPPORTED  = -41
;------------------------------------------------------------------------------------
















