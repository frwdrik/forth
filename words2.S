    // This program just tries to use a defconst to push a return
    // value, and have EXIT_ALL_THE_THINGS use that
    
    #include <asm/unistd.h>
    .include "macro.S"
    .include "init.S"
    .include "io.S"

    .set link, 0

    defvar "HERE",4,,HERE
    defvar "LATEST",6,,LATEST

    defconst "R0",2,,RZ,return_stack_top
    defconst "EXIT_VALUE",10,,EXIT_VALUE,8

    .text
    .globl _start
_start:
    cld
    mov $return_stack_top, %rbp
    call set_up_data_segment

    // cold_start is an address, pointing to QUIT
    mov $cold_start, %rsi
    NEXT

cold_start:
    .quad QUIT

    // Now how to write a function? When we enter a function we can
    // assume that the next function to run is at rsi and it must be
    // preserved so that at the end we can call NEXT to proceed. The
    // preamble will be something like:
DOCOL:
    PUSHRSP %rsi
    add $8, %rax
    mov %rax, %rsi
    NEXT

    defcode "EXIT",4,,EXIT
    POPRSP %rsi
    NEXT

    defword "QUIT",4,,QUIT
    .quad EXIT_VALUE
    .quad EXIT_ALL_THE_THINGS

    defcode "EXIT_ALL_THE_THINGS",19,,EXIT_ALL_THE_THINGS
    pop %rdi
    mov $60, %rax
    syscall
