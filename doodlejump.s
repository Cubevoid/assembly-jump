#####################################################################
#
# CSC258H5S Fall 2020 Assembly Final Project
# University of Toronto, St. George
#
# Student: Colin De Vlieghere, 1005888817
#
# Bitmap Display Configuration:
# - Unit width in pixels: 8
# - Unit height in pixels: 8
# - Display width in pixels: 256
# - Display height in pixels: 256
# - Base Address for Display: 0x10008000 ($gp)
#
# Which milestone is reached in this submission?
# (See the assignment handout for descriptions of the milestones)
# - Milestone 1
## Which approved additional features have been implemented?
# (See the assignment handout for the list of additional features)
# 1. (fill in the feature, if any)
# 2. (fill in the feature, if any)
# 3. (fill in the feature, if any)
# ... (add more if necessary)
#
# Any additional information that the TA needs to know:
# - (write here, if any)
#
#####################################################################

.data
	
	# Display variables
	displayAddress: .word 0x10008000
	displayBuffer: .space 4096
	displayLength: .word 4096

	# Colors
	bgColor: .word 0xefeae5 # tan
	yellow: .word 0xfee33c
	green: .word 0x9ccb4a
	dark_green: .word 0x6c9b1a
	
	# Locations of objects (in display buffer) 
	doodlerLocation: .word 0
	platform1: .word 0
	platform2: .word 0
	platform3: .word 0
	
	# Doodler state variables
	direction: .byte 1 # Direction the Doodler is facing. 0 = Left; 1 = Right.
	altitude: .word 33 # How high (in pixels) the Doodler is above the last platform it touched
	vert_direction: .byte 0 # Vertical velocity of Doodler, 0 = Down; 1 = Up

.text

init:
	# Generate random locations for 2 platforms
	jal random_location_high
	sw $v0, platform1
	
	jal random_location_med
	sw $v0, platform2
	
	la $t0, displayBuffer
	addi $t0, $t0, 3884 # Third platform always spawns bottom middle of screen
	sw $t0, platform3
	
	la $t0, displayBuffer # Doodler spawns right above bottom platform
	addi $t0, $t0, 2480
	sw $t0, doodlerLocation
	
	j main

main:
	lw $t8, 0xffff0000 # Load kb input status into $t8
	beq $t8, 1, keyboard_input # Respond to keyboard input

main_after_kb:

	jal move_doodler_vert # Move the Doodler vertically
	
	jal DrawBG # Draw background into frame buffer
	
	lw $s0, direction

	# If statement to draw correct orientation of Doodler
	beq, $s0, 0, DrawDoodlerLeftCond
	beq, $s0, 1, DrawDoodlerRightCond
	
DrawDoodlerLeftCond:
	jal DrawDoodlerLeft
	j draw_platforms
	
DrawDoodlerRightCond:
	jal DrawDoodlerRight
	j draw_platforms
	
draw_platforms:
	lw $a0, platform1 # Draw platforms from their locations in memory
	jal DrawPlatform
	lw $a0, platform2
	jal DrawPlatform
	lw $a0, platform3
	jal DrawPlatform
	
	jal DrawFromBuffer # Copy from buffer to display
	
	li $v0, 32 # Sleep syscall
	li $a0, 42 # Sleep for 42 ms
	syscall # fps is about 24
	
	j main
	
keyboard_input:
	lw $s5, 0xffff0004 # Load the pressed key into $s5
	beq $s5, 115, Exit # Exit if key pressed is s
	beq $s5, 106, respond_to_j # Check if key pressed is j
	beq $s5, 107, respond_to_k # Check if key pressed is k
	j main_after_kb

respond_to_j: # Move Doodler 1 pixel to the left
	jal move_doodler_left
	j main_after_kb
	
move_doodler_left:
	# Move Doodler left one pixel
	lw $s6, doodlerLocation
	subi $s6, $s6, 4
	sw $s6, doodlerLocation
		
	# Set direction to Left (0)
	add $s7, $zero, $zero
	sw $s7, direction
	
	jr $ra
	
