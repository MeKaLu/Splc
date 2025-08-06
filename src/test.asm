format ELF64 executable

namespace syscall
include "syscalls.asm"
end namespace

namespace String
include "string.asm"
end namespace

entry main

segment readable
stdout String.Normal "stdout"
foo    String.Normal "stdout"

segment executable
main:
        ; compare
        mov rbx, stdout
        mov r8,  stdout.len
        
        mov rdx, foo
        mov r9,  foo.len
        call string.cmpr
        cmp rax, 1
        je  .true
        jne .false
        .true:
                syscall.exit 31
        .false:
                syscall.exit 32
