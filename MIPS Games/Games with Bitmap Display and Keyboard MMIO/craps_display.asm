# STOCK MARS 4.5 - NUMERIC CONTROLS WITH PLAY AGAIN
# Uses only the native Keyboard/Display MMIO Simulator and Bitmap Display.
# Buffered bitmap updates, bounded repaint bursts, and sleeping input polling.
# BITMAP SETTINGS: unit width/height 2, display width/height 512,
# base address 0x10010000 (static data); logical canvas 256 x 256.
# Assemble ONE game; open and connect BOTH tools BEFORE Run. Keyboard input
# goes in the MMIO tool's lower Keyboard area: type numbers, press Enter.
# Default memory configuration; delayed branching OFF; run at unlimited speed.
# Syscalls retained only for exit, random numbers, and optional pacing.
.data 0x10010000
.align 2
ui_framebuffer: .space 262144   # 256*256 RGB words; kept clear of game data.

# CRAPS - MARS bitmap display + Keyboard/Display MMIO input.
# Keep delayed branching disabled. The common renderer is appended below.
.eqv MIN_BET 1
.eqv MAX_BET 10000

.data
cr_title:       .asciiz "LUCKY SEVEN CRAPS"
cr_balance:     .asciiz "BALANCE $"
cr_bet:         .asciiz "BET $"
cr_rounds:      .asciiz "ROUNDS"
cr_point:       .asciiz "POINT"
cr_total:       .asciiz "TOTAL"
cr_unknown:     .asciiz "?"
cr_ready:       .asciiz "READY FOR THE COME-OUT ROLL"
cr_comeout:     .asciiz "COME-OUT ROLL"
cr_pointset:    .asciiz "POINT SET - ROLL TO HIT IT"
cr_natural:     .asciiz "NATURAL! YOU WIN"
cr_pointhit:    .asciiz "POINT HIT! YOU WIN"
cr_craps:       .asciiz "CRAPS! YOU LOSE"
cr_sevenout:    .asciiz "SEVEN OUT! YOU LOSE"
cr_won:         .asciiz "WON $"
cr_lost:        .asciiz "LOST $"
cr_lowered:     .asciiz "BET LOWERED TO YOUR BALANCE"
cr_newmenu:     .asciiz "1 PLAY ($10)  2 CHANGE BET  0 QUIT"
cr_menu:        .asciiz "1 PLAY AGAIN  2 CHANGE BET  0 QUIT"
cr_betprompt:   .asciiz "ENTER NEW BET ($1-$10000):"
cr_badprompt:   .asciiz "$1-$10000; CANNOT EXCEED BALANCE:"
cr_quitprompt:  .asciiz "GAME OVER - FINAL STATS ABOVE"
cr_brokeprompt: .asciiz "NEW GAME: $50. 1 PLAY, 0 QUIT; ENTER"
.align 2
cr_status:      .word cr_ready
cr_amountlabel: .word cr_won
cr_amount:      .word -1
cr_betlowered:  .word 0
cr_pointvalues: .word 4, 5, 6, 8, 9, 10

.text
.globl main
main:
gameStart:
    la $a0, cr_ready
    sw $a0, cr_status
    la $a0, cr_won
    sw $a0, cr_amountlabel
    li $a0, -1
    sw $a0, cr_amount
    sw $zero, cr_betlowered
    li $t8, 10                       # Original starting bet.
    li $t9, 50                       # Original starting balance.
    li $t5, 0                        # Rounds played.
    move $t1, $zero
    move $t2, $zero
    move $t3, $zero
    move $t4, $zero
    li $a0, 0x081C20
    sw $a0, ui_bg
    li $a0, 0x103F37
    sw $a0, ui_panel
    li $a0, 0xF5CB69
    sw $a0, ui_accent
    la $a0, cr_title
    jal ui_init
    jal cr_render

newGameBet:
    la $a0, cr_newmenu
    jal ui_prompt
    jal ui_read_int
    beqz $v1, newGameBet
    beq $v0, 0, quit
    beq $v0, 1, gameLoop
    beq $v0, 2, setPlayerBet
    j newGameBet

