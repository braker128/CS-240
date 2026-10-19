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

# Blackjack for MARS Bitmap Display + Keyboard and Display MMIO Simulator.
# Original game rules, draw distribution, ace handling and payouts are retained.
# Renderer is appended to make this file standalone. Delayed branching: OFF.
.eqv STARTING_BALANCE 50
.eqv MIN_BET 10
.eqv MAX_BET 1000

.data
bj_title: .asciiz "BLACKJACK"
invalidBetMsg: .asciiz "INVALID BET. CHECK BANK AND LIMITS."
balanceMsg: .asciiz "BANK $"
bj_betLabel: .asciiz "BET $"
betMsg: .asciiz "BET $10-$1000 (UP TO YOUR BANK):"
hitStandMsg: .asciiz "HIT [1] OR STAND [0], THEN ENTER:"
standMsg: .asciiz "YOU STAND. DEALER PLAYS."
blackjackMsg: .asciiz "BLACKJACK! YOU WIN 3:2!"
winMsg: .asciiz "YOU WIN!"
dealerBustMsg: .asciiz "DEALER BUSTS! YOU WIN!"
loseMsg: .asciiz "DEALER WINS. YOU LOSE."
bustMsg: .asciiz "YOU BUST! YOU LOSE."
tieMsg: .asciiz "PUSH. YOUR BET IS RETURNED."
gameOverMsg: .asciiz "GAME OVER. BANK BELOW $10."
bj_nextPrompt: .asciiz "NEXT HAND? 1 PLAY, 0 QUIT; ENTER"
bj_overPrompt: .asciiz "NEW GAME: $50. 1 PLAY, 0 QUIT; ENTER"
bj_quitPrompt: .asciiz "GAME OVER. THANKS FOR PLAYING."
bj_badMove: .asciiz "ENTER 1 TO HIT OR 0 TO STAND."
bj_dealerLabel: .asciiz "DEALER"
bj_playerLabel: .asciiz "PLAYER"
bj_totalLabel: .asciiz "TOTAL"
bj_showLabel: .asciiz "SHOW"
bj_softLabel: .asciiz "SOFT ACES"
bj_empty: .asciiz ""
bj_question: .asciiz "?"
bj_rankA: .asciiz "A"
bj_rank2: .asciiz "2"
bj_rank3: .asciiz "3"
bj_rank4: .asciiz "4"
bj_rank5: .asciiz "5"
bj_rank6: .asciiz "6"
bj_rank7: .asciiz "7"
bj_rank8: .asciiz "8"
bj_rank9: .asciiz "9"
bj_rank10: .asciiz "10"
bj_rankJ: .asciiz "J"
bj_rankQ: .asciiz "Q"
bj_rankK: .asciiz "K"
.align 2
bj_rankTable: .word bj_rankA,bj_rank2,bj_rank3,bj_rank4,bj_rank5,bj_rank6,bj_rank7,bj_rank8,bj_rank9,bj_rank10,bj_rankJ,bj_rankQ,bj_rankK
bj_lastRank: .word 0
bj_playerCount: .word 0
bj_dealerCount: .word 0
bj_playerCards: .space 128
bj_dealerCards: .space 128
bj_status: .word bj_empty
bj_statusColor: .word 0x00EECB77

.text
.globl main
main:
gameStart:
li $t8, 0x0008291F
sw $t8, ui_bg
li $t8, 0x00104336
sw $t8, ui_panel
li $t8, 0x00EECB77
sw $t8, ui_accent
la $a0, bj_title
jal ui_init
li $s1, STARTING_BALANCE
j newHand

newHand:
jal resetRoundRegisters
jal bj_render_scene
blt $s1, MIN_BET, gameOver
jal placeBet
jal dealPlayer
jal dealDealer
jal dealPlayer
jal dealDealer
jal calcDealerHandHidden
# The same natural-blackjack precedence as the original game.
bne $s2, 21, checkPlayerBlackjack
bne $t1, 21, checkPlayerBlackjack
jal revealDealerCard
jal calcDealerHand
j tie

checkPlayerBlackjack:
bne $s2, 21, checkDealerBlackjack
jal revealDealerCard
jal calcDealerHand
j blackjackWin

