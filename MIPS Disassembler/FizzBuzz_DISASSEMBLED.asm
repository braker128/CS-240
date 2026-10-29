.data
data0: .asciiz "Fizz"
data1: .asciiz "Buzz"

.text
    addiu $t3, $zero, 3
    addiu $t5, $zero, 5
    addiu $t0, $zero, 0
    addiu $t9, $zero, 100
L0:
    addi $t0, $t0, 1
    div $t0, $t3
    mfhi $t1
    div $t0, $t5
    mfhi $t2
    beq $zero, $t1, L5
L1:
    beq $zero, $t2, L6
L2:
    beq $zero, $t8, L7
L3:
    addiu $t8, $zero, 0
    j L8
L4:
    bne $t0, $t9, L0
    j L9
L5:
    addiu $v0, $zero, 4
    la $a0, data0
    syscall
    addi $t8, $t8, 1
    j L1
L6:
    addiu $v0, $zero, 4
    la $a0, data1
    syscall
    addi $t8, $t8, 1
    j L2
L7:
    addiu $v0, $zero, 1
    addu $a0, $t0, $zero
    syscall
    j L3
L8:
    addiu $v0, $zero, 11
    addiu $a0, $zero, 10
    syscall
    j L4
L9:
