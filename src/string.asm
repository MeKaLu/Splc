namespace syscall
        include "syscalls.asm"
end namespace

struc Normal data*&        
        . db data
        .len = $ - .
        .type_check = "String"
end struc

struc Reserved capacity*
        . rb capacity
        .len dq 0
        .cap = capacity
        .type_check = "String.Reserved"
end struc

; Calls the internal stdout macro
macro stdout str*
        if str.type_check = "String"
                syscall.stdout str, str.len
        else if str.type_check = "String.Reserved"
                syscall.stdout str, [str.len]
        else
                assert 0 = 1
        end if
end macro

; "Clears" the string
macro clear str*
        assert str.type_check = "String.Reserved"
        mov [str],     0
        mov [str.len], 0
end macro

macro copy dest*, src*
        if dest.type_check = "String"
                if src.type_check = "String"
                        assert dest.len >= src.len
                        mov rdx, src.len
                else if src.type_check = "String.Reserved"
                        assert dest.len >= src.cap
                        mov rdx, [src.len]
                else
                        assert 0 = 1
                end if
        else if dest.type_check = "String.Reserved"
                if src.type_check = "String"
                        assert dest.cap >= src.len
                        mov rdx, src.len
                else if src.type_check = "String.Reserved"
                        assert dest.cap >= src.cap
                        mov rdx, [src.len]
                else
                        assert 0 = 1
                end if
        else
                assert 0 = 1
        end if 

        mov rdi, dest
        mov rsi, src
        call copyr
end macro

; Copies the string
; @param rdi: dest
; @param rsi: src
; @param rdx: length
copyr:
        ; index
        push r10
        ; character
        push rax

        xor r10, r10
        .loop:
                mov al, [rsi + r10]   ; ch
                mov [rdi + r10], al   ; dest[i] = ch
                cmp r10, rdx          ; if i == length
                je .exit
                inc r10
                jmp .loop

        .exit:
        pop rax
        pop r10
        ret

; Counts the bytes until it gets to the null character
; @param rdi: buffer
; @param rax: return value
len:
        xor rax, rax
        .loop:
                cmp byte [rdi + rax], 0 ; if character == null
                je .exit
                inc rax
                jmp .loop
        .exit:
        ret

; Compares 2 strings
; @param rdi: a
; @param rsi: b
; @param rdx: a.length
; @param r10: b.length
; @param rax: return value
?cmpr:
        push r8  ; index
        push r9  ; rval
        push rbx ; ch2

        cmp rdx, r10
        jne .exit_false

        xor rax, rax
        mov r9, 1
        .loop:
                ; loop condition
                cmp r8, rdx
                je .exit

                ; compare characters
                mov bl, [rdi + r8]
                mov al, [rsi + r8]
                cmp al, bl
                jne .exit_false

                inc r8
                jmp .loop
        
        .exit_false:
                mov r9, 0
        .exit:
                mov rax, r9
        pop rbx
        pop r9
        pop r8
        ret
        
