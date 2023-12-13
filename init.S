    #include <asm/unistd.h>

    // For some reason asm/unistd.h doesn't get included in this file
    .equ __NR_mprotect, 10
    .equ __NR_brk, 12

    .equ PROT_READ,     0x1		/* Page can be read.  */
    .equ PROT_WRITE,	0x2		/* Page can be written.  */
    .equ PROT_EXEC,     0x4		/* Page can be executed.  */

    // Segment for user definitions
    .text
    .set INITIAL_DATA_SEGMENT_SIZE, 65536
set_up_data_segment:
    // Allocate initial data segment, HERE points to it
    xor %rdi, %rdi
    mov $__NR_brk, %rax
    syscall
    mov %rax, var_HERE
    add $INITIAL_DATA_SEGMENT_SIZE, %rax
    mov %rax, %rdi
    mov $__NR_brk, %rax
    syscall
    // Make the region executable, needed if we want to be able to
    // compile raw assembly instructions into user memory.
    mov var_HERE, %rdi
    mov $INITIAL_DATA_SEGMENT_SIZE, %rsi
    xor %rdx, %rdx
    or $PROT_READ, %rdx
    or $PROT_WRITE, %rdx
    or $PROT_EXEC, %rdx
    mov $__NR_mprotect, %rax
    syscall
    ret

    .set RETURN_STACK_SIZE, 8192
    .set BUFFER_SIZE, 4096

    // FORTH return stack
    .bss
    .align 4096
return_stack:
    .space RETURN_STACK_SIZE
return_stack_top:
