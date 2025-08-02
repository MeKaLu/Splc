format ELF64 executable

namespace syscall
include "syscalls.asm"
end namespace

namespace String
include "string.asm"
end namespace

segment executable
entry main
main:
        ; Get the file path
        cmp qword [rsp], 2
        je .file_path_got
        String.stdout e_expected_file_path
        je .error

        ; Get the length of the file path
        .file_path_got:
        mov rax, [rsp + 16]
        push rax 
        mov rdi, rax
        call String.len
        mov [file_path.len], rax

        ; Checks the length is within the the capacity
        cmp [file_path.len], file_path.cap
        jle .file_path_success
        String.stdout e_expected_file_path_256
        je .error

        ; Copies the file path to the variable
        .file_path_success:
        mov rdi, file_path
        pop rsi ; src
        mov rdx, [file_path.len]
        call String._copy 

        ; Open the file
        syscall.open file_path
        mov [fd], rax
        cmp [fd], -1    ; check for error
        jne .file_open_success
        String.stdout e_failed_to_open_file
        je .error

        ; Get the length of the file
        .file_open_success:
        syscall.lseek.end [fd], 0
        mov [file_length], rax
        syscall.lseek.set [fd], 0
        
        ; Read the file
        syscall.read [fd], buffer, buffer.cap
        mov [buffer.len], rax

        String.stdout buffer

        ; Close the file
        syscall.close [fd]

        syscall.exit 0
        .error: syscall.exit 1

segment readable
e_expected_file_path     String.Normal "Error: Expected a file path, got none!", 10
e_expected_file_path_256 String.Normal "Error: Expected a file path length to be < 256!", 10
e_failed_to_open_file    String.Normal "Error: Failed to open the file!", 10

segment readable writeable
fd dq 0
file_length dq 0
buffer String.Reserved 1024
file_path String.Reserved 256

