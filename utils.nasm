section .data

section .bss

section .text
    global write_to_console
    global read_from_console
    global atoi
    global itoa
    global write_space_inline
    global write_new_line

; Write some text to console (STD_OUT)
;
; Input:
;       r13 - Message to write
;       r14 - Message length to write
;
; Clobbers: rax, rdx, rdi, rcx, r11 (rcx/r11 clobbered by syscall)
;
write_to_console:
    push rbp
    mov rbp, rsp

    mov rax, 1
    mov rdi, 1
    push r13
    push r14
    lea rsi, [r13]
    mov rdx, r14
    syscall

    pop r14
    pop r13
    mov rsp, rbp
    pop rbp
    ret

; Write a simple inline space
; Operands: None
; Clobbers: rax, rdi, rdx, rcx, r11
; Result:   None
; Flags:    None
write_space_inline:
    push rbp
    mov rbp, rsp
    push r13
    push r14

    push ' '
    mov r13, rsp
    mov r14, 1
    call write_to_console
    pop rax

    pop r14
    pop r13
    mov rsp, rbp
    pop rbp
    ret

; Write a newline character
; Operands: None
; Clobbers: rax, rdi, rdx, rcx, r11
; Result:   None
; Flags:    None
write_new_line:
    push rbp
    mov rbp, rsp
    push r13
    push r14

    push 10
    mov r13, rsp
    mov r14, 1
    call write_to_console
    pop rax

    pop r14
    pop r13
    mov rsp, rbp
    pop rbp
    ret


; Read from STDIN into an input buffer
;
; Input:
;       r13 - Input Buffer to be written to
;       r14 - Size of the Buffer
;
; Result:
;       rax - Length of the text input
;       your_buffer - Text input by the user
; Clobbers: rax, rdx, rdi, rcx, r11
read_from_console:
    push rbp
    mov rbp, rsp
    push r13
    push r14

    mov rax, 0
    mov rdi, 0
    mov rsi, r13
    mov rdx, r14
    syscall

    pop r14
    pop r13

    mov rsp, rbp
    pop rbp
    ret

; ASCII to Integer (atoi)
; Input:
;       r13 - Pointer to the ASCII string buffer
;       r14 - Length of the string (including the trailing newline)
; Returns:
;       rax - The converted integer value
; Clobbers: rax, rcx, r9
atoi:
    push rbp
    mov rbp, rsp

    dec r14
    xor rax, rax
    xor r9, r9

.loop_start:
    cmp r9, r14
    jge .loop_end

    movzx rcx, byte [r13 + r9]
    sub rcx, '0'

    imul rax, 10
    add rax, rcx
    inc r9
    jmp .loop_start

.loop_end:
    mov rsp, rbp
    pop rbp
    ret

; Integer to ASCII (itoa)
; Converts a 64-bit integer into a null-terminated string.
;
; Input:
;       rax - The integer to convert
;       rdi - Pointer to the destination memory buffer
; Returns:
;       rax - The length of the string generated (excluding null terminator)
; Clobbers: rax, rcx, rdx, rdi, r8, r9
itoa:
    push rbp
    mov rbp, rsp

    mov rcx, 10
    xor r8, r8

.extract_digits:
    xor rdx, rdx
    div rcx

    add dl, '0'
    push rdx
    inc r8

    test rax, rax
    jnz .extract_digits
    mov r9, r8

.write_string:
    pop rdx
    mov byte [rdi], dl
    inc rdi
    dec r8
    jnz .write_string

    mov byte [rdi], 0x00

    mov rax, r9

    mov rsp, rbp
    pop rbp
    ret
