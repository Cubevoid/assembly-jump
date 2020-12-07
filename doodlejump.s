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
# - Milestone 4
## Which approved additional features have been implemented?
# (See the assignment handout for the list of additional features)
# 1. Scoreboard
# 2. Game over screen (s to reset game)
# 3. Fancy graphics: Doodler, scrolling background, festive platforms
#
# Any additional information that the TA needs to know:
# - Minor bug: memory address out of range when Doodler jumps into top left of screen
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
	red: .word 0xff0000
	dark_green: .word 0x6c9b1a
	scoreboard_color: .word 0x00008b # Scoreboard is dark blue
	grid_color: .word 0xe7dcd2 # darker tan
	
	# Locations of objects (in display buffer) 
	doodlerLocation: .word 0
	platform1: .word 0
	platform2: .word 0
	platform3: .word 0
	
	# Doodler state variables
	direction: .byte 1 # Direction the Doodler is facing. 0 = Left; 1 = Right.
	altitude: .word 33 # How high (in pixels) the Doodler is above the last platform it touched
	vert_direction: .byte 0 # Vertical velocity of Doodler, 0 = Down; 1 = Up
	
	jump_height: .word 18
	
	score: .word 0 # 4 digit decimal (9999 max)
	
	frames: .word 0 # Counts number of frames (for syncing music)

.text

wait_for_start:
	lw $t8, 0xffff0000 # Load kb input status into $t8
	beq $t8, 1, keyboard_input # Respond to keyboard input
	
	li $v0, 32 # Sleep syscall
	li $a0, 50 # Sleep for 50 ms
	syscall
	
	j wait_for_start

init:
	# Generate random locations for 2 platforms
	jal random_location_high
	sw $v0, platform1
	
	jal random_location_med
	sw $v0, platform2
	
	la $t0, displayBuffer
	addi $t0, $t0, 3884 # Third platform always spawns bottom middle of screen
	sw $t0, platform3
	
	la $t0, displayBuffer
	addi $t0, $t0, 2480 # Doodler spawns right above third platform
	sw $t0, doodlerLocation
	
	# reset direction, altitude, vert_direction, score
	addi $t0, $zero, 1
	sw $t0, direction
	addi $t0, $t0, 32
	sw $t0, altitude
	sw $zero, vert_direction
	sw $zero, score
	
	j main

main:
	lw $t8, 0xffff0000 # Load kb input status into $t8
	beq $t8, 1, keyboard_input # Respond to keyboard input
	
	j main_after_kb

main_after_kb:

	jal doodler_vert # Move the Doodler vertically
	
	jal DrawBG # Draw background into frame buffer
	
	jal draw_grid # Fancy grid!
	
	lw $s0, direction

	# If statement to draw correct orientation of Doodler
	beq, $s0, 0, DrawDoodlerLeftCond
	beq, $s0, 1, DrawDoodlerRightCond
	
	j Exit # This should never happen
	
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
	
	jal draw_scoreboard
	
	jal DrawFromBuffer # Copy from buffer to display

sleep:
	li $v0, 32 # Sleep syscall
	li $a0, 42 # Sleep for 42 ms
	syscall # fps is about 24
	
	lw $t0, frames # Increment frame counter
	addi $t0, $t0, 1
	sw $t0, frames
	
	j play_sound
	
