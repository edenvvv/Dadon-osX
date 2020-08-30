
; COPYRIGHT (C) 2008-2010 Akos Mogyorosi <flowwolf>
; FOR DETAILS SEE THE FILE README

; INPUT STREAMING v1.8.0 (64-bit)  13/04/2010

;------------------------------------------------------------------------------------
;OPEN STREAM
;IN:   ecx -  stream type                                  uses: rsi,r14,rcx,rax only
;      rdx -  stream param1
;      r8  -  stream param2
;      rbp - *infoblock
;
;OUT:  rsi - *stream
;      r14 -  size
;      CF set on error

openstream:
                      mov    [rbp+streamtype], ecx
                      mov    [rbp+streamparam1], rdx
                      mov    [rbp+streamparam2], r8
if DEF_MEMORY_STREAM=1
                      cmp    cl , STREAM_TYPE_MEM   ;memory stream
                      jnz    .strm_nomem

                      mov    rsi , rdx
                      mov    r14 , r8

                      ret
        .strm_nomem:
end if
if DEF_FILE_STREAM=1
    if DEF_CALLBACK_STREAM=1
                      cmp    cl , STREAM_TYPE_FILE  ;file stream
                      jnz    .strm_nofile
    end if
                      ;---------- REPLACE THIS ----------
                      push   rbx

                      mov    rbx , rdx
                      call   fopen
                      test   rax , rax
                      jnz    .sk00
                      dec    rax
             .sk00:
                      pop    rbx
                      ;---------- REPLACE THIS ----------
                      mov    [rbp+streamparam2], rax  ;streamparam2=filehndl
                      cmp    rax , INVALID_HANDLE_VALUE
                      setlasterror STREAM_ERR_FILE_NOT_FOUND
                      jz     .err
       .strm_nofile:
end if
if (DEF_FILE_STREAM=1 | DEF_CALLBACK_STREAM=1)
                      ;allocate streambuffer (file and callback streams)
                      mov    ecx , DEF_STREAMBUFFSIZE+16 +8
                      call   memallocz
                      test   rax , rax
                      setlasterror STREAM_ERR_NOT_ENOUGH_MEMORY
                      jz     .err
                      mov    rcx , rax
                      test   al  , 15
                      jz     .sk10
                      and    al  , 15 xor -1
                      add    rax , 16
              .sk10:  mov    [rbp+streambuff], rax
                      mov    [rax+DEF_STREAMBUFFSIZE], rcx

                      lea    rsi , [rax+DEF_STREAMBUFFSIZE]  ;rsi=*streambuff+DEF_STREAMBUFFSIZE
                      xor    r14 , r14                       ;r14=0
                      mov    [rbp+streamfileptr], r14        ;reset filepointer
                      setlasterror STREAM_ERR_OK
                      ret
               .err:  stc
                      ret
end if
;------------------------------------------------------------------------------------




;------------------------------------------------------------------------------------
;READ STREAM
;IN:   rsi, r14                                        uses: rsi,r14,rdx,rcx,rax only
;      rbp - *infoblock
;
;OUT:  rsi, r14
;      CF set on error

readstream:
                      setlasterror STREAM_ERR_OK
if DEF_MEMORY_STREAM=1
    if (DEF_FILE_STREAM=1 | DEF_CALLBACK_STREAM=1)
                      cmp    D [rbp+streamtype], STREAM_TYPE_MEM  ;memory stream
                      jnz    .strm_nomem
    end if
                      setlasterror STREAM_ERR_STREAM_READ
                      stc
                      ret
        .strm_nomem:
end if
if (DEF_FILE_STREAM=1 | DEF_CALLBACK_STREAM=1)
                      push   rdi
                      mov    rdi , [rbp+streambuff]    ;copy bytes remained
                      mov    edx , DEF_STREAMBUFFSIZE
                      lea    rcx , [rdi+rdx]
                      sub    rcx , rsi
                      sub    rdx , rcx
                      mov    rax , rcx
                      shr    rcx , 3
                      and    eax , 7
                      rep movsq
                      xchg   rax , rcx
                      rep movsb
                      push   rax
                      mov    rax , rsp

                      cmp    D [rbp+streamtype], STREAM_TYPE_CALLBACK  ;callback stream
                      jnz    .strm_nocallback
if DEF_CALLBACK_STREAM=1
                      push   Q [rbp+streamparam2], rdi, rdx, Q [rbp+streamfileptr], rax
                      call   Q [rbp+streamparam1]
                      jmp    .sk10
end if
   .strm_nocallback:
if DEF_FILE_STREAM=1
                      ;---------- REPLACE THIS ----------
                      push   r8, rbx

                      mov    rbx , [rbp + streamparam2]
                      mov    rcx , rdi
                      mov    r8  , rax
                      call   fread
                      test   rax , rax
                      setz   al
                      and    eax , 1

                      pop    rbx, r8
                      ;---------- REPLACE THIS ----------
