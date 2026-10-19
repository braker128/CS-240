# MARS 4.5 | standalone game | Keyboard/Display MMIO input + Bitmap Display
# BITMAP SETTINGS: unit width/height 2, display width/height 512,
# base address 0x10010000 (static data); logical canvas 256 x 256.
# Assemble ONE game; open and connect BOTH tools BEFORE Run. Keyboard input
# goes in the MMIO tool's lower Keyboard area: type numbers, press Enter.
# Default memory configuration; delayed branching OFF; run at unlimited speed.
# Syscalls retained only for exit, random numbers, and optional pacing.
.data 0x10010000
.align 2
ui_framebuffer: .space 262144   # 256*256 RGB words; kept clear of game data.

# Tic-tac-toe for the MARS Keyboard/Display MMIO Simulator and Bitmap Display.
# Interface-only adaptation: the original board registers and win rules are retained.
# Bitmap setup: 2 x 2 units, 512 x 512 display, base 0x10010000.
# Connect both tools before Run. Use Keyboard MMIO input; submit with Enter.
.data
tt_title:        .asciiz "TIC-TAC-TOE"
tt_turn:         .asciiz "PLAYER X TO MOVE"
tt_prompt:       .asciiz "PLAYER X: CELL 1-9, THEN ENTER"
tt_rangeError:   .asciiz "INVALID INPUT: CHOOSE 1-9"
tt_takenError:   .asciiz "CELL TAKEN. TRY ANOTHER."
tt_winStatus:    .asciiz "PLAYER X WINS!"
tt_winPrompt:    .asciiz "PLAYER X WINS. GAME OVER."
tt_drawStatus:   .asciiz "DRAW - WELL PLAYED!"
tt_drawPrompt:   .asciiz "DRAW. ALL NINE CELLS FILLED."

# Rectangles within the current cell, whose origin is kept in $t4/$t5.
.macro tt_box (%x, %y, %w, %h)
    addiu $a0, $t4, %x
    addiu $a1, $t5, %y
    li $a2, %w
    li $a3, %h
    jal ui_rect
.end_macro

.text
main:
gameStart:
    # Original empty board: cells 1..8 in s0..s7, cell 9 in t8.
    li $s0, '-'
    li $s1, '-'
    li $s2, '-'
    li $s3, '-'
    li $s4, '-'
    li $s5, '-'
    li $s6, '-'
    li $s7, '-'
    li $t8, '-'
    li $t0, 'X'                 # Current player.
    li $t1, 0                   # Number of accepted moves.
    li $t3, '-'                 # Empty-cell comparison value.

    li $a0, 0x000B1727
    sw $a0, ui_bg
    li $a0, 0x00132B3C
    sw $a0, ui_panel
    li $a0, 0x0055DBD1
    sw $a0, ui_accent
    la $a0, tt_title
    jal ui_init

gameLoop:
    jal printBoard
    jal playerMove
    addi $t1, $t1, 1
    jal checkWin
    bnez $v0, playerWins
    beq $t1, 9, draw

    # Original turn switching.
    li $t2, 'X'
    beq $t0, $t2, switchToO
    li $t0, 'X'
    j gameLoop
switchToO:
    li $t0, 'O'
    j gameLoop

playerWins:
    jal printBoard
    sb $t0, tt_winStatus+7
    sb $t0, tt_winPrompt+7
    la $a0, tt_winStatus
    li $a3, 0x00FFC857
    jal tt_status
    la $a0, tt_winPrompt
    jal ui_prompt
    j exit

draw:
    jal printBoard
    la $a0, tt_drawStatus
    li $a3, 0x00FFC857
    jal tt_status
    la $a0, tt_drawPrompt
    jal ui_prompt
    j exit

exit:
    # The bitmap retains the final position and result after program exit.
    li $v0, 10
    syscall

# Draw the original nine register-backed cells. UI calls do not change game state.
printBoard:
    addiu $sp, $sp, -28
    sw $ra, 0($sp)
    sw $a0, 4($sp)
    sw $a1, 8($sp)
    sw $a2, 12($sp)
    sw $a3, 16($sp)
    sw $v0, 20($sp)
    sw $v1, 24($sp)

    li $a0, 8
    li $a1, 40
    li $a2, 240
    li $a3, 168
    li $v1, 0x000B1727
    jal ui_rect
    sb $t0, tt_turn+7
    la $a0, tt_turn
    li $a3, 0x00EAF1F7
    jal tt_status

    # The inset frame and 2-pixel gutters form the board grid.
    li $a0, 54
    li $a1, 57
    li $a2, 148
    li $a3, 148
    li $v1, 0x00233F51
    jal ui_rect

    li $a0, 56
    li $a1, 59
    move $a2, $s0
    li $a3, 1
    jal tt_cell
    li $a0, 104
    li $a1, 59
    move $a2, $s1
    li $a3, 2
    jal tt_cell
    li $a0, 152
    li $a1, 59
    move $a2, $s2
    li $a3, 3
    jal tt_cell
    li $a0, 56
    li $a1, 107
    move $a2, $s3
    li $a3, 4
    jal tt_cell
    li $a0, 104
    li $a1, 107
    move $a2, $s4
    li $a3, 5
    jal tt_cell
    li $a0, 152
    li $a1, 107
    move $a2, $s5
    li $a3, 6
    jal tt_cell
    li $a0, 56
    li $a1, 155
    move $a2, $s6
    li $a3, 7
    jal tt_cell
    li $a0, 104
    li $a1, 155
    move $a2, $s7
    li $a3, 8
    jal tt_cell
    li $a0, 152
    li $a1, 155
    move $a2, $t8
    li $a3, 9
    jal tt_cell

    lw $ra, 0($sp)
    lw $a0, 4($sp)
    lw $a1, 8($sp)
    lw $a2, 12($sp)
    lw $a3, 16($sp)
    lw $v0, 20($sp)
    lw $v1, 24($sp)
    addiu $sp, $sp, 28
    jr $ra

# a0 = cell x, a1 = cell y, a2 = marker, a3 = cell number.
# Preserve all game registers and the caller's argument/result registers.
tt_cell:
    addiu $sp, $sp, -44
    sw $ra, 0($sp)
    sw $a0, 4($sp)
    sw $a1, 8($sp)
    sw $a2, 12($sp)
    sw $a3, 16($sp)
    sw $v0, 20($sp)
    sw $v1, 24($sp)
    sw $t4, 28($sp)
    sw $t5, 32($sp)
    sw $t6, 36($sp)
    sw $t7, 40($sp)
    move $t4, $a0
    move $t5, $a1
    move $t6, $a2
    move $t7, $a3

    li $v1, 0x00132B3C
    tt_box (1, 1, 46, 46)
    li $a0, 'X'
    beq $t6, $a0, tt_cell_x
    li $a0, 'O'
    beq $t6, $a0, tt_cell_o

    # Empty cell numbers remain readable at twice the normal font size.
    li $a0, 2
    sw $a0, ui_scale
    move $a0, $t7
    addiu $a1, $t4, 19
    addiu $a2, $t5, 17
    li $a3, 0x00607F91
    jal ui_number
    li $a0, 1
    sw $a0, ui_scale
    j tt_cell_done

tt_cell_x:
    # Two continuous, thick diagonal strokes.
    li $v1, 0x00FF6B89
    li $t7, 0
tt_x_loop:
    addu $a0, $t4, $t7
    addiu $a0, $a0, 12
    addu $a1, $t5, $t7
    addiu $a1, $a1, 12
    li $a2, 4
    li $a3, 4
    jal ui_rect
    addiu $a0, $t4, 32
    subu $a0, $a0, $t7
    addu $a1, $t5, $t7
    addiu $a1, $a1, 12
    li $a2, 4
    li $a3, 4
    jal ui_rect
    addiu $t7, $t7, 1
    blt $t7, 21, tt_x_loop
    j tt_cell_done

tt_cell_o:
    # A 28-pixel ring, built from overlapping four-pixel strokes.
    li $v1, 0x0055DBD1
    tt_box (18, 10, 12, 4)
    tt_box (14, 12, 6, 4)
    tt_box (12, 14, 4, 6)
    tt_box (10, 18, 4, 12)
    tt_box (12, 28, 4, 6)
    tt_box (14, 32, 6, 4)
    tt_box (18, 34, 12, 4)
    tt_box (28, 32, 6, 4)
    tt_box (32, 28, 4, 6)
    tt_box (34, 18, 4, 12)
    tt_box (32, 14, 4, 6)
    tt_box (28, 12, 6, 4)

