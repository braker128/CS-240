.eqv MIN_BET 1
.eqv MAX_BET 10000

.data
rollMsg:    .asciiz "Rolled: "
pointMsg:   .asciiz "Point is: "
amtWonMsg:  .asciiz "You won: $"
amtLostMsg: .asciiz "You lost: $"
balMsg:     .asciiz "New balance: $"
playMsg:    .asciiz "Play again? [1 = Again!, 2 = Change Bet, 0 = Quit]: "
newGameMsg: .asciiz "Start game? [1 = Play! ($10 Bet), 2 = Change Bet, 0 = Quit]: "
betMsg:     .asciiz "Enter new bet: $"
badBetMsg:  .asciiz "Bet must be between $1 and $10000, and no more than your balance..\n"
lowBetMsg:  .asciiz "Bet lowered to your remaining balance.\n"
brokeMsg:   .asciiz "You're too broke. Game over.\n"
roundsMsg:  .asciiz "Rounds played: "
newline:    .asciiz "\n"

.text


li $t8 10 # starting playerBet
li $t9 50 # playerBalance


newGameBet:
li $v0, 4
la $a0, newGameMsg
syscall
li $v0, 5
syscall
beq $v0, 0, quit
beq $v0, 1, gameLoop
beq $v0, 2, setPlayerBet
j newGameBet


gameLoop:
addi $t5, $t5, 1

jal diceRoll

beq $t3, 7, winLine
beq $t3, 11, winLine

beq $t3, 2, crapOut
beq $t3, 3, crapOut
beq $t3, 12, crapOut

# Set Point
move $t4, $t3

li $v0, 4
la $a0, pointMsg
syscall
li $v0, 1
move $a0, $t4
syscall
li $v0, 4
la $a0, newline
syscall

# Roll for Point
pointRoll:
jal diceRoll
beq $t3, 7, crapOut
beq $t3, $t4, winPoint
j pointRoll



# === Functions ===

diceRoll:
# Dice Roll 1 (Random 1-6)
li $v0, 42
li $a0, 0
li $a1, 6
syscall
addi $a0, $a0, 1
move $t1, $a0


# Dice Roll 2 (Random 1-6)
li $a0, 0
syscall
addi $a0, $a0, 1
move $t2, $a0

# Sum Dice
add $t3, $t1, $t2

li $v0, 4
la $a0, rollMsg
syscall
li $v0, 1
move $a0, $t3
syscall
li $v0, 4
la $a0, newline
syscall

jr $ra

winLine: # playerBalance += playerBet
move $t0, $t8
j payoutMessage

crapOut:
sub $t9, $t9, $t8 # playerBalance -= playerBet

li $v0, 4
la $a0, amtLostMsg
syscall
li $v0, 1
move $a0, $t8
syscall
li $v0, 4
la $a0, newline
syscall
j endRound


winPoint:
# 2:1 Payout
beq $t4, 4, twoToOne
beq $t4, 10, twoToOne

# 3:2 Payout
beq $t4, 5, threeToTwo
beq $t4, 9, threeToTwo

# 6:5 Payout
beq $t4, 6, sixToFive
beq $t4, 8, sixToFive

j endRound


twoToOne: # playerBalance += (2 * playerBet)
mul $t0, $t8, 2
j payoutMessage

threeToTwo: # playerBalance += [(3 * playerBet) / 2]
mul $t0, $t8, 3
div $t0, $t0, 2
j payoutMessage

sixToFive: # playerBalance += [(6 * playerBet) / 5]
mul $t0, $t8, 6
div $t0, $t0, 5
j payoutMessage

payoutMessage:
add $t9, $t9, $t0 # Payout

li $v0, 4
la $a0, amtWonMsg
syscall
li $v0, 1
move $a0, $t0
syscall
li $v0, 4
la $a0, newline
syscall
j endRound


endRound:
li $v0, 4
la $a0, balMsg
syscall
li $v0, 1
move $a0, $t9
syscall
li $v0, 4
la $a0, newline
syscall

blt $t9, MIN_BET, broke # balance < MIN_BET ($1)
ble $t8, $t9, playAgain # bet is affordable

move $t8, $t9 # set bet to remaining balance
li $v0, 4
la $a0, lowBetMsg
syscall

# Play again?
playAgain:
li $v0, 4
la $a0, playMsg
syscall
li $v0, 5
syscall
beq $v0, 0, quit
beq $v0, 1, nextRound
beq $v0, 2, setPlayerBet
j playAgain

setPlayerBet:
li $v0, 4
la $a0, betMsg
syscall
li $v0, 5
syscall

move $t6, $v0                 # Set playerBetTemp to amount
bgt $t6, $t9, invalidBet      # bet > balance
blt $t6, MIN_BET, invalidBet  # bet < min   
bgt $t6, MAX_BET, invalidBet  # bet > max
move $t8, $t6                 # Set playerBet to playerBetTemp (valid)
j endBet

invalidBet:
li $v0, 4
la $a0, badBetMsg
syscall
j setPlayerBet

endBet:
j nextRound

nextRound:
li $v0, 4
la $a0, newline
syscall
j gameLoop

broke:
li $v0, 4
la $a0, brokeMsg
syscall

quit:
# Rounds played
li $v0, 4
la $a0, roundsMsg
syscall
li $v0, 1
move $a0, $t5
syscall
li $v0, 4
la $a0, newline
syscall

li $v0, 10
syscall
