    // just trying to make a word by hand

    defcode "a",1,,a
    // var_HERE contains the address of the next available space
    mov var_HERE, %rdi
    mov var_LATEST, %rax
    mov %rax, (%rdi)
    add $8, %rdi
    movq $2, (%rdi)
    inc %rdi
    movb $'a', (%rdi)
    inc %rdi
    movb $'a', (%rdi)
    add $3, %rdi
    and $~3, %rdi
    mov var_HERE, %rax
    mov %rax, var_LATEST
    movq $DOCOL, (%rdi)
    add $8, %rdi
    movq $EXIT, (%rdi)
    add $8, %rdi
    mov %rdi, var_HERE
    NEXT