tt_cell_done:
    lw $ra, 0($sp)
    lw $a0, 4($sp)
    lw $a1, 8($sp)
    lw $a2, 12($sp)
    lw $a3, 16($sp)
    lw $v0, 20($sp)
    lw $v1, 24($sp)
    lw $t4, 28($sp)
    lw $t5, 32($sp)
    lw $t6, 36($sp)
    lw $t7, 40($sp)
    addiu $sp, $sp, 44
    jr $ra

# a0 = status message, a3 = text color. The strip sits above the board.
tt_status:
    addiu $sp, $sp, -36
    sw $ra, 0($sp)
    sw $a0, 4($sp)
    sw $a1, 8($sp)
    sw $a2, 12($sp)
    sw $a3, 16($sp)
    sw $v1, 20($sp)
    sw $t4, 24($sp)
    sw $t5, 28($sp)
    lw $t4, 4($sp)
    lw $t5, 16($sp)
    li $a0, 8
    li $a1, 40
    li $a2, 240
    li $a3, 14
    li $v1, 0x000B1727
    jal ui_rect
    li $a0, 1
    sw $a0, ui_scale
    move $a0, $t4
    li $a1, 56
    li $a2, 43
    move $a3, $t5
    jal ui_text
    lw $ra, 0($sp)
    lw $a0, 4($sp)
    lw $a1, 8($sp)
    lw $a2, 12($sp)
    lw $a3, 16($sp)
    lw $v1, 20($sp)
    lw $t4, 24($sp)
    lw $t5, 28($sp)
    addiu $sp, $sp, 36
    jr $ra

playerMove:
    # Save the original return address across the new MMIO/UI calls.
    addiu $sp, $sp, -4
    sw $ra, 0($sp)
prompt_move:
    sb $t0, tt_prompt+7
    la $a0, tt_prompt
    jal ui_prompt
    jal ui_read_int
    move $t2, $v0
    blt $t2, 1, move_rangeError
    bgt $t2, 9, move_rangeError

    beq $t2, 1, cm1
    beq $t2, 2, cm2
    beq $t2, 3, cm3
    beq $t2, 4, cm4
    beq $t2, 5, cm5
    beq $t2, 6, cm6
    beq $t2, 7, cm7
    beq $t2, 8, cm8
    beq $t2, 9, cm9

# These are the original per-cell checks and placements.
cm1:
    bne $s0, $t3, cell_taken
    move $s0, $t0
    j move_accepted
cm2:
    bne $s1, $t3, cell_taken
    move $s1, $t0
    j move_accepted
cm3:
    bne $s2, $t3, cell_taken
    move $s2, $t0
    j move_accepted
cm4:
    bne $s3, $t3, cell_taken
    move $s3, $t0
    j move_accepted
cm5:
    bne $s4, $t3, cell_taken
    move $s4, $t0
    j move_accepted
cm6:
    bne $s5, $t3, cell_taken
    move $s5, $t0
    j move_accepted
cm7:
    bne $s6, $t3, cell_taken
    move $s6, $t0
    j move_accepted
cm8:
    bne $s7, $t3, cell_taken
    move $s7, $t0
    j move_accepted
cm9:
    bne $t8, $t3, cell_taken
    move $t8, $t0
move_accepted:
    lw $ra, 0($sp)
    addiu $sp, $sp, 4
    jr $ra

cell_taken:
    la $a0, tt_takenError
    li $a3, 0x00FF6B89
    jal tt_status
    j prompt_move

move_rangeError:
    la $a0, tt_rangeError
    li $a3, 0x00FF6B89
    jal tt_status
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


