		;==============================================================
		; VRAM WRITE MACROS
		;==============================================================
		; Some utility macros to help generate addresses and commands for
		; writing data to video memory, since they're tricky (and
		; error prone) to calculate manually.
		; The resulting command and address is written to the VDP's
		; control port, ready to accept data in the data port.
		;==============================================================

		; Set the VRAM (video RAM) address to write to next
		macro SetVRAMWriteConst addr
		move.l	#(vdp_cmd_vram_write)|((\addr)&$3FFF)<<16|(\addr)>>14,vdp_control
		endm
		
		macro SetVRAMReadConst addr
		move.l	#(vdp_cmd_vram_read)|((\addr)&$3FFF)<<16|(\addr)>>14,vdp_control
		endm
		
		macro SetVRAMWriteReg addr_reg
		
		movem.l  d0-d1,-(a7)      	
		move.l \addr_reg,d0         ; Move the address to d0
		andi.l #$3FFF,d0            ; Mask lower 14 bits
		lsl.l #8,d0                 ; Shift left by 8 bits
		lsl.l #8,d0                 ; Shift left by another 8 bits (total 16 bits)

		move.l \addr_reg,d1         ; Move the original address to d1
		lsr.l #8,d1                 ; Shift right by 6 bits (preparing for masking)
		lsr.l #6,d1                 ; Shift right by 6 bits (preparing for masking)
		;andi.l #$0003,d1         ; Mask the lower 2 bits after shifting

		or.l  d1,d0                 ; Combine with the rest of the command
		or.l  #(vdp_cmd_vram_write),d0 ; Set the command
		move.l d0,vdp_control
		movem.l (a7)+,d0-d1
		endm
		
		macro SetVRAMReadReg addr_reg
		
		movem.l  d0-d1,-(a7)      	
		move.l \addr_reg,d0         ; Move the address to d0
		andi.l #$3FFF,d0            ; Mask lower 14 bits
		lsl.l #8,d0                 ; Shift left by 8 bits
		lsl.l #8,d0                 ; Shift left by another 8 bits (total 16 bits)

		move.l \addr_reg,d1         ; Move the original address to d1
		lsr.l #8,d1                 ; Shift right by 6 bits (preparing for masking)
		lsr.l #6,d1                 ; Shift right by 6 bits (preparing for masking)
		;andi.l #$0003,d1         ; Mask the lower 2 bits after shifting

		or.l  d1,d0                 ; Combine with the rest of the command
		or.l  #(vdp_cmd_vram_read),d0 ; Set the command
		move.l d0,vdp_control
		movem.l (a7)+,d0-d1
		endm
	
		; Set the CRAM (colour RAM) address to write to next
		macro SetCRAMWrite addr
		move.l  #(vdp_cmd_cram_write)|((\addr)&$3FFF)<<16|(\addr)>>14,vdp_control
		endm

		; Set the VSRAM (vertical scroll RAM) address to write to next
		macro SetVSRAMWrite addr
		move.l  #(vdp_cmd_vsram_write)|((\addr)&$3FFF)<<16|(\addr)>>14,vdp_control
		endm


		; Writes a sprite attribute structure to 4 registers, ready to write to VRAM
		
		macro BuildSpriteStructure x_pos,y_pos,dimension_bits,next_id,priority_bit,palette_id,flip_x,flip_y,tile_id,reg1,reg2,reg3,reg4
		
		; X pos on sprite plane
		; Y pos on sprite plane
		; Sprite tile dimensions (4 bits)
		; Next sprite index in linked list
		; Draw priority
		; Palette index
		; Flip horizontally
		; Flip vertically
		; First tile index
		; Output: reg1
		; Output: reg2
		; Output: reg3
		; Output: reg4
		
		move.w #\y_pos,\reg1
		move.w #(\dimension_bits<<8|\next_id),\reg2
		move.w #(\priority_bit<<14|\palette_id<<13|\flip_x<<11|\flip_y<<10|\tile_id),\reg3
		move.w #\x_pos,\reg4
		endm
		
	
