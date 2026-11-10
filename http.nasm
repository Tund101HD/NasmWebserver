extern write_to_console
extern itoa
extern write_space_inline
extern write_new_line
extern root_fd

section .data
    http_200 db "HTTP/1.1 200 OK", 13, 10
             db "Connection: close", 13, 10      ; temporary: until Content-Type and
             db 13, 10, 0x00                     ; Content-Length are built per file
    http_200_len equ $ - http_200 - 1

    http_403 db "HTTP/1.1 403 Forbidden", 13, 10
             db "Content-Type: text/plain", 13, 10
             db "Connection: close", 13, 10
             db 13, 10, 0x00
    http_403_len equ $ - http_403 - 1
    http_404 db "HTTP/1.1 404 Not Found", 13, 10
             db "Content-Type: text/plain", 13, 10
             db "Connection: close", 13, 10
             db 13, 10, 0x00
    http_404_len equ $ - http_404 - 1

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

    ; placeholder path for 403 responses so printing doesn't use NULL
    http_forbidden_path db "(blocked)", 0x00
    http_forbidden_path_len equ $ - http_forbidden_path - 1

    index_file db "index.html", 0x00
    index_file_len equ $ - index_file - 1

    content_type_html db "text/html", 13, 10
    content_type_html_len equ $ - content_type_html - 1

    content_type_css: db "text/css", 0
    content_type_css_len equ $ - content_type_css - 1

    content_type_app: db "application/octet-stream", 0
    content_type_app_len equ $ - content_type_app - 1

section .bss
    client_buffer resb 1024
    http_code_buffer resb 4
    stat_buf resb 144
section .text
    global handle_http_request

; Handle incoming http traffic
; Operands: rdi - The Client File Descriptor
; Clobbers: rax, rsi, rdx, rcx, r11
; Result:   Nothing
handle_http_request:
    push rbp
    mov rbp, rsp
    push r8
    push r9
    push r10
    push r12
    push r13
    push r14
    push r15

    mov r12, rdi            ; CLIENT fd

    mov rax, 0              ; sys_read
    mov rdi, r12            ; Read from CLIENT FD
    mov rsi, client_buffer
    mov rdx, 1024           ; Up to 1024 bytes
    syscall

    call read_path_from_get

    ; rax = path start, rdi = path end, r8 = response code number, r15 = method code number
    mov r9, rax             ; path starting address
    mov r10, rdi            ; path ending address
    mov r14, -1             ; file fd, -1 = no file to send

    test r9, r9             ; NULL = blocked by the ".." check
    jz .send_response       ; r8 is already 403

    mov rcx, r10
    sub rcx, r9             ; length = end - start, incl. "/"
    cmp rcx, 1
    jne .not_top_level
    mov rsi, index_file     ; "/" → "index.html"
    jmp .open_file

    .not_top_level:
    lea rsi, [r9 + 1]       ; skip the leading "/"

    .open_file:
    mov rax, 257            ; sys_openat
    mov rdi, [root_fd]      ; relative to the doc root
    xor rdx, rdx            ; O_RDONLY
    syscall
    test rax, rax
    js .not_found
    mov r14, rax            ; file fd

    .check_file:
    mov rax, 5              ; sys_fstat
    mov rdi, r14
    mov rsi, stat_buf
    syscall
    mov r13, [stat_buf + 48]      ; st_size (i64), needed for Content-Length
    mov eax, [stat_buf + 24]      ; st_mode (u32)
    and eax, 0xF000
    cmp eax, 0x4000               ; S_IFDIR
    jne .send_response            ; regular file, send it

    ; directory: open index.html relative to it, then close the directory fd
    mov rax, 257            ; sys_openat
    mov rdi, r14            ; relative to the directory we just opened
    mov rsi, index_file
    xor rdx, rdx            ; O_RDONLY
    syscall
    mov r13, rax            ; new fd (or -errno)
    mov rax, 3              ; sys_close
    mov rdi, r14            ; close the directory
    syscall
    mov r14, r13
    test r14, r14
    js .not_found
    jmp .check_file

    .not_found:
    mov r14, -1             ; nothing to send
    mov r8, 404

    .send_response:
    ; METHOD PATH STATUS_CODE - ex GET /index.html 200
    call print_method
    call print_path
    call print_status_code

    mov rsi, http_200
    mov rdx, http_200_len
    cmp r8, 200
    je .write_header
    mov rsi, http_403
    mov rdx, http_403_len
    cmp r8, 403
    je .write_header
    mov rsi, http_404
    mov rdx, http_404_len

    .write_header:
    mov rax, 1              ; sys_write
    mov rdi, r12            ; Write directly to the CLIENT
    syscall

    test r14, r14           ; -1 = no file to send
    js .sys_close

    .send_file:
    mov rax, 40             ; sys_sendfile
    mov rdi, r12            ; out: client fd
    mov rsi, r14            ; in: file fd
    xor rdx, rdx            ; offset = NULL, uses the file position
    mov r10, r13            ; count = remaining bytes (4th arg is r10)
    syscall
    test rax, rax
    jle .close_file         ; 0 = EOF, negative = error
    sub r13, rax
    jnz .send_file          ; sendfile can send fewer bytes than asked

    .close_file:
    mov rax, 3              ; sys_close
    mov rdi, r14            ; Close the FILE file descriptor
    syscall

    .sys_close:
    mov rax, 3              ; sys_close
    mov rdi, r12            ; Close the CLIENT file descriptor
    syscall

    .exit_func:
    pop r15
    pop r14
    pop r13
    pop r12
    pop r10
    pop r9
    pop r8
    mov rsp, rbp
    pop rbp
    ret

