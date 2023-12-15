    // This code exists to test the execution method of forth. I will
    // try to write some words, both "normal" ones and ones defined
    // solely in assembly, and see how it goes.

    // The basic model is this: We keep in rsi the address of a
    // location containg the address of the next instruction to
    // execute. In other words, rsi points to somewhere within a word
    // that contains the address of code to execute, and by advancing
    // rsi, we can advance through the different "words within the
    // word".
    //
    // A diagram:
    //
    //
    // DOUBLE might be defined as 'DUP +'. In memory, this looks like
    //
    //   u64                                    u64    u64   u64  u64
    // -----------------------------------------------------------------
    // | link | 6 | D | O | U | B | L | E | 0 | COLON | DUP | + | EXIT |
    // |----------------------------------------------------------------
    //         len                         pad codeword  |
    //                                                   v
    //                                       points to codeword of DUP
    //
    // When we execute the instruction in *(rsi), we begin executing
    // at the codeword. The codeword serves a purpose similar to the
    // preamble in a C function call. It stores the return address on
    // the RSP stack, and jumps to the next word.

    // name: name of word in forth, max 32 chars
    // namelen: goes into bottom five bits of len
    // flags: we use top three bits of len for flags
    // label: will be label of codeword, so we can refer to it in asm

    // IMPORTANT: link must be set before defining any defword/defcode
    .set link, 0

    .equ JONES_VERSION, 1

    #include <asm/unistd.h>

    .include "macro.S"
    .include "init.S"
    .include "io.S"
    .include "dict.S"
    .include "funs.S"
    .include "mem.S"
    .include "defs.S"
    .include "number.S"
    .include "err.S"

    .equ F_IMMED,   0x80
    .equ F_HIDDEN,  0x20
    .equ F_LENMASK, 0x1f

    defvar "HERE",4,,HERE
    // LATEST must be initialized to last defword/defcode in this file
    defvar "LATEST",6,,LATEST,name_QUIT
    defvar "STATE",5,,STATE
    defvar "BASE",4,,BASE,10
    defvar "S0",2,,S0
    // // setting this to a non-negative integer will cause _KEY to start
    // // try reading from that file descriptor
    // defvar "LOAD_FILE_FD",12,,LOAD_FILE_FD,1

    defconst "VERSION",7,,VERSION,JONES_VERSION
    defconst "R0",2,,RZ,return_stack_top
    defconst "DOCOL",5,,__DOCOL,DOCOL
    defconst "EXIT_VAL",8,,EXIT_VAL,8
    defconst "F_IMMED",7,,__F_IMMED,F_IMMED
    defconst "F_HIDDEN",8,,__F_HIDDEN,F_HIDDEN
    defconst "F_LENMASK",9,,__F_LENMASK,F_LENMASK

    defconst "SYS_EXIT",8,,SYS_EXIT,__NR_exit
    defconst "SYS_OPEN",8,,SYS_OPEN,__NR_open
    defconst "SYS_CLOSE",9,,SYS_CLOSE,__NR_close
    defconst "SYS_READ",8,,SYS_READ,__NR_read
    defconst "SYS_WRITE",9,,SYS_WRITE,__NR_write
    defconst "SYS_CREAT",9,,SYS_CREAT,__NR_creat
    defconst "SYS_BRK",7,,SYS_BRK,__NR_brk
    defconst "SYS_SOCKET",10,,SYS_SOCKET,__NR_socket
    defconst "SYS_CONNECT",11,,SYS_CONNECT,__NR_connect
    defconst "SYS_NANOSLEEP",13,,SYS_NANOSLEEP,__NR_nanosleep

    defconst "O_RDONLY",8,,__O_RDONLY,0
    defconst "O_WRONLY",8,,__O_WRONLY,1
    defconst "O_RDWR",6,,__O_RDWR,2
    defconst "O_CREAT",7,,__O_CREAT,0100
    defconst "O_EXCL",6,,__O_EXCL,0200
    defconst "O_TRUNC",7,,__O_TRUNC,01000
    defconst "O_APPEND",8,,__O_APPEND,02000
    defconst "O_NONBLOCK",10,,__O_NONBLOCK,04000

    .text
    .globl _start
_start:
    cld
    mov %rsp, var_S0
    mov $return_stack_top, %rbp
    _call set_up_data_segment
    _call set_up_key_stack

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

    // TELL pops a string pointer from the stack and prints the string
    defcode "TELL",4,,TELL
    mov %rsi, %rbx
    pop %rsi
    pop %rdi
    _call generic_print
    mov %rbx, %rsi
    NEXT

    defcode "STOP",4,,STOP
    pop %rdi
    mov $60, %rax
    syscall

    defcode "INTERPRET",9,,INTERPRET
    _call _WORD
    // _WORD returns rax=0 on error, so check for that
    test %rax, %rax
    jz 1f
    // set rdi = address
    // already have rcx = length
    mov %rax, %rdi
    // save for error printing if needed
    mov %rdi, %r9
    mov %rcx, %r10
    xor %rax, %rax
    mov %rax, interpret_is_lit
    _call _FIND
    test %rax, %rax
    jz 2f
    // word found, is it an IMMEDIATE codeword?
    mov %rax, %rdi
    movb 8(%rdi), %al
    push %ax
    _call _TCFA
    mov %rax, %rdi
    pop %ax
    andb $F_IMMED, %al
    mov %rdi, %rax
    // run if immediate
    jnz 5f
    // otherwise check if we are compiling or not
    jmp 3f
    // input rdi = address of word start
    // returns rax = address of codeword start
1:  _call print_error
    NEXT
    // not found, assume it is a number
2:  incq interpret_is_lit
    _call _NUMBER
    test %rcx, %rcx
    jnz 7f
    mov %rax, %rbx
    mov $LIT, %rax
    // are we compiling or executing?
3:  mov var_STATE, %rdx
    test %rdx, %rdx
    jz 5f
    // compiling - just append the work to current word definition rax
    // contains address of codeword
    _call _COMMA
    mov interpret_is_lit, %rcx
    test %rcx, %rcx
    jz 4f
    // when LIT, rbx contains a number, add it to current word definition
    mov %rbx, %rax
    _call _COMMA
4:  NEXT
    // executing - run it!
5:  mov interpret_is_lit, %rcx
    test %rcx, %rcx
    jnz 6f
    jmp *(%rax)
    // executing a literal, which means push it on the stack
6:  push %rbx
    NEXT
    // error, word neither found nor is literal number
7:  _call not_found_error
    push %rsi
    mov %r9, %rdi
    mov %r10, %rsi
    _call generic_print
    _call print_newline
    pop %rsi
    NEXT

    // BRANCH is an unconditional jump by the offset found in next
    // instruction
    defcode "BRANCH",6,,BRANCH
    add (%rsi), %rsi
    NEXT

    // ZBRANCH branches only if top of stack is zero
    defcode "0BRANCH",7,,ZBRANCH
    pop %rax
    test %rax, %rax
    jz code_BRANCH
    lodsq
    NEXT

    defword "QUIT",4,,QUIT
    // clear the return stack
    .quad RZ, RSPSTORE
    .quad INTERPRET
    .quad BRANCH, -16

    .data
    .align 8
    // flag used to record if reading a literal
interpret_is_lit:
    .quad 0
