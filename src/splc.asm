format ELF64 executable

namespace syscall
include "syscalls.asm"
end namespace

namespace String
include "string.asm"
end namespace

segment readable
dbg_fnd_str_ltrl         String.Normal "Debug: Found string literal start!", 10
dbg_fnd_str_ltrl_mid     String.Normal "Debug: Found string literal middle!", 10
dbg_fnd_str_ltrl_end     String.Normal "Debug: Found string literal end!", 10
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
file_path String.Reserved 256
parse_state:              dq PARSE_STATE_NONE
        .buffer           String.Reserved 1024
        .literal          dq PARSE_STATE_NONE
        .append_continue  db 0
code    String.Reserved 1024

PARSE_STATE_NONE            = 0x00
PARSE_STATE_KEYWORD         = 0x10
PARSE_STATE_EXPRESSION      = 0x20
PARSE_STATE_EXPRESSION_STR  = 0x21

segment executable
entry main
main:
        ; Get the file path
        cmp qword [rsp], 2
        je .file_path_got
        string.stdout e_expected_file_path
        je exitError

        ; Get the length of the file path
        .file_path_got:
        mov rax, [rsp + 16]
        push rax 
        mov rdi, rax
        call string.len
        mov [file_path.len], rax

        ; Checks the length is within the the capacity
        cmp [file_path.len], file_path.cap
        jle .file_path_success
        string.stdout e_expected_file_path_256
        je exitError

        ; Copies the file path to the variable
        .file_path_success:
        mov rdi, file_path
        pop rsi ; src
        mov rdx, [file_path.len]
        call string.copyr 

        ; Open the file
        syscall.open file_path
        mov [fd], rax
        cmp [fd], -1    ; check for error
        jne .file_open_success
        string.stdout e_failed_to_open_file
        je exitError

        ; Get the length of the file
        .file_open_success:
        syscall.lseek.end [fd], 0
        mov [file_length], rax
        syscall.lseek.set [fd], 0
        
        ; Read the file
        syscall.read [fd], code, code.cap
        mov [code.len], rax

        mov rsi, code
        mov rdx, parse_state.buffer
        call parse
        ; string.stdout parse_state.buffer

        ; Close the file
        syscall.close [fd]

        call exit


exit:      syscall.exit 0
exitError: syscall.exit 1

; rsi = code
; rdx = parse_state.buffer
parse:
        push rax
        push rcx

        xor rax, rax
        .loop:
                mov cl, [rsi + rax] ; code[i]
                mov ch, [parse_state.append_continue]
                ; if append_continue == true then append
                ; if code[i] == ' ' then descent
                cmp ch, 1
                je .append
                cmp cl, ' '
                je .descent
                .append:
                        ; Add cl to parse_state.buffer
                        push r10
                        mov r10, [parse_state.buffer.len] ; j 
                        mov [rdx + r10], cl ; parse_state.buffer[j] = cl
                        inc [parse_state.buffer.len]
                        pop r10
                        cmp ch, 0
                        je .after_descent
                .descent:
                        cmp qword [parse_state], PARSE_STATE_NONE
                        je .expect_any
                        cmp qword [parse_state], PARSE_STATE_KEYWORD
                        je .expect_keyword
                        cmp qword [parse_state], PARSE_STATE_EXPRESSION
                        je .expect_expression
                        .expect_any:
                                call expectAny
                                jmp .descent
                        .expect_keyword:
                                call expectKeyword
                                jmp .after_descent
                        .expect_expression:
                                call expectExpression
                                jmp .after_descent

                .after_descent:
                ; Check for the code EOF
                cmp rax, [code.len]
                jg .exit
                inc rax
                jmp .loop
        .exit:

        pop rcx
        pop rax
        ret

expectAny:
        ; TODO:
        mov qword [parse_state], PARSE_STATE_KEYWORD
        ret

expectKeyword:
        push rdi
        push rdx
        push rsi
        push rax

        xor rax, rax
        mov rdi, keyword_stdout      ; stdout
        mov rsi, rdx                 ; parse_state.buffer
        mov rdx, keyword_stdout.len  ; length
        mov r10, [parse_state.buffer.len]       ; length
        call string.cmpr
        cmp rax, 1
        jne .false
        ; .true:
                syscall.saveReg
                string.stdout keyword_stdout
                string.stdout newline
                syscall.restoreReg
                mov qword    [parse_state],                 PARSE_STATE_EXPRESSION
                mov qword    [parse_state.literal],         PARSE_STATE_NONE
                mov          [parse_state.buffer],          0
                string.clear parse_state.buffer
                pop rax
                pop rsi
                pop rdx
                pop rdi
                ret
        .false:
                syscall.saveReg
                string.stdout e_expected_keyword_found
                string.stdout quote
                string.stdout parse_state.buffer
                string.stdout quote
                string.stdout newline
                syscall.restoreReg
                call exitError

expectExpression:
        push rdx

        cmp [parse_state.literal], PARSE_STATE_EXPRESSION_STR
        je .literal_str

        cmp byte [rdx], '"'
        je .string_literal_start
        cmp byte [rdx], ' '
        ; TODO:
        jmp .unknown

        .literal_str:
        cmp [parse_state.literal], PARSE_STATE_EXPRESSION_STR
        jne .unknown

        add rdx, [parse_state.buffer.len]
        dec rdx
        cmp byte [rdx], '"'
        je .string_literal_end
        jne .string_literal_middle

        .string_literal_start:
                syscall.saveReg
                string.stdout dbg_fnd_str_ltrl
                string.stdout parse_state.buffer
                string.stdout newline
                syscall.restoreReg
                mov qword [parse_state.literal],         PARSE_STATE_EXPRESSION_STR
                mov       [parse_state.append_continue], 1
                jmp .exit
        .string_literal_middle:
                syscall.saveReg
                string.stdout dbg_fnd_str_ltrl_mid
                syscall.restoreReg
                jmp .exit
        .string_literal_end:
                syscall.saveReg
                string.stdout dbg_fnd_str_ltrl_end
                string.stdout parse_state.buffer
                string.stdout newline
                syscall.restoreReg
                mov qword    [parse_state],                 PARSE_STATE_NONE
                mov qword    [parse_state.literal],         PARSE_STATE_NONE
                mov          [parse_state.append_continue], 0
                string.clear parse_state.buffer
                jmp .exit
        .unknown:
                syscall.exit 69

        .exit:
        pop rdx
        ret
