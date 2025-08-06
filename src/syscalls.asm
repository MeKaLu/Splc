macro saveReg
        push rax
        push rdi
        push rsi
        push rdx
        push r10
        push r8
        push r9
end macro

macro restoreReg
        pop r9
        pop r8
        pop r10
        pop rdx
        pop rsi
        pop rdi
        pop rax
end macro

; Calls the exit syscall:
macro exit code*
        mov rax, 60
        mov rdi, code
        syscall
end macro


; Calls the sys_read:
macro read fd*, buffer*, count*
        mov rax, 0
        mov rdi, fd
        mov rsi, buffer
        mov rdx, count
        syscall
end macro

macro write fd*, buffer*, buffer_length*
        mov rax, 1
        mov rdi, fd
        mov rsi, buffer
        mov rdx, buffer_length
        syscall
end macro

; Calls the sys_write with stdout syscall:
macro stdout buffer*, buffer_length*
        mov rax, 1
        mov rdi, 1 ; stdout is 1
        mov rsi, buffer
        mov rdx, buffer_length
        syscall
end macro

; Calls the sys_open:
; Default flag and mode is read only
macro open filename*, flags:0, mode:0
        mov rax, 2
        mov rdi, filename
        mov rsi, flags
        mov rdx, mode
        syscall
end macro

; Calls the sys_close:
macro close fd*
        mov rax, 3
        mov rdi, fd
        syscall
end macro

; Calls the sys_lseek:
macro lseek fd*, offset*, origin*
        mov rax, 8
        mov rdi, fd
        mov rsi, offset
        mov rdx, origin
        syscall
end macro

; Calls the sys_lseek with SEEK_SET:
macro lseek.set fd*, offset*
        mov rax, 8
        mov rdi, fd
        mov rsi, offset
        mov rdx, 0
        syscall
end macro 

; Calls the sys_lseek with SEEK_CUR:
macro lseek.cur fd*, offset*
        mov rax, 8
        mov rdi, fd
        mov rsi, offset
        mov rdx, 1
        syscall
end macro 

; Calls the sys_lseek with SEEK_END:
macro lseek.end fd*, offset*
        mov rax, 8
        mov rdi, fd
        mov rsi, offset
        mov rdx, 2
        syscall
end macro 

macro rename oldname*, newname*
        mov rax, 82
        mov rdi, oldname
        mov rsi, newname
        syscall
end macro
