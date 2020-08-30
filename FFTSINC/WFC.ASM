
; THIS FILE IS PART OF THE 'WAVE FORMAT CONVERTER' LIBRARY SOURCE CODE
; COPYRIGHT (C) 2010 Akos Mogyorosi <flowwolf>
; FOR DETAILS SEE THE FILE README

; WAVE FORMAT CONVERTER  27/06/2010

;wfc_init
;wfc_deinit
;wfc_read


;------------------------------------------------------------------------------------
;WAVE FORMAT CONVERTER INIT
;IN:   rcx -  stream type                                                     uses: -
;      rdx -  stream param 1
;      r8  -  stream param 2
;      r9  - *wfciface [out]
;      r10 - *wfcinfo [out]
;
;OUT:  rax -  wfc_lasterror
;
;NOTE: every successful call to wfc_init involves a call to wfc_deinit

wfc_init:
                      push   r14, r11, rsi, rbp, rcx

                      xchg   rcx , r11                     ;r11 -  stream type

                      ;xor    eax , eax  ;all x64 support SSE2
                      ;inc    eax
                      ;push   rbx
                      ;cpuid
                      ;pop    rbx
                      ;bt     edx , 26
                      ;mov    rax , D WFC_ERR_SSE2_NOT_SUPPORTED
                      ;jnc    .err
                      mov    ecx , wfc_infoblocksize + 16
                      call   memallocz
                      test   rax , rax
                      jnz    .sk10
                      mov    rax , WFC_ERR_NOT_ENOUGH_MEMORY
              .err:
                      pop    rcx, rbp, rsi, r11, r14
                      ret
             .sk10:
                      mov    rcx , rax
                      test   al  , 15
                      jz     .sk12
                      and    al  , 15 xor -1
                      add    rax , 16
             .sk12:   mov    [rax + wfc_infoblock], rcx
                      mov    [r9], rax
                      xchg   rax , rbp                     ;rbp -  infoblock

                      mov    rcx , r11                     ;open stream
                      call   openstream
                      mov    eax , [rbp + wfc_lasterror]
                      jc     .err

                      call   wfc_check_WAV                 ;check header
                      mov    eax , [rbp + wfc_lasterror]
                      jc     .err

                      lea    rax , [rbp + wfc_info]
                      mov    [r10], rax
                      mov    [rbp + wfc_rsi], rsi
                      mov    [rbp + wfc_r14], r14

                      xor    eax , eax
                      pop    rcx, rbp, rsi, r11, r14
                      ret
;------------------------------------------------------------------------------------




;------------------------------------------------------------------------------------
;IN:   rbp -  infoblock                                                uses: r14, rsi
;      rsi - *stream
;      r14 -  streamsize
;
;OUT:  rax -  zero if found
;      CF set on error

wfc_check_WAV:
                      push   rcx

                      sub    r14 , 0x14
                      jnc    .nors1
                      call   readstream
                      jc     .err
            .nors1:   lodsq
                      cmp    eax , "RIFF"
                      jnz    .sk10
                      lodsq
                      mov    rcx , "WAVEfmt "
                      cmp    rcx , rax
                      jnz    .sk10
                      lodsd
                      add    eax , 8
                      sub    r14 , rax
                      jnc    .nors2
                      call   readstream
                      jc     .err
            .nors2:   lodsd
                      cmp    ax  , WFC_FORMAT_TAG_PCM
                      jz     .sk12
                      cmp    ax  , WFC_FORMAT_TAG_IEEE_FLOAT
                      jz     .sk12
                      jmp    .sk10
             .sk12:   mov    [rbp + wfc_info + WFC_INFO_FORMAT_TAG], ax
                      shr    eax , 16
                      mov    [rbp + wfc_info + WFC_INFO_CHANNELS], eax
                      lodsd
                      mov    [rbp + wfc_info + WFC_INFO_RATE], eax
                      lodsd
                      lodsd
                      shr    eax , 16
                      mov    [rbp + wfc_info + WFC_INFO_BITSPERSAMP], eax
                      lodsq
                      cmp    eax , "data"
                      jnz    .sk10
                      shr    rax , 32
                      mov    [rbp + wfc_info + WFC_INFO_SIZE], eax

                      mov    eax , [rbp + wfc_info + WFC_INFO_CHANNELS]
                      imul   eax , [rbp + wfc_info + WFC_INFO_BITSPERSAMP]
                      shr    eax , 3
                      mov    [rbp + wfc_info + WFC_INFO_SAMPSIZE], eax

                      mov    eax , [rbp + wfc_info + WFC_INFO_FORMAT_TAG]
                      cmp    eax , WFC_FORMAT_TAG_IEEE_FLOAT
                      setz   al
                      shl    al  , 4
                      mov    ecx , [rbp + wfc_info + WFC_INFO_BITSPERSAMP]
                      shr    ecx , 3
                      or     ecx , eax
                      mov    eax , [rbp + wfc_info + WFC_INFO_CHANNELS]
                      shl    eax , 8
                      or     eax , ecx
                      mov    [rbp + wfc_info + WFC_INFO_SCFORMAT], eax

                      mov    D [rbp + wfc_info + WFC_INFO_FORMAT], WFC_FORMAT_WAV

                      xor    eax , eax
                      pop    rcx
                      ret
             .sk10:
                      xor    ecx , ecx
                      mov    dl  , STREAM_SEEK_BEGIN
                      call   seekstream
                      jc     .err
                      or     eax , -1
              .err:   pop    rcx
                      ret
;------------------------------------------------------------------------------------




;------------------------------------------------------------------------------------
;WAVE FORMAT CONVERTER DEINIT
;IN:   rcx -  wfciface                                                        uses: -
;
;OUT:  rax -  WFC_ERR_OK

wfc_deinit:
                      push   rbp, rcx

                      xchg   rcx , rbp                     ;rbp -  wfciface
                      call   closestream
                      mov    rcx , [rbp + wfc_infoblock]
                      call   memfree

                      xor    eax , eax
                      pop    rcx, rbp
                      ret
;------------------------------------------------------------------------------------




;------------------------------------------------------------------------------------
;WAVE FORMAT CONVERTER READ
;IN:   rcx -  wfciface                                                        uses: -
;      rdx - *out
;      r8  -  number of samples to read
;
;OUT:  rax -  number of samples read

wfc_read:
                      push   r14, rdi, rsi, rbp, rdx, rcx

                      xchg   rcx , rbp                     ;rbp -  wfciface
                      xchg   rdx , rdi                     ;rdi - *out

                      mov    rsi , [rbp + wfc_rsi]
                      mov    r14 , [rbp + wfc_r14]

                      ;only RAW and WAV are supported
                      mov    rcx , r8
                      imul   ecx , [rbp + wfc_info + WFC_INFO_CHANNELS]
                      imul   ecx , [rbp + wfc_info + WFC_INFO_BITSPERSAMP]
                      shr    ecx , 3
                      mov    rdx , rdi
                      call   copystream
                      xchg   rax , rdx
                      sub    rax , rdi
                      mov    ecx , [rbp + wfc_info + WFC_INFO_CHANNELS]
                      imul   ecx , [rbp + wfc_info + WFC_INFO_BITSPERSAMP]
                      shr    ecx , 3
                      cdq
                      div    ecx

                      mov    [rbp + wfc_rsi], rsi
                      mov    [rbp + wfc_r14], r14

                      pop    rcx, rdx, rbp, rsi, rdi, r14
                      ret
;------------------------------------------------------------------------------------












