    .data
    .align 8
errmsg:
    .asciz "Some error occured!\n"
.equ errmsg_len, . - errmsg

not_found_errmsg:
    .asciz "Word not found: "
.equ not_found_errmsg_len, . - not_found_errmsg

    .text

print_error:
    mov $errmsg, %rdi
    mov $errmsg_len, %rsi
    call generic_print
    ret

not_found_error:
    mov $not_found_errmsg, %rdi
    mov $not_found_errmsg_len, %rsi
    call generic_print
    ret