;==============================================================
; 6502 to 68000 specific Macros
;==============================================================
	
		macro	SBC_X	address
		INVERT_XC_FLAGS
		GET_ADDRESS	\address
		move.b	(a0,d1.w),d4
		subx.b	d4,d0
		INVERT_XC_FLAGS
		endm

		macro	SBC_Y	address
		INVERT_XC_FLAGS
		GET_ADDRESS	\address
		move.b	(a0,d2.w),d4
		subx.b	d4,d0
		INVERT_XC_FLAGS
		endm

		macro	SBC	address
		INVERT_XC_FLAGS
		GET_ADDRESS	\address
		move.b	(a0),d4
		subx.b	d4,d0
		INVERT_XC_FLAGS
		endm

		macro	SBC_IMM	 param
		INVERT_XC_FLAGS
		move.b	#\param,d4
		subx.b	d4,d0
		INVERT_XC_FLAGS
		endm

		macro INVERT_XC_FLAGS
		PUSH_SR
		move.w	(sp),d4
		eor.b	#$11,d4
		move.w	d4,(sp)
		POP_SR
		endm
		
		
		; useful to recall C from X (add then move then bcx)
		macro	SET_C_FROM_X
		PUSH_SR
		move.w	(sp),d4
		bset	#0,d4   | set C
		btst	#4,d4
		bne.b	0f
		bclr	#0,d4   | X is clear: clear C
		0:
		move.w	d4,(sp)
		POP_SR
		endm

		macro	SET_X_FROM_CLEARED_C
		PUSH_SR
		move.w	(sp),d4
		bset	#4,d4   | set X
		btst	#0,d4
		beq.b	0f
		bclr	#4,d4   | C is set: clear X
		0:
		move.w	d4,(sp)
		POP_SR
		endm

		macro CLR_XC_FLAGS
		moveq	#0,d7
		roxl.b	#1,d7
		endm
		
		macro SET_XC_FLAGS
		st	d7
		roxl.b	#1,d7
		endm

		macro CLR_V_FLAG
		moveq	#0,d3
		add.b	d3,d3
		endm

		macro SET_I_FLAG
		;^^^^ TODO: insert interrupt disable code here
		endm
		macro CLR_I_FLAG
		;^^^^ TODO: insert interrupt enable code here
		endm
		
		; Sega Megadrive has a 68000
		
		;ifdef	MC68020
		;macro PUSH_SR
		;move.w	ccr,-(sp)
		;endm
		;macro POP_SR
		;;move.w	(sp)+,ccr
		;endm
		;else
		macro PUSH_SR
		move.w	sr,-(sp)
		endm
		macro POP_SR
		move.w	(sp)+,sr
		endm
		;endif
		
		macro READ_LE_WORD	 srcreg
		movem.l  d0-d4,-(a7)  
		PUSH_SR
		move.b	(1,\srcreg),d4
		lsl.w	#8,d4
		move.b	(\srcreg),d4
		move.l d4,d1
		andi.l #$0000FFFF,d1 ; mask the upper part of d1 to zero
		
		move.l a0, d0          ; Copy a0 to d0
		andi.l #$FFFF0000, d0 ; Clear the lower word of d0
		or.l d4, d0            ; Combine the cleared d0 with d4
		move.l d0,\srcreg     ; Move the result back to a0
		POP_SR
		movem.l  (a7)+,d0-d4
		endm
		
		macro READ_LE_WORD_ROM	 srcreg
		movem.l  d0-d4,-(a7)  
		PUSH_SR
		move.b	(1,\srcreg),d4
		lsl.w	#8,d4
		move.b	(\srcreg),d4
		move.l	d4,a0
		POP_SR
		movem.l  (a7)+,d0-d4
		endm
		
		macro RAM_ADDR_REG srcreg
		move.w	(\srcreg),d5
		or.l #$00ff0000,d5
		move.l	d5,\srcreg
		endm

		macro GET_ADDRESS offset
		lea \1,a0
		bsr	get_address
		endm
		
		macro GET_ADDRESS_X offset
		lea	\offset,a0
		bsr	get_address
		lea	(a0,d1.w),a0
		READ_LE_WORD	a0
		bsr	get_address
		endm

		macro GET_ADDRESS_Y	offset
		GET_ADDRESS \offset
		READ_LE_WORD	a0
		bsr	get_address
		endm
		
		macro GET_ADDRESS_Y_ROM	offset
		GET_ADDRESS \offset
		READ_LE_WORD_ROM	a0
		bsr	get_address
		endm
		
		macro GET_ADDRESS_Y_RAM	offset
		GET_ADDRESS \offset
		READ_LE_WORD_ROM	a0
		bsr	get_address
		endm