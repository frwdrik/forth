    // The purpose of this file is to test out how LOAD-FILE could
    // work, given that we have a single buffer to read to.
    
    .equ O_RDONLY,0

    .equ SEEK_SET, 0    /* Seek from beginning of file.  */
    .equ SEEK_CUR, 1    /* Seek from current position.  */
    .equ SEEK_END, 2    /* Seek from end of file.  */

    .equ stdin, 0
    .equ stdout, 1
    .equ __NR_read, 0
    .equ __NR_write, 1
    .equ __NR_open, 2
    .equ __NR_close, 3
    .equ __NR_lseek, 8
    .equ __NR_exit, 60

    .equ WORD_BUFFER_SIZE,32
    .equ BUFFER_SIZE,4096*4096
    // The theoretical fd limit can be found in /proc/sys/fs/file-max,
    // but the per-process limit is probably a lot smaller. Don't know
    // exactly what it is, but it's not like we're expecting thousands
    // of transitive LOAD-FILE's anyway.
    .equ KEY_STACK_SIZE,1024
    
    // The KEY stack. The purpose of this stack is to allow nested
    // LOAD-FILE's. The constraint we're imposing on ourselves is that
    // we want to only use a single read buffer, and each time we call
    // LOAD-FILE we want KEY to clear that buffer and start reading
    // from the provided file. The problem we must solve is then how,
    // once we've loaded a file, can we go back to the correct
    // position in the previous file?
    //
    // The solution I'm trying out involves keeping a stack of file
    // descriptors. We need to manually track offsets, so that when we
    // go back to reading from a previous file descriptor, we continue
    // where we left off. The reason we need to keep track of offsets
    // manually is read() reads into our buffer, but KEY only hands
    // out a single character at a time. That means the offset as
    // reported by lseek is almost always greater than our actual
    // offset.
    //
    // Each time we call LOAD-FILE, we'll open a new file descriptor
    // and push it onto the stack. Then _KEY will start reading from
    // that fd. When read() returns 0, we will pop the fd off the
    // stack, and see if there's a next one. If there is, then we'll
    // restore its offset and simply continue reading from that one.
    //
    // What is the interface between LOAD-FILE and _KEY? Who is
    // responsible for opening a file descriptor? If we view this as a
    // sort of user vs. kernel space thing, then I think it's cleanest
    // if LOAD-FILE only sets a flag and a filename, and then _KEY
    // handles the rest. On the other hand, if the file doesn't exist,
    // we'd like to tell the user as early as possible. So for that
    // reason, let's have LOAD-FILE open the file. And since we're
    // letting LOAD-FILE do that, it might just as well do the stack
    // handling for us, as a performance benefit over having _KEY
    // check the variable every time.

    .equ key_stack_end_sentinel, -2
    
    .data
curr_offset:
    .quad 0
filename:
    .asciz "jonesforth.f"
key_stack:  
    .quad key_stack_end_sentinel
    .space KEY_STACK_SIZE
key_stack_boundary:  
key_stack_pointer:
    .quad key_stack

    .macro PUSH_KEY_STACK tmp_reg, reg
    addq $8, key_stack_pointer
    movq key_stack_pointer, \tmp_reg
    movq \reg, (\tmp_reg)
    .endm
    
    .macro POP_KEY_STACK tmp_reg, reg
    movq key_stack_pointer, \tmp_reg
    subq $8, key_stack_pointer
    movq (\tmp_reg), \reg
    .endm

    .macro PEEK_KEY_STACK tmp_reg, reg
    movq key_stack_pointer, \tmp_reg
    movq (\tmp_reg), \reg
    .endm

    // ( fd -- )
    defcode "PUSH-KEY-STACK",14,,PUSH_KEY_STACK
    pop %rax
    _call _PUSH_KEY_STACK
    NEXT

    .text
_PUSH_KEY_STACK:
    // save current offset
    PEEK_KEY_STACK %rbx, %rdi
    call compute_offset
    mov %rcx, curr_offset
    PUSH_KEY_STACK %rbx, %rcx
    // now push next fd
    PUSH_KEY_STACK %rbx, %rax
    // reset buffer so that next call to _KEY will start reading from
    // the new file descriptor instead of whatever is left of the
    // buffered input from the previous file descriptor.
    movq $0, curr_offset
    mov $buffer, %rax
    mov %rax, bufftop
    mov %rax, currkey
    ret

    .text
    // Returns actual offset in rcx
compute_offset:
    mov curr_offset, %rcx
    // increment offset by looking at currkey-buffer
    add currkey, %rcx
    sub $buffer, %rcx
    ret
    
    defcode "KEY",3,,KEY
    _call _KEY
    push %rax
    NEXT

    .text
set_up_key_stack:
    PUSH_KEY_STACK %rbx, $stdin
    PUSH_KEY_STACK %rbx, $0
    // push jonesforth.f to stack   
    mov $__NR_open, %rax
    mov $filename, %rdi
    xor %rsi, %rsi
    or $O_RDONLY, %rsi
    syscall
    PUSH_KEY_STACK %rbx, %rax
    ret
    
    // _KEY takes no inputs, returns a single character at a time.
    // _KEY always uses the fd at top of the key stack.
_KEY:
    // First check if we can consume from buffer
    mov (currkey), %rbx
    cmp (bufftop), %rbx
    jge fill_buffer
    xor %rax, %rax
    mov (%rbx), %al
    inc %rbx
    mov %rbx, (currkey)
    ret
fill_buffer:
    // Fill buffer by reading from fd at top of stack
    PEEK_KEY_STACK %rbx, %rdi
    mov $buffer, %rsi
    call compute_offset
    mov %rcx, curr_offset
    mov %rsi, currkey
    mov $BUFFER_SIZE, %rdx
    mov $__NR_read, %rax
    syscall
    // if read() returns 0, go to next fd
    test %rax, %rax
    jle 2f
    add %rax, %rsi              
    mov %rsi, bufftop           /* bufftop = buffer+(number of bytes read) */
    jmp _KEY
2:  // Current fd is EOF, so we close it. Then we check if there are
    // more fd's on the stack, and if there are none, we exit the
    // program.
    POP_KEY_STACK %rbx, %rdi
    mov $__NR_close, %rax
    syscall
pop_next_fd:   
    POP_KEY_STACK %rbx, %rsi
    cmp $key_stack_end_sentinel, %rsi
    je 3f
    // Restore offset
    mov %rsi, curr_offset
    PEEK_KEY_STACK %rbx, %rdi
    cmp $stdin, %rdi
    je fill_buffer              /* don't lseek on stdin */
    mov $SEEK_SET, %rdx
    mov $__NR_lseek, %rax
    syscall    
    jmp fill_buffer
3:  // We reach this when read(stdin, ...) returns EOF
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
1:  call _KEY
    // comments are read until eol
    cmpb $'\\', %al
    je 3f
    // leading spaces are skipped
    cmpb $' ', %al
    jbe 1b
    // we have an actual character to read
    mov $word_buffer, %rdi
2:  // check for space in word buffer
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
3:  // consume comment until newline
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

    .data
filling:
    .asciz "Filling buffer \n"
    .equ filling_len, . - filling
