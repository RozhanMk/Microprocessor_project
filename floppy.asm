.MODEL SMALL
.STACK 64
	.DATA
WINDOW_WIDTH DW 140H
WINDOW_LENGTH DW 0C8H
HALF_WINDOW_WIDTH DW 050H
TIME_AUX DB 0
SEED DW 1234D
BIRD_X DW  0CH	
BIRD_Y DW  0CH
BIRD_INITIAL_X DW 0AH
BIRD_INITIAL_Y DW 64H
BIRD_SIZE DW 06H
BIRD_VELOCITY_Y DW 02H
JUMP_VELOCITY DW 18H
EARLY_DETECTION DW 06H
BLOCKS_X DW 120H, 100H, 80H
BLOCKS_Y DW 0FH, 45H, 0A8H
BLOCKS_COUNT DW 5H, 1H, 2H
BLOCK_X DW 0
BLOCK_Y DW 0
BLOCK_WIDTH DW 03H
BLOCK_LENGTH DW 0CH
BLOCK_COUNT DW 1H
BLOCK_INDEX DW 0H
BLOCK_VELOCITY_X DW 02H
CEILING_X DW 00H
CEILING_Y DW 0AH
CEILING_WIDTH DW 140H
POINTS DB 0H
POINTS_STRING DB '0','0','0','$'
SCREEN_DELAY DB 02h

	.CODE 
MAIN	PROC FAR
    MOV AX,@DATA            ;initialize DS
	MOV DS,AX
	
	CALL CLEAR_SCREEN
	CHECK_TIME:
		MOV AH, 2CH	;get system time
		INT 21H
		CMP DL, TIME_AUX ; current time equal to previous or not?
		JE CHECK_TIME
		MOV TIME_AUX, DL ; update time

		CALL CLEAR_SCREEN ; erase the trial of pixels when moving
		CALL UPDATE_POINTS
		CALL WRITE_POINTS
		CALL DRAW_CEILING
		CALL DRAW_BIRD
		CALL DRAW_ALL_BLOCKS

		MOV AL,SCREEN_DELAY
        CALL DELAY

		CALL MOVE_BIRD
		CALL MOVE_ALL_BLOCKS
		CALL CHECK_JUMP
		JMP CHECK_TIME


MAIN ENDP

DRAW_BIRD PROC
	MOV CX, BIRD_X
	MOV DX, BIRD_Y

	DRAW_HORIZENTAL:
		MOV AH, 0CH	;writing an initial pixel
		MOV AL, 0FH	; white color
		MOV BH, 00H	;set page num
		INT 10H

		INC CX
		MOV AX, BIRD_SIZE
		ADD AX, BIRD_X	;now we add size to the x to calculate width
		CMP CX, AX
		JNG DRAW_HORIZENTAL

	MOV CX, BIRD_X
	DRAW_VERTICAL:
		INC DX
		MOV AX, BIRD_SIZE
		ADD AX, BIRD_Y	;now we add size to the y to calculate height
		CMP DX, AX
		JNG DRAW_HORIZENTAL
	RET
DRAW_BIRD ENDP

DRAW_ALL_BLOCKS PROC
	MOV AX, 0
	MOV BLOCK_INDEX, AX
	EACH_BLOCK:
		MOV SI, OFFSET BLOCKS_X
		MOV DI, OFFSET BLOCKS_Y
		MOV BX, OFFSET BLOCKS_COUNT

		ADD SI, BLOCK_INDEX
		ADD DI, BLOCK_INDEX
		ADD BX, BLOCK_INDEX

		MOV AX, [SI] 
		MOV BLOCK_X, AX
		MOV AX, [DI]
		MOV BLOCK_Y, AX
		MOV AX, [BX]
		MOV BLOCK_COUNT, AX
		
		CALL DRAW_BLOCK
		ADD BLOCK_INDEX, 2H		; add 2 to index cause we have word arrays
		CMP BLOCK_INDEX, 4H		; there are only 3 blocks at any time
		JLE EACH_BLOCK
	RET
DRAW_ALL_BLOCKS ENDP

