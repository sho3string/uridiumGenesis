	; ******************************************************************
	; Sega Megadrive ROM header
	; ******************************************************************

ROM_Start:

	dc.l   $00FFE000			; Initial stack pointer value
	dc.l   CPU_EntryPoint		; Start of program
	dc.l   CPU_Exception 		; Bus error
	dc.l   CPU_Exception 		; Address error
	dc.l   CPU_Exception 		; Illegal instruction
	dc.l   CPU_Exception 		; Division by zero
	dc.l   CPU_Exception 		; CHK CPU_Exception
	dc.l   CPU_Exception 		; TRAPV CPU_Exception
	dc.l   CPU_Exception 		; Privilege violation
	dc.l   INT_Null			; TRACE exception
	dc.l   INT_Null			; Line-A emulator
	dc.l   INT_Null			; Line-F emulator
	dc.l   INT_Null			; Unused (reserved)
	dc.l   INT_Null			; Unused (reserved)
	dc.l   INT_Null			; Unused (reserved)
	dc.l   INT_Null			; Unused (reserved)
	dc.l   INT_Null			; Unused (reserved)
	dc.l   INT_Null			; Unused (reserved)
	dc.l   INT_Null			; Unused (reserved)
	dc.l   INT_Null			; Unused (reserved)
	dc.l   INT_Null			; Unused (reserved)
	dc.l   INT_Null			; Unused (reserved)
	dc.l   INT_Null			; Unused (reserved)
	dc.l   INT_Null			; Unused (reserved)
	dc.l   INT_Null			; Spurious exception
	dc.l   INT_Null			; IRQ level 1
	dc.l   INT_Null			; IRQ level 2
	dc.l   INT_Null			; IRQ level 3
	dc.l   INT_HInterrupt		; IRQ level 4 (horizontal retrace interrupt)
	dc.l   INT_Null  			; IRQ level 5
	dc.l   INT_VInterrupt		; IRQ level 6 (vertical retrace interrupt)
	dc.l   INT_Null			; IRQ level 7
	dc.l   INT_Null			; TRAP #00 exception
	dc.l   INT_Null			; TRAP #01 exception
	dc.l   INT_Null			; TRAP #02 exception
	dc.l   INT_Null			; TRAP #03 exception
	dc.l   INT_Null			; TRAP #04 exception
	dc.l   INT_Null			; TRAP #05 exception
	dc.l   INT_Null			; TRAP #06 exception
	dc.l   INT_Null			; TRAP #07 exception
	dc.l   INT_Null			; TRAP #08 exception
	dc.l   INT_Null			; TRAP #09 exception
	dc.l   INT_Null			; TRAP #10 exception
	dc.l   INT_Null			; TRAP #11 exception
	dc.l   INT_Null			; TRAP #12 exception
	dc.l   INT_Null			; TRAP #13 exception
	dc.l   INT_Null			; TRAP #14 exception
	dc.l   INT_Null			; TRAP #15 exception
	dc.l   INT_Null			; Unused (reserved)
	dc.l   INT_Null			; Unused (reserved)
	dc.l   INT_Null			; Unused (reserved)
	dc.l   INT_Null			; Unused (reserved)
	dc.l   INT_Null			; Unused (reserved)
	dc.l   INT_Null			; Unused (reserved)
	dc.l   INT_Null			; Unused (reserved)
	dc.l   INT_Null			; Unused (reserved)
	dc.l   INT_Null			; Unused (reserved)
	dc.l   INT_Null			; Unused (reserved)
	dc.l   INT_Null			; Unused (reserved)
	dc.l   INT_Null			; Unused (reserved)
	dc.l   INT_Null			; Unused (reserved)
	dc.l   INT_Null			; Unused (reserved)
	dc.l   INT_Null			; Unused (reserved)
	dc.l   INT_Null			; Unused (reserved)

	dc.b "SEGA MEGA DRIVE "                                 	; Console name
	dc.b " "                                 					; Copyright holder and release date
	dc.b " "														; Domestic name
	dc.b " "														; International name
	dc.b "v 0.1"                                   			; Version number
	dc.w $0000                                             		; Checksum
	dc.b "J               "                                 	; I/O support
	dc.l ROM_Start                                          	; Start address of ROM
	dc.l ROM_End-1                                          	; End address of ROM
	dc.l $00FF0000                                         	; Start address of RAM
	dc.l $00FF0000+$0000FFFF                              	; End address of RAM
	dc.l $00000000                                         	; SRAM enabled
	dc.l $00000000                                         	; Unused
	dc.l $00000000                                         	; Start address of SRAM
	dc.l $00000000                                         	; End address of SRAM
	dc.l $00000000                                         	; Unused
	dc.l $00000000                                         	; Unused
	dc.b "                                        "         ; Notes (unused)E
	dc.b "  E             "                                 	; Country codes

	;==============================================================
	; INITIAL VDP REGISTER VALUES
	;==============================================================
	; 24 register values to be copied to the VDP during initialisation.
	; These specify things like initial width/height of the planes,
	; addresses within VRAM to find scroll/sprite data, the
	; background palette/colour index, whether or not the display
	; is on, and clears initial values for things like DMA.
	;==============================================================