gameLoop:
    addi $t5, $t5, 1
    move $t4, $zero                  # No point during a new come-out roll.
    move $t1, $zero
    move $t2, $zero
    move $t3, $zero
    sw $zero, cr_betlowered
    li $a0, -1
    sw $a0, cr_amount
    la $a0, cr_comeout
    sw $a0, cr_status
    la $a0, cr_comeout
    jal ui_prompt
    jal diceRoll
    beq $t3, 7, winLine
    beq $t3, 11, winLine
    beq $t3, 2, crapOut
    beq $t3, 3, crapOut
    beq $t3, 12, crapOut

    move $t4, $t3                    # Establish the original point.
    la $a0, cr_pointset
    sw $a0, cr_status
    jal cr_render
    la $a0, cr_pointset
    jal ui_prompt
pointRoll:
    jal diceRoll                    # Rolls remain automatic; no new input.
    beq $t3, 7, crapOut
    beq $t3, $t4, winPoint
    j pointRoll

diceRoll:
    addiu $sp, $sp, -4
    sw $ra, 0($sp)
    li $v0, 42
    li $a0, 0
    li $a1, 6
    syscall
    addi $a0, $a0, 1
    move $t1, $a0
    li $a0, 0
    syscall
    addi $a0, $a0, 1
    move $t2, $a0
    add $t3, $t1, $t2
    jal cr_render                   # Draw these actual dice, no extra RNG.
    li $a0, 650
    jal ui_pause
    lw $ra, 0($sp)
    addiu $sp, $sp, 4
    jr $ra

winLine:
    move $t0, $t8
    la $a0, cr_natural
    sw $a0, cr_status
    j payoutMessage

crapOut:
    sub $t9, $t9, $t8
    la $a0, cr_craps
    beq $t4, $zero, cr_loss_label_ready
    la $a0, cr_sevenout
cr_loss_label_ready:
    sw $a0, cr_status
    la $a0, cr_lost
    sw $a0, cr_amountlabel
    sw $t8, cr_amount
    j endRound

winPoint:
    la $a0, cr_pointhit
    sw $a0, cr_status
    beq $t4, 4, twoToOne
    beq $t4, 10, twoToOne
    beq $t4, 5, threeToTwo
    beq $t4, 9, threeToTwo
    beq $t4, 6, sixToFive
    beq $t4, 8, sixToFive
    j endRound

twoToOne:
    mul $t0, $t8, 2
    j payoutMessage
threeToTwo:
    mul $t0, $t8, 3
    div $t0, $t0, 2
    j payoutMessage
sixToFive:
    mul $t0, $t8, 6
    div $t0, $t0, 5
    j payoutMessage
payoutMessage:
    add $t9, $t9, $t0
    la $a0, cr_won
    sw $a0, cr_amountlabel
    sw $t0, cr_amount
    j endRound

endRound:
    blt $t9, MIN_BET, broke
    ble $t8, $t9, playAgain
    move $t8, $t9
    li $a0, 1
    sw $a0, cr_betlowered
playAgain:
    jal cr_render                   # Keep the last dice and result visible.
    la $a0, cr_menu
    jal ui_prompt
    jal ui_read_int
    beqz $v1, playAgain
    beq $v0, 0, quit
    beq $v0, 1, nextRound
    beq $v0, 2, setPlayerBet
    j playAgain
setPlayerBet:
    la $a0, cr_betprompt
    jal ui_prompt
cr_read_bet:
    jal ui_read_int
    beqz $v1, invalidBet
    move $t6, $v0
    bgt $t6, $t9, invalidBet
    blt $t6, MIN_BET, invalidBet
    bgt $t6, MAX_BET, invalidBet
    move $t8, $t6
    j nextRound                     # Changing bet starts a round, as before.
invalidBet:
    la $a0, cr_badprompt
    jal ui_prompt
    j cr_read_bet
nextRound:
    j gameLoop
broke:
    jal cr_render
cr_restart_menu:
    la $a0, cr_brokeprompt
    jal ui_prompt
    jal ui_read_int
    beqz $v1, cr_restart_menu
    beq $v0, 1, gameStart
    beqz $v0, quit
    j cr_restart_menu
