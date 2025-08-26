format ELF64 executable

namespace syscall
include "syscalls.asm"
end namespace

namespace String
include "string.asm"
end namespace

entry main

segment readable
number String.Normal "123123"

segment executable
main:
        ; compare
        mov rbx, number
        mov r8,  number.len
     
        call string.isNumber
        cmp rax, 1
        je  .true
        jne .false
        .true:
                syscall.exit 31
        .false:
                syscall.exit 32
