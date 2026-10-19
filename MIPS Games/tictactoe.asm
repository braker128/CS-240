.data

msg_title:   .asciiz "=== TIC-TAC-TOE ===\nCells are numbered 1-9, left to right, top to bottom.\n\n"
msg_prompt1: .asciiz "Player "
msg_prompt2: .asciiz ", enter a cell (1-9): "
msg_rangeError:   .asciiz "Invalid input. Enter a number from 1 to 9.\n"
msg_cellTaken:   .asciiz "That cell is already taken. Try again.\n"
msg_wins:    .asciiz " wins!\n"
msg_draw:    .asciiz "It's a draw!\n"
openBracket:    .asciiz "[ "
closeBracket:   .asciiz "]\n"
newline:      .asciiz "\n"

.text
gameStart:
# Empty Board
li $s0, '-'
li $s1, '-'
li $s2, '-'
li $s3, '-'
li $s4, '-'
li $s5, '-'
li $s6, '-'
li $s7, '-'
li $t8, '-'

li $t0, 'X'  # Current player ('X' or 'O')
li $t1, 0  # Total moves
#  $t2 - Chosen cell (1-9)
li $t3, '-'  # Empty comparison value


li $v0, 4
la $a0, msg_title # "=== TIC-TAC-TOE ===\nCells...\n\n"
syscall


gameLoop:
    jal printBoard
    jal playerMove
    addi $t1, $t1, 1 # moves++

    jal checkWin
    bnez $v0, playerWins # if $v0 != 0, player wins

    beq $t1, 9, draw # board full -> draw

    # Switch players
        li $t2, 'X' # comparison value
        beq $t0, $t2, switchToO # if $t0 == 'X', switch to 'O'

        # Switch to X
        li $t0, 'X'
        j gameLoop

        switchToO:
        li $t0, 'O'
        j gameLoop


    playerWins:
        jal printBoard

        li $v0, 4
        la $a0, msg_prompt1 # "Player "
        syscall

        li $v0, 11
        move $a0, $t0 # 'X' or 'O'
        syscall

        li $v0, 4
        la $a0, msg_wins # " wins!\n"
        syscall

        j exit


    draw:
        jal printBoard

        li $v0, 4
        la $a0, msg_draw # "It's a draw!\n"
        syscall

        j exit


    exit:
    li $v0, 10
    syscall





printBoard:
    # row 1: cells 1 2 3
    li   $v0, 4
    la   $a0, openBracket
    syscall
    li   $v0, 11
    move $a0, $s0
    syscall
    li   $a0, ' '
    syscall
    move $a0, $s1
    syscall
    li   $a0, ' '
    syscall
    move $a0, $s2
    syscall
    li   $a0, ' '
    syscall
    li   $v0, 4
    la   $a0, closeBracket
    syscall
 
    # row 2: cells 4 5 6
    li   $v0, 4
    la   $a0, openBracket
    syscall
    li   $v0, 11
    move $a0, $s3
    syscall
    li   $a0, ' '
    syscall
    move $a0, $s4
    syscall
    li   $a0, ' '
    syscall
    move $a0, $s5
    syscall
    li   $a0, ' '
    syscall
    li   $v0, 4
    la   $a0, closeBracket
    syscall
 
    # row 3: cells 7 8 9
    li   $v0, 4
    la   $a0, openBracket
    syscall
    li   $v0, 11
    move $a0, $s6
    syscall
    li   $a0, ' '
    syscall
    move $a0, $s7
    syscall
    li   $a0, ' '
    syscall
    move $a0, $t8
    syscall
    li   $a0, ' '
    syscall
    li   $v0, 4
    la   $a0, closeBracket
    syscall
 
    li   $v0, 4
    la   $a0, newline
    syscall
    jr   $ra





playerMove:
prompt_move:
    li $v0, 4
    la $a0, msg_prompt1 # "Player "
    syscall

    li $v0, 11
    move $a0, $t0 # 'x' or 'O'
    syscall

    li $v0, 4
    la $a0, msg_prompt2 # ", enter a cell (1-9): "
    syscall

    li $v0, 5
    syscall
    move $t2, $v0 # $t2 == chosen cell (1-9)

    blt $t2, 1, move_rangeError
    bgt $t2, 9, move_rangeError

# Direct to check chosen cell
    beq $t2, 1, cm1
    beq $t2, 2, cm2
    beq $t2, 3, cm3
    beq $t2, 4, cm4
    beq $t2, 5, cm5
    beq $t2, 6, cm6
    beq $t2, 7, cm7
    beq $t2, 8, cm8
    beq $t2, 9, cm9


# Check Move Validity
cm1:
    bne $s0, $t3, cell_taken # if cell 1 is not empty ($t3 == '-') -> cell_taken
    move $s0, $t0 # place marker ('X' or 'O')
    jr $ra
cm2:
    bne $s1, $t3, cell_taken
    move $s1, $t0
    jr $ra
cm3:
    bne $s2, $t3, cell_taken
    move $s2, $t0
    jr $ra
cm4:
    bne $s3, $t3, cell_taken
    move $s3, $t0
    jr $ra
cm5:
    bne $s4, $t3, cell_taken
    move $s4, $t0
    jr $ra
cm6:
    bne $s5, $t3, cell_taken
    move $s5, $t0
    jr $ra
cm7:
    bne $s6, $t3, cell_taken
    move $s6, $t0
    jr $ra
cm8:
    bne $s7, $t3, cell_taken
    move $s7, $t0
    jr $ra
cm9:
    bne $t8, $t3, cell_taken
    move $t8, $t0
    jr $ra

cell_taken:
    li $v0, 4
    la $a0, msg_cellTaken
    syscall
    j prompt_move

move_rangeError:
    li $v0, 4
    la $a0, msg_rangeError
    syscall
    j prompt_move





checkWin: # $v0 = 1 if win, 0 if no win
cw1: # row 1: cells 1 2 3
    beq  $s0, $t3, cw2
    bne  $s0, $s1, cw2
    bne  $s0, $s2, cw2
    j    cw_yes
cw2: # row 2: cells 4 5 6
    beq  $s3, $t3, cw3
    bne  $s3, $s4, cw3
    bne  $s3, $s5, cw3
    j    cw_yes
cw3: # row 3: cells 7 8 9
    beq  $s6, $t3, cw4
    bne  $s6, $s7, cw4
    bne  $s6, $t8, cw4
    j    cw_yes
cw4: # column 1: cells 1 4 7
    beq  $s0, $t3, cw5
    bne  $s0, $s3, cw5
    bne  $s0, $s6, cw5
    j    cw_yes
cw5: # column 2: cells 2 5 8
    beq  $s1, $t3, cw6
    bne  $s1, $s4, cw6
    bne  $s1, $s7, cw6
    j    cw_yes
cw6: # column 3: cells 3 6 9
    beq  $s2, $t3, cw7
    bne  $s2, $s5, cw7
    bne  $s2, $t8, cw7
    j    cw_yes
cw7: # diagonal: cells 1 5 9
    beq  $s0, $t3, cw8
    bne  $s0, $s4, cw8
    bne  $s0, $t8, cw8
    j    cw_yes
cw8: # diagonal: cells 3 5 7
    beq  $s2, $t3, cw_no
    bne  $s2, $s4, cw_no
    bne  $s2, $s6, cw_no
    j    cw_yes
 
cw_no:
    li   $v0, 0
    jr   $ra

cw_yes:
    li   $v0, 1
    jr   $ra