checkDealerBlackjack:
bne $t1, 21, playerTurn
jal revealDealerCard
jal calcDealerHand
j dealerWin

placeBet:
addiu $sp, $sp, -8
sw $ra, 0($sp)
bj_betAgain:
la $a0, betMsg
jal ui_prompt
jal ui_read_int
# A rejected entry must not replace the current stake or change the bank.
beqz $v1, invalidBet
blt $v0, MIN_BET, invalidBet
bgt $v0, MAX_BET, invalidBet
bgt $v0, $s1, invalidBet
move $s0, $v0
sub $s1, $s1, $s0
la $t8, bj_empty
sw $t8, bj_status
jal bj_render_scene
lw $ra, 0($sp)
addiu $sp, $sp, 8
jr $ra

invalidBet:
la $t8, invalidBetMsg
sw $t8, bj_status
li $t8, 0x00FF7E86
sw $t8, bj_statusColor
jal bj_render_scene
j bj_betAgain

resetRoundRegisters:
li $s0, 0
# $s1 is the remaining bank and is deliberately not reset.
li $s2, 0
li $s3, 0
li $s4, 0
li $s5, 0
li $s6, 0
li $s7, 0
li $t0, 0
li $t1, 0
li $t2, 0
li $t3, 0
li $t4, 0
li $t5, 0
li $t6, 0
li $t7, 0
sw $zero, bj_playerCount
sw $zero, bj_dealerCount
la $t8, bj_empty
sw $t8, bj_status
li $t8, 0x00EECB77
sw $t8, bj_statusColor
jr $ra

playerTurn:
jal printDealer
bgt $s2, 21, playerBust
beq $s2, 21, stand
la $a0, hitStandMsg
jal ui_prompt
jal ui_read_int
beqz $v1, playerTurn
move $t3, $v0
beqz $t3, stand
beq $t3, 1, playerHit
la $t8, bj_badMove
sw $t8, bj_status
li $t8, 0x00FF7E86
sw $t8, bj_statusColor
j playerTurn

playerHit:
la $t8, bj_empty
sw $t8, bj_status
jal dealPlayer
j playerTurn

dealPlayer:
move $s7, $ra
jal hit
# Cosmetic card tracking reuses the original random result, without a new draw.
lw $t8, bj_playerCount
sll $t9, $t8, 2
la $a0, bj_playerCards
addu $a0, $a0, $t9
lw $a1, bj_lastRank
sw $a1, 0($a0)
addiu $t8, $t8, 1
sw $t8, bj_playerCount
bne $t0, 11, playerNotAce
addi $s4, $s4, 1
playerNotAce:
add $s2, $s2, $t0
jal calcPlayerHand
move $ra, $s7
jr $ra

dealDealer:
move $s7, $ra
jal hit
lw $t8, bj_dealerCount
sll $t9, $t8, 2
la $a0, bj_dealerCards
addu $a0, $a0, $t9
lw $a1, bj_lastRank
sw $a1, 0($a0)
addiu $t8, $t8, 1
sw $t8, bj_dealerCount
beqz $s6, dealDownCard
bne $t0, 11, dealerNotAce
addi $s5, $s5, 1
dealerNotAce:
add $s3, $s3, $t0
jal calcDealerHand
j dealDealerDone
dealDownCard:
move $s6, $t0
dealDealerDone:
move $ra, $s7
jr $ra

revealDealerCard:
beq $s6, -1, revealDone
bne $s6, 11, revealNotAce
addi $s5, $s5, 1
revealNotAce:
add $s3, $s3, $s6
li $s6, -1
revealDone:
jr $ra

dealerTurn:
jal printDealer
bge $s3, 17, dealerDone
# A short visual beat lets each dealer draw remain visible.
li $a0, 250
jal ui_pause
jal dealDealer
j dealerTurn

dealerDone:
bgt $s3, 21, dealerBust
bgt $s3, $s2, dealerWin
bgt $s2, $s3, playerWin
j tie

dealerWin:
la $t8, loseMsg
j bj_finish

dealerBust:
mul $t0, $s0, 2
add $s1, $s1, $t0
la $t8, dealerBustMsg
j bj_finish