quit:
    jal cr_render
    la $a0, cr_quitprompt
    jal ui_prompt
cr_exit:
    li $v0, 10
    syscall

# Refresh the play area. Preserve all caller registers used by this helper.
cr_render:
    addiu $sp, $sp, -40
    sw $ra, 0($sp)
    sw $a0, 4($sp)
    sw $a1, 8($sp)
    sw $a2, 12($sp)
    sw $a3, 16($sp)
    sw $v1, 20($sp)
    sw $s0, 24($sp)
    sw $s1, 28($sp)
    sw $s2, 32($sp)
    sw $s3, 36($sp)
    li $a0, 1
    sw $a0, ui_scale
    li $a0, 8
    li $a1, 40
    li $a2, 240
    li $a3, 168
    li $v1, 0x103F37
    jal ui_rect
    li $a0, 12
    li $a1, 65
    li $a2, 232
    li $a3, 1
    li $v1, 0x347060
    jal ui_rect

    la $a0, cr_balance
    li $a1, 14
    li $a2, 44
    li $a3, 0xAACDBB
    jal ui_text
    move $a0, $t9
    li $a1, 14
    li $a2, 55
    li $a3, 0xF5CB69
    jal ui_number
    la $a0, cr_bet
    li $a1, 108
    li $a2, 44
    li $a3, 0xAACDBB
    jal ui_text
    move $a0, $t8
    li $a1, 108
    li $a2, 55
    li $a3, 0xF4F1DF
    jal ui_number
    la $a0, cr_rounds
    li $a1, 183
    li $a2, 44
    li $a3, 0xAACDBB
    jal ui_text
    move $a0, $t5
    li $a1, 183
    li $a2, 55
    li $a3, 0xF4F1DF
    jal ui_number

    la $a0, cr_point
    li $a1, 14
    li $a2, 77
    li $a3, 0xF5CB69
    jal ui_text
    la $s0, cr_pointvalues
    li $s1, 57
    li $s2, 6
cr_point_box_loop:
    lw $s3, 0($s0)
    move $a0, $s1
    li $a1, 70
    li $a2, 28
    li $a3, 20
    li $v1, 0x1C5549
    bne $s3, $t4, cr_point_box_color
    li $v1, 0xF5CB69
cr_point_box_color:
    jal ui_rect
    move $a0, $s3
    addiu $a1, $s1, 11
    blt $s3, 10, cr_point_text_pos
    addiu $a1, $s1, 8
cr_point_text_pos:
    li $a2, 77
    li $a3, 0xAACDBB
    bne $s3, $t4, cr_point_text_color
    li $a3, 0x102921
cr_point_text_color:
    jal ui_number
    addiu $s0, $s0, 4
    addiu $s1, $s1, 31
    addiu $s2, $s2, -1
    bgtz $s2, cr_point_box_loop

    li $a0, 65
    li $a1, 101
    move $a2, $t1
    jal cr_draw_die
    li $a0, 139
    li $a1, 101
    move $a2, $t2
    jal cr_draw_die
    la $a0, cr_total
    li $a1, 83
    li $a2, 160
    li $a3, 0xAACDBB
    jal ui_text
    li $a0, 2
    sw $a0, ui_scale
    move $a0, $t3
    li $a1, 124
    li $a2, 155
    li $a3, 0xF5CB69
    jal ui_number
    li $a0, 1
    sw $a0, ui_scale
    lw $a0, cr_status
    li $a1, 14
    li $a2, 179
    li $a3, 0xF4F1DF
    jal ui_text
    lw $a0, cr_amount
    bltz $a0, cr_render_lowered
    lw $a0, cr_amountlabel
    li $a1, 14
    li $a2, 190
    li $a3, 0xF5CB69
    jal ui_text
    lw $a0, cr_amount
    li $a1, 56
    li $a2, 190
    li $a3, 0xF5CB69
    jal ui_number
cr_render_lowered:
    lw $a0, cr_betlowered
    beqz $a0, cr_render_done
    la $a0, cr_lowered
    li $a1, 14
    li $a2, 201
    li $a3, 0xFFB394
    jal ui_text
