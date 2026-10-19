.eqv STARTING_BALANCE 50
.eqv MIN_BET 10
.eqv MAX_BET 1000

.data
invalidBetMsg:  .asciiz "Invalid bet amount. Please enter a valid bet.\n"
playerLabel:    .asciiz "Player: "
dealerLabel:    .asciiz "Dealer: "
hiddenOpen:     .asciiz "[?][" 
openBracket:    .asciiz "["
closeBracket:   .asciiz "]" 
oneAceMsg:      .asciiz " (1 soft Ace)"
acesOpen:       .asciiz " ("
acesClose:      .asciiz " soft Aces)"
newline:        .asciiz "\n"

balanceMsg:     .asciiz "Balance: $"
betMsg:         .asciiz "Enter your bet ($10-$1000): "
hitStandMsg:    .asciiz "\nHit [1] or Stand [0]? "
standMsg:       .asciiz "You stand.\n\n"
blackjackMsg:   .asciiz "Blackjack! You win 3:2!\n\n"
winMsg:         .asciiz "You win!\n\n"
dealerBustMsg:  .asciiz "Dealer busts! You win!\n\n"
loseMsg:        .asciiz "Dealer wins. You lose.\n\n"
bustMsg:        .asciiz "You bust! You lose.\n\n"
tieMsg:         .asciiz "Push. Your bet is returned.\n\n"
gameOverMsg:    .asciiz "Game over. You're out of money.\n\n"

.text


gameStart:
li $s1, STARTING_BALANCE
j newHand

newHand:
jal resetRoundRegisters
blt $s1, MIN_BET, gameOver

li $v0, 4
la $a0, balanceMsg
syscall
li $v0, 1
move $a0, $s1
syscall
li $v0, 4
la $a0, newline 
syscall

jal placeBet
jal dealPlayer
jal dealDealer
jal dealPlayer
jal dealDealer
jal calcDealerHandHidden

# tie
bne $s2, 21, checkPlayerBlackjack
bne $t1, 21, checkPlayerBlackjack
jal revealDealerCard
jal calcDealerHand
jal printDealer
jal printPlayer
j tie

checkPlayerBlackjack:
bne $s2, 21, checkDealerBlackjack
jal revealDealerCard
jal calcDealerHand
jal printDealer
jal printPlayer
j blackjackWin

checkDealerBlackjack:
bne $t1, 21, playerTurn
jal revealDealerCard
jal calcDealerHand
jal printDealer
jal printPlayer
j dealerWin







placeBet:
li $v0, 4
la $a0, betMsg
syscall
li $v0, 5                     # Get bet
syscall
move $s0, $v0                 # Set playerBet to amount
bgt $s0, $s1, invalidBet      # bet > balance
blt $s0, MIN_BET, invalidBet  # bet < min   
bgt $s0, MAX_BET, invalidBet  # bet > max
sub $s1, $s1, $s0             # playerBalance - playerBet
jr $ra

invalidBet:
li $v0, 4
la $a0, invalidBetMsg
syscall
j placeBet

resetRoundRegisters:
li $s0, 0 # playerBet
#  $s1      playerBalance - No reset
li $s2, 0 # playerHand
li $s3, 0 # dealerHand
li $s4, 0 # playerAces
li $s5, 0 # dealerAces
li $s6, 0 # downCard
li $s7, 0 # save $ra

li $t0, 0
li $t1, 0
li $t2, 0
li $t3, 0
li $t4, 0
li $t5, 0
li $t6, 0
li $t7, 0

jr $ra

playerTurn:
jal printDealer # print dealerHand
jal printPlayer # print playerHand
bgt $s2, 21, playerBust # playerHand > 21
beq $s2, 21, stand # auto-stand at 21
li $v0, 4
la $a0, hitStandMsg
syscall
li $v0, 5
syscall
move $t3, $v0
beqz $t3, stand
beq $t3, 1, playerHit
j playerTurn

playerHit:
jal dealPlayer
j playerTurn



dealPlayer:
move $s7, $ra # save $ra
jal hit
bne $t0, 11, playerNotAce
addi $s4, $s4, 1 # playerAces++

playerNotAce:
add $s2, $s2, $t0 # add hit to playerHand
jal calcPlayerHand
move $ra, $s7 # restore $ra
jr $ra



dealDealer:
move $s7, $ra # save $ra
jal hit
beqz $s6, dealDownCard # if downCard == 0
bne $t0, 11, dealerNotAce
addi $s5, $s5, 1 # dealerAces++

dealerNotAce:
add $s3, $s3, $t0 # add hit to dealerHand
jal calcDealerHand
j dealDealerDone