respond_to_k: # Move Doodler 1 pixel to the right
	jal move_doodler_right
	j main_after_kb
	
move_doodler_right:
	# Move Doodler right one pixel
	lw $s6, doodlerLocation
	addi $s6, $s6, 4
	sw $s6, doodlerLocation
			
	# Set direction to Right (1)
	addi $s7, $zero, 1
	sw $s7, direction
	
	jr $ra
	
move_doodler_vert: # Moves Doodler 1px up or down
	lw $t8, vert_direction
	beq $t8, 0, move_doodler_down
	beq $t8, 1, move_doodler_up

move_doodler_down:
	# Update Doodler location and altitude
	lw $t0, doodlerLocation
	lw $t1, altitude
	addi $t0, $t0, 128
	subi $t1, $t1, 1
	sw $t0, doodlerLocation
	sw $t1, altitude
	
	# Test collision with bottom of screen, in which case the game ends
	lw $s1, doodlerLocation # $s1 stores Doodler Location
	la $s2, displayBuffer # $s2 stores origin location (top left corner)
	sub $s0, $s1, $s2 # $s0 is distance of Doodler from origin
	bge $s0, 3200, Exit # Game over if Doodler touches bottom of screen!
	
	jr $ra
	
move_doodler_up:
	# Update Doodler location and altitude
	lw $t0, doodlerLocation
	lw $t1, altitude
	subi $t0, $t0, 128
	addi $t1, $t1, 1
	sw $t0, doodlerLocation
	sw $t1, altitude
	
	jr $ra
	
DrawBG:
	la $t0, displayBuffer # $t0 stores the base address for display
	lw $t1, bgColor # $t1 stores background color (tan)
	lw $t2, displayLength
	add $t2, $t0, $t2 # $t2 stores the end address for display
	j BGLoop
	
BGLoop: 
	bge $t0, $t2, EndBGLoop
	sw $t1, 0($t0) # $t0 is the counter in the loop. Paint pixel teal
	addi $t0, $t0, 4 # Increment one pixel
	j BGLoop
	
EndBGLoop:
	jr $ra
	
DrawDoodlerRight: # doodlerLocation is the top left corner address of the 8x8 Doodler
	lw $a0, doodlerLocation
	lw $t3, yellow
	lw $t4, green
	# Black is $zero register
	
	sw $t3, 4($a0)
	sw $t3, 8($a0)
	sw $t3, 12($a0)
	
	sw $t3, 128($a0)
	sw $t3, 132($a0)
	sw $zero, 136($a0)
	sw $t3, 140($a0)
	sw $zero, 144($a0)
	sw $t3, 156($a0)
	
	sw $t3, 256($a0)
	sw $t3, 260($a0)
	sw $t3, 264($a0)
	sw $t3, 268($a0)
	sw $t3, 272($a0)
	sw $t3, 276($a0)
	sw $t3, 280($a0)
	sw $t3, 284($a0)
	
	sw $t3, 384($a0)
	sw $t3, 388($a0)
	sw $t3, 392($a0)
	sw $t3, 396($a0)
	sw $t3, 400($a0)
	sw $t3, 412($a0)
	
	sw $t4, 512($a0)
	sw $t4, 516($a0)
	sw $t4, 520($a0)
	sw $t4, 524($a0)
	sw $t4, 528($a0)
	
	sw $t4, 640($a0)
	sw $t4, 644($a0)
	sw $t4, 648($a0)
	sw $t4, 652($a0)
	sw $t4, 656($a0)
	
	sw $zero, 768($a0)
	sw $zero, 780($a0)
	sw $zero, 896($a0)
	sw $zero, 900($a0)
	sw $zero, 908($a0)
	sw $zero, 912($a0)
	
	jr $ra
	