cr_render_done:
    lw $ra, 0($sp)
    lw $a0, 4($sp)
    lw $a1, 8($sp)
    lw $a2, 12($sp)
    lw $a3, 16($sp)
    lw $v1, 20($sp)
    lw $s0, 24($sp)
    lw $s1, 28($sp)
    lw $s2, 32($sp)
    lw $s3, 36($sp)
    addiu $sp, $sp, 40
    jr $ra

# a0=x, a1=y, a2=the actual die value (0 displays an unrolled die).
cr_draw_die:
    addiu $sp, $sp, -36
    sw $ra, 0($sp)
    sw $a0, 4($sp)
    sw $a1, 8($sp)
    sw $a2, 12($sp)
    sw $a3, 16($sp)
    sw $v1, 20($sp)
    sw $s0, 24($sp)
    sw $s1, 28($sp)
    sw $s2, 32($sp)
    move $s0, $a0
    move $s1, $a1
    move $s2, $a2
    addiu $a0, $s0, 3
    addiu $a1, $s1, 4
    li $a2, 48
    li $a3, 48
    li $v1, 0x08291F
    jal ui_rect
    move $a0, $s0
    move $a1, $s1
    li $a2, 48
    li $a3, 48
    li $v1, 0xD8CDB2
    jal ui_rect
    addiu $a0, $s0, 2
    addiu $a1, $s1, 2
    li $a2, 44
    li $a3, 44
    li $v1, 0xFFF9E8
    jal ui_rect
    beqz $s2, cr_die_unknown
    beq $s2, 1, cr_die_center
    # Every value >= 2 has the top-left and bottom-right pips.
    addiu $a0, $s0, 9
    addiu $a1, $s1, 9
    jal cr_pip
    addiu $a0, $s0, 33
    addiu $a1, $s1, 33
    jal cr_pip
    beq $s2, 2, cr_die_done
    beq $s2, 3, cr_die_center
    # Four corner pips for 4, 5 and 6.
    addiu $a0, $s0, 33
    addiu $a1, $s1, 9
    jal cr_pip
    addiu $a0, $s0, 9
    addiu $a1, $s1, 33
    jal cr_pip
    beq $s2, 4, cr_die_done
    beq $s2, 5, cr_die_center
    # The two middle side pips make six.
    addiu $a0, $s0, 9
    addiu $a1, $s1, 21
    jal cr_pip
    addiu $a0, $s0, 33
    addiu $a1, $s1, 21
    jal cr_pip
    j cr_die_done
cr_die_center:
    addiu $a0, $s0, 21
    addiu $a1, $s1, 21
    jal cr_pip
    j cr_die_done
cr_die_unknown:
    la $a0, cr_unknown
    addiu $a1, $s0, 21
    addiu $a2, $s1, 21
    li $a3, 0xA99C7F
    jal ui_text
cr_die_done:
    lw $ra, 0($sp)
    lw $a0, 4($sp)
    lw $a1, 8($sp)
    lw $a2, 12($sp)
    lw $a3, 16($sp)
    lw $v1, 20($sp)
    lw $s0, 24($sp)
    lw $s1, 28($sp)
    lw $s2, 32($sp)
    addiu $sp, $sp, 36
    jr $ra
cr_pip:
    li $a2, 6
    li $a3, 6
    li $v1, 0xA72937
    j ui_rect


# Shared bitmap renderer and MMIO keyboard driver.
# Every public UI routine preserves the game's register state, including HI/LO.
# ui_read_int returns value in $v0, success 1/0 in $v1. Invalid text returns 0/0.
# All other public UI register-preservation contracts are unchanged.
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
# Drawing happens offscreen. Only ui_present touches watched bitmap memory.
# Separate shadow avoids even READ notifications from the Bitmap tool.
.align 2
ui_canvas: .space 262144
ui_shadow: .space 262144
ui_dirty_rows: .space 1024
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
    addiu $sp,$sp,-36
    sw $t0,0($sp)
    sw $t1,4($sp)
    sw $t2,8($sp)
    sw $t3,12($sp)
    sw $t4,16($sp)
    sw $t5,20($sp)
    sw $t6,24($sp)
    sw $t7,28($sp)
    sw $t8,32($sp)
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
    la $t5,ui_canvas
    addu $t4,$t4,$t5
    subu $t6,$t2,$t0
