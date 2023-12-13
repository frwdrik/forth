    .macro defword name, namelen, flags=0, label
    .section .rodata
    .align 8
    .globl name_\label
name_\label:
    .quad link
    .set link, name_\label
    .byte \flags+\namelen
    .ascii "\name"
    .align 8
    .globl \label
\label:
    .quad DOCOL
    .endm

    .macro defcode name, namelen, flags=0, label
    .section .rodata
    .align 8
    .globl name_\label
name_\label:
    .quad link
    .set link, name_\label
    .byte \flags+\namelen
    .ascii "\name"
    .align 8
    .globl \label
\label:
    .quad code_\label
    .text
    .align 8
    .globl code_\label
code_\label:
    .endm

    .macro NEXT
    lodsq
    jmp *(%rax)
    .endm

    // macro for pushing the return stack, rbp is stack top
    .macro PUSHRSP reg
    leaq -8(%rbp), %rbp
    mov \reg, (%rbp)
    .endm

    .macro POPRSP reg
    mov (%rbp), \reg
    lea 8(%rbp), %rbp
    .endm

    .macro defvar name, namelen, flags=0, label, initial=0
    defcode \name,\namelen,\flags,\label
    pushq $var_\name
    NEXT
    .data
    .align 8
var_\name:
    .quad \initial
    .endm

    .macro defconst name, namelen, flags=0, label, value
    defcode \name,\namelen,\flags,\label
    pushq $\value
    NEXT
    .endm

    .macro _call label
    push %rsi
    call \label
    pop %rsi
    .endm