# Shared bitmap renderer and MMIO keyboard driver.
# Every public UI routine preserves the game's register state, including HI/LO.
# Only ui_read_int returns a new $v0. No console I/O is used.
.data
.align 2
ui_bg: .word 0x0B1423
ui_panel: .word 0x16263A
ui_accent: .word 0x39D3BB
ui_scale: .word 1
ui_number_buf: .space 16
ui_input_buf: .space 40
ui_char_buf: .space 4
ui_cr_pending: .word 0
ui_overflow_count: .word 0
ui_font:
    .byte 0,0,0,0,0,0,0 # ASCII 32
    .byte 4,4,4,4,4,0,4 # ASCII 33
    .byte 10,10,0,0,0,0,0 # ASCII 34
    .byte 10,10,31,10,31,10,10 # ASCII 35
    .byte 4,15,20,14,5,30,4 # ASCII 36
    .byte 25,26,2,4,8,11,19 # ASCII 37
    .byte 14,17,1,2,4,0,4 # ASCII 38
    .byte 4,4,0,0,0,0,0 # ASCII 39
    .byte 2,4,8,8,8,4,2 # ASCII 40
    .byte 8,4,2,2,2,4,8 # ASCII 41
    .byte 0,21,14,31,14,21,0 # ASCII 42
    .byte 0,4,4,31,4,4,0 # ASCII 43
    .byte 0,0,0,0,6,4,8 # ASCII 44
    .byte 0,0,0,31,0,0,0 # ASCII 45
    .byte 0,0,0,0,0,6,6 # ASCII 46
    .byte 1,2,2,4,8,8,16 # ASCII 47
    .byte 14,17,19,21,25,17,14 # ASCII 48
    .byte 4,12,4,4,4,4,14 # ASCII 49
    .byte 14,17,1,2,4,8,31 # ASCII 50
    .byte 30,1,1,14,1,1,30 # ASCII 51
    .byte 2,6,10,18,31,2,2 # ASCII 52
    .byte 31,16,16,30,1,1,30 # ASCII 53
    .byte 14,16,16,30,17,17,14 # ASCII 54
    .byte 31,1,2,4,8,8,8 # ASCII 55
    .byte 14,17,17,14,17,17,14 # ASCII 56
    .byte 14,17,17,15,1,1,14 # ASCII 57
    .byte 0,6,6,0,6,6,0 # ASCII 58
    .byte 0,6,6,0,6,4,8 # ASCII 59
    .byte 2,4,8,16,8,4,2 # ASCII 60
    .byte 0,0,31,0,31,0,0 # ASCII 61
    .byte 8,4,2,1,2,4,8 # ASCII 62
    .byte 14,17,1,2,4,0,4 # ASCII 63
    .byte 14,17,1,2,4,0,4 # ASCII 64
    .byte 14,17,17,31,17,17,17 # ASCII 65
    .byte 30,17,17,30,17,17,30 # ASCII 66
    .byte 15,16,16,16,16,16,15 # ASCII 67
    .byte 30,17,17,17,17,17,30 # ASCII 68
    .byte 31,16,16,30,16,16,31 # ASCII 69
    .byte 31,16,16,30,16,16,16 # ASCII 70
    .byte 15,16,16,23,17,17,15 # ASCII 71
    .byte 17,17,17,31,17,17,17 # ASCII 72
    .byte 31,4,4,4,4,4,31 # ASCII 73
    .byte 7,2,2,2,18,18,12 # ASCII 74
    .byte 17,18,20,24,20,18,17 # ASCII 75
    .byte 16,16,16,16,16,16,31 # ASCII 76
    .byte 17,27,21,21,17,17,17 # ASCII 77
    .byte 17,25,21,19,17,17,17 # ASCII 78
    .byte 14,17,17,17,17,17,14 # ASCII 79
    .byte 30,17,17,30,16,16,16 # ASCII 80
    .byte 14,17,17,17,21,18,13 # ASCII 81
    .byte 30,17,17,30,20,18,17 # ASCII 82
    .byte 15,16,16,14,1,1,30 # ASCII 83
    .byte 31,4,4,4,4,4,4 # ASCII 84
    .byte 17,17,17,17,17,17,14 # ASCII 85
    .byte 17,17,17,17,17,10,4 # ASCII 86
    .byte 17,17,17,21,21,27,17 # ASCII 87
    .byte 17,17,10,4,10,17,17 # ASCII 88
    .byte 17,17,10,4,4,4,4 # ASCII 89
    .byte 31,1,2,4,8,16,31 # ASCII 90
    .byte 14,8,8,8,8,8,14 # ASCII 91
    .byte 14,17,1,2,4,0,4 # ASCII 92
    .byte 14,2,2,2,2,2,14 # ASCII 93
    .byte 14,17,1,2,4,0,4 # ASCII 94
    .byte 0,0,0,0,0,0,31 # ASCII 95
    .byte 14,17,1,2,4,0,4 # ASCII 96
    .byte 14,17,17,31,17,17,17 # ASCII 97
    .byte 30,17,17,30,17,17,30 # ASCII 98
    .byte 15,16,16,16,16,16,15 # ASCII 99
    .byte 30,17,17,17,17,17,30 # ASCII 100
    .byte 31,16,16,30,16,16,31 # ASCII 101
    .byte 31,16,16,30,16,16,16 # ASCII 102
    .byte 15,16,16,23,17,17,15 # ASCII 103
    .byte 17,17,17,31,17,17,17 # ASCII 104
    .byte 31,4,4,4,4,4,31 # ASCII 105
    .byte 7,2,2,2,18,18,12 # ASCII 106
    .byte 17,18,20,24,20,18,17 # ASCII 107
    .byte 16,16,16,16,16,16,31 # ASCII 108
    .byte 17,27,21,21,17,17,17 # ASCII 109
    .byte 17,25,21,19,17,17,17 # ASCII 110
    .byte 14,17,17,17,17,17,14 # ASCII 111
    .byte 30,17,17,30,16,16,16 # ASCII 112
    .byte 14,17,17,17,21,18,13 # ASCII 113
    .byte 30,17,17,30,20,18,17 # ASCII 114
    .byte 15,16,16,14,1,1,30 # ASCII 115
    .byte 31,4,4,4,4,4,4 # ASCII 116
    .byte 17,17,17,17,17,17,14 # ASCII 117
    .byte 17,17,17,17,17,10,4 # ASCII 118
    .byte 17,17,17,21,21,27,17 # ASCII 119
    .byte 17,17,10,4,10,17,17 # ASCII 120
    .byte 17,17,10,4,4,4,4 # ASCII 121
    .byte 31,1,2,4,8,16,31 # ASCII 122
    .byte 14,17,1,2,4,0,4 # ASCII 123
    .byte 4,4,4,4,4,4,4 # ASCII 124
    .byte 14,17,1,2,4,0,4 # ASCII 125
    .byte 14,17,1,2,4,0,4 # ASCII 126