end if
              .sk10:  pop    rcx
                      test   rax , rax
                      jz     .err
                      jrcxz  .err
                      add    [rbp+streamfileptr], rcx
                      sub    rdx , DEF_STREAMBUFFSIZE
                      neg    rdx
                      add    rdx , rcx
                      mov    [rbp+streambuffsize] , rdx
                      add    r14 , rcx

                      pop    rdi
                      mov    rsi , [rbp+streambuff]  ;reset rsi
                      clc
                      ret
               .err:  pop    rdi
                      setlasterror STREAM_ERR_STREAM_READ
                      stc
                      ret
end if
;------------------------------------------------------------------------------------




;------------------------------------------------------------------------------------
;SEEK STREAM
;IN:   rcx -  distance to move (signed)                    uses: rsi,r14,rcx,rax only
;       dl -  move method
;      rbp - *infoblock
;
;OUT   rsi, r14
;      CF set on error

seekstream:
                      setlasterror STREAM_ERR_OK
if DEF_MEMORY_STREAM=1
    if (DEF_FILE_STREAM=1 | DEF_CALLBACK_STREAM=1)
                      cmp    D [rbp+streamtype], STREAM_TYPE_MEM  ;memory stream
                      jnz    .strm_nomem
    end if
                      cmp    dl , STREAM_SEEK_CURRENT
                      jz     .strm_mem_CURRENT
                      cmp    dl , STREAM_SEEK_FORCECURRENT
                      jz     .strm_mem_CURRENT
                      mov    rsi , [rbp+streamparam1]  ;movemethod: BEGIN
                      mov    r14 , [rbp+streamparam2]
                      add    rsi , rcx
                      sub    r14 , rcx
                      jnbe   .strm_mem_end
      .strm_mem_err:  setlasterror STREAM_ERR_STREAM_SEEK
                      stc
                      ret
  .strm_mem_CURRENT:  add    rsi , rcx                 ;movemethod: CURRENT
                      sub    r14 , rcx
                      jle    .strm_mem_err
                      cmp    r14 , [rbp+streamparam2]
                      ja     .strm_mem_err
      .strm_mem_end:  clc
                      ret
        .strm_nomem:
end if
if DEF_FILE_STREAM=1
    if DEF_CALLBACK_STREAM=1
                      cmp    D [rbp+streamtype], STREAM_TYPE_FILE  ;file stream
                      jnz    .strm_nofile
    end if
                      cmp    dl , STREAM_SEEK_CURRENT
                      jz     .strm_file_CURRENT
                      cmp    dl , STREAM_SEEK_FORCECURRENT
                      jz     .strm_file_FCURRENT
   .strm_file_BEGIN:                                   ;movemethod: BEGIN
                      ;---------- REPLACE THIS ----------
                      push   rbx, rdx

                      mov    rbx , [rbp + streamparam2]
                      mov    edx , STREAM_SEEK_BEGIN
                      call   fseek
                      mov    [rbp + streamfileptr], rax

                      pop    rdx, rbx
                      ;---------- REPLACE THIS ----------
                      test   rax , rax
                      jz     .strm_file_err
                      mov    rsi , [rbp+streambuff]
                      add    rsi , DEF_STREAMBUFFSIZE
                      xor    r14 , r14
                      call   readstream
                      ret
     .strm_file_err:  setlasterror STREAM_ERR_STREAM_SEEK
                      stc
                      ret
 .strm_file_CURRENT:                                   ;movemethod: CURRENT
                      add    rsi , rcx
                      sub    r14 , rcx
                      jle    .strm_file_CURREAD
                      cmp    r14 , [rbp+streambuffsize]
                      ja     .strm_file_CURREAD
                      clc
                      ret
.strm_file_FCURRENT:  sub    r14 , rcx                 ;movemethod: FORCECURRENT
 .strm_file_CURREAD:  neg    r14
                      add    r14 , [rbp+streamfileptr]
                      mov    rcx , r14
                      jmp    .strm_file_BEGIN
       .strm_nofile:
end if
if DEF_CALLBACK_STREAM=1
                      cmp    dl , STREAM_SEEK_CURRENT  ;callback stream
                      jz     .strm_cb_CURRENT
                      cmp    dl , STREAM_SEEK_FORCECURRENT
                      jz     .strm_cb_FCURRENT
     .strm_cb_BEGIN:  mov    [rbp+streamfileptr], rcx  ;movemethod: BEGIN
                      mov    rsi , [rbp+streambuff]
                      add    rsi , DEF_STREAMBUFFSIZE
                      xor    r14 , r14
                      call   readstream
                      ret
   .strm_cb_CURRENT:                                   ;movemethod: CURRENT
                      add    rsi , rcx
                      sub    r14 , rcx
                      jle    .strm_cb_CURREAD
                      cmp    r14 , [rbp+streambuffsize]
                      ja     .strm_cb_CURREAD
                      clc
                      ret
  .strm_cb_FCURRENT:  sub    r14 , rcx                 ;movemethod: FORCECURRENT
   .strm_cb_CURREAD:  neg    r14
                      add    r14 , [rbp+streamfileptr]
                      mov    rcx , r14
                      jmp    .strm_cb_BEGIN
