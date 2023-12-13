    .equ stdin, 0
    .equ stdout, 1
    .equ __NR_read, 0
    .equ __NR_write, 1
    .equ __NR_exit, 60

    .equ WORD_BUFFER_SIZE,32
    .equ BUFFER_SIZE,4096

    defcode "KEY",3,,KEY
    _call _KEY
    push %rax
    NEXT

    .text
    // _KEY reads one character from stdin, and returns it in rax
_KEY:
    mov (currkey), %rbx
    cmp (bufftop), %rbx
    // if currkey >= bufftop, fill buffer
    jge 1f
    xor %rax, %rax
    mov (%rbx), %al
    inc %rbx
    mov %rbx, (currkey)
    ret
1:
    mov $stdin, %rdi
    mov $buffer, %rsi
    // reset currkey to buffer start
    mov %rsi, currkey
    mov $BUFFER_SIZE, %rdx
    mov $__NR_read, %rax
    syscall
    // if read() returns 0, error out
    test %rax, %rax
    jbe 2f
    add %rax, %rsi
    // bufftop = buffer+eax
    mov %rsi, bufftop
    jmp _KEY
2:
    mov $1, %rdi
    mov $__NR_exit, %rax
    syscall

    // EMIT
    // input stack0 = address of single character
    // prints the character to stdout
    defcode "EMIT",4,,EMIT
    pop %rax
    _call _EMIT
    NEXT
_EMIT:
    // 1st param: stdout
    mov $stdout, %rdi

    // write needs the address of the byte to write
    mov %al, emit_scratch
    // 2nd param: address
    mov $emit_scratch, %rsi

    // 3rd param: nbytes = 1
    mov $1, %rdx

    // write syscall
    mov $__NR_write, %rax
    syscall
    ret

    defcode "WORD",4,,WORD
    _call _WORD
    push %rax
    push %rcx
    NEXT

_WORD:
    // Return value:
    // rax: pointer to word, or 0 on error
    // rcx: length of word
1:
    call _KEY
    // comments are read until eol
    cmpb $'\\', %al
    je 3f
    // leading spaces are skipped
    cmpb $' ', %al
    jbe 1b

    mov $word_buffer, %rdi
2:
    // check for space in word buffer
    cmp $word_buffer_end, %rdi
    jge 4f
    // store rax in (rdi) and increment rdi
    stosb
    push %rdi
    call _KEY
    pop %rdi
    // repeat until we hit space
    cmpb $' ', %al
    ja 2b
    // we hit whitespace, so compute length into rcx
    sub $word_buffer, %rdi
    mov %rdi, %rcx
    mov $word_buffer, %rax
    ret
3:
    // consume comment until newline
    call _KEY
    cmpb $'\n', %al
    jne 3b
    jmp 1b
4:
    mov $0, %rax
    mov $0, %rcx
    ret

    // input rdi = number to format
    // returns rax = address of string
    // returns rcx = length of string
_INTERNAL_FORMAT_NUM:
    // we'll write the string right-to-left, in order to avoid
    // reversing the buffer afterwards
    mov $_INTERNAL_FORMAT_NUM_str_end, %r10
    mov $10, %rbx
    xor %rcx, %rcx
    xor %r9, %r9
    mov %rdi, %rax
    test %rax, %rax
    jge 1f
    mov $1, %r9
    neg %rax
1:  dec %rcx
    cqto
    idiv %rbx
    // rax contains quotient, rdx the remainder
    add $'0', %rdx
    movb %dl, (%r10, %rcx)

    test %rax, %rax
    jnz 1b

    test %r9, %r9
    jz 2f
    dec %rcx
    movb $'-', (%r10,%rcx,1)
2:  lea (%r10,%rcx), %rax
    neg %rcx
    ret

    .data
    .align 8
    // currkey and bufftop used by KEY
currkey:
    .quad buffer
bufftop:
    .quad buffer

_INTERNAL_newline:
    .ascii "\n"

    // scratch used by EMIT
emit_scratch:
    .space 1
_INTERNAL_FORMAT_NUM_str:
    .space 100
_INTERNAL_FORMAT_NUM_str_end:

    .bss
word_buffer:
    .space WORD_BUFFER_SIZE
word_buffer_end:

    .align 4096
buffer:
    .space BUFFER_SIZE

    // Some generic print utilities, not to be called from forth
    .text

    // input rdi = address of string
    // input rsi = length of string
generic_print:
    mov %rsi, %rdx
    mov %rdi, %rsi
    mov $stdout, %rdi
    mov $__NR_write, %rax
    syscall
    ret

print_newline:
    mov $_INTERNAL_newline,  %rdi
    mov $1, %rsi
    call generic_print
    ret