.text

ui_rect:
    addiu $sp,$sp,-32
    sw $t0,0($sp)
    sw $t1,4($sp)
    sw $t2,8($sp)
    sw $t3,12($sp)
    sw $t4,16($sp)
    sw $t5,20($sp)
    sw $t6,24($sp)
    sw $t7,28($sp)
# Intersect the rectangle with the 256x256 framebuffer.
    addu $t2,$a0,$a2
    addu $t3,$a1,$a3
    move $t0,$a0
    move $t1,$a1
    bgez $t0,ui_rect_x_ok
    move $t0,$zero
ui_rect_x_ok:
    bgez $t1,ui_rect_y_ok
    move $t1,$zero
ui_rect_y_ok:
    ble $t2,256,ui_rect_right_ok
    li $t2,256
ui_rect_right_ok:
    ble $t3,256,ui_rect_bottom_ok
    li $t3,256
ui_rect_bottom_ok:
    bge $t0,$t2,ui_rect_return
    bge $t1,$t3,ui_rect_return
    sll $t4,$t1,8
    addu $t4,$t4,$t0
    sll $t4,$t4,2
    li $t5,0x10010000
    addu $t4,$t4,$t5
    subu $t6,$t2,$t0
ui_rect_row:
    move $t5,$t4
    move $t7,$t6
ui_rect_col:
    sw $v1,0($t5)
    addiu $t5,$t5,4
    addiu $t7,$t7,-1
    bgtz $t7,ui_rect_col
    addiu $t4,$t4,1024
    addiu $t1,$t1,1
    blt $t1,$t3,ui_rect_row
ui_rect_return:
    lw $t0,0($sp)
    lw $t1,4($sp)
    lw $t2,8($sp)
    lw $t3,12($sp)
    lw $t4,16($sp)
    lw $t5,20($sp)
    lw $t6,24($sp)
    lw $t7,28($sp)
    addiu $sp,$sp,32
    jr $ra

ui_text:
    addiu $sp,$sp,-68
    sw $a0,0($sp)
    sw $a1,4($sp)
    sw $a2,8($sp)
    sw $a3,12($sp)
    sw $v1,16($sp)
    sw $s0,20($sp)
    sw $s1,24($sp)
    sw $s2,28($sp)
    sw $s3,32($sp)
    sw $s4,36($sp)
    sw $s5,40($sp)
    sw $s6,44($sp)
    sw $s7,48($sp)
    sw $t0,52($sp)
    sw $t1,56($sp)
    sw $t2,60($sp)
    sw $ra,64($sp)
move $s0,$a0
    move $s1,$a1
    move $s2,$a2
    move $s3,$a3
    lw $s4,ui_scale
    # Restrict scale to 1 or 2, so accidentally stale state stays bounded.
    beq $s4,2,ui_text_next
    li $s4,1
