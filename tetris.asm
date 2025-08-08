# ------------------------------------------------------------------------------------------------------------
# Parts of this file are left out in accordance with university guidelines.
#
# Below will be the controls I am comfortable with:
# 
# J,L - Move left and right
# K - Soft drop
# Space - Hard drop
# D - Rotate clockwise
# A - Rotate counterclockwise
# F - Swap to next piece
#
# Other notes:
# Since the width of the bitmap is 128 bits with each unit being 8x8,
# there will be 128 / 8 = 16 units horizontally.
#           and 256 / 8 = 32 units vertically.
# Jstris provides 10 units on the width, so we will have side walls of thickness 3 units.
#                 20 units on the height, but we will still draw top and bottom walls of thickness 3 units.
# ------------------------------------------------------------------------------------------------------------

.data
# --- Immutable Data ---
ADDR_DSPL: .word 0x10008000
ADDR_KBRD: .word 0xffff0000
GREY: .word 0x00404040
DARK_GREY: .word 0x00202020
BLACK: .word 0x00000000

# Tetromino I (cyan)
i_piece:
o_piece:
s_piece:
z_piece:
    .half 0x2640    # 0010 0110 0100 0000
    .half 0xC600    # 1100 0110 0000 0000
    .half 0x4c80    # 0100 1100 1000 0000
    
# Tetromino L (orange)
l_piece:
    .half 0x2E00    # 0010 1110 0000 0000
    .half 0x4460    # 0100 0100 0110 0000
    .half 0xC440    # 1100 0100 0100 0000

# Tetromino colours
I_PIECE_colour: .word 0x00FFFF  # Cyan

# Strings for printing to console
bag_contents_msg_header: .asciiz "Generated permutation: "
newline:.asciiz "\n"
lines_cleared_msg_header: .asciiz "Lines cleared: "

# Game over bitmap
u_lose_bitmap:
     # Row 0: 0000000000000000
    .word 0xFFFFFF00, 0xFFFFFF00, 0xFFFFFF00, 0xFFFFFF00, 0xFFFFFF00, 0xFFFFFF00, 0xFFFFFF00, 0xFFFFFF00, 0xFFFFFF00, 0xFFFFFF00, 0xFFFFFF00, 0xFFFFFF00, 0xFFFFFF00, 0xFFFFFF00, 0xFFFFFF00, 0xFFFFFF00
    # Row 1: 1000111011101110
    .word 0xFF000000, 0xFFFFFF00, 0xFFFFFF00, 0xFFFFFF00, 0xFF000000, 0xFF000000, 0xFF000000, 0xFFFFFF00, 0xFF000000, 0xFF000000, 0xFF000000, 0xFFFFFF00, 0xFF000000, 0xFF000000, 0xFF000000, 0xFFFFFF00
    # Row 2: 1000101010001000
    .word 0xFF000000, 0xFFFFFF00, 0xFFFFFF00, 0xFFFFFF00, 0xFF000000, 0xFFFFFF00, 0xFF000000, 0xFFFFFF00, 0xFF000000, 0xFFFFFF00, 0xFFFFFF00, 0xFFFFFF00, 0xFF000000, 0xFFFFFF00, 0xFFFFFF00, 0xFFFFFF00
    .word 0xFF000000, 0xFFFFFF00, 0xFFFFFF00, 0xFFFFFF00, 0xFF000000, 0xFFFFFF00, 0xFF000000, 0xFFFFFF00, 0xFF000000, 0xFFFFFF00, 0xFFFFFF00, 0xFFFFFF00, 0xFF000000, 0xFFFFFF00, 0xFFFFFF00, 0xFFFFFF00
    # Row 4: 1000101011101110
    .word 0xFF000000, 0xFFFFFF00, 0xFFFFFF00, 0xFFFFFF00, 0xFF000000, 0xFFFFFF00, 0xFF000000, 0xFFFFFF00, 0xFF000000, 0xFF000000, 0xFF000000, 0xFFFFFF00, 0xFF000000, 0xFF000000, 0xFF000000, 0xFFFFFF00
    # Row 5: 1000101000100010
    .word 0xFF000000, 0xFFFFFF00, 0xFFFFFF00, 0xFFFFFF00, 0xFF000000, 0xFFFFFF00, 0xFF000000, 0xFFFFFF00, 0xFFFFFF00, 0xFFFFFF00, 0xFF000000, 0xFFFFFF00, 0xFFFFFF00, 0xFFFFFF00, 0xFF000000, 0xFFFFFF00
    .word 0xFFFFFF00, 0xFFFFFF00, 0xFFFFFF00, 0xFFFFFF00, 0xFFFFFF00, 0xFFFFFF00, 0xFFFFFF00, 0xFFFFFF00, 0xFFFFFF00, 0xFFFFFF00, 0xFFFFFF00, 0xFFFFFF00, 0xFFFFFF00, 0xFFFFFF00, 0xFFFFFF00, 0xFFFFFF00
    
