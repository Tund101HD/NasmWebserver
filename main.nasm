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

    error_listening db "[Error] There was an issue listening on the socket!", 10, 0x00
    error_listening_len equ $ - error_listening -1

    client_connected_msg db "[Debug] A client has connected!", 10, 0x00
    client_connected_msg_len equ $ - client_connected_msg - 1

    server_root db "/mnt/c/Users/busin/CLionProjects/AssemblyWebserver/www", 0x00
    server_root_len equ $ - server_root -1

section .bss
    i_port_buffer resb 20
    i_port_def resw 1
    server_fd   resq 1
    root_fd resq 1
    sockaddr_in   resb 16


section .text
    global _start
    global root_fd

_start:

    mov rax, 257
    mov rdi, -100
    mov rsi, server_root
    mov rdx, 0x10000 ; read only
    syscall

    test rax, rax
    js .fatal_exit
    mov [root_fd], rax ; move baseline into root_fd


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

    ; check rax for error — start_server now returns 0 on success, -1 on failure
    cmp rax, -1
    je .fatal_exit

    ; sys_accept loop for client bound connections
    .accept_loop:
    mov rax, 43             ; sys_accept
    mov rdi, [server_fd]    ; Listen on our server socket
    mov rsi, 0              ; NULL
    mov rdx, 0              ; NULL
    syscall

    push rax
    mov r13, client_connected_msg
    mov r14, client_connected_msg_len
    call write_to_console
    pop rax

    mov rdi, rax
    call handle_http_request

    jmp .accept_loop

    .fatal_exit:
    mov rax, 60
    mov rdi, 1              ; exit code 1
    syscall

; Start a TCP Socket on a specified port
; Clobbers: rax, rdi, rdx, rsi, rcx, r11
; Result:   rax = 0 on success, -1 on failure
start_server:
    push rbp
    mov rbp, rsp

    mov rax, 41             ; Open Socket
    mov rdi, 2              ; AF_INET
    mov rsi, 1              ; TCP / SOCK_STREAM
    mov rdx, 0              ; default
    syscall

    cmp rax, -1
    je .error

    mov [server_fd], rax
    mov rdi, sockaddr_in
    xor rax, rax
    mov rcx, 2
    rep stosq
    mov word [sockaddr_in], 2
    mov ax, [i_port_def]
    xchg al, ah
    mov word [sockaddr_in + 2], ax

    mov rax, 49             ; sys_bind
    mov rdi, [server_fd]
    mov rsi, sockaddr_in
    mov rdx, 16
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
    mov rdi, [server_fd]
    mov rsi, 10
    syscall

    cmp rax, -1
    je .listen_error

    xor rax, rax            ; return 0 = success
    jmp .exit_server

    .error:
    mov r13, error_starting_fs
    mov r14, error_starting_fs_len
    call write_to_console
    mov rax, -1             ; return -1 = failure
    jmp .exit_server

    .bind_error:
    mov r13, error_binding_to_socket
    mov r14, error_binding_to_socket_len
    call write_to_console
    mov rax, -1             ; return -1 = failure
    jmp .exit_server

    .listen_error:
    mov r13, error_listening
    mov r14, error_listening_len
    call write_to_console
    mov rax, -1             ; return -1 = failure
    jmp .exit_server

    .exit_server:
    mov rsp, rbp
    pop rbp
    ret