playerWin:
mul $t0, $s0, 2
add $s1, $s1, $t0
la $t8, winMsg
j bj_finish

playerBust:
la $t8, bustMsg
j bj_finish

blackjackWin:
mul $t0, $s0, 5
div $t0, $t0, 2
add $s1, $s1, $t0
la $t8, blackjackMsg
j bj_finish

tie:
add $s1, $s1, $s0
la $t8, tieMsg
j bj_finish

bj_finish:
sw $t8, bj_status
li $t8, 0x00EECB77
sw $t8, bj_statusColor
jal bj_render_scene
blt $s1, MIN_BET, gameOver
bj_play_again:
la $a0, bj_nextPrompt
jal ui_prompt
jal ui_read_int
beqz $v1, bj_play_again
beq $v0, 1, newHand
beqz $v0, bj_quit
j bj_play_again

stand:
la $t8, standMsg
sw $t8, bj_status
li $t8, 0x00EECB77
sw $t8, bj_statusColor
jal revealDealerCard
jal calcDealerHand
j dealerTurn

hit:
li $v0, 42
li $a0, 0
li $a1, 13
syscall
addi $t0, $a0, 1
# Keep the rank before the original rank-to-value conversion.
sw $t0, bj_lastRank
beq $t0, 1, hitAce
ble $t0, 10, hitDone
li $t0, 10
j hitDone
hitAce:
li $t0, 11
hitDone:
jr $ra

calcDealerHand:
ble $s3, 21, cDHDone
beqz $s5, cDHDone
sub $s3, $s3, 10
sub $s5, $s5, 1
j calcDealerHand
cDHDone:
jr $ra

calcDealerHandHidden:
move $t1, $s3
move $t2, $s5
add $t1, $t1, $s6
bne $s6, 11, cDHHLoop
addi $t2, $t2, 1
cDHHLoop:
ble $t1, 21, cDHHDone
beqz $t2, cDHHDone
sub $t1, $t1, 10
sub $t2, $t2, 1
j cDHHLoop
cDHHDone:
jr $ra

calcPlayerHand:
ble $s2, 21, cPHDone
beqz $s4, cPHDone
sub $s2, $s2, 10
sub $s4, $s4, 1
j calcPlayerHand
cPHDone:
jr $ra

# A single complete scene draws both hands together in the bitmap.
printDealer:
printPlayer:
j bj_render_scene

gameOver:
la $t8, gameOverMsg
sw $t8, bj_status
jal bj_render_scene
bj_restart_menu:
la $a0, bj_overPrompt
jal ui_prompt
jal ui_read_int
beqz $v1, bj_restart_menu
beq $v0, 1, gameStart
beqz $v0, bj_quit
j bj_restart_menu
bj_quit:
la $a0, bj_quitPrompt
jal ui_prompt
li $v0, 10
syscall

# All bj_draw_* routines preserve game registers and HI/LO, including nested calls.
bj_render_scene:
addiu $sp, $sp, -80
sw $ra, 0($sp)
sw $t0, 4($sp)
sw $t1, 8($sp)
sw $t2, 12($sp)
sw $t3, 16($sp)
sw $t4, 20($sp)
sw $t5, 24($sp)
sw $t6, 28($sp)
sw $t7, 32($sp)
sw $t8, 36($sp)
sw $t9, 40($sp)
sw $a0, 44($sp)
sw $a1, 48($sp)
sw $a2, 52($sp)
sw $a3, 56($sp)
sw $v0, 60($sp)
sw $v1, 64($sp)
mfhi $t0
sw $t0, 68($sp)
mflo $t0
sw $t0, 72($sp)

