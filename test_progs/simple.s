start: addi a1, x0, 2
    addi a2, x0, 3
    addi a3, x0, 4
    addi a4, x0, 8
loop: add a1, a1, a1
    add a2, a2, a2
    bne a1, a4, loop
nop
nop
nop 
nop
wfi