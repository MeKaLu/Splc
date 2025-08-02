namespace syscall
        include "syscalls.asm"
end namespace

struc Normal data*&        
        . db data
        .len = $ - $$
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
        call _copy
end macro

; Copies the string
; @param rdi: dest
; @param rsi: src
; @param rdx: length
_copy:
        ; index
        push r10
        ; character
        push r8

        xor r10, r10
        .loop:
                mov r8, [rsi + r10]   ; ch
                mov [rdi + r10], r8   ; dest[i] = ch
                cmp r10, rdx          ; if i == length
                je .exit
                inc r10
                jmp .loop

        .exit:
        pop r8
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