ui_text_next:
    lbu $t0,0($s0)
    beqz $t0,ui_text_return
    addiu $s0,$s0,1
    beq $t0,10,ui_text_newline
    beq $t0,13,ui_text_next
    blt $t0,97,ui_text_upper
    bgt $t0,122,ui_text_upper
    addiu $t0,$t0,-32
ui_text_upper:
    blt $t0,32,ui_text_unknown
    ble $t0,126,ui_text_glyph
ui_text_unknown:
    li $t0,63
ui_text_glyph:
    addiu $t0,$t0,-32
    sll $t1,$t0,3
    subu $t0,$t1,$t0
    la $s5,ui_font
    addu $s5,$s5,$t0
    li $s6,0
ui_text_row:
    lbu $s7,0($s5)
    li $t2,0
ui_text_col:
    li $t0,16
    srlv $t0,$t0,$t2
    and $t0,$t0,$s7
    beqz $t0,ui_text_skip
    move $t0,$t2
    move $t1,$s6
    bne $s4,2,ui_text_coords
    sll $t0,$t0,1
    sll $t1,$t1,1
ui_text_coords:
    addu $a0,$s1,$t0
    addu $a1,$s2,$t1
    move $a2,$s4
    move $a3,$s4
    move $v1,$s3
    jal ui_rect
ui_text_skip:
    addiu $t2,$t2,1
    blt $t2,5,ui_text_col
    addiu $s5,$s5,1
    addiu $s6,$s6,1
    blt $s6,7,ui_text_row
    li $t0,6
    bne $s4,2,ui_text_advance
    li $t0,12
ui_text_advance:
    addu $s1,$s1,$t0
    j ui_text_next
ui_text_newline:
    # Recover the caller's original x from its saved argument.
    lw $s1,4($sp)
    sll $t0,$s4,3
    addu $s2,$s2,$t0
    j ui_text_next
ui_text_return:
    lw $a0,0($sp)
    lw $a1,4($sp)
    lw $a2,8($sp)
    lw $a3,12($sp)
    lw $v1,16($sp)
    lw $s0,20($sp)
    lw $s1,24($sp)
    lw $s2,28($sp)
    lw $s3,32($sp)
    lw $s4,36($sp)
    lw $s5,40($sp)
    lw $s6,44($sp)
    lw $s7,48($sp)
    lw $t0,52($sp)
    lw $t1,56($sp)
    lw $t2,60($sp)
    lw $ra,64($sp)
    addiu $sp,$sp,68
    jr $ra

ui_number:
    addiu $sp,$sp,-32
    sw $a0,0($sp)
    sw $t0,4($sp)
    sw $t1,8($sp)
    sw $t2,12($sp)
    sw $t3,16($sp)
    sw $ra,20($sp)
    mfhi $t0
    sw $t0,24($sp)
    mflo $t0
    sw $t0,28($sp)
la $t1,ui_number_buf
    addiu $t1,$t1,15
    sb $zero,0($t1)
    move $t0,$a0
    slt $t3,$t0,$zero
    beqz $t3,ui_number_abs
    subu $t0,$zero,$t0
ui_number_abs:
    li $t2,10
ui_number_digit:
    divu $t0,$t2
    mfhi $t0
    addiu $t0,$t0,48
    addiu $t1,$t1,-1
    sb $t0,0($t1)
    mflo $t0
    bnez $t0,ui_number_digit
    beqz $t3,ui_number_draw
    addiu $t1,$t1,-1
    li $t0,45
    sb $t0,0($t1)
ui_number_draw:
    move $a0,$t1
    jal ui_text
ui_number_return:
    lw $t0,24($sp)
    mthi $t0
    lw $t0,28($sp)
    mtlo $t0
    lw $a0,0($sp)
    lw $t0,4($sp)
    lw $t1,8($sp)
    lw $t2,12($sp)
    lw $t3,16($sp)
    lw $ra,20($sp)
    addiu $sp,$sp,32
    jr $ra

ui_init:
    addiu $sp,$sp,-32
    sw $a0,0($sp)
    sw $a1,4($sp)
    sw $a2,8($sp)
    sw $a3,12($sp)
    sw $v1,16($sp)
    sw $t0,20($sp)
    sw $t1,24($sp)
    sw $ra,28($sp)