# --- Mutable Data ---
CUR_PIECE_row: .word 0  # value of current piece's row idx
CUR_PIECE_col: .word 0  # value of current piece's col idx, (rol,col) denotes the top left of thee 4x4 grid housing the tetromino
CUR_PIECE_colour: .word 0

FRAME_COUNT: .word 0
NUM_GRAV_COLLISIONS: .word 0

BAG: .space 28  # the array to store the result (7 words)
BAG_INDEX: .word 0  # [0,6]

LINE_BUFFER: .space 40  # 10 cells
CONDENSATION: .space 1040  # 26 rows of 10 cells, 26 * 40 = 1040
CONDENSATION_SIZE: .word 0
NUM_LINES_CLEARED: .word 0

##############################################################################
.text
.globl main


# -----	block start
main:
    lw $s7, ADDR_DSPL  # s7 will act as a global var we never modify for the rest of the program
    li $s6, 0  # s6 will also act as a global var indicating whether the cur. piece is a shadow piece (1 if shadow piece)
    
    jal draw_walls
    jal draw_entire_grid
    jal prep_bag
    
    j game_loop
# -----	block end


# -----	block start
game_loop:
	jal update_frame_count
	jal handle_spawn_piece
	jal handle_gravity
	jal handle_keyboard_input
	jal sleep
    b game_loop
# ----- block end


# -----	block start
draw_walls:
	lw $t1, GREY
	li $t4, 0  # row_idx = 0, starting row index
    li $t8, 0  # col_idx
    li $t9, 16  # col_end
    j col_loop
    
col_loop:
    beq $t8, $t9, col_done
    # Calculate unit offset: t7 = (row_idx * width + col_idx) * 4
    mul $t7, $t4, 16
    add $t7, $t7, $t8
    mul $t7, $t7, 4
    add $t7, $t7, $s7  # t7 += ADDR_DSPL
    # Write the grey unit to memory
    sw $t1, 0($t7)
	addi $t8, $t8, 1  # col_idx++
    j col_loop

col_done:
    addi $t4, $t4, 1  # row_start++
    # Check if we've reached row_end
    beq $t4, 3, top_wall_done
    beq $t4, 32, bottom_wall_done
    # Check if row_idx == 29 and col_idx == 3, meaning left wall is finished
    # No walls done drawing, so continuing finishing current wall
    # Check if s3 == 1
    beq $s3, 1, case_draw_right_wall
case_draw_non_right_walls:
    li $t8, 0  # col_idx = 0
    j col_loop
case_draw_right_wall:
	li $t8, 13 
	j col_loop

top_wall_done:
	li $t4, 29  # go to bottom wall
	li $t8, 0
	li $t9, 16
	j col_loop
bottom_wall_done:
	li $t4, 3  # go to left wall
	li $t8, 0
	li $t9, 3
	j col_loop
left_wall_done:
	li $t4, 3  # go to right wall
	li $t8, 13
	li $t9, 16
	li $s3, 1  # s3 will be a flag indicating we are currently drawing the right wall
    j col_loop
draw_walls_done:
	jr $ra
# ----- block end


# -----	block start
draw_entire_grid:
	# Prep t0 and t1 for drawing the grid
    li $t0, 3
    li $t1, 29
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    jal draw_grid
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra
# -----	block end