li $t0, 1
sw $t0, ui_scale
li $a0, 8
li $a1, 38
li $a2, 240
li $a3, 171
li $v1, 0x0008291F
jal ui_rect
la $a0, balanceMsg
li $a1, 12
li $a2, 42
li $a3, 0x00EECB77
jal ui_text
move $a0, $s1
li $a1, 50
li $a2, 42
li $a3, 0x00FFFFFF
jal ui_number
la $a0, bj_betLabel
li $a1, 148
li $a2, 42
li $a3, 0x00EECB77
jal ui_text
move $a0, $s0
li $a1, 184
li $a2, 42
li $a3, 0x00FFFFFF
jal ui_number
li $a0, 12
li $a1, 53
li $a2, 232
li $a3, 1
li $v1, 0x003F6554
jal ui_rect
li $a1, 124
jal ui_rect
li $a1, 196
jal ui_rect
la $a0, bj_dealerLabel
li $a1, 12
li $a2, 60
li $a3, 0x00EECB77
jal ui_text
la $a0, bj_showLabel
bne $s6, -1, bj_dealerTotalLabelReady
la $a0, bj_totalLabel
bj_dealerTotalLabelReady:
li $a1, 80
li $a2, 60
li $a3, 0x00C7D9CE
jal ui_text
move $a0, $s3
li $a1, 116
li $a2, 60
li $a3, 0x00FFFFFF
jal ui_number
beqz $s5, bj_noDealerSoft
la $a0, bj_softLabel
li $a1, 151
li $a2, 60
li $a3, 0x00C7D9CE
jal ui_text
move $a0, $s5
li $a1, 211
li $a2, 60
li $a3, 0x00FFFFFF
jal ui_number
bj_noDealerSoft:
la $a0, bj_dealerCards
lw $a1, bj_dealerCount
li $a2, 73
li $a3, 1
bne $s6, -1, bj_drawDealerCards
li $a3, 0
bj_drawDealerCards:
jal bj_draw_hand
la $a0, bj_playerLabel
li $a1, 12
li $a2, 132
li $a3, 0x00EECB77
jal ui_text
la $a0, bj_totalLabel
li $a1, 80
li $a2, 132
li $a3, 0x00C7D9CE
jal ui_text
move $a0, $s2
li $a1, 116
li $a2, 132
li $a3, 0x00FFFFFF
jal ui_number
beqz $s4, bj_noPlayerSoft
la $a0, bj_softLabel
li $a1, 151
li $a2, 132
li $a3, 0x00C7D9CE
jal ui_text
move $a0, $s4
li $a1, 211
li $a2, 132
li $a3, 0x00FFFFFF
jal ui_number
bj_noPlayerSoft:
la $a0, bj_playerCards
lw $a1, bj_playerCount
li $a2, 145
li $a3, 0
jal bj_draw_hand
lw $a0, bj_status
li $a1, 12
li $a2, 200
lw $a3, bj_statusColor
jal ui_text
lw $t0, 68($sp)
mthi $t0
lw $t0, 72($sp)
mtlo $t0
lw $v1, 64($sp)
lw $v0, 60($sp)
lw $a3, 56($sp)
lw $a2, 52($sp)
lw $a1, 48($sp)
lw $a0, 44($sp)
lw $t9, 40($sp)
lw $t8, 36($sp)
lw $t7, 32($sp)
lw $t6, 28($sp)
lw $t5, 24($sp)
lw $t4, 20($sp)
lw $t3, 16($sp)
lw $t2, 12($sp)
lw $t1, 8($sp)
lw $t0, 4($sp)
lw $ra, 0($sp)
addiu $sp, $sp, 80
jr $ra


# a0=rank array, a1=count, a2=first row y, a3=hide first card.
# Two rows of eleven cards hold every legal hand, including 21 aces.
bj_draw_hand:
addiu $sp, $sp, -80
sw $ra, 0($sp)
sw $t0, 4($sp)
sw $t1, 8($sp)
sw $t2, 12($sp)
sw $t3, 16($sp)
sw $t4, 20($sp)
sw $t5, 24($sp)
sw $t6, 28($sp)
sw $t7, 32($sp)
sw $t8, 36($sp)
sw $t9, 40($sp)
sw $a0, 44($sp)
sw $a1, 48($sp)
sw $a2, 52($sp)
sw $a3, 56($sp)
sw $v0, 60($sp)
sw $v1, 64($sp)
mfhi $t0
sw $t0, 68($sp)
mflo $t0
sw $t0, 72($sp)