move $t1,$a0
    li $a0,0
    li $a1,0
    li $a2,256
    li $a3,256
    lw $v1,ui_bg
    jal ui_rect
    li $a3,34
    lw $v1,ui_panel
    jal ui_rect
    li $a1,32
    li $a3,2
    lw $v1,ui_accent
    jal ui_rect
    li $t0,2
    sw $t0,ui_scale
    move $a0,$t1
    li $a1,12
    li $a2,10
    li $a3,0xEAF1F7
    jal ui_text
    li $t0,1
    sw $t0,ui_scale
ui_init_return:
    lw $a0,0($sp)
    lw $a1,4($sp)
    lw $a2,8($sp)
    lw $a3,12($sp)
    lw $v1,16($sp)
    lw $t0,20($sp)
    lw $t1,24($sp)
    lw $ra,28($sp)
    addiu $sp,$sp,32
    jr $ra

ui_prompt:
    addiu $sp,$sp,-32
    sw $a0,0($sp)
    sw $a1,4($sp)
    sw $a2,8($sp)
    sw $a3,12($sp)
    sw $v1,16($sp)
    sw $t0,20($sp)
    sw $t1,24($sp)
    sw $ra,28($sp)
move $t1,$a0
    li $t0,1
    sw $t0,ui_scale
    li $a0,8
    li $a1,214
    li $a2,240
    li $a3,34
    lw $v1,ui_panel
    jal ui_rect
    move $a0,$t1
    li $a1,14
    li $a2,219
    li $a3,0xEAF1F7
    jal ui_text
ui_prompt_return:
    lw $a0,0($sp)
    lw $a1,4($sp)
    lw $a2,8($sp)
    lw $a3,12($sp)
    lw $v1,16($sp)
    lw $t0,20($sp)
    lw $t1,24($sp)
    lw $ra,28($sp)
    addiu $sp,$sp,32
    jr $ra

ui_getchar:
    addiu $sp,$sp,-8
    sw $t0,0($sp)
    sw $t1,4($sp)
li $t0,0xFFFF0000
ui_getchar_poll:
    lw $t1,0($t0)
    andi $t1,$t1,1
    beqz $t1,ui_getchar_poll
    lw $v0,4($t0)
    andi $v0,$v0,255
    # Ignore an LF immediately following CR (pasted CRLF input).
    lw $t1,ui_cr_pending
    sw $zero,ui_cr_pending
    beqz $t1,ui_getchar_check_cr
    beq $v0,10,ui_getchar_poll
ui_getchar_check_cr:
    bne $v0,13,ui_getchar_return
    li $t1,1
    sw $t1,ui_cr_pending
ui_getchar_return:
    lw $t0,0($sp)
    lw $t1,4($sp)
    addiu $sp,$sp,8
    jr $ra

ui_input_draw:
    addiu $sp,$sp,-24
    sw $a0,0($sp)
    sw $a1,4($sp)
    sw $a2,8($sp)
    sw $a3,12($sp)
    sw $v1,16($sp)
    sw $ra,20($sp)
li $a0,14
    li $a1,232
    li $a2,226
    li $a3,10
    lw $v1,ui_panel
    jal ui_rect
    la $a0,ui_input_buf
    li $a1,14
    li $a2,233
    lw $a3,ui_accent
    jal ui_text
ui_input_draw_return:
    lw $a0,0($sp)
    lw $a1,4($sp)
    lw $a2,8($sp)
    lw $a3,12($sp)
    lw $v1,16($sp)
    lw $ra,20($sp)
    addiu $sp,$sp,24
    jr $ra

ui_read_int:
    addiu $sp,$sp,-68
    sw $a0,0($sp)
    sw $a1,4($sp)
    sw $a2,8($sp)
    sw $a3,12($sp)
    sw $v1,16($sp)
    sw $s0,20($sp)
    sw $s1,24($sp)
    sw $s2,28($sp)
    sw $s3,32($sp)
    sw $s4,36($sp)
    sw $t0,40($sp)
    sw $t1,44($sp)
    sw $t2,48($sp)
    sw $t3,52($sp)
    sw $ra,56($sp)
    mfhi $t0
    sw $t0,60($sp)
    mflo $t0
    sw $t0,64($sp)
la $s0,ui_input_buf
    li $s1,0
    sw $zero,ui_overflow_count
    sb $zero,0($s0)
    jal ui_input_draw