VDPRegisters:
	dc.b $14 ; $00: H interrupt on, palettes on
	dc.b $74 ; $01: V interrupt on, display on, DMA on, Genesis mode on
	dc.b $30 ; $02: Pattern table for Scroll Plane A at VRAM $C000 (bits 3-5 = bits 13-15)
	dc.b $00 ; $03: Pattern table for Window Plane at VRAM $0000 (disabled) (bits 1-5 = bits 11-15)
	dc.b $07 ; $04: Pattern table for Scroll Plane B at VRAM $E000 (bits 0-2 = bits 11-15)
	dc.b $78 ; $05: Sprite table at VRAM $F000 (bits 0-6 = bits 9-15)
	dc.b $00 ; $06: Unused
	dc.b $00 ; $07: Background colour: bits 0-3 = colour, bits 4-5 = palette
	dc.b $00 ; $08: Unused
	dc.b $00 ; $09: Unused
	dc.b $08 ; $0A: Frequency of Horiz. interrupt in Rasters (number of lines travelled by the beam)
	dc.b $00 ; $0B: External interrupts off, V scroll fullscreen, H scroll fullscreen
	dc.b $81 ; $0C: Shadows and highlights off, interlace off, H40 mode (320 x 224 screen res)
	dc.b $3F ; $0D: Horiz. scroll table at VRAM $FC00 (bits 0-5)
	dc.b $00 ; $0E: Unused
	dc.b $02 ; $0F: Autoincrement 2 bytes
	dc.b $01 ; $10: Scroll plane size: 64x32 tiles
	dc.b $00 ; $11: Window Plane X pos 0 left (pos in bits 0-4, left/right in bit 7)
	dc.b $00 ; $12: Window Plane Y pos 0 up (pos in bits 0-4, up/down in bit 7)
	dc.b $FF ; $13: DMA length lo byte
	dc.b $FF ; $14: DMA length hi byte
	dc.b $00 ; $15: DMA source address lo byte
	dc.b $00 ; $16: DMA source address mid byte
	dc.b $80 ; $17: DMA source address hi byte, memory-to-VRAM mode (bits 6-7)
	
	even

	;==============================================================
	; CONSTANTS
	;==============================================================
	; Defines names for commonly used values and addresses to make
	; the code more readable.
	;==============================================================
	
; VDP port addresses
vdp_control				equ $00C00004
vdp_data					equ $00C00000
vdp_debug					equ $00C0001C
vdp_debug_mirror			equ $00C0001E

; VDP commands
vdp_cmd_vram_write			equ $40000000
vdp_cmd_cram_write			equ $C0000000

; VDP memory addresses
; according to VDP registers 0x2 and 0x4 (see table above)
vram_addr_tiles			equ $0000
vram_addr_plane_a			equ $C000
vram_addr_plane_b			equ $E000
vram_addr_sprite_table	equ $F000	
vram_addr_hscroll			equ $FC00

; Screen width and height (in pixels)
vdp_screen_width			equ $0140
vdp_screen_height			equ $00F0