DrawDoodlerLeft: # doodlerLocation is the top left corner address of the 8x8 Doodler
	lw $a0, doodlerLocation
	lw $t3, yellow
	lw $t4, green
	# Black is $zero register
	
	sw $t3, 4($a0)
	sw $t3, 8($a0)
	sw $t3, 12($a0)
	
	sw $t3, 116($a0)
	sw $zero, 128($a0)
	sw $t3, 132($a0)
	sw $zero, 136($a0)
	sw $t3, 140($a0)
	sw $t3, 144($a0)
	
	sw $t3, 244($a0)
	sw $t3, 248($a0)
	sw $t3, 252($a0)
	sw $t3, 256($a0)
	sw $t3, 260($a0)
	sw $t3, 264($a0)
	sw $t3, 268($a0)
	sw $t3, 272($a0)
	
	sw $t3, 372($a0)
	sw $t3, 384($a0)
	sw $t3, 388($a0)
	sw $t3, 392($a0)
	sw $t3, 396($a0)
	sw $t3, 400($a0)
	
	sw $t4, 512($a0)
	sw $t4, 516($a0)
	sw $t4, 520($a0)
	sw $t4, 524($a0)
	sw $t4, 528($a0)
	
	sw $t4, 640($a0)
	sw $t4, 644($a0)
	sw $t4, 648($a0)
	sw $t4, 652($a0)
	sw $t4, 656($a0)
	
	sw $zero, 772($a0)
	sw $zero, 784($a0)
	sw $zero, 896($a0)
	sw $zero, 900($a0)
	sw $zero, 908($a0)
	sw $zero, 912($a0)
	
	jr $ra
	
DrawPlatform: # function takes in $a0 for left start point of platform. Platform is 7 pixels long
	lw $t0, dark_green # $t0 is Dark green
	sw $t0, 0($a0)
	sw $t0, 4($a0)
	sw $t0, 8($a0)
	sw $t0, 12($a0)
	sw $t0, 16($a0)
	sw $t0, 20($a0)
	sw $t0, 24($a0)
	
	jr $ra
	
random_location_high: # function outputs a random location for platforms in memory buffer in $v0
	# First generate X coordinate (do not want platforms to hang over multiple rows)
	li $v0, 42
	li $a0, 0
	li $a1, 26 # up to but not including 26
	syscall
	mul $t0, $a0, 4 # X coord is in $t0
	
	li $v0, 42
	li $a0, 0
	li $a1, 10
	syscall
	addi $a0, $a0, 4
	mul $t1, $a0, 128 # Y coord is in $t1
	
	add $v0, $t0, $t1 # Add X and Y coord
	la $t2, displayBuffer
	add $v0, $v0, $t2 # Return X and Y coord relative to display buffer address
	
	jr $ra
	
random_location_med: # function outputs a random location for platforms in memory buffer in $v0
	# First generate X coordinate (do not want platforms to hang over multiple rows)
	li $v0, 42
	li $a0, 0
	li $a1, 26 # up to but not including 26
	syscall
	mul $t0, $a0, 4 # X coord is in $t0
	
	li $v0, 42
	li $a0, 0
	li $a1, 10
	syscall
	addi $a0, $a0, 16
	mul $t1, $a0, 128 # Y coord is in $t1
	
	add $v0, $t0, $t1 # Add X and Y coord
	la $t2, displayBuffer
	add $v0, $v0, $t2 # Return X and Y coord relative to display buffer address
	
	jr $ra
	
DrawFromBuffer: # Draw whatever is in the memory buffer onto the screen
	la $t0, displayBuffer
	lw $t1, displayAddress
	lw $t2, displayLength
	add $t3, $t1, $t2 # $t3 stores the max display address
	j DrawLoop
	
DrawLoop:
	bge $t1, $t3, DrawLoopEnd # Loop exits when display address >= max display address
	lw $t9, 0($t0) # Copy from buffer to $t9
	sw $t9, 0($t1) # Copy from $t9 to display
	
	addi $t0, $t0, 4 # Increment buffer address
	addi $t1, $t1, 4 # Increment display address
	j DrawLoop
	
DrawLoopEnd:
	jr $ra
	
Exit:
	li $v0, 10 # terminate the program gracefully
	syscall