ui_read_int_key:
    jal ui_getchar
    beq $v0,10,ui_read_int_parse
    beq $v0,13,ui_read_int_parse
    beq $v0,8,ui_read_int_backspace
    beq $v0,127,ui_read_int_backspace
    blt $v0,32,ui_read_int_key
    # Keep printable invalid characters so typos are editable and rejected,
    # rather than accidentally turning an invalid entry into a valid wager.
    bgt $v0,126,ui_read_int_key
    bge $s1,37,ui_read_int_full
    addu $t0,$s0,$s1
    sb $v0,0($t0)
    sb $zero,1($t0)
    addiu $s1,$s1,1
    jal ui_input_draw
    j ui_read_int_key
ui_read_int_full:
    lw $t0,ui_overflow_count
    addiu $t0,$t0,1
    sw $t0,ui_overflow_count
    # The final column becomes a warning marker for a full input field.
    li $t0,33
    sb $t0,ui_char_buf
    sb $zero,ui_char_buf+1
    la $a0,ui_char_buf
    li $a1,236
    li $a2,233
    li $a3,0xFF637D
    jal ui_text
    j ui_read_int_key
ui_read_int_backspace:
    lw $t0,ui_overflow_count
    beqz $t0,ui_read_int_erase
    addiu $t0,$t0,-1
    sw $t0,ui_overflow_count
    bnez $t0,ui_read_int_key
    jal ui_input_draw
    j ui_read_int_key
ui_read_int_erase:
    beqz $s1,ui_read_int_key
    addiu $s1,$s1,-1
    addu $t0,$s0,$s1
    sb $zero,0($t0)
    jal ui_input_draw
    j ui_read_int_key
ui_read_int_parse:
    lw $t0,ui_overflow_count
    bnez $t0,ui_read_int_invalid
    beqz $s1,ui_read_int_invalid
    move $s2,$s0
    li $s3,0
    li $s4,0
    lbu $t0,0($s2)
    beq $t0,45,ui_read_int_negative
    bne $t0,43,ui_read_int_digits
    addiu $s2,$s2,1
    j ui_read_int_digits
ui_read_int_negative:
    li $s4,1
    addiu $s2,$s2,1
ui_read_int_digits:
    lbu $t0,0($s2)
    beqz $t0,ui_read_int_invalid
ui_read_int_digit_loop:
    blt $t0,48,ui_read_int_invalid
    bgt $t0,57,ui_read_int_invalid
    addiu $t0,$t0,-48
    # Unsigned magnitude <=2147483648, allowing signed INT_MIN.
    li $t1,214748364
    bgtu $s3,$t1,ui_read_int_invalid
    bne $s3,$t1,ui_read_int_accumulate
    li $t1,7
    addu $t1,$t1,$s4
    bgtu $t0,$t1,ui_read_int_invalid
ui_read_int_accumulate:
    sll $t1,$s3,3
    sll $t2,$s3,1
    addu $s3,$t1,$t2
    addu $s3,$s3,$t0
    addiu $s2,$s2,1
    lbu $t0,0($s2)
    bnez $t0,ui_read_int_digit_loop
    move $v0,$s3
    beqz $s4,ui_read_int_return
    subu $v0,$zero,$v0
    j ui_read_int_return
ui_read_int_invalid:
    li $v0,0x80000000
ui_read_int_return:
    lw $t0,60($sp)
    mthi $t0
    lw $t0,64($sp)
    mtlo $t0
    lw $a0,0($sp)
    lw $a1,4($sp)
    lw $a2,8($sp)
    lw $a3,12($sp)
    lw $v1,16($sp)
    lw $s0,20($sp)
    lw $s1,24($sp)
    lw $s2,28($sp)
    lw $s3,32($sp)
    lw $s4,36($sp)
    lw $t0,40($sp)
    lw $t1,44($sp)
    lw $t2,48($sp)
    lw $t3,52($sp)
    lw $ra,56($sp)
    addiu $sp,$sp,68
    jr $ra

ui_wait_enter:
    addiu $sp,$sp,-8
    sw $v0,0($sp)
    sw $ra,4($sp)
ui_wait_enter_key:
    jal ui_getchar
    beq $v0,10,ui_wait_enter_return
    beq $v0,13,ui_wait_enter_return
    j ui_wait_enter_key
ui_wait_enter_return:
    lw $v0,0($sp)
    lw $ra,4($sp)
    addiu $sp,$sp,8
    jr $ra

ui_pause:
    addiu $sp,$sp,-4
    sw $v0,0($sp)
li $v0,32
    syscall
ui_pause_return:
    lw $v0,0($sp)
    addiu $sp,$sp,4
    jr $ra