dealDownCard:
move $s6, $t0 # store hit in downCard

dealDealerDone:
move $ra, $s7 # restore $ra
jr $ra



revealDealerCard:
beq $s6, -1, revealDone
bne $s6, 11, revealNotAce
addi $s5, $s5, 1   # dealerAces++

revealNotAce:
add $s3, $s3, $s6  # add downCard to dealerHand
li $s6, -1         # set downCard to -1

revealDone:
jr $ra


dealerTurn:
jal printDealer # print dealerHand
bge $s3, 17, dealerDone # If dealerHand >= 17
jal dealDealer
j dealerTurn

dealerDone: 
bgt $s3, 21, dealerBust 
bgt $s3, $s2, dealerWin 
bgt $s2, $s3, playerWin 
j tie 

dealerWin:
li $v0, 4
la $a0, loseMsg
syscall
j newHand

dealerBust: # (Pay out 1:1)
li $v0, 4
la $a0, dealerBustMsg
syscall
mul $t0, $s0, 2
add $s1, $s1, $t0
j newHand

playerWin: # (Pay out 1:1)
li $v0, 4
la $a0, winMsg
syscall
mul $t0, $s0, 2
add $s1, $s1, $t0
j newHand

playerBust:
li $v0, 4
la $a0, bustMsg
syscall
j newHand

blackjackWin: # (Pay out 3:2)
li $v0, 4
la $a0, blackjackMsg
syscall
mul $t0, $s0, 5
div $t0, $t0, 2
add $s1, $s1, $t0
j newHand

tie:
li $v0, 4
la $a0, tieMsg
syscall
add $s1, $s1, $s0
j newHand

stand:
li $v0, 4
la $a0, standMsg
syscall
jal revealDealerCard 
jal calcDealerHand
j dealerTurn

hit: 
li $v0, 42
li $a0, 0
li $a1, 13  # Upper bound
syscall
addi $t0, $a0, 1  # +1, 1-13 hit amount

beq $t0, 1, hitAce
ble $t0, 10, hitDone  # 2-10
li $t0, 10            # 11-13 == 10
j hitDone

hitAce:
li $t0, 11
j hitDone

hitDone:
jr $ra



calcDealerHand: # (handle Aces)
ble $s3, 21, cDHDone
beqz $s5, cDHDone
sub $s3, $s3, 10
sub $s5, $s5, 1
j calcDealerHand

cDHDone:
jr $ra



calcDealerHandHidden: # (handle start blackjack)
move $t1, $s3 # Move dealerHand to dealerHandHidden
move $t2, $s5 # Move dealerAces to dealerAcesHidden
add $t1, $t1, $s6 # Add downCard to dealerHandHidden

bne $s6, 11, cDHHLoop
addi $t2, $t2, 1 # dealerAcesHidden++

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



printPlayer:
li $v0, 4
la $a0, playerLabel      # "Player: "
syscall

li $v0, 4
la $a0, openBracket
syscall

li $v0, 1
move $a0, $s2              # print playerHand
syscall

li $v0, 4
la $a0, closeBracket
syscall

beqz $s4, printTurnEnd     # no aces
beq  $s4, 1, printOneAce

# 2+ aces: " (X Aces)"
li $v0, 4
la $a0, acesOpen
syscall
li $v0, 1    
move $a0, $s4
syscall
li $v0, 4
la $a0, acesClose
syscall
j printTurnEnd

printDealer:
li $v0, 4
la $a0, dealerLabel     # "Dealer: "
syscall

beq $s6, -1, printDealerRevealed   # Card already revealed

li $v0, 4
la $a0, hiddenOpen
syscall

li   $v0, 1
move $a0, $s3
syscall

li $v0, 4
la $a0, closeBracket
syscall

j printDealerAces

printDealerRevealed:
li $v0, 4
la $a0, openBracket
syscall
li $v0, 1
move $a0, $s3   # print dealerHand
syscall
li $v0, 4
la $a0, closeBracket
syscall
j printDealerAces

printDealerAces:
beqz $s5, printTurnEnd     # no aces
beq  $s5, 1, printOneAce

# 2+ aces: " (X Aces)"
li $v0, 4
la $a0, acesOpen
syscall
li $v0, 1    
move $a0, $s5
syscall
li $v0, 4
la $a0, acesClose
syscall
j printTurnEnd

printOneAce: # " (1 Ace)"
li $v0, 4
la $a0, oneAceMsg
syscall
j printTurnEnd

printTurnEnd:
li $v0, 4
la $a0, newline
syscall
jr $ra

gameOver:
li $v0, 4
la $a0, gameOverMsg
syscall
li $v0, 10
syscall
