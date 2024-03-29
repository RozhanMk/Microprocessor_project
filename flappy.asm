.MODEL SMALL
.STACK 64
	.DATA

WINDOW_WIDTH DW 140H
WINDOW_LENGTH DW 0C8H

TIME_AUX DB 0
TIME_UPDATE_PASSED DB 0
HAS_10US_PASSED DW 0
SECONDS_JUMPING DW 02H

ACCELERATION DW 01H
SEED DW 1234h

BIRD_X DW  0CH	
BIRD_Y DW  0CH
BIRD_INITIAL_X DW 0AH
BIRD_INITIAL_Y DW 64H
BIRD_SIZE DW 06H
BIRD_VELOCITY_Y DW 02H
BIRD_VELOCITY_X DW 01H	;constant

JUMP_VELOCITY_Y DW 20H
JUMP_VELOCITY_X DW 01H	;constant

BLOCKS_X DW 120H, 100H, 80H, 60h	;initial position of blocks
BLOCKS_Y DW 0FH, 45H, 0A8H, 0B3H	;initial position of blocks (these will be chosen randomly when the bird goes further)
BLOCKS_COUNT DW 5H, 1H, 2H, 4h
BLOCK_X DW 0
BLOCK_Y DW 0
BLOCK_WIDTH DW 03H
BLOCK_LENGTH DW 0CH
BLOCK_COUNT DW 1H
BLOCK_INDEX DW 0
BLOCK_VELOCITY_X DW 02H	;constant

CEILING_X DW 00H
CEILING_Y DW 0AH
CEILING_WIDTH DW 140H
EARLY_DETECTION DW 06H

POINTS DB 0
POINTS_STRING DB '0','0','0','$'


	.CODE 
MAIN	PROC FAR
    MOV AX,@DATA            ;initialize DS
	MOV DS,AX
	
	CALL CLEAR_SCREEN
	MOV AH, 2CH	;get system time
	INT 21H
	MOV TIME_UPDATE_PASSED, DL
	CHECK_TIME:
		MOV AH, 2CH	;get system time
		INT 21H
		CMP DL, TIME_AUX ; current time equal to previous or not?
		JE CHECK_TIME
		MOV TIME_AUX, DL 

		MOV BL, DL
		SUB BL, TIME_UPDATE_PASSED
		CMP BL, 0AH
		JE DO_UPDATE
		NEG BL
		CMP BL, 0AH
		JE DO_UPDATE
		MOV HAS_10US_PASSED, 0
		
		
		CALL CLEAR_SCREEN ; erase the trial of pixels when moving
		CALL UPDATE_POINTS
		CALL WRITE_POINTS
		CALL DRAW_CEILING
		CALL DRAW_BIRD
		CALL DRAW_ALL_BLOCKS

		CALL MOVE_BIRD
		CALL MOVE_ALL_BLOCKS
		CALL CHECK_JUMP
		JMP CHECK_TIME

		DO_UPDATE:
			MOV TIME_UPDATE_PASSED, DL
			MOV HAS_10US_PASSED, 1H
			CALL UPDATE_BIRD_VELOCITY
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
		CMP BLOCK_INDEX, 6H		; there are only 4 blocks at any time
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
	
	MOV AX, BIRD_VELOCITY_Y	; move bird in y
	ADD BIRD_Y, AX
	
	; MOV AX, BIRD_VELOCITY_X	; move bird in x 
	; ADD BIRD_X, AX
	
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
		MOV BIRD_VELOCITY_Y, 02H
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
		MOV BIRD_VELOCITY_Y, 02H
		CALL RESET_BIRD_POS
		RET 
	
	MOVE_BIRD ENDP

UPDATE_BIRD_VELOCITY PROC 
	MOV BX, ACCELERATION
	ADD BIRD_VELOCITY_Y, BX
	ret
	UPDATE_BIRD_VELOCITY ENDP

UPDATE_JUMP_VELOCITY PROC
	MOV AX, SECONDS_JUMPING
	MOV BX, ACCELERATION
	MUL BX
	NEG AX
	ADD AX, JUMP_VELOCITY_Y
	MOV JUMP_VELOCITY_Y, AX
	ret
	UPDATE_JUMP_VELOCITY ENDP

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
		CMP BLOCK_INDEX, 6H		; there are only 4 blocks on screen
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
	RANDOM_COUNT:	;getting a Random number(between 1-5) based on system time
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

	RANDOM_Y:
		mov ax, SEED   
		mov cx, 11021D  ; Multiplier
		mov dx, 2213D   ; Increment
		mov bx, 5000h   ; Modulus	

		; random number using LCG algorithm
		mul cx          ; ax = ax * cx
		add ax, dx      ; ax = ax + dx
		MOV DX, 0
		div bx          ; (remainder is the random number) dx between 0 and 7FFF
		MOV SEED, DX
		MOV AX, DX
		MOV BX, 131D	; cause I want random num between 0-130
		MOV DX, 0	 
		DIV BX		; cause I want random num between 0-130
		add DX, 10D     ; Random number between 10 and 140
		
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
		CALL UPDATE_JUMP_VELOCITY
		MOV AX, ACCELERATION
		MOV BX, SECONDS_JUMPING
		MUL BX
		MOV BX, SECONDS_JUMPING
		MUL BX
		MOV BX, 02H
		DIV BX
		NEG AX
		MOV CX, AX ;CX = -1/2*gt^2 / 10

		SUB BIRD_Y, CX

		MOV AX, JUMP_VELOCITY_Y
		MOV BX, SECONDS_JUMPING
		MUL BX	; AX = v0 * t / 10
		SUB BIRD_Y, AX
		
		MOV AX, JUMP_VELOCITY_X
		ADD BIRD_X, AX

	
		MOV BIRD_VELOCITY_Y, 02H
		MOV JUMP_VELOCITY_Y, 18H

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