# ----- block start
draw_grid:
	## Will work assuming that already...
	## $t0 stores starting row
	## $t1 stores ending row
	## Note. this routine forcefully draws the entire list of rows
	
	lw $t2, DARK_GREY
	lw $s2, BLACK
	li $t3, 3  # col_idx
	j draw_grid_helper

draw_grid_helper:
cur_row_is_odd:
cur_row_is_even:
grid_loop_done:
	addi $t0, $t0, 1  # row_idx++
	beq $t0, $t1, draw_grid_done
	li $t3, 3
	beq $s0, 0, alternate_grid_pattern
	li $s0, 0
	j draw_grid_helper
alternate_grid_pattern:
	li $s0, 1
	j draw_grid_helper
	
draw_grid_done:
	jr $ra
# -----	block end


# ----- block start
prep_bag:
print_loop:
print_done:
generate_permutation:
outer_loop:
retry_label:
    # Generate a random number 'r' between 0 and 6
    li $v0, 41  # Syscall for random int
    li $a0, 0  # Use PRNG 0
    syscall  # Random int is now in $a0
    li $a1, 7
    divu $a0, $a1  # Using modulo to ensure range is 0-6
    mfhi $t1  # $t1 = r (our random number candidate)
    li $s1, 0  # j = 0
check_duplicate_loop:
    beq $s1, $s0, found_unique  # If j == i, we've checked all existing numbers
    # Get the value at BAG[j]
    sll $t2, $s1, 2  # offset = j * 4
    j check_duplicate_loop
found_unique:
    # The number in $t1 is unique, so store it in the array
    sll $t2, $s0, 2  # offset = i * 4
    add $t3, $t0, $t2  # address = base + offset
    # Move to the next position in the array
    addi $s0, $s0, 1
    j outer_loop

    generation_done:
  lw $s1, 0($sp)
  lw $s0, 4($sp)
lw $ra, 8($sp)
  addi $sp, $sp, 12
  jr $ra
# ----- block end


# ----- block start
  update_frame_count:
  lw $t0, FRAME_COUNT
  addi $t0, $t0, 1
  sw $t0, FRAME_COUNT
  jr $ra
# ----- block end


# ----- block start
sleep:
	li $v0, 32
	li $a0, 16
	syscall
	jr $ra
# ----- block end


# ----- block start    
handle_spawn_piece:
continue_spawn_piece:
reset_BAG:
skip_reset_BAG:
load_i_piece:
    la $t2, i_piece
    lw $t3, I_PIECE_colour
    sw $t3, CUR_PIECE_colour
    j end_piece_select
load_o_piece:
    la $t2, o_piece
    lw $t3, O_PIECE_colour
    sw $t3, CUR_PIECE_colour
    j end_piece_select
load_t_piece:
    la $t2, t_piece
    lw $t3, T_PIECE_colour
    sw $t3, CUR_PIECE_colour
    j end_piece_select
load_s_piece:
    la $t2, s_piece
    lw $t3, S_PIECE_colour
    sw $t3, CUR_PIECE_colour
    j end_piece_select
load_z_piece:
    la $t2, z_piece
    lw $t3, Z_PIECE_colour
    sw $t3, CUR_PIECE_colour
    j end_piece_select
load_j_piece:
    la $t2, j_piece
    lw $t3, J_PIECE_colour
    sw $t3, CUR_PIECE_colour
    j end_piece_select
load_l_piece:
    la $t2, l_piece
    lw $t3, L_PIECE_colour
    sw $t3, CUR_PIECE_colour
    j end_piece_select
    
end_piece_select:
    # Increment BAG_INDEX
    lw $t0, BAG_INDEX
    addi $t0, $t0, 1
    sw $t0, BAG_INDEX

	# Prep data into *memory* before first render of piece...
	sw $t2, CUR_PIECE_type  # t2 has been loaded into by match above
	lh $t3, 0($t2)
	sh $t3, CUR_PIECE
	sh $t3, CUR_PIECE_shadow
	li $t0, 3  # spawn point = (3,5)
	li $t1, 5
	sw $t0, CUR_PIECE_row
	sw $t1, CUR_PIECE_col	
	sw $zero, CUR_PIECE_rot  # reset rotation index
	
	addi $sp, $sp, -4
    sw $ra, 0($sp)
    jal handle_shadow
    lw $ra, 0($sp)
    addi $sp, $sp, 4
	addi $sp, $sp, -4
    sw $ra, 0($sp)
    jal draw_piece
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    
    li $t0, 0  # set dropped status to 0
	sw $t0, CUR_PIECE_dropped
	j spawn_piece_done
	