; Handle any (known) request for any client fd
; Operands: client_buffer must contain the raw HTTP request
; Clobbers: rax, rcx, rdi, rsi, r8, r15
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
;           rdi = Length of method string + space
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

    xor rax, rax                  ; No known method
    mov rdi, 0                    ; set rdi to 0 so caller doesn't use garbage
    jmp .exit_func2

    .on_p:
    cmp byte [client_buffer + 3], ' '
    je .on_put
    mov rax, 2                    ; POST
    mov rdi, 5
    jmp .exit_func2

    .on_put:
    mov rax, 4                    ; PUT
    mov rdi, 4
    jmp .exit_func2

    .on_delete:
    mov rax, 3                    ; DELETE
    mov rdi, 7
    jmp .exit_func2

    .on_head:
    mov rax, 6                    ; HEAD
    mov rdi, 5
    jmp .exit_func2

    .on_get:
    mov rax, 1                    ; GET
    mov rdi, 4
    jmp .exit_func2

    .on_trace:
    mov rax, 5                    ; TRACE
    mov rdi, 6
    jmp .exit_func2

    .exit_func2:
    mov rsp, rbp
    pop rbp
    ret

; Print the method name followed by a space
; Operands: r15 - Method Code (see check_method)
; Clobbers: rax, rdi, rsi, rdx, rcx, r11
; Result:   Nothing
print_method:
    push rbp
    mov rbp, rsp
    push r13
    push r14

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

    mov r13, http_unknown           ; 0 or anything unexpected
    mov r14, http_unknown_len
    jmp .print

    .on_get_m:
    mov r13, http_get
    mov r14, http_get_len
    jmp .print

    .on_post_m:
    mov r13, http_post
    mov r14, http_post_len
    jmp .print

    .on_delete_m:
    mov r13, http_delete
    mov r14, http_delete_len
    jmp .print

    .on_put_m:
    mov r13, http_put
    mov r14, http_put_len
    jmp .print

    .on_trace_m:
    mov r13, http_trace
    mov r14, http_trace_len
    jmp .print

    .on_head_m:
    mov r13, http_head
    mov r14, http_head_len

    .print:
    call write_to_console
    call write_space_inline

    pop r14
    pop r13
    mov rsp, rbp
    pop rbp
    ret

; Print the request path followed by a space
; Operands: r9  - Path starting address (0 if the path was blocked)
;           r10 - Path ending address
; Clobbers: rax, rdi, rsi, rdx, rcx, r11
; Result:   Nothing
print_path:
    push rbp
    mov rbp, rsp
    push r13
    push r14

    ; handle NULL path from 403 case safely
    test r9, r9
    jnz .real_path
    mov r13, http_forbidden_path
    mov r14, http_forbidden_path_len
    jmp .print

    .real_path:
    mov r13, r9
    mov r14, r10
    sub r14, r9                     ; path length = end - start

    .print:
    call write_to_console
    call write_space_inline

    pop r14
    pop r13
    mov rsp, rbp
    pop rbp
    ret

; Print the status code number followed by a newline
; Operands: r8 - Response code number
; Clobbers: rax, rdi, rsi, rdx, rcx, r11
; Result:   Nothing
print_status_code:
    push rbp
    mov rbp, rsp
    push r8                         ; itoa clobbers r8 and r9
    push r9
    push r13
    push r14

    mov rax, r8
    mov rdi, http_code_buffer
    call itoa
    mov r13, http_code_buffer
    mov r14, rax                    ; itoa returns the string length
    call write_to_console
    call write_new_line

    pop r14
    pop r13
    pop r9
    pop r8
    mov rsp, rbp
    pop rbp
    ret