play_sound: # Maps the frame count to the correct tone in the nyan cat soundtrack
	# Soundtrack has 32 8th notes at ~60bpm
	# Since the sleep is 42ms, every 3 frames = 1 eigth note
	# $t0 stores frame count
	
	addi $t1, $zero, 3
	div $t0, $t1 # HI stores remainder, i.e. frames % 3
	mfhi $t1
	bne $t1, $zero, main # If frame is not multiple of 3, don't play sound
	mflo $t0 # $t0 now stores 8th note count (absolute)
	addi $t1, $zero, 32
	div $t0, $t1 # 8th note count mod 32 (stored in HI)
	mfhi $t0 # $t0 stores 8th note count (mod 32)
	
	addi $v0, $zero, 31 # Service 31
	addi $a2, $zero, 1 # Instrument, 0-127 (1 is piano)
	addi $a3, $zero, 60 # Volume, 0-127
	
	beq $t0, 0, f_sharp_long
	beq $t0, 2, g_sharp_long
	beq $t0, 4, d
	beq $t0, 5, d_sharp_long
	beq $t0, 7, c_sharp
	beq $t0, 8, d
	beq $t0, 9, c_sharp
	beq $t0, 10, b_long
	beq $t0, 12, b_long
	beq $t0, 14, c_sharp_long
	beq $t0, 16, d_long
	beq $t0, 18, d
	beq $t0, 19, c_sharp
	beq $t0, 20, b_note # b is an instruction, sadly
	beq $t0, 21, c_sharp
	beq $t0, 22, d_sharp
	beq $t0, 23, f_sharp
	beq $t0, 24, g_sharp
	beq $t0, 25, d_sharp
	beq $t0, 26, f_sharp
	beq $t0, 27, c_sharp
	beq $t0, 28, d_sharp
	beq $t0, 29, b_note
	beq $t0, 30, c_sharp
	beq $t0, 31, b_note
	
	j main # shouldn't happen
	
play_long:
	addi $a1, $zero, 252 # Duration of sound in ms
	syscall
	j main
	
play:
	addi $a1, $zero, 126 # Duration of sound in ms
	syscall
	j main

f_sharp_long:
	addi $a0, $zero, 66 # Pitch, 0-127
	j play_long

g_sharp_long:
	addi $a0, $zero, 68 # Pitch, 0-127
	j play_long
	
d:
	addi $a0, $zero, 62 # Pitch, 0-127
	j play
	
d_sharp_long:
	addi $a0, $zero, 63 # Pitch, 0-127
	j play_long
	
c_sharp:
	addi $a0, $zero, 61 # Pitch, 0-127
	j play
	
b_long:
	addi $a0, $zero, 59 # Pitch, 0-127
	j play_long
	
c_sharp_long:
	addi $a0, $zero, 61 # Pitch, 0-127
	j play_long
	
d_long:
	addi $a0, $zero, 62 # Pitch, 0-127
	j play_long
	
b_note:
	addi $a0, $zero, 59 # Pitch, 0-127
	j play
	
d_sharp:
	addi $a0, $zero, 63 # Pitch, 0-127
	j play

f_sharp:
	addi $a0, $zero, 66 # Pitch, 0-127
	j play
	
g_sharp:
	addi $a0, $zero, 68 # Pitch, 0-127
	j play
	
	
keyboard_input:
	lw $s5, 0xffff0004 # Load the pressed key into $s5
	beq $s5, 115, init # Start game if key pressed is s
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
	
doodler_vert: # Handles vertical Doodler stuff
	subi, $sp, $sp, 4 # Move stack pointer up 1 word
	sw $ra, 0($sp) # Store $ra in the stack
	
	jal detect_platform_collision
	
	lw $ra, 0($sp) # Pop from stack into $ra
	addi $sp, $sp, 4 
	
	lw $t7, altitude
	lw $t8, jump_height
	bge $t7, $t8, start_falling # max altitude is 15 pixels
	
	j move_doodler_vert # Unnecessary

move_doodler_vert: # Move Doodler 1px up or down
	lw $t8, vert_direction
	beq $t8, 0, move_doodler_down
	beq $t8, 1, move_doodler_up
	
	jr $ra # Should not be necessary
	
start_falling:
	addi $t8, $zero, 0 # Set $t8 to 0 (falling)
	sw $t8, vert_direction # Set vert_direction to 0 (falling)
	
	j move_doodler_vert
	
move_doodler_down:
	# Update Doodler location and altitude
	lw $t0, doodlerLocation
	lw $t1, altitude
	addi $t0, $t0, 128 # Move doodler down one pixel
	subi $t1, $t1, 1 # Subtract 1 from altitude
	sw $t0, doodlerLocation
	sw $t1, altitude
	
	# Test collision with bottom of screen, in which case the game ends
	lw $s1, doodlerLocation # $s1 stores Doodler Location
	la $s2, displayBuffer # $s2 stores origin location (top left corner)
	sub $s0, $s1, $s2 # $s0 is distance of Doodler from origin
	bge $s0, 3200, game_over_screen # Game over if Doodler touches bottom of screen!
	
	jr $ra # Jump back to where doodler_vert was called
	