spawn_piece_done:
	jr $ra
# ----- block end


# ----- block start	
load_cur_piece_data:
load_cur_piece_continue:
load_shadow_piece:
draw_piece:
	## Assumptions coming in ...
	## Loop counter is inited to 0 at $t8
	## All data pertaining to the current piece is written in memory already, including:
	## Starting (r,c)
	## The piece itself
	## Its colour
	## etc.
	
	# Loading piece data from memory...
    # Finally draw the piece
draw_piece_helper:
	# Where the actual recursion/loop takes place...
	beq $t8, 16, draw_piece_done
	and $t9, $t4, $t6
	beqz $t9, skip_draw
	# Bit mask matched, compute unit offset
	# Get row and col inside 4x4 grid from loop counter
	li $t2, 4
	div $t8, $t2
	mflo $t2  # row = loop counter / 4
	mfhi $t3  # col = loop counter % 4
	# Add these onto the starting coordinates (hardcoded for spawning, loaded from CUR_PIECE_row and col otherwise)
	add $t2, $t2, $s0  # starting row=3 for spawning
	add $t3, $t3, $s1  # starting col=5 for spawning
	# Compute unit offset - (row * 16 + col) * 4
	mul $t7, $t2, 16
    mul $t7, $t7, 4
    # Draw the tetromino's cell to bitmap
    sw $t5, 0($t7)
skip_draw:
	srl $t6, $t6, 1
	addi $t8, $t8, 1
	j draw_piece_helper
	
draw_piece_done:	
	jr $ra
# ----- block end


# ----- block start	
erase_piece:
	## In order to preserve the bg grid, employ the following rule:
	## (odd,odd) -> darkgrey
	## (odd,even) -> black
	## (even,odd) -> black
	## (even,even) -> darkgrey
	## where (r,c) are logical coordinates and not the unit offsets
	
	# Loading piece data from memory...
erase_piece_helper:
	# Set the right cell colour using fix_grid_pattern
	# This routine will modify s2-5 inclusive, but we don't use them so 
	# no need to caller-save.
	move $a0, $t2
	move $a1, $t3
	move $a2, $t7
	addi $sp, $sp, -4
	sw $ra, 0($sp)
	jal fix_grid_pattern
	lw $ra, 0($sp)
    addi $sp, $sp, 4
skip_erase:
fix_grid_pattern:
r_odd_c_odd:
r_odd_c_even:
r_even:
r_even_c_odd:
r_even_c_even:
skip_fix:
erase_piece_done:
# ----- block end 


# ----- block start
handle_shadow:
	## Idea: First load in current piece's (r,c), then set the shadow's (r,c) to match.
	##       Then continuously check for collisions while shifting the shadow downwards.
	## The shadow should be only be drawn once when a piece is spawned and 
	## re-drawn on movement (left,right,rotation).
	## This is better for performance and prevents a tearing effect
	## when both are drawn repetitively over one another.
	## Note that pieces are only redrawn on movement as well.
	## Note. the shadow is always drawn first before the piece itself, and 
	##       the piece is allowed to "collide" (draw) over the shadow.
	
	# Set shadow register to 1
	
	# Erase current shadow, unless piece just spawned
erase_current_shadow:
handle_shadow_continue:
handle_shadow_helper:
draw_shadow:
handle_shadow_collision:
	lw $t0, CUR_PIECE_shadow_row
    addi $t0, $t0, -1
    sw $t0, CUR_PIECE_shadow_row
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    jal draw_piece
    lw $ra, 0($sp)
    addi $sp, $sp, 4
	j handle_shadow_done
    
handle_shadow_done:
	li $s6, 0
	jr $ra
