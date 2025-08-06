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

TOKEN_STATE_NONE     = 0x00
TOKEN_STATE_SYMBOL   = 0x10
TOKEN_STATE_SLITERAL = 0x20

TOKEN_TYPE_SYMBOL    = 0x00
TOKEN_TYPE_COMMA     = 0x10
TOKEN_TYPE_SLITERAL  = 0x20

PARSE_STATE_NONE        = 0x00
PARSE_STATE_KEYWORD     = 0x10
PARSE_STATE_EXPRESSION  = 0x20

namespace EMIT
        STATE_NONE     = 0x00
        STATE_STDOUT   = 0x01
        STATE_EXPR     = 0x10
        STATE_EXPR_VA  = 0x11
end namespace 

segment readable
dbg_fnd_str_ltrl          String.Normal "Debug: Found string literal start!", 10
dbg_fnd_str_ltrl_mid      String.Normal "Debug: Found string literal middle!", 10
dbg_fnd_str_ltrl_end      String.Normal "Debug: Found string literal end!", 10
e:
        .expected_file_path      String.Normal "Error: Expected a file path, got none!", 10
        .expected_file_path_256  String.Normal "Error: Expected a file path length to be < 256!", 10
        .failed_to_open_file     String.Normal "Error: Failed to open the file!", 10
        .expected_file_size_1024 String.Normal "Error: Expected a file size to be < 1024!", 10
        .expected_keyword_found  String.Normal "Error: Expected keyword, found " 
        .unknown_token_type      String.Normal "Error: Unknown token type "
        .unknown_emit_state      String.Normal "Error: Unknown emit state "
        .to_expect               String.Normal "to expect", 10
        .to_emit                 String.Normal "to emit", 10
quote                     String.Normal "`"
newline                   String.Normal 10
seperation_line           String.Normal "-----------------------", 10
space                     String.Normal " "
namespace emit
        output_path       String.Normal "a.out", 0
        output_path_e     String.Normal "a.out.old", 0
        stdout            String.Normal "syscall.stdout"
        mark_va           String.Normal ","
        mark_sliteral     String.Normal '"'
end namespace
namespace keyword
        stdout            String.Normal "stdout"
end namespace

segment readable writeable
fd          dq 0
file_length dq 0
file_path   String.Reserved 256
code        String.Reserved 1024
tokens:
        repeat 1024, i:0
                .i Token 
        end repeat
        .len dq 0
        .cap = 1024

emit.state db EMIT.STATE_NONE

segment executable
entry main
main:
        ; Get the file path
        cmp qword [rsp], 2
        je .file_path_got
        string.stdout e.expected_file_path
        call exitError

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
        string.stdout e.expected_file_path_256
        call exitError

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
        string.stdout e.failed_to_open_file
        call exitError

        ; Get the length of the file
        .file_open_success:
        syscall.lseek.end [fd], 0
        mov [file_length], rax
        syscall.lseek.set [fd], 0

        ; Check if it is within bounds
        cmp [file_length], code.cap
        jl .file_seek_success
        string.stdout e.expected_file_size_1024
        call exitError
        
        .file_seek_success:
        ; Read the file
        syscall.read [fd], code, code.cap
        mov [code.len], rax

        ; Close the file
        syscall.close [fd]

        ; remove a.out
        syscall.rename emit.output_path, emit.output_path_e

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

        call parse

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

                ; TODO print the types

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

parse:
        push r10 ; index
        push r8  ; parse_state
        push rdi ; tokens

        xor r10, r10
        xor r8, r8
        mov rdi, tokens
        .loop:
                cmp r10, [tokens.len]
                je .exit

                 ; calculate the index
                push rdi
                push r10
                        imul r10, TOKEN_SIZE
                        add rdi, r10
                pop r10

                cmp r8, PARSE_STATE_NONE
                je .parse_state_none
                cmp r8, PARSE_STATE_KEYWORD
                je .parse_state_keyword
                cmp r8, PARSE_STATE_EXPRESSION
                je .parse_state_expression

                .parse_state_none:
                        call expectAny
                        jmp .parse_state_after
                .parse_state_keyword:
                        call expectKeyword
                        jmp .parse_state_after
                .parse_state_expression:
                        call expectExpression
                        jmp .parse_state_after
                .parse_state_after: pop rdi

                inc r10
                jmp .loop

        .exit:

        pop rdi
        pop r8
        pop r10
        ret