move_doodler_up:
	# Update Doodler location and altitude
	lw $t0, doodlerLocation
	lw $t1, altitude
	
	la $t2, displayBuffer
	addi $t2, $t2, 124 # $t2 is the last pixel of the first row
	ble $t0, $t2, shift_everything_down_instead # If Doodler is already at top of screen, shift everything down instead
	
	subi $t0, $t0, 128 # Move doodler up one pixel
	addi $t1, $t1, 1 # Add 1 to altitude
	sw $t0, doodlerLocation
	sw $t1, altitude
	
	jr $ra # Jump back to where doodler_vert was called
	
shift_everything_down_instead:

	lw $t0, score
	addi $t0, $t0, 1 # Add 1 to score
	sw $t0, score

	addi $t1, $t1, 1 # Add 1 to altitude
	sw $t1, altitude
	
	lw $s1, platform1
	lw $s2, platform2
	lw $s3, platform3
	addi $s1, $s1, 128 # Move all platforms down 1 px
	addi $s2, $s2, 128
	addi $s3, $s3, 128
	sw $s1, platform1
	sw $s2, platform2
	sw $s3, platform3
	
	# If any platforms fall below the floor, we need to generate a new one above
	la $t2, displayBuffer
	lw $t3, displayLength
	add $t2, $t2, $t3 # $t2 is max value of display
	bge $s1, $t2, gen_new_platform_1 # Generate a new platform if it is below display
	bge $s2, $t2, gen_new_platform_2
	bge $s3, $t2, gen_new_platform_3
	
	jr $ra # Jump back to where doodler_vert was called
	
gen_new_platform_1:
	# First generate X coordinate (do not want platforms to hang over multiple rows)
	li $v0, 42
	li $a0, 0
	li $a1, 26 # up to but not including 26
	syscall
	mul $t0, $a0, 4 # X coord is in $t0
	
	# Y = 0 (top row) stored in $t1
	add $t1, $zero, $zero
	
	add $t3, $t0, $t1 # Add X and Y coord
	la $t2, displayBuffer
	add $t3, $t3, $t2 # $t3 is X and Y coord relative to display buffer address
	
	sw $t3, platform1 # Store new Platform location
	
	jr $ra # Jump back to where doodler_vert was called
	
gen_new_platform_2:
	# First generate X coordinate (do not want platforms to hang over multiple rows)
	li $v0, 42
	li $a0, 0
	li $a1, 26 # up to but not including 26
	syscall
	mul $t0, $a0, 4 # X coord is in $t0
	
	# Y = 0 (top row) stored in $t1
	add $t1, $zero, $zero
	
	add $t3, $t0, $t1 # Add X and Y coord
	la $t2, displayBuffer
	add $t3, $t3, $t2 # $t3 is X and Y coord relative to display buffer address
	
	sw $t3, platform2 # Store new Platform location
	
	jr $ra # Jump back to where doodler_vert was called
gen_new_platform_3:
		# First generate X coordinate (do not want platforms to hang over multiple rows)
	li $v0, 42
	li $a0, 0
	li $a1, 26 # up to but not including 26
	syscall
	mul $t0, $a0, 4 # X coord is in $t0
	
	# Y = 0 (top row) stored in $t1
	add $t1, $zero, $zero
	
	add $t3, $t0, $t1 # Add X and Y coord
	la $t2, displayBuffer
	add $t3, $t3, $t2 # $t3 is X and Y coord relative to display buffer address
	
	sw $t3, platform3 # Store new Platform location
	
	jr $ra # Jump back to where doodler_vert was called
	
detect_platform_collision: # Function sets vert_direction to 1 if Doodler's foot is touching a platform AND Doodler is moving down, otherwise it leaves vert_direction untouched
	# Load object locations into $s0-$s3
	lw $s0, doodlerLocation
	lw $s1, platform1
	lw $s2, platform2
	lw $s3, platform3
	lw $s4, vert_direction
	
	beq $s4, 1, not_3 # Don't check for collisions if Doodler is moving UP
	
	addi $s0, $s0, 1024 # Add 128*8 to doodler location to get leftmost under-foot pixel
	sub $s1, $s1, $s0 # Subtract platform - doodler foot to get difference
	sub $s2, $s2, $s0 # $s1, $s2, and $s3 now store difference in platform loc relative to Doodler foot
	sub $s3, $s3, $s0 # (in memory buffer)
	
	# Platform start must be between -6px and 4px relative to $s0 to collide
	bge $s1, -24, foot_cond_1 # At least -6px