# ----- block end 

	
# ----- block start	
handle_gravity:
	## Move current piece down every second	
	# Load frame count
	lw $t0, FRAME_COUNT
    li $t1, 32
    blt $t0, $t1, gravity_done  # Wait until 32 frames passed
    # Reset frame counter
    li $t0, 0
    sw $t0, FRAME_COUNT

    # Erase current piece
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    jal erase_piece
    lw $ra, 0($sp)
    addi $sp, $sp, 4
	# Increment current piece row 
    lw $t0, CUR_PIECE_row
    addi $t0, $t0, 1  # try moving down (row + 1)
    sw $t0, CUR_PIECE_row
    # Check collision
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    jal check_collision
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    beq $v0, 1, restore_gravity  # back out early due to collision
    j continue_gravity
restore_gravity:
	lw $t0, CUR_PIECE_row
    addi $t0, $t0, -1
    sw $t0, CUR_PIECE_row
    # In addition, increment NUM_GRAV_COLLISIONS
    lw $t0, NUM_GRAV_COLLISIONS
    addi $t0, $t0, 1
    sw $t0, NUM_GRAV_COLLISIONS
    # And check if it has reached threshold
    bgt $t0, 10, lock_piece
    j continue_gravity
lock_piece:
	# Draw new piece
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    jal draw_piece
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    # Check for line clears
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    jal handle_line_clear
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    # Check for game over 
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    jal handle_game_over
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    # Set metadata
	lw $t1, CUR_PIECE_dropped
	li $t1, 1
	sw $t1, CUR_PIECE_dropped  # this will trigger a new piece to spawn
	li $t0, 0
	sw $t0, NUM_GRAV_COLLISIONS
	j gravity_done
continue_gravity:
    # Draw new piece
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    jal draw_piece
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    j gravity_done
	
gravity_done:
    jr $ra
# ----- block end


# ----- block start
handle_keyboard_input:
	lw $t0, ADDR_KBRD  # $t0 = base address for keyboard
    lw $t8, 0($t0)  # Load first word from keyboard
    beq $t8, 1, keyboard_input  # If first word 1, key is pressed
    j handle_input_done

keyboard_input:
    lw $a0, 4($t0)  # load second word from keyboard
    beq $a0, 0x6a, handle_Left  # J
    beq $a0, 0x6c, handle_Right  # L
    beq $a0, 0x6b, handle_Down  # K
    beq $a0, 0x20, handle_Harddrop  # Space
    beq $a0, 0x61, rotCcw  # A
    beq $a0, 0x64, rotCw  # D
    beq $a0, 0x66, handle_Hold  # F
    beq $a0, 0x71, handle_Quit  # Q
    j handle_input_done

handle_Left:
	# Erase current piece    
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    jal erase_piece
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    # Decrement current piece col
    lw $t0, CUR_PIECE_col
    addi $t0, $t0, -1
    sw $t0, CUR_PIECE_col
    # Check collision
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    jal check_collision
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    beq $v0, 1, restore_left  # back out early due to collision
    j continue_left
restore_left:
continue_left:
handle_Right:
restore_right:
continue_right:
handle_Harddrop:
	## Basically just replace the shadow piece with the current piece.
	## Set current piece's (r,c) to shadow's.
	## No need to handle_shadow because the shadow will just be covered up.
	## And spawn_piece will spawn draw the new piece's shadow and piece next.
	
	# Erase current piece
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    jal erase_piece
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    # Set new (r,c) for current piece
	lw $t0, CUR_PIECE_shadow_row
	lw $t1, CUR_PIECE_shadow_col
	sw $t0, CUR_PIECE_row
	sw $t1, CUR_PIECE_col
	# Draw the piece
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    jal draw_piece
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    # Check for line clears
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    jal handle_line_clear
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    # Check for game over 
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    jal handle_game_over
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    # Set metadata
	lw $t1, CUR_PIECE_dropped
	li $t1, 1
	sw $t1, CUR_PIECE_dropped  # this will trigger a new piece to spawn
	j handle_input_done
	