; The plane width and height (in tiles)
; according to VDP register 0x10 (see table above)
vdp_plane_width			equ $40
vdp_plane_height			equ $20

; The size of the sprite plane (512x512 pixels)
;
; With only a 320x240 display size, a lot of this
; is off screen, which is useful for hiding sprites
; when not needed (saves needing to adjust the linked
; list in the attribute table).
vdp_sprite_plane_width	equ $200
vdp_sprite_plane_height	equ $200

; The sprite border (invisible area left + top) size
;
; The sprite plane is 512x512 pixels, but is offset by
; -128 pixels in both X and Y directions. To see a sprite
; on screen at 0,0 we need to offset its position by
; this border.
vdp_sprite_border_x		equ $80
vdp_sprite_border_y		equ $80

; Hardware version address
hardware_ver_address		equ $00A10001

; TMSS
tmss_address				equ $00A14000
tmss_signature				equ 'SEGA'

; The size of a word and longword
size_word					equ 2
size_long					equ 4

; The size of one palette (in bytes, words, and longwords)
size_palette_b				equ $20
size_palette_w				equ size_palette_b/size_word
size_palette_l				equ size_palette_b/size_long

; The size of one graphics tile (in bytes, words, and longwords)
size_tile_b				equ $20
size_tile_w				equ size_tile_b/size_word
size_tile_l				equ size_tile_b/size_long

; Sprite initial draw positions (in pixels)
sprite_1_start_pos_x		equ vdp_sprite_border_x
sprite_1_start_pos_y		equ vdp_sprite_border_y+$0040
sprite_2_start_pos_x		equ vdp_sprite_border_x+$0040
sprite_2_start_pos_y		equ vdp_sprite_border_y+$0020

; Speed (in pixels per frame) to move our sprites
sprite_1_move_speed_x		equ $1
sprite_1_move_speed_y		equ $1
sprite_2_move_speed_x		equ $2
sprite_2_move_speed_y		equ $0


charRam		equ vram_addr_plane_a
; Emulate the > operator used on 6502 assemblers
; Used to extract the high byte of a 16bit address stored in a table
; probably not very efficient
charRamHi	equ (charRam >> 8) & $FF

	;==============================================================
	; TILE IDs
	;==============================================================
	; The indices of the first tile in each sprite. We only need
	; to tell the sprite table where to find the starting tile of
	; each sprite, so we don't bother keeping track of every tile
	; index.
	;
	; Note we still leave the first tile blank (planes A and B are
	; filled with tile 0) so we'll be uploading our sprite tiles
	; from index 1.
	;
	; See bottom of the file for the sprite tiles themselves.
	;==============================================================
tile_id_sprite_1	equ $ff ; Sprite 1 index (9 tiles / 24 pixels x 24 pixels ) - add 8 for next frame.

	;==============================================================
	; MEMORY MAP
	;==============================================================
	; We need to store the current sprite positions in RAM and update
	; them each frame. There are a few ways to create a memory map,
	; but the cleanest, simplest, and easiest to maintain method
	; uses the assembler's "RS" keywords. RSSET begins a new table of
	; offsets starting from any other offset (here we're starting at
	; 0x00FF0000, the start of RAM), and allows us to add named entries
	; of any size for the "variables". We can then read/write these
	; variables using the offsets' labels (see INT_VInterrupt for use
	; cases).
	;==============================================================
	;RSSET $0FF0000				; Start a new offset table from beginning of RAM
ram_sprite_1_pos_x: ds.w 1	; 1 table entry of word size for sprite 1's X pos
ram_sprite_1_pos_y: ds.w 1	; 1 table entry of word size for sprite 1's Y pos


; Hello World draw position (in tiles)
text_pos_x					equ $00
text_pos_y					equ $00

z80_bus_req     			equ $00A11100
z80_bus_grant   			equ $00A11101
z80_reset       			equ $00A11200
z80_ram         			equ $00A00000

	;==============================================================
	; Memory emulation for ZP
	;==============================================================
ZERO_PAGE_BASE equ $FF0000  ; Base address for the emulated zero page

	;==============================================================
	; TILE IDs
	;==============================================================
	; The indices of each tile above. Once the tiles have been
	; written to VRAM, the VDP refers to each tile by its index.
	;==============================================================