not_1:
	bge $s2, -24, foot_cond_2
not_2:
	bge $s3, -24, foot_cond_3
not_3:
	# Do nothing if no conditions are satisfied
	jr $ra
	
foot_cond_1: # Bounce if at most 4px difference
	ble $s1, 16, bounce
	j not_1 # Otherwise do nothing
	
foot_cond_2:
	ble $s2, 16, bounce
	j not_2
	
foot_cond_3:
	ble $s3, 16, bounce
	j not_3
	
bounce: # Set vert_direction to 1 and altitude to 0
	addi $t0, $zero, 1
	sw $t0, vert_direction
	sw $zero, altitude
	
	# Sound effect!
	addi $v0, $zero, 31 # Service 31
	addi $a0, $zero, 70 # Pitch, 0-127
	addi $a1, $zero, 100 # Duration of sound in ms
	addi $a2, $zero, 12 # Instrument, 0-127
	addi $a3, $zero, 60 # Volume, 0-127
	syscall
	
	jr $ra
	
DrawBG:
	la $t0, displayBuffer # $t0 stores the base address for display
	lw $t1, bgColor # $t1 stores background color (tan)
	lw $t2, displayLength
	add $t2, $t0, $t2 # $t2 stores the end address for display
	j BGLoop
	
BGLoop: 
	bge $t0, $t2, EndBGLoop
	sw $t1, 0($t0) # $t0 is the counter in the loop. Paint pixel tan
	addi $t0, $t0, 4 # Increment one pixel
	j BGLoop
	
EndBGLoop:
	jr $ra
	
draw_grid: # draws a grid in the display buffer, with a vertical offset equal to score % 4
	la $a0, displayBuffer # Load buffer start address into $a0
	addi $t0, $zero, 16 # $t0 stores spacing between each line (4px)
	addi $t1, $a0, 128 # $t1 stores max x value
	addi $t2, $a0, 4096 # $t2 stores max y value
	
	addi $sp, $sp, -4 # Move stack pointer up
	sw $ra, 0($sp) # Push $ra to stack
	
	addi $a0, $a0, 4
	j draw_vert_lines
	
draw_vert_lines: # Draw all the vertical lines
	bge $a0, $t1, end_vert_lines_loop
	jal draw_vline
	add $a0, $a0, $t0 # Increment $a0 by spacing
	j draw_vert_lines

end_vert_lines_loop: # Reset $a0
	la $a0, displayBuffer
	
	lw $t3, score
	addi $t4, $zero, 4
	div $t3, $t4 # Divide score by 4; HI stores remainder
	mfhi $t3 # $t3 stores vertical offset in pixels
	mul $t3, $t3, 128 # $t3 stores vertical offset in bytes
	
	add $a0, $a0, $t3 # $a0 is starting value of horiz lines
	
	j draw_horiz_lines

draw_horiz_lines: # Now draw all the horizontal lines with correct offset
	bge $a0, $t2, end_horiz_lines_loop # Break when max y value is reached
	jal draw_hline
	addi $a0, $a0, 512 # Increment $a0 by 4 lines
	j draw_horiz_lines

end_horiz_lines_loop:
	lw $ra, 0($sp) # Pop $sp off stack
	addi $sp, $sp, 4 # Move stack pointer down
	jr $ra

draw_hline: # function draws a horizontal gridline at the memory location in $a0. Does not modify the value in $a0.
	add $s0, $a0, $zero # Duplicate value of $a0 into $s0
	addi $s1, $s0, 128 # $s1 stores end of line
	lw $s2, grid_color
	
hline_loop:
	bge $s0, $s1, end_hline_loop
	sw $s2, 0($s0) # Push pixel
	addi $s0, $s0, 4 # Increment $s0
	j hline_loop
	
