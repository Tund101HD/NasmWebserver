extern write_to_console
extern itoa
extern write_space_inline
extern write_new_line
section .data
    http_200 db "HTTP/1.1 200 OK", 13, 10
             db "Content-Type: text/plain", 13, 10
             db "Connection: close", 13, 10
             db 13, 10
             db "200 OK from Assembly Web Server", 10, 0x00
    http_200_len equ $ - http_200 - 1

    http_403 db "HTTP/1.1 403 Forbidden", 13, 10
             db "Content-Type: text/plain", 13, 10
             db "Connection: close", 13, 10
             db 13, 10, 0x00
    http_403_len equ $ - http_403 - 1

    http_unknown db "N/A", 0x00
    http_unknown_len equ $ - http_unknown -1

    http_get db "GET", 0x00
    http_get_len equ $ - http_get -1

    http_post db "POST", 0x00
    http_post_len equ $ - http_post -1

    http_delete db "DELETE", 0x00
    http_delete_len equ $ - http_delete -1

    http_put db "PUT", 0x00
    http_put_len equ $ - http_put -1

    http_trace db "TRACE", 0x00
    http_trace_len equ $ - http_trace -1

    http_head db "HEAD", 0x00
    http_head_len equ $ - http_head -1

section .bss
    client_buffer resb 1024
    http_code_buffer resb 3
section .text
    global handle_http_request

; Handle incoming http traffic
; Operands: rdi - The Client File Descriptor
; Clobbers: rax, rsi, rdx
; Result:   Nothing
handle_http_request:
    push rbp
    mov rbp, rsp
    push r9
    push r10
    push r11
    push r12
    push r13
    push r14

    mov r12, rdi            ; CLIENT fd

    mov rax, 0              ; sys_read
    mov rdi, r12            ; Read from CLIENT FD
    mov rsi, client_buffer
    mov rdx, 1024           ; Up to 1024 bytes
    syscall
    call read_path_from_get
    mov r9, rax             ; starting address
    mov r10, rdi            ; ending address
    mov r11, rsi            ; response code text
    mov r13, rcx            ; response code len
    push r11
    push r13
    push r13
    push r14

    cmp r15, 0
    je .on_unknown_m
    cmp r15, 1
    je .on_get_m
    cmp r15, 2
    je .on_post_m
    cmp r15, 3
    je .on_delete_m
    cmp r15, 4
    je .on_put_m
    cmp r15, 5
    je .on_trace_m
    cmp r15, 6
    je .on_head_m

    .on_unknown_m:
    mov r13, http_unknown
    mov r14, http_unknown_len
    jmp .printing

    .on_get_m:
    mov r13, http_get
    mov r14, http_get_len
    jmp .printing

    .on_post_m:
    mov r13, http_post
    mov r14, http_post_len
    jmp .printing

    .on_delete_m:
    mov r13, http_delete
    mov r14, http_delete_len
    jmp .printing

    .on_put_m:
    mov r13, http_put
    mov r14, http_put_len
    jmp .printing

    .on_trace_m:
    mov r13, http_trace
    mov r14, http_trace_len
    jmp .printing

    .on_head_m:
    mov r13, http_head
    mov r14, http_head_len
    jmp .printing

    .printing:
    call write_to_console
    call write_space_inline
    push r10
    sub r10, r9
    mov r13, r9
    mov r14, r10
    call write_to_console
    call write_space_inline
    push r9                 ; clobbered by itoa
    push r8                 ; clobbered by itoa
    mov rax, r8             ; r8 holds the response code number.
    mov rdi, http_code_buffer
    call itoa
    pop r8
    pop r9
    mov r13, http_code_buffer
    mov r14, rax            ; len of the string
    call write_to_console
    call write_space_inline
    call write_new_line

    pop r10                 ; restore clobbered values
    pop r14
    pop r13
    pop r13                 ; idk why but no touchy
    pop r11

    mov rax, 1              ; sys_write
    mov rdi, r12            ; Write directly to the CLIENT
    mov rsi, r11            ; HTTP response
    mov rdx, r13
    syscall

    .sys_close:
    mov rax, 3              ; sys_close
    mov rdi, r12            ; Close the CLIENT file descriptor
    syscall

    .exit_func:
    pop r14
    pop r13
    pop r12
    pop r11
    pop r10
    pop r9
    mov rsp, rbp
    pop rbp
    ret