tile_id_space			equ $20
tile_count				equ 254	; Last entry is just the count
sprite_count			equ 423
number_of_palettes		equ 2
vdpreg_bgcol			equ $8700
palette_a				equ	$00
palette_b				equ $10
palette_c				equ $20
palette_d				equ $30

ROM_End:

	include 'macros.asm'

CPU_EntryPoint:
	jmp	InitSystem
Main:
	jmp  Game


InitSystem:
	
	;==============================================================
	; Initialise status register and set interrupt level.
	; This begins firing vertical and horizontal interrupts.
	;==============================================================
	move.w #$2300,sr
	
	tst.l $00A10008 ; Test mystery reset (expansion port reset?)
	bne Main         ; Branch if Not Equal (to zero) - to Main
	tst.w $00A1000C ; Test reset button
	bne Main        ; Branch if Not Equal (to zero) - to Main
	
	;==============================================================
	; Initialise the Mega Drive
	;==============================================================
	

; Write the TMSS signature (if a model 1+ Mega Drive)
	jsr	VDP_WriteTMSS
Skip:

; Initalize the Z80 processor
InitZ80:
	move.w  #$0100,z80_bus_req ; Request access to the Z80 bus
    move.w  #$0100,z80_reset   ; Hold the Z80 in a reset state
Wait:
	btst #$0,$00A11100   ; Test bit 0 of A11100 to see if the 68k has access to the Z80 bus yet
	bne Wait              ; If we don't yet have control, branch back up to Wait

	move.l #Z80Data,a0      ; Load address of data into a0
	move.l #z80_ram,a1     ; Copy Z80 RAM address to a1
	move.l #$29,d0          ; 42 bytes of init data (minus 1 for counter)
.Copy:
	move.b (a0)+,(a1)+      ; Copy data, and increment the source/dest addresses
	dbra d0,.Copy

	move.w #$0000,z80_reset   ; Release reset state
    move.w #$0000,z80_bus_req ; Release control of bus
	
InitPSG:
	move.l #PSGData,a0      ; Load address of PSG data into a0
	move.l #$03,d0         ; 4 bytes of data
.Copy:
	move.b (a0)+,$00C00011 ; Copy data to PSG RAM
	dbra d0,.Copy
	
	; Load the initial VDP registers
	jsr    VDP_LoadRegisters
	
InitControllerPorts:
	 ; Set IN I/O direction, interrupts off, on all ports
	move.b #$00,$000A10009 ; Controller port 1 CTRL
	move.b #$00,$00A1000B ; Controller port 2 CTRL
	move.b #00,$00A1000D ; EXP port CTRL
	
	;==============================================================
	; Clear VRAM (video memory)
	;==============================================================
	SetVRAMWriteConst $0000
	
	move.w #($00010000/size_word)-1,d0 ; Loop counter = 64kb, in words (-1 for DBRA loop)
ClrVramLp:                         
    move.w #tile_id_space,vdp_data     ; blank tile / glyph         
    dbra d0,ClrVramLp 
	; init horizontal scroll register
	SetVRAMWriteConst vram_addr_hscroll
	move.w #0,vdp_data					   ; reset horinzontal scroll register to 0, was set to #32 (tile_id_space) from previous operation.
	
	;==============================================================
	; Write the palette to CRAM (colour memory)
	;==============================================================
	
	; Setup the VDP to write to CRAM address 0x0000 (first palette)
	SetCRAMWrite $0000
	
	; Write the palette to CRAM
	lea    C64Palette,a0			; Move palette address to a0
	move.w #size_palette_w*number_of_palettes-1,d0	; Loop counter = 8 words in palette (-1 for DBRA loop)
PalLp:								; Start of loop
	move.w (a0)+,vdp_data			; Write palette entry, post-increment address
	dbra d0,PalLp					; Decrement d0 and loop until finished (when d0 reaches -1)
	
	; Setup the VDP to write to VRAM address 0x0000 (the address of the first graphics tile, index 0)
	SetVRAMWriteConst vram_addr_tiles
	
	;==============================================================
	; Write the font glyph tiles to VRAM
	;==============================================================
	lea    UridiumCharSet,a0					; Move the address of the first graphics tile into a0
	move.w #(tile_count*(size_tile_l))-1,d0	; Loop counter = 8 longwords per tile * num tiles (-1 for DBRA loop)