end_hline_loop:
	jr $ra
	
draw_vline: # function draws a vertical gridline at the memory location in $a0. Does not modify the value in $a0.
	add $s0, $a0, $zero # Duplicate value of $a0 into $s0
	add $s1, $s0, 4096 # $s1 stores end of line
	lw $s2, grid_color
	
vline_loop:
	bge $s0, $s1, end_vline_loop
	sw $s2, 0($s0) # Push pixel
	addi $s0, $s0, 128 # Increment $s0
	j vline_loop
	
end_vline_loop:
	jr $ra
	
DrawPlatform: # function takes in $a0 for left start point of platform. Platform is 7 pixels long
	lw $t0, dark_green # $t0 is Dark green
	lw $t1, red # $t1 is Red
	sw $t0, 0($a0)
	sw $t1, 4($a0)
	sw $t0, 8($a0)
	sw $t1, 12($a0)
	sw $t0, 16($a0)
	sw $t1, 20($a0)
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
	li $a1, 10 # up to but not including 10
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
	
# NUMBERS ARE ALL 3px WIDE BY 5px TALL
# Location is top left corner
draw_1: # Function draws a 1 at memory location specified in $a3
	lw $t0, scoreboard_color # $t0 stores color of scoreboard
	
	sw $t0, 0($a3)
	sw $t0, 4($a3)
	sw $t0, 132($a3)
	sw $t0, 260($a3)
	sw $t0, 388($a3)
	sw $t0, 512($a3)
	sw $t0, 516($a3)
	sw $t0, 520($a3)
	
	jr $ra

draw_2: # Function draws a 2 at memory location specified in $a3
	lw $t0, scoreboard_color # $t0 stores color of scoreboard
	
	sw $t0, 0($a3)
	sw $t0, 4($a3)
	sw $t0, 8($a3)
	sw $t0, 136($a3)
	sw $t0, 256($a3)
	sw $t0, 260($a3)
	sw $t0, 264($a3)
	sw $t0, 384($a3)
	sw $t0, 512($a3)
	sw $t0, 516($a3)
	sw $t0, 520($a3)
	
	jr $ra
	
draw_3: # Function draws a 3 at memory location specified in $a3
	lw $t0, scoreboard_color # $t0 stores color of scoreboard
	
	sw $t0, 0($a3)
	sw $t0, 4($a3)
	sw $t0, 8($a3)
	sw $t0, 136($a3)
	sw $t0, 256($a3)
	sw $t0, 260($a3)
	sw $t0, 264($a3)
	sw $t0, 392($a3)
	sw $t0, 512($a3)
	sw $t0, 516($a3)
	sw $t0, 520($a3)
	
	jr $ra
	
draw_4: # Function draws a 4 at memory location specified in $a3
	lw $t0, scoreboard_color # $t0 stores color of scoreboard
	
	sw $t0, 0($a3)
	sw $t0, 8($a3)
	sw $t0, 128($a3)
	sw $t0, 136($a3)
	sw $t0, 256($a3)
	sw $t0, 260($a3)
	sw $t0, 264($a3)
	sw $t0, 392($a3)
	sw $t0, 520($a3)
	
	jr $ra
	
draw_5: # Function draws a 5 at memory location specified in $a3
	lw $t0, scoreboard_color # $t0 stores color of scoreboard
	
	sw $t0, 0($a3)
	sw $t0, 4($a3)
	sw $t0, 8($a3)
	sw $t0, 128($a3)
	sw $t0, 256($a3)
	sw $t0, 260($a3)
	sw $t0, 264($a3)
	sw $t0, 392($a3)
	sw $t0, 512($a3)
	sw $t0, 516($a3)
	sw $t0, 520($a3)
	
	jr $ra
	
draw_6: # Function draws a 6 at memory location specified in $a3
	lw $t0, scoreboard_color # $t0 stores color of scoreboard
	
	sw $t0, 0($a3)
	sw $t0, 4($a3)
	sw $t0, 8($a3)
	sw $t0, 128($a3)
	sw $t0, 256($a3)
	sw $t0, 260($a3)
	sw $t0, 264($a3)
	sw $t0, 384($a3)
	sw $t0, 392($a3)
	sw $t0, 512($a3)
	sw $t0, 516($a3)
	sw $t0, 520($a3)
	
	jr $ra
	
