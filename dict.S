    // Routines for finding a word by name. Words are stored in a
    // linked list. The first 64-bits of each word is the address of
    // the previous word. So to find a word, we traverse the linked
    // list until we either find the word, or we reach a null pointer.

    // input stack0 = length
    // input stack1 = address
    defcode "FIND",4,,FIND
    pop %rcx
    pop %rdi
    _call _FIND
    push %rax
    NEXT

    // input rdi = address of word
    // input rcx = length of word
    // implicit arguments:
    //   - var_LATEST: points to last defined word
    // returns
    //   - rax = address of word, 0 when not found
_FIND:
    mov var_LATEST, %rdx
    // check for null pointer at end of list
1:  test %rdx, %rdx
    jz 3f
    // now compare length and name to see if we have the correct word
    xor %rax, %rax
    movb 8(%rdx), %al
    andb $(F_HIDDEN|F_LENMASK), %al
    cmp %cl, %al
    jne 2f
    // length matches, so check char by char
    push %rcx
    push %rdi
    lea 9(%rdx), %rsi
    repe cmpsb
    pop %rdi
    pop %rcx
    jne 2f
    // the strings are equal
    mov %rdx, %rax
    ret
    // advance to next word in list
2:  mov (%rdx), %rdx
    jmp 1b
    // not found, return 0
3:  xor %rax, %rax
    ret

    // FIND returns the dictionary pointer, to get the codeword we
    // have to skip the header. This is what >CFA will do for us.
    defcode ">CFA",4,,TCFA
    pop %rdi
    _call _TCFA
    push %rax
    NEXT
    // input rdi = address of word start
    // returns rdi = address of codeword start
_TCFA:
    xor %rax, %rax
    // skip header
    add $8, %rdi
    mov (%rdi), %al
    inc %rdi
    andb $F_LENMASK, %al
    // skip name
    add %rdi, %rax
    // 8 byte alignment
    add $7, %rax
    and $~7, %rax
    ret

    // >DFA takes a dictionary entry address as returned by FIND and
    // returns a pointer to the first data field (the next field after
    // the codeword)
    defword ">DFA",4,,TDFA
    .quad TCFA
    .quad INCR8
    .quad EXIT
