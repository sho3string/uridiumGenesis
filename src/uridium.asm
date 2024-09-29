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
	
	
	;=========================
	; Self modifying variables
	;=========================
	
	; Load the frame counter into d0 (use as a seed)
    move.b  $C00008,$00ffd41b
	; Move address of character set 2 into 0x00ff7800
	move.l	#$0000a000,$00ff7800
	; Move 0x80 into 0x00ff0180, used at l_2a7
	move.b #$80,$00ff0180
	; Move 0x10 into 0x00ff0181
	move.b #$10,$00ff0181
	

	;=================
	; Change bg colour
	;=================
	move.b	#$00,d0								; select the palette colour
	move.b	#palette_a,d1						; select the palette
	;PUSH_SR
	GET_ADDRESS	$d021						; [sta $d021] background color
	move.b	d0,(a0)								; [...]
	;POP_SR
	
	;=========
	; Clear ZP
	;=========
	move.w	#$fe,d2 							; [ldy #$fe] %11111110
	clr.b	d0									; [lda #$00]
l_0916:
	;PUSH_SR
	;GET_ADDRESS $0001 						; [sta $0001,y] clears zero page addresses from 0xff to 0x02
	lea $00ff0001,a0
    move.b	d0,(a0,d2.w)						; [...]
	dbra d2,l_0916
	;POP_SR
	;subq.b	#1,d2								; [dey]
	;bne	l_0916									; [bne l_0916]


	;========================================
	; Copy star generation data to 0x00ff0800
	;========================================
	lea l_800,a0
	move.w #$ff,d2								; 256
SGL:											; Start of loop
	lea $00ff0800,a1
	move.b	(a0,d2.w),(a1,d2.w)
	dbra d2,SGL	
	
	; loads data from one table at $8000-$9fff and reproduces
	; the data at $e000-$ffff. it achieves this by storing the 16 bit
	; vectors at $b2,$b3 and $b0,$b1 and incrementing the high byte
	; ie the value stored in $b3 & $b1

	;================================================
	; Copy bgObjectData in ROM to FF0E000 and FF08000
	;================================================

	move.w	#l_8000,d2
	bsr.w	setupSourceCopy				; ROM source

	move.w	#$e000,d2						; RAM - 0xFFE000
	bsr.w	setupDestinationCopy
	
	move.w	#l_8000,d2
	bsr.w	setupSourceCopy				; ROM source

	move.w	#$8000,d2						; RAM - 0xFF8000
	bsr.w	setupDestinationCopy
	
	;==========
	; Game init
	;==========
	bsr.w	l_25e5							; [jsr l_25e5] manta shadows generated here.
	
	;Clears the high score summary area, first 4 rows.
	move.b	#$04,d3 						; [ldx #$02]
	move.b	#$30,d0							; [lda #$30] select tile
	lea vram_addr_plane_a,a1
	SetVRAMWriteReg a1
	bsr.w	l_b189							; [jsr l_b189] fills first 4 rows with d0
	
	; test sprite
	bsr.w test_sprite
	
	;===============
	; Player 2 score
	;===============
	; use address pointer as we can't write to rom ( l_b1b8+1 )
	PUSH_SR
	;GET_ADDRESS	$0						; [sta l_b1b8+1] -- use first byte in ram.
	move.b #$3e,$00ff0000					; start even
	POP_SR
	bsr.w	l_b1b4 							; [jsr l_b1b4]
	
	
	;===================
	; Player 1 score
	;===================
	PUSH_SR
	;GET_ADDRESS	$0						; [sta l_b1b8+1] -- use first byte in ram.
	move.b	#$02,$00ff0000					; [...]
	POP_SR
	bsr.w	l_b1b4							; [jsr l_b1b4]
	
	move.b	#$01,d0							; [lda #$01]
	PUSH_SR
	;GET_ADDRESS	$5c						; [sta $5c]
	move.b	d0,$00ff005c					; [...]
	POP_SR

l_0a20:	
	
	;=============================
	; Render Score colours - Green
	;=============================
	
	
	
	;=========
	; Player 1
	;=========
	;generates player 1 text on screen
	move.w	#gamedataTextP1,d2
	move.b  d2,d1
	lsr.w	#8,d2							; get high byte
	bsr.w l_b295
	

	;=========
	; Player 2
	;=========
	;generates player 2 text on screen
	move.w	#gamedataTextP2,d2 			; 0xc02
	move.b  d2,d1
	lsr.w	#8,d2							; get high byte
	bsr.w l_b295
	
	;==================================
	;Initialises large text scroll data
	;==================================
	
	bsr.w	l_2415                            	; [jsr l_2415]
	move.b	#$03,d0                        		; [lda #$03]
	PUSH_SR
	;GET_ADDRESS	$5b                       ; [sta $5b]
	move.b	d0,$00ff005b						; [...]
	POP_SR
	

l_0a6f:
	bsr.w	l_17cc                            	; [jsr l_17cc] - sets up interrupt to irq1 - to do
	clr.b	d0                               	; [lda #$00] disable sprites
	;PUSH_SR
	;GET_ADDRESS	$d015                     ; [sta $d015] sprite enable register
	move.b	d0,$00ffd015                       ; [...]
	;GET_ADDRESS	$5a                       ; [sta $5a]
	move.b	d0,$00ff005a                       ; [...]
	;GET_ADDRESS	$28                       ; [sta $28]
	move.b	d0,$00ff0028                       ; [...]
	;POP_SR
	move.b	#$11,d0                        		; [lda #$11]
	;PUSH_SR
	;GET_ADDRESS	$90                       ; [sta $90]
	move.b	d0,$00ff0090                       ; [...]
	;POP_SR
	

	;============
	;Clear screen
	;============
	move.b #$30,d0                        		; [lda #$30] - tile #
	move.w #$4,d1								; start clearing screen 4 rows down
	lsl.w #7,d1									; x 8
	lea vram_addr_plane_a,a1					
	add.w d1,a1
	SetVRAMWriteReg a1
	bsr.w	l_2397                            	; [jsr l_2397]
	
	move.b #$20,d0                        		; [lda #$30] - tile #
	move.w #$4,d1								; start clearing screen 4 rows down
	lsl.w #7,d1									; x 8
	lea vram_addr_plane_b,a1					
	add.w d1,a1
	SetVRAMWriteReg a1
	bsr.w	l_2397                            	; [jsr l_2397]
	
	; test
	;SetVRAMWriteConst $C986
	;move.w #$01,vdp_data
	;SetVRAMWriteConst $C434
	;move.w #$01,vdp_data
	;SetVRAMWriteConst $CB3A
	;move.w #$01,vdp_data
	;SetVRAMWriteConst $C684
	;move.w #$01,vdp_data
	
	lea $00ff1c2c,a0							; set default address to l_1c73 @ 1c2c
	move.l #l_1c73,(a0)

	
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
	
	;=================================
	;Scrolling routine with large text
	;=================================
	bne.s	l_0ad4						; [bne l_0ad4] scrolling attract mode.
	
	;===================
	;Player pressed fire
	;When equal to zero
	;===================
	jmp	l_0b65							; [jmp l_0b65] game starts here
	
	;============================
	;Pre demo - scrolling attract
	;============================
l_0ad4:
	clr.b	d0							; [lda #$00]
	;PUSH_SR
	;GET_ADDRESS	$26					; [sta $26]
	move.b	d0,$00ff0026				; [...]
	;POP_SR
	move.b	#$0f,d0						; [lda #$0f]
	;PUSH_SR
	;GET_ADDRESS	$8d					; [sta $8d]
	move.b	d0,$00ff008d				; [...]
	;POP_SR
	bsr.w	l_20ec						; [jsr l_20ec]
	move.b	#$fc,d0						; [lda #$fc]
	;PUSH_SR
	;GET_ADDRESS	$2e					; [sta $2e]
	move.b	d0,$00ff002e				; [...]
	;POP_SR
	bsr.w	l_217e						; [jsr l_217e]
	;GET_ADDRESS	$18					; [lda $18]
	move.b	$00ff0018,d0				; [...]
	bne	l_0aed							; [bne l_0aed] - hall of fame screen.
	jmp	l_0b65							; [jmp l_0b65] - init scores, player pressed fire
	
	;===================
	;Hall Of Fame Screen
	;===================

l_0aed:
	bsr.w	l_17cc                          ; [jsr l_17cc]
	
	;===================
	;Clear planes
	;===================
	move.b #$30,d0                        		; [lda #$30] - tile #
	move.w #$4,d1								; start clearing screen 4 rows down
	lsl.w #7,d1									; x 8
	lea vram_addr_plane_a,a1					
	add.w d1,a1
	SetVRAMWriteReg a1
	bsr.w	l_2397                            	; [jsr l_2397]
	
	move.b #$20,d0                        		; [lda #$30] - tile #
	move.w #$4,d1								; start clearing screen 4 rows down
	lsl.w #7,d1									; x 8
	lea vram_addr_plane_b,a1					
	add.w d1,a1
	SetVRAMWriteReg a1
	bsr.w	l_2397                            	; [jsr l_2397]
	
	; colours
	;move.b	#$a0,d1                        	; [ldx #$a0]
	;move.b	#$d8,d2                        	; [ldy #$d8]
	;PUSH_SR
	;GET_ADDRESS	$1c                       ; [stx $1c]
	;move.b	d1,(a0)                         	; [...]
	;GET_ADDRESS	$1d                       ; [sty $1d]
	;move.b	d2,(a0)                         	; [...]
	
	;POP_SR
	;move.b	#$63,d1                        	; [ldx #$63]
	;move.b	#$37,d2                        	; [ldy #$37]
	;PUSH_SR
	;GET_ADDRESS	$1a                       ; [stx $1a]
	;move.b	d1,(a0)                         	; [...]
	;GET_ADDRESS	$1b                       ; [sty $1b]
	;move.b	d2,(a0)                         	; [...]
	;POP_SR
	;move.b	#$14,d2                        	; [ldy #$14]
	;bsr.w	l_23a5                           ; [jsr l_23a5]
	
	move.w #gamedataTextHOF,d2				; [ldx #$f5] , [ldy #$34]
	move.b d2,d1
	lsr.w #8,d2
	bsr.w l_b295	
	
	move.w #gamedataTextHigh,d2						
	move.b d2,d1
	lsr.w #8,d2
	bsr.w l_b295	
	
	move.w #gamedataTextSecond,d2						
	move.b d2,d1
	lsr.w #8,d2
	bsr.w l_b295	
	
	move.w #gamedataTextThird,d2		
	move.b d2,d1
	lsr.w #8,d2
	bsr.w	l_b295 

	move.w #gamedataTextFourth,d2		
	move.b d2,d1
	lsr.w #8,d2
	bsr.w	l_b295 
	
	move.w #gamedataTextFifth,d2		
	move.b d2,d1
	lsr.w #8,d2
	bsr.w	l_b295 
	
	move.w #gamedataTextSixth,d2		
	move.b d2,d1
	lsr.w #8,d2
	bsr.w	l_b295
	
	move.w #gamedataTextSeventh,d2		
	move.b d2,d1
	lsr.w #8,d2
	bsr.w	l_b295
	
	move.w #gamedataTextEighth,d2				; not working ?
	move.b d2,d1
	lsr.w #8,d2
	bsr.w	l_b295 

	bsr.w	l_2150                            	; [jsr l_2150]
	GET_ADDRESS	$18                       	; [lda $18]
	move.b	(a0),d0                         	; [...]
	beq	l_0b65                             		; [beq l_0b65]
	
	move.w #gamedataTextDemo,d2		
	move.b d2,d1
	lsr.w #8,d2
	bsr.w	l_b295 
	
	;============
	;Attract Demo
	;============
	bsr.w l_21b5								; to do once scrolling is fixed.
	
	;GET_ADDRESS	$18                       ; [lda $18]
	move.b	$00ff0018,d0                       ; [...]
	beq	l_0b65                             		; [beq l_0b65]
	jmp	l_0a6f                             		; [jmp l_0a6f]
	
	; End of attract main loop
	
	;==============
	;Game Play Loop
	;==============
	
l_0b65:
	move.w	#$08,d1                        		; [ldx #$08]
l_0b67:
	lea l_3496,a0               				; [lda l_310a+$38c,x]
	move.b	(a0,d1.w),d0                    	; [...]
	PUSH_SR
	;GET_ADDRESS	$0250                     ; [sta $0250,x]
	lea $00ff0250,a0
    move.b	d0,(a0,d1.w)                 		; [...]
	;GET_ADDRESS	$0260                     ; [sta $0260,x]
    lea $00ff0260,a0
	move.b	d0,(a0,d1.w)                 		; [...]
	;GET_ADDRESS	$20                       ; [sta $20,x]
	lea $00ff0020,a0
    move.b	d0,(a0,d1.w)                 		; [...]
	POP_SR
	subq.b	#1,d1                           	; [dex]
	bpl	l_0b67                             		; [bpl l_0b67]
	
	move.b	#$12,d0                        		; [lda #$12]
	;PUSH_SR
	;GET_ADDRESS	$90                       ; [sta $90]
	move.b	d0,$00ff0090                       ; [...]
	;POP_SR
	move.b	#$02,d0                        		; [lda #$02]
	;PUSH_SR
	;GET_ADDRESS	$5d                       ; [sta $5d]
	move.b	d0,$00ff005d                       ; [...]
	;POP_SR
	bsr.w	l_19b7                            	; [jsr l_19b7]

	move.b	#$2f,d0                        		; [lda #$2f]
	;PUSH_SR
	;GET_ADDRESS	l_3f45               		; [sta l_310a+$e40] - 
	;move.b	d0,l_3f45                         ; [...]
	;POP_SR
	move.b	#$01,d0                        		; [lda #$01]
	;PUSH_SR
	;GET_ADDRESS	$5d                       ; [sta $5d]
	move.b	d0,$00ff005d                       ; [...]
	;POP_SR
	move.b	#$02,d0                        		; [lda #$02]
	;PUSH_SR
	;GET_ADDRESS	$5a                       ; [sta $5a]
	move.b	d0,$00ff005a                       ; [...]
	;POP_SR
	move.b	#$09,d0                        		; [lda #$09]
	;PUSH_SR
	;GET_ADDRESS	$8d                       ; [sta $8d]
	move.b	d0,$00ff008d                       ; [...]
	;POP_SR
	move.b	#$1f,d0                        		; [lda #$1f]
	;PUSH_SR
	;GET_ADDRESS	l_b1b8+1                  ; [sta l_b1b8+1]
	move.b	d0,$00ff0000                       ; [...]
	;POP_SR
	bsr.w	l_b1b4                            	; [jsr l_b1b4]
	move.b	#$01,d0                        		; [lda #$01]
	;PUSH_SR
	;GET_ADDRESS	l_b1b8+1                  ; [sta l_b1b8+1]
	move.b	d0,$00ff0000                       ; [...]
	;POP_SR
	bsr.w	l_b1b4                            	; [jsr l_b1b4]

	; to do once we complete attract mode
l_0ba1:
l_0baf:
l_0bcc:
l_0be8:
	
l_0e23:
	;GET_ADDRESS	$90						; [lda $90]
	lea $00ff0090,a0
	move.b	(a0),d0							; [...]
	beq	l_0e67                             	; [beq l_0e67]
	cmp.b	#$02,d0							; [cmp #$02]
	bne	l_0e2e                             	; [bne l_0e2e]
	jmp	l_0f5c                             	; [jmp l_0f5c]
	
l_0e2e:
	cmp.b	#$01,d0							; [cmp #$01]
	bne	l_0e35                             	; [bne l_0e35]
	jmp	l_0e6b                             	; [jmp l_0e6b]
l_0e35:
	cmp.b #$03,d0                         	; [cmp #$03]
	bne	l_0e3c                             	; [bne l_0e3c]
	jmp	l_0f5c                             	; [jmp l_0f5c]
l_0e3c:
	cmp.b	#$11,d0							; [cmp #$11]
	beq	l_0e49                             	; [beq l_0e49]
	cmp.b	#$12,d0							; [cmp #$12]
	beq	l_0e5f                             	; [beq l_0e5f]
	cmp.b	#$13,d0							; [cmp #$13]
	beq	l_0e49                             	; [beq l_0e49]
	rts                                    	; [rts]
l_0e49:
	bsr.w	l_1108                        	; [jsr l_1108]
	;GET_ADDRESS	$95                   ; [lda $95]
	move.b	$00ff0095,d0                   ; [...]
	PUSH_SR
	;GET_ADDRESS	$ef						; [sta $ef]
	move.b	d0,$00ff00ef					; [...]
	POP_SR
	move.b	#$01,d0                        	; [lda #$01]
	PUSH_SR
	;GET_ADDRESS	$f2						; [sta $f2]
	move.b	d0,$00ff00f2					; [...]
	POP_SR
	clr.b	d0								; [lda #$00]
	PUSH_SR
	GET_ADDRESS	l_3e99             		; [sta l_3942+$557] - 3e99, fix this
	move.b	d0,(a0)							; [...]
	POP_SR
	move.b	#$fe,d0                        	; [lda #$fe]
	PUSH_SR
	GET_ADDRESS	l_3e99+1            	; [sta l_3942+$558] - 3e9a, fix this
	move.b	d0,(a0)							; [...]
	POP_SR
	rts                                    	; [rts]
l_0e5f:
	bsr.w	l_1108							; [jsr l_1108]
	move.b	#$0f,d0                        	; [lda #$0f]
	PUSH_SR
	GET_ADDRESS	$ef						; [sta $ef]
	move.b	d0,(a0)							; [...]
	POP_SR
	rts                                    	; [rts]
l_0e67:
	bsr.w l_1108                           ; [jsr l_1108]
l_0e6a:
	rts 
l_0e6b:
	GET_ADDRESS	$f2						; [dec $f2]
	subq.b	#1,(a0)							; [...]
	beq	l_0e72                             	; [beq l_0e72]
	jmp	l_0f5c                             	; [jmp l_0f5c]
	
l_0e72:
	move.b	#$05,d0                        	; [lda #$05]
	PUSH_SR
	GET_ADDRESS	 $f2                    ; [sta $f2]
	move.b	d0,(a0)                        ; [...]
	POP_SR
	GET_ADDRESS	 l_3e99+1            	; [lda l_3942+$558] - fix this
	move.b	(a0),d0                        ; [...]
	cmp.b	#$ff,d0                        ; [cmp #$ff]
	beq	l_0e6a                             	; [beq l_0e6a]
	cmp.b	#$fe,d0                         ; [cmp #$fe]
	bne	l_0eb3                             	; [bne l_0eb3]
	
l_0e81:
	GET_ADDRESS	l_3e99               	; [lda l_3942+$557] - fix this
	move.b	(a0),d0                         ; [...]
	asl.b	#1,d0                            ; [asl a]
	CLR_XC_FLAGS                           ; [clc]

	GET_ADDRESS	l_3e99               	; [adc l_3942+$557] - fix this
	move.b	(a0),d4							;	addx.b	(a0),d0  ; [...]
	addx.b	d4,d0                         	; [...]
	move.b	d0,d2                           ; [tay]
	GET_ADDRESS	l_3d2c                    ; [lda $3d2c,y]
	move.b	(a0,d2.w),d0                    ; [...]
	
	PUSH_SR
	GET_ADDRESS	l_3e99+1				; [sta l_3942+$558]
	move.b	d0,(a0)                         ; [...]
	POP_SR
	clr.b	d1								; [ldx #$00]
	cmp.b	#$ff,d0							; [cmp #$ff]
	bne	l_0e97                             	; [bne l_0e97]
	rts                                    	; [rts]
	
l_0e97:
	GET_ADDRESS	l_3d2c                     	; [lda $3d2c,y]
	move.b	(a0,d2.w),d0                    	; [...]
	PUSH_SR
	GET_ADDRESS	$a0                       	; [sty $a0]
	move.b	d2,(a0)                         	; [...]
	POP_SR
	move.b	d0,d2                           	; [tay]
	GET_ADDRESS	l_3d71                     	; [lda $3d71,y]
	move.b	(a0,d2.w),d0                    	; [...]
	PUSH_SR
	GET_ADDRESS	$f3                       	; [sta $f3,x]
    move.b	d0,(a0,d1.w)                 	; [...]
	POP_SR
	GET_ADDRESS	l_3d90                     	; [lda $3d90,y]
	move.b	(a0,d2.w),d0                    	; [...]
	PUSH_SR
	GET_ADDRESS	$fc                       	; [sta $fc,x]
    move.b	d0,(a0,d1.w)                 	; [...]
	POP_SR
	move.b	#$01,d0                        	; [lda #$01]
	PUSH_SR
	GET_ADDRESS	$f6                       	; [sta $f6,x]
    move.b	d0,(a0,d1.w)                 	; [...]
	POP_SR
	GET_ADDRESS	$a0                       	; [ldy $a0]
	move.b	(a0),d2                         	; [...]
	addq.b	#1,d2                           	; [iny]
	addq.b	#1,d1                           	; [inx]
	cmp.b	#$03,d1                         	; [cpx #$03]
	bne	l_0e97                             	; [bne l_0e97]

l_0eb3:
	clr.b	d0                              ; [lda #$00]
	PUSH_SR
	GET_ADDRESS	$9f                    ; [sta $9f]
	move.b	d0,(a0)                        ; [...]
	POP_SR
	
l_0eb7:
	move.b	d0,d1                           	; [tax]
	GET_ADDRESS	$f6                       	; [dec $f6,x]
    subq.b	#1,(a0,d1.w)                 	; [...]
	beq	l_0ebf                             	; [beq l_0ebf]
	jmp	l_0f51                             	; [jmp l_0f51]

l_0ebf:
	GET_ADDRESS	$fc                       	; [lda $fc,x]
	move.b	(a0,d1.w),d0                    	; [...]
	PUSH_SR
	GET_ADDRESS	$a3                       	; [sta $a3]
	move.b	d0,(a0)                         	; [...]
	POP_SR
	GET_ADDRESS	$f3                       	; [lda $f3,x]
	move.b	(a0,d1.w),d0                    	; [...]
	PUSH_SR
	GET_ADDRESS	$a2                       	; [sta $a2]
	move.b	d0,(a0)                         	; [...]
	POP_SR
	clr.b	d2                               	; [ldy #$00]
	GET_ADDRESS_Y	$a2                     	; [lda ($a2),y]
	move.b	(a0,d2.w),d0                    	; [...]
	bne	l_0ee4                             	; [bne l_0ee4]
	addq.b	#1,d2                           	; [iny]
	GET_ADDRESS_Y	$a2                     	; [lda ($a2),y]
	move.b	(a0,d2.w),d0                    	; [...]
	and.b	#$07,d0                         	; [and #$07]
	not.b	d0                               	; [eor #$ff]
	SET_XC_FLAGS                           	; [sec]
	move.b	#$07,d4								;	addx.b	#$07,d0  ; [adc #$07]
	addx.b	d4,d0                        	; [adc #$07]
	PUSH_SR
	GET_ADDRESS	$f9                       	; [sta $f9,x]
    move.b	d0,(a0,d1.w)                 	; [...]
	POP_SR
	GET_ADDRESS_Y	$a2                     	; [lda ($a2),y]
	move.b	(a0,d2.w),d0                    	; [...]
	addq.b	#1,d2                           	; [iny]
	and.b	#$f0,d0                         	; [and #$f0]
	lsr.b	#4,d0
	;lsr.b	#1,d0                            	; [lsr a]
	;lsr.b	#1,d0                            	; [lsr a]
	;lsr.b	#1,d0                            	; [lsr a]
	;lsr.b	#1,d0                            	; [lsr a]
	PUSH_SR
	GET_ADDRESS	$a4                       	; [sta $a4,x]
    move.b	d0,(a0,d1.w)                 		; [...]
	POP_SR

l_0ee4:
	GET_ADDRESS_Y	$a2                     	; [lda ($a2),y]
	move.b	(a0,d2.w),d0                    	; [...]
	cmp.b	#$ff,d0                         	; [cmp #$ff]
	bne	l_0ef5                             		; [bne l_0ef5]
	move.b	#$fe,d2                        		; [ldy #$fe]
	PUSH_SR
	GET_ADDRESS	l_3e99+1                    ; [sty $3e9a]
	move.b	d2,(a0)                         	; [...]
	POP_SR
	GET_ADDRESS	l_3e99                     	; [inc $3e99]
	addq.b	#1,(a0)                         	; [...]
	jmp	l_0e81                             		; [jmp l_0e81]



l_0ef5:
	move.b	d2,d0                           	; [tya]
	SET_XC_FLAGS                           	; [sec]
	GET_ADDRESS	$f3                       	; [adc $f3,x]
	move.b	(a0,d1.w),d4					;	addx.b	(a0,d1.w),d0                    	; [...]
	addx.b	d4,d0                    	; [...]
	PUSH_SR
	GET_ADDRESS	$f3                       	; [sta $f3,x]
    move.b	d0,(a0,d1.w)                 	; [...]
	POP_SR
	clr.b	d0                               	; [lda #$00]
	GET_ADDRESS	$fc                       	; [adc $fc,x]
	move.b	(a0,d1.w),d4				;	addx.b	(a0,d1.w),d0                    	; [...]
	addx.b	d4,d0                    	; [...]
	PUSH_SR
	GET_ADDRESS	$fc                       	; [sta $fc,x]
    move.b	d0,(a0,d1.w)                 	; [...]
	POP_SR
	GET_ADDRESS_Y	$a2                     	; [lda ($a2),y]
	move.b	(a0,d2.w),d0                    	; [...]
	and.b	#$f0,d0                         	; [and #$f0]
	bne	l_0f0c                             	; [bne l_0f0c]
	move.b	#$10,d0                        	; [lda #$10]
	jmp	l_0f10                             	; [jmp l_0f10]
	
l_0f0c:
	lsr.b	#1,d0                            	; [lsr a]
	lsr.b	#1,d0                            	; [lsr a]
l_0f0e:
	lsr.b	#1,d0                            	; [lsr a]
	lsr.b	#1,d0                            	; [lsr a]

l_0f10:
	PUSH_SR
	GET_ADDRESS	$f6                       	; [sta $f6,x]
    move.b	d0,(a0,d1.w)                 	; [...]
	POP_SR
	GET_ADDRESS	$f9                       	; [lda $f9,x]
	move.b	(a0,d1.w),d0                    	; [...]
	move.b	d0,d1                           	; [tax]
	GET_ADDRESS_Y	$a2                     	; [lda ($a2),y]
	move.b	(a0,d2.w),d0                    	; [...]
	and.b	#$0f,d0                         	; [and #$0f]
	move.b	d0,d2                           	; [tay]
	GET_ADDRESS	l_3d10                     	; [lda $3d10,y]
	move.b	(a0,d2.w),d0                    	; [...]
	PUSH_SR
	GET_ADDRESS	$f0                       	; [sta $f0]
	move.b	d0,(a0)                         	; [...]
	POP_SR
	GET_ADDRESS	l_3d00                     	; [lda $3d00,y]
	move.b	(a0,d2.w),d0                    	; [...]
	
l_0f22:
	lsr.b	#1,d0                            	; [lsr a]
	GET_ADDRESS	$f0                       	; [ror $f0]
	move.b	(a0),d4								; roxr.b	#1,(a0)                         	; [...]
	roxr.b	#1,d4                         		; [...]
	PUSH_SR
	move.b	d4,(a0)								;	roxr.b	#1,(a0)                         	; [...]
	POP_SR
	subq.b	#1,d1                           	; [dex]
	bne	l_0f22                             		; [bne l_0f22]
	PUSH_SR
	GET_ADDRESS	$f1                       	; [sta $f1]
	move.b	d0,(a0)                         	; [...]
	POP_SR
	GET_ADDRESS	$9f                       	; [ldx $9f]
	move.b	(a0),d1                         	; [...]
	GET_ADDRESS	$a4                       	; [lda $a4,x]
	move.b	(a0,d1.w),d0                    	; [...]
	move.b	d0,d2                           	; [tay]
												; [clc]
	add.b	#$27,d0                        		; [adc #$27]
	PUSH_SR
	GET_ADDRESS	$91                       	; [sta $91,x]
    move.b	d0,(a0,d1.w)                 		; [...]
	
	lea	l_3d1e,a0
	lsl.b #1,d2									; 4 bytes per address
	add.w d2,a0
	move.l (a0),a0
	
	; to do later
	
	;POP_SR
	;GET_ADDRESS	$3d1e                     	; [lda $3d1e,y]
	;move.b	(a0,d2.w),d0                    	; [...]
	;PUSH_SR
	;GET_ADDRESS	$a3                       	; [sta $a3]
	;move.b	d0,(a0)                         	; [...]
	;POP_SR
	;GET_ADDRESS	$3d25                     	; [lda $3d25,y]
	;move.b	(a0,d2.w),d0                    	; [...]
	;PUSH_SR
	
	GET_ADDRESS	$a2                       	; [sta $a2]
	move.b	d0,(a0)                         	; [...]
	POP_SR
	GET_ADDRESS	$f0                       	; [lda $f0]
	move.b	(a0),d0                         	; [...]
	move.b	#$01,d2                        	; [ldy #$01]
	PUSH_SR
	GET_ADDRESS_Y	$a2                     	; [sta ($a2),y]
	move.b	d0,(a0,d2.w)                    	; [...]
	POP_SR
	move.b	#$0d,d2                        	; [ldy #$0d]
	PUSH_SR
	GET_ADDRESS_Y	$a2                     	; [sta ($a2),y]
	move.b	d0,(a0,d2.w)                    	; [...]
	POP_SR
	GET_ADDRESS	$f1                       	; [lda $f1]
	move.b	(a0),d0                         	; [...]
	addq.b	#1,d2                           	; [iny]
	PUSH_SR
	GET_ADDRESS_Y	$a2                     	; [sta ($a2),y]
	move.b	d0,(a0,d2.w)                    	; [...]
	POP_SR
	move.b	#$02,d2                        	; [ldy #$02]
	PUSH_SR
	GET_ADDRESS_Y	$a2                     	; [sta ($a2),y]
	move.b	d0,(a0,d2.w)                    	; [...]
	POP_SR

l_0f51:
	GET_ADDRESS	$9f                       	; [inc $9f]
	addq.b	#1,(a0)                         	; [...]
	GET_ADDRESS	$9f                       	; [lda $9f]
	move.b	(a0),d0                         	; [...]
	cmp.b	#$03,d0                         	; [cmp #$03]
	beq	l_0f5c                             	; [beq l_0f5c]
	jmp	l_0eb7                             	; [jmp l_0eb7]

l_0f5c:
	GET_ADDRESS	$ef                       	; [lda $ef]
	move.b	(a0),d0                         	; [...]
	
l_1108:
	; sid.
	rts
	
	
	; Used during static screens - 0x3f93
l_17cc:
	move.w vdp_control, d0				; Move VDP status word to d0
	andi.w #$0008,d0						; AND with bit 4 (vblank), result in status register
	bne l_17cc								; [bne l_17cc]
	
	; black background colour
	move.b	#$00,d3							; select the palette colour
	move.b	#palette_a,d1					; select the palette
	PUSH_SR
	GET_ADDRESS	$d021					; [sta $d021] background color
	move.b	d0,(a0)							; [...]
	POP_SR
	
	;move.w  #$2700,sr       				; Disable all interrupts (set interrupt mask level to 7)
	;;lea IntTable,a0
    ;;move.l  8(a0),VblankRamAddress+2  	; Update the interrupt vector in RAM
	;move.l IntTable+8,VblankRamAddress+2 
   ; move.w  #$2300,sr       				; Re-enable interrupts (set interrupt mask level to 0, enabling VBlank/HBlank)
	rts
	
	; Set interrupt address to 0x3f00 - used during scrolling routine.
l_17e2:
	move.w vdp_control, d0					; Move VDP status word to d0
	andi.w #$0008,d0						; AND with bit 4 (vblank), result in status register
	bne l_17e2								; [bne l_17e2]

	;============================
	; Sets up INT routine to 3f00
	;=============================
	;GET_ADDRESS	$2f 					; [lda $2f] - load framecount.
	;move.b	(a0),d0							; [...]
	
	;move.b	#$fc,d0							; [lda #$fc]
	;PUSH_SR
	
	;GET_ADDRESS	$d012					; [sta $d012]
	;move.b	d0,(a0)							; [...]
	;
	;POP_SR
	;SET_I_FLAG                          ; [sei]
	
	; Interrupt address 0x3f00.
	;clr.b	d1                           ; [ldx #$00]
	;move.b	#$3f,d2                      ; [ldy #$3f]
	;PUSH_SR
	; Set the interrupt address
	;GET_ADDRESS	$fffe					; [stx $fffe]
	;move.b	d1,(a0)							; [...]
	;GET_ADDRESS	$ffff					; [sty $ffff]
	;move.b	d2,(a0)							; [...]
	;POP_SR
	;CLR_I_FLAG							; [cli] ; start interrupts
	;rts									; [rts]
	
	; change screen to black
	move.b	#$00,d0                   		; [lda #$f0] black screen
	move.b	#palette_a,d1
	GET_ADDRESS	$d021             		; [sta $d021] - doesnt work during interrupt
	move.b	d0,(a0)                   		; [...]
	
	;move.w  #$2700,sr       				; Disable all interrupts (set interrupt mask level to 7)
    ;;lea IntTable,a0
    ;;move.l  4(a0),VblankRamAddress+2 	; Update the interrupt vector in RAM
	;move.l  IntTable+4,VblankRamAddress+2
    ;move.w  #$2300,sr       				; Re-enable interrupts (set interrupt mask level to 0, enabling VBlank/HBlank)
	rts
	
l_19b7:
	move.b	#$30,d1							; [ldx #$30]
	;GET_ADDRESS	$5d						; [lda $5d]
	move.b	$00ff005d,d0					; [...]
	cmp.b	#$01,d0							; [cmp #$01]
	bne	l_19da								; [bne l_19da]
	;GET_ADDRESS	$25						; [lda $25]
	move.b	$00ff0025,d0					; [...]
	;lsr.b	#1,d0							; [lsr a]
	;lsr.b	#1,d0							; [lsr a]
	;lsr.b	#1,d0							; [lsr a]
	;lsr.b	#1,d0							; [lsr a]
	lsr.b #4,d0
	beq	l_19c8								; [beq l_19c8]
	move.b	d0,d1							; [tax]
	
	;===========
	;Print lives
	;===========
l_19c8:
	;PUSH_SR
	;GET_ADDRESS	$3142					; [stx $3142]
	move.b	d1,l_3142						; [...]	- fix this
	;POP_SR
	;GET_ADDRESS	$25						; [lda $25]
	move.b	$00ff0025,d0					; [...]
	and.b	#$0f,d0							; [and #$0f]
	;PUSH_SR
	;GET_ADDRESS	$3143					; [sta $3143]
	move.b	d0,l_3142+1					; [...] - fix this
	;POP_SR
	move.b	#$3a,d1							; [ldx #$3a]
	move.b	#$31,d2							; [ldy #$31]
	bsr.w	l_b295							; [jsr l_b295]
	rts										; [rts]
	
l_19da:
	;GET_ADDRESS	$25						; [lda $25]
	move.b	$00ff0025,d0					; [...]
	;lsr.b	#1,d0							; [lsr a]
	;lsr.b	#1,d0							; [lsr a]
	;lsr.b	#1,d0							; [lsr a]
	;lsr.b	#1,d0							; [lsr a]
	lsr.b #4,d0
	beq	l_19e3								; [beq l_19e3]
	move.b	d0,d1							; [tax]
	
l_19e3:
	;PUSH_SR
	;GET_ADDRESS	$3149						; [stx $3149]
	lea	l_3149,a0
	move.b	d1,(a0)								; [...]
	;POP_SR
	;GET_ADDRESS	$25							; [lda $25]
	move.b	$00ff0025,d0						; [...]
	and.b	#$0f,d0								; [and #$0f]
	;PUSH_SR
	;GET_ADDRESS	$314a						; [sta $314a]
	lea l_3149+1,a0
	move.b	d0,(a0)								; [...]
	;POP_SR
	;move.b	#$45,d1								; [ldx #$45]
	;move.b	#$31,d2								; [ldy #$31]
	;bsr.w	l_b295								; [jsr l_b295]
	move.w #gamedataText2UP,d2				
	move.b d2,d1
	ror.w #8,d2
	bsr.w l_b295							; [jsr l_b295]
	rts											; [rts]

l_19f5:
	; [sed]
	;GET_ADDRESS	$38f9                     ; [lda $38f9,y]
	lea l_38f9,a0
	move.b	(a0,d2.w),d0                    	; [...]
	CLR_XC_FLAGS                           	; [clc]
	;GET_ADDRESS	$23                       ; [adc $23]
	move.b	$00ff0023,d4								;	addx.b	(a0),d0
	addx.b	d4,d0                         	; [...]
	PUSH_SR
	;GET_ADDRESS	$23                       	; [sta $23]
	move.b	d0,$00ff0023                         	; [...]
	POP_SR
	;GET_ADDRESS	$38ed                     	; [lda $38ed,y]
	lea l_38ed,a0
	move.b	(a0,d2.w),d0                    	; [...]
	;GET_ADDRESS	$22                       	; [adc $22]
	move.b	$00ff0022,d4						;	addx.b	(a0),d0                         	; [...]
	addx.b	d4,d0                         	; [...]
	PUSH_SR
	;GET_ADDRESS	$22                       	; [sta $22]
	move.b	d0,$00ff0022                        	; [...]
	;GET_ADDRESS	$21                       	; [lda $21]
	move.b	$00ff0021,d0                         	; [...]
	move.b	#$00,d4							;	addx.b	#$00,d0                        	; [adc #$00]
	addx.b	d4,d0                        	; [adc #$00]
	PUSH_SR
	;GET_ADDRESS	$21                       	; [sta $21]
	move.b	d0,$00ff0021                         	; [...]
	POP_SR
	;GET_ADDRESS	$20                       	; [lda $20]
	move.b	$00ff0020,d0                         	; [...]
	move.b	#$00,d4								;	addx.b	#$00,d0 
	addx.b	d4,d0                        	; [adc #$00]
	PUSH_SR
	;GET_ADDRESS	$20                       	; [sta $20]
	move.b	d0,$00ff0020                         	; [...]
	POP_SR
	bcc	l_1a21                             	; [bcc l_1a21]
	move.b	#$99,d0                        	; [lda #$99]
	PUSH_SR
	;GET_ADDRESS	$20                       	; [sta $20]
	move.b	d0,$00ff0020                         	; [...]
	;GET_ADDRESS	$21                       	; [sta $21]
	move.b	d0,$00ff0021                         	; [...]
	;GET_ADDRESS	$22                       	; [sta $22]
	move.b	d0,$00ff0022                         	; [...]
	;GET_ADDRESS	$23                       	; [sta $23]
	move.b	d0,$00ff0023                         	; [...]
	POP_SR
	POP_SR                                 	; [plp]
	rts                                    	; [rts]

l_1a21:
	POP_SR                                 	; [plp]
	bcc	l_1a36                             	; [bcc l_1a36]
	CLR_XC_FLAGS                           	; [clc]
	;GET_ADDRESS	$25                       	; [lda $25]
	move.b	$00ff0025,d0                         	; [...]
	move.b	#$01,d4	;	addx.b	#$01,d0                        	; [adc #$01]
	addx.b	d4,d0                        	; [adc #$01]
	bcs	l_1a36                             	; [bcs l_1a36]
	PUSH_SR
	;GET_ADDRESS	$25                       	; [sta $25]
	move.b	d0,$00ff0025                         	; [...]
	POP_SR
	bsr.w	l_19b7                            	; [jsr l_19b7]
	move.b	#$81,d0                        	; [lda #$81]
	PUSH_SR
	;GET_ADDRESS	$91                       	; [sta $91]
	move.b	d0,$00ff0091                        	; [...]
	POP_SR
	rts                                    	; [rts]

l_1a36:
	;nop                                 ; [cld]
	rts                                    	; [rts]

l_1a75:
	;GET_ADDRESS	$62                       	; [lda $62]
	move.b	$00ff0062,d0                         	; [...]
	and.b	#$3f,d0                         	; [and #$3f]
	cmp.b	#$21,d0                         	; [cmp #$21]
	bne	l_1a97                             	; [bne l_1a97]
	;GET_ADDRESS	$6c                       	; [lda $6c]
	move.b	$00ff006c,d0                         	; [...]
	beq	l_1a98                             	; [beq l_1a98]
	cmp.b	#$80,d0                         	; [cmp #$80]
	bne	l_1a97                             	; [bne l_1a97]
	clr.b	d0                               	; [lda #$00]
	;PUSH_SR
	;GET_ADDRESS	$6c                       	; [sta $6c]
	move.b	d0,$00ff006c                         	; [...]
	;POP_SR
	;GET_ADDRESS	$88                       	; [lda $88]
	move.b	$00ff0088,d0                         	; [...]
	bne	l_1a93                             	; [bne l_1a93]
	;GET_ADDRESS	$68                       	; [lda $68]
	move.b	$00ff0068,d0                         	; [...]
	bne	l_1a93                             	; [bne l_1a93]
	;GET_ADDRESS	$87                       	; [inc $87]
	addq.b	#1,$00ff0087                         	; [...]
l_1a93:
	clr.b	d0                               	; [lda #$00]
	;PUSH_SR
	;GET_ADDRESS	$88                       	; [sta $88]
	move.b	d0,$00ff0088                         	; [...]
	;POP_SR
l_1a97:
	rts                                    	; [rts]
	
l_1a98:
	clr.b	d0                               	; [lda #$00]
	;PUSH_SR
	;GET_ADDRESS	$1b                       	; [sta $1b]
	move.b	d0,$00ff001b                         	; [...]
	;POP_SR
	move.b	#$80,d0                        	; [lda #$80]
	;PUSH_SR
	;GET_ADDRESS	$6c                       	; [sta $6c]
	move.b	d0,$00ff006c                         	; [...]
	;POP_SR
	move.b	#$ae,d0                        	; [lda #$ae]
	;PUSH_SR
	;GET_ADDRESS	$92                       	; [sta $92]
	move.b	d0,$00ff0092                         	; [...]
	;POP_SR
	;GET_ADDRESS	$24                       	; [ldy $24]
	move.b	$00ff0024,d2                         	; [...]
	GET_ADDRESS_Y	$6d                     	; [lda ($6d),y]
	move.b	(a0,d2.w),d0                    	; [...]
	cmp.b	#$ff,d0                         	; [cmp #$ff]
	bne	l_1ab9                             	; [bne l_1ab9]
	move.b $00ffd41b,d0                     ; [lda $d41b]
	and.b	#$03,d0                         ; [and #$03]
											; [clc]
	add.b	#$12,d0                        	; [adc #$12]
	;PUSH_SR
	;GET_ADDRESS	$68                       	; [sta $68]
	move.b	d0,$00ff0068                         	; [...]
	;POP_SR
	jmp	l_1abf                             	; [jmp l_1abf]
l_1ab9:
	;GET_ADDRESS	$24                       	; [inc $24]
	addq.b	#1,$00ff0024                         	; [...]
	clr.b	d1                               	; [ldx #$00]
	;PUSH_SR
	;GET_ADDRESS	$68                       	; [stx $68]
	move.b	d1,$00ff0068                         	; [...]
	;POP_SR
l_1abf:
	asl.b	#1,d0                            	; [asl a]
	;GET_ADDRESS	$1b                       	; [rol $1b]
	move.b	$00ff001b,d4					;	roxl.b	#1,(a0) 
	roxl.b	#1,d4                         	; [...]
	;PUSH_SR
	move.b	d4,$00ff001b			;	roxl.b	#1,(a0)                         	; [...]
	;POP_SR
	asl.b	#1,d0                            	; [asl a]
	;GET_ADDRESS	$1b                       	; [rol $1b]
	move.b	$00ff001b,d4	;	roxl.b	#1,(a0)                         	; [...]
	roxl.b	#1,d4                         	; [...]
	;PUSH_SR
	move.b	d4,$00ff001b	;	roxl.b	#1,(a0)                         	; [...]
	;POP_SR
	asl.b	#1,d0                            	; [asl a]
	;GET_ADDRESS	$1b                       	; [rol $1b]
	move.b	$00ff001b,d4	;	roxl.b	#1,(a0)                         	; [...]
	roxl.b	#1,d4                         	; [...]
	;PUSH_SR
	move.b	d4,$00ff001b	;	roxl.b	#1,(a0)                         	; [...]
	;POP_SR
	asl.b	#1,d0                            	; [asl a]
	;GET_ADDRESS	$1b                       	; [rol $1b]
	move.b	$00ff001b,d4	;	roxl.b	#1,(a0)                         	; [...]
	roxl.b	#1,d4                         	; [...]
	;PUSH_SR
	move.b	d4,$00ff001b	;	roxl.b	#1,(a0)                         	; [...]
	;GET_ADDRESS	$1a                       	; [sta $1a]
	move.b	d0,$00ff001a                         	; [...]
	;POP_SR
	;GET_ADDRESS	$1b                       	; [lda $1b]
	move.b	$00ff001b,d0                         	; [...]
	move.b	#$c2,d4	;	addx.b	#$c2,d0                        	; [adc #$c2]
	addx.b	d4,d0                        	; [adc #$c2]
	;PUSH_SR
	;GET_ADDRESS	$1b                       	; [sta $1b]
	move.b	d0,$00ff001b                         	; [...]
	;POP_SR
	st.b	d0                                	; [lda #$ff]
	;PUSH_SR
	;GET_ADDRESS	$08                       	; [sta $08]
	move.b	d0,$00ff0008                         	; [...]
	;GET_ADDRESS	$0b                       	; [sta $0b]
	move.b	d0,$00ff000b                         	; [...]
	;GET_ADDRESS	$06                       	; [sta $06]
	move.b	d0,$00ff0006                         	; [...]
	;POP_SR
	;GET_ADDRESS	$4f                       	; [lda $4f]
	move.b	$00ff004f,d0                         	; [...]
	;PUSH_SR
	;GET_ADDRESS	$0d                       	; [sta $0d]
	move.b	d0,$00ff000d                        	; [...]
	;POP_SR
	move.w	#$0e,d2                        	; [ldy #$0e]
	GET_ADDRESS_Y	$1a                     	; [lda ($1a),y]
	move.b	(a0,d2.w),d0                    	; [...]
	;PUSH_SR
	;GET_ADDRESS	$7e                       	; [sta $7e]
	move.b	d0,$00ff007e                        	; [...]
	;POP_SR
	move.b	d0,d1                           	; [tax]
	;GET_ADDRESS	$36f3                     	; [lda $36f3,x]
	lea l_36f3,a0
	move.b	(a0,d1.w),d0                    	; [...]
	;PUSH_SR
	;GET_ADDRESS	$66                       	; [sta $66]
	move.b	d0,$00ff0066                        	; [...]
	;POP_SR
	not.b	d0                               	; [eor #$ff]
	                           	; [clc]
	add.b	#$01,d0                        	; [adc #$01]
	;PUSH_SR
	;GET_ADDRESS	$63                       	; [sta $63]
	move.b	d0,$00ff0063                         	; [...]
	;POP_SR
	clr.b	d0                               	; [lda #$00]
	;PUSH_SR
	;GET_ADDRESS	$6b                       	; [sta $6b]
	move.b	d0,$00ff006b                        	; [...]
	;GET_ADDRESS	$67                       	; [sta $67]
	move.b	d0,$00ff0067                         	; [...]
	;GET_ADDRESS	$83                       	; [sta $83]
	move.b	d0,$00ff0083                         	; [...]
	;POP_SR
	st.b	d0                                	; [lda #$ff]
	;PUSH_SR
	;GET_ADDRESS	$64                       	; [sta $64]
	move.b	d0,$00ff0064                         	; [...]
	;GET_ADDRESS	$81                       	; [sta $81]
	move.b	d0,$00ff0081                        	; [...]
	;POP_SR
	;GET_ADDRESS	$3703                     	; [lda $3703,x]
	lea l_3703,a0
	move.b	(a0,d1.w),d0                    	; [...]
	;PUSH_SR
	;GET_ADDRESS	$82                       	; [sta $82]
	move.b	d0,$00ff0082                        	; [...]
	;POP_SR
	not.b	d0                               	; [eor #$ff]
	                           	; [clc]
	add.b	#$01,d0                        	; [adc #$01]
	;PUSH_SR
	;GET_ADDRESS	$80                       	; [sta $80]
	move.b	d0,$00ff0080                         	; [...]
	;POP_SR
	;GET_ADDRESS	$25                       	; [lda $25]
	move.b	$00ff0025,d0                         	; [...]
	lsr.b	#1,d0                            	; [lsr a]
	CLR_XC_FLAGS                           	; [clc]
	;GET_ADDRESS	$26                       	; [adc $26]
	move.b	$00ff0026,d4	;	addx.b	(a0),d0                         	; [...]
	addx.b	d4,d0                         	; [...]
	;GET_ADDRESS	$28                       	; [adc $28]
	move.b	$00ff0028,d4	;	addx.b	(a0),d0                         	; [...]
	addx.b	d4,d0                         	; [...]
	;GET_ADDRESS	$3713                     	; [adc $3713,x]
	lea l_3713,a0
	move.b	(a0,d1.w),d4	;	addx.b	(a0,d1.w),d0                    	; [...]
	addx.b	d4,d0                    	; [...]
	;PUSH_SR
	;GET_ADDRESS	$69                       	; [sta $69]
	move.b	d0,$00ff0069                         	; [...]
	;POP_SR
	;GET_ADDRESS	$3723                     	; [lda $3723,x]
	lea l_3723,a0								; enemy bullet data ?
	move.b	(a0,d1.w),d0                    	; [...]
	;PUSH_SR
	;GET_ADDRESS	$6a                       	; [sta $6a]
	move.b	d0,(a0)                         	; [...]
	;POP_SR
	;GET_ADDRESS	$3733                     	; [lda $3733,x]
	lea l_3733,a0
	move.b	(a0,d1.w),d0                    	; [...]
	;PUSH_SR
	;GET_ADDRESS	$7f                       	; [sta $7f]
	move.b	d0,$00ff007f                         	; [...]
	;POP_SR
	;GET_ADDRESS	$3743                     	; [lda $3743,x]
	lea l_3743,a0
	move.b	(a0,d1.w),d0                    	; [...]
	;PUSH_SR
	;GET_ADDRESS	$65                       	; [sta $65]
	move.b	d0,$00ff0065                        	; [...]
	;POP_SR
	subq.b	#1,d2                           	; [dey]
	GET_ADDRESS_Y	$1a                     	; [lda ($1a),y]
	move.b	(a0,d2.w),d0                    	; [...]
	beq	l_1b45                             	; [beq l_1b45]
	cmp.b	#$ff,d0                         	; [cmp #$ff]
	beq	l_1b36                             	; [beq l_1b36]
	move.b $00ffd41b,d0                     	; [lda $d41b] - random number
	bpl	l_1b45                             	; [bpl l_1b45]
	
l_1b36:
	;GET_ADDRESS	$2e                       	; [lda $2e]
	move.b	$00ff002e,d0                         	; [...]
	not.b	d0                               	; [eor #$ff]
											; [clc]
	add.b	#$01,d0                        	; [adc #$01]
	;PUSH_SR
	;GET_ADDRESS	$84                       	; [sta $84]
	move.b	d0,$00ff0084                         	; [...]
	;POP_SR
	;GET_ADDRESS	$2e                       	; [lda $2e]
	move.b	$00ff002e,d0                         	; [...]
	bmi	l_1b4d                             	; [bmi l_1b4d]
	bpl	l_1b5b                             	; [bpl l_1b5b]	

l_1b45:
	clr.b	d0                               	; [lda #$00]
	;PUSH_SR
	;GET_ADDRESS	$84                       	; [sta $84]
	move.b	d0,$00ff0084                         	; [...]
	;POP_SR
	;GET_ADDRESS	$2e                       	; [lda $2e]
	move.b	$00ff002e,d0                         	; [...]
	bmi	l_1b5b                             	; [bmi l_1b5b]	
	
l_1b4d:
	move.b	#$a4,d0                        	; [lda #$a4]
	;PUSH_SR
	;GET_ADDRESS	$05                       	; [sta $05]
	move.b	d0,$00ff0005                         	; [...]
	;POP_SR
	;GET_ADDRESS	$7e                       	; [lda $7e]
	move.b	$00ff007e,d0                         	; [...]
	                           	; [clc]
	add.b	#$a0,d0                        	; [adc #$a0]
	;PUSH_SR
	;GET_ADDRESS	$0e                       	; [sta $0e]
	move.b	d0,$00ff000e                        	; [...]
	;POP_SR
	jmp	l_1b83                             	; [jmp l_1b83]
	
l_1b5b:
	move.b	#$a2,d0                        	; [lda #$a2]
	;PUSH_SR
	;GET_ADDRESS	$05                       	; [sta $05]
	move.b	d0,$00ff0005                         	; [...]
	;POP_SR
	;GET_ADDRESS	$7e                       	; [lda $7e]
	move.b	$00ff007e,d0                         	; [...]
	                           	; [clc]
	add.b	#$b0,d0                        	; [adc #$b0]
	;PUSH_SR
	;GET_ADDRESS	$0e                       	; [sta $0e]
	move.b	d0,$00ff000e                         	; [...]
	;POP_SR
	;GET_ADDRESS	$63                       	; [lda $63]
	move.b	$00ff0063,d0                         	; [...]
	;GET_ADDRESS	$66                       	; [ldx $66]
	move.b	$00ff0066,d1                         	; [...]
	;PUSH_SR
	;GET_ADDRESS	$63                       	; [stx $63]
	move.b	d1,$00ff0063                         	; [...]
	;GET_ADDRESS	$66                       	; [sta $66]
	move.b	d0,$00ff0066                         	; [...]
	;POP_SR
	;GET_ADDRESS	$64                       	; [lda $64]
	move.b	$00ff0064,d0                         	; [...]
	;GET_ADDRESS	$67                       	; [ldx $67]
	move.b	$00ff0067,d1                         	; [...]
	;PUSH_SR
	;GET_ADDRESS	$64                       	; [stx $64]
	move.b	d1,$00ff0064                         	; [...]
	;GET_ADDRESS	$67                       	; [sta $67]
	move.b	d0,$00ff0067                         	; [...]
	;POP_SR
	;GET_ADDRESS	$65                       	; [lda $65]
	move.b	$00ff0065,d0                         	; [...]
	not.b	d0                               	; [eor #$ff]
	                           	; [clc]
	add.b	#$01,d0                        	; [adc #$01]
	;PUSH_SR
	;GET_ADDRESS	$65                       	; [sta $65]
	move.b	d0,$00ff0065                         	; [...]
	;POP_SR
	st.b	d0                                	; [lda #$ff]
	;PUSH_SR
	;GET_ADDRESS	$6b                       	; [sta $6b]
	move.b	d0,$00ff006b                         	; [...]
	;POP_SR


	
l_1b83:
	move.b	#$0c,d2                        	; [ldy #$0c]
	GET_ADDRESS_Y	$1a                     	; [lda ($1a),y]
	move.b	(a0,d2.w),d0                    	; [...]
	;PUSH_SR
	;GET_ADDRESS	$7c                       	; [sta $7c]
	move.b	d0,$00ff007c                         	; [...]
	;POP_SR
	clr.b	d0                               	; [lda #$00]
	;PUSH_SR
	;GET_ADDRESS	$7d                       	; [sta $7d]
	move.b	d0,$00ff007d                         	; [...]
	;POP_SR
	move.b	#$05,d2                        	; [ldy #$05]
	;PUSH_SR
	;GET_ADDRESS	$11                       	; [sty $11]
	move.b	d2,$00ff0011                         	; [...]
	;POP_SR
	move.b	#$0a,d1                        	; [ldx #$0a]
	;PUSH_SR
	;GET_ADDRESS	$10                       	; [stx $10]
	move.b	d1,$00ff0010                        	; [...]
	;POP_SR

l_1b95:
	;GET_ADDRESS	$11                       	; [ldy $11]
	move.b	$00ff0011,d2                         	; [...]
	;PUSH_SR
	;GET_ADDRESS	$04                       	; [sty $04]
	move.b	d2,$00ff0004                         	; [...]
	;POP_SR
	GET_ADDRESS_Y	$1a                     	; [lda ($1a),y]
	move.b	(a0,d2.w),d0                    	; [...]
	beq	l_1bc0                             	; [beq l_1bc0]
	;GET_ADDRESS	$10                       	; [ldx $10]
	move.b	$00ff0010,d1                         	; [...]
	move.b	d0,d2                           	; [tay]
	;GET_ADDRESS	$c120                     	; [lda $c120,y]
	lea scrollTextData+$120,a0
	move.b	(a0,d2.w),d0                    	; [...]
	;PUSH_SR
	;GET_ADDRESS	$70                       	; [sta $70,x]
	lea $00ff0070,a0
    move.b	d0,(a0,d1.w)                 	; [...]
	;POP_SR
	addq.b	#1,d1                           	; [inx]
	;GET_ADDRESS	$c190                     	; [lda $c190,y]
	lea scrollTextData+$190,a0
	move.b	(a0,d2.w),d0                    	; [...]
	;PUSH_SR
	;GET_ADDRESS	$70                       	; [sta $70,x]
	lea $00ff0070,a0
    move.b	d0,(a0,d1.w)                 	; [...]
	;POP_SR
	;GET_ADDRESS	$11                       	; [ldy $11]
	move.b	(a0),d2                         	; [...]
	move.b	#$02,d0                        	; [lda #$02]
	;PUSH_SR
	;GET_ADDRESS	$a490                     	; [sta $a490,y]
	lea $00ffa490,a0
    move.b	d0,(a0,d2.w)                 	; [...]
	;POP_SR
	;GET_ADDRESS	$6c                       	; [inc $6c]
	addq.b	#1,$00ff006c                         	; [...]
	;GET_ADDRESS	$88                       	; [inc $88]
	addq.b	#1,$00ff0088                         	; [...]
	;GET_ADDRESS	$7d                       	; [lda $7d]
	move.b	$00ff007d,d0                         	; [...]
	;PUSH_SR
	;GET_ADDRESS	$a4b0                     	; [sta $a4b0,y]
	lea $00ffa4b0,a0
    move.b	d0,(a0,d2.w)                 	; [...]
	;POP_SR
	CLR_XC_FLAGS                           	; [clc]
	;GET_ADDRESS	$7c                       	; [adc $7c]
	move.b	$00ff007c,d4					;	addx.b	(a0),d0                         	; [...]
	addx.b	d4,d0                         	; [...]
	;PUSH_SR
	;GET_ADDRESS	$7d                       	; [sta $7d]
	move.b	d0,$00ff007d                         	; [...]
	;POP_SR

l_1bc0:
	move.b	d2,d0                           	; [tya]
												; [clc]
	add.b	#$06,d0                        	; [adc #$06]
	move.b	d0,d2                           	; [tay]
	GET_ADDRESS_Y	$1a                     	; [lda ($1a),y]
	move.b	(a0,d2.w),d0                    	; [...]
	bne	l_1bcb                             	; [bne l_1bcb]
	;GET_ADDRESS	$33                       	; [lda $33]
	move.b	$00ff0033,d0                         	; [...]

l_1bcb:
	;PUSH_SR
	;GET_ADDRESS	$07                       ; [sta $07]
	move.b	d0,$00ff0007                       ; [...]
	;POP_SR
	bsr.w	l_b0e3                            	; [jsr l_b0e3]
	;GET_ADDRESS	$11                       	; [ldy $11]
	move.b	$00ff0011,d2                         	; [...]
	;GET_ADDRESS	$6b                       	; [lda $6b]
	move.b	$00ff006b,d0                         	; [...]
	;PUSH_SR
	;GET_ADDRESS	$a4e8                     	; [sta $a4e8,y]
	lea $00ffa4e8,a0
    move.b	d0,(a0,d2.w)                 	; [...]
	;POP_SR
	clr.b	d0                               	; [lda #$00]
	;PUSH_SR
	;GET_ADDRESS	$a4b8                     	; [sta $a4b8,y]
	lea $00ffa4b8,a0
    move.b	d0,(a0,d2.w)                 	; [...]
	;GET_ADDRESS	$a4a8                     	; [sta $a4a8,y]
	lea $00ffa4a8,a0
    move.b	d0,(a0,d2.w)                 	; [...]
	;GET_ADDRESS	$a4c0                     ; [sta $a4c0,y]
	lea $00ffa4c0,a0
    move.b	d0,(a0,d2.w)                 	; [...]
	;GET_ADDRESS	$a4a0                    ; [sta $a4a0,y]
	lea $00ffa4a0,a0
    move.b	d0,(a0,d2.w)                 	; [...]
	;GET_ADDRESS	$a4c8                    ; [sta $a4c8,y]
	lea $00ffa4c8,a0
    move.b	d0,(a0,d2.w)                 	; [...]
	;POP_SR
	;GET_ADDRESS	$84                      ; [lda $84]
	move.b	$00ff0084,d0                     ; [...]
	;PUSH_SR
	;GET_ADDRESS	$a498                  ; [sta $a498,y]
	lea $00ffa498,a0
    move.b	d0,(a0,d2.w)                 	; [...]
	;POP_SR
	bpl	l_1bf4                             	; [bpl l_1bf4]
	st.b	d0                                	; [lda #$ff]
	;PUSH_SR
	;GET_ADDRESS	$a4a8                  ; [sta $a4a8,y]
    move.b	d0,(a0,d2.w)                 	; [...]
	lea $00ffa4a8,a0
	;POP_SR

l_1bf4:
	;GET_ADDRESS	$10                   ; [dec $10]
	;subq.b	#1,$00ff0010                   ; [...]
	;GET_ADDRESS	$10                   ; [dec $10]
	;subq.b	#1,$00ff0010                   ; [...]
	subq.b #2,$00ff0010
	;GET_ADDRESS	$11                   ; [dec $11]
	subq.b	#1,$00ff0011                   ; [...]
	bpl	l_1b95                             	; [bpl l_1b95]
	rts                                    	; [rts]
	
	
l_1bfd:
	move.b	#$0a,d0                        		; [lda #$0a]
	;PUSH_SR
	;GET_ADDRESS	$10                       ; [sta $10]
	move.b	d0,$00ff0010                       ; [...]
	;POP_SR
	lsr.b	#1,d0                            	; [lsr a]
	;PUSH_SR
	;GET_ADDRESS	$11                       ; [sta $11]
	move.b	d0,$00ff0011                       ; [...]
	;POP_SR
	st.b	d0                                	; [lda #$ff]
	;PUSH_SR
	;GET_ADDRESS	$0b                       ; [sta $0b]
	move.b	d0,$00ff000b                       ; [...]
	;GET_ADDRESS	$08                       ; [sta $08]
	move.b	d0,$00ff0008                       ; [...]
	;POP_SR
	clr.b	d0                               	; [lda #$00]
	;PUSH_SR
	;GET_ADDRESS	$0a                       ; [sta $0a]
	move.b	d0,$00ff000a                       ; [...]
	;POP_SR
l_1c0e:
	;GET_ADDRESS	$11                       ; [ldy $11]
	move.b	$00ff0011,d2                       ; [...]
	;PUSH_SR
	;GET_ADDRESS	$04                       ; [sty $04]
	move.b	d2,$00ff0004                       ; [...]
	;POP_SR
	;GET_ADDRESS	$a490                     ; [lda $a490,y]
	
	lea $00ffa490,a0
	move.b	(a0,d2.w),d0                    	; [...]
	and.b	#$0e,d0                         	; [and #$0e]
	beq	l_1c2e                             		; [beq l_1c2e]
	move.b	d0,d1                           	; [tax]
	;GET_ADDRESS	$36e5                     ; [lda $36e5,x]
	
	lea l_36e5,a0								; finish this.
	move.l	(a0,d1.w),$00ff1c2c				; save address to use
	
	;move.b	(a0,d1.w),d0                    	; [...]
	;PUSH_SR
	;GET_ADDRESS	$1c2c                     ; [sta $1c2c]
	;move.b	d0,(a0)                         	; [...]
	;POP_SR
	
	;GET_ADDRESS	$36e6                     ; [lda $36e6,x]
	;move.b	(a0,d1.w),d0                    	; [...]
	;PUSH_SR
	;GET_ADDRESS	$1c2d                     ; [sta $1c2d]
	;move.b	d0,(a0)                         	; [...]
	;POP_SR
	
	bsr.w	l_b05d                            	; [jsr l_b05d]
	;GET_ADDRESS	$11                       ; [ldy $11]
	move.b	$00ff0011,d2                       ; [...]
l_1c2b:
	
	lea $00ff1c2c,a0							; [jsr l_1c73]
	move.l (a0),a0								
	jsr (a0)
	

l_1c2e:
	;GET_ADDRESS	$10                       ; [dec $10]
	;subq.b	#1,$00ff0010						; [...]
	;GET_ADDRESS	$10                       ; [dec $10]
	;subq.b	#1,$00ff0010						; [...]
	subq.b	#2,$00ff0010 
	;GET_ADDRESS	$11                       ; [dec $11]
	subq.b	#1,$00ff0011                       ; [...]
	bpl	l_1c0e                             		; [bpl l_1c0e]
	rts                                    		; [rts]
l_1c37:
	bsr.w	l_1c5a                            	; [jsr l_1c5a]
	;GET_ADDRESS	$62                       ; [lda $62]
	move.b	$00ff0062,d0                       ; [...]
	and.b	#$01,d0                         	; [and #$01]
	bne	l_1c57                             		; [bne l_1c57]
	;GET_ADDRESS	$0e                       ; [inc $0e]
	addq.b	#1,$00ff000e                       ; [...]
	;GET_ADDRESS	$0e                       ; [lda $0e]
	move.b	$00ff000e,d0                       ; [...]
	cmp.b	#$1e,d0                         	; [cmp #$1e]
	bcs	l_1c57                             		; [bcc l_1c57]
	clr.b	d0                               	; [lda #$00]
	;PUSH_SR
	;GET_ADDRESS	$08                       ; [sta $08]
	move.b	d0,$00ff0008                       ; [...]
	;POP_SR
	;GET_ADDRESS	$11                       ; [ldy $11]
	move.b	$00ff0011,d2                       ; [...]
	;PUSH_SR
	;GET_ADDRESS	$a490                     ; [sta $a490,y]
	lea $00ffa490,a0
    move.b	d0,(a0,d2.w)                 		; [...]
	;POP_SR
	;GET_ADDRESS	$6c                       ; [dec $6c]
	subq.b	#1,$00ff006c						; [...]
	bsr.w	l_b13f                            	; [jsr l_b13f]
	rts                                    		; [rts]
l_1c57:
	jmp l_1ea6
	
l_1c5a:
	CLR_XC_FLAGS                           	; [clc]
	;GET_ADDRESS	$2e                       ; [lda $2e]
	move.b	$00ff002e,d0                       ; [...]
	bmi	l_1c68                             		; [bmi l_1c68]
	;GET_ADDRESS	$05                       ; [adc $05]
	move.b	$00ff0005,d4						; addx.b	(a0),d0
	addx.b	d4,d0                         		; [...]
	PUSH_SR
	;GET_ADDRESS	$05                       ; [sta $05]
	move.b	d0,$00ff0005                       ; [...]
	POP_SR
	bcc	l_1c67                             		; [bcc l_1c67]
	;GET_ADDRESS	$06                       ; [inc $06]
	addq.b	#1,$00ff0006                       ; [...]
l_1c67:
	rts                                    		; [rts]
	
l_1c68:
	;GET_ADDRESS	$05                       ; [adc $05]
	move.b	$00ff0005,d4						;	addx.b	(a0),d0
	addx.b	d4,d0                         		; [...]
	;PUSH_SR
	;GET_ADDRESS	$05                       ; [sta $05]
	move.b	d0,$00ff0005                       ; [...]
	;POP_SR
	;GET_ADDRESS	$06                       ; [lda $06]
	move.b	$00ff0006,d0                       ; [...]
	move.b	#$ff,d4								; addx.b	#$ff,d0  ; [adc #$ff]
	addx.b	d4,d0                        		; [adc #$ff]
	;PUSH_SR
	;GET_ADDRESS	$06                       ; [sta $06]
	move.b	d0,$00ff0006                       ; [...]
	;POP_SR
	rts                                    		; [rts]

l_1c73:
	bsr.w	l_1c5a                            	; [jsr l_1c5a]
	bsr.w	l_1ef4                            	; [jsr l_1ef4]
	;GET_ADDRESS	$a4b0                     ; [lda $a4b0,y]
	lea $00ffa4b0,a0
	move.b	(a0,d2.w),d0                    	; [...]
	bne	l_1ca7                             		; [bne l_1ca7]
	;GET_ADDRESS	$10                       ; [ldx $10]
	move.b	$00ff0010,d1                       ; [...]
	;GET_ADDRESS_X	$70                     	; [lda ($70,x)]
	move.b	$00ff0070,d0                       ; [...]
	cmp.b	#$ff,d0                         	; [cmp #$ff]
	beq	l_1ca7                             		; [beq l_1ca7]
	;GET_ADDRESS	$70                       ; [inc $70,x]
	lea $00ff0070,a0
    addq.b	#1,(a0,d1.w)                 		; [...]
	bne	l_1c8c                             		; [bne l_1c8c]
	;GET_ADDRESS	$71                       ; [inc $71,x]
	lea $00ff0071,a0
    addq.b	#1,(a0,d1.w)                 		; [...]
l_1c8c:
	movem.w	d0,-(sp)                       		; [pha]
	and.b	#$7f,d0                         	; [and #$7f]
	;PUSH_SR
	;GET_ADDRESS	$a4b8                     ; [sta $a4b8,y]
	lea $00ffa4b8,a0
    move.b	d0,(a0,d2.w)                 		; [...]
	;POP_SR
	movem.w	(sp)+,d0                       		; [pla]
	bmi	l_1c9c                             		; [bmi l_1c9c]
	move.b	#$01,d0                        		; [lda #$01]
	;PUSH_SR
	;GET_ADDRESS	$a4b0                     ; [sta $a4b0,y]
	lea $00ffa4b0,a0
    move.b	d0,(a0,d2.w)                 		; [...]
	;POP_SR
	bne	l_1ca7                             		; [bne l_1ca7]
l_1c9c:
	;GET_ADDRESS_X	$70                     	; [lda ($70,x)]
	move.b	$00ff0070,d0                       ; [...]
	;PUSH_SR
	;GET_ADDRESS	$a4b0                     ; [sta $a4b0,y]
	lea $00ffa4b0,a0
    move.b	d0,(a0,d2.w)                 		; [...]
	;POP_SR
	;GET_ADDRESS	$70                       ; [inc $70,x]
	lea $00ff0070,a0
    addq.b	#1,(a0,d1.w)                 		; [...]
	bne	l_1ca7                             		; [bne l_1ca7]
	;GET_ADDRESS	$71                       ; [inc $71,x]
	lea $00ff0071,a0
    addq.b	#1,(a0,d1.w)                 		; [...]
l_1ca7:
	;GET_ADDRESS	$a4b0                     ; [lda $a4b0,y]
	lea $00ffa4b0,a0
	move.b	(a0,d2.w),d0                    	; [...]
	SET_XC_FLAGS                           	; [sec]
	SBC_IMM	$01                           		; [sbc #$01]
	;PUSH_SR
	;GET_ADDRESS	$a4b0                     ; [sta $a4b0,y]
	lea $00ffa4b0,a0
    move.b	d0,(a0,d2.w)                 		; [...]
	;POP_SR
	;GET_ADDRESS	$a4b8                     ; [lda $a4b8,y]
	lea $00ffa4b8,a0
	move.b	(a0,d2.w),d0                    	; [...]
	;PUSH_SR
	;GET_ADDRESS	$6f                       ; [sta $6f]
	move.b	d0,$00ff006f                       ; [...]
	;POP_SR
	bne	l_1cba                             		; [bne l_1cba]
	jmp	l_1db0                             		; [jmp l_1db0]
l_1cba:
	and.b	#$0f,d0                         	; [and #$0f]
	beq	l_1d31                             		; [beq l_1d31]
	and.b	#$01,d0                         	; [and #$01]
	beq	l_1cde                             		; [beq l_1cde]
	;GET_ADDRESS	$a4c0                     ; [lda $a4c0,y]
	lea $00ffa4c0,a0
	move.b	(a0,d2.w),d0                    	; [...]
	CLR_XC_FLAGS                           	; [clc]
	;GET_ADDRESS	$63                       ; [adc $63]
	move.b	$00ff0063,d4						;	addx.b	(a0),d0
	addx.b	d4,d0                         		; [...]
	;PUSH_SR
	;GET_ADDRESS	$a4c0                     ; [sta $a4c0,y]
	lea $00ffa4c0,a0
    move.b	d0,(a0,d2.w)                 		; [...]
	;POP_SR
	;GET_ADDRESS	$a498                     ; [lda $a498,y]
	lea $00ffa498,a0
	move.b	(a0,d2.w),d0                    	; [...]
	;GET_ADDRESS	$64                       ; [adc $64]
	move.b	(a0),d4								;	addx.b	(a0),d0
	addx.b	d4,d0                         		; [...]
	;PUSH_SR
	;GET_ADDRESS	$a498                     ; [sta $a498,y]
	lea $00ffa498,a0
    move.b	d0,(a0,d2.w)                 		; [...]
	;POP_SR
	;GET_ADDRESS	$a4a8                     ; [lda $a4a8,y]
	lea $00ffa4a8,a0
	move.b	(a0,d2.w),d0                    	; [...]
	;GET_ADDRESS	$64                       ; [adc $64]
	move.b	$00ff0064,d4						;	addx.b	(a0),d0 
	addx.b	d4,d0                         		; [...]
	;PUSH_SR
	;GET_ADDRESS	$a4a8                     ; [sta $a4a8,y]
	lea $00ffa4a8,a0
    move.b	d0,(a0,d2.w)                 		; [...]
	;POP_SR
	jmp	l_1cfd                             		; [jmp l_1cfd]
	
l_1cde:
	;GET_ADDRESS	$6f                       ; [lda $6f]
	move.b	(a0),d0                         	; [...]
	and.b	#$02,d0                         	; [and #$02]
	beq	l_1cfd                             		; [beq l_1cfd]
	;GET_ADDRESS	$a4c0                     ; [lda $a4c0,y]
	lea $00ffa4c0,a0
	move.b	(a0,d2.w),d0                    	; [...]
	CLR_XC_FLAGS                           	; [clc]
	;GET_ADDRESS	$66                       ; [adc $66]
	move.b	$00ff0066,d4						;	addx.b	(a0),d0 
	addx.b	d4,d0                         		; [...]
	;PUSH_SR
	;GET_ADDRESS	$a4c0                     ; [sta $a4c0,y]
	lea $00ffa4c0,a0
    move.b	d0,(a0,d2.w)                 		; [...]
	;POP_SR
	;GET_ADDRESS	$a498                     ; [lda $a498,y]
	lea $00ffa498,a0
	move.b	(a0,d2.w),d0                    	; [...]
	;GET_ADDRESS	$67                       ; [adc $67]
	move.b	$00ff0067,d4						;	addx.b	(a0),d0
	addx.b	d4,d0                         		; [...]
	;PUSH_SR
	;GET_ADDRESS	$a498                     ; [sta $a498,y]
	lea $00ffa498,a0
    move.b	d0,(a0,d2.w)                 		; [...]
	;POP_SR
	;GET_ADDRESS	$a4a8                     ; [lda $a4a8,y]
	lea $00ffa4a8,a0
	move.b	(a0,d2.w),d0                    	; [...]
	;GET_ADDRESS	$67                       ; [adc $67]
	move.b	$00ff0067,d4						;	addx.b	(a0),d0                         
	addx.b	d4,d0                         		; [...]
	;PUSH_SR
	;GET_ADDRESS	$a4a8                     ; [sta $a4a8,y]
	lea $00ffa4a8,a0
    move.b	d0,(a0,d2.w)                 		; [...]
	;POP_SR

l_1cfd:
	;GET_ADDRESS	$6f                       ; [lda $6f]
	move.b	(a0),d0                         	; [...]
	and.b	#$04,d0                         	; [and #$04]
	beq	l_1d17                             		; [beq l_1d17]
	;GET_ADDRESS	$a4c8                     ; [lda $a4c8,y]
	lea $00ffa4c8,a0
	move.b	(a0,d2.w),d0                    	; [...]
	CLR_XC_FLAGS                           	; [clc]
	;GET_ADDRESS	$82                       ; [adc $82]
	move.b	$00ff0082,d4						;	addx.b	(a0),d0
	addx.b	d4,d0                         		; [...]
	;PUSH_SR
	;GET_ADDRESS	$a4c8                     ; [sta $a4c8,y]
	lea $00ffa4c8,a0
    move.b	d0,(a0,d2.w)                 		; [...]
	;POP_SR
	;GET_ADDRESS	$a4a0                     ; [lda $a4a0,y]
	lea $00ffa4a0,a0
	move.b	(a0,d2.w),d0                    	; [...]
	;GET_ADDRESS	$83                       ; [adc $83]
	move.b	$00ff0083,d4						; x.b	(a0),d0
	addx.b	d4,d0                         		; [...]
	;PUSH_SR
	;GET_ADDRESS	$a4a0                     ; [sta $a4a0,y]
	lea $00ffa4a0,a0
    move.b	d0,(a0,d2.w)                 		; [...]
	;POP_SR
	jmp	l_1db0                             		; [jmp l_1db0]
	
l_1d17:
	;GET_ADDRESS	$6f                       ; [lda $6f]
	move.b	(a0),d0                         	; [...]
	and.b	#$08,d0                         	; [and #$08]
	beq	l_1d2e                             		; [beq l_1d2e]
	;GET_ADDRESS	$a4c8                     ; [lda $a4c8,y]
	lea $00ffa4c8,a0
	move.b	(a0,d2.w),d0                    	; [...]
	CLR_XC_FLAGS                           	; [clc]
	;GET_ADDRESS	$80                       ; [adc $80]
	move.b	$00ff0080,d4						; addx.b	(a0),d0
	addx.b	d4,d0                         		; [...]
	;PUSH_SR
	;GET_ADDRESS	$a4c8                     ; [sta $a4c8,y]
	lea $00ffa4c8,a0
    move.b	d0,(a0,d2.w)                 		; [...]
	;POP_SR
	;GET_ADDRESS	$a4a0                     ; [lda $a4a0,y]
	lea $00ffa4a0,a0
	move.b	(a0,d2.w),d0                    	; [...]
	;GET_ADDRESS	$81                       ; [adc $81]
	move.b	$00ff0081,d4						;	addx.b	(a0),d0
	addx.b	d4,d0                         		; [...]
	;PUSH_SR
	;GET_ADDRESS	$a4a0                     ; [sta $a4a0,y]
	lea $00ffa4a0,a0
    move.b	d0,(a0,d2.w)                 		; [...]
	;POP_SR

l_1d2e:
	jmp	l_1db0                             		; [jmp l_1db0]
l_1d31:
	;GET_ADDRESS	$6f                       ; [lda $6f]
	move.b	$00ff006f,d0                       ; [...]
	and.b	#$10,d0                         	; [and #$10]
	beq	l_1d44                             		; [beq l_1d44]
	;GET_ADDRESS	$a4e8                     ; [lda $a4e8,y]
	lea $00ffa4e8,a0
	move.b	(a0,d2.w),d0                    	; [...]
	cmp.b	#$80,d0                         	; [cmp #$80]
	bne	l_1d41                             		; [bne l_1d41]
	bsr.w	l_1f0f                            	; [jsr l_1f0f]

l_1d41:
	jmp	l_1dcb                             	; [jmp l_1dcb]
l_1d44:
	;GET_ADDRESS	$6f                       	; [lda $6f]
	move.b	$00ff006f,d0                         	; [...]
	and.b	#$20,d0                         	; [and #$20]
	beq	l_1d5e                             	; [beq l_1d5e]
	clr.b	d0                               	; [lda #$00]
	;PUSH_SR
	;GET_ADDRESS	$a4c0                     	; [sta $a4c0,y]
	lea $00ffa4c0,a0
    move.b	d0,(a0,d2.w)                 	; [...]
	;GET_ADDRESS	$a498                     	; [sta $a498,y]
	lea $00ffa498,a0
    move.b	d0,(a0,d2.w)                 	; [...]
	;GET_ADDRESS	$a4a8                     	; [sta $a4a8,y]
	lea $00ffa4a8,a0
    move.b	d0,(a0,d2.w)                 	; [...]
	;GET_ADDRESS	$a4c8                     	; [sta $a4c8,y]
	lea $00ffa4c8,a0
    move.b	d0,(a0,d2.w)                 	; [...]
	;GET_ADDRESS	$a4a0                     	; [sta $a4a0,y]
	lea $00ffa4a0,a0
    move.b	d0,(a0,d2.w)                 	; [...]
	;POP_SR
	jmp	l_1dcb                             	; [jmp l_1dcb]

l_1d5e:
	;GET_ADDRESS	$6f						; [lda $6f]
	move.b	$00ff006f,d0					; [...]
	and.b	#$40,d0							; [and #$40]
	beq	l_1db0                             	; [beq l_1db0]
	;GET_ADDRESS	$07						; [lda $07]
	move.b	$00ff0007,d0					; [...]
	;GET_ADDRESS	$33						; [cmp $33]
	cmp.b	$00ff0033,d0                   ; [...]
	beq	l_1da8								; [beq l_1da8]
	bcc	l_1d8b                             	; [bcc l_1d8b]
	;GET_ADDRESS	$a4a0					; [lda $a4a0,y]
	lea $00ffa4a0,a0
	move.b	(a0,d2.w),d0					; [...]
	beq	l_1d77                             	; [beq l_1d77]
	bpl	l_1da8                             	; [bpl l_1da8]
	cmp.b	#$fc,d0							; [cmp #$fc]
	bcs	l_1db0                             	; [bcc l_1db0]

l_1d77:
	;GET_ADDRESS	$a4c8                 ; [lda $a4c8,y]
	lea $00ffa4c8,a0
	move.b	(a0,d2.w),d0                   ; [...]
	CLR_XC_FLAGS                           ; [clc]
	;GET_ADDRESS	$80						; [adc $80]
	move.b	$00ff0080,d4					;	addx.b	(a0),d0
	addx.b	d4,d0                         	; [...]
	;PUSH_SR
	;GET_ADDRESS	$a4c8					; [sta $a4c8,y]
	lea $00ffa4c8,a0
    move.b	d0,(a0,d2.w)                 	; [...]
	;POP_SR
	;GET_ADDRESS	$a4a0					; [lda $a4a0,y]
	lea $00ffa4a0,a0
	move.b	(a0,d2.w),d0					; [...]
	;GET_ADDRESS	$81						; [adc $81]
	move.b	$00ff0081,d4					;	addx.b	(a0),d0
	addx.b	d4,d0                         	; [...]
	;PUSH_SR
	;GET_ADDRESS	$a4a0					; [sta $a4a0,y]
	lea $00ffa4a0,a0
    move.b	d0,(a0,d2.w)                 	; [...]
	;POP_SR
	jmp	l_1db0                             	; [jmp l_1db0]
	
l_1d8b:
	;GET_ADDRESS	$a4a0                 ; [lda $a4a0,y]
	lea $00ffa4a0,a0
	move.b	(a0,d2.w),d0					; [...]
	bmi	l_1da8                             	; [bmi l_1da8]
	cmp.b	#$05,d0							; [cmp #$05]
	bcc	l_1db0                             	; [bcs l_1db0]
	;GET_ADDRESS	$a4c8					; [lda $a4c8,y]
	lea $00ffa4c8,a0
	move.b	(a0,d2.w),d0					; [...]
	CLR_XC_FLAGS							; [clc]
	;GET_ADDRESS	$82						; [adc $82]
	move.b	$00ff0082,d4					;	addx.b	(a0),d0
	addx.b	d4,d0                         	; [...]
	;PUSH_SR
	;GET_ADDRESS	$a4c8					; [sta $a4c8,y]
	lea $00ffa4c8,a0
    move.b	d0,(a0,d2.w)                 	; [...]
	;POP_SR
	;GET_ADDRESS	$a4a0					; [lda $a4a0,y]
	lea $00ffa4a0,a0
	move.b	(a0,d2.w),d0					; [...]
	;GET_ADDRESS	$83						; [adc $83]
	move.b	$00ff0083,d4					;	addx.b	(a0),d0
	addx.b	d4,d0                         	; [...]
	;PUSH_SR
	;GET_ADDRESS	$a4a0					; [sta $a4a0,y]
	lea $00ffa4a0,a0
    move.b	d0,(a0,d2.w)                 	; [...]
	;POP_SR
	jmp	l_1db0                             	; [jmp l_1db0]

l_1da8:
	clr.b	d0								; [lda #$00]
	;PUSH_SR
	;GET_ADDRESS	$a4c8                 ; [sta $a4c8,y]
	lea $ff00a4c8,a0
    move.b	d0,(a0,d2.w)					; [...]
	;GET_ADDRESS	$a4a0					; [sta $a4a0,y]
	lea $ff00a4a0,a0
    move.b	d0,(a0,d2.w)					; [...]
	;POP_SR

l_1db0:
	;GET_ADDRESS	$62						; [lda $62]
	move.b	$00ff0062,d0					; [...]
	and.b	#$07,d0							; [and #$07]
	;GET_ADDRESS	$04						; [cmp $04]
	cmp.b	$00ff0004,d0					; [...]
	bne	l_1dcb                             	; [bne l_1dcb]
	;GET_ADDRESS	$a4e8					; [lda $a4e8,y]
	lea $00ffa4e8,a0
	move.b	(a0,d2.w),d0					; [...]
	cmp.b	#$80,d0							; [cmp #$80]
	bne	l_1dcb                             	; [bne l_1dcb]
	;GET_ADDRESS	$69						; [lda $69]
	move.b	$00ff0069,d0					; [...]
	beq	l_1dcb                             	; [beq l_1dcb]		
	cmp.b	$00ffd41b,d0					; [cmp $d41b] - random number
	bcs	l_1dcb                             	; [bcc l_1dcb]
	bsr.w	l_1f0f							; [jsr l_1f0f]

l_1dcb:
	;GET_ADDRESS	$06						; [lda $06]
	move.b	$00ff0006,d0					; [...]
	roxr.b	#1,d0							; [ror a]
	;GET_ADDRESS	$05						; [lda $05]
	move.b	$00ff0005,d0					; [...]
	roxr.b	#1,d0							; [ror a]
	;lsr.b	#1,d0							; [lsr a]
	;lsr.b	#1,d0							; [lsr a]
	lsr.b #2,d0
	SET_XC_FLAGS							; [sec]
	SBC_IMM	$02                           	; [sbc #$02]
	cmp.b	#$27,d0							; [cmp #$27]
	bcs	l_1ddd                             	; [bcc l_1ddd]
	jmp	l_1e68                             	; [jmp l_1e68]

l_1ddd:
	;PUSH_SR
	;GET_ADDRESS	$0f						; [sta $0f]
	move.b	d0,$00ff000f					; [...]
	;POP_SR
	move.b	#$80,d0                        	; [lda #$80]
	;PUSH_SR
	;GET_ADDRESS	$a4e8					; [sta $a4e8,y]
	lea $00ffa4e8,a0
    move.b	d0,(a0,d2.w)                 	; [...]
	;POP_SR
	;GET_ADDRESS	$07						; [lda $07]
	move.b	$00ff0007,d0					; [...]
	;lsr.b	#1,d0							; [lsr a]
	;lsr.b	#1,d0							; [lsr a]
	;lsr.b	#1,d0							; [lsr a]
	lsr.b #3,d0
	SET_XC_FLAGS							; [sec]
	SBC_IMM	$05                           	; [sbc #$05]
	cmp.b	#$17,d0							; [cmp #$17]
	bcs	l_1df3                             	; [bcc l_1df3]
	jmp	l_1ea2                             	; [jmp l_1ea2]

l_1df3:
	cmp.b	#$06,d0							; [cmp #$06]
	bcc	l_1dfa                             	; [bcs l_1dfa]
	jmp	l_1ea2                             	; [jmp l_1ea2]

l_1dfa:
	move.b	d0,d1							; [tax]
	;GET_ADDRESS	l_b360					; [lda l_b360,x]
	lea l_b360,a0
	move.b	(a0,d1.w),d0					; [...]
	PUSH_SR
	;GET_ADDRESS	$1b						; [sta $1b]
	move.b	d0,$00ff001b					; [...]
	POP_SR
	;GET_ADDRESS	l_b360+$19				; [lda l_b360+$19,x]
	lea l_b379,a0
	move.b	(a0,d1.w),d0					; [...]
	CLR_XC_FLAGS							; [clc]
	;GET_ADDRESS	$0f						; [adc $0f]
	move.b	$00ff000f,d4					; addx.b	(a0),d0
	addx.b	d4,d0                         	; [...]
	PUSH_SR
	;GET_ADDRESS	$1a						; [sta $1a]
	move.b	d0,$00ff001a					; [...]
	POP_SR
	bcc	l_1e0c                             	; [bcc l_1e0c]
	;GET_ADDRESS	$1b						; [inc $1b]
	addq.b	#1,$00ff001b					; [...]

l_1e0c:
	clr.b	d2								; [ldy #$00]
	GET_ADDRESS_Y	$1a						; [lda ($1a),y]
	move.b	(a0,d2.w),d0					; [...]
	cmp.b	#$20,d0							; [cmp #$20]
	bcs	l_1e2d                             	; [bcc l_1e2d]
	addq.b	#1,d2							; [iny]
	GET_ADDRESS_Y	$1a						; [lda ($1a),y]
	move.b	(a0,d2.w),d0					; [...]
	cmp.b	#$20,d0							; [cmp #$20]
	bcs	l_1e2d                             	; [bcc l_1e2d]
	move.b	#$28,d2                        	; [ldy #$28]
	GET_ADDRESS_Y	$1a						; [lda ($1a),y]
	move.b	(a0,d2.w),d0					; [...]
	cmp.b	#$20,d0							; [cmp #$20]
	bcs	l_1e2d                             	; [bcc l_1e2d]
	addq.b	#1,d2							; [iny]
	GET_ADDRESS_Y	$1a						; [lda ($1a),y]
	move.b	(a0,d2.w),d0					; [...]
	cmp.b	#$20,d0							; [cmp #$20]
	bcs	l_1e2d                             	; [bcc l_1e2d]
	jmp	l_1ea2                             	; [jmp l_1ea2]

l_1e2d:
	and.b	#$0f,d0							; [and #$0f]
	move.b	d0,d1							; [tax]
	;GET_ADDRESS	$a460					; [lda $a460,x]
	lea $00ffa460,a0
	move.b	(a0,d1.w),d0					; [...]
	beq	l_1e4b                             	; [beq l_1e4b]
	;GET_ADDRESS	$a430					; [lda $a430,x]
	lea $00ffa430,a0
	move.b	(a0,d1.w),d0					; [...]
	;PUSH_SR
	;GET_ADDRESS	$1c						; [sta $1c]
	move.b	d0,$00ff001c					; [...]
	;POP_SR
	;GET_ADDRESS	$a440					; [lda $a440,x]
	lea $00ffa440,a0
	move.b	(a0,d1.w),d0					; [...]
	;PUSH_SR
	;GET_ADDRESS	$1d						; [sta $1d]
	move.b	d0,$00ff001d					; [...]
	;POP_SR
	clr.b	d2								; [ldy #$00]
	;GET_ADDRESS	$a450					; [lda $a450,x]
	lea $00ffa450,a0
	move.b	(a0,d1.w),d0					; [...]
	;PUSH_SR
	GET_ADDRESS_Y	$1c						; [sta ($1c),y]
	move.b	d0,(a0,d2.w)					; [...]
	;POP_SR
	clr.b	d0								; [lda #$00]
	;PUSH_SR
	;GET_ADDRESS	$a460					; [sta $a460,x]
	lea $00ffa460,a0
    move.b	d0,(a0,d1.w)                 	; [...]
	;POP_SR
l_1e4b:
	;GET_ADDRESS	$68						; [lda $68]
	move.b	$00ff0068,d0					; [...]
	bne	l_1e54                             	; [bne l_1e54]
	;GET_ADDRESS	$7f						; [ldy $7f]
	move.b	$00ff007f,d2					; [...]
	bsr.w	l_19f5							; [jsr l_19f5] - to do.

l_1e54:
	move.b	#$26,d0                        	; [lda #$26]
	;PUSH_SR
	;GET_ADDRESS	$92						; [sta $92]
	move.b	d0,$00ff0092					; [...]
	;POP_SR
	;GET_ADDRESS	$11						; [ldy $11]
	move.b	$00ff0011,d2					; [...]
	move.b	#$06,d0                        	; [lda #$06]
	;PUSH_SR
	;GET_ADDRESS	$a490					; [sta $a490,y]
	lea $00ffa490,a0
    move.b	d0,(a0,d2.w)                 	; [...]
	;POP_SR
	move.b	#$14,d0                        	; [lda #$14]
	;PUSH_SR
	;GET_ADDRESS	$0e						; [sta $0e]
	move.b	d0,$00ff000e					; [...]
	;POP_SR
	;GET_ADDRESS	$88						; [dec $88]
	subq.b	#1,$00ff0088					; [...]
	jmp	l_1ea2                             	; [jmp l_1ea2]
	
l_1e68:
	;GET_ADDRESS	$06						; [lda $06]
	move.b	$00ff0006,d0					; [...]
	and.b	#$01,d0							; [and #$01]
	beq	l_1ea2                             	; [beq l_1ea2]
	;GET_ADDRESS	$a4e8					; [lda $a4e8,y]
	lea $00ffa4e8,a0
	move.b	(a0,d2.w),d0					; [...]
	cmp.b	#$80,d0							; [cmp #$80]
	bne	l_1e87                             	; [bne l_1e87]
	;GET_ADDRESS	$05						; [lda $05]
	move.b	$00ff0005,d0					; [...]
	bmi	l_1e80                             	; [bmi l_1e80]
	move.b #$ff,d0							; [lda #$ff]
	;PUSH_SR
	;GET_ADDRESS	$a4e8					; [sta $a4e8,y]
	lea $00ffa4e8,a0
    move.b	d0,(a0,d2.w)                 	; [...]
	;POP_SR
	bne	l_1ea2                             	; [bne l_1ea2]
	
l_1e80:
	clr.b	d0								; [lda #$00]
	;PUSH_SR
	;GET_ADDRESS	$a4e8					; [sta $a4e8,y]
	lea $00ffa4e8,a0
    move.b	d0,(a0,d2.w)                 	; [...]
	;POP_SR
	beq	l_1ea2                             	; [beq l_1ea2]	
	
l_1e87:
	cmp.b	#$ff,d0							; [cmp #$ff]
	bne	l_1e93                             	; [bne l_1e93]
	;GET_ADDRESS	$05						; [lda $05]
	move.b	$00ff0005,d0					; [...]
	cmp.b	#$e8,d0							; [cmp #$e8]
	bcs	l_1ea2                             	; [bcc l_1ea2]
	bcs	l_1e99                             	; [bcs l_1e99]
	
l_1e93:
	;GET_ADDRESS	$05						; [lda $05]
	move.b	$00ff0005,d0					; [...]
	cmp.b	#$78,d0							; [cmp #$78]
	bcc	l_1ea2                             	; [bcs l_1ea2]
l_1e99:
	clr.b	d0								; [lda #$00]
	;PUSH_SR
	;GET_ADDRESS	$08						; [sta $08]
	move.b	d0,$00ff0008					; [...]
	;GET_ADDRESS	$a490					; [sta $a490,y]
	lea $00ffa490,a0
    move.b	d0,(a0,d2.w)                 	; [...]
	;POP_SR
	;GET_ADDRESS	$6c						; [dec $6c]
	subq.b	#1,$00ff006c					; [...]

l_1ea2:
	bsr.w	l_b13f							; [jsr l_b13f]
	rts                                    	; [rts]
	
l_1ea6:
	;GET_ADDRESS	$06                   ; [lda $06]
	move.b	$00ff0006,d0                   ; [...]
	and.b	#$01,d0                        ; [and #$01]
	beq	l_1ebf                             	; [beq l_1ebf]
	;GET_ADDRESS	$05                   ; [lda $05]
	move.b	$00ff0005,d0                   ; [...]
	cmp.b	#$9c,d0                         	; [cmp #$9c]
	bcs	l_1ebf                             	; [bcc l_1ebf]
	cmp.b	#$c4,d0                         	; [cmp #$c4]
	bcc	l_1ebf                             	; [bcs l_1ebf]
	clr.b	d0                               	; [lda #$00]
	PUSH_SR
	;GET_ADDRESS	$08                   ; [sta $08]
	move.b	d0,$00ff0008                    ; [...]
	;GET_ADDRESS	$a490                 ; [sta $a490,y]
	lea $00ffa490,a0
    move.b	d0,(a0,d2.w)                 	; [...]
	POP_SR
	;GET_ADDRESS	$6c                    ; [dec $6c]
	subq.b	#1,$00ff006c                    ; [...]
l_1ebf:
	bsr.w	l_b13f                          ; [jsr l_b13f]
	rts                                    	; [rts]
	
l_1ec3:
	bsr.w	l_1c5a                         ; [jsr l_1c5a]
	bsr.w	l_1ef4                         ; [jsr l_1ef4]
	;GET_ADDRESS	 $a4b0                ; [lda $a4b0,y]
	lea $00ffa4b0,a0
	move.b	(a0,d2.w),d0                   ; [...]
	SET_XC_FLAGS                           ; [sec]
	SBC_IMM	$01                           	; [sbc #$01]
	PUSH_SR
	;GET_ADDRESS	$a4b0                 ; [sta $a4b0,y]
	lea $00ffa4b0,a0
    move.b	d0,(a0,d2.w)                 	; [...]
	POP_SR
	beq	l_1ee4                             	; [beq l_1ee4]
	bsr.w	l_1ff0                          ; [jsr l_1ff0]
	bcc	l_1ee1                             	; [bcc l_1ee1]
	;GET_ADDRESS	 $3d                  ; [lda $3d]
	move.b	$00ff003d,d0
	cmp.b	#$14,d0                        ; [cmp #$14]
	bcc	l_1ee1                             	; [bcs l_1ee1]
	;GET_ADDRESS	 $32                  ; [inc $32]
	addq.b	#1,$00ff0032                   ; [...]

l_1ee1:
	jmp	l_1ea6                             	; [jmp l_1ea6]
l_1ee4:
	move.b	#$14,d0                        	; [lda #$14]
	PUSH_SR
	;GET_ADDRESS 	$0e                    ; [sta $0e]
	move.b	d0,$00ff000e                   ; [...]
	POP_SR
	move.b	#$06,d0                        	; [lda #$06]
	PUSH_SR
	;GET_ADDRESS	$a490                  ; [sta $a490,y]
	lea $00ffa490,a0
    move.b	d0,(a0,d2.w)                 	; [...]
	POP_SR
	move.b	#$0a,d0                        	; [lda #$0a]
	PUSH_SR
	;GET_ADDRESS	$92                   ; [sta $92]
	move.b	d0,$00ff0092                   ; [...]
	POP_SR
	jmp	l_1ea6                             	; [jmp l_1ea6]

l_1ef4:
	;GET_ADDRESS	$a498					; [lda $a498,y]
	lea $00ffa498,a0
	move.b	(a0,d2.w),d0					; [...]
	CLR_XC_FLAGS							; [clc]
	;GET_ADDRESS	$05						; [adc $05]
	move.b	$00ff0005,d4					; addx.b	(a0),d0
	addx.b	d4,d0                         	; [...]
	;PUSH_SR
	;GET_ADDRESS	$05						; [sta $05]
	move.b	d0,$00ff0005					; [...]
	;POP_SR
	;GET_ADDRESS	$a4a8					; [lda $a4a8,y]
	lea $00ffa4a8,a0
	move.b	(a0,d2.w),d0					; [...]
	;GET_ADDRESS	$06						; [adc $06]
	move.b	$00ff0006,d4					;	addx.b	(a0),d0
	addx.b	d4,d0                         	; [...]
	;PUSH_SR
	;GET_ADDRESS	$06						; [sta $06]
	move.b	d0,$00ff0006					; [...]
	;POP_SR
	;GET_ADDRESS	$a4c8					; [lda $a4c8,y]
	lea $00ffa4c8,a0
	move.b	(a0,d2.w),d0					; [...]
	asl.b	#1,d0							; [asl a]
	;GET_ADDRESS	$a4a0					; [lda $a4a0,y]
	lea $00ffa4a0,a0
	move.b	(a0,d2.w),d0					; [...]
	;GET_ADDRESS	$07	; [adc $07]
	move.b	$00ff0007,d4					;	addx.b	(a0),d0
	addx.b	d4,d0                         	; [...]
	;PUSH_SR
	;GET_ADDRESS	$07						; [sta $07]
	move.b	d0,$00ff0007					; [...]
	;POP_SR
	rts                                    	; [rts]

l_1f0f:
	move.b	#$05,d2                        	; [ldy #$05]
l_1f11:
	;GET_ADDRESS	$a490					; [lda $a490,y]
	lea $00ffa490,a0
	move.b	(a0,d2.w),d0					; [...]
	beq	l_1f1c                             	; [beq l_1f1c]
	subq.b	#1,d2							; [dey]
	bpl	l_1f11                             	; [bpl l_1f11]
	;GET_ADDRESS	$11						; [ldy $11]
	move.b	$00ff0011,d2					; [...]
	rts                                    	; [rts]
	
l_1f1c:
	;PUSH_SR
	;GET_ADDRESS	$04                   ; [sty $04]
	move.b	d2,$00ff0004                   ; [...]
	;POP_SR
	;GET_ADDRESS	$0e                   ; [lda $0e]
	move.b	$00ff000e,d0                   ; [...]
	movem.w	d0,-(sp)                       	; [pha]
	st.b	d0                              ; [lda #$ff]
	;PUSH_SR
	;GET_ADDRESS	$08                    ; [sta $08]
	move.b	d0,$00ff0008                    ; [...]
	;POP_SR
	;GET_ADDRESS	$6a                    ; [lda $6a]
	move.b	$00ff006a,d0                    ; [...]
	;PUSH_SR
	;GET_ADDRESS	$0e                    ; [sta $0e]
	move.b	d0,$00ff000e                    ; [...]
	;POP_SR
	bsr.w	l_b13f                           ; [jsr l_b13f]
	;GET_ADDRESS	$11                    ; [ldy $11]
	move.b	$00ff0011,d2                    ; [...]
	;GET_ADDRESS	$a498                   ; [lda $a498,y]
	lea $00ffa498,a0
	move.b	(a0,d2.w),d0                    ; [...]
	;GET_ADDRESS	$a4a8                   ; [ldx $a4a8,y]
	lea $00ffa4a8,a0
	move.b	(a0,d2.w),d1                     ; [...]
	;GET_ADDRESS	$04                     ; [ldy $04]
	move.b	$00ff0004,d2                     ; [...]
	CLR_XC_FLAGS                             ; [clc]
	;GET_ADDRESS	$65                      ; [adc $65]
	move.b	$00ff0065,d4						;	addx.b	(a0),d0
	addx.b	d4,d0                        
	;PUSH_SR
	;GET_ADDRESS	$a498                   ; [sta $a498,y]
	lea $00ffa498,a0
    move.b	d0,(a0,d2.w)                 	 ; [...]
	;POP_SR
	move.b	d1,d0                            ; [txa]
	;GET_ADDRESS	$6b                       	; [adc $6b]
	move.b	$00ff006b,d4					;	addx.b	(a0),d0 
	addx.b	d4,d0                         	; [...]
	;PUSH_SR
	;GET_ADDRESS	$a4a8                  ; [sta $a4a8,y]
	lea $00ffa4a8,a0
    move.b	d0,(a0,d2.w)                 	; [...]
	;POP_SR
	clr.b	d0                               ; [lda #$00]
	;PUSH_SR
	;GET_ADDRESS	$a4a0                   ; [sta $a4a0,y]
	lea $00ffa4a0,a0
    move.b	d0,(a0,d2.w)                 	; [...]
	;GET_ADDRESS	$a4c8                 ; [sta $a4c8,y]
	lea $00ffa4c8,a0
    move.b	d0,(a0,d2.w)                 	; [...]
	;POP_SR
	move.b	#$04,d0                        	; [lda #$04]
	;PUSH_SR
	;GET_ADDRESS	$a490                  ; [sta $a490,y]
	lea $00ffa490,a0
    move.b	d0,(a0,d2.w)                 	; [...]
	;POP_SR
	move.b	#$a0,d0                        	; [lda #$a0]
	;PUSH_SR
	;GET_ADDRESS	$a4b0                  ; [sta $a4b0,y]
	lea $00ffa4b0,a0
    move.b	d0,(a0,d2.w)                 	; [...]
	;POP_SR
	movem.w	(sp)+,d0                       	; [pla]
	;PUSH_SR
	;GET_ADDRESS	$0e                   ; [sta $0e]
	move.b	d0,$00ff000e                    ; [...]
	;POP_SR
	;GET_ADDRESS	$6c                    ; [inc $6c]
	addq.b	#1,$00ff006c                    ; [...]
	;GET_ADDRESS	$11                    ; [ldy $11]
	move.b	$00ff0011,d2                    ; [...]
	;PUSH_SR
	;GET_ADDRESS	$04                    ; [sty $04]
	move.b	d2,$00ff0004                    ; [...]
	;POP_SR
	move.b	#$0b,d0                        	; [lda #$0b]
	;PUSH_SR
	;GET_ADDRESS	$92                    ; [sta $92]
	move.b	d0,$00ff0092                    ; [...]
	;POP_SR
	rts                                    	; [rts]
l_1f62:

	bsr.w	l_1c5a							; [jsr l_1c5a]
	;GET_ADDRESS	$62                   ; [lda $62]
	move.b	$00ff0062,d0                   ; [...]
	and.b	#$03,d0                         	; [and #$03]
	bne	l_1f7c                             	; [bne l_1f7c]
	;GET_ADDRESS	$0e                    ; [dec $0e]
	subq.b	#1,$00ff000e                         	; [...]
	;GET_ADDRESS	$0e                       	; [lda $0e]
	move.b	$00ff000e,d0                         	; [...]
	cmp.b	#$14,d0                         	; [cmp #$14]
	bcc	l_1f7c                             	; [bcs l_1f7c]
	move.b	#$0a,d0                        	; [lda #$0a]
	;PUSH_SR
	;GET_ADDRESS	$a490                     	; [sta $a490,y]
	lea $00ffa490,a0
    move.b	d0,(a0,d2.w)                 	; [...]
	;POP_SR
	move.b	#$11,d0                        	; [lda #$11]
	;PUSH_SR
	;GET_ADDRESS	$0e                       	; [sta $0e]
	move.b	d0,$00ff000e                         	; [...]
	;POP_SR
	
l_1f7c:
	jmp	l_1ea6                             	; [jmp l_1ea6]
	

l_1f7f:
	;GET_ADDRESS	$6c							; [lda $6c]
	move.b	$00ff006c,d0						; [...]
	bpl	l_1f9a									; [bpl l_1f9a]
	;GET_ADDRESS	$69							; [lda $69]
	move.b	(a0),d0								; [...]
	beq	l_1f9a									; [beq l_1f9a]
	;lsr.b	#1,d0                            	; [lsr a]
	;lsr.b	#1,d0                            	; [lsr a]
	lsr.b	#2,d0
	; random number
	cmp.b	$00ffd41b,d0						; [cmp $d41b]
	bcs	l_1f9a									; [bcc l_1f9a]
	;GET_ADDRESS	$54							; [ldx $54]
	move.b	$00ff0054,d1						; [...]
	bmi	l_1f9a									; [bmi l_1f9a]
l_1f92:
	;GET_ADDRESS	$0240						; [lda $0240,x]
	lea $00ff0240,a0
	move.b	(a0,d1.w),d0						; [...]
	bpl	l_1f9b									; [bpl l_1f9b]
	subq.b	#1,d1                           	; [dex]
	bpl	l_1f92									; [bpl l_1f92]
l_1f9a:
	rts
	
l_1f9b:
	move.b	#$05,d2								; [ldy #$05]
l_1f9d:
	;GET_ADDRESS	$a490						; [lda $a490,y]
	lea $00ffa490,a0
	move.b	(a0,d2.w),d0						; [...]
	beq	l_1fa6									; [beq l_1fa6]
	subq.b	#1,d2								; [dey]
	bpl	l_1f9d									; [bpl l_1f9d]
	rts											; [rts]

l_1fa6:
	;PUSH_SR
	;GET_ADDRESS	$04                       ; [sty $04]
	move.b	d2,$00ff0004                       ; [...]
	;POP_SR
	move.b #$ff,d0                                ; [lda #$ff]
	;PUSH_SR
	;GET_ADDRESS	$08                       ; [sta $08]
	move.b	d0,$00ff0008                       ; [...]
	;POP_SR
	move.b	#$1d,d0                        		; [lda #$1d]
	;PUSH_SR
	;GET_ADDRESS	$0e                       ; [sta $0e]
	move.b	d0,$00ff000e                        ; [...]
	;POP_SR
	move.b	#$0d,d0                        		; [lda #$0d]
	;PUSH_SR
	;GET_ADDRESS	$92                       ; [sta $92]
	move.b	d0,$00ff0092                       ; [...]
	;POP_SR
	move.b	#$08,d0                        		; [lda #$08]
	;PUSH_SR
	;GET_ADDRESS	$a490                     ; [sta $a490,y]
	lea	$00ffa490,a0
    move.b	d0,(a0,d2.w)                 		; [...]
	;POP_SR
	;GET_ADDRESS	$26                       ; [lda $26]
	move.b	$00ff0026,d0                        ; [...]
	;asl.b	#1,d0                            	; [asl a]
	;asl.b	#1,d0                            	; [asl a]
	asl.b	#2,d0
	;GET_ADDRESS	$28                       ; [adc $28]
	move.b	$00ff0028,d4						;	addx.b	(a0),d0 
	addx.b	d4,d0                         		; [...]
	or.b	#$80,d0                          	; [ora #$80]
	;PUSH_SR
	;GET_ADDRESS	$a4b0                     ; [sta $a4b0,y]
	lea $00ffa4b0,a0
    move.b	d0,(a0,d2.w)                 		; [...]
	;POP_SR
	clr.b	d0                               	; [lda #$00]
	;PUSH_SR
	;GET_ADDRESS	$a498                     ; [sta $a498,y]
	lea $00ffa498,a0
    move.b	d0,(a0,d2.w)                 		; [...]
	;GET_ADDRESS	$a4a8                     ; [sta $a4a8,y]
	lea $00ffa4a8,a0
    move.b	d0,(a0,d2.w)                 		; [...]
	;GET_ADDRESS	$a4a0                     ; [sta $a4a0,y]
	lea $00ffa4a0,a0
    move.b	d0,(a0,d2.w)                 		; [...]
	;POP_SR
	;GET_ADDRESS	$0220                     ; [lda $0220,x]
	lea $00ff0220,a0
	move.b	(a0,d1.w),d0                    	; [...]
	;asl.b	#1,d0                            	; [asl a]
	;asl.b	#1,d0                            	; [asl a]
	;asl.b	#1,d0                            	; [asl a]
	asl.b	#3,d0
												; [clc]
	add.b	#$2c,d0                        		; [adc #$2c]
	;PUSH_SR
	;GET_ADDRESS	$07                       ; [sta $07]
	move.b	d0,$00ff0007                       ; [...]
	;POP_SR
	;GET_ADDRESS	$0240                     ; [lda $0240,x]
	lea $00ff0240,a0
	move.b	(a0,d1.w),d0                    	; [...]
												; [clc]
	add.b	#$02,d0                        		; [adc #$02]
	;asl.b	#1,d0                            	; [asl a]
	;asl.b	#1,d0                            	; [asl a]
	;asl.b	#1,d0                            	; [asl a]
	asl.b	#3,d0
	;PUSH_SR
	;GET_ADDRESS	$05                       ; [sta $05]
	move.b	d0,$00ff0005                       ; [...]
	;POP_SR
	clr.b	d0                               	; [lda #$00]
	roxl.b	#1,d0                           	; [rol a]
	;PUSH_SR
	;GET_ADDRESS	$06                       ; [sta $06]
	lea $00ff0006,a0
	move.b	d0,(a0)                         	; [...]
	;POP_SR
	bsr.w	l_b13f                            	; [jsr l_b13f]
	;GET_ADDRESS	$6c                       ; [inc $6c]
	addq.b	#1,$00ff006c                        ; [...]
	rts                                    		; [rts]
	
l_1ff0:
	;GET_ADDRESS	$06                      ; [lda $06]
	move.b	$00ff0006,d0                     ; [...]
	and.b	#$01,d0                         ; [and #$01]
	bne	l_201f                             	; [bne l_201f]
	;GET_ADDRESS	$05                     ; [lda $05]
	move.b	$00ff0005,d0                     ; [...]
	cmp.b	#$a2,d0                         	; [cmp #$a2]
	bcs	l_201f                             	; [bcc l_201f]
	cmp.b	#$b2,d0                         	; [cmp #$b2]
	bcc	l_201f                             	; [bcs l_201f]
	;GET_ADDRESS	$07                      ; [lda $07]
	move.b	$00ff0007,d0                       ; [...]
	SET_XC_FLAGS                           	; [sec]
	;GET_ADDRESS	$33                       ; [sbc $33]
	SBC	$00ff0033,d0                           ; [...]
	PUSH_SR
	;GET_ADDRESS	$0f                      ; [sta $0f]
	move.b	d0,$00ff000f                       ; [...]
	POP_SR
	CLR_XC_FLAGS                           	; [clc]
	;GET_ADDRESS	$0e                       ; [ldx $0e]
	move.b	$00ff000e,d1                         	; [...]
	;GET_ADDRESS	 $374f                     	; [adc $374f,x]
	move.b	(a0,d1.w),d4					;	addx.b	(a0,d1.w),d0 
	addx.b	d4,d0                    	; [...]
	SET_XC_FLAGS                           	; [sec]
	SBC_IMM	$05                           	; [sbc #$05]
	bmi	l_201f                           ; [bmi l_201f]
	;GET_ADDRESS	$0f                 ; [lda $0f]
	move.b	$00ff000f,d0 
	CLR_XC_FLAGS                        ; [clc]
	;GET_ADDRESS	$3747              ; [adc $3747,x]
	move.b	(a0,d1.w),d4				;	addx.b	(a0,d1.w),d0
	addx.b	d4,d0                    	; [...]
	SET_XC_FLAGS                           	; [sec]
	SBC_IMM	 $0f                           	; [sbc #$0f]
	bpl	l_201f                             	; [bpl l_201f]
	SET_XC_FLAGS                           	; [sec]
	rts                                    	; [rts]
	
l_201f:
	CLR_XC_FLAGS                           ; [clc]
	rts                                    	; [rts]
	
l_2021: ; air mine routine.
	rts
	
l_20ec:
	bsr.w	l_2c66                            	; [jsr l_2c66]
	move.b	#$40,d0                        		; [lda #$40]
	move.b	d0,$00ff0029                       ; [sta $29]
	;move.b	#$f1,d0                        	; [lda #$f1]    
	move.b	#$f1,$00ff004a                     ; [sta $4a]
	;clr.b	d0                               	; [lda #$00]          
	move.b	#$0,$00ff002a                      ; [sta $2a]
	bsr.w	l_2cb2                            	; [jsr l_2cb2] - tested 95%
	bsr.w	l_2ca5                            	; [jsr l_2ca5] - tested 100%
	bsr.w	l_2f33                            	; [jsr l_2f33] - tested 0% color tables - to do
	bsr.w	l_2e17                            	; [jsr l_2e17] - clear bottom row 8. 5000 ?
	bsr.w	l_2beb                            	; [jsr l_2beb]
	bsr.w	l_2ed7                            	; [jsr l_2ed7] - generate stars
	bsr.w	l_2532                            	; [jsr l_2532] - more stars
	;move.b	#$fb,d0                        	; [lda #$fb]
	;PUSH_SR
	;GET_ADDRESS	$d025                     ; [sta $d025] - sprite extra colour 1 ( bits 0-3 )
	;move.b	d0,(a0)                         	; [...]
	;POP_SR
	clr.w	d0                               	; [lda #$00]               
	move.b	d0,$00ff0034 						; [sta $34]
	move.b	d0,$00ff002e 	                    ; [sta $2e]
	move.b	d0,$00ff003f						; [sta $3f]
	move.b	d0,$00ff0047                    	; [sta $47]
	move.b	d0,$00ff0046                       ; [sta $46]
	move.b	d0,$00ff003e                      	; [sta $3e]
	move.b	d0,$00ff0032                    	; [sta $32]
	;move.b	#$ff,d0								; [lda #$ff]
	;PUSH_SR
	move.b	#$ff,$00ff002d                 	; [sta $2d]
	;POP_SR
	;move.b	#$10,d0								; [lda #$10]
	;PUSH_SR
	move.b	#$10,$00ff003d                     ; [sta $3d]
	;POP_SR
	;move.b	#$05,d0								; [lda #$05]
	;PUSH_SR
	move.b	#$05,$00ff0045                     ; [sta $45]
	;POP_SR
	;move.b	#$59,d0                        	; [lda #$59]
	;PUSH_SR
	move.b	#$59,$00ff0040                     ; [sta $40]
	;POP_SR
	;move.b	#$98,d0                        	; [lda #$98]
	;PUSH_SR
	move.b	#$98,$00ff0033                     ; [sta $33]
	;POP_SR
	;move.b	#$01,d0                        	; [lda #$01]
	;PUSH_SR
	move.b	#$01,$00ff0048                     ; [sta $48]
	;POP_SR
	;GET_ADDRESS	$2936                     ; [lda $2936]
	;lea	l_2935+1,a0
	;move.b	l_2935+1,d0                       ; [...]
	;PUSH_SR
	move.b	l_2935+1,$00ff0049                 ; [sta $49]
	;POP_SR
	move.b	$00ff004b,d0                 		; [lda $4b]
	;PUSH_SR
	;GET_ADDRESS	$d02e                     ; [sta $d02e] sprite #7 color (only bits #0-#3).
	;move.b	d0,(a0)                         	; [...]
	;POP_SR
	;move.b	#$2f,d0                        	; [lda #$2f]
	;PUSH_SR
	;GET_ADDRESS	$3f4a                     ; [sta $3f4a]
	;lea $00ff3f4a,a0							; scroll value used in interrupt routine on c64
	move.b	#$2f,$00ff3f4a                     ; [...]
	;POP_SR
	bsr.w	l_17e2                            	; [jsr l_17e2]
	rts                                    		; [rts]

	
	;===================
	; Attract mode setup
	;===================
l_2150:
	;move.w	#$02,d0						; [lda #$02] - timer for splash screen
	;PUSH_SR
	move.b	#02,$00ff0059				; [sta $59]  - splash screen timer ( pre scrolling )
	;POP_SR
	;clr.b	d0							; [lda #$00]
	;PUSH_SR
	move.b	#$0,$00ff0062				; [sta $62]
	;POP_SR

	;=======================
	; Attract mode main loop
	;=======================
l_2158:
	
	bsr.w	l_b019						; [jsr l_b019] - verify joy controls
	bsr.w	l_b1fd						; [jsr l_b1fd] - read the keyboard 	- in progress.
	bsr.w	l_b31b						; [jsr l_b31b] - results of input to screen, volume, number of players - to do.
	
	;=============
	;Animation bar
	;=============
	bsr.w	l_22d3						; [jsr l_22d3]
	bsr.w	l_2342						; [jsr l_2342]
	bsr.w	l_23b5						; [jsr l_23b5]
	
	;========================
	;Timing for animation bar
	;========================
	move.w	#$24,d2						; [ldy #$0c]	; delay timer for animation bar transition
	bsr.w	l_b244						; [jsr l_b244]
	;GET_ADDRESS	$62					; [inc $62]
	addq.b	#2,$00ff0062				; [...]
	;GET_ADDRESS	$18					; [lda $18]
	move.b	$00ff0018,d0				; [...]
	beq.s	l_217d 						; [beq l_217d]
	;GET_ADDRESS	$62 				; [lda $62]
	move.b	$00ff0062,d0				; [...]
	bne.s	l_2158 						; [bne l_2158]
	;GET_ADDRESS	$59					; [dec $59]
	subq.b	#1,$00ff0059				; [...]
	bne	l_2158							; [bne l_2158]
	
l_217d:
	rts 								; [rts]
	
l_217e:
	clr.b	d0							; [lda #$00]
	;PUSH_SR
	;GET_ADDRESS	$62					; [sta $62]
	move.b	d0,$00ff0062				; [...]
	;POP_SR
l_2182:
	;GET_ADDRESS	$2f					; [lda $2f]
	;move.b	(a0),d0						; [...]
	;bne	l_2182						; [bne l_2182]
	move.w vdp_control,d0				; Move VDP status word to d0
	andi.w #$0008,d0					; AND with bit 4 (vblank), result in status register
	bne.w l_2182	
	
	;======================
	; Scroll playfield only
	;======================
	move.b $00ff002c,d0				; value to scroll 0 or 4 - when scroll = 0, character is shifted an entire column
	move.b	#$12,d1						; playfield height is 17
	lea vram_addr_hscroll+$a0,a1	
scroll_loop:
	add.w	#$20,a1
	SetVRAMWriteReg a1
	move.w d0,vdp_data
	dbra d1,scroll_loop
	
	bsr.w	l_2b40						; [jsr l_2b40]
	bsr.w	l_2beb						; [jsr l_2beb] - scrolling routine and bullets for manta ?
	;bsr.w	l_2ed7						; [jsr l_2ed7] - see 20ec
	bsr.w	l_2fc8						; [jsr l_2fc8] - to do
	bsr.w	l_b019						; [jsr l_b019] - read joystick
	bsr.w	l_b1fd						; [jsr l_b1fd] - read keyboard
	bsr.w	l_22d3						; [jsr l_22d3]
	bsr.w	l_b31b 						; [jsr l_b31b]
	bsr.w	l_23b5						; [jsr l_23b5]
	bsr.w	l_2342 						; [jsr l_2342]
	;GET_ADDRESS	$62					; [inc $62]
	addq.b	#1,$00ff0062				; [...]
	;GET_ADDRESS	$18					; [lda $18]
	move.b	$00ff0018,d0				; [...]
	beq.s	l_21b4						; [beq l_21b4]
	;GET_ADDRESS	$2a					; [lda $2a]	; scroll timer ?
	move.b	$00ff002a,d0				; [...]
	cmp.b	#$0e,d0						; [cmp #$0e]
	bcs.w	l_2182						; [bcc l_2182]
	;GET_ADDRESS	$29					; [lda $29]
	move.b	$00ff0029,d0				; [...]
	bpl	l_2182 							; [bpl l_2182]
l_21b4:
	rts 								; [rts]
	
	;=================
	;Game attract demo
	;=================
	
	; in progress
	
l_21b5:
	;move.b	#$01,d0						; [lda #$01]
	;GET_ADDRESS	$5a					; [sta $5a]
	;move.b	d0,$00ff005a
	move.b #$01,$00ff005a
	clr.b	d0							; [lda #$00]
	;GET_ADDRESS	$5f					; [sta $5f]
	move.b	d0,$00ff005f
	;GET_ADDRESS	$5e					; [sta $5e]
	move.b	d0,$00ff005e
	;GET_ADDRESS	$20					; [sta $20]
	move.b	d0,$00ff0020
	;GET_ADDRESS	$21					; [sta $21]
	move.b	d0,$00ff0021
	;GET_ADDRESS	$22					; [sta $22]
	move.b	d0,$00ff0022
	;GET_ADDRESS	$23					; [sta $23]
	move.b	d0,$00ff0023
	;GET_ADDRESS	$24					; [sta $24]
	move.b	d0,$00ff0024
	;move.b	#$07,d0						; [lda #$07]
	;GET_ADDRESS	$8d					; [sta $8d]
	;move.b	d0,$00ff008d
	move.b #$07,$00ff008d
	
	move.b	#$10,d0						; [lda #$10]
	;GET_ADDRESS	$8e					; [sta $8e]
	move.b	d0,$00ff008e				; [...]
	;GET_ADDRESS	$0800				; [lda $0800]
	;move.b	l_800,d0					; [...]
	move.b  $0ff0800,d0
	and.b	#$07,d0						; [and #$07]
										; [clc]
	add.b	#$01,d0						; [adc #$01]
	;GET_ADDRESS	$26					; [sta $26]
	move.b	d0,$00ff0026				; [...]
	bsr.w	l_20ec						; [jsr l_20ec]
	;bsr.w	l_1a38						; [jsr l_1a38] - alters characters set from c100, change this routine.
	;move.b	#$08,d0						; [lda #$08]
	;GET_ADDRESS	$59					; [sta $59]
	;move.b	d0,$00ff0059
	move.b #$08,$00ff0059
	move.w #l_32c1,d2					;[ldx #$c1]/ [ldy #$32]			
	move.b d2,d1
	lsr.w #8,d2
	move.b	d1,$00ff001a				;[stx $1a]
	move.b	d2,$00ff001b				;[sty $1b]
	bsr.w l_b287
	
	;GET_ADDRESS	$3319 				; [lda $3319]
	;move.b	(a0),d0						; [...]
	;PUSH_SR
	;GET_ADDRESS	$1b					; [sta $1b]
	;move.b	d0,(a0)						; [...]
	;POP_SR
	;GET_ADDRESS	$330f				; [lda $330f]
	;move.b	(a0),d0						; [...]
	;PUSH_SR
	;GET_ADDRESS	$1a					; [sta $1a]
	;move.b	d0,(a0)						; [...]
	
	move.l #l_330f,a0					; [lda $330f] and $3319 ( hi/low )
	move.l	(a0),d2
	move.b d2,d1
	lsr.w #8,d2
	move.b	d1,$00ff001a				; [stx $1a]
	move.b	d2,$00ff001b				; [sty $1b]
	bsr.w l_b287						; [jsr l_b287]

	;GET_ADDRESS	$4e					; [lda $4e]
	move.b	$00ff004e,d0				; [...]
	;GET_ADDRESS	$d025				; [sta $d025]
	;move.b	 d0,(a0)					; [...]
	;GET_ADDRESS	$4b					; [lda $4b]
	move.b	$00ff004b,d0				; [...]
	;GET_ADDRESS	$d02e				; [sta $d02e]
	;move.b	d0,(a0)						; [...]
	
	;move.b $ff,d0						; [lda #$ff]
	;GET_ADDRESS	$55					; [sta $55]
	;move.b	d0,$00ff0055				; [...]
	move.b $ff,$00ff0055
	move.w	#$07,d2						; [ldy #$07]

l_220d:
	;GET_ADDRESS	$32ed				; [lda $32ed,y]
	lea l_32ed,a0
	move.b	(a0,d2.w),d0				; [...]
	;PUSH_SR
	;GET_ADDRESS	$0035				; [sta $0035,y]
	lea $00ff0035,a0
    move.b	d0,(a0,d2.w)				; [...]
	;POP_SR
	;subq.b	#1,d2						; [dey]
	;bpl	l_220d						; [bpl l_220d]
	dbra d2,l_220d
	
	;===================
	;Game demo main loop
	;===================
l_2216:
	;GET_ADDRESS	$2f					; [lda $2f]
	;move.b	$00ff002f,d0				; [...]
	;bne.s	l_2216						; [bne l_2216]
	move.w vdp_control,d0				; Move VDP status word to d0
	andi.w #$0008,d0					; AND with bit 4 (vblank), result in status register
	bne.w l_2216	
	
	
	bsr.w	l_2a17						; [jsr l_2a17] - routine manages the bullets.
	bsr.w	l_2b40						; [jsr l_2b40]	
l_2220:
	; need to test these
	bsr.w	l_2beb						; [jsr l_2beb]
	;bsr.w	l_2ed7						; [jsr l_2ed7] - see 20ec
	bsr.w	l_2fc8						; [jsr l_2fc8] - to test
	bsr.w	l_1bfd 						; [jsr l_1bfd] - to test
	bsr.w	l_1a75						; [jsr l_1a75]
	bsr.w	l_b019						; [jsr l_b019] check joystick
	bsr.w	l_b1fd						; [jsr l_b1fd]
	bsr.w	l_b31b						; [jsr l_b31b]
	;GET_ADDRESS	$18					; [lda $18]
	move.b	$00ff0018,d0
	beq	l_227b							; [beq l_227b]
	clr.b	d0							; [lda #$00]
	;PUSH_SR
	;GET_ADDRESS	$22					; [sta $22]
	move.b	d0,$00ff0022
	;POP_SR
	;GET_ADDRESS	$62					; [inc $62]
	addq.b	#1,$00ff0062				; [...]
	;GET_ADDRESS	$62					; [lda $62]
	move.b	$00ff0062,d0				; [...]
	and.b	#$03,d0						; [and #$03]
	move.b	d0,d2						; [tay]
	;GET_ADDRESS	$36dd				; [lda $36dd,y]

	lea l_36dd,a0
	rol.b #2,d2	
	move.l (a0,d2.w),$00ff0108			; use ram ptr 	
	;GET_ADDRESS	$36e1             ; [lda $36e1,y] - not needed
	
l_2253:		
	move.l $00ff0108,a0
	jsr	(a0)							; ptr to table at l_36dd, ; [jsr l_22d3]
	; test these.
	bsr.w	l_2287						; [jsr l_2287]
	bsr.w	l_292f						; [jsr l_292f]
	bsr.w	l_2576						; [jsr l_2576]
	bsr.w	l_2635						; [jsr l_2635]
	bsr.w	l_268c						; [jsr l_268c]
	bsr.w	l_2713						; [jsr l_2713]
	;GET_ADDRESS	$32					; [lda $32]
	move.b	$00ff0032,d0				; [...]
	bne	l_227c							; [bne l_227c]
	;GET_ADDRESS	$62					; [lda $62]
	move.b	$00ff0062,d0				; [...]
	bne	l_2216							; [bne l_2216]
	;GET_ADDRESS	$59					; [dec $59]
	subq.b	#1,$00ff0059				; [...]
	bne	l_2216							; [bne l_2216]
	move.b	#$10,d0						; [lda #$10]
	PUSH_SR
	;GET_ADDRESS	$18					; [sta $18]
	move.b	d0,$00ff0018				; [...]
	;POP_SR
	bsr.w	l_3086						; [jsr l_3086]
	
l_227b:
	rts
	
l_227c:
	move.b	#$10,d0						; [lda #$10]
	;PUSH_SR
	;GET_ADDRESS	$18					; [sta $18]
	move.b	d0,$00ff0018				; [...]
	;POP_SR
	bsr.w	l_245b						; [jsr l_245b]
	bsr.w	l_3086						; [jsr l_3086]
	rts									; [rts]
	
l_2287:
	;GET_ADDRESS	$8e                       ; [lda $8e]
	move.b	$00ff008e,d0                       ; [...]
	;PUSH_SR
	;GET_ADDRESS	$18                       ; [sta $18]
	move.b	d0,$00ff0018                       ; [...]
	;POP_SR
	move.b $00ffd41b,d0                     	; [lda $d41b] - sid, used for random numbers
	cmp.b	#$be,d0                         	; [cmp #$be]
	bcs	l_229a                             		; [bcc l_229a]
	;GET_ADDRESS	$18                       ; [lda $18]
	move.b	$00ff0018,d0                       ; [...]
	eor.b	#$10,d0                         	; [eor #$10]
	;PUSH_SR
	;GET_ADDRESS	$18                       ; [sta $18]
	move.b	d0,$00ff0018                       ; [...]
	;GET_ADDRESS	$8e                       ; [sta $8e]
	move.b	d0,$00ff008e                       ; [...]
	;POP_SR
	
l_229a:
	;GET_ADDRESS	$5e                       ; [lda $5e]
	move.b	$00ff005e,d0                       ; [...]
	PUSH_SR
	;GET_ADDRESS	$16                       ; [sta $16]
	move.b	d0,$00ff0016                       ; [...]
	POP_SR
	move.b $00ffd41b,d0                   		; [lda $d41b]
	cmp.b	#$b4,d0                         	; [cmp #$b4]
	bcs	l_22b6                             		; [bcc l_22b6]
	clr.b	d2                               	; [ldy #$00]
	cmp.b	#$dc,d0                         	; [cmp #$dc]
	bcs	l_22b2                             		; [bcc l_22b2]
	addq.b	#1,d2                           	; [iny]
	cmp.b	#$ee,d0                         	; [cmp #$ee]
	bcs	l_22b2                             		; [bcc l_22b2]
	subq.b	#1,d2                           	; [dey]
	subq.b	#1,d2                           	; [dey]
	
l_22b2:
	;PUSH_SR
	;GET_ADDRESS	$16                       ; [sty $16]
	move.b	d2,$00ff0016                       ; [...]
	;GET_ADDRESS	$5e                       ; [sty $5e]
	move.b	d2,$00ff005e                       ; [...]
	;POP_SR
	
l_22b6:
	;GET_ADDRESS	$5f                       ; [lda $5f]
	move.b	$00ff005f,d0                       ; [...]
	;PUSH_SR
	;GET_ADDRESS	$17                       ; [sta $17]
	move.b	d0,$00ff0017                       ; [...]
	;POP_SR
	;GET_ADDRESS	$d41b                     	; [lda $d41b]
	move.b $00ffd41b,d0
	cmp.b	#$b4,d0                         	; [cmp #$b4]
	bcs	l_22d2                             	; [bcc l_22d2]
	clr.b	d2                               	; [ldy #$00]
	cmp.b	#$dc,d0                         	; [cmp #$dc]
	bcs	l_22ce                             	; [bcc l_22ce]
	addq.b	#1,d2                           	; [iny]
	cmp.b	#$ee,d0                         	; [cmp #$ee]
	bcs	l_22ce                             	; [bcc l_22ce]
	subq.b	#1,d2                           	; [dey]
	subq.b	#1,d2                           	; [dey]
	
l_22ce:
	;PUSH_SR
	;GET_ADDRESS	$17                       ; [sty $17]
	move.b	d2,$00ff0017                       ; [...]
	;GET_ADDRESS	$5f                       ; [sty $5f]
	move.b	d2,$00ff005f                       ; [...]
	;POP_SR
l_22d2:
	rts                                    	; [rts]

l_22d3:
	;GET_ADDRESS	$62					; [lda $62]
	move.b	$00ff0062,d0				; [...]
	and.b	#$7f,d0						; [and #$7f]
	bne	l_231c							; [bne l_231c]
	;GET_ADDRESS	$5b					; [lda $5b]
	move.b	$00ff005b,d0				; [...]
	;PUSH_SR
	;GET_ADDRESS	$0f					; [sta $0f]
	move.b	d0,$00ff000f				; [...]
	;POP_SR
										; [clc]
	add.b	#$01,d0						; [adc #$01]
	and.b	#$03,d0						; [and #$03]
	;PUSH_SR
	;GET_ADDRESS	$5b					; [sta $5b]
	move.b	d0,$00ff005b				; [...]
	;POP_SR
	beq	l_231d							; [beq l_231d]
	;GET_ADDRESS	$5a					; [lda $5a]
	;move.b	$00ff005a,d0				; [...]
	cmp.b	#$03,$00ff005a				; [cmp #$03]
	beq	l_231d							; [beq l_231d]
	;GET_ADDRESS	$5b					; [lda $5b]
	move.b	$00ff005b,d0				; [...]
	cmp.b	#$01,d0						; [cmp #$01]
	beq	l_2325							; [beq l_2325]
	cmp.b	#$02,d0						; [cmp #$02]
	beq	l_232d							; [beq l_232d]
	;GET_ADDRESS	$5a					; [lda $5a]
	move.b	$00ff005a,d0				; [...]
	cmp.b	#$02,d0                     ; [cmp #$02]
	beq	l_2335                          ; [beq l_2335]
	
	;==============================
	;Animation Bar center and right
	;==============================
l_22fc:
	;GET_ADDRESS	$5c					; [lda $5c]
	move.b	$00ff005c,d2				; [...]
	;move.b	d0,d2						; [tay]
	
	rol.w #2,d2							 ; 16bit address to 32bit
	move.l #l_3570,a0							
	move.l	(a0,d2.w),d2
	move.b d2,d1
	ror.w #8,d2
	bsr.w l_b295

	;GET_ADDRESS	$3573                ; [lda $3573,y]
	;move.b	(a0,d2.w),d0                ; [...]
	;GET_ADDRESS	$3570                ; [ldx $3570,y]
	;move.b	(a0,d2.w),d1                ; [...]
	;move.b	d0,d2                       ; [tay]
	;bsr.w	l_b295                       ; [jsr l_b295]
	
	;GET_ADDRESS	 $61					; [lda $61]
	move.b	$00ff0061,d0					; [...]
	beq	l_2315								; [beq l_2315]
	
	move.w #l_34f5,d2						; [ldx #$f5] , [ldy #$34]
	move.b d2,d1
	ror.w #8,d2
	bsr.w l_b295							; [jsr l_b295]
	rts                                     ; [rts]
	;==========================
	;Animation Bar left portion
	;==========================
l_2315:
	move.l #gameTextColour,d2				; [ldx #$f5] , [ldy #$34]
	move.b d2,d1
	ror.w #8,d2
	bsr.w l_b295							; [jsr l_b295]
l_231c:
	rts
	
	;=====================
	;Animation Bar Uridium
	;=====================
l_231d:
	move.w #gameTextUridium,d2			; [ldx #$f5] , [ldy #$34]
	move.b d2,d1
	ror.w #8,d2
l_2321:
	bsr.w l_b295						; [jsr l_b295]
	rts

	;========================
	;Animation Bar High Score
	;========================
l_2325:
	move.w #gameTextHighScore,d2				
	move.b d2,d1
	ror.w #8,d2
	bsr.w l_b295		
	rts 

	;======================= 
	;Animation Bar 12000 AEB
	;=======================
l_232d:
	move.w #gameTextHighAEB,d2				
	move.b d2,d1
	ror.w #8,d2
	bsr.w l_b295		
	rts 

	;=============================
	;Prints Level During game play
	;=============================
l_2335:	
	; to do.
	;GET_ADDRESS	$26                       ; [ldy $26]
	;move.b	(a0),d2                         	; [...]
	;GET_ADDRESS	$e050                     ; [ldx $e050,y]
	;move.b	(a0,d2.w),d1                    	; [...]
	;GET_ADDRESS	$e060                    	; [lda $e060,y]
	;move.b	(a0,d2.w),d0                    	; [...]
	;move.b	d0,d2                           	; [tay]
	;jbsr	l_b295								; [jsr l_b295]
	
	; to check this later
	;GET_ADDRESS	$26                       ; [ldy $26]
	move.b	$00ff0026,d2                       ; [...]
	lea	$0ffe050,a0                    		; [ldx $e050,y]
	move.b	(a0,d2.w),d1
	lea	$0ffe060,a0
	move.b	(a0,d2.w),d0  
	move.b	d0,d2
	bsr.w	l_b295
	rts                                    		; [rts]
	
l_2342:
	;GET_ADDRESS	$19                       ; [lda $19]
	move.b	$00ff0019,d0                       ; [...]
	and.b	#$10,d0                         	; [and #$10]
	beq	l_2351                             		; [beq l_2351]
	;GET_ADDRESS	$19                       ; [lda $19]
	move.b	$00ff0019,d0                       ; [...]
	and.b	#$a0,d0                         	; [and #$a0]
	cmp.b	#$80,d0                         	; [cmp #$80]
	beq	l_237b                             		; [beq l_237b]
	rts                                    		; [rts]
	
l_2351:	
	;clr.b	d1                               	; [ldx #$00]
	;move.b	#$dc,d2                        	; [ldy #$dc]
	;PUSH_SR
	;GET_ADDRESS	$b025                     ; [stx $b025]
	;move.b	d1,(a0)                         	; [...]
	;GET_ADDRESS	$b026                    	; [sty $b026]
	;move.b	d2,(a0)                         	; [...]
	;POP_SR
	;move.b	#$01,d1                        	; [ldx #$01]
	;move.b	#$dc,d2                        	; [ldy #$dc]
	;PUSH_SR
	;GET_ADDRESS	$b028                    	; [stx $b028]
	;move.b	d1,(a0)                         	; [...]
	;GET_ADDRESS	$b029                     ; [sty $b029]
	;move.b	d2,(a0)                         	; [...]
	;POP_SR
	
	;GET_ADDRESS	$19                       ; [lda $19]
	move.b	$00FF0019,d0                       ; [...]
	bmi	l_2389                             		; [bmi l_2389]
	move.b	#$02,d0                        		; [lda #$02]
	PUSH_SR
	;GET_ADDRESS	$5c                       ; [sta $5c]
	move.b	d0,$00FF005C                       ; [...]
	POP_SR               
	
	move.w #l_34d0,d2							; [ldx #$d0]
	move.b d2,d1								; [ldy #$34]
	lsr.w #8,d2									; [jsr l_b295]
	bsr.w l_b295		

l_2374:
	;GET_ADDRESS	$5b                       ; [lda $5b]
	move.b	$00FF005B,d0                       ; [...]
	cmp.b	#$03,d0                         	; [cmp #$03]
	beq	l_22fc                             		; [beq l_22fc]
	rts                                    		; [rts]	
	
l_237b:
	clr.b	d0                               	; [lda #$00]
	PUSH_SR
	;GET_ADDRESS	$5c                       ; [sta $5c]
	move.b	d0,$00FF005C                       ; [...]
	POP_SR
	
	move.w #l_34db,d2				
	move.b d2,d1
	lsr.w #8,d2
	bsr.w l_b295		
	jmp	l_2374                             		; [jmp l_2374]

l_2389:
	move.b	#$01,d0                        		; [lda #$01]
	;PUSH_SR
	;GET_ADDRESS	$5c                       ; [sta $5c]
	move.b	d0,$00FF005C                       ; [...]
	;POP_SR
	move.w #l_34e5,d2				
	move.b d2,d1
	lsr.w #8,d2
	bsr.w l_b295		
	jmp	l_2374                             		; [jmp l_2374]	
	
	;==============
	;Clears screen
	;==============
l_2397:
	move.w	a1,d2 								; vram_addr_plane_a address.
	move.b d2,d1								; get low byte
	lsr.w #8,d2									; get high byte
	
	;PUSH_SR
	;GET_ADDRESS	$1c                       ; [stx $1c]
	move.b	d1,$00ff001c                       ; [...]
	;GET_ADDRESS	$1d                       ; [sty $1d]
	move.b	d2,$00ff001d						; [...]
	;POP_SR
	move.w	#$18,d3                        		; [ldx #$15]
	bsr.w	l_b189                            	; [jsr l_b189]
	rts                                    		; [rts]

	;==============
	;Sets color ram
	;==============

l_23a5:
	;PUSH_SR
	;GET_ADDRESS	$8f                       ; [sty $8f]
	move.b	d2,$00FF008F                       ; [...]
	;POP_SR
l_23a7:
	;GET_ADDRESS	$8f                      	; [ldy $8f]
	move.b	$00FF008F,d2                       ; [...]
	GET_ADDRESS_Y	$1a                     	; [lda ($1a),y]
	move.b	(a0,d2.w),d0                    	; [...]
	move.b	#$01,d1                        		; [ldx #$01]
	bsr.w	l_b189                            	; [jsr l_b189]
	;GET_ADDRESS	$8f                       	; [dec $8f]
	subq.b	#1,(a0)                         	; [...]
	bpl	l_23a7                             		; [bpl l_23a7]
	rts                                    		; [rts]
	
l_23b5:
	;GET_ADDRESS	$19                       ; [lda $19]
	move.b	$00FF0019,d0                       ; [...]
	and.b	#$08,d0                         	; [and #$08]
	bne	l_23d6                             		; [bne l_23d6]
	;GET_ADDRESS	$19                       ; [lda $19]
	move.b	$00FF0019,d0                       ; [...]
	bpl	l_23d7                             		; [bpl l_23d7]

	move.w #l_36a0,d2							; [ldx #$a0]	
	move.b d2,d1								; [ldy #$36]
	lsr.w #8,d2									; [jsr l_b295]
	bsr.w l_b295		
	
	clr.b	d0                               	; [lda #$00]
	;PUSH_SR
	;GET_ADDRESS	$61                       ; [sta $61]
	move.b	d0,$00FF0061                       ; [...]
	;POP_SR
	bsr.w	l_23ef                            	; [jsr l_23ef]
	;GET_ADDRESS	$5b                       ; [lda $5b]
	move.b	$00FF005B,d0                       ; [...]
	cmp.b	#$03,d0                         	; [cmp #$03]
	bne	l_23d6                             		; [bne l_23d6]
	jmp	l_22fc                             		; [jmp l_22fc]
l_23d6:
	rts                                    		; [rts]
	
l_23d7:
	move.w #l_36ad,d2							; [ldx #$a0]	
	move.b d2,d1								; [ldy #$36]
	lsr.w #8,d2									; [jsr l_b295]
	bsr.w l_b295		
	
	move.b #$ff,d0                             ; [lda #$ff]
	;PUSH_SR
	;GET_ADDRESS	$61                       ; [sta $61]
	move.b	d0,$00FF0061                       ; [...]
	;POP_SR
	bsr.w	l_23ef                            	; [jsr l_23ef]
	;GET_ADDRESS	$5b                       ; [lda $5b]
	move.b	$00FF005B,d0                       ; [...]
	cmp.b	#$03,d0                         	; [cmp #$03]
	bne	l_23d6                             		; [bne l_23d6]
	jmp	l_22fc                             		; [jmp l_22fc]
	rts                                    		; [rts]

l_23ef:
	; to do.
	;GET_ADDRESS	$61                       ; [lda $61]
	move.b	$00FF0061,d0                        ; [...]
	beq	l_2402                             		; [beq l_2402]
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
	;PUSH_SR
	;GET_ADDRESS $10                       	; [stx $10]
	move.b	d1,$00FF0010                       ; [...]
	;GET_ADDRESS $11                       	; [stx $11]
	move.b	d1,$00FF0011                       ; [...]
	;POP_SR
l_241b:
	GET_ADDRESS l_349f                     	; [ldy $349f,x]
	move.b	(a0,d1.w),d2                    	; [...]
	bmi	l_244d                             		; [bmi l_244d]
l_2420:
	;GET_ADDRESS scrollTextData             	; [lda $c000,y]
	lea scrollTextData,a0
	move.b	(a0,d2.w),d0  						; 0x78			; [...]
	CLR_XC_FLAGS								; [clc]		
	move.b	#$60,d4	
	addx.b	d4,d0         						 ; 0xD8            	 ; [adc #$60]
	
	lea scrollTextData,a0									
	add.w d0,a0
	move.l a0,d3
	
	;PUSH_SR
	;GET_ADDRESS	$1a                       ; [sta $1a]
	move.b	d3,$00ff001a                       ; [...]
	;POP_SR
	
	move.l d3,d0
	lsr.w #8,d0									; get the high byte
	
	;PUSH_SR
	;GET_ADDRESS	$1b                       ; [sta $1b]
	move.b	d0,$00ff001b                       ; [...]
	;POP_SR
	clr.w	d2                               	; [ldy #$00]
	;GET_ADDRESS	$11                       ; [ldx $11]
	move.b	$00ff0011,d1                       ; [...]
l_2432:
	GET_ADDRESS_Y_ROM	$1a                     ; [lda ($1a),y] - from rom
	move.b	(a0,d2.w),d0                    	; [...]
	beq	l_243a                             		; [beq l_243a]
	;PUSH_SR
	;GET_ADDRESS	l_8010                    ; [sta $8010,x] 
	lea $00ff8010,a0
    move.b	d0,(a0,d1.w)                 		; [...]
	
	;POP_SR
	addq.b	#1,d1                           	; [inx]
l_243a:
	addq.b	#1,d2                           	; [iny]
	cmp.b	#$04,d2                         	; [cpy #$04]
	bcs	l_2432                             		; [bcc l_2432]
	move.b	#$01,d0                        		; [lda #$01]
	;PUSH_SR
	;GET_ADDRESS	l_8010                    ; [sta $8010,x]
	lea $00FF8010,a0
    move.b	d0,(a0,d1.w)                 		; [...]
	;POP_SR
	addq.b	#1,d1                           	; [inx]
	;PUSH_SR
	;GET_ADDRESS	$11                       ; [stx $11]
	move.b	d1,$00FF0011						; [...]
	;POP_SR
	;GET_ADDRESS	$10                       ; [inc $10]
	addq.b	#1,$00ff0010                       ; [...]
	;GET_ADDRESS	$10                       ; [ldx $10]
	move.b	$00ff0010,d1                       ; [...]
	bpl	l_241b                             		; [bpl l_241b]
l_244d:
	;GET_ADDRESS	 $11                      ; [ldx $11]
	move.b	$00ff0011,d1                       ; [...]
	move.b	#$03,d2                        		; [ldy #$03]
	clr.w	d0                               	; [lda #$00]
l_2453:
	;PUSH_SR
	;GET_ADDRESS	l_8010                    ; [sta $8010,x]
	lea $00ff8010,a0
    move.b	d0,(a0,d1.w)                 		; [...]
	;POP_SR
	addq.b	#1,d1                           	; [inx]
	subq.b	#1,d2                           	; [dey]
	bpl	l_2453                             		; [bpl l_2453]
	rts                                    		; [rts]

l_245b:
	clr.b	d0                               	; [lda #$00]
	;PUSH_SR
	;GET_ADDRESS	$d015                     ; [sta $d015] disable sprites
	;move.b	d0,(a0)                         	; [...]
	;GET_ADDRESS	$3f							; [sta $3f]
	move.b	d0,$00ff003f						; [...]
	;POP_SR
	move.b	#$06,d0								; [lda #$06]
	;PUSH_SR
	;GET_ADDRESS	$59							; [sta $59]
	move.b	d0,$00ff0059						; [...]
	;POP_SR
	move.b	#$0c,d0								; [lda #$0c]
	;PUSH_SR
	;GET_ADDRESS	$91							; [sta $91]
	move.b	d0,$00ff0091
	;GET_ADDRESS	$92							; [sta $92]
	move.b	d0,$00ff0092						; [...]
	
	; sprite code
	;POP_SR
	;move.b	#$f8,d0								; [lda #$f8]
	;PUSH_SR
	;GET_ADDRESS	$d026                     ; [sta $d026]
	;move.b	d0,(a0)                         	; [...]
	;POP_SR
	;move.b	#$f0,d0                        	; [lda #$f0]
	;PUSH_SR
	;GET_ADDRESS	$d025                     ; [sta $d025]
	;move.b	d0,(a0)                         	; [...]
	;POP_SR
	
	;move.b	#$e2,d1								; [ldx #$e2]
	;move.b	#$32,d2								; [ldy #$32]
	;PUSH_SR
	;GET_ADDRESS	$1a							; [stx $1a]
	;move.b	d1,(a0)								; [...]
	;GET_ADDRESS	$1b							; [sty $1b]
	;move.b	d2,(a0)								; [...]
	;POP_SR
	;bsr.w	l_b287								; [jsr l_b287]
	
	; sprite explosion data
	move.w #l_32e2,d2					
	move.b d2,d1
	lsr.w #8,d2
	move.b	d1,$00ff001a
	move.b	d2,$00ff001b
	bsr.w l_b287
	
	
	;GET_ADDRESS	$33							; [lda $33]
	move.b	$00ff0033,d0                       ; [...]
	;PUSH_SR
	;GET_ADDRESS	$07							; [sta $07]
	move.b	d0,$00ff0007						; [...]
	;POP_SR
	bsr.w	l_b13f                            	; [jsr l_b13f]

l_2532:
	;move.b	#$a0,d1								; [ldx #$a0]
	;move.b	#$48,d2								; [ldy #$48]
	
	;48a0 - 4800 = a0
	;a0/40 = 4 rows
	;(160 + 4 * 24 ) < 1 = C200
	
	; top row star
	move.b	#$00,d1								
	move.b	#$e2,d2								
	;PUSH_SR
	;GET_ADDRESS	$1c                       ; [stx $1c]
	move.b	d1,$00ff001c                       ; [...]
	;GET_ADDRESS	$1d                       ; [sty $1d]
	move.b	d2,$00ff001d                       ; [...]
	;POP_SR
	move.b	#$30,d0								; [lda #$30]
	;PUSH_SR
	;GET_ADDRESS	$10                       ; [sta $10]
	move.b	d0,$00ff0010                       ; [...]
	;POP_SR
	bsr.w	l_2f15                            	; [jsr l_2f15]
	CLR_XC_FLAGS                           	; [clc]
	;GET_ADDRESS	$1c                       ; [lda $1c]
	move.b	$00ff001c,d0                       ; [...]
	;move.b	#$28,d4								; addx.b	#$28,d0 ; [adc #$28]
	move.b	#$80,d4								
	addx.b	d4,d0								; [adc #$28]
	;PUSH_SR
	;GET_ADDRESS	$1c                       ; [sta $1c]
	move.b	d0,$00ff001c                       ; [...]
	;POP_SR
	bcc	l_254c									; [bcc l_254c]
	;GET_ADDRESS	$1d                       ; [inc $1d]
	addq.b	#1,$00ff001d                       ; [...]
	
	; bottom row star
l_254c:
	bsr.w	l_2f15                            	; [jsr l_2f15]
	;move.b	#$98,d1                        	; [ldx #$98]
	;move.b	#$4b,d2                        	; [ldy #$4b]
	
	;4b98 - 4800 = 398
	;0x398/40 = 23 rows
	;(920 + 23 * 24 ) < 1 = CB80
	move.b	#$80,d1								
	move.b	#$eB,d2		
	
	;PUSH_SR
	;GET_ADDRESS	$1c                       ; [stx $1c]
	move.b	d1,$00ff001c                       ; [...]
	;GET_ADDRESS	$1d                       ; [sty $1d]
	move.b	d2,$00ff001d                       ; [...]
	;POP_SR
	bsr.w	l_2f15                            	; [jsr l_2f15]
	CLR_XC_FLAGS                           	; [clc]
	;GET_ADDRESS	$1c                       ; [lda $1c]
	move.b	$00ff001c,d0                       ; [...]
	;move.b	#$28,d4								; addx.b	#$28,d0  ; [adc #$28]
	move.b #$80,d4
	addx.b	d4,d0                        		; [adc #$28]
	;PUSH_SR
	;GET_ADDRESS 	$1c                       ; [sta $1c]
	;move.b	d0,(a0)                         	; [...]
	;POP_SR
	move.b d0,$00ff001c
	bcs	l_2565                             		; [bcc l_2565]
	;GET_ADDRESS	$1d                       ; [inc $1d]
	addq.b	#1,$00ff001d                       ; [...]
l_2565:	
	bsr.w	l_2f15                            	; [jsr l_2f15]
	move.b	#$05,d2                        		; [ldy #$05]
	move.b	#$20,d0                        		; [lda #$20]
l_256c:
	;PUSH_SR
	;GET_ADDRESS	$4bac                     ; [sta $4bac,y]
	
	;4bac - 4800 = 3ac
	;3ac/40 = 23 rows
	;(940 + 23 * 24 ) < 1 = CBA8

	lea $eba8,a0                     			
    ;move.b	d0,(a0,d2.w)                 		
	add.w d2,a0
	SetVRAMWriteReg a0
	move.w d0,vdp_data

	;GET_ADDRESS	$4bd4                     ; [sta $4bd4,y]
	
	;4bd4 - 4800 = 3d4
	;3d4/40 = 24 rows
	;(980 + 24 * 24 ) < 1 = CC28
	
	lea $ec28,a0
    ;move.b	d0,(a0,d2.w)                 		; [...]
	add.w d2,a0
	SetVRAMWriteReg a0
	move.w d0,vdp_data
	
	;POP_SR
	subq.b	#1,d2                           	; [dey]
	bpl	l_256c                             		; [bpl l_256c]
	rts                                    		; [rts]

l_2576:
	;GET_ADDRESS	$49                     ; [lda $49]
	move.b	$00ff0049,d0                         ; [...]
	beq	l_25b0                             	; [beq l_25b0]
	
l_257a:
	;GET_ADDRESS	$16                    ;lda $16]
	move.b	$00ff0016,d0                     ; [...]
	beq	l_259e                             	; [beq l_259e]
	bmi	l_258f                             	; [bmi l_258f]
	;GET_ADDRESS	$34                   ; [inc $34]
	addq.b	#1,$00ff0034                   ; [...]
	;GET_ADDRESS	$34                    ; [lda $34]
	move.b	$00ff0034,d0                     ; [...]
	bmi	l_258e                             	; [bmi l_258e]
	;GET_ADDRESS	$36                    ; [cmp $36]
	cmp.b	$00ff0036,d0                    ; [...]
	bcs	l_258e                             	; [bcc l_258e]
	;GET_ADDRESS	$36                    ; [lda $36]
	move.b	$00ff0036,d0                    ; [...]
	;PUSH_SR
	;GET_ADDRESS	$34                    ; [sta $34]
	move.b	d0,$00ff0034                    ; [...]
	;POP_SR
l_258e:
	rts                                    	; [rts]
	
l_258f:
	;GET_ADDRESS	$34                   ; [dec $34]
	subq.b	#1,$00ff0034                        ; [...]
	;GET_ADDRESS	$34                  ; [lda $34]
	move.b	$00ff0034,d0                   ; [...]
	bpl	l_258e                             	; [bpl l_258e]
	;GET_ADDRESS	$35                    ; [cmp $35]
	cmp.b	$00ff0035,d0                    ; [...]
	bcc	l_258e                             	; [bcs l_258e]
	;GET_ADDRESS	$35                    ; [lda $35]
	move.b	$00ff0035,d0                    ; [...]
	;PUSH_SR
	;GET_ADDRESS	$34                    ; [sta $34]
	move.b	d0,$00ff0034                    ; [...]
	;POP_SR
	rts                                    	; [rts]
	
l_259e:
	;GET_ADDRESS	$34                     ; [lda $34]
	move.b	$00ff0034,d0                     ; [...]
	cmp.b	#$ff,d0                         	; [cmp #$ff]
	beq	l_25ab                             	; [beq l_25ab]
	roxl.b	#1,d0                           	; [rol a]
	;GET_ADDRESS	$34                      ; [lda $34]
	move.b	$00ff0034,d0                       ; [...]
	roxr.b	#1,d0                           	; [ror a]
	;PUSH_SR
	;GET_ADDRESS	$34                      ; [sta $34]
	move.b	d0,$00ff0034                      ; [...]
	;POP_SR
	rts                                    	; [rts]
	
l_25ab:
	clr.b	d0                               ; [lda #$00]
	;PUSH_SR
	;GET_ADDRESS	$34                      ; [sta $34]
	move.b	d0,$00ff0034                      ; [...]
	;POP_SR
	rts                                    	; [rts]

l_25b0:
	;GET_ADDRESS	$16                     ; [lda $16]
	move.b	$00ff0016,d0                     ; [...]
	bne	l_25b9                             	; [bne l_25b9]
	;GET_ADDRESS	$49                   ; [inc $49]
	addq.b	#1,$00ff0049                    ; [...]
	jmp	l_259e                             	; [jmp l_259e]
	
l_25b9:
	;GET_ADDRESS	$3f                    ; [lda $3f]
	move.b	$00ff003f,d0                     ; [...]
	bne	l_257a                             	; [bne l_257a]
	;GET_ADDRESS	$45                    ;lda $45]
	move.b	$00ff0045,d0                      ; [...]
	bmi	l_257a                             	; [bmi l_257a]
	and.b	#$03,d0                         	; [and #$03]
	cmp.b	#$01,d0                         	; [cmp #$01]
	bne	l_25df                             	; [bne l_25df]
	CLR_XC_FLAGS                           	; [clc]
	;GET_ADDRESS	$16                       	; [adc $16]
	move.b	$00ff0016,d4					;	addx.b	(a0),d0 
	addx.b	d4,d0                         	; [...]
	and.b	#$03,d0                         	; [and #$03]
	or.b	#$80,d0                          	; [ora #$80]
	;PUSH_SR
	;GET_ADDRESS	$0f                       ; [sta $0f]
	move.b	d0,$00ff000f                        ; [...]
	;POP_SR
	;GET_ADDRESS	$3e                       	; [lda $3e]
	move.b	$00ff003e,d0                         	; [...]
	cmp.b	#$03,d0                         	; [cmp #$03]
	bcs	l_257a                             	; [bcc l_257a]

l_25d6:
	;GET_ADDRESS	$45                       ; [lda $45]
	move.b	$00ff0045,d0                         ; [...]
	and.b	#$fc,d0                         	; [and #$fc]
	;GET_ADDRESS	$0f                       ; [ora $0f]
	or.b	$00ff000f,d0                      
	;PUSH_SR
	;GET_ADDRESS	$46                       ; [sta $46]
	move.b	d0,$00ff0046                        ; [...]
	;POP_SR
	rts                                    	; [rts]
	
l_25df:
	move.b	#$81,d0                        	; [lda #$81]
	;PUSH_SR
	;GET_ADDRESS	$0f                    ; [sta $0f]
	move.b	d0,$00ff000f                    ; [...]
	;POP_SR
	bne	l_25d6                             	; [bne l_25d6]
	
	;=========================
	;Manta's Shadow generation
	;=========================
		
l_25e5:		
	; 432 tiles * 32 ( bytes per tile )
	; 225 tiles * 32 ( bytes per tile ) for non mirrored Manta sprites
	SetVRAMWriteConst (vram_addr_tiles+size_tile_b)+tile_count*size_tile_b+manta_count_flipx*size_tile_b
	lea SpritesManta,a0
	lea $00FF1000,a1									; temporarily use the ram to store the shadows.
	move.w #(manta_count_flipx*(size_tile_b))-1,d0	; Loop counter 423 xx 32 bytes per tile
	
L_25F7:													; Start of loop
	move.b (a0)+,d1									; Load byte from sprite data
	tst.b d1											; Test if byte is zero (transparent)
	beq SkipShadow										; If zero, skip shadow generation
	move.b #$bb,d1										; Set shadow color (some darker shade)
SkipShadow:
	move.b d1,(a1)+									; Write byte to shadow buffer and post-increment address
	dbra d0,L_25F7										; Decrement d0 and loop until finished (when d0 reaches -1)
	
	; Write the shadow tiles to VRAM
	lea    $00FF1000,a1							; Move the address of the shadow buffer into a1
	move.w #(manta_count_flipx*(size_tile_l))-1,d0	; Loop counter = 8 longwords per tile * num tiles (-1 for DBRA loop)
ShadowWriteLp:										; Start of shadow writing loop
	move.l (a1)+,vdp_data							; Write tile line (4 bytes per line), and post-increment address
	dbra d0,ShadowWriteLp							; Decrement d0 and loop until finished (when d0 reaches -1)
	
	move.b	#$00,d1									; [ldx #<l_lvl_data2]
	move.b	#$c0,d2									; [ldy #>l_lvl_data2]
	PUSH_SR
	GET_ADDRESS	$1c								; [stx $1c]
	move.b	d1,(a0)									; [...]
	GET_ADDRESS	$1d								; [sty $1d]
	move.b	d2,(a0)									; [...]
	POP_SR
	rts
	
l_2617:
	bmi	l_2627                             	; [bmi l_2627]
	CLR_XC_FLAGS                           	; [clc]
	;GET_ADDRESS	$2d                       	; [adc $2d]
	move.b	$00ff002d,d4						;	addx.b	(a0),d0 
	addx.b	d4,d0                         	; [...]
	;PUSH_SR
	;GET_ADDRESS	$2d                       	; [sta $2d]
	move.b	d0,$00ff002f                         ; [...]
	;POP_SR
	;GET_ADDRESS	$2e                       	; [lda $2e]
	move.b	$00ff002e,d0                         	; [...]
	move.b	#$00,d4							; [adc #$00]
	addx.b	d4,d0                        	; [adc #$00]
	bmi	l_2650                             	; [bmi l_2650]
	
l_2624:
	jmp	l_2679                             	; [jmp l_2679]
l_2627:
	CLR_XC_FLAGS                           ; [clc]
	;GET_ADDRESS	$2d                   ; [adc $2d]
	move.b	$00ff002d,d4					;	addx.b	(a0),d0 
	addx.b	d4,d0                         	; [...]
	;PUSH_SR
	;GET_ADDRESS	$2d                   ; [sta $2d]
	move.b	d0,$00ff002d                    ; [...]
	;POP_SR
	;GET_ADDRESS	$2e                   ; [lda $2e]
	move.b	$00ff002e,d0                   ; [...]
	move.b	#$ff,d4	;	addx.b	#$ff,d0    ; [adc #$ff]
	addx.b	d4,d0                        	; [adc #$ff]
	bmi	l_2650                             	; [bmi l_2650]
	jmp	l_2679                             	; [jmp l_2679]
	
l_2635:
	;GET_ADDRESS	$3f                       ; [lda $3f]
	move.b	$00ff003f,d0                         ; [...]
	bne	l_2617                             		; [bne l_2617]
	;GET_ADDRESS	$45                       ; [lda $45]
	move.b	$00ff0045,d0                       ; [...]
	and.b	#$04,d0                         	; [and #$04]
	bne	l_2668                             		; [bne l_2668]
	;GET_ADDRESS	$17                       ; [lda $17]
	move.b	$00ff0017,d0                       ; [...]
	beq	l_2659                             		; [beq l_2659]
	bmi	l_265a                             		; [bmi l_265a]
	;GET_ADDRESS	$2d                       ; [lda $2d]
	move.b	$00ff002d,d0                       ; [...]
	CLR_XC_FLAGS                           	; [clc]
	;GET_ADDRESS	$39                       ; [adc $39]
	move.b	$00ff0039,d4						;
	addx.b	d4,d0                         		; [...]
	PUSH_SR
	;GET_ADDRESS	$2d                       ; [sta $2d]
	move.b	d0,$00ff002d                       ; [...]
	POP_SR
	;GET_ADDRESS	$2e                       ; [lda $2e]
	move.b	$00ff002e,d0                       ; [...]
	move.b	#$ff,d4								; [adc #$ff]
	addx.b	d4,d0                        		; [adc #$ff]
	
l_2650:
	;PUSH_SR
	;GET_ADDRESS	$2e                       ; [sta $2e]
	move.b	d0,$00ff002e                        ; [...]
	;POP_SR
	not.b	d0                               	; [eor #$ff]
												; [clc]
	add.b	#$01,d0                        		; [adc #$01]
	;PUSH_SR
	;GET_ADDRESS	$3e                      ; [sta $3e]
	move.b	d0,$00ff003e                       ; [...]
	;POP_SR
l_2659:
	rts                                    	; [rts]
	
l_265a:
	;GET_ADDRESS	$2d                       ; [lda $2d]
	move.b	$00ff002d,d0                         ; [...]
	CLR_XC_FLAGS                           	; [clc]
	;GET_ADDRESS	$3a                       	; [adc $3a]
	move.b	$00ff003a,d4						;	addx.b	(a0),d0
	addx.b	d4,d0                         	; [...]
	;PUSH_SR
	;GET_ADDRESS	$2d                       	; [sta $2d]
	move.b	d0,$00ff002d                         	; [...]
	;POP_SR
	;GET_ADDRESS	$2e                       	; [lda $2e]
	move.b	$00ff002e,d0                         	; [...]
	move.b	#$00,d4							; [adc #$00]
	addx.b	d4,d0                        	; [adc #$00]
	jmp	l_2650                             	; [jmp l_2650]
	
l_2668:
	;GET_ADDRESS	$17                    ; [lda $17]
	move.b	$00f0017,d0                         ; [...]
	beq	l_2659                             	; [beq l_2659]
	bpl	l_267e                             	; [bpl l_267e]
	;GET_ADDRESS	$2d                    ; [lda $2d]
	move.b	$00ff002d,d0                     ; [...]
	CLR_XC_FLAGS                           	; [clc]
	;GET_ADDRESS	$3b                       	; [adc $3b]
	move.b	$00ff003b,d4					;	addx.b	(a0),d0
	addx.b	d4,d0                         	; [...]
	;PUSH_SR
	;GET_ADDRESS	$2d                       ; [sta $2d]
	move.b	d0,$00ff002d                        ; [...]
	;POP_SR
	;GET_ADDRESS	$2e                       	; [lda $2e]
	move.b	$00ff002e,d0                         	; [...]
	move.b	#$00,d4							; [adc #$00]
	addx.b	d4,d0                        	; [adc #$00]
	
l_2679:
	;PUSH_SR
	;GET_ADDRESS	$2e                       	; [sta $2e]
	move.b	d0,$00ff002e                         	; [...]
	;GET_ADDRESS	$3e                       	; [sta $3e]
	move.b	d0,$00ff003e                         	; [...]
	;POP_SR
	rts                                    	; [rts]
	
l_267e:
	;GET_ADDRESS	$2d                       ; [lda $2d]
	move.b	$00ff002d,d0                         ; [...]
	CLR_XC_FLAGS                           	; [clc]
	;GET_ADDRESS	$3c                       ; [adc $3c]
	move.b	$00ff003c,d4						;	addx.b	(a0),d0 
	addx.b	d4,d0                         	; [...]
	;PUSH_SR
	;GET_ADDRESS	$2d                       ; [sta $2d]
	move.b	d0,$00ff002d                        ; [...]
	;POP_SR
	;GET_ADDRESS	$2e                       ; [lda $2e]
	move.b	$00ff002e,d0                         	; [...]
	move.b	#$ff,d4							; [adc #$ff]
	addx.b	d4,d0                        	; [adc #$ff]
	jmp	l_2679                             	; [jmp l_2679]
	
l_268c:
	;GET_ADDRESS	$34                    ; [lda $34]
	move.b	(a0),d0                         ; [...]
	CLR_XC_FLAGS                           ; [clc]
	;GET_ADDRESS	$33                    ; [adc $33]
	move.b	(a0),d4							;	addx.b	(a0),d0
	addx.b	d4,d0                         	; [...]
	cmp.b	#$62,d0                         	; [cmp #$62]
	bcc	l_2697                             	; [bcs l_2697]
	move.b	#$62,d0                        	; [lda #$62]
	
l_2697:
	cmp.b	#$d7,d0                         	; [cmp #$d7]
	bcs	l_269d                             	; [bcc l_269d]
	move.b	#$d7,d0                        	; [lda #$d7]
	
l_269d:
	;PUSH_SR
	;GET_ADDRESS	$33                   ; [sta $33]
	move.b	d0,$00ff0033                   ; [...]
	;POP_SR
	;GET_ADDRESS	$2e                   ; [lda $2e]
	move.b	$00ff002e,d0                    ; [...]
	bmi	l_26d1                             	; [bmi l_26d1]
	;GET_ADDRESS	$38                   ; [cmp $38]
	cmp.b	$00ff0038,d0                   ; [...]
	bcs	l_26ab                             	; [bcc l_26ab]
	;GET_ADDRESS	$38                   ; [lda $38]
	move.b	$00ff0038,d0                    ; [...]
	;PUSH_SR
	;GET_ADDRESS	$2e                    ; [sta $2e]
	move.b	d0,$00ff002e                   ; [...]
	;POP_SR
	
l_26ab:
	;GET_ADDRESS	$45                    ; [lda $45]
	move.b	$00ff0045,d0                    ; [...]
	bmi	l_26eb                             	; [bmi l_26eb]
	;GET_ADDRESS	$2a                   ; [lda $2a]
	move.b	$00ff002a,d0                    ; [...]
	bne	l_26ba                             	; [bne l_26ba]
	move.b	#$c8,d0                        	; [lda #$c8]
	;PUSH_SR
	;GET_ADDRESS	$3f                   ; [sta $3f]
	move.b	d0,$00ff003f                     ; [...]
	;POP_SR
	jmp	l_26eb                             	; [jmp l_26eb]
	
l_26ba:
	cmp.b	#$0e,d0                         ; [cmp #$0e]
	bcs	l_26eb                             	; [bcc l_26eb]
	;GET_ADDRESS	$29                   ; [lda $29]
	move.b	$00ff0029,d0                         ; [...]
	bpl	l_26eb                             	; [bpl l_26eb]
	
l_26c2:
	;GET_ADDRESS	$45                   ; [lda $45]
	move.b	$00ff0045,d0                    ; [...]
	or.b	#$80,d0                         ; [ora #$80]
	PUSH_SR
	;GET_ADDRESS	$46                   ; [sta $46]
	move.b	d0,$00ff0046                   ; [...]
	;POP_SR
	jmp	l_26eb                             	; [jmp l_26eb]
	
l_26cb:
	;GET_ADDRESS	$29                   ; [lda $29]
	move.b	$00ff0029,d0                   ; [...]
	bmi	l_26eb                             	; [bmi l_26eb]
	bpl	l_26c2                             	; [bpl l_26c2]
l_26d1:
	;GET_ADDRESS	$37                   ; [cmp $37]
	cmp.b	$00ff0037,d0                     ; [...]
	bcc	l_26d9                             	; [bcs l_26d9]
	;GET_ADDRESS	$37                       	; [lda $37]
	move.b	$00ff0037,d0                         	; [...]
	;PUSH_SR
	;GET_ADDRESS	$2e                       	; [sta $2e]
	move.b	d0,$00ff002e                         	; [...]
	;POP_SR

l_26d9:
	;GET_ADDRESS	$45                    ; [lda $45]
	move.b	$00ff0045,d0                    ; [...]
	bmi	l_26eb                             	; [bmi l_26eb]
	;GET_ADDRESS	$2a                   ; [lda $2a]
	move.b	$00ff002a,d0                    ; [...]
	bmi	l_26eb                             	; [bmi l_26eb]
	beq	l_26cb                             	; [beq l_26cb]
	cmp.b	#$0e,d0                         	; [cmp #$0e]
	bcs	l_26eb                             	; [bcc l_26eb]
	move.b	#$38,d0                        	; [lda #$38]
	;PUSH_SR
	;GET_ADDRESS	$3f                   ; [sta $3f]
	move.b	d0,$00ff003f                   ; [...]
	;POP_SR

l_26eb:
	;GET_ADDRESS	$3e                    ; [lda $3e]
	move.b	$00ff003e,d0                    ; [...]
	cmp.b	#$03,d0                         ; [cmp #$03]
	bcc	l_26ff                             	; [bcs l_26ff]
	cmp.b	#$02,d0                         	; [cmp #$02]
	bcc	l_2700                             	; [bcs l_2700]
	;GET_ADDRESS	$45                    ; [lda $45]
	move.b	$00ff0045,d0                     ; [...]
	bmi	l_26ff                             	; [bmi l_26ff]
	eor.b	#$04,d0                         ; [eor #$04]
	or.b	#$80,d0                          ; [ora #$80]
	;PUSH_SR
	;GET_ADDRESS	$46                    ; [sta $46]
	move.b	d0,$00ff0046                      ; [...]
	;POP_SR
l_26ff:
	rts                                    	; [rts]
	
l_2700:
	;GET_ADDRESS	$45                    ; [lda $45]
	move.b	$00ff0045,d0                    ; [...]
	bmi	l_26ff                             	; [bmi l_26ff]
	and.b	#$03,d0                         ; [and #$03]
	cmp.b	#$01,d0                         ; [cmp #$01]
	beq	l_26ff                             	; [beq l_26ff]
	;GET_ADDRESS	$45                    ; [lda $45]
	move.b	$00ff0045,d0                    ; [...]
	and.b	#$fc,d0                         ; [and #$fc]
	or.b	#$81,d0                          ; [ora #$81]
	;PUSH_SR
	;GET_ADDRESS	$46                    ; [sta $46]
	move.b	d0,$00ff0046                    ; [...]
	;POP_SR
	rts                                    	; [rts]

l_2713:
	;GET_ADDRESS	$46                    ; [lda $46]
	move.b	$00ff0046,d0                    ; [...]
	bpl	l_2774                             	; [bpl l_2774]
	;GET_ADDRESS	$45                    ; [lda $45]
	move.b	$00ff0045,d0                    ; [...]
	and.b	#$04,d0                         ; [and #$04]
	beq	l_2757                             	; [beq l_2757]
	;GET_ADDRESS	$45                    ; [lda $45]
	move.b	$00ff0045,d0                    ; [...]
	asl.b	#1,d0                            ; [asl a]
	
l_2720:
	;asl.b	#1,d0                            	; [asl a]
	;asl.b	#1,d0                            	; [asl a]
	asl.b	#2,d0
	and.b	#$18,d0                         	; [and #$18]
	;PUSH_SR
	;GET_ADDRESS	$0f                       ; [sta $0f]
	move.b	d0,$00ff000f                         ; [...]
	;POP_SR
	;GET_ADDRESS	$46                       ; [lda $46]
	move.b	$00ff0046,d0                       ; [...]
	and.b	#$07,d0                         	; [and #$07]
	;GET_ADDRESS	$0f                       ; [ora $0f]
	or.b	$00ff000f,d0                       ; [...]
	move.b	d0,d1                           	; [tax]
	;GET_ADDRESS	$3266                     ; [lda $3266,x]
	lea l_3266,a0
	rol.b #2,d1
	move.l	(a0,d1.w),$00ff0442				; use 0x00ff0442.

	;PUSH_SR
	;GET_ADDRESS	$42                       ; [sta $42]
	;move.b	d0,$00ff0042                      ; [...]
	
	; not needed, using 32 bit addresses
	;POP_SR
	;GET_ADDRESS	$327c                     ; [lda $327c,x]
	;move.b	(a0,d1.w),d0                    	; [...]
	;PUSH_SR
	;GET_ADDRESS	$43                       ; [sta $43]
	;move.b	d0,$00ff0043                       ; [...]
	;POP_SR


l_2737:
	clr.b	d2                               	; [ldy #$00]
	GET_ADDRESS_Y	$42                     	; [lda ($42),y]
	move.b	(a0,d2.w),d0                    	; [...]
	;PUSH_SR
	;GET_ADDRESS	$44                       ; [sta $44]
	move.b	d0,$00ff0044                       ; [...]
	;POP_SR
	move.b	d0,d2                           	; [tay]
	addq.b	#1,d2                           	; [iny]
	GET_ADDRESS_Y	$42                     	; [lda ($42),y]
	move.b	(a0,d2.w),d0                    	; [...]
	;PUSH_SR
	;GET_ADDRESS	$47                       ; [sta $47]
	move.b	d0,$00ff0047                        ; [...]
	;POP_SR
	bne	l_2749                           		; [bne l_2749]
	;GET_ADDRESS	$3f                       ; [lda $3f]
	move.b	$00ff003f,d0                         	; [...]
	bne	l_274e                           		; [bne l_274e]

l_2749:
	addq.b	#1,d2                           	; [iny]
	GET_ADDRESS_Y	$42                     	; [lda ($42),y]
	move.b	(a0,d2.w),d0                    	; [...]
	;PUSH_SR
	;GET_ADDRESS	$3f                       ; [sta $3f]
	move.b	d0,$00ff003f                       ; [...]
	;POP_SR
	
l_274e:
	;GET_ADDRESS	$46                       ; [lda $46]
	move.b	$00ff0046,d0                        ; [...]
	;PUSH_SR
	;GET_ADDRESS	$45                       ; [sta $45]
	move.b	d0,$00ff0045                       ; [...]
	;POP_SR
	clr.b	d0                               	; [lda #$00]
	;PUSH_SR
	;GET_ADDRESS	$46                       ; [sta $46]
	move.b	d0,$00ff0046                       ; [...]
	;POP_SR
	rts                                    		; [rts]
l_2757:	
	;GET_ADDRESS	$45                       ; [lda $45]
	move.b	$00ff0045,d0                       ; [...]
	;asl.b	#1,d0                            	; [asl a]
	;asl.b	#1,d0                            	; [asl a]
	;asl.b	#1,d0                            	; [asl a]
	asl.b	#3,d0
	and.b	#$18,d0                         	; [and #$18]
	;PUSH_SR
	;GET_ADDRESS	$0f                       ; [sta $0f]
	move.b	d0,$00ff000f                       ; [...]
	;POP_SR
	;GET_ADDRESS	$46                       ; [lda $46]
	move.b	$00ff0046,d0                       ; [...]
	and.b	#$07,d0                         	; [and #$07]
	;GET_ADDRESS	$0f                       ; [ora $0f]
	or.b	$00ff000f,d0                       ; [...]
	move.b	d0,d1                           	; [tax]
	;GET_ADDRESS	$3292                     ; [lda $3292,x]
	lea l_3292,a0
	rol.b #2,d1
	move.l	(a0,d1.w),$00ff0442
	
	;move.b	(a0,d1.w),d0                    	; [...]
	;PUSH_SR
	;GET_ADDRESS	$42                       ; [sta $42]
	;move.b	d0,(a0)                         	; [...]
	;POP_SR
	;GET_ADDRESS	$32a4                     ; [lda $32a4,x]
	;move.b	(a0,d1.w),d0                    	; [...]
	;PUSH_SR
	;GET_ADDRESS	$43                       ; [sta $43]
	;move.b	d0,(a0)                         	; [...]
	;POP_SR
	jmp	l_2737                             		; [jmp l_2737]
	
l_2774:

l_292f:
	;GET_ADDRESS	$48                   ; [lda $48]
	move.b	$00ff0048,d0                   ; [...]
	bmi	l_2954                             	; [bmi l_2954]
	beq	l_2943                             	; [beq l_2943]
l_2935:
	move.b	#$07,d0                        	; [lda #$07]
	;PUSH_SR
	;GET_ADDRESS	$49                   ; [sta $49]
	move.b	d0,$00ff0049                   ; [...]
	;POP_SR
	;GET_ADDRESS	$18                   ; [lda $18]
	move.b	$00ff0018,d0                   ; [...]
	bne	l_2942                             	; [bne l_2942]
	;PUSH_SR
	;GET_ADDRESS	$48                   ; [sta $48]
	move.b	d0,$00ff0048                   ; [...]
	;POP_SR
	bsr.w	l_2959                          ; [jsr l_2959]
l_2942:
	rts                                    	; [rts]
	
l_2943:
	;GET_ADDRESS	$18                   ; [lda $18]
	move.b	$00ff0018,d0                   ; [...]
	beq	l_294d                             	; [beq l_294d]
	;GET_ADDRESS	$48                   ; [inc $48]
	addq.b	#1,$00ff0048                    ; [...]
	bsr.w	l_2959                          ; [jsr l_2959]
	rts                                    	; [rts]
l_294d:
	;GET_ADDRESS	$49                   ; [lda $49]
	move.b	$00ff0049,d0                   ; [...]
	bmi	l_2942                             	; [bmi l_2942]
	;GET_ADDRESS	$49                   ; [dec $49]
	subq.b	#1,$00ff0049                   ; [...]
	rts                                    	; [rts]	
	
l_2954:
	and.b	#$7f,d0                         ; [and #$7f]
	;PUSH_SR
	;GET_ADDRESS	$48                    ; [sta $48]
	move.b	d0,$00ff0048                   ; [...]
	;POP_SR
	rts                                    	; [rts]
	
l_2959:
	;GET_ADDRESS	$48                       	; [lda $48]
	move.b	$00ff0048,d0                         	; [...]
	or.b	#$80,d0                          	; [ora #$80]
	;PUSH_SR
	;GET_ADDRESS	$48                       	; [sta $48]
	move.b	d0,$00ff0048                         	; [...]
	;POP_SR
	;GET_ADDRESS	$40                       	; [ldx $40]
	move.b	$00ff0040,d1                         	; [...]
	;GET_ADDRESS	$3373                     	; [lda $3373,x]
	lea l_3372+1,a0
	move.b	(a0,d1.w),d0                    	; [...]
	beq	l_2993                             	; [beq l_2993]
	CLR_XC_FLAGS                           	; [clc]
	;GET_ADDRESS	$33                       	; [adc $33]
	move.b	$00ff0033,d4					;	addx.b	(a0),d0 
	addx.b	d4,d0                         	; [...]
	SET_XC_FLAGS                           	; [sec]
	SBC_IMM	$62                           	; [sbc #$62]
	;PUSH_SR
	;GET_ADDRESS	$0f                       ; [sta $0f]
	move.b	d0,$00ff000f                         ; [...]
	;POP_SR
	clr.b	d1                               	; [ldx #$00]
	bsr.w	l_2994                            	; [jsr l_2994]
	bcs	l_2993                             	; [bcs l_2993]
	;PUSH_SR
	;GET_ADDRESS	$10                       	; [stx $10]
	move.b	d1,$00ff0010                         	; [...]
	;POP_SR
	bsr.w	l_29a1                            	; [jsr l_29a1]
	;GET_ADDRESS	$40                       	; [ldx $40]
	move.b	$00ff0040,d1                         	; [...]
	;GET_ADDRESS	$33a1                     	; [lda $33a1,x]
	lea l_33a1,a0
	move.b	(a0,d1.w),d0                    	; [...]
	beq	l_2993                             	; [beq l_2993]
	CLR_XC_FLAGS                           	; [clc]
	;GET_ADDRESS	$33                       	; [adc $33]
	move.b	$00ff0033,d4							;	addx.b	(a0),d0 
	addx.b	d4,d0                         	; [...]
	SET_XC_FLAGS                           	; [sec]
	SBC_IMM	$62                           	; [sbc #$62]
	;PUSH_SR
	;GET_ADDRESS	$0f                       ; [sta $0f]
	move.b	d0,$00ff000f                        ; [...]
	;POP_SR
	;GET_ADDRESS	$10                       ; [ldx $10]
	move.b	$00ff0010,d1                      ; [...]
	bsr.w	l_2994                            	; [jsr l_2994]
	bcs	l_2993                             	; [bcs l_2993]
	bsr.w	l_29a1                            	; [jsr l_29a1]
	
l_2993:
	rts                                    	; [rts]
	
l_2994:
	;GET_ADDRESS	$a460                    ; [lda $a460,x]
	lea $00ffa460,a0
	move.b	(a0,d1.w),d0                    	; [...]
	beq	l_299f                             	; [beq l_299f]
	addq.b	#1,d1                           	; [inx]
	cmp.b	#$06,d1                         	; [cpx #$06]
	bcs	l_2994                             	; [bcc l_2994]
	rts                                    	; [rts]

l_299f:
	CLR_XC_FLAGS                           	; [clc]
	rts                                    	; [rts]
	
l_29a1:
	move.b	#$09,d0                        	; [lda #$09]
	;PUSH_SR
	;GET_ADDRESS	$91                     ; [sta $91]
	move.b	d0,$00ff0091                     ; [...]
	;POP_SR
	move.b	#$02,d0                        	; [lda #$02]
	;GET_ADDRESS	$2e                      ; [ldy $2e]
	move.b	$00ff002e,d2                       ; [...]
	beq	l_29df                             	; [beq l_29df]
	bmi	l_29df                             	; [bmi l_29df]
	move.b	#$fe,d0                        	; [lda #$fe]
	;PUSH_SR
	;GET_ADDRESS	$a460                  ; [sta $a460,x]
	lea $00ffa460,a0
    move.b	d0,(a0,d1.w)                 	; [...]
	;POP_SR
	;GET_ADDRESS	$52                     ; [lda $52]
	move.b	$00ff0052,d0                     ; [...]
	;PUSH_SR
	;GET_ADDRESS	$a430                   ; [sta $a430,x]
	lea $00ffa430,a0
    move.b	d0,(a0,d1.w)                 	; [...]
	;GET_ADDRESS	$12                       ; [sta $12]
	move.b	d0,$00ff0012                      ; [...]
	;POP_SR
	;GET_ADDRESS	$0f                      ; [lda $0f]
	move.b	$00ff000f,d0                      ; [...]
	and.b	#$07,d0                         	; [and #$07]
	cmp.b	#$07,d0                         	; [cmp #$07]
	bne	l_29c3                             	; [bne l_29c3]
	move.b	#$06,d0                        	; [lda #$06]	
	
l_29c3:
	;PUSH_SR
	;GET_ADDRESS	$a470                     	; [sta $a470,x]
	lea $00ffa470,a0
    move.b	d0,(a0,d1.w)                 	; [...]
	;POP_SR
	;GET_ADDRESS	$0f                       	; [lda $0f]
	move.b	$00ff000f,d0                         	; [...]
	;lsr.b	#1,d0                            	; [lsr a]
	;lsr.b	#1,d0                            	; [lsr a]
	lsr.b #2,d0
	and.b	#$fe,d0                         	; [and #$fe]
	;PUSH_SR
	;GET_ADDRESS	$0f                       ; [sta $0f]
	move.b	d0,$00ff000f                        ; [...]
	;POP_SR
	;GET_ADDRESS	$53                       	; [lda $53]
	move.b	$00ff0053,d0                         	; [...]
	and.b	#$01,d0                         	; [and #$01]
	CLR_XC_FLAGS                           	; [clc]
	;GET_ADDRESS	$0f                       	; [adc $0f]
	move.b	(a0),d4								;	addx.b	(a0),d0  
	addx.b	d4,d0                         	; [...]
	move.b	#$82,d4							;	; [adc #$82]
	addx.b	d4,d0                        	; [adc #$82]
	;PUSH_SR
	;GET_ADDRESS	$a440                    ; [sta $a440,x]
	lea $00ffa440,a0
    move.b	d0,(a0,d1.w)                 	; [...]
	;GET_ADDRESS	$13                       	; [sta $13]
	move.b	d0,$00ff0013                         	; [...]
	;POP_SR
	jmp	l_2a0f                             	; [jmp l_2a0f]

l_29df:
	;PUSH_SR
	;GET_ADDRESS	$a460                  ; [sta $a460,x]
	lea $00ffa460,a0
    move.b	d0,(a0,d1.w)                 	; [...]
	;POP_SR
	CLR_XC_FLAGS                           ; [clc]
	;GET_ADDRESS	$52                   ; [adc $52]
	move.b	$00ff0052,d4					;	addx.b	(a0),d0	
	addx.b	d4,d0                         	; [...]
	;PUSH_SR
	;GET_ADDRESS	$a430                   ; [sta $a430,x]
	lea $00ffa430,a0
    move.b	d0,(a0,d1.w)                 	; [...]
	;GET_ADDRESS	$12                    ; sta $12]
	move.b	d0,$00ff0012                    ; [...]
	;GET_ADDRESS	$0f                    ; [lda $0f]
	move.b	$00ff000f,d0                    ; [...]
	and.b	#$07,d0                         	; [and #$07]
	cmp.b	#$07,d0                         	; [cmp #$07]
	bne	l_29f5                             	; [bne l_29f5]
	move.b	#$06,d0                        	; [lda #$06]	
	
l_29f5:
	;PUSH_SR
	;GET_ADDRESS	$a470                  ; [sta $a470,x]
	lea $00ffa470,a0
    move.b	d0,(a0,d1.w)                 	; [...]
	;POP_SR
	;GET_ADDRESS	$0f                     ; [lda $0f]
	move.b	$00ff000f,d0                         ; [...]
	;lsr.b	#1,d0                            ; [lsr a]
	;lsr.b	#1,d0                            ; [lsr a]
	lsr.b #2,d0
	and.b	#$fe,d0                         ; [and #$fe]
	;PUSH_SR
	;GET_ADDRESS	$0f                      ; [sta $0f]
	move.b	d0,$00ff000f                         ; [...]
	;POP_SR
	;GET_ADDRESS	$53                       ; [lda $53]
	move.b	$00ff0053,d0                         ; [...]
	and.b	#$01,d0                         	; [and #$01]
	CLR_XC_FLAGS                           	; [clc]
	;GET_ADDRESS	$0f                       	; [adc $0f]
	move.b	$00ff000f,d4						;	addx.b	(a0),d0
	addx.b	d4,d0                         	; [...]
	;POP_SR                                 	; [plp]
	move.b	#$82,d4							; [adc #$82]
	addx.b	d4,d0                        	; [adc #$82]
	;PUSH_SR
	;GET_ADDRESS	$a440                     ; [sta $a440,x]
	lea $00ffa440,a0
    move.b	d0,(a0,d1.w)                 	; [...]
	;GET_ADDRESS	$13                       ; [sta $13]
	move.b	d0,$00ff0013                         ; [...]
	;POP_SR
l_2a0f:
	clr.w	d2                               	; [ldy #$00]
	GET_ADDRESS_Y	$12                     	; [lda ($12),y]
	move.b	(a0,d2.w),d0                    	; [...]
	;PUSH_SR
	;GET_ADDRESS	$a450                  ; [sta $a450,x]
	lea $00ffa450,a0
    move.b	d0,(a0,d1.w)                 	; [...]
	;POP_SR
	rts                                    	; [rts]
	
	;====================
	; Bullets generation.
	;====================
	
l_2a17:
	clr.w	d2                               	; [ldy #$00]
	move.w	#$05,d1                        		; [ldx #$05]
	
l_2a1b:
	;GET_ADDRESS	$a460						; [lda $a460,x]
	lea	$00ffa460,a0
	move.b	(a0,d1.w),d0                    	; [...]
	beq	l_2a2f                             		; [beq l_2a2f]
	;GET_ADDRESS	$a430                     ; [lda $a430,x]
	lea	$00ffa430,a0
	move.b	(a0,d1.w),d0                    	; [...]
	;PUSH_SR
	;GET_ADDRESS	 $1c                      ; [sta $1c]
	move.b	d0,$00ff001c                       ; [...]
	;POP_SR
	;GET_ADDRESS	$a440                     ; [lda $a440,x]
	lea $00ffa440,a0
	move.b	(a0,d1.w),d0                    	; [...]
	;PUSH_SR
	;GET_ADDRESS	$1d                       ; [sta $1d]
	move.b	d0,$00ff001d                       ; [...]
	;POP_SR
	;GET_ADDRESS	$a450                     ; [lda $a450,x]
	lea $00ffa450,a0
	move.b	(a0,d1.w),d0                    	; [...]
	;PUSH_SR
	GET_ADDRESS_Y	$1c                     	; [sta ($1c),y]
	move.b	d0,(a0,d2.w)                    	; [...]
	;POP_SR
l_2a2f:
	subq.b	#1,d1                           	; [dex]
	bpl	l_2a1b                             		; [bpl l_2a1b]
	addq.b	#1,d1                           	; [inx]
l_2a33:	
	;GET_ADDRESS	$a460                     ; [lda $a460,x]
	lea $00ffa460,a0
	move.b	(a0,d1.w),d0                    	; [...]
	beq	l_2aa3                             		; [beq l_2aa3]
	bsr.w	l_2ac9                           	; [jsr l_2ac9]
	;PUSH_SR
	;GET_ADDRESS	$a440                     ; [sta $a440,x]
	lea $00ffa440,a0
    move.b	d0,(a0,d1.w)                 		; [...]
	;GET_ADDRESS	$1d                       ; [sta $1d]
	move.b	d0,$00ff001d                       ; [...]
	;POP_SR
	roxr.b	#1,d0                           	; [ror a]
	;GET_ADDRESS	$1c                       ; [lda $1c]
	move.b	$00ff001c,d0                       ; [...]
	roxr.b	#1,d0                           	; [ror a]
	;GET_ADDRESS	$50                       ; [cmp $50]
	cmp.b	$00ff0050,d0                       ; [...]
	bcs	l_2abd									; [bcc l_2abd]
	;GET_ADDRESS	$51							; [cmp $51]
	cmp.b	$00ff0051,d0                       ; [...]
	bcc	l_2abd									; [bcs l_2abd]
	GET_ADDRESS_Y	$1c                     	; [lda ($1c),y]
	move.b	(a0,d2.w),d0                    	; [...]
	bpl	l_2a5e									; [bpl l_2a5e]
	cmp.b	#$90,d0                         	; [cmp #$90]
	bcs	l_2ab9									; [bcc l_2ab9]
	cmp.b	#$a0,d0                         	; [cmp #$a0]
	bcc	l_2a5e									; [bcs l_2a5e]
	bsr.w	l_2ae9                           	; [jsr l_2ae9]
	jmp	l_2abd									; [jmp l_2abd]
	

l_2a5e:
	;PUSH_SR
	;GET_ADDRESS	$a450                     ; [sta $a450,x]
	lea $00ffa450,a0
    move.b	d0,(a0,d1.w)                 		; 0x20
	
	;GET_ADDRESS	$2a8a                     ; [sty $2a8a]
	;move.b	 d2,(a0)                         	; clears high address - 78 = 0.
	lea $00ff7800,a0							; pointer to hold address	of character set 2.						
	move.b d2,2(a0)							; write to high address - clear high to 0
			
	
	asl.b	#1,d0                            	; [asl a]				- 0x40
	;GET_ADDRESS	$2a8a                     ; [rol $2a8a]
	lea $00ff7800,a0
	move.b	2(a0),d4							; roxl.b	#1,(a0)		
	roxl.b	#1,d4                         		; [...]
	move.b	d4,2(a0)							; roxl.b	#1,(a0)		- 0x00
	
	asl.b	#1,d0                            	; [asl a]				- 0x80
	;GET_ADDRESS	$2a8a                     ; [rol $2a8a]
	lea $00ff7800,a0
	move.b	2(a0),d4							; roxl.b	#1,(a0)
	roxl.b	#1,d4                         		; [...]
	move.b	d4,2(a0)							; roxl.b	#1,(a0)		- 0x00
	
	asl.b	#1,d0                            	; [asl a]				- 0x00, carry set
	;GET_ADDRESS	$2a8a                     ; [rol $2a8a]
	lea $00ff7800,a0
	move.b	2(a0),d4							; roxl.b	#1,(a0)
	roxl.b	#1,d4                         		; [...]
	move.b	d4,2(a0)							; roxl.b	#1,(a0)		- 0x01 to 2a8a
	
	;GET_ADDRESS	$2a89                     ; [sta $2a89]
	lea $00ff7800,a0
	move.b	d0,1(a0)                         	; [...]					- 0x00 to 2a89

	;GET_ADDRESS	$2a8a                     ; [lda $2a8a]
	lea $00ff7800,a0							;
	move.b	2(a0),d0                         	; [...]					- load 0x01 to d0
	move.b	#$78,d4								; [adc #$78]			- adds 0x78 = 0x79
	addx.b	d4,d0                        		; [adc #$78]
	
	;GET_ADDRESS	$2a8a                     ; [sta $2a8a]
	lea $00ff7800,a0
	move.b	d0,2(a0)                         	; [...]					- writes 0x79 to high byte
	
	
	;GET_ADDRESS	$3937                     ; [lda $3937,x]
	lea l_3937,a0								
	move.b	(a0,d1.w),d0                    	; [...]	 
	
l_2a7e:
	;or.b	#$80,d0                          	; [ora #$80]			- self modifying.
	or.b	$00ff0180,d0						; arbitrary address 0xff0180
	;GET_ADDRESS	$14                       ; [sta $14]
	move.b	d0,$00ff0014                       ; [...]
	move.b	#$78,d0                        		; [lda #$78]
	;GET_ADDRESS	$15                       ; [sta $15]
	move.b	d0,$00ff0015                       ; [...]
	
	;move.b	#$07,d2                        	; [ldy #$07]
	move.b #31,d2								; each row of 8x8 tiles has 32 bytes of data.
l_2a88:
	
	; clears are for bullets 1 row of pixels at a time.
	;GET_ADDRESS	$7800                     ; [lda $7800,y] - is changed to 7907
												; 32 chars x 8 - 0x100, start index of blank glyph
	;lea vram_addr_tiles+1280*size_tile_b,a0	; 0x7907
	lea vram_addr_tiles+1280*size_tile_b+32*32,a0	- 0xA41F
	add.w d2,a0								; 0x31, start from right to left of row.
	SetVRAMReadReg a0
	move.w	vdp_data,d0
	
	;move.b	(a0,d2.w),d0                    	; [...]
	
	;PUSH_SR
	;GET_ADDRESS_Y	$14                     	; [sta ($14),y]
	;move.b	d0,(a0,d2.w)                    	; makes the change to tile 16 first to blank glyph
	lea vram_addr_tiles+1280*size_tile_b+16*32,a0
	add.w d2,a0
	SetVRAMWriteReg a0
	move.w	d0,vdp_data
	
	
	;POP_SR
	subq.b	#2,d2                           	; [dey] - subtract two since we write a word at a time.
	bpl	l_2a88                             		; [bpl l_2a88]
	jmp *
	
	
	;GET_ADDRESS	$a470                     ; [ldy $a470,x]
	lea $00ffa470,a0
	move.b	(a0,d1.w),d2                    	; [...]
	clr.b	d0                               	; [lda #$00]
	;PUSH_SR
	GET_ADDRESS_Y	$14                     	; [sta ($14),y]
	move.b	d0,(a0,d2.w)                    	; [...]
	;POP_SR
	addq.b	#1,d2                           	; [iny]
	move.b	#$aa,d0                        		; [lda #$aa]
	;PUSH_SR
	GET_ADDRESS_Y	$14                     	; [sta ($14),y]
	move.b	d0,(a0,d2.w)                    	; [...]
	;POP_SR
	clr.b	d2                               	; [ldy #$00]
	move.b	d1,d0                           	; [txa]
	;or.b	#$10,d0                          	; [ora #$10]	- self modifying
	or.b $00ff0181,d0
	;PUSH_SR
	GET_ADDRESS_Y	$1c                     	; [sta ($1c),y]
	move.b	d0,(a0,d2.w)                    	; [...]
	;POP_SR
l_2aa3:
	addq.b	#1,d1                           	; [inx]
	cmp.b	#$06,d1                         	; [cpx #$06]
	bcs	l_2a33                             		; [bcc l_2a33]
	
	;GET_ADDRESS	$2a7f                     ; [lda $2a7f]
	move.b	$00ff0180,d0                       ; [...]
	eor.b	#$80,d0                         	; [eor #$80]  - value of 80 needs to change as well.
	;GET_ADDRESS	$2a7f                     ; [sta $2a7f]
	move.b	d0,$00ff0180                       ; [...]
	;POP_SR
	;GET_ADDRESS	$2aa0                     ; [lda $2aa0] - self modifying.
	
	move.b	$00ff0181,d0                       ; [...]
	eor.b	#$10,d0                         	; [eor #$10]
	;GET_ADDRESS	$2aa0                     ; [sta $2aa0]
	move.b	d0,$00ff0181                       ; [...]
	rts                                    		; [rts]
	

l_2ab9:
	move.b	#$21,d0                        		; [lda #$21]
	PUSH_SR
	;GET_ADDRESS	$91                       ; [sta $91]
	move.b	d0,$00ff0091                       ; [...]
	POP_SR
	
l_2abd:
	;GET_ADDRESS	$a460                     ; [lda $a460,x]
	lea $00ffa460,a0
	move.b	(a0,d1.w),d0                    	; [...]
	beq	l_2aa3                             		; [beq l_2aa3]
	clr.b	d0                               	; [lda #$00]
	PUSH_SR
	;GET_ADDRESS	$a460                     ; [sta $a460,x]
	lea $00ffa460,a0
    move.b	d0,(a0,d1.w)                 		; [...]
	POP_SR
	beq	l_2aa3                             		; [beq l_2aa3]

l_2ac9:
	bmi	l_2ada                             		; [bmi l_2ada]
	CLR_XC_FLAGS                           	; [clc]
	;GET_ADDRESS	$a430                     ; [adc $a430,x]
	lea $00ffa430,a0
	move.b	(a0,d1.w),d4						; addx.b	(a0,d1.w),d0
	addx.b	d4,d0                    	
	PUSH_SR
	;GET_ADDRESS	$a430                     ; [sta $a430,x]
	lea $00ffa430,a0
    move.b	d0,(a0,d1.w)
	;GET_ADDRESS	$1c                       ; [sta $1c]
	move.b	d0,$00ff001c                       ; [...]
	POP_SR
	;GET_ADDRESS	$a440                     ; [lda $a440,x]
	lea $00ffa440,a0
	move.b	(a0,d1.w),d0                    	; [...]
	move.b	#$00,d4								; [adc #$00]
	addx.b	d4,d0                        		; [adc #$00]
	rts                                    		; [rts]
	
l_2ada:
	CLR_XC_FLAGS                           	; [clc]
	;GET_ADDRESS	$a430                     ; [adc $a430,x]
	lea $00ffa430,a0
	move.b	(a0,d1.w),d4						;	addx.b	(a0,d1.w),d0 
	addx.b	d4,d0
	PUSH_SR
	;GET_ADDRESS	$a430                     ; [sta $a430,x]
	lea $00ffa430,a0
    move.b	d0,(a0,d1.w)
	;GET_ADDRESS	$1c							; [sta $1c]
	move.b	d0,$00ff001c						; [...]
	POP_SR
	;GET_ADDRESS	$a440						; [lda $a440,x]
	lea $00ffa440,a0
	move.b	(a0,d1.w),d0                    	; [...]
	move.b	#$ff,d4								; [adc #$ff]
	addx.b	d4,d0                        		; [adc #$ff]
	rts                                    		; [rts]
	
l_2ae9:
	move.b	d0,d2                           	; [tay]
	;GET_ADDRESS	$a430                     ; [lda $a430,x]
	lea $00ffa430,a0
	move.b	(a0,d1.w),d0                    	; [...]
	SET_XC_FLAGS                           	; [sec]
	SBC_Y	l_33c6                          	; [sbc $33c6,y]
	PUSH_SR
	;GET_ADDRESS	$1a                       ; [sta $1a]
	lea $00ff001a,a0
	move.b	d0,(a0)                         	; [...]
	POP_SR
	;GET_ADDRESS	$a440                     ; [lda $a440,x]
	lea $00ffa440,a0
	move.b	(a0,d1.w),d0                    	; [...]
	SBC_Y	l_33d6                           	; [sbc $33d6,y]
	PUSH_SR
	;GET_ADDRESS	$1b                       ; [sta $1b]
	move.b	d0,$00ff001b                       ; [...]
	POP_SR
	GET_ADDRESS	l_33e6                     	; [lda $33e6,y]
	move.b	(a0,d2.w),d0                    	; [...]
	PUSH_SR
	;GET_ADDRESS	$11                       ; [sta $11]
	move.b	d0,$00ff0011                       ; [...]
	;GET_ADDRESS	$8f                       ; [sta $8f]
	move.b	d0,$00ff008f                       ; [...]
	POP_SR
	GET_ADDRESS	l_33f6                    	; [lda $33f6,y]
	move.b	(a0,d2.w),d0                    	; [...]
	move.b	d0,d2                           	; [tay]
	PUSH_SR
	;GET_ADDRESS	$10                       ; [stx $10]
	move.b	d1,$00ff0010                         ; [...]
	POP_SR
	bsr.w	l_19f5                            	; [jsr l_19f5]
	;GET_ADDRESS	$10                       ; [ldx $10]
	move.b	$00ff0010,d1                       ; [...]
	move.b	#$1b,d0                        		; [lda #$1b]
	PUSH_SR
	;GET_ADDRESS	$92                       ; [sta $92]
	move.b	d0,$00ff0092                       ; [...]
	POP_SR
	
l_2b11:
	;GET_ADDRESS	$11                       ; [ldy $11]
	move.b	$00ff0011,d2                       ; [...]
l_2b13:
	GET_ADDRESS_Y	$1a                     	; [lda ($1a),y]
	move.b	(a0,d2.w),d0                    	; [...]
	cmp.b	#$20,d0                         	; [cmp #$20]
	bcs	l_2b33                             		; [bcc l_2b33]
	cmp.b	#$f0,d0                         	; [cmp #$f0]
	bcc	l_2b22                             		; [bcs l_2b22]
	SET_XC_FLAGS                           	; [sec]
	SBC_IMM	 $20                           		; [sbc #$20]
	PUSH_SR
	GET_ADDRESS_Y	$1a                     	; [sta ($1a),y]
	move.b	d0,(a0,d2.w)                    	; [...]
	POP_SR

l_2b22:
	subq.b	#1,d2                           	; [dey]
	bpl	l_2b13                             		; [bpl l_2b13]
	;GET_ADDRESS	$8f                       ; [dec $8f]
	subq.b	#1,$00ff008f                       ; [...]
	bmi	l_2b30                             		; [bmi l_2b30]
	;GET_ADDRESS	$1b                       ; [inc $1b]
	;addq.b	#1,(a0)                         	; [...]
	;GET_ADDRESS	$1b                       ; [inc $1b]
	;addq.b	#1,(a0)                         	; [...]
	addq.b #2,$00ff001b
	jmp	l_2b11                             		; [jmp l_2b11]
	
l_2b30:
	clr.b	d2                               	; [ldy #$00]
	rts                                    		; [rts]
l_2b33:
	PUSH_SR
	;GET_ADDRESS	$10                       ; [stx $10]
	move.b	d1,$00ff0010                       ; [...]
	POP_SR
	move.b	d0,d1                           	; [tax]
	clr.b	d0                               	; [lda #$00]
	PUSH_SR
	;GET_ADDRESS	$a460                     ; [sta $a460,x]
	lea $00ffa460,a0
    move.b	d0,(a0,d1.w)                 		; [...]
	POP_SR
	;GET_ADDRESS	$10                       ; [ldx $10]
	move.b	$00ff0010,d1                       ; [...]
	jmp	l_2b22                             		; [jmp l_2b22]
	
l_2b40:
	;GET_ADDRESS	$2e                       ; [lda $2e]
	move.b	$00ff002e,d0                       ; [...]
	beq	l_2b53                             		; [beq l_2b53]
	bpl	l_2b5d                             		; [bpl l_2b5d]
	;GET_ADDRESS	$29                       ; [lda $29]
	move.b	$00ff0029,d0                       ; [...]
	SET_XC_FLAGS                           	; [sec]
	;GET_ADDRESS	$2e                       ; [sbc $2e]
	SBC	$00ff002e,d0    
	;PUSH_SR
	;GET_ADDRESS	$29							; [sta $29]
	move.b	d0,$00ff0029						; [...]
	;POP_SR
	;GET_ADDRESS	$2a							; [lda $2a]
	move.b	$00ff002a,d0						; [...]
	SBC_IMM	 $ff                           		; [sbc #$ff]
	;PUSH_SR
	;GET_ADDRESS	$2a							; [sta $2a]
	move.b	d0,$00ff002a						; [...]
	;POP_SR


l_2b53:
	move.b	#$08,d0                        		; [lda #$08]
	SET_XC_FLAGS                           	; [sec]
	;GET_ADDRESS	$29                       ; [sbc $29]
	SBC	$00ff0029,d0   
	and.b	#$07,d0                         	; [and #$07]
	;PUSH_SR
	;GET_ADDRESS	$2c                       ; [sta $2c]
	move.b	d0,$00ff002C                       ; [...]
	;POP_SR
	rts                                    		; [rts]

l_2b5d:
	;GET_ADDRESS	$29                       ; [lda $29]
	move.b	$00ff0029,d0                       ; [...]
	SET_XC_FLAGS                           	; [sec]
	;GET_ADDRESS	$2e                       ; [sbc $2e]
	SBC	$00ff002e,d0   
	;PUSH_SR
	;GET_ADDRESS	$29                       ; [sta $29]
	move.b	d0,$00ff0029                       ; [...]
	;POP_SR
	;GET_ADDRESS	$2a                       ; [lda $2a]
	move.b	$00ff002a,d0                       ; [...]
	SBC_IMM	 $00                           		; [sbc #$00]
	;PUSH_SR
	;GET_ADDRESS	$2a                       ; [sta $2a]
	move.b	d0,$00ff002a                       ; [...]
	;POP_SR
	jmp	l_2b53                             		; [jmp l_2b53]

l_2bbe:
	rts
	
l_2beb:
	;GET_ADDRESS	$29							; [lda $29]
	move.b	$00ff0029,d0                       ; [...]
												; [clc]
												
												
	add.b	#$07,d0                        		; [adc #$07]
	;PUSH_SR
	;GET_ADDRESS	$31                       ; [sta $31]
	move.b	d0,$00ff0031                       ; [...]
	;POP_SR
	;GET_ADDRESS	$2a                       ; [lda $2a]
	move.b	$00ff002a,d0                       ; [...]
	move.b	#$00,d4								; addx.b	#$00,d0         ; [adc #$00]
	addx.b	d4,d0                        		; [adc #$00]
	lsr.b	#1,d0                            	; [lsr a]
	;GET_ADDRESS	$31                       ; [ror $31]
	move.b	$00ff0031,d4						; roxr.b	#1,(a0)         ; [...]
	roxr.b	#1,d4                         		; [...]
	;PUSH_SR
	move.b	d4,$00ff0031						; roxr.b	#1,(a0)         ; [...]
	;POP_SR
	lsr.b	#1,d0                            	; [lsr a]
	;GET_ADDRESS	$31                       ; [ror $31]
	move.b	$00ff0031,d4						; roxr.b	#1,(a0)         ; [...]
	roxr.b	#1,d4                         		; [...]
	;PUSH_SR
	move.b	d4,$00ff0031						; roxr.b	#1,(a0)
	;POP_SR
	lsr.b	#1,d0                            	; [lsr a]
	;GET_ADDRESS	$31                       ; [ror $31]
	move.b	$00ff0031,d4						; roxr.b	#1,(a0)            
	roxr.b	#1,d4                         		; [...]
	;PUSH_SR
	move.b	d4,$00ff0031						; roxr.b	#1,(a0) ; [...]
	;POP_SR
	and.b	#$01,d0                         	; [and #$01]
	;PUSH_SR
	;GET_ADDRESS	$0f                       ; [sta $0f]
	move.b	d0,$00ff000f                       ; [...]
	;POP_SR
	
	; Scroll look up table start
	move.b	#$82,d0								; [lda #$82]
	;GET_ADDRESS	$0f							; [ora $0f]
	or.b $00ff000f,d0                          ; [...]
	
	;GET_ADDRESS	$30							; [sta $30]
	move.b	d0,$00ff0030                       ; [...]
	
	; use pointers to ram to handle self modifying code
	;GET_ADDRESS	l_2c1f+2					; [sta $2c21] , high byte address of 0x8200
	;move.b	d0,(a0)                         	; [...]
	move.b	d0,$00ff0108						; low byte in
	;GET_ADDRESS	$31                       ; [lda $31]
	move.b	$00ff0031,d0                       ; [...]
	move.b	d0,$00ff0109                       ; [sta $2c20] , high byte address of 0x8200
	
												; [lda #$48]  , use vram address on sega
	move.b	#$c3,$00ff0104						; [sta $2c24] , low byte address of 0x48f0
												; [lda #$f0],
	move.b	#$00,$00ff0105                     ; [sta $2c23] , high byte address of 0x48f0
	move.w	#$11,d1                        		; [ldx #$11]  ; 17 rows of playfield to render
	move.w	#$0500,d0							; Tile bank 3
	
	
l_2c1d:
	move.w	#$26,d6                       		; [ldy #$26] 	 ; index into tile data
	move.w	#$4c,d2 							; this index is used for write to vram
l_2c1f:   
	; [lda $8200,y]  tile data - use ram address pointer ; 
	move.w  $00ff0108,d3           			; Load the 16-bit address (high and low bytes) into d3
	or.l    #$00ff0000,d3          			; Convert to RAM address
	move.l  d3,a0
	move.b  (a0,d6.w),d0           			; Get the tile data from table
	
	; row address for vram
	; 1		c300 
	; 2		c340
	; 3		c380
	; 4		c3c0
	; 5		c400
	; 6		c440
	; 7		c480
	; 8		c4c0
	; 9		c500
	; a		c540
	; b		c580
	; c		c5c0
	; d		c600
	; e		c640
	; f		c680
	; 10	c6c0
	; 11	c700
	
	
	;move.w  $ff0104,d5    					; Load the 16-bit address from $FF0104 (low byte) and $FF0105 (high byte)
    ;move.l  d5,a1         					; Move the resulting 32-bit address to a1
	;add.w d2,a1
	move.l  $00ff0102,a1    					; Optimized variation of the above, move a lw from 0xff0102 since upper word is 0
	add.w d2,a1
	
	SetVRAMWriteReg a1
	move.w d0,vdp_data							; [sta $48f0,y]  render playfield
	
	subq.b	#1,d6								; used to index tile data ( 0x8200 / 0xff8200 )
	subq.b	#2,d2                           	; [dey]	 - 2 bytes per character in table.
	bpl	l_2c1f                             		; [bpl l_2c1f]	
	subq.b	#1,d1                           	; [dex]
	beq	l_2c42                             		; [beq l_2c42]
								
	addq.b	#2,$00ff0108						; [inc $2c21] x 2

	move.w $00ff0104,d5
	add.w #$80,d5								; [adc #$28] next row
	move.w	d5,$ff0104
	jmp	l_2c1d                                 ; [jmp l_2c1d]
	
l_2c42:
	;GET_ADDRESS	$31                       ; [lda $31]
	move.b	$00ff0031,d0                       ; [...]
												; [clc]
	add.b	#$12,d0                        		; [adc #$12]
	;PUSH_SR
	;GET_ADDRESS	$52                       ; [sta $52]
	move.b	d0,$00ff0052                       ; [...]
	;GET_ADDRESS	$33                       ; [lda $33]
	move.b	$00ff0033,d0                       ; [...]
	SET_XC_FLAGS                           	; [sec]
	SBC_IMM	 $58                           		; [sbc #$58]
	and.b	#$f8,d0                         	; [and #$f8]
	lsr.b	#2,d0
	;POP_SR                                 	; [plp]
	;GET_ADDRESS	$30                       ; [adc $30]
	move.b	$00ff0030,d4						; addx.b (a0),d0
	addx.b	d4,d0                         		; [...]
	;PUSH_SR
	;GET_ADDRESS	$53                       ; [sta $53]
	move.b	d0,$00ff0053                       ; [...]
	;POP_SR
	;GET_ADDRESS	$30                       ; [lda $30]
	move.b	$00ff0030,d0                       ; [...]
	roxr.b	#1,d0                           	; [ror a]
	;GET_ADDRESS	$31                       ; [lda $31]
	move.b	$00ff0031,d0                       ; [...]
	roxr.b	#1,d0                           	; [ror a]
	;PUSH_SR
	;GET_ADDRESS	$50                       ; [sta $50]
	move.b	d0,$00ff0050                       ; [...]
	;POP_SR
												; [clc]
	add.b	#$14,d0                        		; [adc #$14]
	;PUSH_SR
	;GET_ADDRESS	$51                       ; [sta $51]
	move.b	d0,$00ff0051                       ; [...]
	;POP_SR
	rts                                    		; [rts]

l_2c66:
	;clr.w	d1                               ; [ldx #$00]
	move.w	#$20,d1								; address table at e050 uses 32 bit addresses so need to move 20 bytes further down 
	move.w	#$e1,d2                        		; [ldy #$e1]
	;PUSH_SR
	;GET_ADDRESS	$1a                       ; [stx $1a]
	move.b	d1,$00ff001a                       ; [...]
	;GET_ADDRESS	$1b                       ; [sty $1b]
	move.b	d2,$00ff001b                       ; [...]
	;POP_SR
	move.w	#$01,d1                        		; [ldx #$01]

l_2c70:
	clr.w	d2                               	; [ldy #$00]
	;PUSH_SR
	;GET_ADDRESS	$11                       ; [sty $11]
	move.b	d2,$00ff0011                       ; [...]
	;POP_SR
	;GET_ADDRESS	$1a                       ; [lda $1a]
	move.b	$00ff001a,d0                       ; [...]
	
	; create address table low
	;PUSH_SR
	;GET_ADDRESS	$a400                     ; [sta $a400,x]
	lea $00ffa400,a0
    move.b	d0,(a0,d1.w)                 		; [...]
	;POP_SR
	;GET_ADDRESS	$1b                       ; [lda $1b]
	move.b	$00ff001b,d0
	
	; create address table high
	;PUSH_SR
	;GET_ADDRESS	$a500                     ; [sta $a500,x]
	lea $ffa500,a0
    move.b	d0,(a0,d1.w)                 		; [...]
	;POP_SR
	addq.b	#1,d1                           	; [inx]
	beq	l_2ca4                             		; [beq l_2ca4]
	GET_ADDRESS_Y	$1a                     	; [lda ($1a),y]

	move.b	(a0,d2.w),d0                    	; [...]
	beq	l_2ca4                             		; [beq l_2ca4]
	;PUSH_SR
	;GET_ADDRESS	$8f                       ; [sta $8f]
	move.b	d0,$00ff008f                       ; [...]
	;POP_SR
	;GET_ADDRESS	$11                       ; [inc $11]
	addq.b	#1,$00ff0011                       ; [...]
l_2c89:
	;GET_ADDRESS	$11                       ; [ldy $11]
	move.b	$00ff0011,d2						; [...]
	GET_ADDRESS_Y	$1a                     	; [lda ($1a),y]
	move.b	(a0,d2.w),d0                    	; [...]
	SET_XC_FLAGS                           	; [sec]
	;GET_ADDRESS	$11							; [adc $11]
	move.b	$00ff0011,d4						; addx.b	(a0),d0
	addx.b	d4,d0                         		; [...]
	;PUSH_SR
	;GET_ADDRESS	$11                       ; [sta $11]
	move.b	d0,$00ff0011                       ; [...]
	;POP_SR
	;GET_ADDRESS	$8f                       ; [dec $8f]
	subq.b	#1,$00ff008f                       ; [...]
	bne	l_2c89                             	; [bne l_2c89]
	;GET_ADDRESS	$1a                       ; [lda $1a]
	move.b	$00ff001a,d0                         	; [...]
	CLR_XC_FLAGS                           	; [clc]
	;GET_ADDRESS	$11                       	; [adc $11]
	move.b	$00ff0011,d4								;	addx.b	(a0),d0 
	addx.b	d4,d0                         	; [...]
	PUSH_SR
	;GET_ADDRESS	$1a                       	; [sta $1a]
	move.b	d0,$00ff001a                         	; [...]
	POP_SR
	bcc	l_2c70                             	; [bcc l_2c70]
	;GET_ADDRESS	$1b                       ; [inc $1b]
	addq.b	#1,$00ff001b                         	; [...]
	jmp	l_2c70                             	; [jmp l_2c70

l_2ca4:
	rts
	;===================
	; Clear A400 to A4ff
	; "" A500 to A5ff
	;===================
l_2ca5:
	clr.w	d0                               	; [lda #$00]
	move.w	d0,d2                           	; [tay]
l_2ca8:
	PUSH_SR
	;GET_ADDRESS	$a400                     ; [sta $a400,y]
	lea $ffa400,a0
	move.b	d0,(a0,d2.w)                 	; [...]
	;GET_ADDRESS	$a500                     	; [sta $a500,y]
	lea $ffa500,a0
    move.b	d0,(a0,d2.w)                 	; [...]
	POP_SR
	addq.b	#1,d2                           	; [iny]
	bne	l_2ca8                             	; [bne l_2ca8]
	rts                                    	; [rts]
	

l_2cb2:
	move.b #$ff,d0                             ; [lda #$ff]
	PUSH_SR
	GET_ADDRESS	$54                       	; [sta $54]
	move.b	d0,(a0)                         	; [...]
	POP_SR
	GET_ADDRESS	$26                       	; [lda $26]
	move.b	(a0),d0                         	; [...]
	and.b	#$0f,d0                         	; [and #$0f]
	move.b	d0,d2                           	; [tay]
	;GET_ADDRESS	$e010                     ; [lda $e010,y]
	lea $ffe010,a0
	move.b	(a0,d2.w),d0                    	; [...]
	PUSH_SR
	GET_ADDRESS	$12                       	; [sta $12]
	move.b	d0,(a0)                         	; [...]
	POP_SR
	;GET_ADDRESS	$e020                     ; [lda $e020,y]
	lea $ffe020,a0
	move.b	(a0,d2.w),d0                    	; [...]
	PUSH_SR
	GET_ADDRESS	$13                       	; [sta $13]
	move.b	d0,(a0)                         	; [...]
	POP_SR
	move.b	#$a2,d0                        	; [lda #$a2]
	PUSH_SR
	GET_ADDRESS	$15                       	; [sta $15]
	move.b	d0,(a0)                         	; [...]
	POP_SR
	clr.b	d0                               	; [lda #$00]
	PUSH_SR
	GET_ADDRESS	$14                       	; [sta $14]
	move.b	d0,(a0)                         	; [...]
	POP_SR

	;====================
	;Clears the playfield
	;Prior to scrolling.
	;====================
l_2ccd: ; 0x341a
	move.w	#$3f,d2                        		; [ldy #$3f]
	move.b	#$20,d0                        		; [lda #$20] - blank tile.
l_2cd1:
	;PUSH_SR
	GET_ADDRESS_Y	$14                     	; [sta ($14),y]
	move.b	d0,(a0,d2.w)                    	; [...] 
	;POP_SR
	subq.b	#1,d2                           	; [dey]
	bpl	l_2cd1                             		; [bpl l_2cd1]
	;GET_ADDRESS	$15                       ; [dec $15]
	;subq.b	#1,(a0)                         	; [...]
	;GET_ADDRESS	$15                       ; [dec $15]
	;subq.b	#1,(a0)                         	; [...]
	subq.b #2,$00ff0015
	;GET_ADDRESS	$15                       ; [lda $15]
	move.b	$00ff0015,d0						; [...]
	cmp.b	#$82,d0                         	; [cmp #$82]
	bcc	l_2ccd                             		; [bcs l_2ccd]
	
	move.b	#$40,d1                        		; [ldx #$40]
	move.b	#$a2,d2                        		; [ldy #$a2]
	;PUSH_SR
	;GET_ADDRESS	$14                       ; [stx $14]
	move.b	d1,$00ff0014                       ; [...]
	;GET_ADDRESS	$15                       ; [sty $15]
	move.b	d2,$00ff0015                       ; [...]
	;POP_SR
	
	;===============================
	;Gets addr pointers to char data
	;structs created previously
	;===============================

l_2ce8:
	clr.w	d2                               	; [ldy #$00]
	GET_ADDRESS_Y	$12                     	; [lda ($12),y] ; 0x8010 on c64
	move.b	(a0,d2.w),d0                    	; [...]			 ; get index - 0x3e
	beq	l_2d57                             		; [beq l_2d57]	 ; are we done copying data ? - bp addr 0x13c0

	move.b	d0,d1                           	; [tax]		     ; index
	;GET_ADDRESS	$ffa500						; [lda $a500,x] ; into 0xa500
	lea $00ffa500,a0
	move.b	(a0,d1.w),d0                    	; [...]
	;PUSH_SR
	;GET_ADDRESS	$1b                       ; [sta $1b]
	move.b	d0,$00ff001b                       ; [...]
	;POP_SR
	;GET_ADDRESS	$ffa400						; [lda $a400,x]
	lea $00ffa400,a0
	move.b	(a0,d1.w),d0                    	; [...]
	;PUSH_SR
	;GET_ADDRESS	$1a                       ; [sta $1a]
	move.b	d0,$00ff001a                       ; [...]
	;POP_SR
	CLR_XC_FLAGS                           	; [clc]
	;GET_ADDRESS	$12                       ; [lda $12]
	move.b	$00ff0012,d0                       ; [...]
	move.b	#$01,d4								; addx.b	#$01,d0   ; [adc #$01]
	addx.b	d4,d0                        		; [adc #$01]
	;PUSH_SR
	;GET_ADDRESS	$12                       ; [sta $12]
	move.b	d0,$00ff0012                       ; [...]
	;POP_SR
	bcc	l_2d04                             		; [bcc l_2d04]
	;GET_ADDRESS	$13                       ; [inc $13]
	addq.b	#1,$00ff0013                       ; [...]
l_2d04:
	GET_ADDRESS_Y	$1a                     	; [lda ($1a),y] ;Number of columns of items in struct.
	move.b	(a0,d2.w),d0                    	; [...]
	addq.b	#1,d2                           	; [iny]
	;PUSH_SR
	;GET_ADDRESS	$8f                       ; [sta $8f]
	move.b	d0,$00ff008f                       ; [...]
	;POP_SR
l_2d09:
	;GET_ADDRESS	$14                       ; [lda $14]
	move.b	$00ff0014,d0                       ; [...]
	;PUSH_SR
	;GET_ADDRESS	$1c                       ; [sta $1c]
	move.b	d0,$00ff001c                       ; [...]
	;POP_SR
	;GET_ADDRESS	$15                       ; [lda $15]
	move.b	$00ff0015,d0                       ; [...]
	;PUSH_SR
	;GET_ADDRESS	$1d                       ; [sta $1d]
	move.b	d0,$00ff001d                       ; [...]
	;POP_SR
	GET_ADDRESS_Y	$1a                     	; [lda ($1a),y]
	move.b	(a0,d2.w),d0                    	; [...]
	addq.b	#1,d2                           	; [iny]
	and.b	#$1f,d0                         	; [and #$1f]
	
	;when x/d0 = 8 or any other number, this is the start row index for scroll text.
	;Dreadnought can be any width so X determines this
	move.b	d0,d1                           	; [tax]


	;======================================================	
	;Tiles for the large scroll text and also the main ship
	;======================================================

	;=====================================================		
	;Below data for U letter in Uridium.
	;Starts from the left, bottom tile first.
	;1 column has 8 rows.

	;Some of the data for the U
	;0x30,0x22,0x22,0x22,0x22,0x22,0x22,0x23 
	;to A240,A040,9E40,9C40,9A40,9840,9640,9440

	;0x32,0x25,0x25,0x25,0x25,0x25,0x25,0x26
	;.. A241,A041,9E41,9C41,9A41,9841,9641,9441

	;0x24,0x25,0x25,0x25,0x25,0x25,0x25,0x26
	;.. A242,A042,9E42,9C42,9A42,9842,9642,9442

	;       _ 
	;0x9440	|  <- row 12 - 0x23
	;0x9640	|  <- row 13 - 0x22
	;0x9840	|  <- row 14 - 0x22
	;0x9a40	|  <- row 15 - 0x22
	;0x9c40	|  <- row 16 - 0x22
	;0x9e40	|  <- row 17 - 0x22
	;0xa040	|  <- row 18 - 0x22
	;0xa240	 ` <- row 19 - 0x30

	;============================
	;Data for dreadnought - Gold.
	;============================

	;Some of the data for the Dreadnought
	;0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x20
	;A240,A040,9E40,9C40,9A40,9840,9640,9440

	;0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x20
	;.. A241,A041,9E41,9C41,9A41,9841,9641,9441

	;0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x20
	;.. A242,A042,9E42,9C42,9A42,9842,9642,9442

	;0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x20 
	;.. A243,A043,9E43,9C43,9A43,9843,9643,9443

	;0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x20 
	;.. A244,A044,9E44,9C44,9A44,9844,9644,9444

	;0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x20 
	;.. A245,A045,9E45,9C45,9A45,9845,9645,9445

	;0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x20 
	;.. A246,A046,9E46,9C46,9A46,9846,9646,9446

	;0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x20 
	;.. A247,A047,9E47,9C47,9A47,9847,9647,9447

	;0x20,0x30,0x22,0x22,0x22,0x22,0x22,0x22,0x22,0x22,0x22,0x22,0x22,0x22,0x22,0x2b
	;.. A248,A048,9E48,9C48,9A48,9848,9648,9448,9248,9048,8e48,8c48,8a48,8848,8648,8448

	;0x20,0x32,0x25,0x25,0x25,0x25,0x25,0x25,0x25,0x25,0x25,0x25,0x25,0x25,0x25,0x2c
	;.. A249,A049,9E49,9C49,9A49,9849,9649,9449,9249,9049,8e49,8c49,8a49,8849,8649,8449

	;0x30,0x31,0x25,0x25,0x25,0x25,0x25,0x25,0x25,0x25,0x25,0x25,0x25,0x25,0x25,0x2a
	;.. A24a,A04a,9E4a,9C4a,9A4a,984a,964a,944a,924a,904a,8e4a,8c4a,8a4a,884a,864a,844a


	;0x8448	/
	;0x8648	|
	;0x8848	|
	;0x8a48	|
	;0x8c48	|
	;0x8e48	|
	;0x9048	|
	;0x9248	|
	;0x9448	|
	;0x9648	|
	;0x9848	|
	;0x9a48	|
	;0x9c48	|
	;0x9e48	|
	;0xa048	`
	;0xa248	 

l_2d17:
	GET_ADDRESS_Y	$1a                     	; [lda ($1a),y]
	move.b	(a0,d2.w),d0                    	; [...]
	addq.b	#1,d2                           	; [iny]
	;PUSH_SR
	;GET_ADDRESS	$11                       ; [sty $11]
	move.b	d2,$00ff0011                       ; [...]
	;POP_SR
	clr.w	d2                               	; [ldy #$00]
	;PUSH_SR
	GET_ADDRESS_Y	$1c                     	; [sta ($1c),y]
	move.b	d0,(a0,d2.w)                    	; [...]
	;POP_SR
	;GET_ADDRESS	$11                       ; [ldy $11]
	move.b	$00ff0011,d2                       ; [...]
	;GET_ADDRESS	$1d                       ; [dec $1d]
	;subq.b	#1,$00ff001d                       ; [...]
	;GET_ADDRESS	$1d                       ; [dec $1d]
	;subq.b	#1,$00ff001d                       ; [...]
	subq.b	#2,$00ff001d
	subq.b	#1,d1                           	; [dex]
	bne	l_2d17                             		; [bne l_2d17]
	
l_2d29:
	;have we finished coping ?
	;GET_ADDRESS	$1d                       ; [lda $1d]
	move.b	$00ff001d,d0                       ; [...]
	cmp.b	#$82,d0                         	; [cmp #$82]
	bcs	l_2d40                             		; [bcc l_2d40]
	;PUSH_SR
	;GET_ADDRESS	$11                       ; [sty $11]
	move.b	d2,$00ff0011                       ; [...]
	;POP_SR
	clr.w	d2                               	; [ldy #$00]
	move.b	#$20,d0                        		; [lda #$20]
	;PUSH_SR
	GET_ADDRESS_Y	$1c                     	; [sta ($1c),y]
	move.b	d0,(a0,d2.w)                    	; [...]
	;POP_SR
	;GET_ADDRESS	$11                       ; [ldy $11]
	move.b	$00ff0011,d2
	;GET_ADDRESS	$1d                       ; [dec $1d]
	subq.b	#2,$00ff001d                       ; [...]
	;GET_ADDRESS	$1d                       ; [dec $1d]
	;subq.b	#1,(a0)                         	; [...]
	jmp	l_2d29                             		; [jmp l_2d29]
l_2d40:
	CLR_XC_FLAGS                           	; [clc]
	;GET_ADDRESS	$14                       ; [lda $14]
	; move to index the next column. On second pass, 0xa240 becomes 0xa241 for the letter U
	move.b	$00ff0014,d0                       ; [...]
	move.b	#$01,d4								; addx.b	#$01,d0  ; [adc #$01]
	addx.b	d4,d0                        		; [adc #$01]
	PUSH_SR
	;GET_ADDRESS	$14                       ; [sta $14]
	move.b	d0,$00ff0014
	POP_SR
	bcc	l_2d4b                             		; [bcc l_2d4b]
	;GET_ADDRESS	$15                       ; [inc $15]
	addq.b	#1,$00ff0015                       ; [...]
l_2d4b:
	;GET_ADDRESS	$15                       ; [lda $15]
	move.b	$00ff0015,d0                       ; [...]
	cmp.b	#$a4,d0                         	; [cmp #$a4]
	bcc	l_2d66                             		; [bcs l_2d66]
	;GET_ADDRESS	$8f                       ; [dec $8f]
	subq.b	#1,$00ff008f                       ; [...]
	;render the next column for the letter U
	bne	l_2d09                             		; [bne l_2d09]
	;next struct / second half of large letter
	beq	l_2ce8                             		; [beq l_2ce8] 0x2d55 on c64 version
	
l_2d57:
	;GET_ADDRESS	$ffa401						; [lda $a401]
	move.b	$00ffa401,d0						; [...]
	;PUSH_SR
	;GET_ADDRESS	$1a                       ; [sta $1a]
	move.b	d0,$00ff001a                       ; [...]
	;POP_SR
	;GET_ADDRESS	$ffa501						; [lda $a501]
	move.b	$00ffa501,d0						; [...]
	;PUSH_SR
	;GET_ADDRESS	$1b							; [sta $1b]
	move.b	d0,$00ff001b						; [...]
	;POP_SR
	clr.w	d2                               	; [ldy #$00]
	jmp	l_2d04                             		; [jmp l_2d04]
l_2d66:
	clr.w	d2                               	; [ldy #$00]
	CLR_XC_FLAGS                           	; [clc]
	GET_ADDRESS	$12                       	; [lda $12]
	move.b	(a0),d0                         	; [...]
	move.b	#$01,d4								; addx.b	#$01,d0  ; [adc #$01]
	addx.b	d4,d0                        		; [adc #$01]
	PUSH_SR
	GET_ADDRESS	$12                       	; [sta $12]
	move.b	d0,(a0)                         	; [...]
	POP_SR
	bcc	l_2d73                             		; [bcc l_2d73]
	GET_ADDRESS	$13                       	; [inc $13]
	addq.b	#1,(a0)                         	; [...]
l_2d73:
	GET_ADDRESS_Y	$12                     	; [lda ($12),y]
	move.b	(a0,d2.w),d0                    	; [...]
	or.b	#$80,d0                          	; [ora #$80]
	and.b	#$bf,d0                         	; [and #$bf]
	PUSH_SR
	GET_ADDRESS	$15                       	; [sta $15]
	move.b	d0,(a0)                         	; [...]
	POP_SR
	cmp.b	#$a4,d0                         	; [cmp #$a4]
	bcc	l_2de3                             		; [bcs l_2de3]
	addq.b	#1,d2                           	; [iny]
	GET_ADDRESS_Y	$12                     	; [lda ($12),y]
	move.b	(a0,d2.w),d0                    	; [...]			0x80cc - 0x0
	PUSH_SR
	GET_ADDRESS	$14                       	; [sta $14]	
	move.b	d0,(a0)                         	; [...]			set to 0x8000
	POP_SR
	addq.b	#1,d2                           	; [iny]
	GET_ADDRESS_Y	$12                     	; [lda ($12),y]
	move.b	(a0,d2.w),d0                    	; [...]
	beq	l_2de3                             		; [beq l_2de3] returns to 0x20fe - jsr $2ca5
	
	; to test.
	move.b	d0,d1                           	; [tax]
	GET_ADDRESS	$ffa500                     ; [lda $a500,x]
	move.b	(a0,d1.w),d0                    	; [...]
	PUSH_SR
	GET_ADDRESS	$1b                       	; [sta $1b]
	move.b	d0,(a0)                         	; [...]
	POP_SR
	GET_ADDRESS	$ffa400                     ; [lda $a400,x]
	move.b	(a0,d1.w),d0                    	; [...]
	PUSH_SR
	GET_ADDRESS	$1a                       	; [sta $1a]
	move.b	d0,(a0)                         	; [...]
	POP_SR
	CLR_XC_FLAGS                           	; [clc]
	GET_ADDRESS	$12                       	; [lda $12]
	move.b	(a0),d0                         	; [...]
	move.b	#$03,d4								; [adc #$03]
	addx.b	d4,d0                        	; [adc #$03]
	PUSH_SR
	GET_ADDRESS	$12                       	; [sta $12]
	move.b	d0,(a0)                         	; [...]
	POP_SR
	bcc	l_2d9f                             	; [bcc l_2d9f]
	GET_ADDRESS	$13                       	; [inc $13]
	addq.b	#1,(a0)                         	; [...]
l_2d9f:
	clr.b	d2                               	; [ldy #$00]
	GET_ADDRESS_Y	$1a                     	; [lda ($1a),y]
	move.b	(a0,d2.w),d0                    	; [...]
	addq.b	#1,d2                           	; [iny]
	PUSH_SR
	GET_ADDRESS	$8f                       	; [sta $8f]
	move.b	d0,(a0)                         	; [...]
	POP_SR
l_2da6:
	GET_ADDRESS	$14                       	; [lda $14]
	move.b	(a0),d0                         	; [...]
	PUSH_SR
	GET_ADDRESS	$1c                       	; [sta $1c]
	move.b	d0,(a0)                         	; [...]
	POP_SR
	GET_ADDRESS	$15                       	; [lda $15]
	move.b	(a0),d0                         	; [...]
	PUSH_SR
	GET_ADDRESS	$1d                       	; [sta $1d]
	move.b	d0,(a0)                         	; [...]
	POP_SR
	GET_ADDRESS_Y	$1a                     	; [lda ($1a),y]
	move.b	(a0,d2.w),d0                    	; [...]
	addq.b	#1,d2                           	; [iny]
	and.b	#$1f,d0                         	; [and #$1f]
	move.b	d0,d1                           	; [tax]
l_2db4:
	GET_ADDRESS_Y	$1a                     	; [lda ($1a),y]
	move.b	(a0,d2.w),d0                    	; [...]
	addq.b	#1,d2                           	; [iny]
	PUSH_SR
	GET_ADDRESS	$11                       	; [sty $11]
	move.b	d2,(a0)                         	; [...]
	POP_SR
	clr.b	d2                               	; [ldy #$00]
	cmp.b	#$20,d0                         	; [cmp #$20]
	beq	l_2dc1                             		; [beq l_2dc1]
	PUSH_SR
	GET_ADDRESS_Y	$1c                     	; [sta ($1c),y]
	move.b	d0,(a0,d2.w)                    	; [...]
	POP_SR
l_2dc1:
	bsr.s	l_2de4                            	; [jsr l_2de4]
	GET_ADDRESS	$11                       	; [ldy $11]
	move.b	(a0),d2                         	; [...]
	GET_ADDRESS	$1d                       	; [dec $1d]
	subq.b	#1,(a0)                         	; [...]
	GET_ADDRESS	$1d                       	; [dec $1d]
	subq.b	#1,(a0)                         	; [...]
	bpl	l_2de3                             		; [bpl l_2de3]
	subq.b	#1,d1                           	; [dex]
	bne	l_2db4                             		; [bne l_2db4]
	CLR_XC_FLAGS                           	; [clc]
	GET_ADDRESS	$14                       	; [lda $14]
	move.b	(a0),d0                         	; [...]
	move.b	#$01,d4								;	addx.b	#$01,d0  ; [adc #$01]
	addx.b	d4,d0                        		; [adc #$01]
	PUSH_SR
	GET_ADDRESS	$14                       	; [sta $14]
	move.b	d0,(a0)                         	; [...]
	POP_SR
	bcc	l_2dda                             		; [bcc l_2dda]
	GET_ADDRESS	$15                       	; [inc $15]
	addq.b	#1,(a0)                         	; [...]
l_2dda:
	GET_ADDRESS	$8f                       	; [dec $8f]
	subq.b	#1,(a0)                         	; [...]
	bne	l_2da6                             		; [bne l_2da6]
	clr.b	d2                               	; [ldy #$00]
	jmp	l_2d73                             		; [jmp l_2d73]
l_2de3:
	rts                                    		; [rts]
l_2de4:
	cmp.b	#$59,d0                         	; [cmp #$59]
	bcs	l_2e16                             		; [bcc l_2e16]
	cmp.b	#$5c,d0                         	; [cmp #$5c]
	bcc	l_2e16                             		; [bcs l_2e16]
	GET_ADDRESS	$54                       	; [ldy $54]
	move.b	(a0),d2                         	; [...]
	addq.b	#1,d2                           	; [iny]
	cmp.b	#$10,d2                         	; [cpy #$10]
	bcc	l_2e16                             		; [bcs l_2e16]
	PUSH_SR
	GET_ADDRESS	$54                       	; [sty $54]
	move.b	d2,(a0)                         	; [...]
	POP_SR
	GET_ADDRESS	$1d                       	; [lda $1d]
	move.b	(a0),d0                         	; [...]
	and.b	#$01,d0                         	; [and #$01]
	PUSH_SR
	GET_ADDRESS	$0230                     	; [sta $0230,y]
    move.b	d0,(a0,d2.w)                 		; [...]
	POP_SR
	GET_ADDRESS	$1d                       	; [lda $1d]
	move.b	(a0),d0                         	; [...]
	SET_XC_FLAGS                           	; [sec]
	SBC_IMM	 $82                           		; [sbc #$82]
												; [clc]
	add.b	#$0c,d0                        		; [adc #$0c]
	lsr.b	#1,d0                            	; [lsr a]
	PUSH_SR
	GET_ADDRESS	$0220                     	; [sta $0220,y]
    move.b	d0,(a0,d2.w)                 		; [...]
	POP_SR
	GET_ADDRESS	$1c                       	; [lda $1c]
	move.b	(a0),d0                         	; [...]
	PUSH_SR
	GET_ADDRESS	$0210                     	; [sta $0210,y]
    move.b	d0,(a0,d2.w)                 		; [...]
	POP_SR
	roxr.b	#1,d0                           	; [ror a]
	PUSH_SR
	GET_ADDRESS	$0200                     	; [sta $0200,y]
    move.b	d0,(a0,d2.w)                 		; [...]
	POP_SR
	st.b	d0                                	; [lda #$ff]
	PUSH_SR
	GET_ADDRESS	$0240                     	; [sta $0240,y]
    move.b	d0,(a0,d2.w)                 		; [...]
	POP_SR
l_2e16:
	rts                                    	; [rts]

l_2e17:
	move.w	#$18,d2                        	; [ldy #$18]
	move.b	#$01,d0                        	; [lda #$01]
l_2e1b:
	PUSH_SR
	;GET_ADDRESS	$a518                 ; [sta $a518,y]
	lea $00ffa518,a0
    move.b	d0,(a0,d2.w)                 	; [...]
	POP_SR
	subq.b	#1,d2                          ; [dey]
	cmp.b	#$14,d2                        ; [cpy #$14]
	bcc	l_2e1b                             	; [bcs l_2e1b]
	move.w	#$0f,d2                        	; [ldy #$0f]
	clr.b	d0                             ; [lda #$00]
	PUSH_SR
	;GET_ADDRESS	$10                   ; [sta $10]
	move.b	d0,$00ff0010                        ; [...]
	POP_SR

l_2e29:
	
	;GET_ADDRESS	$10						; [ldx $10] - 0x1bf0
	move.b	$00ff0010,d1					; [...]
	;lea l_800,a0							; [lda $0800,x]
	lea $0ff0800,a0
	move.b	(a0,d1.w),d0					; [...]			; 0xb5
	;GET_ADDRESS	$10						; [inc $10]
	addq.b	#1,$00ff0010					; [...]
	and.b	#$0f,d0							; [and #$0f]		; 0x05
											; [clc]
	add.b	#$07,d0							; [adc #$07]		; 0x05+0x7 = 0xc
	move.b	d0,d1							; [tax]			; 0xc
	lea $ffa500,a0							; [lda $a500,x]
	move.b	(a0,d1.w),d0					; [...]			; if 0 then branch to 2e3e
	beq	l_2e3e								; [beq l_2e3e]
	bsr.w l_2ea5							; [jsr l_2ea5]
	
l_2e3e: 
	
	; character ram table	hi
	lea		l_b360_c64,a0
	move.b	(a0,d1.w),d0               ; [...]
	PUSH_SR
	lea	$ffa400,a0               		; [sta $a400,y]
    move.b	d0,(a0,d2.w)                ; [...]
	POP_SR
	
	; character ram table	low
	lea l_b379_c64,a0
	move.b	(a0,d1.w),d0                ; [...]
	
	
	PUSH_SR
	lea	$ffa410,a0                      ; [sta $a410,y]
    move.b	d0,(a0,d2.w)                ; [...]
	POP_SR
	
	lea l_340f,a0                     	; [lda $340f,x]  - check these values, colour ram ??
	move.b	(a0,d1.w),d0               ; [...]
	PUSH_SR
	lea $ffa480,a0						; [sta $a480,y]
    move.b	d0,(a0,d2.w)               ; [...]
	POP_SR
	
	lea $ffa500,a0						; [inc $a500,x]
    addq.b	#1,(a0,d1.w)				; [...]
	GET_ADDRESS	$10					; [ldx $10]
	move.b	(a0),d1						; [...]
	
	; transform these values to vram addresses
	;4b4e - $ca8c
	;4969 - $c482
	;4ad7 - $c90e
	;4a51 - $c742
	;49c4 - $c598
	;4918 - $c380	- not visible on original
	;4b25 - $ca0a
	;4acd - $c8ca
	;4a76 - $c7bc
	;4a90 - $c820
	;499a - $c514 
	;4a11 - $c692
	;4afb - $c986
	;495a - $c434
	;4b8d - $cb3a 
	;49e2 - $c604 ok
	
	;lea l_800,a0							; [lda $0800,x]	
	lea $0ff0800,a0
	move.b	(a0,d1.w),d0					; [...]									0xc2
	GET_ADDRESS	$10						; [inc $10]
	addq.b	#1,(a0) 						; [...]
	and.b	#$1f,d0							; [and #$1f]							0x02	
	cmp.b	#$14,d0							; [cmp #$14]							
	bcs.s	l_2e62							; [bcc l_2e62]
	; need to add 1 to factor in carry set.
	move.b	#5,d4							; addx.b #$04,d0  ; [adc #$04]
	addx.b	d4,d0                        	; [adc #$04]

l_2e62:
	move.b	d0,d1                           ; [tax]
	lea $ffa518,a0                       	; [lda $a518,x]
	move.b	(a0,d1.w),d0                   ; [...]
	beq.s	l_2e6b                          ; [beq l_2e6b]
	bsr.w	l_2ebe                          ; [jsr l_2ebe]
	
l_2e6b:
	lea	$ffa518,a0                      	; [inc $a518,x]
    addq.b	#1,(a0,d1.w)                 	; [...] 
	move.b	d1,d0                          ; [txa]
	CLR_XC_FLAGS                           ; [clc]
	lea	$ffa410,a0                     	; [adc $a410,y]
	move.b	(a0,d2.w),d4					; addx.b	(a0,d2.w),d0                    	; [...]
	addx.b	d4,d0                     		; [...]
	PUSH_SR
	lea	$ffa410,a0 	                   	; [sta $a410,y]
    move.b	d0,(a0,d2.w)                 	; [...]
	lea	$ffa400,a0                   		; [lda $a400,y]
	move.b	(a0,d2.w),d0                   ; [...]
	move.b	#$00,d4							; addx.b	#$00,d0  ; [adc #$00]
	addx.b	d4,d0                        	; [adc #$00]
	PUSH_SR
	lea	$ffa400,a0                     	; [sta $a400,y]
    move.b	d0,(a0,d2.w)                 	; [...]
	POP_SR
	POP_SR                                 	; [plp]
	lea	$ffa480,a0	                     	; [lda $a480,y]
	move.b	(a0,d2.w),d0                    	; [...]
	move.b	#$00,d4							;	addx.b	#$00,d0 ; [adc #$00]
	addx.b	d4,d0                        	; [adc #$00]
	PUSH_SR
	lea	$ffa480,a0                    		; [sta $a480,y]
    move.b	d0,(a0,d2.w)                 	; [...]
	POP_SR
	GET_ADDRESS	$10                    ; [ldx $10]
	move.b	(a0),d1                        ; [...]
	;lea l_800,a0                     		; [lda $0800,x]
	lea $0ff0800,a0
	move.b	(a0,d1.w),d0                    ; [...]
	;GET_ADDRESS	$10                     ; [inc $10]
	addq.b	#1,$00ff0010                    ; [...]
	and.b	#$01,d0                         ; [and #$01]
											; [clc]
	add.b	#$42,d0                        	; [adc #$42]
	PUSH_SR
	lea	$ffa420,a0	                  		; [sta $a420,y]
    move.b	d0,(a0,d2.w)                 	; [...]
	POP_SR
	subq.b	#1,d2                           	; [dey]
	bpl.w	l_2e29                             	; [bpl l_2e29]
	clr.b	d0                               	; [lda #$00]
	move.b	#$40,d2                        	; [ldy #$40]
	
l_2e9e:
	PUSH_SR
	lea	$ffa500,a0	                		; [sta $a500,y]
    move.b	d0,(a0,d2.w)                 	; [...]
	POP_SR
	subq.b	#1,d2                           ; [dey]
	bpl.s	l_2e9e                         ; [bpl l_2e9e]
	rts                                    	; [rts]

l_2ea5:
	GET_ADDRESS	$8d                       	; [lda $8d]
	move.b	(a0),d0                         	; [...]
	PUSH_SR
	GET_ADDRESS	$8f                       	; [sta $8f]
	move.b	d0,(a0)                         	; [...]
	POP_SR

l_2ea9:
	
	move.b	d1,d0                           	; [txa]
	CLR_XC_FLAGS                           ; [clc]
	add.b	#$07,d0                        	; [adc #$07]
	cmp.b	#$17,d0                         	; [cmp #$17]
	bcs.s	l_2eb3                             ; [bcc l_2eb3]
	sub.b 	#$10,d0                           	; [sbc #$10]
l_2eb3:
	move.b	d0,d1                           	; [tax]
	GET_ADDRESS	$8f                       	; [dec $8f]
	subq.b	#1,(a0)                         	; [...]
	beq	l_2ebd                             	; [beq l_2ebd]
	lea $ffa500,a0                     	; [lda $a500,x]
	move.b	(a0,d1.w),d0                    	; [...]
	bne.s	l_2ea9                             ; [bne l_2ea9]
l_2ebd:
	rts                                    	; [rts]
l_2ebe:
	GET_ADDRESS	$8d                     ; [lda $8d]
	move.b	(a0),d0                         ; [...]
	PUSH_SR
	GET_ADDRESS	$8f                     ; [sta $8f]
	move.b	d0,(a0)                         ; [...]
	POP_SR
l_2ec2:
	move.b	d1,d0                           	; [txa]
											; [clc]
	add.b	#$07,d0                        	; [adc #$07]
	cmp.b	#$27,d0                         ; [cmp #$27]
	bcs.s	l_2ecc                             ; [bcc l_2ecc]
	;SBC_IMM	 $27                      ; [sbc #$27]
	sub.b #$27,d0
l_2ecc:
	move.b	d0,d1                           	; [tax]
	GET_ADDRESS	$8f                       	; [dec $8f]
	subq.b	#1,(a0)                         	; [...]
	beq.s	l_2ed6                             	; [beq l_2ed6]
	lea $ffa518,a0                     	; [lda $a518,x]
	move.b	(a0,d1.w),d0                    	; [...]
	bne.s	l_2ec2                             	; [bne l_2ec2]
l_2ed6:
	rts                                    	; 
	
	; ===============================================		
	; star generation between first 2 and last 2 rows
	; ===============================================
l_2ed7:
	;lea $00ff008d,a0							; [ldx $8d] - 1e5a
	;move.b	(a0),d1                         	; [...]
	move.b $00ff008d,d1
l_2ed9:
	move.w #0,d5
	; ===============================================		
	; Transform stars from VIC II to Sega vram memory
	; adjusting the position based on the difference 
	; between the screen setups of the C64 and Sega
	; Handle the difference in row length and character 
	; positioning between the two systems.
	; ===============================================
	
	; The alogorithm
	; 49e2 - $c604
	; 49e2 - 4800 = 1e2
	; 1e2 / 40 = 12 rows 
	; 482 + 12 * 24 < 1 = 604
	; 0xc000 | 0x604 = 0xc604
	
	; 4b8d - $cb3a
	; 4b8d - 4800 = 38d
	; 0x38d / 0x28 = 22 rows
	; 909 + 22 * 24 < 1 = B3a
	
	; 495a - $c434
	; 495a - 4800 = 15a
	; 0x15a / 0x28 = 8
	; 346 + 8 * 24 < 1 = 434
	
	; 4afb - $c986
	
	; on game demo, first star
	; 4acd - $c8ca
	; 4acd - 4800 = 2cd
	; 2cd / 40 = 17 rows
	; 717 + 17 * 24 < 1 = 8ca
	
	
	
	
	; implementation - ffa400
	clr.w d3
	lea $00ffa400,a0
	move.b	(a0,d1.w),d0	; get the high
	asl.w	#8,d0			; shift it 8 bits left
	move.b	16(a0,d1.w),d0	; get the low
	sub.w #$4800,d0		; 0x1e2	 ( characters from start )
	move.w	d0,d3			; save 0x1e2
	divu.w  #40,d0			; get row # = c.
	
	mulu.w #24,d0			; get the delta ( sega has 64 rows )
	
	add.w d0,d3				; add delta to start
	asl.w #1,d3				; multiply that by 2, each char is equal to two bytes
	or.w #$e000,d3			; add the base address of vram
	move.w d3,d0
	lsr.w #8,d0
							; [sta $15]
	move.b	d0,$00ff0015	; store high address used to render star.
	move.b	d3,$00ff0014           			; [sta $14]             
	clr.b	d2                               	; [ldy #$00]
	GET_ADDRESS_Y_RAM	$14                     ; [lda ($14),y]
	add.w d2,a0
	; read character ram position
	SetVRAMReadReg a0
	cmp.w #$20,vdp_data
	bne.w l_2f0b                             	; [bne l_2f0b]

	; pointers to star objects
	;GET_ADDRESS	$a420                     ; [lda $a420,x]
	lea $00ffa420,a0							; star
	move.b	(a0,d1.w),d0                    	; [...]
	
	;PUSH_SR
	GET_ADDRESS_Y_RAM	$14                     ; [sta ($14),y]
	add.w d2,a0
	SetVRAMWriteReg a0
	or.w	#$0500,d0
	move.w d0,vdp_data							; write a star if 0x20 is found.
	
	; color ram.
	;move.b	d0,(a0,d2.w)                    	; [...]	 ; 
	;POP_SR
	
	;GET_ADDRESS	$a480                     ; [lda $a480,x]
	lea $00ffa480,a0
	move.b	(a0,d1.w),d0                    	; [...]
	
	;PUSH_SR
	;GET_ADDRESS	$15                       ; [sta $15]
	move.b	d0,$00ff0015                       ; [...]
	;POP_SR
	;GET_ADDRESS	$58                       ; [lda $58]
	move.b	$00ff0058,d0                       ; [...]
	
l_2ef7:
	;PUSH_SR
	;GET_ADDRESS_Y	$14                     	; [sta ($14),y] - write to colour ram
	;move.b	d0,(a0,d2.w)                    	; [...]
	;POP_SR
	subq.b	#1,d1                           	; [dex] - 0x1f7c
	bpl.w	l_2ed9								; [bpl l_2ed9]

	;GET_ADDRESS	$2c                       ; [ldx $2c] - scroll value
	move.b	$00ff002c,d1						; [...]
	;GET_ADDRESS	l_311e                    ; [lda $311e,x]
	lea l_311e,a0
	move.b	(a0,d1.w),d0                    	; [...]
	;PUSH_SR
	move.b	d0,$ff7a15							; [sta $7a15] - shift star
	move.b	d0,$ff7a1a							; [sta $7a1a] - shift star               	
	move.b	d0,$ff7a1b							; [sta $7a1b] - shift star
	;POP_SR
	rts                                    		; [rts]
l_2f0b:
	;GET_ADDRESS	$a480                     ; [lda $a480,x]
	lea $00ffa480,a0
	move.b	(a0,d1.w),d0                    	; [...]
	;GET_ADDRESS	$15                     
	move.b	d0,$00ff0015              			; [sta $15]        
	;GET_ADDRESS	$4d                       
	move.b	$00ff004d,d0                      	; [lda $4d]
	jmp	l_2ef7                             		; [jmp l_2ef7]

l_2f15:
	;move.b	#$26,d2                        	; [ldy #$26]
	move.w	#$4e,d2 							; each character is 2 bytes on the sega
	
l_2f17:
	;GET_ADDRESS	$10                       ; [ldx $10]
	move.b	$00ff0010,d1                       ; [...]
	;lea l_800,a0
	lea $0ff0800,a0
	move.b	(a0,d1.w),d0                    	; [...]
	;GET_ADDRESS	$10							; [inc $10]
	addq.b	#1,$00ff0010						; [...]
	move.b	d0,d1								; [tax]
	move.b	#$20,d0								; [lda #$20] clear postion
	cmp.b	#$f0,d1								; [cpx #$f0]
	bcs.s	l_2f2d_2							; [bcc l_2f2d]
	
	move.b	#$42,d0                        		; [lda #$42] draw a star
	cmp.b	#$f8,d1                         	; [cpx #$f8]		  
	bcc.s	l_2f2d                            	; [bcs l_2f2d]
	move.b	#$01,d4								; [adc #$01]
	addx.b	d4,d0                        		; [adc #$01]
	
l_2f2d:											; draw star
	GET_ADDRESS_Y_RAM	 $1c					; [sta ($1c),y]
	add.w d2,a0
	SetVRAMWriteReg a0
	;or.w #$0500,d0
	move.w d0,vdp_data
	subq.b	#2,d2                           	; [dey]
	bpl.w	l_2f17                             	; [bpl l_2f17]
	rts											; [rts]

l_2f2d_2:										; clear foreground
	GET_ADDRESS_Y_RAM	 $1c					; [sta ($1c),y]
	sub.w #$2000,a0
	add.w d2,a0
	SetVRAMWriteReg a0
	move.w d0,vdp_data
	subq.b	#2,d2                           	; [dey]
	bpl.w	l_2f17                             	; [bpl l_2f17]
	rts			
	
	;==============
	; Level colours
	;==============
l_2f33:
	; colour table for super dreadnoughts - customize this routine
	;move.b	#$72,d1                        	; [ldx #$72]
	;move.b	#$33,d2                        	; [ldy #$33]
	move.w	#l_3372,d2
	move.b  d2,d1
	lsr.w	#8,d2								; get high byte
	
	PUSH_SR
	GET_ADDRESS	$1c                       	; [stx $1c]
	move.b	d1,(a0)                         	; [...]
	GET_ADDRESS	$1d                       	; [sty $1d]
	move.b	d2,(a0)                         	; [...]
	POP_SR
	
	clr.b	d0                               	; [lda #$00]
	PUSH_SR
	GET_ADDRESS	$8f                       	; [sta $8f]
	move.b	d0,(a0)                         	; [...]
	POP_SR
	GET_ADDRESS	$61                       	; [lda $61]
	move.b	(a0),d0                         	; [...]
	bne.w	l_2f5b                             	; [bne l_2f5b]
	GET_ADDRESS	$26                       	; [ldy $26]
	move.b	(a0),d2                         	; [...]
	;GET_ADDRESS	l_copied_data1+$30        ; [lda l_copied_data1+$30,y]
	lea	$ffe030,a0                    		
	move.b	(a0,d2.w),d0                    	; [...]
	beq.w	l_2f5b                             	; [beq l_2f5b]
	PUSH_SR
	GET_ADDRESS	$8f                       	; [sta $8f]
	move.b	d0,(a0)                         	; [...]
	POP_SR

l_2f4c:
	CLR_XC_FLAGS                           	; [clc]
	GET_ADDRESS	$1c                       	; [lda $1c]
	move.b	(a0),d0                         	; [...]
	move.b	#$05,d4								; addx.b	#$05,d0 - [adc #$05]
	addx.b	d4,d0                        		; [adc #$05]
	PUSH_SR
	GET_ADDRESS	$1c                       	; [sta $1c]
	move.b	d0,(a0)                         	; [...]
	POP_SR
	bcc.s	l_2f57								; [bcc l_2f57]
	GET_ADDRESS	$1d                       	; [inc $1d]
	addq.b	#1,(a0)                         	; [...]
l_2f57:
	GET_ADDRESS	$8f                       	; [dec $8f]
	subq.b	#1,(a0)                         	; [...]
	bne.s	l_2f4c                             	; [bne l_2f4c]
	
l_2f5b:
	move.b	#$04,d2                        		; [ldy #$04]
l_2f5d:
	GET_ADDRESS_Y	$1c                     	; [lda ($1c),y]
	move.b	(a0,d2.w),d0                    	; [...]
	PUSH_SR
	GET_ADDRESS	$004b                     	; [sta $004b,y]
    move.b	d0,(a0,d2.w)                 		; [...]
	POP_SR
	subq.b	#1,d2                           	; [dey]
	bpl	l_2f5d                             		; [bpl l_2f5d]
	
	GET_ADDRESS	$4b                       	; [lda $4b]
	move.b	(a0),d0                         	; [...]
	PUSH_SR
	GET_ADDRESS	$d023                     	; [sta $d023] - background colour 2
	;move.b	d0,(a0)                         	; [...]
	POP_SR
	GET_ADDRESS	$4c                       	; [lda $4c]
	move.b	(a0),d0                         	; [...]
	PUSH_SR
	GET_ADDRESS	$d022                     	; [sta $d022] - background colour 1
	;move.b	d0,(a0)                         	; [...]
	POP_SR
	GET_ADDRESS	$4e                       	; [lda $4e]
	move.b	(a0),d0                         	; [...]
	PUSH_SR
	GET_ADDRESS	$d025                     	; [sta $d025] - sprite multicolor register 0
	;move.b	d0,(a0)                         	; [...]
	POP_SR
	move.b	#$f1,d0                        		; [lda #$f1]
	PUSH_SR
	GET_ADDRESS	$d026                     	; [sta $d026] - Sprite multi-color register 1
	;move.b	d0,(a0)                         	; [...]
	POP_SR
	GET_ADDRESS	$4d                       	; [lda $4d]
	move.b	(a0),d0                         	; [...]
	and.b	#$f7,d0                         	; [and #$f7]
	PUSH_SR
	GET_ADDRESS	$58                       	; [sta $58]
	move.b	d0,(a0)                         	; [...]
	POP_SR
	
	; colour ram - this needs to be customized.
	move.b	#$a0,d1                        		; [ldx #$a0]
	move.b	#$d8,d2                        		; [ldy #$d8]
	PUSH_SR
	GET_ADDRESS	$1c                       	; [stx $1c]
	move.b	d1,(a0)                         	; [...]
	GET_ADDRESS	$1d                       	; [sty $1d]
	move.b	d2,(a0)                         	; [...]
	POP_SR
	move.b	#$02,d3                        		; [ldx #$02]
	GET_ADDRESS	$58                       	; [lda $58]
	move.b	(a0),d0                         	; [...]
	;bsr.w	l_b189								; [jsr l_b189]
	move.b	#$11,d3								; [ldx #$11]
	GET_ADDRESS	$4d							; [lda $4d]
	move.b	(a0),d0                         	; [...]
	;bsr.w	l_b189								; [jsr l_b189]
	move.b	#$02,d3                        		; [ldx #$02]
	GET_ADDRESS	$58                       	; [lda $58]
	move.b	(a0),d0                         	; [...]
	;bsr.w	l_b189								; [jsr l_b189]
	rts                                    		; [rts]
	
l_2fc8:
	rts
	
l_3086:
	clr.b	d1									; [ldx #$00]
	;PUSH_SR
	;GET_ADDRESS	$10							; [stx $10]
	move.b	d1,$00ff0010						; [...]
	;POP_SR
	
l_308a:
	;GET_ADDRESS	$d41b						; [lda $d41b]
	move.b	$00ffd41b,d0						; [...]
	;GET_ADDRESS	$10							; [ldx $10]
	move.b	$00ff0010,d1
	;GET_ADDRESS	$0800						; [eor $0800,x]
	;lea l_800,a0
	lea $0ff0800,a0
	move.b	(a0,d1.w),d4						; eor.b	(a0,d1.w),d0
	eor.b	d4,d0                     			; [...]
	;PUSH_SR
	;GET_ADDRESS	$0800						; [sta $0800,x]
	;lea l_800,a0
	lea $0ff0800,a0
    move.b	d0,(a0,d1.w)						; [...]
	;POP_SR
	;GET_ADDRESS	l_data1+$f                ; [rol l_data1+$f]
	;move.b	l_800f,d4							; roxl.b	#1,(a0)
	move.b $0ff800f,d4
	roxl.b	#1,d4								; [...]
	;PUSH_SR
	move.b	d4,(a0)								; roxl.b	#1,(a0)
	;POP_SR
	;GET_ADDRESS	l_data1+$f					; [ror l_data1+$f]
	;move.b	l_800f,d4							; roxr.b	#1,(a0)
	move.b $0ff800f,d4
	roxr.b	#1,d4								; [...]
	;PUSH_SR
	move.b	d4,(a0)								;	roxr.b	#1,(a0)
	;POP_SR
	;GET_ADDRESS	$10							; [inc $10]
	addq.b	#1,$00ff0010						; [...]
	bne	l_308a									; [bne l_308a]
	rts											; [rts]
	
	; Vertical blank interrupt 2
l_3f00:
	;addi.b #$1,vblank_counter   				; Increment vinterrupt counter
	
	;...
	;...
l_3f3c:
	; handles scroll value during main game.
	;SBC_IMM	0x01							; [sbc #$01]
	;bne	l_3f3c								; [bne l_3f3c]
	;GET_ADDRESS	0x2c						; [lda $2c]
	;move.b	(a0),d0                         	; [...]
	;and.b	#0x07,d0                         	; [and #$07] mask off first 3 bits
	;or.b	#0xd0,d0							; [ora #$d0] - 3f45
	rte
	

	
	; Vertical blank interrupt 1
l_3f93:
	;addi.b #$1,vblank_counter   
	;movem.l	d0/a0,-(sp)					; [pha] push accumulator on stack
	;move.b	#$07,d0								; [lda #$07] 0x7 in a
												; [sec] set carry flag
l_3f97:
	;sub.b #1,d0								; [sbc #$01] does this 7 times
	;bne.s	l_3f97								; [bne l_3f97]
	
l_3faf:
	;clr.w	d0 									; [lda #$00] current raster position. self modifying code @ $3fb0
	;PUSH_SR
	;GET_ADDRESS	$2f							; [sta $2f] store frame count in zero page address ( likely not needed )
	;move.b	d0,(a0)								; [...]
	;POP_SR
	; change screen to black moved to 17e2
	;bsr.w	l_b24b								; [jsr l_b24b]
	;bsr.w	l_0e23 								; title tune.
l_3fd5:
	;movem.l (sp)+,d0/a0						; [pla]
	rte
	

l_b019:
	clr.b	d0                               	; [lda #$00]
	;PUSH_SR
	GET_ADDRESS	$16                       	; [sta $16]
	move.b	d0,(a0)                         	; [...]
	GET_ADDRESS	$17                       	; [sta $17]
	move.b	d0,(a0)                         	; [...]
	;POP_SR
	
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
	bne	l_b03d				  	  ; [bne l_b03d]
	
	;process right
l_b03b:
	GET_ADDRESS	$17			  ; [inc $17]
	addq.b	#1,(a0)				  ; [...]

l_b03d:
	btst #pad_button_up,d0
	beq.s l_b04a	;doup                 ; [beq l_b04a	// do up]
	
	btst #pad_button_down,d0
	beq.s l_b04e	;dodown               ; [beq l_b04e	 // do down]
	jmp	l_b050	;checkthefirebutton       ; [jmp l_b050	 // check the fire button]

	;process up
l_b04a:
	GET_ADDRESS	$16						;[dec $16]
	subq.b	#1,(a0)							; [...]
	bne.s	l_b050							; [bne l_b050]

	;process down
l_b04e:
	GET_ADDRESS	$16                     ; [inc $16]
	addq.b	#1,(a0)                         ; [...]
l_b050:
	and.b #$10,d0							;isoldatefirebutton,d0 | [and #$10	// isoldate fire button]
	PUSH_SR
	GET_ADDRESS	$18						;storeresultin0page.0valueforfirebuttondown	| [sta $18// store result in 0 page. 0 value for fire button down]
	move.b	d0,(a0)                         ; [...]
	POP_SR
	rts                                    	; [rts]

	;first 4 bytes are used to check the joystick on the c64 which we won't use.
l_b055:
dc.b $01,$02,$04,$08,$10,$20,$40,$8

	even
	; sprite routines
l_b05d:
	rts
	
l_b0e3:
	
	;GET_ADDRESS	 $04					;[ldy $04]
	move.b	$00ff0004,d2					; [...]
	;GET_ADDRESS	l_b055					; [lda l_b055,y]
	lea l_b055,a0
	move.b	(a0,d2.w),d0
	;PUSH_SR
	;GET_ADDRESS	$02						; [sta $02]
	move.b	d0,$00ff0002
	;POP_SR
	not.b	d0                             ; [eor #$ff]
	;PUSH_SR
	;GET_ADDRESS	$03                   ; [sta $03]
	move.b	d0,$00ff0003
	;POP_SR
	;GET_ADDRESS	$0d						; [lda $0d]
	move.b	$00ff000d,d0
	;PUSH_SR
	;GET_ADDRESS	$d027                 ; [sta $d027,y]
    ;move.b	d0,(a0,d2.w)
	;POP_SR
	;GET_ADDRESS	$0b						; [lda $0b]
	move.b	$00ff000b,d0
	beq	l_b0fe                             	; [beq l_b0fe]
	;GET_ADDRESS	$02                   ; [lda $02]
	move.b	$00ff0002,d0
	GET_ADDRESS	$d01c                     	; [ora $d01c]
	or.b	(a0),d0							; [...]
	bne	l_b103								; [bne l_b103]
	rts
	
l_b0fe:
	GET_ADDRESS	$d01c                     	; [lda $d01c]
	move.b	(a0),d0                         	; [...]
	;GET_ADDRESS	$03                       ; [and $03]
	lea $00ff0003,a0
	and.b	(a0),d0                          	; [...]
	
l_b103:
	PUSH_SR
	GET_ADDRESS	 $d01c                     	; [sta $d01c]
	move.b	d0,(a0)
	POP_SR
	;GET_ADDRESS	$09						; [lda $09]
	lea $00ff0009,a0
	move.b	(a0),d0							; [...]
	beq	l_b111								; [beq l_b111]
	;GET_ADDRESS	$02						; [lda $02]
	move.b	$00ff0002,d0
	GET_ADDRESS	$d017						; [ora $d017]
	or.b	(a0),d0							; [...]
	bne	l_b116								; [bne l_b116]

l_b111:
	GET_ADDRESS	$d017                     	; [lda $d017]
	move.b	(a0),d0                         	; [...]
	;GET_ADDRESS	$03                       ; [and $03]
	lea $00ff0003,a0
	and.b	(a0),d0                          	; [...]

l_b116:
	PUSH_SR
	GET_ADDRESS	$d017                     	; [sta $d017]
	move.b	d0,(a0)                         	; [...]
	POP_SR
	;GET_ADDRESS	$0c                       ; [lda $0c]
	move.b	$00ff000c,d0                       ; [...]
	beq	l_b124                             		; [beq l_b124]
	;GET_ADDRESS	$02                       ; [lda $02]
	move.b	$00ff0002,d0                       ; [...]
	GET_ADDRESS	$d01d                     	; [ora $d01d]
	or.b	(a0),d0                           	; [...]
	bne	l_b129                             		; [bne l_b129]

l_b124:
	GET_ADDRESS	$d01d                     	; [lda $d01d]
	move.b	(a0),d0                         	; [...]
	;GET_ADDRESS	$03                       ; [and $03]
	and.b	$00ff0003,d0                       ; [...]
l_b129:
	PUSH_SR
	GET_ADDRESS	$d01d                     	; [sta $d01d]
	move.b	d0,(a0)                         	; [...]
	POP_SR
	;GET_ADDRESS	$0a                       ; [lda $0a]
	move.b	$00ff000a,d0                       ; [...]
	beq	l_b137                             		; [beq l_b137]
	;GET_ADDRESS	$02                       ; [lda $02]
	move.b	$00ff0002,d0                       ; [...]
	GET_ADDRESS	$d01b                     	; [ora $d01b]
	or.b	(a0),d0                           	; [...]
	bne	l_b13c                             		; [bne l_b13c]

l_b137:
	GET_ADDRESS	$d01b                     	; [lda $d01b]
	move.b	(a0),d0                         	; [...]
	;GET_ADDRESS	$03                       ; [and $03]
	and.b	$00ff0003,d0                       ; [...]
l_b13c:
	PUSH_SR
	GET_ADDRESS	$d01b                     	; [sta $d01b]
	move.b	d0,(a0)                         	; [...]
	POP_SR
	
l_b13f:
	rts
	
	;====================================================
	;Renders row of characters d3 = tile index, d3 = rows
	;====================================================

l_b189:
	;PUSH_SR
	GET_ADDRESS $0d                       		; [sta $0d]
	move.b	d0,(a0)                         	; [...]
	move.l	a0,a2								; preserve pointer to tile address in a2
	;POP_SR
l_b18b: 
	clr.b d2                               		; [ldy #$00]
l_b18d:
	; fill 1 row of characters
	;PUSH_SR
	GET_ADDRESS_Y_RAM	 $1c                     ; [sta ($1c),y] ; stores tile at said address
	add.w d2,a0
	move.b (a2),d6
	move.w d6,vdp_data
	;POP_SR
	addq.w #1,d2                           		; [iny]
	cmp.w #$28,d2                         		; [cpy #$28] ; have we read 40 characters
	bcs.s l_b18d 								; [bcc l_b18d]
	
	subq.b	#1,d3                           	; [dex] , done 1  row
	beq.s	l_b1a7								; [beq l_b1a7]
	CLR_XC_FLAGS								; [clc]
	add.w #$80,a1
	SetVRAMWriteReg a1
	bcs.w	l_b1a2								; [bcc l_b1a2]
l_b1a2:
	move.b (a2),d6								; get tile.
	move.w d6,vdp_data
	jmp	l_b18b									; [jmp l_b18b]
l_b1a7:
	CLR_XC_FLAGS								; [clc]
	add.w #$80,a1
	SetVRAMWriteReg a1
	bcs.w l_b1b3                             	; [bcc l_b1b3]
l_b1b3:
	rts                                    		; [rts]
 	
	
l_b1b4:
	move.b	#$04,d0                        		; [lda #$02]
	;PUSH_SR
	GET_ADDRESS	$b4                       	; [sta $b4]
	move.b	d0,(a0)                         	; [...]
	;POP_SR
l_b1b8:
	;move.b	 #$02,d0                        	; [lda #$02] 	  - self modifying
	;PUSH_SR
	GET_ADDRESS	$0                   		; [sta l_b1b8+1] - use first byte in ram instead / can't SM in rom
	move.b	(a0),d0                         	; [...]
	;POP_SR
	
	
	;PUSH_SR
	GET_ADDRESS	$b5                       	; [sta $b5]
	move.b	d0,(a0)                         	; [...]
	;POP_SR
	
	clr.b	d1                               	; [ldx #$00]
	;PUSH_SR
	GET_ADDRESS	$10                       	; [stx $10]
	move.b	d1,(a0)                         	; [...]
	;POP_SR
	
	move.b	#$30,d0                        		; [lda #$30] ; blank tile.
	;PUSH_SR
	GET_ADDRESS	$0f                       	; [sta $0f]
	move.b	d0,(a0)                         	; [...]
	;POP_SR
	
l_b1c4:
	GET_ADDRESS	$20                       	; [lda $20,x]
	move.b	(a0,d1.w),d0                    	; [...]
	lsr.b	#4,d0
	;lsr.b	#1,d0                            ; [lsr a]
	;lsr.b	#1,d0                            ; [lsr a]
	;lsr.b	#1,d0                            ; [lsr a]
	;lsr.b	#1,d0                            ; [lsr a]
	bne	l_b1ef									; [bne l_b1ef]
	GET_ADDRESS	$0f                       	; [lda $0f]
	move.b	(a0),d0                         	; [...]

l_b1ce:
	;PUSH_SR
	GET_ADDRESS	$b6                       	; [sta $b6]
	move.b	d0,(a0)                         	; [...]
	;POP_SR
	bsr.w	l_b2c6                           	; [jsr l_b2c6]
	GET_ADDRESS	$10                       	; [ldx $10]
	move.b	(a0),d1                         	; [...]
	GET_ADDRESS	$20                       	; [lda $20,x]
	move.b	(a0,d1.w),d0                    	; [...]
	and.b	#$0f,d0                         	; [and #$0f]
	bne	l_b1f6                             		; [bne l_b1f6]
	cmp.b	#$03,d1                         	; [cpx #$03]
	beq	l_b1f6                             		; [beq l_b1f6]
	GET_ADDRESS	$0f                       	; [lda $0f]
	move.b	(a0),d0                         	; [...]
l_b1e1:
	;PUSH_SR
	GET_ADDRESS	$b6                       	; [sta $b6]
	move.b	d0,(a0)                         	; [...]
	;POP_SR
	bsr.w	l_b2c6                            	; [jsr l_b2c6]
	GET_ADDRESS	$10                       	; [inc $10]
	addq.b	#1,(a0)                         	; [...]
	GET_ADDRESS	$10                       	; [ldx $10]
	move.b	(a0),d1                         	; [...]
	cmp.b	#$04,d1                         	; [cpx #$04]
	bne	l_b1c4                             		; [bne l_b1c4]
	rts                                    		; [rts]

l_b1ef:
	clr.b d2                               		; [ldy #$00]
	;PUSH_SR
	GET_ADDRESS	$0f                       	; [sty $0f]
	move.b	d2,(a0)                         	; [...]
	;POP_SR
	jmp	l_b1ce                             		; [jmp l_b1ce]
l_b1f6:
	clr.b	d2                               	; [ldy #$00]
	;PUSH_SR
	GET_ADDRESS	$0f                       	; [sty $0f]
	move.b	d2,(a0)                         	; [...]
	;POP_SR
	jmp	l_b1e1                             		; [jmp l_b1e1

l_b1fd:
	;kludge for now.
	move.b	#$78,d0                         	; [...]
	;PUSH_SR
	GET_ADDRESS	$19                       	; [sta $19]
	move.b	d0,(a0)                         	; [...]
	;POP_SR
	rts

	;===========
	;Delay timer
	;===========
	
l_b244:
	subq.b #1,d1                           	; [dex]
	bne.s	l_b244                             	; [bne l_b244]
	subq.b	#1,d2                           	; [dey]
	bne.s	l_b244                             	; [bne l_b244]
	rts                                    		; [rts]
	
	
l_b24b:
	;GET_ADDRESS	$01                       ; [lda $01]
	move.b	$00FF0001,d0                       ; [...]
	and.b	#$10,d0                         	; [and #$10]
	beq	l_b25a                             		; [beq l_b25a]
	;GET_ADDRESS	$01                       ; [lda $01]
	move.b	$00FF0001,d0                       ; [...]
	or.b	#$20,d0                          	; [ora #$20]
	;PUSH_SR
	;GET_ADDRESS	$01                       ; [sta $01]
	move.b	d0,$00FF0001                       ; [...]
	;GET_ADDRESS	$94                       ; [sta $94]
	move.b	d0,$00FF0094                       ; [...]
	;POP_SR
l_b259:
	rts                                    		; [rts]
l_b25a:
	;GET_ADDRESS	$94                       ; [lda $94]
	move.b	$00FF0094,d0                       ; [...]
	beq	l_b259                             		; [beq l_b259]
	;GET_ADDRESS	$01                       ; [lda $01]
	move.b	$00FF0001,d0                       ; [...]
	and.b	#$df,d0                         	; [and #$df]
	PUSH_SR
	;GET_ADDRESS	$01                       ; [sta $01]
	move.b	d0,$00FF0001                       ; [...]
	POP_SR
	rts  
	
l_b287:
	move.b	#$0a,d2								; [ldy #$0a]
l_b289:
	;GET_ADDRESS_Y_RAM	 $1a					; [lda ($1a),y]
	lea $00ff001a,a0
	move.b	(a0,d2.w),d0
	;GET_ADDRESS	$0004						; [sta $0004,y]
	lea $00ff0004,a0
    move.b	d0,(a0,d2.w)						; [...]
	subq.b	#1,d2								; [dey]
	bpl	l_b289									; [bpl l_b289]
	bsr.w	l_b0e3								; [jsr l_b0e3]
	rts											; [rts]
	
l_b295:
	;PUSH_SR
	;GET_ADDRESS	$be							; [stx $be]
	move.b	d1,$00ff00be						; [...]
	;GET_ADDRESS	$bf 						; [sty $bf]
	move.b	d2,$00ff00bf						; [...]
	;POP_SR
	
	clr.w	d2                               	; [ldy #$00]
	GET_ADDRESS_Y_ROM	 $be					; [lda ($be),y] ; gets the y position
	move.b	(a0,d2.w),d0                    	; [...]
	rol.b #1,d0
	;PUSH_SR
	;GET_ADDRESS	$b4							; [sta $b4]
	move.b	d0,$00ff00b4						; [...]
	;POP_SR
	cmp.b	#$30,d0                         	; [cmp #$18] 	; have we read 24 rows
	bcc	l_b2c5                             		; [bcs l_b2c5]
	addq.b	#1,d2                           	; [iny]
	
	GET_ADDRESS_Y_ROM	$be                     ; [lda ($be),y] - get the data from rom
	move.b	(a0,d2.w),d0						; [...] , gets the x position of text to print on screen.
	rol.b #1,d0									; multiply x pos by 2 since each position on screen needs 2 bytes on the sega
	;PUSH_SR
	;GET_ADDRESS	$b5							; [sta $b5]	; store position in $b5
	move.b	d0,$00ff00b5						; [...]
	;POP_SR
	addq.b	#1,d2                           	; [iny]
	
	GET_ADDRESS_Y_ROM $be						; [lda ($be),y]
	move.b	(a0,d2.w),d0                    	; get first half of glyph
	and.b	#$7f,d0                         	; [and #$7f]
	jmp	l_b2b4                             		; [jmp l_b2b4]
l_b2b0:
	;GET_ADDRESS	$ba							; [ldy $ba]
	move.b	$00ff00ba,d2						; [...]
	GET_ADDRESS_Y_ROM	$be						; [lda ($be),y]
	move.b	(a0,d2.w),d0                    	; [...]
l_b2b4:
	addq.b	#1,d2                           	; [iny]
	
	;PUSH_SR
	;GET_ADDRESS	$ba							; [sty $ba]
	move.b	d2,$00ff00ba						; [...]
	;POP_SR
	bmi.s	l_b2c5                             	; [bmi l_b2c5]
	tst.b	d0                               	; [cmp #$00]
	bmi.s	l_b2c5                             	; [bmi l_b2c5]
	;PUSH_SR
	;GET_ADDRESS	$b6							; [sta $b6]
	move.b	d0,$00ff00b6						; [...]
	;POP_SR
	bsr.s l_b2c6                            	; [jsr l_b2c6]
	jmp	l_b2b0                             		; [jmp l_b2b0]
l_b2c5:
	rts                                    		; [rts]

l_b2c6:
	
	; get from the high byte table
	;GET_ADDRESS	$b4							; [ldy $b4]
	move.b	$00ff00b4,d2						; [...]
	;GET_ADDRESS	l_b360						; [lda l_b360,y]
	lea l_b360,a0
	move.b	(a0,d2.w),d0                    	; [...]
	;PUSH_SR
	;GET_ADDRESS	$b1							; [sta $b1]
	move.b	d0,$00ff00b1                       ; [...]
	;POP_SR
	
	; get from the low byte table
	;GET_ADDRESS	l_b379		                ; [lda l_b360+$19,y]
	lea l_b379,a0
	move.b	(a0,d2.w),d0                    	; gets high video address 0xc0
	CLR_XC_FLAGS                           	; [clc]
	;GET_ADDRESS	$b5							; [adc $b5]
	move.b	$00ff00b5,d4								
	addx.b	d4,d0                         		
	;PUSH_SR
	;GET_ADDRESS	$b0                       ; [sta $b0]
	move.b	d0,$00ff00b0						; [...]
	;POP_SR              
	
	clr.w	d0                               	; [lda #$00]
	;GET_ADDRESS	$b1							; [adc $b1]
	move.b	$00ff00b1,d4						; addx.b	(a0),d0
	addx.b	d4,d0                         		; [...]
	;PUSH_SR
	;GET_ADDRESS	$b1							; [sta $b1]
	move.b	d0,$00ff00b1						; [...]
	;POP_SR
	
	GET_ADDRESS	$b6                       	; [lda $b6]
	move.b	(a0),d0                         	; [...]
	clr.w	d2                               	; [ldy #$00]
	;PUSH_SR
	GET_ADDRESS_Y_RAM	$b0                    ; [sta ($b0),y] ; write to video memory
	add.w d2,a0
	SetVRAMWriteReg a0
	move.w d0,vdp_data
	;POP_SR
		
	or.b	#$80,d0                          	; [ora #$80] ; index into table for bottom half of character
	move.b	#$80,d2                        		; [ldy #$28] ; #$80 for the next row down
	
	; render top row of text
	;PUSH_SR
	GET_ADDRESS_Y_RAM	$b0            			; [sta ($b0),y] ; write to video memory
	add.w d2,a0
	SetVRAMWriteReg a0
	move.w d0,vdp_data	
	;POP_SR
	
	;GET_ADDRESS	$b5							; [inc $b5]
	addq.b	#2,$00ff00b5						; [...] 2 bytes per char on the sega megadrive
	and.b	#$7f,d0                         	; [and #$7f]
	cmp.b	#$3a,d0                         	; [cmp #$3a]
	
	bcs	l_b301                             		; [bcc l_b301]
	cmp.b	#$5a,d0                         	; [cmp #$5a]
	bcc	l_b301                             		; [bcs l_b301]
	move.b	#$02,d2                        		; [ldy #$01]
	move.b	#$20,d4								; addx.b	#0x20,d0  ; [adc #$20]
	addx.b	d4,d0                        		; [adc #$20]
	
	; render second half of character of two glyph letter
	;PUSH_SR
	GET_ADDRESS_Y_RAM	$b0                     ; [sta ($b0),y] ; write to video memory
	add.w d2,a0
	SetVRAMWriteReg a0
	move.w d0,vdp_data	
	;POP_SR
	
	or.b	#$80,d0                          	; [ora #$80]	; bottom row glyph / tile
	move.b	#$82,d2                        		; [ldy #$29]	; render second half of glyph
	
	;PUSH_SR
	GET_ADDRESS_Y_RAM	$b0                     ; [sta ($b0),y] ; write to video memory
	add.w d2,a0
	SetVRAMWriteReg a0
	move.w d0,vdp_data		
	;POP_SR
	
	;GET_ADDRESS	$b5							; [inc $b5]
	addq.b	#2,$00ff00b5						; 2 bytes per char position on sega

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
	lea $00ff00b3,a0
	;GET_ADDRESS	$b3                       ; [inc $b3]
	addq.b	#1,(a0)                         	; [...]
	;GET_ADDRESS	$b1                       ; [inc $b1]
	lea $00ff00b1,a0
	addq.b	#1,(a0)                         	; [...]
	subq.b	#1,d1                           	; [dex]
	bne.s	l_b302                             	; [bne l_b302
	rts                                    		; [rts]

	;=============================================
	;block copy, 0-ff bytes
	;is called by l_b302 x times or called outside
	;=============================================

l_b30f:
	GET_ADDRESS_Y_ROM	$b2                     ; [lda ($b2),y]
	move.b	(a0,d2.w),d0                    	; [...]
	;PUSH_SR
	GET_ADDRESS_Y	$b0                     	; [sta ($b0),y]
	move.b	d0,(a0,d2.w)                    	; [...]
	;POP_SR
	subq.b	#1,d2                           	; [dey]
	bne	l_b30f                             		; [bne l_b30f]
	GET_ADDRESS_Y_ROM	$b2                     ; [lda ($b2),y]
	move.b	(a0,d2.w),d0                    	; [...]
	;PUSH_SR
	GET_ADDRESS_Y	$b0                     	; [sta ($b0),y]
	move.b	d0,(a0,d2.w)                    	; [...]
	;POP_SR
	rts                                    		; [rts]

l_b31b:
	;GET_ADDRESS	$62                       ; [lda $62]
	move.b	$00ff0062,d0                       ; [...]
	and.b	#$03,d0                         	; [and #$03]
	bne	l_b35f                             		; [bne l_b35f]
	;GET_ADDRESS	$19                       ; [lda $19]
	move.b	$00ff0019,d0                       ; [...]
	and.b	#$40,d0                         	; [and #$40]
	bne	l_b35f									; [bne l_b35f]
	;GET_ADDRESS	$19                       ; [lda $19]
	move.b	$00ff0019,d0                       ; [...]
	bpl	l_b336									; [bpl l_b336]
	;GET_ADDRESS	$95                       ; [lda $95]
	move.b	$00ff0095,d0                       ; [...]
	cmp.b	#$0f,d0                         	; [cmp #$0f]
	bcc	l_b33e									; [bcs l_b33e]
	;GET_ADDRESS	$95                       ; [inc $95]
	addq.b	#1,$00ff0095                       ; [...]
	jmp	l_b33e									; [jmp l_b33e]
l_b336:
	;GET_ADDRESS	$95                       ; [lda $95]
	move.b	$00ff0095,d0                       ; [...]
	tst.b	d0                               	; [cmp #$00]
	beq	l_b33e									; [beq l_b33e]
	;GET_ADDRESS	$95                       ; [dec $95]
	subq.b	#1,$00ff0095                       ; [...]
l_b33e:
	;GET_ADDRESS	$95                       ; [lda $95]
	move.b	$00ff0095,d0                       ; [...]
	cmp.b	#$0a,d0                         	; [cmp #$0a]
	bcs	l_b34b                             		; [bcc l_b34b]
	SBC_IMM	$0a                           		; [sbc #$0a]
	move.b	#$01,d2                        		; [ldy #$01]
	jmp	l_b34d									; [jmp l_b34d]
l_b34b:
	move.b	#$30,d2                        		; [ldy #$30]
l_b34d:
	;PUSH_SR
	;GET_ADDRESS	l_b3c0+1                  ; [sty l_b3c0+1]
	move.b	d2,l_b3c0+1						; use ZP ram, to do later
	;GET_ADDRESS	l_b3c0+2                  ; [sta l_b3c0+2]
	move.b	d0,l_b3c0+2						; use ZP ram, to do later
	;POP_SR
	;GET_ADDRESS	$95                       ; [lda $95]
	move.b	$00ff0095,d0                       ; [...]
	;PUSH_SR
	;GET_ADDRESS	$ef                       ; [sta $ef]
	move.b	d0,$00ff00ef						; [...]
	;POP_SR
	;nop                                    	; [nop]
	move.w #l_b3b8,d2							; [ldx #<l_b3b8] / [ldy #>l_b3b8]
	move.b d2,d1
	lsr.w #8,d2
	bsr.w l_b295								; [jsr l_b295]
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
	cmp.l 	#$d021,a0					; get bg colour register
	beq.s	changeBackgroundColour
	cmp.l	#$d41b,a0					; get random number
	beq.s	getRandomNumber
	rts
	
handleSpriteEnable:
	; to do
	; 0xc0001c may not be supported in MAME
	rts

changeBackgroundColour:				; [ d0 = colour index, d1 = palette index ]
	move.w	#vdpreg_bgcol,d2			; background colour register
	add.b	d0,d2						; index the colour
	or.w	d1,d2						; select the palette 0x00,0x10,0x20,0x30
	move.w d2,vdp_control 				; Set background colour to palette 0, colour 8
	rts

; Registers:
; d3 - holds the current random number
getRandomNumber:
	move.b $00ffd41b,d0
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
	include 'scrollTextData.asm'					; scroll text and level 15 data
	
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
	dc.b $00,$40,$80,$c0
	dc.b $00,$40,$80
	
	; used to transform vic II addresses to sega vram 
l_b360_c64:
	dc.b $48,$48,$48,$48,$48,$48,$48,$49
	dc.b $49,$49,$49,$49,$49,$4a,$4a,$4a
	dc.b $4a,$4a,$4a,$4a,$4b,$4b,$4b,$4b
	dc.b $4b
	
l_b379_c64:
	dc.b $00,$28,$50,$78,$a0
	dc.b $c8,$f0,$18,$40,$68
	dc.b $90,$b8,$e0,$08,$30
	dc.b $58,$80,$a8,$d0,$f8
	dc.b $20,$48,$70,$98
	
l_b3b8:
	dc.b $00,$0f,$4f,$18,$15,$1e,$42,$0e

l_b3c0:
	dc.b $30,$00,$05,$ff,$20,$44,$b5,$85
	dc.b $bd,$c9,$46,$f0,$0d,$c9,$53,$d0

	;================
	; Star generation
	; Used to seed ?
	; 0xb5 0xff 0x01 0xb5 0xff 0x95 0xc9 0x18 0x95 0xca 0x69 0xca 0x10 0x95 0xcd 0xb4
	;================
l_800:
	dc.b $B5,$C2,$49,$FF,$18,$69,$01,$95
	dc.b $C2,$B5,$C3,$49,$FF,$69,$00,$95
	dc.b $C3,$B5,$C9,$49,$FF,$18,$69,$01
	dc.b $95,$C9,$B5,$CA,$49,$FF,$69,$00
	dc.b $95,$CA,$4C,$2D,$10,$B5,$CC,$95
	dc.b $C0,$B5,$CD,$95,$C1,$B4,$C6,$88
	dc.b $94,$C6,$D0,$18,$20,$A5,$10,$B5
	dc.b $CE,$F0,$04,$A6,$9F,$95,$91,$A6
	dc.b $9F,$A9,$00,$95,$96,$E0,$02,$D0
	dc.b $03,$20,$2B,$11,$E6,$9F,$A4,$9F
	dc.b $C0,$03,$B0,$08,$B9,$44,$11,$85
	dc.b $A0,$4C,$8C,$0F,$60,$20,$00,$11
	dc.b $A9,$00,$85,$A3,$B9,$96,$00,$38
	dc.b $E9,$01,$29,$7F,$0A,$26,$A3,$0A
	dc.b $26,$A3,$0A,$26,$A3,$0A,$26,$A3
	dc.b $18,$69,$AB,$85,$A2,$A9,$39,$65
	dc.b $A3,$85,$A3,$A0,$00,$B1,$A2,$20
	dc.b $BA,$10,$A4,$9F,$BE,$47,$11,$A0
	dc.b $0F,$B1,$A2,$95,$C0,$CA,$88,$D0
	dc.b $F8,$A5,$9F,$C9,$02,$D0,$05,$A9
	dc.b $00,$8D,$5F,$0F,$60,$A4,$A1,$A9
	dc.b $00,$99,$06,$D4,$99,$05,$D4,$A9
	dc.b $08,$99,$04,$D4,$A9,$00,$99,$04
	dc.b $D4,$60,$0A,$0A,$85,$A0,$20,$A5
	dc.b $10,$A2,$03,$A4,$A1,$BD,$4A,$11
	dc.b $99,$00,$D4,$C8,$CA,$10,$F6,$84
	dc.b $A1,$A2,$03,$A4,$A0,$B9,$47,$39
	dc.b $E6,$A0,$A4,$A1,$99,$00,$D4,$E6
	dc.b $A1,$CA,$D0,$EF,$A4,$A0,$B9,$47
	dc.b $39,$A6,$9F,$95,$99,$88,$88,$88
	dc.b $B9,$47,$39,$95,$9C,$09,$01,$A4
	dc.b $A1,$88,$88,$88,$99,$00,$D4,$60
	
	even
	
	;================================
	;Include game assets
	;================================
	include 'assets\chrsets\chrset1.asm'			; default character set
	include 'assets\chrsets\chrset2.asm'			; scroll text character set
	;include 'assets\chrsets\chrset3.asm'			; mini game character set
	;include 'assets\chrsets\chrset4.asm'			; game playfield character set
	include 'assets\sprites\manta-flipx.asm' 		; manta frames.
 