; Handle any (known) request for any client fd
; Operands:
; Clobbers: rax, rcx, rdi, rsi, r8
; Result:   rax = starting address of path
;           rdi = ending address of path
;           rsi = response code text
;           rcx = response code len
;           r8  = response code number
;           r15 = method code number
read_path_from_get:
    push rbp
    mov rbp, rsp
    push r12
    push r13
    push r14
    push r9
    call check_method
    mov r15, rax                ; Store Method Code
    mov r9, rdi                 ; Store len
    lea r12, [client_buffer+r9] ; Skip "<method> "
    mov r13, 1024
    .loop_start:
    mov al, [r12]
    cmp al, '.'                 ; Is current char a dot?
    je .on_dot

    test al, al                 ; Check for null terminator
    jz .loop_end
    cmp al, ' '                 ; Check for space
    je .on_space

    inc r12
    dec r13
    jnz .loop_start


    .on_dot:
    cmp byte [r12 + 1], '.'     ; is the next char a dot?
    je .error_path_traverse     ; path traversal found
    inc r12
    dec r13
    jnz .loop_start



    .on_space:
    mov byte [r12], 0x00

    .loop_end:
    lea rax, [client_buffer+r9]  ; First address
    lea rdi, [r12]               ; Last address
    mov rsi, http_200
    mov rcx, http_200_len
    mov r8, 200
    jmp .exit

    .error_path_traverse:
    xor rax, rax
    xor rdi, rdi
    mov rsi, http_403
    mov rcx, http_403_len
    mov r8, 403

    .exit:
    pop r9
    pop r14
    pop r13
    pop r12
    mov rsp, rbp
    pop rbp
    ret

; Dirty check for the method used in the client request
; Operands: client_buffer
; Clobbers: rax, rdi
; Result:   rax = Method Code (see note)
;           rdi = Length of method in string (space included)
; Flags:    None
; Note:     UNKNOWN -> 0
;           GET -> 1
;           POST -> 2
;           DELETE -> 3
;           PUT -> 4
;           TRACE -> 5
;           HEAD -> 6
check_method:
    push rbp
    mov rbp, rsp

    mov al, byte [client_buffer]

    cmp al, 'G'
    je .on_get
    cmp al, 'D'
    je .on_delete
    cmp al, 'H'
    je .on_head
    cmp al, 'T'
    je .on_trace
    cmp al, 'P'
    je .on_p

    xor rax, rax                  ; No known method (best guess)
    jmp .exit_func2

    .on_p:
    cmp byte [client_buffer + 3], ' '
    je .on_put
    mov rax, 2                    ; POST (best guess)
    mov rdi, 5
    jmp .exit_func2

    .on_put:
    mov rax, 4                    ; PUT (best guess)
    mov rdi, 4
    jmp .exit_func2

    .on_delete:
    mov rax, 3                    ; DELETE (best guess)
    mov rdi, 7
    jmp .exit_func2

    .on_head:
    mov rax, 6                    ; HEAD (best guess)
    mov rdi, 5
    jmp .exit_func2

    .on_get:
    mov rax, 1                    ; GET (best guess)
    mov rdi, 4
    jmp .exit_func2

    .on_trace:
    mov rax, 5                    ; TRACE (best guess)
    mov rdi, 6
    jmp .exit_func2

    .exit_func2:
    mov rsp, rbp
    pop rbp
    ret


