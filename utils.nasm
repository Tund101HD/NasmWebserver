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
; Clobbers: rax , rdx , rdi
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
; Clobbers: rax, rdi, rdx
; Result:   None
; Flags:    None
; Note:     Uses wirte_to_console
write_space_inline:
    push rbp
    mov rbp, rsp
    push r13
    push r14

    push ' '                        ; Push the literal space character onto the stack memory
    mov r13, rsp
    mov r14, 1
    call write_to_console
    pop rax                         ; clean up stack into rax

    pop r14
    pop r13
    mov rsp, rbp
    pop rbp
    ret

; Write a simple inline space
; Operands: None
; Clobbers: rax, rdi, rdx
; Result:   None
; Flags:    None
; Note:     Uses wirte_to_console
write_new_line:
    push rbp
    mov rbp, rsp
    push r13
    push r14

    push 10                        ; New line code
    mov r13, rsp
    mov r14, 1
    call write_to_console
    pop rax                         ; clean up stack into rax

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
; Clobbers: rax , rdx , rdi
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

    dec r14                     ; Subtract 1 from length to ignore the 0x0A newline character
    xor rax, rax
    xor r9, r9

.loop_start:
    cmp r9, r14
    jge .loop_end


    movzx rcx, byte [r13 + r9]  ; Read 1 byte at (Buffer_Address + Index)


    sub rcx, '0'                ; Subtract ASCII '0' (0x30). e.g., '8' (0x38) - '0' (0x30) = 8


    imul rax, 10                ; Multiply running total by 10
    add rax, rcx                ; Add the new integer digit to the total
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

    mov rcx, 10         ; We will divide by 10 to extract digits
    xor r8, r8          ; r8 will be our digit counter. Set to 0.

.extract_digits:
    xor rdx, rdx
    div rcx

    add dl, '0'
    push rdx
    inc r8

    test rax, rax
    jnz .extract_digits
    mov r9, r8          ; Save the total digit count so we can return it later

.write_string:
    pop rdx             ; Pop the character off the stack
    mov byte [rdi], dl  ; Write the 1-byte character into the buffer
    inc rdi             ; Move the buffer pointer forward 1 byte
    dec r8              ; Decrement our digit counter
    jnz .write_string   ; Keep popping until we've written all digits

    ; Null-terminate the string so it's safe to use with other functions
    mov byte [rdi], 0x00

    mov rax, r9         ; Return the total length of the string in rax

    mov rsp, rbp
    pop rbp
    ret