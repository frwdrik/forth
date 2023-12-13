    // now some FORTH primitives

    defcode "DROP",4,,DROP
    // drop top of stack
    pop %rax
    NEXT

    defcode "SWAP",4,,SWAP
    pop %rax
    pop %rbx
    push %rax
    push %rbx
    NEXT

    defcode "DUP",3,,DUP
    // duplicate top of stack
    mov (%rsp), %rax
    push %rax
    NEXT

    defcode "OVER",4,,OVER
    // get second element of stack, duplicate it on top
    mov 8(%rsp), %rax
    push %rax
    NEXT

    defcode "ROT",3,,ROT
    // ( n1 n2 n3 -- n2 n3 n1 )
    // rotate, bring third element to front
    pop %rax
    pop %rbx
    pop %rcx
    push %rbx
    push %rax
    push %rcx
    NEXT

    defcode "-ROT",4,,NROT
    // ( n1 n2 n3 -- n3 n1 n2 )
    // rotate, bring second element to front
    pop %rax
    pop %rbx
    pop %rcx
    push %rax
    push %rcx
    push %rbx
    NEXT

    defcode "2DROP",5,,TWODROP
    pop %rax
    pop %rax
    NEXT

    defcode "2DUP",4,,TWODUP
    mov 8(%rsp), %rax
    mov (%rsp), %rbx
    push %rax
    push %rbx
    NEXT

    // swap top two pairs of elements of stack
    defcode "2SWAP",5,,TWOSWAP
    pop %rax
    pop %rbx
    pop %rcx
    pop %rdx
    push %rbx
    push %rax
    push %rdx
    push %rcx
    NEXT

    // duplicate top of stack if non-zero   
    defcode "?DUP",4,,QDUP
    mov (%rsp),%rax
    test %rax,%rax
    jz 1f
    push %rax
1:	NEXT

    defcode "1+",2,,INCR
    incq (%rsp)
    NEXT

    defcode "1-",2,,DECR
    decq (%rsp)
    NEXT

    defcode "4+",2,,INCR4
    addq $4, (%rsp)
    NEXT

    defcode "4-",2,,DECR4
    subq $4,(%rsp) 
    NEXT

    defcode "8+",2,,INCR8
    addq $8, (%rsp)
    NEXT

    defcode "8-",2,,DECR8
    subq $8,(%rsp)
    NEXT

    defcode "+",1,,ADD
    pop %rax  
    add %rax,(%rsp)
    NEXT

    // (a b) -> (a-b)
    defcode "-",1,,SUB
    pop %rax       
    sub %rax,(%rsp)
    NEXT

    defcode "*",1,,MUL
    pop %rax
    pop %rbx
    imul %rbx, %rax
    push %rax
    NEXT

    // https://en.algorithmica.org/hpc/arithmetic/division/
    defcode "/MOD",4,,DIVMOD
    xor %rdx, %rdx
    // divisor
    pop %rbx
    // dividend
    pop %rax
    // stores result quotient in rax, remainder in edx
    idiv %rbx
    push %rdx
    push %rax
    NEXT

    defcode "=",1,,EQU
    pop %rax
    pop %rbx
    cmp %rbx, %rax
    sete %al
    movzb %al, %rax
    push %rax
    NEXT

    defcode "<>",2,,NEQU
    pop %rax
    pop %rbx
    cmp %rbx, %rax
    setne %al
    movzb %al, %rax
    push %rax
    NEXT

    // Signed comparison
    defcode "<",1,,LT
    pop %rax
    pop %rbx
    cmp %rax, %rbx
    setl %al
    movzb %al, %rax
    push %rax
    NEXT

    defcode ">",1,,GT
    pop %rax
    pop %rbx
    cmp %rax, %rbx
    setg %al
    movzb %al, %rax
    push %rax
    NEXT

    defcode "<=",2,,LTE
    pop %rax
    pop %rbx
    cmp %rax, %rbx
    setle %al
    movzb %al, %rax
    push %rax
    NEXT

    defcode ">=",2,,GTE
    pop %rax
    pop %rbx
    cmp %rax, %rbx
    setge %al
    movzb %al, %rax
    push %rax
    NEXT

    defcode "0=",2,,ZEQU
    pop %rax
    test %rax, %rax
    setz %al
    movzb %al, %rax
    push %rax
    NEXT

    defcode "0<>",3,,ZNEQU
    pop %rax
    test %rax, %rax
    setnz %al
    movzb %al, %rax
    push %rax
    NEXT

    defcode "0<",2,,ZLT
    pop %rax
    test %rax, %rax
    setl %al
    movzb %al, %rax
    push %rax
    NEXT

    defcode "0>",2,,ZGT
    pop %rax
    test %rax, %rax
    setg %al
    movzb %al, %rax
    push %rax
    NEXT

    defcode "0<=",3,,ZLE
    pop %rax
    test %rax, %rax
    setle %al
    movzb %al, %rax
    push %rax
    NEXT

    defcode "0>=",3,,ZGE
    pop %rax
    test %rax, %rax
    setge %al
    movzb %al, %rax
    push %rax
    NEXT

    defcode "AND",3,,AND
    pop %rax
    and %rax, (%rsp)
    NEXT

    defcode "OR",2,,OR
    pop %rax
    or %rax, (%rsp)
    NEXT

    defcode "XOR",3,,XOR
    pop %rax
    xor %rax, (%rsp)
    NEXT

    defcode "INVERT",6,,INVERT
    notq (%rsp)
    NEXT

    defcode "PT",2,,PT
    pop %rdi
    push %rsi
    _call _INTERNAL_FORMAT_NUM
    mov %rax, %rdi
    mov %rcx, %rsi
    _call generic_print
    _call print_newline
    pop %rsi
    NEXT

    defcode "PRINT_RSP",9,,PRINT_RSP
    mov %rsp, %rdi
    push %rsi
    _call _INTERNAL_FORMAT_NUM
    mov %rax, %rdi
    mov %rcx, %rsi
    _call generic_print
    _call print_newline
    pop %rsi
    NEXT

    // drops top of return stack
    defcode "RDROP",5,,RDROP
    add $8, %rbp
    NEXT

    // Reads a char from stdin, pushes the char onto the stack
    defcode "CHAR",4,,CHAR
    _call _WORD
    // rax: pointer to word, or 0 on error
    // rcx: length of word
    xor %rbx, %rbx
    movb (%rax), %bl
    push %rbx
    NEXT

    defcode "SYSCALL3",8,,SYSCALL3
    mov %rsi, %r9
    pop %rax
    pop %rdi
    pop %rsi
    pop %rdx
    syscall
    push %rax
    mov %r9, %rsi
    NEXT

    defcode "SYSCALL2",8,,SYSCALL2
    mov %rsi, %r9
    pop %rax
    pop %rdi
    pop %rsi
    syscall
    push %rax
    mov %r9, %rsi
    NEXT

    defcode "SYSCALL1",8,,SYSCALL1
    pop %rax
    pop %rdi
    syscall
    push %rax
    NEXT

    defcode "SYSCALL0",8,,SYSCALL0
    pop %rax
    syscall
    push %rax
    NEXT