ui_rect_row:
    # A row is dirty even if the final composited pixels match the old frame.
    la $t8,ui_dirty_rows
    sll $t5,$t1,2
    addu $t8,$t8,$t5
    li $t5,1
    sw $t5,0($t8)
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
    lw $t8,32($sp)
    addiu $sp,$sp,36
    jr $ra

ui_present:
    addiu $sp,$sp,-48
    sw $t0,0($sp)
    sw $t1,4($sp)
    sw $t2,8($sp)
    sw $t3,12($sp)
    sw $t4,16($sp)
    sw $t5,20($sp)
    sw $t6,24($sp)
    sw $t7,28($sp)
    sw $t8,32($sp)
    sw $t9,36($sp)
    sw $a0,40($sp)
    sw $v0,44($sp)
la $t0,ui_canvas
    la $t1,ui_shadow
    li $t2,0x10010000
    la $t3,ui_dirty_rows
    li $t4,256
    li $t8,0
ui_present_row:
    lw $t9,0($t3)
    beqz $t9,ui_present_skip_row
    sw $zero,0($t3)
    li $t5,256
ui_present_pixel:
    lw $t6,0($t0)
    lw $t7,0($t1)
    beq $t6,$t7,ui_present_next_pixel
    sw $t6,0($t1)
    sw $t6,0($t2)
    addiu $t8,$t8,1
    # Bound the repaint burst; let Swing service pending paint events.
    blt $t8,512,ui_present_next_pixel
    li $t8,0
    li $v0,32
    li $a0,1
    syscall
ui_present_next_pixel:
    addiu $t0,$t0,4
    addiu $t1,$t1,4
    addiu $t2,$t2,4
    addiu $t5,$t5,-1
    bgtz $t5,ui_present_pixel
    j ui_present_next_row
ui_present_skip_row:
    addiu $t0,$t0,1024
    addiu $t1,$t1,1024
    addiu $t2,$t2,1024
ui_present_next_row:
    addiu $t3,$t3,4
    addiu $t4,$t4,-1
    bgtz $t4,ui_present_row
ui_present_return:
    lw $t0,0($sp)
    lw $t1,4($sp)
    lw $t2,8($sp)
    lw $t3,12($sp)
    lw $t4,16($sp)
    lw $t5,20($sp)
    lw $t6,24($sp)
    lw $t7,28($sp)
    lw $t8,32($sp)
    lw $t9,36($sp)
    lw $a0,40($sp)
    lw $v0,44($sp)
    addiu $sp,$sp,48
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
    jal ui_present
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
    addiu $sp,$sp,-16
    sw $t0,0($sp)
    sw $t1,4($sp)
    sw $a0,8($sp)
    sw $ra,12($sp)
jal ui_present
    li $t0,0xFFFF0000
ui_getchar_poll:
    lw $t1,0($t0)
    andi $t1,$t1,1
    bnez $t1,ui_getchar_ready
    # Do not spin at full speed while the user is idle.
    li $v0,32
    li $a0,10
    syscall
    j ui_getchar_poll
ui_getchar_ready:
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
    lw $a0,8($sp)
    lw $ra,12($sp)
    addiu $sp,$sp,16
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
    li $v1,1
    beqz $s4,ui_read_int_return
    subu $v0,$zero,$v0
    j ui_read_int_return
ui_read_int_invalid:
    move $v0,$zero
    move $v1,$zero
ui_read_int_return:
    lw $t0,60($sp)
    mthi $t0
    lw $t0,64($sp)
    mtlo $t0
    lw $a0,0($sp)
    lw $a1,4($sp)
    lw $a2,8($sp)
    lw $a3,12($sp)
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
    addiu $sp,$sp,-8
    sw $v0,0($sp)
    sw $ra,4($sp)
jal ui_present
    li $v0,32
    syscall
ui_pause_return:
    lw $v0,0($sp)
    lw $ra,4($sp)
    addiu $sp,$sp,8
    jr $ra