rotCcw:
	## Incrementing through each piece's stored rotations is in order of CW.
	## A is CCW, so decrement.
	
	# Erase current piece
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    jal erase_piece
    lw $ra, 0($sp)
    addi $sp, $sp, 4
	# Update rotation index
	lw $t0, CUR_PIECE_rot
	addi $t0, $t0, -1
	bltz $t0, fix_ccw_index
	j apply_rot
fix_ccw_index:
	addi $t0, $t0, 4  # -1 + 4 = 3
apply_rot:
restore_rot:
    sw $s5, CUR_PIECE
continue_rot:
rotCw:
	# Erase current piece
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    jal erase_piece
    lw $ra, 0($sp)
    addi $sp, $sp, 4
	# Update rotation index
	lw $t0, CUR_PIECE_rot
	addi $t0, $t0, 1
	beq $t0, 4, fix_cw_index
	j apply_rot
fix_cw_index:
	addi $t0, $t0, -4  # 4 - 4 = 0
	j apply_rot
	
handle_Down:
	lw $t0, FRAME_COUNT
	addi $t0, $t0, 20
	sw $t0, FRAME_COUNT
	j handle_input_done
	
handle_Hold:
	## Actually just allows you to hold as much as you want,
	## and the holding is just switching to the next piece in the bag.
	
	# Erase the shadow
handle_Quit:
	li $v0, 10
	syscall
	
handle_input_done:
	jr $ra
# ----- block end


# ----- block start
check_collision:
	## Checks if the current piece is colliding with:
	## - A wall
	## - Other placed pieces
	## That's it.
	## Assumptions coming in ...
	## Any movement/rotations are applied in memory already.
	
	addi $sp, $sp, -4
    sw $ra, 0($sp)
    jal load_cur_piece_data
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    j check_collision_helper
    
check_collision_helper:
	## Loop over the piece using bitmask prepped by load_cur_piece_data
    ## If the current piece overlaps with a cell that is NOT(BLACK OR DARKGREY OR CUR_PIECE_shadow_colour), then collision.
    ## As BLACK and DARKGREY or CUR_PIECE_shadow_colour cells are the only cells a piece can occupy
    ## Note that if the current piece is a shadow piece we allow shadow pieces to 
    ## "collide" with themselves, so no need to reference s6 here.
    
	and $t9, $t4, $t6
	li $t2, 4
	mflo $t2  # row = loop counter / 4
	mfhi $t3  # col = loop counter % 4
	# Add these onto the starting coordinates
	add $t3, $t3, $s1
	# Compute unit offset - (row * 16 + col) * 4
	mul $t7, $t2, 16
    mul $t7, $t7, 4
    add $t7, $t7, $s7
    # **Check current cell colour
    lw $t0, DARK_GREY
    lw $t2, CUR_PIECE_shadow_colour
    j skip_check  # IS darkgrey, so no collision on this cell
not_darkgrey:
neither_black_nor_darkgrey:
neither_black_nor_darkgrey_nor_shadowcolour:  # collision
skip_check:
check_collision_fail:	
check_collision_success:
# ----- block end


# ----- block start
handle_line_clear:
	## Will have 2 phases...
	## -- Phase 1: --
	## Loop from bottom row to top row, checking for completed lines.
	## If we encounter a cell that is not occupied by a piece, then the line is incomplete.
	## We save the row to memory.
	## Otherwise if the current row is complete, ignore it, and also set a flag to re-draw entire grid.
	## Memory will now contain the set of pieces after condensation (when everything drops after the lines are cleared).
	## Check the flag above to see if we need to re-draw the scene at all.
	## If yes, move on to Phase 2.
	## -- Phase 2: --
	## First wipe the entire grid using draw_entire_grid.
	## Finally loop through the condensation until 'condensation_size' and draw it onto the bitmap.
	
	addi $sp, $sp, -4
    sw $ra, 0($sp)
    jal phase1
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    # Once phase 1 is done, check s4 to proceed to phase 2 or not.
    beq $s4, 1, go_to_phase2
	jr $ra  # else, no line clears occurred so finish the handler.
go_to_phase2:
phase1:
phase1_helper:
row_incomplete:
write_to_LINE_BUFFER:
phase1_loop_done:
row_was_incomplete:
	# Push incomplete row to condensation
	addi $sp, $sp, -4
	sw $ra, 0($sp)
	jal save_to_condensation
	lw $ra, 0($sp)
    addi $sp, $sp, 4
   	j phase1_helper
	
