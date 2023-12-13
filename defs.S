    // Creating words

    // CREATE creates the header for a word
    defcode "CREATE",6,,CREATE
    // get name length and address
    pop %rcx
    pop %rbx
    // set link pointer in header to previously defined word, by
    // setting HERE = LATEST
    mov var_HERE, %rdi
    mov var_LATEST, %rax
    stosq
    // length byte and word itself
    mov %cl, %al
    stosb
    push %rsi
    mov %rbx, %rsi
    rep movsb
    pop %rsi
    add $7, %rdi
    and $~7, %rdi
    // update LATEST and HERE,
    // LATEST should point to HERE, then HERE = rdi
    mov var_HERE, %rax
    mov %rax, var_LATEST
    mov %rdi, var_HERE
    NEXT

    // HIDDEN marks current word as hidden
    defcode "HIDDEN",6,,HIDDEN
    pop %rdi
    add $8, %rdi
    xorb $F_HIDDEN, (%rdi)
    NEXT

    // HIDE marks next entered word as hidden
    defword "HIDE",4,,HIDE
    .quad WORD
    .quad FIND
    .quad HIDDEN
    .quad EXIT

    // Literals

    // We define a code LIT that instead of executing code, expects
    // next word to be address of a literal value to push to stack
    defcode "LIT",3,,LIT
    // rsi already points to next "instruction", so load it into rax
    // and increment rsi
    lodsq
    push %rax
    NEXT

    // LITSTRING expects next word to be length of a string, followed
    // by the literal string itself. Pushes length and address of
    // string onto the stack.
    defcode "LITSTRING",9,,LITSTRING
    lodsq
    push %rsi
    push %rax
    add %rax, %rsi
    add $7, %rsi
    and $~7, %rsi
    NEXT

    // COMMA appends the value at top of stack to HERE, and increments
    // HERE by 8 bytes
    defcode ",",1,,COMMA
    pop %rax
    _call _COMMA
    NEXT
_COMMA:
    mov var_HERE, %rdi
    stosq
    mov %rdi, var_HERE
    ret

    // LBRAC puts us in immediate mode
    defcode "[",1,F_IMMED,LBRAC
    xor %rax, %rax
    mov %rax, var_STATE
    NEXT

    // RBRAC puts us in compile mode
    defcode "]",1,F_IMMED,RBRAC
    movq $1, var_STATE
    NEXT

    // COLON starts compilation
    //   - read name and create header
    //   - append DOCOL codeword
    //   - hide current word
    //   - enter compilation state
    //   - return
    defword ":",1,,COLON
    .quad WORD
    .quad CREATE
    .quad LIT, DOCOL, COMMA
    .quad LATEST, FETCH, HIDDEN
    .quad RBRAC
    .quad EXIT

    // SEMICOLON ends compilation
    //   - append EXIT
    //   - unhide word
    //   - exit compilation state
    //   - return
    defword ";",1,F_IMMED,SEMICOLON
    .quad LIT, EXIT, COMMA
    .quad LATEST, FETCH, HIDDEN
    .quad LBRAC
    .quad EXIT

    // IMMEDIATE marks current word as immediate
    defcode "IMMEDIATE",9,F_IMMED,IMMEDIATE
    mov var_LATEST, %rdi
    add $8, %rdi
    xorb $F_IMMED, (%rdi)
    NEXT

    // push to stack the codeword pointer of the next word, only works
    // in compiled code
    defcode "'",1,,TICK
    lodsq
    push %rax
    NEXT

    // jmp to address pointed to by address at top of stack
    defcode "EXECUTE",7,,EXECUTE
    pop %rax
    jmp *(%rax)