draw_7: # Function draws a 7 at memory location specified in $a3
	lw $t0, scoreboard_color # $t0 stores color of scoreboard
	
	sw $t0, 0($a3)
	sw $t0, 4($a3)
	sw $t0, 8($a3)
	sw $t0, 136($a3)
	sw $t0, 264($a3)
	sw $t0, 392($a3)
	sw $t0, 520($a3)
	
	jr $ra
	
draw_8: # Function draws an 8 at memory location specified in $a3
	lw $t0, scoreboard_color # $t0 stores color of scoreboard
	
	sw $t0, 0($a3)
	sw $t0, 4($a3)
	sw $t0, 8($a3)
	sw $t0, 128($a3)
	sw $t0, 136($a3)
	sw $t0, 256($a3)
	sw $t0, 260($a3)
	sw $t0, 264($a3)
	sw $t0, 384($a3)
	sw $t0, 392($a3)
	sw $t0, 512($a3)
	sw $t0, 516($a3)
	sw $t0, 520($a3)
	
	jr $ra
	
draw_9: # Function draws a 9 at memory location specified in $a3
	lw $t0, scoreboard_color # $t0 stores color of scoreboard
	
	sw $t0, 0($a3)
	sw $t0, 4($a3)
	sw $t0, 8($a3)
	sw $t0, 128($a3)
	sw $t0, 136($a3)
	sw $t0, 256($a3)
	sw $t0, 260($a3)
	sw $t0, 264($a3)
	sw $t0, 392($a3)
	sw $t0, 512($a3)
	sw $t0, 516($a3)
	sw $t0, 520($a3)
	
	jr $ra
	
draw_0: # Function draws a 0 at memory location specified in $a3
	lw $t0, scoreboard_color # $t0 stores color of scoreboard
	
	sw $t0, 0($a3)
	sw $t0, 4($a3)
	sw $t0, 8($a3)
	sw $t0, 128($a3)
	sw $t0, 136($a3)
	sw $t0, 256($a3)
	sw $t0, 264($a3)
	sw $t0, 384($a3)
	sw $t0, 392($a3)
	sw $t0, 512($a3)
	sw $t0, 516($a3)
	sw $t0, 520($a3)
	
	jr $ra
	
draw_scoreboard:
	lw $t1, score # $t1 stores the current score
	addi $s1, $zero, 10 # $s1 stores 10^1
	addi $s2, $zero, 100 # $s2 stores 10^2
	addi $s3, $zero, 1000 # $s3 stores 10^3
	
	div $t1, $s3 # LO stores value of score // 1000, HI stores remainder
	mflo $t9 # $t9 stores thousands digit of score
	mfhi $t1 # $t1 stores score without thousands digit
	
	div $t1, $s2 # LO stores value of $t1 // 100, HI stores remainder
	mflo $t8 # $t8 stores hundreds digit of score
	mfhi $t1 # $t1 stores score without thousands or hundreds digit
	
	div $t1, $s1 # LO stores value of $t1 // 10, HI stores remainder
	mflo $t7 # $t7 stores tens digit of score
	mfhi $t6 # $t6 stores ones digit of score
	
	# TODO: stack preserve $ra
	subi $sp, $sp, 4 # move stack pointer up
	sw $ra, 0($sp) # push $ra into stack
	
	jal draw_ones_digit
	jal draw_tens_digit
	jal draw_hundreds_digit
	jal draw_thousands_digit
	
	lw $ra, 0($sp) # pop $ra from stack
	addi $sp, $sp, 4 # move stack pointer down
	
	jr $ra
	
draw_ones_digit: # Function takes in $t6 (ones digit of score) and draws it on the screen
	la $t2, displayBuffer
	addi $a3, $t2, 240 # set $a3 to location to draw ones digit
	
	# Draw appropriate asset for $t6 (score's ones digit)
	beq $t6, 0, draw_0
	beq $t6, 1, draw_1
	beq $t6, 2, draw_2
	beq $t6, 3, draw_3
	beq $t6, 4, draw_4
	beq $t6, 5, draw_5
	beq $t6, 6, draw_6
	beq $t6, 7, draw_7
	beq $t6, 8, draw_8
	beq $t6, 9, draw_9
	
	j draw_ones_digit # SHOULD NEVER HAPPEN
	