animate_line_clear:
	addi $t0, $t0, 1  # revert the row_idx decrement 
	j animate_line_clear_helper
	
animate_line_clear_helper:
	beq $t5, 13, animate_line_clear_done
	# Calculate unit offset: t7 = (row_idx * width + col_idx) * 4
    mul $t7, $t0, 16
    add $t7, $t7, $t5
    mul $t7, $t7, 4
    add $t7, $t7, $s7
	lw $t8, LINE_CLEAR_colour
  	sw $t8, 0($t7)  # Write line clear colour to bitmap
  	# Sleep for a bit...
  	li $v0, 32
	li $a0, 32
	syscall
	addi $t5, $t5, 1
  	j animate_line_clear_helper
  	
animate_line_clear_done:
	addi $t0, $t0, -1  # decrement row_idx (restore)
	li $t5, 3  # restore col_idx
	# Sleep for a bit in case chain of line clears...
  	li $v0, 32
	li $a0, 48
	syscall
	jr $ra
	
save_to_condensation:
	li $s3, 1  # reset s3, default it to "row is complete" until we find that it isn't
	# Save registers
	addi $sp, $sp, -24
	sw $t0, 0($sp)
	sw $t1, 4($sp)
	sw $t2, 8($sp)
	sw $t3, 12($sp)
	sw $t4, 16($sp)
	sw $t5, 20($sp)
	# Prep arguments for save_to_condensation_helper
	li $t0, 0  # basically col index
	# Call it
	addi $sp, $sp, -4
	sw $ra, 0($sp)
	jal save_to_condensation_helper
	lw $ra, 0($sp)
    addi $sp, $sp, 4
    # Restore registers
    lw $t0, 0($sp)
	lw $t1, 4($sp)
	lw $t2, 8($sp)
	lw $t3, 12($sp)
	lw $t4, 16($sp)
	lw $t5, 20($sp)
	addi $sp, $sp, 24
	jr $ra
    
save_to_condensation_helper:
	# Loop through line buffer and write to 'condensation'
	beq $t0, 10, save_to_condensation_done  # read next row
	# Get address of current element in line buffer
	la $s1, LINE_BUFFER
	mul $t1, $t0, 4
	add $t1, $t1, $s1
	# Read from the line buffer
	lw $t2, 0($t1)
	# Save into 'condensation'
	la $t3, CONDENSATION
	lw $t4, CONDENSATION_SIZE
	# Get address of current top of 'condensation'
	add $t5, $t4, $t3
	sw $t2, 0($t5)  # finally push into 'condensation'
	# Update condensation_size
	addi $t4, $t4, 4
	sw $t4, CONDENSATION_SIZE
	# Increment col index
	addi $t0, $t0, 1
	j save_to_condensation_helper
save_to_condensation_done:
	jr $ra
	
phase1_done:
	jr $ra
	
phase2:
	# Wipe the scene
	addi $sp, $sp, -4
    sw $ra, 0($sp)
    jal draw_entire_grid
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    # While looping through the bitmap, also loop through the condensation and draw to it.
    li $t0, 28  # row_idx
    li $t1, 3  # col_idx
    li $t2, 0  # basically col_idx that will be used as the loop counter
    li $s1, 0  # condensation_idx that increments by 4 on each cell traversal
    j phase2_helper
    
phase2_helper:
	beq $t1, 13, phase2_loop_done
	# Calculate unit offset: t7 = (row_idx * width + col_idx) * 4
    mul $t7, $t0, 16
    add $t7, $t7, $t1
    mul $t7, $t7, 4
    add $t7, $t7, $s7
    # Grab the current colour inside condensation using condensation_idx
	la $t4, CONDENSATION
	add $t4, $t4, $s1
	lw $t6, 0($t4)  # t6 now holds the condensation cell colour
	# If the cell was black or darkgrey, fix its pattern first
	move $a0, $t0
	move $a1, $t1
	move $a2, $t7
	lw $s4, DARK_GREY
	lw $s5, BLACK
	beq $t6, $s4, fix_phase2_grid_pattern
	beq $t6, $s5, fix_phase2_grid_pattern
	# Otherwise, write to bitmap
	sw $t6, 0($t7)
	j skip_fix_phase2_grid_pattern