move $t0, $a0
move $t1, $a1
move $t2, $a2
move $t3, $a3
li $t4, 0
bj_handLoop:
bge $t4, $t1, bj_handDone
li $t9, 11
divu $t4, $t9
mfhi $t5
mflo $t6
mul $t5, $t5, 21
addiu $a0, $t5, 12
mul $t6, $t6, 25
addu $a1, $t2, $t6
sll $t7, $t4, 2
addu $t7, $t0, $t7
lw $a2, 0($t7)
li $a3, 0
bnez $t4, bj_handCardVisible
move $a3, $t3
bj_handCardVisible:
# Cosmetic suits cycle by rank and card position; no random calls added.
addu $v0, $a2, $t4
andi $v0, $v0, 3
jal bj_draw_card
addiu $t4, $t4, 1
j bj_handLoop
bj_handDone:
lw $t0, 68($sp)
mthi $t0
lw $t0, 72($sp)
mtlo $t0
lw $v1, 64($sp)
lw $v0, 60($sp)
lw $a3, 56($sp)
lw $a2, 52($sp)
lw $a1, 48($sp)
lw $a0, 44($sp)
lw $t9, 40($sp)
lw $t8, 36($sp)
lw $t7, 32($sp)
lw $t6, 28($sp)
lw $t5, 24($sp)
lw $t4, 20($sp)
lw $t3, 16($sp)
lw $t2, 12($sp)
lw $t1, 8($sp)
lw $t0, 4($sp)
lw $ra, 0($sp)
addiu $sp, $sp, 80
jr $ra


# a0=x, a1=y, a2=rank1..13, a3=hidden, v0=cosmetic suit0..3.
bj_draw_card:
addiu $sp, $sp, -80
sw $ra, 0($sp)
sw $t0, 4($sp)
sw $t1, 8($sp)
sw $t2, 12($sp)
sw $t3, 16($sp)
sw $t4, 20($sp)
sw $t5, 24($sp)
sw $t6, 28($sp)
sw $t7, 32($sp)
sw $t8, 36($sp)
sw $t9, 40($sp)
sw $a0, 44($sp)
sw $a1, 48($sp)
sw $a2, 52($sp)
sw $a3, 56($sp)
sw $v0, 60($sp)
sw $v1, 64($sp)
mfhi $t0
sw $t0, 68($sp)
mflo $t0
sw $t0, 72($sp)

move $t0, $a0
move $t1, $a1
move $t2, $a2
move $t3, $a3
move $t4, $v0
li $a2, 18
li $a3, 22
li $v1, 0x00EECB77
jal ui_rect
addiu $a0, $t0, 1
addiu $a1, $t1, 1
li $a2, 16
li $a3, 20
li $v1, 0x00F3F0DF
beqz $t3, bj_cardFaceBackground
li $v1, 0x00193567
bj_cardFaceBackground:
jal ui_rect
beqz $t3, bj_cardFace
# Blue back and fine gold inset keep the dealer's hole rank secret.
addiu $a0, $t0, 3
addiu $a1, $t1, 3
li $a2, 12
li $a3, 16
li $v1, 0x003D669C
jal ui_rect
addiu $a0, $t0, 4
addiu $a1, $t1, 4
li $a2, 10
li $a3, 14
li $v1, 0x00193567
jal ui_rect
la $a0, bj_question
addiu $a1, $t0, 6
addiu $a2, $t1, 7
li $a3, 0x00EECB77
jal ui_text
j bj_cardDone
bj_cardFace:
li $t5, 0x001F2934
andi $t6, $t4, 1
beqz $t6, bj_cardColorReady
li $t5, 0x00B82E48
bj_cardColorReady:
addiu $t6, $t2, -1
sll $t6, $t6, 2
la $t7, bj_rankTable
addu $t7, $t7, $t6
lw $a0, 0($t7)
addiu $a1, $t0, 2
addiu $a2, $t1, 2
move $a3, $t5
jal ui_text
addiu $a0, $t0, 6
addiu $a1, $t1, 12
move $a2, $t4
move $a3, $t5
jal bj_draw_suit
bj_cardDone:
lw $t0, 68($sp)
mthi $t0
lw $t0, 72($sp)
mtlo $t0
lw $v1, 64($sp)
lw $v0, 60($sp)
lw $a3, 56($sp)
lw $a2, 52($sp)
lw $a1, 48($sp)
lw $a0, 44($sp)
lw $t9, 40($sp)
lw $t8, 36($sp)
lw $t7, 32($sp)
lw $t6, 28($sp)
lw $t5, 24($sp)
lw $t4, 20($sp)
lw $t3, 16($sp)
lw $t2, 12($sp)
lw $t1, 8($sp)
lw $t0, 4($sp)
lw $ra, 0($sp)
addiu $sp, $sp, 80
jr $ra