draw_tens_digit:
	la $t2, displayBuffer
	addi $a3, $t2, 224 # set $a3 to location to draw tens digit
	
	# Draw appropriate asset for $t7 (score's tens digit)
	beq $t7, 0, draw_0
	beq $t7, 1, draw_1
	beq $t7, 2, draw_2
	beq $t7, 3, draw_3
	beq $t7, 4, draw_4
	beq $t7, 5, draw_5
	beq $t7, 6, draw_6
	beq $t7, 7, draw_7
	beq $t7, 8, draw_8
	beq $t7, 9, draw_9
	
	j draw_tens_digit # SHOULD NEVER HAPPEN

draw_hundreds_digit:
	la $t2, displayBuffer
	addi $a3, $t2, 208 # set $a3 to location to draw hundreds digit
	
	# Draw appropriate asset for $t8 (score's hundreds digit)
	beq $t8, 0, draw_0
	beq $t8, 1, draw_1
	beq $t8, 2, draw_2
	beq $t8, 3, draw_3
	beq $t8, 4, draw_4
	beq $t8, 5, draw_5
	beq $t8, 6, draw_6
	beq $t8, 7, draw_7
	beq $t8, 8, draw_8
	beq $t8, 9, draw_9
	
	j draw_hundreds_digit # SHOULD NEVER HAPPEN
	
draw_thousands_digit:
	la $t2, displayBuffer
	addi $a3, $t2, 192 # set $a3 to location to draw thousands digit
	
	# Draw appropriate asset for $t9 (score's thousands digit)
	beq $t9, 0, draw_0
	beq $t9, 1, draw_1
	beq $t9, 2, draw_2
	beq $t9, 3, draw_3
	beq $t9, 4, draw_4
	beq $t9, 5, draw_5
	beq $t9, 6, draw_6
	beq $t9, 7, draw_7
	beq $t9, 8, draw_8
	beq $t9, 9, draw_9
	
	j draw_thousands_digit # SHOULD NEVER HAPPEN
	
