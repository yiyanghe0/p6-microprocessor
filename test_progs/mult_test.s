	li	x1, 0x000a   #00
	li	x2, 0x000b   #04
	li	x3, 0x000c   #08
	li	x4, 0x000d   #0c
    mul x1, x1, x1   #10
    mul x2, x2, x2   #14
    mul x3, x3, x3   #18
    wfi              #1c