end if
;------------------------------------------------------------------------------------




;------------------------------------------------------------------------------------
;GET STREAM POSITION
;IN:   rsi, r14                                                        uses: rax only
;      rbp -  *infoblock
;
;OUT:  rax -  pos

getstreampos:
if ((DEF_FILE_STREAM=1 | DEF_CALLBACK_STREAM=1) & DEF_MEMORY_STREAM=1)
                      cmp    D [rbp+streamtype], STREAM_TYPE_MEM  ;memory stream
                      jnz    .strm_nomem
end if
if DEF_MEMORY_STREAM=1
                      mov    rax , rsi
                      sub    rax , [rbp+streamparam1]
                      ret
end if
if (DEF_FILE_STREAM=1 | DEF_CALLBACK_STREAM=1)
        .strm_nomem:
                      mov    rax , [rbp+streamfileptr]  ;file/callback streams
                      sub    rax , [rbp+streambuffsize]
                      add    rax , rsi
                      sub    rax , [rbp+streambuff]
                      ret
end if
;------------------------------------------------------------------------------------




;------------------------------------------------------------------------------------
;GET STREAM SIZE
;IN:   rsi, r14                                                        uses: rax only
;      rbp - *infoblock
;
;OUT:  rax -  size

getstreamsize:
if (DEF_FILE_STREAM=1 | DEF_CALLBACK_STREAM=1)
                      xor    eax , eax
    if DEF_MEMORY_STREAM=1
                      cmp    D [rbp+streamtype], STREAM_TYPE_MEM  ;memory stream
                      jnz    .strm_nomem
    end if
end if
if DEF_MEMORY_STREAM=1
                      mov    rax , [rbp+streamparam2]
                      ret
end if
        .strm_nomem:
if DEF_FILE_STREAM=1
    if DEF_CALLBACK_STREAM=1
                      cmp    D [rbp+streamtype],STREAM_TYPE_FILE  ;file stream
                      jnz    .strm_nofile
    end if
                      ;---------- REPLACE THIS ----------
                      push   rbx

                      mov    rbx , [rbp + streamparam2]
                      call   fgetsize

                      pop    rbx
                      ;---------- REPLACE THIS ----------
                      ret
       .strm_nofile:
end if
if DEF_CALLBACK_STREAM=1
                      push   Q [rbp+streamparam2], rax, rax, rax, rax
                      call   Q [rbp+streamparam1]
                      ret
end if
;------------------------------------------------------------------------------------




;------------------------------------------------------------------------------------
;COPY STREAM
;IN:   rsi, r14                                        uses: rsi,r14,rdx,rcx,rax only
;      rcx -  length
;      rdx - *destination
;      rbp - *infoblock
;
;OUT:  rsi, r14
;      rcx -  zero
;      rdx - *destination + length
;      CF set on error

copystream:
                      xchg   rdx , rdi
              .lp10:  cmp    r14 , rcx
                      jae    .sk10
                      sub    rcx , r14
                      push   rdx , rcx
                      mov    rcx , r14
                      shr    rcx , 3
                      rep movsq
                      mov    rcx , r14
                      and    ecx , 7
                      rep movsb
                      xor    r14 , r14
                      call   readstream
                      pop    rcx , rdx
                      jc     .err
                      jmp    .lp10
              .sk10:  sub    r14 , rcx
                      mov    rax , rcx
                      shr    rcx , 3
                      and    eax , 7  ;CF=0
                      rep movsq
                      xchg   rax , rcx
                      rep movsb
               .err:  xchg   rdx , rdi
                      ret
;------------------------------------------------------------------------------------




;------------------------------------------------------------------------------------
;CLOSE STREAM
;IN:   rbp - *infoblock                                            uses: rcx,rax only
;
;OUT:  -

closestream:
if DEF_FILE_STREAM=1
    if (DEF_MEMORY_STREAM=1 | DEF_CALLBACK_STREAM=1)
                      cmp    D [rbp+streamtype], STREAM_TYPE_FILE
                      jnz    .strm_nofile
    end if
                      mov    rax , [rbp+streambuff]
                      test   rax , rax
                      jz     .sk10
                      mov    rcx , [rax+DEF_STREAMBUFFSIZE]
                      call   memfree
              .sk10:  mov    rax , [rbp+streamparam2]
                      cmp    rax , INVALID_HANDLE_VALUE
                      jz     .strm_nofile
                      ;---------- REPLACE THIS ----------
                      push   rbx

                      mov    rbx , rax
                      call   fclose

                      pop    rbx
                      ;---------- REPLACE THIS ----------
       .strm_nofile:
end if
                      ret
;------------------------------------------------------------------------------------


align 8

STREAMBUFFSIZE dq DEF_STREAMBUFFSIZE




