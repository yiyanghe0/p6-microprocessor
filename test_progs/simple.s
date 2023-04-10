start: addi a1, x0, 2  #00
    addi a2, x0, 3     #04
    lw   a5, 0(x0)     #08
    addi a3, x0, 4     #0c
    addi a4, x0, 8     #10
loop: add a1, a1, a1   #14
    add a2, a2, a2     #18
    bne a1, a4, loop   #1c
wfi                    #20