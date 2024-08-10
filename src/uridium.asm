Game:
	; Each scroll plane is made up of a 64x32 tile grid (this size is specified in VDP register 0x10),
	; with each cell specifying the index of each tile to draw, the palette to draw it with, and
	; some flags (for priority and flipping).
	;
	; Each plane cell is 1 word in size (2 bytes), in the binary format
	; ABBC DEEE EEEE EEEE, where:
	;
	;   A = Draw priority (1 bit)
	;   B = Palette index (2 bits, specifies palette 0, 1, 2, or 3)
	;   C = Flip tile horizontally (1 bit)
	;   D = Flip tile vertically (1 bit)
	;   E = Tile index to draw (11 bits, specifies tile index from 0 to 2047)
	;
	; Since we're using priority 0, palette 0, and no flipping, we
	; only need to write the tile ID and leave everything else zero.
	
	; Setup the VDP to write the tile ID at text_pos_x,text_pos_y in plane A's cell grid.
	; Plane A's cell grid starts at address 0xC000, which is specified in VDP register 0x2.
	;
	; Since each cell is 1 word in size, to compute a cell address within plane A:
	; ((y_pos * plane_width) + x_pos) * size_word
	
	bsr.w CPUInit
	
	;=================
	; Change bg colour
	;=================
	move.b	#$00,d0                        		; select the palette colour
	move.b	#palette_a,d1				; select the palette
	PUSH_SR
	GET_ADDRESS	$d021                     	; [sta $d021] background color
	move.b	d0,(a0)                         	; [...]
	POP_SR
	
	;=========
	; Clear ZP
	;=========
	move.w	#$fe,d2                        		; [ldy #$fe] %11111110
	clr.b	d0                               	; [lda #$00]
l_0916:
	PUSH_SR
	GET_ADDRESS $0001                     		; [sta $0001,y] clears zero page addresses from 0xff to 0x02
    move.b	d0,(a0,d2.w)                 		; [...]
	POP_SR
	subq.b	#1,d2                           	; [dey]
	bne	l_0916                             	; [bne l_0916]


	; loads data from one table at $8000-$9fff and reproduces
	; the data at $e000-$ffff. it achieves this by storing the 16 bit
	; vectors at $b2,$b3 and $b0,$b1 and incrementing the high byte
	; ie the value stored in $b3 & $b1

	;================================================
	; Copy bgObjectData in ROM to FF0E000 and FF08000
	;================================================

	move.w	#l_8000,d2
	bsr.w	setupSourceCopy				; ROM source

	move.w	#$e000,d2				; RAM - 0xFFE000
	bsr.w	setupDestinationCopy
	
	;move.w	#l_8000,d2
	;bsr.w	setupSourceCopy				; ROM source

	;move.w	#$8000,d2				; RAM - 0xFF8000
	;bsr.w	setupDestinationCopy
	

	;==========
	; Game init
	;==========
	bsr.w	l_25e5                            	; [jsr l_25e5] manta shadows generated here.
	
	;clears the high score summary area, first 4 rows.
	move.b	#$04,d3                        		; [ldx #$02]
	move.b	#$30,d0                        		; [lda #$30] select tile
	lea vram_addr_plane_a,a1
	SetVRAMWriteReg a1
	bsr.w	l_b189                       		; [jsr l_b189] fills first 4 rows with d0
	; test sprite
	bsr.w test_sprite
	
	;===============
	; Player 2 score
	;===============
	; use address pointer as we can't write to rom ( l_b1b8+1 )
	PUSH_SR
	GET_ADDRESS	$0                   		; [sta l_b1b8+1] -- use first byte in ram.
	move.b #$3e,(a0)				; start even
	POP_SR
	
	bsr.w	l_b1b4                           	; [jsr l_b1b4]
	
	;===================
	; Player 1 score
	;===================
	PUSH_SR
	GET_ADDRESS	$0                   		; [sta l_b1b8+1] -- use first byte in ram.
	move.b	#$02,(a0)                        	; [...]
	POP_SR
	bsr.w	l_b1b4                           	; [jsr l_b1b4]
	
	move.b	#$01,d0                        		; [lda #$01]
	PUSH_SR
	GET_ADDRESS	$5c                       	; [sta $5c]
	move.b	d0,(a0)                         	; [...]
	POP_SR

l_0a20:	
	
	;=============================
	; Render Score colours - Green
	;=============================
	
	
	;===================
	; Player 1
	;===================
	;generates player 1 text on screen
	move.w	#gamedataTextP1,d2
	move.b  d2,d1
	lsr.w	#8,d2					; get high byte
	bsr.w l_b295
	
	;===================
	; Player 2
	;===================
	;generates player 2 text on screen
	move.w	#gamedataTextP2,d2 			; 0xc02
	move.b  d2,d1
	lsr.w	#8,d2					; get high byte
	bsr.w l_b295
	
	;===================================
	;Initialises large text scroll data
	;===================================
	
	bsr.w	l_2415                            	; [jsr l_2415]
	move.b	#$03,d0                        		; [lda #$03]
	PUSH_SR
	GET_ADDRESS	$5b                       	; [sta $5b]
	move.b	d0,(a0)                         	; [...]
	POP_SR

l_0a6f:
	bsr.w	l_17cc                            	; [jsr l_17cc] - sets up interrupt to irq1 - to do
	clr.b	d0                               	; [lda #$00] disable sprites
	PUSH_SR
	GET_ADDRESS	$d015                     	; [sta $d015] sprite enable register
	move.b	d0,(a0)                         	; [...]
	GET_ADDRESS	$5a                       	; [sta $5a]
	move.b	d0,(a0)                         	; [...]
	GET_ADDRESS	$28                       	; [sta $28]
	move.b	d0,(a0)                         	; [...]
	POP_SR
	move.b	#$11,d0                        		; [lda #$11]
	PUSH_SR
	GET_ADDRESS	$90                       	; [sta $90]
	move.b	d0,(a0)                         	; [...]
	POP_SR
	
	
	;===================
	;Clear screen
	;===================
	move.b #$30,d0                        		; [lda #$30] - tile #
	move.w #$4,d1					; start clearing screen 4 rows down
	lsl.w #7,d1					; x 8
	lea vram_addr_plane_a,a1					
	add.w d1,a1
	SetVRAMWriteReg a1
	bsr.w	l_2397                            	; [jsr l_2397]
	
	;=================
	;Set color to text
	;=================
	; to do later
	
	;======
	;HEWSON
	;======
	move.w	#gamedataTextHEWSON,d2 		
	move.b d2,d1
	lsr.w #8,d2
	bsr.w l_b295
	
	
	;========
	;PRESENTS
	;========
	move.w	#gamedataTextPresents,d2 		
	move.b d2,d1
	lsr.w #8,d2
	bsr.w l_b295
	
	;=======
	;URIDIUM
	;=======
	move.w #gamedataTextURIDIUM,d2
	move.b  d2,d1
	lsr.w	#8,d2
	bsr.w l_b295

	;=========
	;Graftgold
	;=========
	move.w #gamedataTextGraftGold,d2
	move.b d2,d1
	lsr.w #8,d2
	bsr.w l_b295
	
	
	;==========================
	;Designed and programmed by
	;==========================
	move.w #gamedataTextDesignedBy,d2
	move.b d2,d1
	lsr.w #8,d2
	bsr.w l_b295
	
	;================
	;Andrew Braybrook
	;================
	move.w #gamedataTextAndrew,d2
	move.b d2,d1
	lsr.w #8,d2
	bsr.w l_b295
	
	;===================
	;Clear animation bar
	;===================
	move.w #gamedataTextBlankLine,d2
	move.b d2,d1
	lsr.w #8,d2
	bsr.w l_b295
	
	;=======
	;Attract
	;=======
	jsr l_2150
	
	GET_ADDRESS	$18					; [lda $18] game state here
	move.b	(a0),d0						; [...]
	;bne	l_0ad4						; [bne l_0ad4] scrolling attract mode.
	;jmp	l_0b65						; [jmp l_0b65] game starts here
	jmp *
	
l_17cc:
	rts
	
	;===================
	; Attract mode setup
	;===================
l_2150:
	move.b	#$02,d0						; [lda #$02]
	PUSH_SR
	GET_ADDRESS	$59					; [sta $59]
	move.b	d0,(a0)						; [...]
	POP_SR
	clr.b	d0                              		; [lda #$00]
	PUSH_SR
	GET_ADDRESS	$62					; [sta $62]
	move.b	d0,(a0)						; [...]
	POP_SR

	;=======================
	; Attract mode main loop
	;=======================
l_2158:
	
	bsr.w	l_b019                          		; [jsr l_b019] - check joy controls
	bsr.w	l_b1fd                          		; [jsr l_b1fd] - read the keyboard 	- to do.
	bsr.w	l_b31b                          		; [jsr l_b31b] - results of input to screen, volume, number of players - to do.
	
	;=============
	;Animation bar
	;=============
	bsr.w	l_22d3						; [jsr l_22d3]
	bsr.w	l_2342							; [jsr l_2342]
	bsr.w	l_23b5						; [jsr l_23b5]

	move.b	#$0c,d2						; [ldy #$0c]
	bsr.w	l_b244						; [jsr l_b244]
	GET_ADDRESS	$62					; [inc $62]
	addq.b	#1,(a0)						; [...]
	GET_ADDRESS	$18					; [lda $18]
	move.b	(a0),d0						; [...]
	beq.s	l_217d 						; [beq l_217d]
	GET_ADDRESS	$62 					; [lda $62]
	move.b	(a0),d0						; [...]
	bne.s	l_2158 						; [bne l_2158]
	GET_ADDRESS	$59					; [dec $59]
	subq.b	#1,(a0)						; [...]
	bne	l_2158						; [bne l_2158]
	
l_217d:
	rts 							; [rts]

l_217e:
	clr.b	d0						; [lda #$00]
	PUSH_SR
	GET_ADDRESS	$62					; [sta $62]
	move.b	d0,(a0)						; [...]
	POP_SR
	
l_2182:

	GET_ADDRESS	$2f                       		; [lda $2f]
	move.b	(a0),d0                         		; [...]
	bne	l_2182                             		; [bne l_2182]
	bsr.w	l_2b40                          		; [jsr l_2b40]
	bsr.w	l_2beb                           		; [jsr l_2beb] scrolling routine and bullets for manta ?
	;bsr.w	l_2ed7						; [jsr l_2ed7]
	;bsr.w	l_2fc8						; [jsr l_2fc8]
	bsr.w	l_b019                            		; [jsr l_b019] read joystick
	bsr.w	l_b1fd                            		; [jsr l_b1fd] read keyboard
	bsr.w	l_22d3                            		; [jsr l_22d3]
	bsr.w	l_b31b                            		; [jsr l_b31b]
	bsr.w	l_23b5                            		; [jsr l_23b5]
	bsr.w	l_2342                            		; [jsr l_2342]
	GET_ADDRESS	$62                       		; [inc $62]
	addq.b	#1,(a0)                         		; [...]
	GET_ADDRESS	$18                       		; [lda $18]
	move.b	(a0),d0                         		; [...]
	beq	l_21b4                             		; [beq l_21b4]
	GET_ADDRESS	$2a                       		; [lda $2a]
	move.b	(a0),d0                         		; [...]
	cmp.b	#$0e,d0                         		; [cmp #$0e]
	bcs	l_2182                             		; [bcc l_2182]
	GET_ADDRESS	$29                       		; [lda $29]
	move.b	(a0),d0                         		; [...]
	bpl	l_2182                             		; [bpl l_2182]
l_21b4:
	rts                                    			; [rts]

l_22d3:
	GET_ADDRESS	$62                       		; [lda $62]
	move.b	(a0),d0                         		; [...]
	and.b	#$7f,d0                         		; [and #$7f]
	bne	l_231c                             		; [bne l_231c]
	GET_ADDRESS	$5b                       		; [lda $5b]
	move.b	(a0),d0                         		; [...]
	PUSH_SR
	GET_ADDRESS	$0f                       		; [sta $0f]
	move.b	d0,(a0)                         		; [...]
	POP_SR
								; [clc]
	add.b	#$01,d0                        			; [adc #$01]
	and.b	#$03,d0                         		; [and #$03]
	PUSH_SR
	GET_ADDRESS	$5b                       		; [sta $5b]
	move.b	d0,(a0)                         		; [...]
	POP_SR
	beq	l_231d                             		; [beq l_231d]
	GET_ADDRESS	$5a                       		; [lda $5a]
	move.b	(a0),d0                         		; [...]
	cmp.b	#$03,d0                         		; [cmp #$03]
	beq	l_231d                             		; [beq l_231d]
	GET_ADDRESS	$5b                       		; [lda $5b]
	move.b	(a0),d0                         		; [...]
	cmp.b	#$01,d0                         		; [cmp #$01]
	beq	l_2325                             		; [beq l_2325]
	cmp.b	#$02,d0                         		; [cmp #$02]
	beq	l_232d                             		; [beq l_232d]
	GET_ADDRESS	$5a                       		; [lda $5a]
	move.b	(a0),d0                         		; [...]
	cmp.b	#$02,d0                         		; [cmp #$02]
	beq	l_2335                             		; [beq l_2335]
	
l_22fc:
	GET_ADDRESS	$5c                       		; [lda $5c]
	move.b	(a0),d2                         		; [...]
	;move.b	d0,d2                           		; [tay]
	
	lsl.w #2,d2						; 16bit address to 32bit
	move.l #l_3570,a0							
	move.l	(a0,d2.w),d2
	move.b d2,d1
	lsr.w #8,d2
	bsr.w l_b295

	;GET_ADDRESS	$3573                     		; [lda $3573,y] - to do
	;move.b	(a0,d2.w),d0                    		; [...]
	;GET_ADDRESS	$3570                     		; [ldx $3570,y] - to do
	;move.b	(a0,d2.w),d1                    		; [...]
	;move.b	d0,d2                           		; [tay]
	;bsr.w	l_b295                            		; [jsr l_b295]
	
	GET_ADDRESS	$61                       		; [lda $61]
	move.b	(a0),d0                         		; [...]
	beq	l_2315                             		; [beq l_2315]
	
	move.w #l_34f5,d2					; [ldx #$f5] , [ldy #$34]
	move.b d2,d1
	lsr.w #8,d2
	bsr.w l_b295						; [jsr l_b295]
	rts                                    			; [rts]
	

	;==========================
	;Animation Bar left portion
	;==========================
l_2315:
	move.w #gameTextColour,d2				; [ldx #$f5] , [ldy #$34]
	move.b d2,d1
	lsr.w #8,d2
	bsr.w l_b295						; [jsr l_b295]
l_231c:
	rts
	
	;=====================
	;Animation Bar Uridium
	;=====================
l_231d:
	move.w #gameTextUridium,d2				; [ldx #$f5] , [ldy #$34]
	move.b d2,d1
	lsr.w #8,d2
l_2321:
	bsr.w l_b295						; [jsr l_b295]
	rts

	;========================
	;Animation Bar High Score
	;========================
l_2325:
	move.w #gameTextHighScore,d2				
	move.b d2,d1
	lsr.w #8,d2
	bsr.w l_b295		
	rts 

	;======================= 
	;Animation Bar 12000 AEB
	;=======================
l_232d:
	move.w #gameTextHighAEB,d2				
	move.b d2,d1
	lsr.w #8,d2
	bsr.w l_b295		
	rts 

	;=============================
	;Prints Level During game play
	;=============================
l_2335:	
	; to do.
	;GET_ADDRESS	$26                       	; [ldy $26]
	;move.b	(a0),d2                         	; [...]
	;GET_ADDRESS	$e050                     	; [ldx $e050,y]
	;move.b	(a0,d2.w),d1                    	; [...]
	;GET_ADDRESS	$e060                    	; [lda $e060,y]
	;move.b	(a0,d2.w),d0                    	; [...]
	;move.b	d0,d2                           	; [tay]
	;jbsr	l_b295                            	; [jsr l_b295]
	
	; to check this later
	GET_ADDRESS	$26                       	; [ldy $26]
	move.b	(a0),d2                         	; [...]
	lea	$ffe050,a0                    		; [ldx $e050,y]
	move.b	(a0,d2.w),d1
	lea	$ffe060,a0
	move.b	(a0,d2.w),d0  
	move.b	d0,d2
	bsr.w	l_b295
	rts                                    		; [rts]
	
l_2342:
	GET_ADDRESS	$19                       	; [lda $19]
	move.b	(a0),d0                         	; [...]
	and.b	#$10,d0                         	; [and #$10]
	beq	l_2351                             	; [beq l_2351]
	GET_ADDRESS	$19                       	; [lda $19]
	move.b	(a0),d0                         	; [...]
	and.b	#$a0,d0                         	; [and #$a0]
	cmp.b	#$80,d0                         	; [cmp #$80]
	beq	l_237b                             	; [beq l_237b]
	rts                                    		; [rts]
	
l_2351:	
	;clr.b	d1                               	; [ldx #$00]
	;move.b	#$dc,d2                        		; [ldy #$dc]
	;PUSH_SR
	;GET_ADDRESS	$b025                     	; [stx $b025]
	;move.b	d1,(a0)                         	; [...]
	;GET_ADDRESS	$b026                    	; [sty $b026]
	;move.b	d2,(a0)                         	; [...]
	;POP_SR
	;move.b	#$01,d1                        		; [ldx #$01]
	;move.b	#$dc,d2                        		; [ldy #$dc]
	;PUSH_SR
	;GET_ADDRESS	$b028                    	 ; [stx $b028]
	;move.b	d1,(a0)                         	; [...]
	;GET_ADDRESS	$b029                     	; [sty $b029]
	;move.b	d2,(a0)                         	; [...]
	;POP_SR
	
	GET_ADDRESS	$19                       	; [lda $19]
	move.b	(a0),d0                         	; [...]
	bmi	l_2389                             	; [bmi l_2389]
	move.b	#$02,d0                        		; [lda #$02]
	PUSH_SR
	GET_ADDRESS	$5c                       	; [sta $5c]
	move.b	d0,(a0)                         	; [...]
	POP_SR               
	
	move.w #l_34d0,d2				; [ldx #$d0]
	move.b d2,d1					; [ldy #$34]
	lsr.w #8,d2					; [jsr l_b295]
	bsr.w l_b295		

l_2374:
	GET_ADDRESS	$5b                       	; [lda $5b]
	move.b	(a0),d0                         	; [...]
	cmp.b	#$03,d0                         	; [cmp #$03]
	beq	l_22fc                             	; [beq l_22fc]
	rts                                    		; [rts]	
	
l_237b:
	clr.b	d0                               	; [lda #$00]
	PUSH_SR
	GET_ADDRESS	$5c                       	; [sta $5c]
	move.b	d0,(a0)                         	; [...]
	POP_SR
	
	move.w #l_34db,d2				
	move.b d2,d1
	lsr.w #8,d2
	bsr.w l_b295		
	jmp	l_2374                             	; [jmp l_2374]

l_2389:
	move.b	#$01,d0                        		; [lda #$01]
	PUSH_SR
	GET_ADDRESS	$5c                       	; [sta $5c]
	move.b	d0,(a0)                         	; [...]
	POP_SR
	move.w #l_34e5,d2				
	move.b d2,d1
	lsr.w #8,d2
	bsr.w l_b295		
	jmp	l_2374                             	; [jmp l_2374]	
	
	;==============
	;Clears screen
	;==============
l_2397:
	move.w	a1,d2 					; vram_addr_plane_a address.
	move.b d2,d1					; get low byte
	lsr.w #8,d2					; get high byte
	
	PUSH_SR
	GET_ADDRESS	$1c                       	; [stx $1c]
	move.b	d1,(a0)                         	; [...]
	GET_ADDRESS	$1d                       	; [sty $1d]
	move.b	d2,(a0)                         	; [...]
	POP_SR
	move.w	#$18,d3                        		; [ldx #$15]
	bsr.w	l_b189                            	; [jsr l_b189]
	rts                                    		; [rts]

	;==============
	;Sets color ram
	;==============

l_23a5:
	PUSH_SR
	GET_ADDRESS	$8f                       	; [sty $8f]
	move.b	d2,(a0)                         	; [...]
	POP_SR
l_23a7:
	GET_ADDRESS	$8f                       	; [ldy $8f]
	move.b	(a0),d2                         	; [...]
	GET_ADDRESS_Y	$1a                     	; [lda ($1a),y]
	move.b	(a0,d2.w),d0                    	; [...]
	move.b	#$01,d1                        		; [ldx #$01]
	bsr.w	l_b189                            	; [jsr l_b189]
	GET_ADDRESS	$8f                       	; [dec $8f]
	subq.b	#1,(a0)                         	; [...]
	bpl	l_23a7                             	; [bpl l_23a7]
	rts                                    		; [rts]
	
l_23b5:
	GET_ADDRESS	$19                       	; [lda $19]
	move.b	(a0),d0                         	; [...]
	and.b	#$08,d0                         	; [and #$08]
	bne	l_23d6                             	; [bne l_23d6]
	GET_ADDRESS	$19                       	; [lda $19]
	move.b	(a0),d0                         	; [...]
	bpl	l_23d7                             	; [bpl l_23d7]

	move.w #l_36a0,d2				; [ldx #$a0]	
	move.b d2,d1					; [ldy #$36]
	lsr.w #8,d2					; [jsr l_b295]
	bsr.w l_b295		
	
	clr.b	d0                               	; [lda #$00]
	PUSH_SR
	GET_ADDRESS	$61                       	; [sta $61]
	move.b	d0,(a0)                         	; [...]
	POP_SR
	bsr.w	l_23ef                            	; [jsr l_23ef]
	GET_ADDRESS	$5b                       	; [lda $5b]
	move.b	(a0),d0                         	; [...]
	cmp.b	#$03,d0                         	; [cmp #$03]
	bne	l_23d6                             	; [bne l_23d6]
	jmp	l_22fc                             	; [jmp l_22fc]
l_23d6:
	rts                                    		; [rts]
	
l_23d7:
	move.w #l_36ad,d2				; [ldx #$a0]	
	move.b d2,d1					; [ldy #$36]
	lsr.w #8,d2					; [jsr l_b295]
	bsr.w l_b295		
	
	move.b #$ff,d0                             	; [lda #$ff]
	PUSH_SR
	GET_ADDRESS	$61                       	; [sta $61]
	move.b	d0,(a0)                         	; [...]
	POP_SR
	bsr.w	l_23ef                            	; [jsr l_23ef]
	GET_ADDRESS	$5b                       	; [lda $5b]
	move.b	(a0),d0                         	; [...]
	cmp.b	#$03,d0                         	; [cmp #$03]
	bne	l_23d6                             	; [bne l_23d6]
	jmp	l_22fc                             	; [jmp l_22fc]
	rts                                    		; [rts]

l_23ef:
	; to do.
	GET_ADDRESS	$61                       	; [lda $61]
	move.b	(a0),d0                         	; [...]
	beq	l_2402                             	; [beq l_2402]
	move.b	#$f1,d0                        		; [lda #$f1]
	;PUSH_SR
	;GET_ADDRESS	$d85a                    	; [sta $d85a]
	;move.b	d0,(a0)                         	; [...]
	;GET_ADDRESS	$d85b                   	; [sta $d85b]
	;move.b	d0,(a0)                         	; [...]
	;GET_ADDRESS	$d882                  	  	; [sta $d882]
	;move.b	d0,(a0)                         	; [...]
	;GET_ADDRESS	$d883                   	; [sta $d883]
	;move.b	d0,(a0)                         	; [...]
	;POP_SR
	rts                                    		; [rts]

l_2402:
	; to do
	;move.b	#$f2,d0                       	 	; [lda #$f2]
	;PUSH_SR
	;GET_ADDRESS	$d85a                     	; [sta $d85a]
	;move.b	d0,(a0)                         	; [...]
	;GET_ADDRESS	$d85b                    	 ; [sta $d85b]
	;move.b	d0,(a0)                         	; [...]
	;POP_SR
	;move.b	#$f5,d0                        		; [lda #$f5]
	;PUSH_SR
	;GET_ADDRESS	$d882                     	; [sta $d882]
	;move.b	d0,(a0)                         	; [...]
	;POP_SR
	;move.b	#$f6,d0                        		; [lda #$f6]
	;PUSH_SR
	;GET_ADDRESS	$d883                     	; [sta $d883]
	;move.b	d0,(a0)                         	; [...]
	;POP_SR
	rts                                    		; [rts]

l_2415:
	clr.w d1                               		; [ldx #$00]
	PUSH_SR
	GET_ADDRESS $10                       		; [stx $10]
	move.b	d1,(a0)                         	; [...]
	GET_ADDRESS $11                       		; [stx $11]
	move.b	d1,(a0)                         	; [...]
	POP_SR
l_241b:
	GET_ADDRESS l_349f                     		; [ldy $349f,x]
	move.b	(a0,d1.w),d2                    	; [...]
	bmi	l_244d                             	; [bmi l_244d]
l_2420:
	GET_ADDRESS scrollTextData             		; [lda $c000,y]
	move.b	(a0,d2.w),d0  ; 0x78			; [...]
	CLR_XC_FLAGS					; [clc]		
	move.b	#$60,d4	
	addx.b	d4,d0          ; 0xD8            	 ; [adc #$60]
	
	lea scrollTextData,a0
	add.w d0,a0
	move.l a0,d3
	
	PUSH_SR
	GET_ADDRESS	$1a                       	; [sta $1a]
	move.b	d3,(a0)                         	; [...]
	POP_SR
	
	move.l d3,d0
	lsr.w #8,d0					; get the high byte
	
	PUSH_SR
	GET_ADDRESS	$1b                       	; [sta $1b]
	move.b	d0,(a0)                         	; [...]
	POP_SR
	clr.w	d2                               	; [ldy #$00]
	GET_ADDRESS	$11                       	; [ldx $11]
	move.b	(a0),d1                         	; [...]
l_2432:
	GET_ADDRESS_Y_ROM	$1a                     ; [lda ($1a),y] - from rom
	move.b	(a0,d2.w),d0                    	; [...]
	beq	l_243a                             	; [beq l_243a]
	PUSH_SR
	;GET_ADDRESS	l_8010                    	; [sta $8010,x] 
	lea $FF8010,a0
    move.b	d0,(a0,d1.w)                 		; [...]
	POP_SR
	addq.b	#1,d1                           	; [inx]
l_243a:
	addq.b	#1,d2                           	; [iny]
	cmp.b	#$04,d2                         	; [cpy #$04]
	bcs	l_2432                             	; [bcc l_2432]
	move.b	#$01,d0                        		; [lda #$01]
	PUSH_SR
	;GET_ADDRESS	l_8010                    	; [sta $8010,x]
	lea $FF8010,a0
    move.b	d0,(a0,d1.w)                 		; [...]
	POP_SR
	addq.b	#1,d1                           	; [inx]
	PUSH_SR
	GET_ADDRESS	$11                       	; [stx $11]
	move.b	d1,(a0)                         	; [...]
	POP_SR
	GET_ADDRESS	$10                       	; [inc $10]
	addq.b	#1,(a0)                         	; [...]
	GET_ADDRESS	$10                       	; [ldx $10]
	move.b	(a0),d1                         	; [...]
	bpl	l_241b                             	; [bpl l_241b]
l_244d:
	GET_ADDRESS	$11                       	; [ldx $11]
	move.b	(a0),d1                         	; [...]
	move.b	#$03,d2                        		; [ldy #$03]
	clr.w	d0                               	; [lda #$00]
l_2453:
	PUSH_SR
	;GET_ADDRESS	l_8010                    	; [sta $8010,x]
	lea $FF8010,a0
    move.b	d0,(a0,d1.w)                 		; [...]
	POP_SR
	addq.b	#1,d1                           	; [inx]
	subq.b	#1,d2                           	; [dey]
	bpl	l_2453                             		; [bpl l_2453]
	rts                                    		; [rts]

	
	;=========================
	;Manta's Shadow generation
	;=========================
l_25e5:				
	; 432 tiles * 32 ( bytes per tile )
	SetVRAMWriteConst (vram_addr_tiles+size_tile_b)+tile_count*size_tile_b+sprite_count*size_tile_b
	lea SpritesManta,a0
	lea $00FF1000,a1				; temporarily use the ram to store the shadows.
	move.w #(sprite_count*(size_tile_b))-1,d0	; Loop counter 423 xx 32 bytes per tile
L_25F7:							; Start of loop
	move.b (a0)+,d1                                 ; Load byte from sprite data
	tst.b d1					; Test if byte is zero (transparent)
	beq SkipShadow 					; If zero, skip shadow generation
	move.b #$bb,d1					; Set shadow color (some darker shade)
SkipShadow:
	move.b d1,(a1)+					; Write byte to shadow buffer and post-increment address
	dbra d0,L_25F7					; Decrement d0 and loop until finished (when d0 reaches -1)
	
	; Write the shadow tiles to VRAM
	lea    $00FF1000,a1				; Move the address of the shadow buffer into a1
	move.w #(sprite_count*(size_tile_l))-1,d0	; Loop counter = 8 longwords per tile * num tiles (-1 for DBRA loop)
ShadowWriteLp:						; Start of shadow writing loop
	move.l (a1)+,vdp_data 				; Write tile line (4 bytes per line), and post-increment address
	dbra d0,ShadowWriteLp				; Decrement d0 and loop until finished (when d0 reaches -1)
	
	move.b	#$00,d1 				; [ldx #<l_lvl_data2]
	move.b	#$c0,d2					; [ldy #>l_lvl_data2]
	PUSH_SR
	GET_ADDRESS	$1c				; [stx $1c]
	move.b	d1,(a0)					; [...]
	GET_ADDRESS	$1d				; [sty $1d]
	move.b	d2,(a0)					; [...]
	POP_SR
	rts
	
l_2b40:
	GET_ADDRESS	$2e                       	; [lda $2e]
	move.b	(a0),d0                         	; [...]
	beq	l_2b53                             	; [beq l_2b53]
	bpl	l_2b5d                             	; [bpl l_2b5d]
	GET_ADDRESS	$29                       	; [lda $29]
	move.b	(a0),d0                         	; [...]
	SET_XC_FLAGS                           		; [sec]
	GET_ADDRESS	$2e                       	; [sbc $2e]
	SBC	(a0),d0    
	PUSH_SR
	GET_ADDRESS	$29                       	; [sta $29]
	move.b	d0,(a0)                         	; [...]
	POP_SR
	GET_ADDRESS	$2a                       	; [lda $2a]
	move.b	(a0),d0                         	; [...]
	SBC_IMM	 $ff                           		; [sbc #$ff]
	PUSH_SR
	GET_ADDRESS	$2a                       	; [sta $2a]
	move.b	d0,(a0)                         	; [...]
	POP_SR


l_2b53:
	move.b	#$08,d0                        		; [lda #$08]
	SET_XC_FLAGS                           		; [sec]
	GET_ADDRESS	$29                       	; [sbc $29]
	SBC	(a0),d0   
	and.b	#$07,d0                         	; [and #$07]
	PUSH_SR
	GET_ADDRESS	$2c                       	; [sta $2c]
	move.b	d0,(a0)                         	; [...]
	POP_SR
	rts                                    		; [rts]

l_2b5d:
	GET_ADDRESS	$29                       	; [lda $29]
	move.b	(a0),d0                         	; [...]
	SET_XC_FLAGS                           		; [sec]
	GET_ADDRESS	$2e                       	; [sbc $2e]
	SBC	(a0),d0   
	PUSH_SR
	GET_ADDRESS	$29                       	; [sta $29]
	move.b	d0,(a0)                         	; [...]
	POP_SR
	GET_ADDRESS	$2a                       	; [lda $2a]
	move.b	(a0),d0                         	; [...]
	SBC_IMM	 $00                           		; [sbc #$00]
	PUSH_SR
	GET_ADDRESS	$2a                       	; [sta $2a]
	move.b	d0,(a0)                         	; [...]
	POP_SR
	jmp	l_2b53                             	; [jmp l_2b53]

l_2beb:
	GET_ADDRESS	$29                       	; [lda $29]
	move.b	(a0),d0                         	; [...]
							; [clc]
	add.b	#$07,d0                        		; [adc #$07]
	PUSH_SR
	GET_ADDRESS	$31                       	; [sta $31]
	move.b	d0,(a0)                         	; [...]
	POP_SR
	GET_ADDRESS	$2a                       	; [lda $2a]
	move.b	(a0),d0                         	; [...]
	move.b	#$00,d4	;	addx.b	#$00,d0         ; [adc #$00]
	addx.b	d4,d0                        		; [adc #$00]
	lsr.b	#1,d0                            	; [lsr a]
	GET_ADDRESS	$31                       	; [ror $31]
	move.b	(a0),d4	;	roxr.b	#1,(a0)         ; [...]
	roxr.b	#1,d4                         		; [...]
	PUSH_SR
	move.b	d4,(a0)	;	roxr.b	#1,(a0)         ; [...]
	POP_SR
	lsr.b	#1,d0                            	; [lsr a]
	GET_ADDRESS	$31                       	; [ror $31]
	move.b	(a0),d4	;	roxr.b	#1,(a0)         ; [...]
	roxr.b	#1,d4                         		; [...]
	PUSH_SR
	move.b	d4,(a0)					; roxr.b	#1,(a0)
	POP_SR
	lsr.b	#1,d0                            	; [lsr a]
	GET_ADDRESS	$31                       	; [ror $31]
	move.b	(a0),d4					; roxr.b	#1,(a0)            
	roxr.b	#1,d4                         		; [...]
	PUSH_SR
	move.b	d4,(a0)					; roxr.b	#1,(a0) ; [...]
	POP_SR
	and.b	#$01,d0                         	; [and #$01]
	PUSH_SR
	GET_ADDRESS	$0f                       	; [sta $0f]
	move.b	d0,(a0)                         	; [...]
	POP_SR
	move.b	#$82,d0                        		; [lda #$82]
	GET_ADDRESS	$0f                       	; [ora $0f]
	or.b	(a0),d0                           	; [...]
	PUSH_SR
	GET_ADDRESS	$30                       	; [sta $30]
	move.b	d0,(a0)                         	; [...]
	GET_ADDRESS	l_2c1f+2			; [sta $2c21] , high byte address of 0x8200
	move.b	d0,(a0)                         	; [...]
	POP_SR
	GET_ADDRESS	$31                       	; [lda $31]
	move.b	(a0),d0                         	; [...]
	PUSH_SR
	GET_ADDRESS	l_2c1f+1			; [sta $2c20] , low byte address of 0x8200
	move.b	d0,(a0)                         	; [...]
	POP_SR
	move.b	#$48,d0					; [lda #$48]
	PUSH_SR
	GET_ADDRESS	l_2c1f+5			; [sta $2c24] , high byte address of 0x48f0
	move.b	d0,(a0)					; [...]
	POP_SR
	move.b	#$f0,d0                        		; [lda #$f0]
	PUSH_SR
	GET_ADDRESS	l_2c1f+4			; [sta $2c23] , low byte address of 0x48f0
	move.b	d0,(a0)                         	; [...]
	POP_SR
	move.b	#$11,d1                        		; [ldx #$11]
	
l_2c1d:
	move.b	#$26,d2                        		; [ldy #$26]
l_2c1f:
	GET_ADDRESS	$8200                     	; [lda $8200,y]
	move.b	(a0,d2.w),d0                    	; [...]
	PUSH_SR
	GET_ADDRESS	$48f0                     	; [sta $48f0,y]
    move.b	d0,(a0,d2.w)                 		; [...]
	POP_SR
	subq.b	#1,d2                           	; [dey]
	bpl	l_2c1f                             	; [bpl l_2c1f]
	subq.b	#1,d1                           	; [dex]
	beq	l_2c42                             	; [beq l_2c42]
	GET_ADDRESS	$2c21                     	; [inc $2c21]
	addq.b	#1,(a0)                         	; [...]
	GET_ADDRESS	$2c21                     	; [inc $2c21]
	addq.b	#1,(a0)                         	; [...]
	GET_ADDRESS	$2c23                     	; [lda $2c23]
	move.b	(a0),d0                         	; [...]
							; [clc]
	add.b	#$28,d0                        		; [adc #$28]
	PUSH_SR
	GET_ADDRESS	$2c23                     	; [sta $2c23]
	move.b	d0,(a0)                         	; [...]
	POP_SR
	bcc	l_2c1d                                  ; [bcc l_2c1d]
	GET_ADDRESS	$2c24                     	; [inc $2c24]
	addq.b	#1,(a0)                         	; [...]
	jmp	l_2c1d                                  ; [jmp l_2c1d]
	rts

l_2c42:
	GET_ADDRESS	$31                       	; [lda $31]
	move.b	(a0),d0                         	; [...]
							; [clc]
	add.b	#$12,d0                        		; [adc #$12]
	PUSH_SR
	GET_ADDRESS	$52                       	; [sta $52]
	move.b	d0,(a0)                         	; [...]
	GET_ADDRESS	$33                       	; [lda $33]
	move.b	(a0),d0                         	; [...]
	SET_XC_FLAGS                           		; [sec]
	SBC_IMM	$58                           		; [sbc #$58]
	and.b	#$f8,d0                         	; [and #$f8]
	lsr.b	#1,d0                            	; [lsr a]
	lsr.b	#1,d0                            	; [lsr a]
	POP_SR                                 		; [plp]
	GET_ADDRESS	$30                       	; [adc $30]
	move.b	(a0),d4					; addx.b (a0),d0
	addx.b	d4,d0                         		; [...]
	PUSH_SR
	GET_ADDRESS	$53                       	; [sta $53]
	move.b	d0,(a0)                         	; [...]
	POP_SR
	GET_ADDRESS	$30                       	; [lda $30]
	move.b	(a0),d0                         	; [...]
	roxr.b	#1,d0                           	; [ror a]
	GET_ADDRESS	$31                       	; [lda $31]
	move.b	(a0),d0                         	; [...]
	roxr.b	#1,d0                           	; [ror a]
	PUSH_SR
	GET_ADDRESS	$50                       	; [sta $50]
	move.b	d0,(a0)                         	; [...]
	POP_SR
							; [clc]
	add.b	#$14,d0                        		; [adc #$14]
	PUSH_SR
	GET_ADDRESS	$51                       	; [sta $51]
	move.b	d0,(a0)                         	; [...]
	POP_SR
	rts                                    		; [rts]

l_b019:
	clr.b	d0                               	; [lda #$00]
	PUSH_SR
	GET_ADDRESS	$16                       	; [sta $16]
	move.b	d0,(a0)                         	; [...]
	GET_ADDRESS	$17                       	; [sta $17]
	move.b	d0,(a0)                         	; [...]
	POP_SR
	
	; first determine what key presses are required and see if we can translate those to buttons on the controller
	;move.b	#0xff					;ignorekeyboardpresses [lda #$ff  // ignore keyboard presses]
	;PUSH_SR
	;GET_ADDRESS	0xdc00//cia#1(portregistera)	; [sta $dc00 // cia#1 (port register a)]
	;move.b	d0,(a0)                         	
	;POP_SR
	
	;===================
	;Read Pad
	;===================
l_b024:
	jsr  ReadPad1	;Read pad 1 state, result in d0
	btst #pad_button_left,d0
	beq.s l_b037
	
	btst #pad_button_right,d0
	beq.s l_b03b
	
	jmp	l_b03d	 ;checkupanddown

	;process left
l_b037:
	GET_ADDRESS	$17			  ; [dec $17]
	subq.b	#1,(a0)				  ; [...]
	bne	l_b03d				  ; [bne l_b03d]
	
	;process right
l_b03b:
	GET_ADDRESS	$17			  ; [inc $17]
	addq.b	#1,(a0)				  ; [...]

l_b03d:
	btst #pad_button_up,d0
	beq	l_b04a	;doup                     ; [beq l_b04a	// do up]
	
	btst #pad_button_down,d0
	beq	l_b04e	;dodown                   ; [beq l_b04e	 // do down]
	jmp	l_b050	;checkthefirebutton       ; [jmp l_b050	 // check the fire button]

	;process up
l_b04a:
	GET_ADDRESS	$16                     ;[dec $16]
	subq.b	#1,(a0)                         ; [...]
	bne	l_b050                          ; [bne l_b050]

	;process down
l_b04e:
	GET_ADDRESS	$16                     ; [inc $16]
	addq.b	#1,(a0)                         ; [...]
l_b050:
	and.b #$10,d0				;isoldatefirebutton,d0    	| [and #$10	// isoldate fire button]
	PUSH_SR
	GET_ADDRESS	$18			;storeresultin0page.0valueforfirebuttondown	| [sta $18// store result in 0 page. 0 value for fire button down]
	move.b	d0,(a0)                         ; [...]
	POP_SR
	rts                                    	; [rts]

	;first 4 bytes are used to check the joystick on the c64 which we won't use.
l_b055:
dc.b $01,$02,$04,$08,$10,$20,$40,$80
	;====================================================
	;Renders row of characters d3 = tile index, d3 = rows
	;====================================================

l_b189:
	PUSH_SR
	GET_ADDRESS $0d                       		; [sta $0d]
	move.b	d0,(a0)                         	; [...]
	move.l	a0,a2					; preserve pointer to tile address in a2
	POP_SR
l_b18b: 
	clr.b d2                               		; [ldy #$00]
l_b18d:
	; fill 1 row of characters
	PUSH_SR
	GET_ADDRESS_Y_RAM	$1c                     ; [sta ($1c),y] ; stores tile at said address
	move.b (a2),d6
	move.w d6,vdp_data
	POP_SR
	addq.w #1,d2                           		; [iny]
	cmp.w #$28,d2                         		; [cpy #$28] ; have we read 40 characters
	bcs	l_b18d                             	; [bcc l_b18d]
	
	subq.b	#1,d3                           	; [dex] , done 1  row
	beq	l_b1a7                             	; [beq l_b1a7]
	CLR_XC_FLAGS                           		; [clc]
	add.w #$80,a1
	SetVRAMWriteReg a1
	bcs	l_b1a2                             	; [bcc l_b1a2]
l_b1a2:
	move.b (a2),d6					; get tile.
	move.w d6,vdp_data
	jmp	l_b18b                             	; [jmp l_b18b]
l_b1a7:
	CLR_XC_FLAGS                           		; [clc]
	add.w #$80,a1
	SetVRAMWriteReg a1
	bcs l_b1b3                             		; [bcc l_b1b3]
l_b1b3:
	rts                                    		; [rts]
 	
	
l_b1b4:
	move.b	#$04,d0                        		; [lda #$02]
	PUSH_SR
	GET_ADDRESS	$b4                       	; [sta $b4]
	move.b	d0,(a0)                         	; [...]
	POP_SR
l_b1b8:
	;move.b	 #$02,d0                        	; [lda #$02] 	  - self modifying
	PUSH_SR
	GET_ADDRESS	$0                   		; [sta l_b1b8+1] - use first byte in ram instead / can't SM in rom
	move.b	(a0),d0                         	; [...]
	POP_SR
	
	
	PUSH_SR
	GET_ADDRESS	$b5                       	; [sta $b5]
	move.b	d0,(a0)                         	; [...]
	POP_SR
	
	clr.b	d1                               	; [ldx #$00]
	PUSH_SR
	GET_ADDRESS	$10                       	; [stx $10]
	move.b	d1,(a0)                         	; [...]
	POP_SR
	
	move.b	#$30,d0                        		; [lda #$30] ; blank tile.
	PUSH_SR
	GET_ADDRESS	$0f                       	; [sta $0f]
	move.b	d0,(a0)                         	; [...]
	POP_SR
	
l_b1c4:
	GET_ADDRESS	$20                       	; [lda $20,x]
	move.b	(a0,d1.w),d0                    	; [...]
	lsr.b	#4,d0
	;lsr.b	#1,d0                            	; [lsr a]
	;lsr.b	#1,d0                            	; [lsr a]
	;lsr.b	#1,d0                            	; [lsr a]
	;lsr.b	#1,d0                            	; [lsr a]
	bne	l_b1ef                             	; [bne l_b1ef]
	GET_ADDRESS	$0f                       	; [lda $0f]
	move.b	(a0),d0                         	; [...]

l_b1ce:
	PUSH_SR
	GET_ADDRESS	$b6                       	; [sta $b6]
	move.b	d0,(a0)                         	; [...]
	POP_SR
	bsr.w	l_b2c6                           	; [jsr l_b2c6]
	GET_ADDRESS	$10                       	; [ldx $10]
	move.b	(a0),d1                         	; [...]
	GET_ADDRESS	$20                       	; [lda $20,x]
	move.b	(a0,d1.w),d0                    	; [...]
	and.b	#$0f,d0                         	; [and #$0f]
	bne	l_b1f6                             	; [bne l_b1f6]
	cmp.b	#$03,d1                         	; [cpx #$03]
	beq	l_b1f6                             	; [beq l_b1f6]
	GET_ADDRESS	$0f                       	; [lda $0f]
	move.b	(a0),d0                         	; [...]
l_b1e1:
	PUSH_SR
	GET_ADDRESS	$b6                       	; [sta $b6]
	move.b	d0,(a0)                         	; [...]
	POP_SR
	bsr.w	l_b2c6                            	; [jsr l_b2c6]
	GET_ADDRESS	$10                       	; [inc $10]
	addq.b	#1,(a0)                         	; [...]
	GET_ADDRESS	$10                       	; [ldx $10]
	move.b	(a0),d1                         	; [...]
	cmp.b	#$04,d1                         	; [cpx #$04]
	bne	l_b1c4                             	; [bne l_b1c4]
	rts                                    		; [rts]

l_b1ef:
	clr.b d2                               		; [ldy #$00]
	PUSH_SR
	GET_ADDRESS	$0f                       	; [sty $0f]
	move.b	d2,(a0)                         	; [...]
	POP_SR
	jmp	l_b1ce                             	; [jmp l_b1ce]
l_b1f6:
	clr.b	d2                               	; [ldy #$00]
	PUSH_SR
	GET_ADDRESS	$0f                       	; [sty $0f]
	move.b	d2,(a0)                         	; [...]
	POP_SR
	jmp	l_b1e1                             	; [jmp l_b1e1

l_b1fd:
	;kludge for now.
	move.b	#$78,d0                         	; [...]
	PUSH_SR
	GET_ADDRESS	$19                       	; [sta $19]
	move.b	d0,(a0)                         	; [...]
	POP_SR
	rts

l_b244:
	subq.b	#1,d1                           	; [dex]
	bne	l_b244                             	; [bne l_b244]
	subq.b	#1,d2                           	; [dey]
	bne	l_b244                             	; [bne l_b244]
	rts                                    		; [rts]
	
l_b295:
	PUSH_SR
	GET_ADDRESS		$be                     ; [stx $be]
	move.b	d1,(a0)                         	; [...]
	GET_ADDRESS	$bf                       	; [sty $bf]
	move.b	d2,(a0)                         	; [...]
	POP_SR
	
	clr.w	d2                               	; [ldy #$00]
	GET_ADDRESS_Y_ROM	$be                     ; [lda ($be),y] ; gets the y position
	move.b	(a0,d2.w),d0                    	; [...]
	lsl.b #1,d0
	PUSH_SR
	GET_ADDRESS	$b4                       	; [sta $b4]
	move.b	d0,(a0)                         	; [...]
	POP_SR
	cmp.b	#$30,d0                         	; [cmp #$18] 	; have we read 24 rows
	bcc	l_b2c5                             	; [bcs l_b2c5]
	addq.b	#1,d2                           	; [iny]
	
	GET_ADDRESS_Y_ROM	$be                     ; [lda ($be),y] - get the data from rom
	move.b	(a0,d2.w),d0                    	; [...] , gets the x position of text to print on screen.
	lsl.b #1,d0					; multiply x pos by 2 since each position on screen needs 2 bytes on the sega
	PUSH_SR
	GET_ADDRESS	$b5                       	; [sta $b5]	; store position in $b5
	move.b	d0,(a0)                         	; [...]
	POP_SR
	addq.b	#1,d2                           	; [iny]
	
	GET_ADDRESS_Y_ROM $be                     	; [lda ($be),y]
	move.b	(a0,d2.w),d0                    	; get first half of glyph
	and.b	#$7f,d0                         	; [and #$7f]
	jmp	l_b2b4                             	; [jmp l_b2b4]
l_b2b0:
	GET_ADDRESS	$ba                       	; [ldy $ba]
	move.b	(a0),d2                         	; [...]
	GET_ADDRESS_Y_ROM	$be                     ; [lda ($be),y]
	move.b	(a0,d2.w),d0                    	; [...]
l_b2b4:
	addq.b	#1,d2                           	; [iny]
	
	PUSH_SR
	GET_ADDRESS	$ba                       	; [sty $ba]
	move.b	d2,(a0)                         	; [...]
	POP_SR
	bmi.s	l_b2c5                             	; [bmi l_b2c5]
	tst.b	d0                               	; [cmp #$00]
	bmi.s	l_b2c5                             	; [bmi l_b2c5]
	PUSH_SR
	GET_ADDRESS	$b6                       	; [sta $b6]
	move.b	d0,(a0)                         	; [...]
	POP_SR
	bsr.s l_b2c6                            	; [jsr l_b2c6]
	jmp	l_b2b0                             	; [jmp l_b2b0]
l_b2c5:
	rts                                    		; [rts]

l_b2c6:
	
	; get from the high byte table
	GET_ADDRESS	$b4                       	; [ldy $b4]
	move.b	(a0),d2                         	; [...]
	GET_ADDRESS	l_b360                     	; [lda l_b360,y]
	move.b	(a0,d2.w),d0                    	; [...]
	PUSH_SR
	GET_ADDRESS	$b1                       	; [sta $b1]
	move.b	d0,(a0)                         	; [...]
	POP_SR
	
	; get from the low byte table
	GET_ADDRESS	l_b379		                ; [lda l_b360+$19,y]
	move.b	(a0,d2.w),d0                    	; gets high video address 0xc0
	CLR_XC_FLAGS                           		; [clc]
	GET_ADDRESS	$b5				; [adc $b5]
	move.b	(a0),d4								
	addx.b	d4,d0                         		
	PUSH_SR
	GET_ADDRESS	$b0                       	; [sta $b0]
	move.b	d0,(a0)                         	; [...]
	POP_SR              
	
	clr.w	d0                               	; [lda #$00]
	GET_ADDRESS	$b1                       	; [adc $b1]
	move.b	(a0),d4					; addx.b	(a0),d0
	addx.b	d4,d0                         		; [...]
	PUSH_SR
	GET_ADDRESS	$b1                       	; [sta $b1]
	move.b	d0,(a0)                         	; [...]
	POP_SR
	
	GET_ADDRESS	$b6                       	; [lda $b6]
	move.b	(a0),d0                         	; [...]
	clr.w	d2                               	; [ldy #$00]
	PUSH_SR
	GET_ADDRESS_Y_RAM	$b0                     ; [sta ($b0),y] ; write to video memory
	;move.l a0,d5
	;and.l #$0000FFFF,d5				; mask out the high word as we write to video memory
	;move.l d5,a0
	add.w d2,a0
	SetVRAMWriteReg a0
	move.w d0,vdp_data
	POP_SR
		
	or.b	#$80,d0                          	; [ora #$80] ; index into table for bottom half of character
	move.b	#$80,d2                        		; [ldy #$28] ; #$80 for the next row down
	
	; render top row of text
	PUSH_SR
	GET_ADDRESS_Y_RAM	$b0            		; [sta ($b0),y] ; write to video memory
	;move.l a0,d5
	;and.l #$0000FFFF,d5				; mask oout the high word as we write to video memory
	;move.l d5,a0
	add.w d2,a0
	SetVRAMWriteReg a0
	move.w d0,vdp_data	
	POP_SR
	
	GET_ADDRESS	$b5                       	; [inc $b5]
	addq.b	#2,(a0)                         	; [...] 2 bytes per char on the sega megadrive
	and.b	#$7f,d0                         	; [and #$7f]
	cmp.b	#$3a,d0                         	; [cmp #$3a]
	
	bcs	l_b301                             	; [bcc l_b301]
	cmp.b	#$5a,d0                         	; [cmp #$5a]
	bcc	l_b301                             	; [bcs l_b301]
	move.b	#$02,d2                        		; [ldy #$01]
	move.b	#$20,d4					; addx.b	#0x20,d0  ; [adc #$20]
	addx.b	d4,d0                        		; [adc #$20]
	
	; render second half of character of two glyph letter
	PUSH_SR
	GET_ADDRESS_Y_RAM	$b0                     ; [sta ($b0),y] ; write to video memory
	;move.l a0,d5
	;and.l #$0000FFFF,d5				; mask out the high word as we write to video memory
	;move.l d5,a0
	add.w d2,a0
	SetVRAMWriteReg a0
	move.w d0,vdp_data	
	POP_SR
	
	or.b	#$80,d0                          	; [ora #$80]	; bottom row glyph / tile
	move.b	#$82,d2                        		; [ldy #$29]	; render second half of glyph
	
	PUSH_SR
	GET_ADDRESS_Y_RAM	$b0                     ; [sta ($b0),y] ; write to video memory
	;move.l a0,d5
	;and.l #$0000FFFF,d5				;  mask oout the high word as we write to video memory
	;move.l d5,a0
	add.w d2,a0
	SetVRAMWriteReg a0
	move.w d0,vdp_data		
	POP_SR
	
	GET_ADDRESS	$b5                       	; [inc $b5]
	addq.b	#2,(a0)                         	; 2 bytes per char position on sega

l_b301:
	rts 

	;=================================================	
	;incremements low byte vector a number of times
	;specified by x. this allows copying large chunks
	;from one address specified by $b2,$b3 ( 2 bytes )
	;to $b0,$b1
	;=================================================	

l_b302:
	clr.w	d2                               	; [ldy #$00]
	bsr.s	l_b30f                            	; [jsr l_b30f]
	GET_ADDRESS	$b3                       	; [inc $b3]
	addq.b	#1,(a0)                         	; [...]
	GET_ADDRESS	$b1                       	; [inc $b1]
	addq.b	#1,(a0)                         	; [...]
	subq.b	#1,d1                           	; [dex]
	bne	l_b302                             	; [bne l_b302
	rts                                    		; [rts]

	;=============================================
	;block copy, 0-ff bytes
	;is called by l_b302 x times or called outside
	;=============================================

l_b30f:
	GET_ADDRESS_Y_ROM	$b2                     ; [lda ($b2),y]
	move.b	(a0,d2.w),d0                    	; [...]
	PUSH_SR
	GET_ADDRESS_Y	$b0                     	; [sta ($b0),y]
	move.b	d0,(a0,d2.w)                    	; [...]
	POP_SR
	subq.b	#1,d2                           	; [dey]
	bne	l_b30f                             	; [bne l_b30f]
	GET_ADDRESS_Y_ROM	$b2                     ; [lda ($b2),y]
	move.b	(a0,d2.w),d0                    	; [...]
	PUSH_SR
	GET_ADDRESS_Y	$b0                     	; [sta ($b0),y]
	move.b	d0,(a0,d2.w)                    	; [...]
	POP_SR
	rts                                    		; [rts]

l_b31b:

	GET_ADDRESS	$62                       	; [lda $62]
	move.b	(a0),d0                         	; [...]
	and.b	#$03,d0                         	; [and #$03]
	bne	l_b35f                             		; [bne l_b35f]
	GET_ADDRESS	$19                       	; [lda $19]
	move.b	(a0),d0                         	; [...]
	and.b	#$40,d0                         	; [and #$40]
	bne	l_b35f                             	; [bne l_b35f]
	GET_ADDRESS	$19                       	; [lda $19]
	move.b	(a0),d0                         	; [...]
	bpl	l_b336                             	; [bpl l_b336]
	GET_ADDRESS	$95                       	; [lda $95]
	move.b	(a0),d0                         	; [...]
	cmp.b	#$0f,d0                         	; [cmp #$0f]
	bcc	l_b33e                             	; [bcs l_b33e]
	GET_ADDRESS	$95                       	; [inc $95]
	addq.b	#1,(a0)                         	; [...]
	jmp	l_b33e                             	; [jmp l_b33e]
l_b336:
	GET_ADDRESS	$95                       	; [lda $95]
	move.b	(a0),d0                         	; [...]
	tst.b	d0                               	; [cmp #$00]
	beq	l_b33e                             	; [beq l_b33e]
	GET_ADDRESS	$95                       	; [dec $95]
	subq.b	#1,(a0)                         	; [...]
l_b33e:
	GET_ADDRESS	$95                       	; [lda $95]
	move.b	(a0),d0                         	; [...]
	cmp.b	#$0a,d0                         	; [cmp #$0a]
	bcs	l_b34b                             		; [bcc l_b34b]
	SBC_IMM	$0a                           		; [sbc #$0a]
	move.b	#$01,d2                        		; [ldy #$01]
	jmp	l_b34d                             	; [jmp l_b34d]
l_b34b:
	move.b	#$30,d2                        		; [ldy #$30]
l_b34d:
	PUSH_SR
	GET_ADDRESS	l_b3c0+1                   	; [sty l_b3c0+1]
	move.b	d2,(a0)                         	; use ZP ram, to do later
	GET_ADDRESS	l_b3c0+2                   	; [sta l_b3c0+2]
	move.b	d0,(a0)                         	; use ZP ram, to do later
	POP_SR
	GET_ADDRESS	$95                       	; [lda $95]
	move.b	(a0),d0                         	; [...]
	PUSH_SR
	GET_ADDRESS	$ef                       	; [sta $ef]
	move.b	d0,(a0)                         	; [...]
	POP_SR
	nop                                    		; [nop]
	move.w #l_b3b8,d2				; [ldx #<l_b3b8] / [ldy #>l_b3b8]
	move.b d2,d1
	lsr.w #8,d2
	bsr.w l_b295					; [jsr l_b295]
l_b35f:
	rts                                    		; [rts]
	
test_sprite:

	; Some junk code to test the sprite engine
	;==============================================================
	; Set up the Sprite Attribute Table (SAT)
	;==============================================================

	; The Sprite Attribute Table is a table of sprites to draw.
	; Each entry in the table describes the first tile ID, the number
	; of tiles to draw (and their layout), the X and Y position
	; (on the 512x512 sprite plane), the palette to draw with, a
	; priority flag, and X/Y flipping flags.
	;
	; Sprites can be layed out in these tile dimensions:
	;
	; 1x1 (1 tile)  - 0000
	; 1x2 (2 tiles) - 0001
	; 1x3 (3 tiles) - 0010
	; 1x4 (4 tiles) - 0011
	; 2x1 (2 tiles) - 0100
	; 2x2 (4 tiles) - 0101
	; 2x3 (6 tiles) - 0110
	; 2x4 (8 tiles) - 0111
	; 3x1 (3 tiles) - 1000
	; 3x2 (6 tiles) - 1001
	; 3x3 (9 tiles) - 1010
	; 3x4 (12 tiles)- 1011
	; 4x1 (4 tiles) - 1100
	; 4x2 (8 tiles) - 1101
	; 4x3 (12 tiles)- 1110
	; 4x4 (16 tiles)- 1111
	;
	; The tiles are layed out in COLUMN MAJOR, rather than planes A and B
	; which are row major. Tiles within a sprite cannot be reused (since it
	; only accepts a starting tile and a count/layout) so the whole sprite
	; needs uploading to VRAM in one consecutive chunk, even if some tiles
	; are duplicates.
	;
	; The X/Y flipping flags take the layout into account, you don't need
	; to re-adjust the layout, position, or tile IDs to flip the entire
	; sprite as a whole.
	;
	; There are 64 entries in the table, but the number of them drawn,
	; and the order in which they're processed, is determined by a linked
	; list. Each sprite entry has an index to the NEXT sprite to be drawn.
	; If this index is 0, the list ends, and the VDP won't draw any more
	; sprites this frame.

	; Start writing to the sprite attribute table in VRAM
	; move this to uridium.asm, here for testing for now.,
	SetVRAMWriteConst vram_addr_sprite_table
	
	;==============================================================
	; Set up sprite 1

	; Write all values into registers first to make it easier. We
	; write to VRAM one word at a time (auto-increment is set to 2
	; in VDP register 0xF), so we'll assign each word to a register.
	;
	; Since bit twiddling and manipulating structures isn't the focus of
	; this sample, we have a macro to simplify this part.

	; Position:   sprite_1_start_pos_x,sprite_1_start_pos_y
	; Dimensions: 2x2 tiles (8 tiles total) = 0101 in binary (see table above)
	; Next link:  sprite index 1 is next to be processed
	; Priority:   0
	; Palette id: 0
	; Flip X:     0	
	; Flip Y:     0
	; Tile id:    tile_id_sprite_1
	
	BuildSpriteStructure sprite_1_start_pos_x,sprite_1_start_pos_y,%1010,$1,$0,$0,$0,$0,tile_id_sprite_1,d0,d1,d2,d3
	; Write the entire sprite attribute structure to the sprite table
	move.w d0,vdp_data
	move.w d1,vdp_data
	move.w d2,vdp_data
	move.w d3,vdp_data
	
	;==============================================================
	; Intitialise variables in RAM
	;==============================================================
	move.w #sprite_1_start_pos_x,ram_sprite_1_pos_x
	move.w #sprite_1_start_pos_y,ram_sprite_1_pos_y
	rts


	;  include 68k game code here
CPUInit:
	moveq	#0,d0
	moveq	#0,d1
	moveq	#0,d2
	moveq	#0,d3
	moveq	#0,d4
	moveq	#0,d5
	moveq	#0,d6
	moveq	#0,d7
	rts	
	
	;==============================================================
	; C64 emulation, do something useful based on address
	;==============================================================
get_address:
	cmp 	#$ff,a0
	ble.s	getZPAddress				; read zero page
	cmp.l  #$d015,a0
	beq.s	handleSpriteEnable			; use the sega debug register
	cmp.l 	#$d021,a0				; get bg colour register
	beq.s	changeBackgroundColour
	rts
	
handleSpriteEnable:
	; to do
	; 0xc0001c may not be supported in MAME
	rts

changeBackgroundColour:					; [ d0 = colour index, d1 = palette index ]
	move.w	#vdpreg_bgcol,d2			; background colour register
	add.b	d0,d2					; index the colour
	or.w	d1,d2					; select the palette 0x00,0x10,0x20,0x30
	move.w d2,vdp_control 				; Set background colour to palette 0, colour 8
	rts

getZPAddress:
	add.l	#ZERO_PAGE_BASE,a0			; get base address of 0xFF0000				
	rts
	
setupSourceCopy:
	move.b  d2,d1
	lsr.w	#8,d2					; get high byte
	PUSH_SR
	GET_ADDRESS	$b2                       	; [stx $b2] $00 in b2
	move.b	d1,(a0)                         	; [...]
	GET_ADDRESS	$b3                       	; [sty $b3] $80 in b3
	move.b	d2,(a0)                         	; [...]
	POP_SR
	rts
	
setupDestinationCopy:
	move.b  d2,d1
	lsr.w	#8,d2					; get high byte
	PUSH_SR
	GET_ADDRESS	$b0                       	; [stx $b0] $00 in b0
	move.b	d1,(a0)                         	; [...]
	GET_ADDRESS	$b1                       	; [sty $b1] $e0 in b1 ; $e000
	move.b	d2,(a0)                         	; [...]
	POP_SR
	move.b	#$20,d1                        		; [ldx #$20]
	bsr.w	l_b302                           	; [jsr l_b302] copies blocks of data 256 * x - 1 times
	rts
	
	;==============================================================
	; PALETTE
	;==============================================================
	; A single colour palette (16 colours) we'll be using to draw text.
	; Colour #0 is always transparent, no matter what colour value
	; you specify.
	; We only use white (colour 2) and transparent (colour 0) in this
	; demo, the rest are just examples.
	;==============================================================
	; Each colour is in binary format 0000 BBB0 GGG0 RRR0,
	; so 0x0000 is black, 0x0EEE is white (NOT 0x0FFF, since the
	; bottom bit is discarded), 0x000E is red, 0x00E0 is green, and
	; 0x0E00 is blue.
	;==============================================================
	even
C64Palette:
	dc.w $0000	; Colour 0 = Black / Transparent
	dc.w $0EEE	; Colour 1 = White
	dc.w $0009	; Colour 2 = Red
	dc.w $0EEA	; Colour 3 = Cyan
	dc.w $0C4C ; Colour 4 = Violet
	dc.w $05c0 ; Colour 5 = Green
	dc.w $0A00 ; Colour 6 = Blue
	dc.w $07EE	; Colour 7 = Yellow
	dc.w $058D	; Colour 8 = Orange
	dc.w $0046	; Colour 9 = Brown
	dc.w $077F	; Colour A = Light red
	dc.w $0333	; Colour B = Dark Grey
	dc.w $0777	; Colour C = Grey
	dc.w $06FA	; Colour D = Light Green
	dc.w $0F80	; Colour E = Light Blue
	dc.w $0BBB	; Colour F = Light Grey
	
MiscPalette:
	dc.w $0000 ; Colour 0 - Transparent
	dc.w $000E ; Colour 1 - Red
	dc.w $00E0 ; Colour 2 - Green
	dc.w $0E00 ; Colour 3 - Blue
	dc.w $0000 ; Colour 4 - Black
	dc.w $0EEE ; Colour 5 - White
	dc.w $00EE ; Colour 6 - Yellow
	dc.w $008E ; Colour 7 - Orange
	dc.w $0E0E ; Colour 8 - Pink
	dc.w $0808 ; Colour 9 - Purple
	dc.w $0444 ; Colour A - Dark grey
	dc.w $0888 ; Colour B - Light grey
	dc.w $0EE0 ; Colour C - Turquoise
	dc.w $000A ; Colour D - Maroon
	dc.w $0600 ; Colour E - Navy blue
	dc.w $0060 ; Colour F - Dark green

	;==========
	; Game data
	;==========
	include 'gamedata.asm'	 						; game data
	include 'bgObjectData.asm'
	include 'scrollTextData.asm'						; scroll text and level 15 data
	
	even
	;=======================================================
	; VIC II ptrs to character memory - from 4800 on the c64
	; Sega uses 0xc000
	;=======================================================
l_b360:
	; High Byte Video Address - 25 rows
	dc.b charRamHi,charRamHi,charRamHi,charRamHi
	dc.b charRamHi+1,charRamHi+1,charRamHi+1,charRamHi+1
	dc.b charRamHi+2,charRamHi+2,charRamHi+2,charRamHi+2
	dc.b charRamHi+3,charRamHi+3,charRamHi+3,charRamHi+3
	dc.b charRamHi+4,charRamHi+4,charRamHi+4,charRamHi+4
	dc.b charRamHi+5,charRamHi+5,charRamHi+5,charRamHi+5
	dc.b charRamHi+6,charRamHi+6,charRamHi+6,charRamHi+6
	dc.b charRamHi+7,charRamHi+7,charRamHi+7,charRamHi+7
	dc.b charRamHi+8,charRamHi+8,charRamHi+8,charRamHi+8
	dc.b charRamHi+9,charRamHi+9,charRamHi+9,charRamHi+9
	dc.b charRamHi+$a,charRamHi+$a,charRamHi+$a,charRamHi+$a
	dc.b charRamHi+$b,charRamHi+$b,charRamHi+$b,charRamHi+$b
	dc.b charRamHi+$c,charRamHi+$c,charRamHi+$c

l_b379:
	; Low Byte Video Address - The sega has 64 characters per row
	dc.b $00,$40,$80,$c0
	dc.b $00,$40,$80,$c0
	dc.b $00,$40,$80,$c0
	dc.b $00,$40,$80,$c0
	dc.b $00,$40,$80,$c0
	dc.b $00,$40,$80,$c0
	dc.b $00,$40,$80,$c0
	dc.b $00,$40,$80,$c0
	dc.b $00,$40,$80,$c0
	dc.b $00,$40,$80,$c0
	dc.b $00,$40,$80
	
l_b3b8:
	dc.b $00,$0f,$4f,$18,$15,$1e,$42,$0e

l_b3c0:
	dc.b $30,$00,$05,$ff,$20,$44,$b5,$85
	dc.b $bd,$c9,$46,$f0,$0d,$c9,$53,$d0
	

	;================================
	;Include game assets
	;================================
	include 'assets\chrsets\chrset1.asm'	; default character set
	include 'assets\sprites\manta.asm' 	; manta
 