fix_phase2_grid_pattern:
skip_fix_phase2_grid_pattern:
phase2_loop_done:
phase2_done:
	# Print the num lines cleared message
    li $v0, 4
    la $a0, lines_cleared_msg_header
    syscall
	lw $a0, NUM_LINES_CLEARED  # load the number into $a0 for printing
    # Print the number
    li $v0, 1
    syscall
    # Print newline
    li $v0, 4
    la $a0, newline
    syscall
	jr $ra
# ----- block end


# ----- block start
handle_game_over:
	## Checks if game over (any part of the top wall contains a coloured cell)
	li $t0, 5  # row_idx = 5 however, to work around the spawning issue...
	li $t1, 3  # col_idx
	j handle_game_over_helper
	
handle_game_over_helper:
	beq $t1, 13, handle_game_over_done
	# Compute unit offset - (row * 16 + col) * 4
	mul $t7, $t0, 16
    add $t7, $t7, $t1
    mul $t7, $t7, 4
    add $t7, $t7, $s7
    # **Check current cell colour
    lw $s2, 0($t7)
    lw $s3, DARK_GREY
    lw $s4, BLACK
    beq $s2, $s3, continue_game_over_helper
    beq $s2, $s4, continue_game_over_helper
    j trigger_game_over
continue_game_over_helper:
	addi $t1, $t1, 1  # increment col_idx
	j handle_game_over_helper
	
trigger_game_over:
	addi $sp, $sp, -4
    sw $ra, 0($sp)
    jal draw_game_over_screen
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    j handle_Retry
   
handle_Retry:
	lw $t0, ADDR_KBRD  # $t0 = base address for keyboard
    lw $t8, 0($t0)  # Load first word from keyboard
    beq $t8, 1, retry_input  # If first word 1, key is pressed
	j handle_Retry  # loop until player chooses to retry
	
retry_input:
	lw $a0, 4($t0)
	# Reset some essential global vars before restarting game...
	lw $t1, CUR_PIECE_dropped
	li $t1, 1
	sw $t1, CUR_PIECE_dropped  # this will trigger a new piece to spawn
	lw $t1, NUM_LINES_CLEARED
	li $t1, 0
	sw $t1, NUM_LINES_CLEARED
	beq $a0, 0x72, main
	j handle_Retry
   
draw_game_over_screen:
	la $s0, u_lose_bitmap
	li $t0, 10  # start at row_idx = 10
	li $t1, 0  # col_idx
	
draw_game_over_screen_helper:
	beq $t1, 16, draw_game_over_screen_loop_done
	# Get addr. of current element of u_lose_bitmap
	# Must subtract row_idx by 13 first
	addi $t2, $t0, -10
	# Use same formula - (row * 16 + col) * 4
	mul $t7, $t2, 16
    add $t7, $t7, $t1
    mul $t7, $t7, 4
    add $t7, $t7, $s0  # add everything onto addr. of u_lose_bitmap
    # Load colour at u_lose_bitmap
    lw $s1, 0($t7)
    # Write that to the main bitmap display
    # Compute unit offset - (row * 16 + col) * 4
	mul $t7, $t0, 16
    add $t7, $t7, $t1
    mul $t7, $t7, 4
    add $t7, $t7, $s7  # add everything onto addr. of ADDR_BITMAP (or whatever it was)
    sw $s1, 0($t7)
    
    addi $t1, $t1, 1  # increment col_idx
    j draw_game_over_screen_helper
    
draw_game_over_screen_loop_done:
	addi $t0, $t0, 1  # increment row_idx
	beq $t0, 19, draw_game_over_screen_done
	li $t1, 0  # reset col_idx
	j draw_game_over_screen_helper
	
draw_game_over_screen_done:
	jr $ra
	
handle_game_over_done:
	## If code reaches here then the entire row was checked and no piece went
	## past the top wall.
	## So continue game as usual.
	jr $ra
# ----- block end
