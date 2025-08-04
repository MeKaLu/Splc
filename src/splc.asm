format ELF64 executable

namespace syscall
include "syscalls.asm"
end namespace

namespace String
include "string.asm"
end namespace

struc Token
        .slice_start dq 0  ; 8 bytes
        .slice_end   dq 0  ; 8 bytes
        .type        db 0  ; 1 byte
end struc
TOKEN_SIZE = 17

macro Token name*, n*
end macro

segment readable
dbg_fnd_str_ltrl          String.Normal "Debug: Found string literal start!", 10
dbg_fnd_str_ltrl_mid      String.Normal "Debug: Found string literal middle!", 10
dbg_fnd_str_ltrl_end      String.Normal "Debug: Found string literal end!", 10
e_expected_file_path      String.Normal "Error: Expected a file path, got none!", 10
e_expected_file_path_256  String.Normal "Error: Expected a file path length to be < 256!", 10
e_failed_to_open_file     String.Normal "Error: Failed to open the file!", 10
e_expected_file_size_1024 String.Normal "Error: Expected a file size to be < 1024!", 10
e_expected_keyword_found  String.Normal "Error: Expected keyword, found " 
keyword_stdout            String.Normal "stdout"
quote                     String.Normal "`"
newline                   String.Normal 10
seperation_line           String.Normal "-----------------------", 10

segment readable writeable
fd          dq 0
file_length dq 0
file_path   String.Reserved 256
parse_state:              dq PARSE_STATE_NONE
        .buffer           String.Reserved 1024
        .literal          dq PARSE_STATE_NONE
        .append_continue  db 0
code    String.Reserved 1024
tokens:
        repeat 1024, i:0
                .i Token 
        end repeat
        .len dq 0
        .cap = 1024

TOKEN_STATE_NONE     = 0x00
TOKEN_STATE_SYMBOL   = 0x10
TOKEN_STATE_SLITERAL = 0x20

TOKEN_TYPE_SYMBOL    = 0x00
TOKEN_TYPE_COMMA     = 0x10
TOKEN_TYPE_SLITERAL  = 0x20

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
        jl .file_path_success
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

        ; Check if it is within bounds
        cmp [file_length], code.cap
        jl .file_seek_success
        string.stdout e_expected_file_size_1024
        je exitError
        
        .file_seek_success:
        ; Read the file
        syscall.read [fd], code, code.cap
        mov [code.len], rax

        ; Close the file
        syscall.close [fd]

        call tokenize
        ; mov rax, tokens
        ; mov qword [rax], 0
        ; mov qword [rax + 8], 6
        ; mov byte [rax + 16], 1
        ; mov rbx, 1
        ; imul rbx, TOKEN_SIZE
        ; add rax, rbx
        ; mov qword [rax], 7
        ; mov qword [rax + 8], 13
        ; mov byte [rax + 16], 2
        ; mov [tokens.len], 2

        call printTokens

        syscall.exit [tokens.len]

        ; mov rsi, code
        ; mov rdx, parse_state.buffer
        ; call parse

        call exit


exit:      syscall.exit 0
exitError: syscall.exit 1

printTokens:
        syscall.saveReg
                string.stdout seperation_line
        syscall.restoreReg
        push r10 ; index
        push rdi ; tokens

        xor r10, r10
        mov rdi, tokens
        .loop:
                cmp r10, [tokens.len]
                je .exit

                push rdi
                push r9
                push r8

                ; calculate the index
                push r10
                imul r10, TOKEN_SIZE
                add rdi, r10
                pop r10

                ; get the slice_start
                mov r9, [rdi]
                ; get the slice_end
                mov r8, [rdi + 8] 

                syscall.saveReg
                push r11
                push r8
                        mov r11, code
                        add r11, r9
                        sub r8, r9
                        syscall.stdout r11, r8
                        string.stdout quote
                        string.stdout newline
                pop r8
                pop r11
                syscall.restoreReg
                
                pop r8
                pop r9
                pop rdi

                inc r10
                jmp .loop
        .exit:
        
        pop rdi
        pop r10
        ret

tokenize:
        push r10 ; index
        push r9  ; slice_start
        push r11 ; surround_count
        push r12 ; token_index
        push rax ; code[i]
        push rsi ; code
        push rdi ; tokens

        xor r10, r10
        xor r9, r9
        xor r11, r11
        xor r12, r12
        xor rax, rax
        mov rsi, code
        mov rdi, tokens
        .loop:
                ; Check for the code EOF
                cmp r10, [code.len]
                je .exit

                mov cl, [rsi + r10] ; code[i]

                .token:
                        ; 0,   1,   2
                        ; [17] [17] [17]
                        ; 0,   17,  24
                        push rdi ; tokens[i]
                        push r12
                                imul r12, TOKEN_SIZE ; i * size
                                add rdi, r12
                        pop r12
                        ; got tokens[i]
                        mov      [rdi],      r9                 ; slice_start
                        mov      [rdi + 8],  r10                ; slice_end
                        mov byte [rdi + 16], TOKEN_TYPE_SYMBOL  ; type

                        ; find the token type
                        cmp cl, '"'
                        je .token_is_sliteral
                        cmp cl, ','
                        je .char_is_comma
                        cmp cl, ' '
                        je .char_is_space
                        push r10
                                inc r10
                                cmp r10, [code.len]
                        pop r10
                        je .should_add_last
                        jne .token_after

                        .should_add_last:
                                ; skip the empty, otherwise append
                                cmp r10, r9
                                jne .token_append
                                je  .token_skip
                        .char_is_comma:
                                cmp r11, 0
                                jg .token_after
                                je .token_is_comma
                        .char_is_space:
                                cmp r11, 0
                                jg .token_after
                                ; skip the empty, otherwise append
                                cmp r10, r9
                                jne .token_append
                                je  .token_skip

                        .token_is_comma:
                                mov byte [rdi + 16], TOKEN_TYPE_COMMA  ; type
                                jmp .token_append
                        .token_is_sliteral:
                                inc r11
                                cmp r11, 2
                                mov byte [rdi + 16], TOKEN_TYPE_SLITERAL  ; type
                                je  .token_append
                                jne .token_skip
                        .token_append:
                                ; dbg
                                syscall.saveReg
                                push r11
                                push r10
                                        mov r11, rsi ; code
                                        add r11, r9
                                        sub r10, r9  ; slice_end - slice_start
                                        syscall.stdout r11, r10  ; lentgh
                                        string.stdout quote
                                        string.stdout newline
                                pop r10
                                pop r11
                                syscall.restoreReg

                                ; append
                                inc [tokens.len]
                                mov r9, r10  ; set slice_start
                                inc r9
                                inc r12      ; increase the token index
                                xor r11, r11 ; reset surround count
                        .token_after:
                                pop rdi
                                jmp .after
                        .token_skip:
                                mov r9, r10  ; set slice_start
                                inc r9
                                pop rdi
                .after:
                inc r10
                jmp .loop
        .exit:
        pop rdi
        pop rsi
        pop rax
        pop r12
        pop r11
        pop r9
        pop r10
        ret

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

        ; TODO: go through a list of keywords
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
                mov          [parse_state.append_continue], 1
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
