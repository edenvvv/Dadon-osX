;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Audio processing - Memory manager
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


audio_memory:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Init audio memory
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    push  r15

    imul  r15 , 8*2
    mov   rdi , process_info_base_high
    add   r15 , rdi

    ; Memory position

    mov   rdi , 0x100000 * app_mem_top 
    cmp   rcx , rdi
    jae   ameml0
    cmp   rdx , rdi
    jae   ameml0
    mov   rax , rcx
    add   rax , rdx
    cmp   rax , rdi
    jae   ameml0

    ; Size atleast 256000 bytes

    cmp   rdx , 256000
    jae   ameml1

  ameml0:

    pop   r15

    mov   rax , -2
    ret
  ameml1:

    ; Memory start and size

    mov   [r15+0],rcx
    mov   [r15+8],rdx

    ; Init memory

    mov   rdi , rcx
    mov   rcx , 1040
    mov   rax , 0
    cld
    rep   stosq

    ;
    ; Add two entries
    ; one at the beginning and
    ; one at the end of memory area
    ;

    mov   rdi , [r15+0]
    mov  [rdi], dword 2
    ;
    mov   rax , rdi
    add   rax , 1024*8*2
    mov   [rdi+16],rax
    mov   [rdi+16+8],dword 1024
    ;
    mov   rax , rdi
    add   rax , [r15+8]

    sub   rax , 8192
    mov   [rdi+32],rax
    mov   [rdi+32+8],dword 1024

    pop   r15

    ; Success

    mov   rax , 0

    ret


audio_reserve_memory:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Reserve audio memory
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    push  rbx rcx rdx rsi rdi r15

    imul  r15 , 8*2
    mov   rdi , process_info_base_high
    add   r15 , rdi

    ; Area defined ?

    cmp   [r15+0],dword 0
    je    memresfail

    add   rcx , 130
    and   rcx , 0xfffff80

    mov   rsi , [r15+0]

    mov   rdx , [rsi]
    cmp   rdx , 790
    ja    memresfail
    cmp   rdx , 0
    je    memresfail

    ; scan mem

    dec   rdx
    add   rsi , 16

  scanmemmore:

    cmp   rdx , 0
    je    memresfail

    mov   rax , [rsi]
    add   rax , [rsi+8]
    mov   rbx , [rsi+16]
    sub   rbx , rax

    cmp   rcx , rbx
    ja    nocurrentmiddle

    ; mem slot found

    ; make room

    add   rsi , 16

    push  rsi
    push  rcx

    mov   rdi , rsi
    add   rdi , 16

    mov   rcx , [r15+0]

    add   rcx , 900*8*2
    sub   rcx , rsi

    add   rsi , rcx
    add   rdi , rcx

    add   rcx , 16

    std
    rep   movsb
    cld

    pop   rcx
    pop   rsi

    ; Check for valid entries

    push  rax rbx rcx rdx
    mov   rdx , 0x100000 * app_mem_top 
    cmp   rax , rdx
    jae   amemfail
    cmp   rcx , rdx
    jae   amemfail
    mov   rbx , rax
    add   rbx , rcx
    cmp   rbx , rdx
    jae   amemfail
    jmp   amemsuccess
  amemfail:
    ; Invalid, likely due to application
    ; memory corruption.
    jmp   amemfail
  amemsuccess:
    pop   rdx rcx rbx rax

    mov   [rsi],rax
    mov   [rsi+8],rcx

    cmp   r14 , 1
    jne   nomemclear
    call  clearmem
  nomemclear:

    mov   rsi , [r15+0]

    inc   qword [rsi]

    ; success

    pop   r15 rdi rsi rdx rcx rbx

    ret

  nocurrentmiddle:

    add   rsi , 16

    dec   rdx

    jmp   scanmemmore

  memresfail:

    mov   rax , 0

    ; fail

    pop   r15 rdi rsi rdx rcx rbx

    ret


audio_memory_free:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Free audio memory
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    push  rax rbx rcx rdx rsi rdi r15

    imul  r15 , 8*2
    mov   rdi , process_info_base_high
    add   r15 , rdi

    mov   rsi , [r15+0]

    mov   rdx , [rsi]

  scanmempos:

    cmp   rdx , 0
    je    nomemposfound

    add   rsi , 16

    cmp   [rsi],rcx
    jne   nothismempos

    push  rcx rsi rdi

    mov   rdi , rsi
    add   rsi , 16

    mov   rcx , [r15+0]

    add   rcx , 900*2*8
    sub   rcx , rdi
    cld
    rep   movsb

    mov   rsi , [r15+0]

    dec   qword [rsi]

    pop   rdi rsi rcx

  nothismempos:

    dec   rdx
    jmp   scanmempos

  nomemposfound:

    pop   r15 rdi rsi rdx rcx rbx rax

    ret



clearmem:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Clear reserved memory area
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    push  rax rcx rdi

    mov   rdi , rax
    mov   rax , 0
    cld
    rep   stosb

    pop   rdi rcx rax

    ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;   Memory functions
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

memalloc:
    push  r14
    mov   r14 , 0 ; no clear
    call  audio_reserve_memory
    pop   r14
    ret
memallocz:
    push  r14
    mov   r14 , 1 ; clear
    call  audio_reserve_memory
    pop   r14
    ret
memrealloc:
    push  r14
    mov   r14 , 0 ; no clear
    call  audio_memory_free
    call  audio_reserve_memory
    pop   r14
    ret
memreallocz:
    push  r14
    mov   r14 , 1 ; clear
    call  audio_memory_free
    call  audio_reserve_memory
    pop   r14
    ret
memsize:
    ; IN: rcx=*mem - OUT:  rax=size or -1
    mov   rax , -1
    ret
memfree:
    ; IN: rcx=*mem
    call  audio_memory_free
    ret