game_over_screen: # Draws GAME OVER on the screen and resets game
	
	la $t2, displayBuffer
	addi $t2, $t2, 1048 # $t2 stores starting location to draw text
	
	lw $t0, scoreboard_color # $t0 stores dark blue
	
	# Row 1
	sw $t0, 0($t2)
	sw $t0, 4($t2)
	sw $t0, 8($t2)
	sw $t0, 12($t2)
	sw $t0, 20($t2)
	sw $t0, 24($t2)
	sw $t0, 28($t2)
	sw $t0, 32($t2)
	sw $t0, 40($t2)
	sw $t0, 44($t2)
	sw $t0, 52($t2)
	sw $t0, 56($t2)
	sw $t0, 64($t2)
	sw $t0, 68($t2)
	sw $t0, 72($t2)
	sw $t0, 76($t2)
	
	# Row 2
	addi $t2, $t2, 128 # Move $t2 to next row
	sw $t0, 0($t2)
	sw $t0, 20($t2)
	sw $t0, 32($t2)
	sw $t0, 40($t2)
	sw $t0, 48($t2)
	sw $t0, 56($t2)
	sw $t0, 64($t2)
	
	# Row 3
	addi $t2, $t2, 128 # Move $t2 to next row
	sw $t0, 0($t2)
	sw $t0, 8($t2)
	sw $t0, 12($t2)
	sw $t0, 20($t2)
	sw $t0, 24($t2)
	sw $t0, 28($t2)
	sw $t0, 32($t2)
	sw $t0, 40($t2)
	sw $t0, 48($t2)
	sw $t0, 56($t2)
	sw $t0, 64($t2)
	sw $t0, 68($t2)
	sw $t0, 72($t2)
	
	# Row 4
	addi $t2, $t2, 128 # Move $t2 to next row
	sw $t0, 0($t2)
	sw $t0, 12($t2)
	sw $t0, 20($t2)
	sw $t0, 32($t2)
	sw $t0, 40($t2)
	sw $t0, 56($t2)
	sw $t0, 64($t2)
	
	# Row 5
	addi $t2, $t2, 128 # Move $t2 to next row
	sw $t0, 0($t2)
	sw $t0, 4($t2)
	sw $t0, 8($t2)
	sw $t0, 12($t2)
	sw $t0, 20($t2)
	sw $t0, 32($t2)
	sw $t0, 40($t2)
	sw $t0, 56($t2)
	sw $t0, 64($t2)
	sw $t0, 68($t2)
	sw $t0, 72($t2)
	sw $t0, 76($t2)
	
	# Next row of letters
	addi $t2, $t2, 512 # Move $t2 down 4 rows
	sw $t0, 0($t2)
	sw $t0, 4($t2)
	sw $t0, 8($t2)
	sw $t0, 12($t2)
	sw $t0, 20($t2)
	sw $t0, 32($t2)
	sw $t0, 40($t2)
	sw $t0, 44($t2)
	sw $t0, 48($t2)
	sw $t0, 52($t2)
	sw $t0, 60($t2)
	sw $t0, 64($t2)
	sw $t0, 68($t2)
	
	# Row 2
	addi $t2, $t2, 128 # Move $t2 down one row
	sw $t0, 0($t2)
	sw $t0, 12($t2)
	sw $t0, 20($t2)
	sw $t0, 32($t2)
	sw $t0, 40($t2)
	sw $t0, 60($t2)
	sw $t0, 72($t2)
	
	# Row 3
	addi $t2, $t2, 128 # Move $t2 down one row
	sw $t0, 0($t2)
	sw $t0, 12($t2)
	sw $t0, 20($t2)
	sw $t0, 32($t2)
	sw $t0, 40($t2)
	sw $t0, 44($t2)
	sw $t0, 48($t2)
	sw $t0, 60($t2)
	sw $t0, 64($t2)
	sw $t0, 68($t2)
	
	# Row 4
	addi $t2, $t2, 128 # Move $t2 down one row
	sw $t0, 0($t2)
	sw $t0, 12($t2)
	sw $t0, 20($t2)
	sw $t0, 32($t2)
	sw $t0, 40($t2)
	sw $t0, 60($t2)
	sw $t0, 72($t2)
	
	# Row 5
	addi $t2, $t2, 128 # Move $t2 down one rows
	sw $t0, 0($t2)
	sw $t0, 4($t2)
	sw $t0, 8($t2)
	sw $t0, 12($t2)
	sw $t0, 24($t2)
	sw $t0, 28($t2)
	sw $t0, 40($t2)
	sw $t0, 44($t2)
	sw $t0, 48($t2)
	sw $t0, 52($t2)
	sw $t0, 60($t2)
	sw $t0, 72($t2)
	
	jal DrawFromBuffer
	
	# Sound effect!
	addi $v0, $zero, 33 # Service 33
	addi $a0, $zero, 70 # Pitch, 0-127
	addi $a1, $zero, 300 # Duration of sound in ms
	addi $a2, $zero, 13 # Instrument, 0-127
	addi $a3, $zero, 60 # Volume, 0-127
	syscall
	
	addi $v0, $zero, 33 # Service 33
	addi $a0, $zero, 69 # Pitch, 0-127
	addi $a1, $zero, 300 # Duration of sound in ms
	addi $a2, $zero, 13 # Instrument, 0-127
	addi $a3, $zero, 60 # Volume, 0-127
	syscall
	
	addi $v0, $zero, 33 # Service 33
	addi $a0, $zero, 68 # Pitch, 0-127
	addi $a1, $zero, 300 # Duration of sound in ms
	addi $a2, $zero, 13 # Instrument, 0-127
	addi $a3, $zero, 60 # Volume, 0-127
	syscall
	
	addi $v0, $zero, 33 # Service 33
	addi $a0, $zero, 67 # Pitch, 0-127
	addi $a1, $zero, 300 # Duration of sound in ms
	addi $a2, $zero, 13 # Instrument, 0-127
	addi $a3, $zero, 60 # Volume, 0-127
	syscall
	
	j wait_for_start
	
Exit:
	li $v0, 10 # terminate the program gracefully
	syscall
