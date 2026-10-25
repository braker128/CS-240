# Count from 1 to 100
li $t1, 1
li $t2, 101

loop1:
j PrintInt
PrintIntEnd:

j PrintNewLine
PrintNewLineEnd:

addi $t1, $t1, 1
bne $t1, $t2, loop1
j Exit


# Functions (Methods)
PrintInt:
li $v0, 1
move $a0, $t1
syscall
j PrintIntEnd

PrintNewLine:
li $v0, 11
li $a0, '\n'
syscall
j PrintNewLineEnd

Exit:
