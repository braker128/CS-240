# Set-up
li $t0, 0x10010000 # load immediate, [li $destination, value]
li $t1, 0x10010020
li $t2, 8
li $t3, 7
sw $t2, 0($t0) # store word, [sw $source, offset($base_register)]
sw $t3, 0($t1)


# Clear
li $t0, 0
li $t1, 0
li $t2, 0
li $t3, 0


# [Program]
li $t0, 0x10010000
li $t1, 0x10010020
li $t2, 0x10010040

lw $t3, 0($t0) # load word, [lw $destination, offset($base_register)]
lw $t4, 0($t1)

add $t5, $t3, $t4

sw $t5, 0($t2)