DRAW_BLOCK PROC NEAR
	MOV SI, BLOCK_COUNT
	MOV AX, BLOCK_LENGTH
	MUL SI
	MOV SI, AX		;SI is the length of block(based on block_count)
	MOV CX, BLOCK_X
	MOV DX, BLOCK_Y

	DRAW_HORIZENTAL:
		MOV AH, 0CH	;writing an initial pixel
		MOV AL, 0AH	; green color
		MOV BH, 00H	;set page num
		INT 10H

		INC CX
		MOV AX, BLOCK_WIDTH
		ADD AX, BLOCK_X
		CMP CX, AX
		JNG DRAW_HORIZENTAL

	MOV CX, BLOCK_X
	DRAW_VERTICAL:
		INC DX
		MOV AX, SI		; SI is currently the new block_length
		ADD AX, BLOCK_Y	
		CMP DX, AX
		JNG DRAW_HORIZENTAL

	RET
DRAW_BLOCK ENDP

MOVE_BIRD PROC
	MOV AX, BIRD_VELOCITY_Y	; move bird
	ADD BIRD_Y, AX

	MOV AX, BIRD_Y ; detect when bird hits the floor
	ADD AX, BIRD_SIZE
	CMP AX, WINDOW_LENGTH
	JGE RESET_BIRD
	
	MOV AX, 0
	ADD AX, BIRD_SIZE
	ADD AX, EARLY_DETECTION
	ADD AX, CEILING_Y
	CMP BIRD_Y, AX	; detect when bird hits the ceiling
	JLE RESET_BIRD

	MOV SI, OFFSET BLOCKS_X
	MOV DI, OFFSET BLOCKS_Y
	MOV BX, OFFSET BLOCKS_COUNT
	MOV CX, 03H
	EACH_BLOCK: ; detect collision with the blocks
		MOV AX, [SI] 
		MOV BLOCK_X, AX
		MOV AX, [DI]
		MOV BLOCK_Y, AX
		MOV AX, [BX]
		MOV BLOCK_COUNT, AX

		MOV AX, BIRD_X
		ADD AX, BIRD_SIZE
		CMP AX, BLOCK_X	
		JNG NO_COLLISION
		
		MOV AX, BLOCK_X
		ADD AX, BLOCK_WIDTH
		CMP BIRD_X, AX
		JNL NO_COLLISION
		
		MOV AX, BIRD_Y
		ADD AX, BIRD_SIZE
		CMP AX, BLOCK_Y
		JNG NO_COLLISION
		
		MOV DX, BLOCK_LENGTH
		MOV AX, BLOCK_COUNT
		MUL DX		; AX contains block_length
		ADD AX, BLOCK_Y
		CMP BIRD_Y, AX
		JNL NO_COLLISION
		
		; if it reaches this point, there is a collision
		MOV POINTS, 0
		CALL RESET_BIRD_POS
		RET
		; if this get called, there is no collisions
		NO_COLLISION:
			ADD SI, 2H
			ADD DI, 2H
			ADD BX, 2H
			LOOP EACH_BLOCK
	; if it reaches here, our bird is healthy *-*
	RET


	RESET_BIRD:
		MOV POINTS, 0
		CALL RESET_BIRD_POS
		RET 
	
MOVE_BIRD ENDP

MOVE_ALL_BLOCKS PROC NEAR
	MOV AX, 0
	MOV BLOCK_INDEX, AX
	EACH_BLOCK:
		MOV SI, OFFSET BLOCKS_X
		MOV DI, OFFSET BLOCKS_Y
		MOV BX, OFFSET BLOCKS_COUNT

		ADD SI, BLOCK_INDEX
		ADD DI, BLOCK_INDEX
		ADD BX, BLOCK_INDEX

		MOV AX, [SI] 
		MOV BLOCK_X, AX
		MOV AX, [DI]
		MOV BLOCK_Y, AX
		MOV AX, [BX]
		MOV BLOCK_COUNT, AX
		
		CALL MOVE_BLOCK
		ADD BLOCK_INDEX, 2H
		CMP BLOCK_INDEX, 4H		; there are only 3 blocks on screen
		JLE EACH_BLOCK
	RET
	
MOVE_ALL_BLOCKS ENDP
	
MOVE_BLOCK PROC NEAR
	MOV AX, BLOCK_VELOCITY_X	
	SUB BLOCK_X, AX				; move block to left horizentally
	MOV SI, OFFSET BLOCKS_X
	ADD SI, BLOCK_INDEX
	MOV DX, BLOCK_X
	MOV [SI], DX

	CMP BLOCK_X, 0
	JL CREATE_BLOCK				; detect when block exits the screen

	RET
	
	CREATE_BLOCK:
		CALL CREATE_NEW_BLOCK
		RET
