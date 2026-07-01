extern write_to_console
extern read_from_console
extern atoi
extern handle_http_request

section .data
    port_prompt db "Please specify a port to run on", 10 , 0x00
    port_prompt_len equ $ - port_prompt -1
    starting_msg db "[Info] Starting webserver at port ", 0x00
    starting_msg_len equ $ - starting_msg - 1

    success_msg_bind db "[Debug] Succesfully bound to socket", 10 , 0x00
    success_msg_bind_len equ $ - success_msg_bind -1
    success_msg_listen db "[Debug] Now listening to connection", 10 , 0x00
    success_msg_listen_len equ $ - success_msg_listen -1


    error_starting_fs db "[Error] There was an issue creating a socket!", 10, 0x00
    error_starting_fs_len equ $ - error_starting_fs -1

    error_binding_to_socket db "[Error] There was an issue binding to a socket!", 10, 0x00
    error_binding_to_socket_len equ $ - error_binding_to_socket -1

    client_connected_msg db "[Debug] A client has connected!", 10, 0x00
    client_connected_msg_len equ $ - client_connected_msg - 1

    got_client_msg db "[Debug] Sys_Accept fired! Client connected!", 10, 0x00
    got_client_msg_len equ $ - got_client_msg - 1

section .bss
    i_port_buffer resb 20
    i_port_def resw 1
    i_socket_fs resq 1
    server_fd   resq 1
    client_fd   resq 1
    sockaddr_in   resb 16

section .text
    global _start

_start:

    mov r13, port_prompt
    mov r14, port_prompt_len
    call write_to_console


    mov r13, i_port_buffer
    mov r14, 20
    call read_from_console

    mov r15, rax ; mov length into r15 for later use

    mov r13, i_port_buffer
    mov r14, rax
    call atoi

    mov [i_port_def], ax

    mov r13, starting_msg
    mov r14, starting_msg_len
    call write_to_console
    mov r13, i_port_buffer
    mov r14, r15
    call write_to_console

    call start_server

    ; sys_accept loop for client bound connections
    ; Operands: None
    ; Clobbers: rax, rdi, rsi, rdx
    ; Result:   None
    ; Flags:    None
    ; Note:     No exit right now
    .accept_loop:
    mov rax, 43             ; sys_accept
    mov rdi, [server_fd]    ; Listen on our server socket
    mov rsi, 0              ; NULL (We don't care about the client's IP struct right now)
    mov rdx, 0              ; NULL (Length of client IP struct)
    syscall

    push rax
    mov r13, client_connected_msg
    mov r14, client_connected_msg_len
    call write_to_console
    pop rax
    ; When the code reaches here, it means a client connected!
    ; rax now holds the client's specific socket File Descriptor.
    mov rdi, rax
    call handle_http_request

    ; Loop back up and wait for the next person!
    jmp .accept_loop

    mov rax, 60
    xor rdi, rdi
    syscall
; Start a TCP Socket on a specified port
; Clobbers: rax, rdi, rdx, rsi
; Result:   rax = ...
start_server:
    push rbp
    mov rbp, rsp

    mov rax, 41 ; Open Socket
    mov rdi, 2 ;AF_INET
    mov rsi, 1 ; TCP / SOCK_STREAM
    mov rdx, 0 ; default
    syscall

    cmp rax, -1
    je .error
    .socket_success:
    mov [server_fd], rax
    mov rdi, sockaddr_in
    xor rax, rax
    mov rcx, 2
    rep stosq
    mov word [sockaddr_in], 2 ; byte 0+1
    mov ax, [i_port_def]
    xchg al, ah                       ; Convert from Little to Big Endian for sys_bind
    mov word [sockaddr_in + 2], ax ; byte 2+3 (port address)
    ; sin_addr (bytes 4-7) is already 0 (INADDR_ANY) thanks to our zero-fill above.
    ; sin_zero padding (bytes 8-15) is also already 0.
    mov rax, 49             ; sys_bind
    mov rdi, [server_fd]    ; Socket FD
    mov rsi, sockaddr_in    ; 16-byte sockaddr_in pointer
    mov rdx, 16             ; Size of sockaddr_in
    syscall

    cmp rax, -1
    je .bind_error

    mov r13, success_msg_bind
    mov r14, success_msg_bind_len

    call write_to_console
    mov r13, success_msg_listen
    mov r14, success_msg_listen_len
    call write_to_console
    mov rax, 50             ; sys_listen
    mov rdi, [server_fd]    ; Our socket descriptor
    mov rsi, 10             ; Hold 10 incoming requests
    syscall

    cmp rax, -1
    je .listen_error
    jmp .exit_server

    .error:
    mov r13, error_starting_fs
    mov r14, error_starting_fs_len
    call write_to_console
    jmp .exit_server
    ret

    .bind_error:
    mov r13, error_binding_to_socket
    mov r14, error_binding_to_socket_len
    call write_to_console
    jmp .exit_server
    ret

    .listen_error:
    jmp .exit_server
    ret

    .exit_server:
    mov rsp, rbp
    pop rbp
    ret