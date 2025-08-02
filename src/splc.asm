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
        je exitError

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
        je exitError

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
        je exitError

        ; Get the length of the file
        .file_open_success:
        syscall.lseek.end [fd], 0
        mov [file_length], rax
        syscall.lseek.set [fd], 0
        
        ; Read the file
        syscall.read [fd], buffer, buffer.cap
        mov [buffer.len], rax

        mov rsi, buffer
        mov rdx, buffer2
        call parse
        ; String.stdout buffer2

        ; Close the file
        syscall.close [fd]

        call exit


exit:      syscall.exit 0
exitError: syscall.exit 1

; rsi = buffer
; rdx = buffer2
parse:
        push rax
        push rcx

        xor rax, rax
        .loop:
                mov cl, [rsi + rax] ; buffer[i]
                ; Check if ch == ' '
                cmp cl, ' '
                je .space
                        ; Add ch to buffer2
                        push r10
                        mov r10, [buffer2.len] ; j 
                        mov [rdx + r10], cl ; buffer2[j] = ch
                        inc [buffer2.len]
                        pop r10
                        jmp .space_after
                .space:
                        call isKeyword
                .space_after:

                cmp rax, [buffer.len]
                jg .exit
                inc rax
                jmp .loop
        .exit:

        pop rcx
        pop rax
        ret

isKeyword:
        push rdi
        push rdx
        push rsi
        push rax

        xor rax, rax
        mov rdi, keyword_stdout      ; stdout
        mov rsi, rdx                 ; buffer2
        mov rdx, keyword_stdout.len  ; length
        mov r10, [buffer2.len]       ; length
        call String.cmp 
        cmp rax, 1
        jne .false
        ; .true:
                syscall.saveReg
                String.stdout keyword_stdout
                String.stdout newline
                syscall.restoreReg
                mov [buffer2.len], 0
                pop rax
                pop rsi
                pop rdx
                pop rdi
                ret
        .false:
                syscall.saveReg
                String.stdout e_expected_keyword_found
                String.stdout quote
                String.stdout buffer2
                String.stdout quote
                String.stdout newline
                syscall.restoreReg
                call exitError

segment readable
e_expected_file_path     String.Normal "Error: Expected a file path, got none!", 10
e_expected_file_path_256 String.Normal "Error: Expected a file path length to be < 256!", 10
e_failed_to_open_file    String.Normal "Error: Failed to open the file!", 10
e_expected_keyword_found String.Normal "Error: Expected keyword, found " 
keyword_stdout           String.Normal "stdout"
quote                    String.Normal "`"
newline                  String.Normal 10

segment readable writeable
fd dq 0
file_length dq 0
buffer    String.Reserved 1024
buffer2   String.Reserved 1024
file_path String.Reserved 256

