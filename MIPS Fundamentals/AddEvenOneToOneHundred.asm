# Start and Incrementer
li $t1, 2
# End
li $t2, 102

loop:
# Accumulator
add $t0, $t0, $t1
# Increment
addi $t1, $t1, 2
# Loop Back
bne $t1, $t2, loop