CharLp:											; Start of loop
	move.l (a0)+,vdp_data						; Write tile line (4 bytes per line), and post-increment address
	dbra d0,CharLp								; Decrement d0 and loop until finished (when d0 reaches -1)
	
	;==============================================================
	; Write the sprites tiles to VRAM
	;==============================================================
	SetVRAMWriteConst (vram_addr_tiles+size_tile_b)+tile_count*size_tile_b
	; Write the sprite tiles to VRAM
	lea    SpritesManta,a0						; Move the address of the first graphics tile into a0
	move.w #(sprite_count*(size_tile_l))-1,d0	; Loop counter = 8 longwords per tile * num tiles (-1 for DBRA loop)
SpriteLp:										; Start of loop
	move.l (a0)+,vdp_data						; Write tile line (4 bytes per line), and post-increment address
	dbra d0,SpriteLp							; Decrement d0 and loop until finished (when d0 reaches -1)
	

	; just writing some garbage to the VRAM for debugging purposes - testing character generator
	lea vram_addr_plane_a,a0
	SetVRAMWriteReg a0
	
	move.w #$0,d0	; row count
	move.w #$0,d1
	move.w #$25,d2	; fill the whole screen
loop:
	
	move.w d1,vdp_data
	add.w #1,d0
	add.w #1,d1
	cmp.w #40,d0
	bne.s loop
	
	move.w #0,d0
	add.w #$80,a0			; set next row down from current row.
	SetVRAMWriteReg a0		; set vdp_control
	dbra d2,loop
	
	; WIP - add all the other character sets as well ( there are three others to add )
	; Clear RAM (top 64k of memory space)
    move.l #$00000000,d0       ; We're going to write zeroes over the whole of RAM, 4 bytes at a time
    move.l #$00000000,a0       ; Starting from address 0x0, clearing backwards
    move.l #$00003FFF,d1       ; Clear 64k, 4 bytes at a time. That's 16383 writes
ClearRAM:
    move.l d0,-(a0)            ; Decrement address by 4 bytes and then copy our zero to that address
    dbra d1,ClearRAM           ; Decrement loop counter d1, exiting when it reaches zero
	
	;==============================================================
	; Initialise status register and set interrupt level.
	; This begins firing vertical and horizontal interrupts.
	;==============================================================
	move.w #$2300,sr
	jmp Main
	
	include 'uridium.asm'	; main program is here.
	include 'utility.asm' ; utility functions here

	
	;==============================================================
	; INTERRUPT ROUTINES
	;==============================================================
	; The interrupt routines, as specified in the vector table at
	; the top of the file.
	; Note that we use RTE to return from an interrupt, not
	; RTS like a subroutine.
	;==============================================================

	; Vertical interrupt - run once per frame
INT_VInterrupt:
	; Doesn't do anything in this demo
	rte

	; Horizontal interrupt - run once per N scanlines (N = specified in VDP register 0xA)
INT_HInterrupt:
	; Doesn't do anything in this demo
	rte

	; NULL interrupt - for interrupts we don't care about
INT_Null:
	rte

	; Exception interrupt - called if an error has occured
CPU_Exception:
	; Just halt the CPU if an error occurred. Later on, you may want to write
	; an exception handler to draw the current state of the machine to screen
	; (registers, stack, error type, etc) to help debug the problem.
	stop  #$2700
	rte

PSGData:
   dc.w $9fbf,$dfff

Z80Data:
   dc.w $af01,$d91f
   dc.w $1127,$0021
   dc.w $2600,$f977
   dc.w $edb0,$dde1
   dc.w $fde1,$ed47
   dc.w $ed4f,$d1e1
   dc.w $f108,$d9c1
   dc.w $d1e1,$f1f9
   dc.w $f3ed,$5636
   dc.w $e9e9,$8104
   dc.w $8f01
