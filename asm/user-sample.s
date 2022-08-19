.set noreorder
.set noat
.globl __start
.section text

__start:
.text
    lui $a1, 0x8040     # $a1 = 0x803ffffc
	addi $a1,$a1,-4
	lui $a2, 0x8050		# $a2 = 0x80500000
	addi $a3,$a2,-4		# $a3 = 0x804ffffc
loop1:
	beq $a1,$a2,loop1end
	addiu $a1,$a1,4
	lw $t0,0($a1)
	or $t3,$0,$0
	or $t2,$0,$0
loop2:
	mul $t1,$t3,$t3
	sub $t2,$t1,$t0
	bgtz $t2,loop2end
	nop
	beq $0,$0,loop2
	addiu $t3,$t3,1
	
loop2end:
	addi $t4,$t3,-1
	beq $0,$0,loop1
	sw  $t4,4($a3)
loop1end:
	jr $ra
	nop