; @param r8 : parse_state
; @param rdi: token
expectAny:
        push rbx ; token.type
        mov bl, [rdi + 16]

        cmp bl, TOKEN_TYPE_SYMBOL
        je .symbol
        cmp bl, TOKEN_TYPE_COMMA
        je .comma
        cmp bl, TOKEN_TYPE_SLITERAL
        je .sliteral

        string.stdout e.unknown_token_type
        string.stdout e.to_expect
        call exitError

        .symbol:
                mov r8, PARSE_STATE_KEYWORD
                call expectKeyword
                jmp .exit
        .comma:
                ; TODO
                syscall.exit 70
                jmp .exit
        .sliteral:
                mov r8, PARSE_STATE_EXPRESSION
                call expectExpression
                jmp .exit

        .exit:
        pop rbx
        ret

; @param r8 : parse_state
; @param rdi: token
expectKeyword:
        ; TODO: go through all of the keywords

        push r10 ; parse_state

        ; compare
        push rbx ; a
        push rdx ; b
        push r8  ; a.len
        push r9  ; b.len
        push rax ; rval
                mov rbx, keyword.stdout
                mov r8,  keyword.stdout.len
                
                mov rdx, code
                add rdx, [rdi]
                mov r9,  [rdi + 8]
                sub r9,  [rdi]
                call string.cmpr
                cmp rax, 1
                je  .true
                jne .false
                .true:
                        mov [emit.state], EMIT.STATE_STDOUT
                        mov r10, PARSE_STATE_EXPRESSION
                        call emit
                        jmp .exit
                .false:
                        ; TODO
                        syscall.exit -1
                        jmp .exit
        .exit:
        pop rax
        pop r9
        pop r8
        pop rdx
        pop rbx

        ; Save the parse_state
        mov r8, r10
        pop r10
                      
        ret

; @param r8 : parse_state
; @param rdi: token
expectExpression:
        ; TODO
        push rbx ; token.type

        mov bl, [rdi + 16] ; token.type
        cmp bl, TOKEN_TYPE_COMMA
        je .emit.expr_va
        cmp bl, TOKEN_TYPE_SLITERAL
        je .emit.expr

        string.stdout e.unknown_token_type
        string.stdout e.to_expect
        call exitError

        .emit.expr:
                mov [emit.state], EMIT.STATE_EXPR
                jmp .exit
        .emit.expr_va:
                mov [emit.state], EMIT.STATE_EXPR_VA
                jmp .exit

        .exit:
        pop rbx
        jmp emit

; @param r8 : parse_state
; @param rdi: token
?emit:
        syscall.saveReg
        ; open file        
        syscall.open emit.output_path, 0101 ; O_CREAT | O_WRONLY
        mov [fd], rax
        cmp [fd], -1 ; check for error
        jne .file_open_success
        string.stdout e.failed_to_open_file
        call exitError

        .file_open_success:
        syscall.lseek.end [fd], 0
        cmp [emit.state], EMIT.STATE_STDOUT
        je .write_stdout
        cmp [emit.state], EMIT.STATE_EXPR
        je .write_expr
        cmp [emit.state], EMIT.STATE_EXPR_VA
        je .write_expr_va

        string.stdout e.unknown_emit_state
        string.stdout e.to_emit
        call exitError

        .write_stdout:
                syscall.write [fd], emit.stdout, emit.stdout.len
                syscall.write [fd], space,       space.len
                jmp .exit
        .write_expr:
                syscall.write [fd], emit.mark_sliteral, emit.mark_sliteral.len
                ; get the expression
                syscall.restoreReg
                push r11
                push r12
                        mov r11, code
                        add r11, [rdi]
                        mov r12, [rdi + 8]
                        sub r12, [rdi]
                        syscall.saveReg
                                syscall.write [fd], r11, r12
                        syscall.restoreReg
                pop r12
                pop r11
                syscall.saveReg
                syscall.write [fd], emit.mark_sliteral, emit.mark_sliteral.len
                jmp .exit
        .write_expr_va:
                syscall.write [fd], emit.mark_va, emit.mark_va.len
                jmp .exit

        .exit:
                mov [emit.state], EMIT.STATE_NONE

        ; close file
        syscall.close [fd]
        syscall.restoreReg
        ret