MOVE_BLOCK ENDP

CREATE_NEW_BLOCK PROC
	RANDOM_COUNT:
		MOV AH, 2CH
		INT 21H
		MOV AL,DL
		MOV AH,0
		MOV CL,20
		DIV CL
		MOV BL, AL
		INC BL	;BL is between 1 and 5 as the new block_count


	MOV SI, OFFSET BLOCKS_COUNT
	ADD SI, BLOCK_INDEX
	MOV [SI], BL
	
	MOV SI, OFFSET BLOCKS_X
	ADD SI, BLOCK_INDEX
	MOV AX, WINDOW_WIDTH
	MOV [SI], AX

	;//TO DO: CHOOSE BLOCK_Y RANDOMLY//
	RANDOM_Y:
		mov ax, SEED   
		mov cx, 11021D  ; Multiplier
		mov dx, 2213D   ; Increment
		mov bx, 131D   ; Modulus

		; random number using LCG algorithm
		mul cx          ; ax = ax * cx
		add ax, dx      ; ax = ax + dx
		MOV DX, 0
		div bx          ; (remainder is the random number) dx between 0 and 130
		MOV SEED, DX
		add DX, 10D      ; Random number between 10 and 140
		
	MOV SI, OFFSET BLOCKS_Y
	ADD SI, BLOCK_INDEX
	MOV [SI], DX

	RET
CREATE_NEW_BLOCK ENDP

CHECK_JUMP PROC
	MOV AH, 01H	; check if any key is pressed
	INT 16h
	JZ NO_KEY_PRESSED	;zero in ZF if no key is pressed
	
	MOV AH, 00H ; chcek which key is pressed(AL = ascii)
	INT 16h

	CMP AL, 20H	; CHECK FOR SPACE KEY
	JE JUMP
	RET

	JUMP:
		MOV AX, JUMP_VELOCITY
		SUB BIRD_Y, AX
		INC POINTS
		RET
	NO_KEY_PRESSED:
		RET

	RET
CHECK_JUMP ENDP

RESET_BIRD_POS PROC NEAR
	MOV AX, BIRD_INITIAL_X		;get the bird to the center and left side
	MOV BIRD_X, AX

	MOV AX, BIRD_INITIAL_Y
	MOV BIRD_Y, AX

	RET
RESET_BIRD_POS ENDP


CLEAR_SCREEN PROC
	MOV AH, 00h	; set video mode
	MOV AL, 0Dh	; choose video mode
	INT 10h		; execute

	MOV AH, 0BH	; set background color
	MOV BH, 00H
	MOV BL, 00H	; black color
	INT 10H
	
	RET
CLEAR_SCREEN ENDP

DELAY PROC NEAR
    
    MOV AH,2Ch
    INT 21h
    MOV BL, DL
    WAITLOOP:
        MOV AH,2Ch
        INT 21h
        MOV CL, DL
        SUB CL, BL
        CMP CL,AL
        JB WAITLOOP
    RET
DELAY ENDP

UPDATE_POINTS PROC NEAR
    MOV AX, 0
    MOV AL, POINTS
    MOV BL,10
    DIV BL
    ADD AH, 30h
    MOV [POINTS_STRING+2],AH
	MOV AH, 0
	DIV BL
	ADD AL, 30H
	ADD AH, 30H
    MOV [POINTS_STRING],AL
	MOV [POINTS_STRING +1],AH
    RET
UPDATE_POINTS ENDP

WRITE_POINTS PROC
	MOV AH, 0EH	;function to print
	MOV BH, 00H	;page num
	MOV BL, 0FH ;white color
	
	MOV AL, [POINTS_STRING]
	INT 10H
	MOV AL, [POINTS_STRING+1]
	INT 10H
	MOV AL, [POINTS_STRING+2]
	INT 10H

	RET
WRITE_POINTS ENDP


DRAW_CEILING PROC NEAR
	MOV CX, CEILING_X
	MOV DX, CEILING_Y
	DRAW_HORIZENTAL:
		MOV AH, 0CH	;writing an initial pixel
		MOV AL, 0FH	;white color
		MOV BH, 00H	;set page num
		INT 10H
		
		INC CX
		MOV AX, CEILING_WIDTH
		ADD AX, CEILING_X	
		CMP CX, AX
		JNG DRAW_HORIZENTAL
	
	RET
DRAW_CEILING ENDP

END    MAIN       