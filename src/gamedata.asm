
l_310a:
	dc.b $00,$90,$98,$a0,$a8,$b0,$b8,$c0
	dc.b $c4,$c8,$cc,$d0,$d4,$d8,$dc,$e0
	dc.b $e4,$e8,$ec,$f0

l_311e:
	dc.b $fe,$fd,$fb,$f7
	dc.b $ef,$df,$bf,$7f

gamedataTextP1:
	dc.b $00,$01
	dc.b $49,$15,$0a,$22,$0e,$1b,$01,$ff			; player 1 text

gamedataTextP2:
	dc.b $00,$1f
	dc.b $49,$15,$0a,$22,$0e,$1b,$02,$ff 		; player 2 text
	
gamedataText1UP:			
	dc.b $00,$01,$01,$1e,$19,$30,$7a,$7b			;1up
l_3142:	
	dc.b $30,$03,$ff 								;3 lives.
gamedataText2UP:		
	dc.b $00,$1f,$7a,$7b
	
l_3149:
	dc.b $30,$03,$30,$02,$1e,$19,$ff

gamedataTextBlankLine:	
	dc.b $00,$0f
	dc.b $30,$30,$30,$30,$30,$30,$30,$30
	dc.b $30,$30,$30,$ff

;land now
l_315e:
	dc.b $00,$0f,$45,$0a
	dc.b $17,$0d,$30,$17,$18,$54,$25,$ff
	
; Colour ram table for player colours

l_316a:
	dc.b $0e,$0e,$0e,$0e,$0e,$0e,$0e,$0e
	dc.b $0e,$0e,$0a,$0a,$0a,$0a,$0a,$0a
	dc.b $0a,$0a,$0a,$0a,$0a,$0a,$0a,$0a
	dc.b $0a,$0a,$0a,$0a,$0a,$0a,$0e,$0e
	dc.b $0e,$0e,$0e,$0e,$0e,$0e,$0e,$0e
l_3192:
	dc.b $0d,$0d,$0d,$0d,$0d,$0d,$0d,$0d
	dc.b $0d,$0d,$01,$01,$01,$01,$01,$01
	dc.b $01,$01,$01,$01,$01,$01,$01,$01
	dc.b $01,$01,$01,$01,$01,$01,$0d,$0d
	dc.b $0d,$0d,$0d,$0d,$0d,$0d,$0d,$0d
	
	dc.b $05,$05,$05,$05,$05,$05,$05,$05
	dc.b $05,$05,$07,$07,$07,$07,$07,$07
	dc.b $07,$07,$07,$07,$07,$07,$07,$07
	dc.b $07,$07,$07,$07,$07,$07,$05,$05
	dc.b $05,$05,$05,$05,$05,$05,$05,$05	
	

l_349f:	
	dc.b $4e,$1b,$12
	dc.b $0d,$12,$1e,$42,$30,$0b,$22,$30
	dc.b $3a,$17,$0d,$1b,$0e,$54,$30,$3b
	dc.b $1b,$0a,$22,$0b,$1b,$18,$18,$14
	dc.b $28,$30,$41,$12,$10,$11,$30,$2e
l_34c2:	  
	dc.b $30
	
; high score scrolling - "12000 AEB"
l_34c3:
	dc.b $01,$02,$00,$00,$00,$30,$3a
	dc.b $3e,$3b,$ff,$ff,$ff,$ff
	
l_34d0:	
	dc.b $00,$0f
	dc.b $30,$30,$55,$55,$30,$56,$30,$30
	dc.b $ff
	
l_34db:
	dc.b $00,$0f,$30,$55,$55,$30,$56
	dc.b $56,$30,$ff

l_34e5:
	dc.b $00,$0f,$30,$30,$30
	dc.b $55,$30,$56,$30,$30,$30,$ff

gameTextColour:
	dc.b $02
	dc.b $0a,$57,$ff

l_34f5:
	dc.b $02
	dc.b $0a,$58,$ff

gameTextUridium:
	dc.b $02
	dc.b $0A,$30,$30,$30,$30,$30,$31,$32
	dc.b $33,$34,$35,$36,$37,$38,$39,$7D
	dc.b $30,$30,$30,$30,$30,$ff


gameTextHighScore:
	dc.b $02,$0a
	dc.b $30,$30,$30,$30,$30,$41,$12,$2e
	dc.b $1c,$0c,$18,$1b,$0e,$30,$30,$30
	dc.b $30,$30,$30,$ff

gameTextHighAEB:
	dc.b $02,$0A,$30,$30
	
l_352a:
	dc.b $30,$30,$30,$01,$02,$00,$00,$00
	dc.b $30,$3a,$3e,$3b,$30,$30,$30,$ff

l_353a:
	dc.b $02,$0c,$30,$30,$30,$30,$30,$55
	dc.b $55,$30,$30,$30,$30,$30,$56,$56,$ff

l_354b:
	dc.b $02,$0c,$30,$30,$30,$30,$30
	dc.b $55,$30,$30,$30,$30,$30,$30,$30
	dc.b $30,$30,$56,$ff

l_355e:
	dc.b $02,$0c,$30,$30
	dc.b $30,$30,$30,$55,$55,$30,$30,$30
	dc.b $30,$30,$30,$30,$56,$ff
	
	even
l_3570:
	dc.l l_353a,l_354b,l_355e
l_3573:
	;dc.b >l_353a,>l_354b,>l_355e
	
gamedataTextHEWSON:
	dc.b $06,$0e,$41,$3e
	dc.b $50,$4c,$48,$47,$ff

gamedataTextPresents:
	dc.b $09,$10,$19
	dc.b $1b,$0e,$1c,$0e,$17,$1d,$1c,$ff

gamedataTextURIDIUM:		
	dc.b $0c,$0f,$31,$32,$33,$34,$35,$36
	dc.b $37,$38,$39,$7d,$ff

gamedataTextGraftGold:
	dc.b $0f,$07,$59
	dc.b $30,$40,$1b,$0a,$0f,$1d,$10,$18
	dc.b $15,$0d,$30,$45,$1d,$0d,$28,$30
	dc.b $01,$09,$08,$06,$28,$ff

gamedataTextDesignedBy:
	dc.b $12,$05
	dc.b $3d,$0e,$1c,$12,$10,$17,$0e,$0d
	dc.b $30,$0a,$17,$0d,$30,$19,$1b,$18
	dc.b $10,$1b,$0a,$42,$42,$0e,$0d,$30
	dc.b $0b,$22,$ff

gamedataTextAndrew:
	dc.b $15,$0b,$3a,$17,$0d
	dc.b $1b,$0e,$54,$30,$3b,$1b,$0a,$22
	dc.b $0b,$1b,$18,$18,$14,$28,$ff
	
l_36a0:
	dc.b $00,$0f
	dc.b $30,$30,$3c,$18,$15,$18,$1e,$1b
	dc.b $30,$30,$ff

l_36ad:
	dc.b $00,$0f,$3b,$15,$0c
	dc.b $14,$2e,$50,$11,$1d,$0e,$ff
