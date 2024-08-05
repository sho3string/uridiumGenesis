;==============================================================
; UTILITY FUNCTIONS
;==============================================================
; Subroutines to initialise the TMSS, and load all VDP registers
;==============================================================

VDP_WriteTMSS:

	; The TMSS (Trademark Security System) locks up the VDP if we don't
	; write the string 'SEGA' to a special address. This was to discourage
	; unlicensed developers, since doing this displays the "LICENSED BY SEGA
	; ENTERPRISES LTD" message to screen (on Mega Drive models 1 and higher).
	;
	; First, we need to check if we're running on a model 1+, then write
	; 'SEGA' to hardware address 0xA14000.

	move.b hardware_ver_address,d0			; Move Megadrive hardware version to d0
	andi.b #$0F,d0								; The version is stored in last four bits, so mask it with 0F
	beq	SkipTMSS								; If version is equal to 0, skip TMSS signature
	move.l #tmss_signature,tmss_address		; Move the string "SEGA" to 0xA14000
SkipTMSS:
	; Check VDP
	move.w vdp_control,d0						; Read VDP status register (hangs if no access)
	
	rts

VDP_LoadRegisters:

	; To initialise the VDP, we write all of its initial register values from
	; the table at the top of the file, using a loop.
	;
	; To write a register, we write a word to the control port.
	; The top bit must be set to 1 (so 0x8000), bits 8-12 specify the register
	; number to write to, and the bottom byte is the value to set.
	;
	; In binary:
	;   100X XXXX YYYY YYYY
	;   X = register number
	;   Y = value to write

	; Set VDP registers
	lea    VDPRegisters,a0	; Load address of register table into a0
	move.w #$18-1,d0			; 24 registers to write (-1 for loop counter)
	move.w #$8000,d1			; 'Set register 0' command to d1

CopyRegLp:
	move.b (a0)+,d1			; Move register value from table to lower byte of d1 (and post-increment the table address for next time)
	move.w d1,vdp_control		; Write command and value to VDP control port
	addi.w #$0100,d1			; Increment register #
	dbra   d0,CopyRegLp		; Decrement d0, and jump back to top of loop if d0 is still >= 0
	rts
