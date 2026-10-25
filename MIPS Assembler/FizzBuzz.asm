.data
fizzText: .asciiz "Fizz"
buzzText: .asciiz "Buzz"
.text

li $t3, 3
li $t5, 5

#Range
li $t0, 0   # Start
li $t9, 100 # End

increment:
addi $t0, $t0, 1

# rem Rdest, Rsrc1, Rsrc2 -- Rdest = Rsrc1 % Rsec2
rem $t1, $t0, $t3 # X % 3 Output (Fizz: $t1 == 0)
rem $t2, $t0, $t5 # X % 5 Output (Buzz: $t2 == 0)

# FizzBuzz Text
beq $zero, $t1, fizz
fizzEnd:
beq $zero, $t2, buzz
buzzEnd:

beq $zero, $t8, printInt
printIntEnd:
li $t8, 0

j newLine
newLineEnd:

bne $t0, $t9, increment

j Exit


# Functions
fizz:
li $v0, 4
la $a0, fizzText
syscall
addi $t8, $t8, 1
j fizzEnd

buzz:
li $v0, 4
la $a0, buzzText
syscall
addi $t8, $t8, 1
j buzzEnd

printInt:
li $v0, 1
move $a0, $t0
syscall
j printIntEnd

newLine:
li $v0, 11
li $a0, '\n'
syscall
j newLineEnd

Exit: