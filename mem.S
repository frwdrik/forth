    // MEMORY

    // M[stack0] = stack1
    defcode "!",1,,STORE
    pop %rbx
    pop %rax
    mov %rax,(%rbx)
    NEXT

    defcode "@",1,,FETCH
    pop %rbx
    mov (%rbx),%rax
    push %rax
    NEXT

    defcode "+!",2,,ADDSTORE
    pop %rbx
    pop %rax
    add %rax,(%rbx)
    NEXT

    defcode "-!",2,,SUBSTORE
    pop %rbx
    pop %rax
    sub %rax,(%rbx)
    NEXT

    // ( byte addr -- )
    defcode "C!",2,,STOREBYTE
    pop %rbx
    pop %rax
    mov %al, (%rbx)
    NEXT

    // ( addr -- byte )
    defcode "C@",2,,LOADBYTE
    pop %rbx
    xor %rax, %rax
    mov (%rbx), %al
    push %rax
    NEXT

    // block copy, ( source dest len )
    defcode "CMOVE",5,,CMOVE
    mov %rsi, %rdx
    pop %rcx
    pop %rdi
    pop %rsi
    rep movsb
    mov %rdx, %rsi
    NEXT

    defcode ">R",2,,TOR
    pop %rax
    PUSHRSP %rax
    NEXT

    defcode "R>",2,,FROMR
    POPRSP %rax
    push %rax
    NEXT

    // pushes value from return stack ontto data stack
    defcode "RSP@",4,,RSPFETCH
    push %rbp
    NEXT

    // pops value from data stack to return stack
    defcode "RSP!",4,,RSPSTORE
    pop %rbp
    NEXT

    // get current stack pointer
    defcode "DSP@",4,,DSPFETCH
    mov %rsp, %rax
    push %rax
    NEXT

    // set stack pointer
    defcode "DSP!",4,,DSPSTORE
    pop %rsp
    NEXT
