    // NUMBER
    defcode "NUMBER",6,,NUMBER
    // length of string
    pop %rcx
    // start address of string
    pop %rdi
    push %rsi
    call _NUMBER
    pop %rsi
    // parsed number
    push %rax
    // number of unparsed chars, is zero when no errors
    push %rcx
    NEXT

    // input rdi = start of string
    // input rcx = length of string
    //
    // On success, returns number in rax sets and rcx = 0. On error
    // rcx is nonzero.
_NUMBER:
    xor %rax, %rax
    xor %rbx, %rbx

    // trying to parse a zero-length string is an error, but will return 0.
    test %rcx, %rcx
    jz 5f

    // get BASE (in %dl)
    mov var_BASE, %rdx

    // Check if first character is '-'.
    // %bl = first character in string
    movb (%rdi), %bl
    inc %rdi
    // push 0 on stack
    push %rax
    // negative number?
    cmpb $'-',%bl
    jnz 2f
    pop %rax
    // push <> 0 on stack, indicating negative
    push %rbx
    dec %rcx
    jnz 1f
    // error: string is only '-'.
    pop %rbx
    mov $1,%rcx
    ret

    // Loop reading digits.
    // %rax *= BASE
1:	imul %rdx,%rax
    // %bl = next character in string
    movb (%rdi),%bl
    inc %rdi

    // Convert 0-9, A-Z to a number 0-35.
    // < '0'?
2:	subb $'0',%bl
    jb 4f
    // <= '9'?
    cmp $10,%bl
    jb 3f
    // < 'A'? (17 is 'A'-'0')
    subb $17,%bl
    jb 4f
    addb $10,%bl

    // >= BASE?
3:	cmp %dl,%bl
    jge 4f

    // OK, so add it to %rax and loop.
    add %rbx,%rax
    dec %rcx
    jnz 1b

    // Negate the result if first character was '-' (saved on the stack).
4:	pop %rbx
    test %rbx,%rbx
    jz 5f
    neg %rax

5:	ret