# Pixel suits: spade0, heart1, club2, diamond3, in a 5x7 area.
bj_draw_suit:
addiu $sp, $sp, -80
sw $ra, 0($sp)
sw $t0, 4($sp)
sw $t1, 8($sp)
sw $t2, 12($sp)
sw $t3, 16($sp)
sw $t4, 20($sp)
sw $t5, 24($sp)
sw $t6, 28($sp)
sw $t7, 32($sp)
sw $t8, 36($sp)
sw $t9, 40($sp)
sw $a0, 44($sp)
sw $a1, 48($sp)
sw $a2, 52($sp)
sw $a3, 56($sp)
sw $v0, 60($sp)
sw $v1, 64($sp)
mfhi $t0
sw $t0, 68($sp)
mflo $t0
sw $t0, 72($sp)

move $t0, $a0
move $t1, $a1
move $t2, $a2
move $t3, $a3
move $v1, $t3
beq $t2, 1, bj_suitHeart
beq $t2, 2, bj_suitClub
# Diamond and spade share a pointed top.
addiu $a0, $t0, 2
move $a1, $t1
li $a2, 1
li $a3, 1
jal ui_rect
addiu $a0, $t0, 1
addiu $a1, $t1, 1
li $a2, 3
jal ui_rect
move $a0, $t0
addiu $a1, $t1, 2
li $a2, 5
jal ui_rect
addiu $a0, $t0, 1
addiu $a1, $t1, 3
li $a2, 3
jal ui_rect
addiu $a0, $t0, 2
addiu $a1, $t1, 4
li $a2, 1
jal ui_rect
beq $t2, 3, bj_suitDone
j bj_suitStem
bj_suitHeart:
move $a0, $t0
move $a1, $t1
li $a2, 2
li $a3, 2
jal ui_rect
addiu $a0, $t0, 3
jal ui_rect
move $a0, $t0
addiu $a1, $t1, 2
li $a2, 5
li $a3, 1
jal ui_rect
addiu $a0, $t0, 1
addiu $a1, $t1, 3
li $a2, 3
jal ui_rect
addiu $a0, $t0, 2
addiu $a1, $t1, 4
li $a2, 1
jal ui_rect
j bj_suitDone
bj_suitClub:
addiu $a0, $t0, 2
move $a1, $t1
li $a2, 2
li $a3, 2
jal ui_rect
move $a0, $t0
addiu $a1, $t1, 2
jal ui_rect
addiu $a0, $t0, 3
jal ui_rect
addiu $a0, $t0, 2
addiu $a1, $t1, 3
li $a2, 1
li $a3, 2
jal ui_rect
bj_suitStem:
addiu $a0, $t0, 2
addiu $a1, $t1, 5
li $a2, 1
li $a3, 1
jal ui_rect
addiu $a0, $t0, 1
addiu $a1, $t1, 6
li $a2, 3
jal ui_rect
bj_suitDone:
lw $t0, 68($sp)
mthi $t0
lw $t0, 72($sp)
mtlo $t0
lw $v1, 64($sp)
lw $v0, 60($sp)
lw $a3, 56($sp)
lw $a2, 52($sp)
lw $a1, 48($sp)
lw $a0, 44($sp)
lw $t9, 40($sp)
lw $t8, 36($sp)
lw $t7, 32($sp)
lw $t6, 28($sp)
lw $t5, 24($sp)
lw $t4, 20($sp)
lw $t3, 16($sp)
lw $t2, 12($sp)
lw $t1, 8($sp)
lw $t0, 4($sp)
lw $ra, 0($sp)
addiu $sp, $sp, 80
jr $ra



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
