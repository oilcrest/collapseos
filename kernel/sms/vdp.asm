; vdp - console on SMS' VDP
;
; Implement PutC on the console. Characters start at the top left. Every PutC
; call converts the ASCII char received to its internal font, then put that
; char on screen, advancing the cursor by one. When reaching the end of the
; line (33rd char), wrap to the next.
;
; In the future, there's going to be a scrolling mechanism when we reach the
; bottom of the screen, but for now, when the end of the screen is reached, we
; wrap up to the top.
;
; *** Consts ***
;
.equ	VDP_CTLPORT	0xbf
.equ	VDP_DATAPORT	0xbe

; *** Variables ***
;
.equ	VDP_ROW		VDP_RAMSTART
.equ	VDP_LINE	VDP_ROW+1
.equ	VDP_RAMEND	VDP_LINE+1

; *** Code ***

vdpInit:
	xor	a
	ld	(VDP_ROW), a
	ld	(VDP_LINE), a

	ld	hl, vdpInitData
	ld	b, vdpInitDataEnd-vdpInitData
	ld	c, VDP_CTLPORT
	otir

	xor	a
	out	(VDP_CTLPORT), a
	ld	a, 0x40
	out	(VDP_CTLPORT), a
	ld	bc, 0x4000
.loop1:
	xor	a
	out	(VDP_DATAPORT), a
	dec	bc
	ld	a, b
	or	c
	jr	nz, .loop1

	xor	a
	out	(VDP_CTLPORT), a
	ld	a, 0xc0
	out	(VDP_CTLPORT), a
	ld	hl, vdpPaletteData
	ld	b, vdpPaletteDataEnd-vdpPaletteData
	ld	c, VDP_DATAPORT
	otir

	xor	a
	out	(VDP_CTLPORT), a
	ld	a, 0x40
	out	(VDP_CTLPORT), a
	ld	hl, vdpFontData
	ld	bc, vdpFontDataEnd-vdpFontData
.loop2:
	ld	a, (hl)
	out	(VDP_DATAPORT), a
	inc	hl
	dec	bc
	ld	a, b
	or	c
	jr	nz, .loop2

	ld	a, 0b11000000
	out	(VDP_CTLPORT), a
	ld	a, 0x81
	out	(VDP_CTLPORT), a
	ret

vdpPutC:
	; First, let's place our cursor. We need to first send our LSB, whose
	; 6 low bits contain our row*2 (each tile is 2 bytes wide) and high
	; 2 bits are the two low bits of our line
	; special case: line feed, carriage return
	cp	ASCII_LF
	jr	z, vdpLF
	cp	ASCII_CR
	jr	z, vdpCR
	; ... but first, let's convert it.
	call	vdpConv
	; ... and store it away
	ex	af, af'
	push	bc
	ld	b, 0		; we push rotated bits from VDP_LINE into B so
				; that we'll already have our low bits from the
				; second byte we'll send right after.
	ld	a, (VDP_LINE)
	sla	a		; should always push 0, so no pushing in B
	sla	a		; same
	sla	a		; same
	sla	a \ rl b
	sla	a \ rl b
	sla	a \ rl b
	ld	c, a
	ld	a, (VDP_ROW)
	sla	a		; A * 2
	or	c		; bring in two low bits from VDP_LINE into high
				; two bits
	out	(VDP_CTLPORT), a
	ld	a, b		; 3 low bits set
	or	0x78
	out	(VDP_CTLPORT), a
	pop	bc

	; We're ready to send our data now. Let's go
	ex	af, af'
	out	(VDP_DATAPORT), a

	; Move cursor. The screen is 32x24
	ex	af, af'
	ld	a, (VDP_ROW)
	cp	31
	jr	z, .incline
	; We just need to increase row
	inc	a
	ld	(VDP_ROW), a
	ex	af, af'		; bring back orig A
	ret
.incline:
	; increase line and start anew
	ex	af, af'		; bring back orig A
	call	vdpCR
	jr	vdpLF

vdpCR:
	push	af
	xor	a
	ld	(VDP_ROW), a
	pop	af
	ret

vdpLF:
	push	af
	ld	a, (VDP_LINE)
	inc	a
	cp	24
	jr	nz, .norollover
	; bottom reached, roll over to top of screen
	xor	a
.norollover:
	ld	(VDP_LINE), a
	pop	af
	ret

; Convert ASCII char in A into a tile index corresponding to that character.
; When a character is unknown, returns 0x5e (a '~' char).
vdpConv:
	; The font is organized to closely match ASCII, so this is rather easy.
	; We simply subtract 0x20 from incoming A
	sub	0x20
	cp	0x5f
	ret	c		; A < 0x5f, good
	ld	a, 0x5e
	ret

vdpPaletteData:
.db 0x00,0x3f
vdpPaletteDataEnd:

; VDP initialisation data
vdpInitData:
.db 0x04,0x80,0x00,0x81,0xff,0x82,0xff,0x85,0xff,0x86,0xff,0x87,0x00,0x88,0x00,0x89,0xff,0x8a
vdpInitDataEnd:

vdpFontData:
.db 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00
.db 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00
.db 0x18,0x00,0x00,0x00,0x18,0x00,0x00,0x00,0x18,0x00,0x00,0x00,0x18,0x00,0x00,0x00
.db 0x18,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x18,0x00,0x00,0x00,0x00,0x00,0x00,0x00
.db 0x6C,0x00,0x00,0x00,0x6C,0x00,0x00,0x00,0x6C,0x00,0x00,0x00,0x00,0x00,0x00,0x00
.db 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00
.db 0x36,0x00,0x00,0x00,0x36,0x00,0x00,0x00,0x7F,0x00,0x00,0x00,0x36,0x00,0x00,0x00
.db 0x7F,0x00,0x00,0x00,0x36,0x00,0x00,0x00,0x36,0x00,0x00,0x00,0x00,0x00,0x00,0x00
.db 0x0C,0x00,0x00,0x00,0x3F,0x00,0x00,0x00,0x68,0x00,0x00,0x00,0x3E,0x00,0x00,0x00
.db 0x0B,0x00,0x00,0x00,0x7E,0x00,0x00,0x00,0x18,0x00,0x00,0x00,0x00,0x00,0x00,0x00
.db 0x60,0x00,0x00,0x00,0x66,0x00,0x00,0x00,0x0C,0x00,0x00,0x00,0x18,0x00,0x00,0x00
.db 0x30,0x00,0x00,0x00,0x66,0x00,0x00,0x00,0x06,0x00,0x00,0x00,0x00,0x00,0x00,0x00
.db 0x38,0x00,0x00,0x00,0x6C,0x00,0x00,0x00,0x6C,0x00,0x00,0x00,0x38,0x00,0x00,0x00
.db 0x6D,0x00,0x00,0x00,0x66,0x00,0x00,0x00,0x3B,0x00,0x00,0x00,0x00,0x00,0x00,0x00
.db 0x0C,0x00,0x00,0x00,0x18,0x00,0x00,0x00,0x30,0x00,0x00,0x00,0x00,0x00,0x00,0x00
.db 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00
.db 0x0C,0x00,0x00,0x00,0x18,0x00,0x00,0x00,0x30,0x00,0x00,0x00,0x30,0x00,0x00,0x00
.db 0x30,0x00,0x00,0x00,0x18,0x00,0x00,0x00,0x0C,0x00,0x00,0x00,0x00,0x00,0x00,0x00
.db 0x30,0x00,0x00,0x00,0x18,0x00,0x00,0x00,0x0C,0x00,0x00,0x00,0x0C,0x00,0x00,0x00
.db 0x0C,0x00,0x00,0x00,0x18,0x00,0x00,0x00,0x30,0x00,0x00,0x00,0x00,0x00,0x00,0x00
.db 0x00,0x00,0x00,0x00,0x18,0x00,0x00,0x00,0x7E,0x00,0x00,0x00,0x3C,0x00,0x00,0x00
.db 0x7E,0x00,0x00,0x00,0x18,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00
.db 0x00,0x00,0x00,0x00,0x18,0x00,0x00,0x00,0x18,0x00,0x00,0x00,0x7E,0x00,0x00,0x00
.db 0x18,0x00,0x00,0x00,0x18,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00
.db 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00
.db 0x00,0x00,0x00,0x00,0x18,0x00,0x00,0x00,0x18,0x00,0x00,0x00,0x30,0x00,0x00,0x00
.db 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x7E,0x00,0x00,0x00
.db 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00
.db 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00
.db 0x00,0x00,0x00,0x00,0x18,0x00,0x00,0x00,0x18,0x00,0x00,0x00,0x00,0x00,0x00,0x00
.db 0x00,0x00,0x00,0x00,0x06,0x00,0x00,0x00,0x0C,0x00,0x00,0x00,0x18,0x00,0x00,0x00
.db 0x30,0x00,0x00,0x00,0x60,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00
.db 0x3C,0x00,0x00,0x00,0x66,0x00,0x00,0x00,0x6E,0x00,0x00,0x00,0x7E,0x00,0x00,0x00
.db 0x76,0x00,0x00,0x00,0x66,0x00,0x00,0x00,0x3C,0x00,0x00,0x00,0x00,0x00,0x00,0x00
.db 0x18,0x00,0x00,0x00,0x38,0x00,0x00,0x00,0x18,0x00,0x00,0x00,0x18,0x00,0x00,0x00
.db 0x18,0x00,0x00,0x00,0x18,0x00,0x00,0x00,0x7E,0x00,0x00,0x00,0x00,0x00,0x00,0x00
.db 0x3C,0x00,0x00,0x00,0x66,0x00,0x00,0x00,0x06,0x00,0x00,0x00,0x0C,0x00,0x00,0x00
.db 0x18,0x00,0x00,0x00,0x30,0x00,0x00,0x00,0x7E,0x00,0x00,0x00,0x00,0x00,0x00,0x00
.db 0x3C,0x00,0x00,0x00,0x66,0x00,0x00,0x00,0x06,0x00,0x00,0x00,0x1C,0x00,0x00,0x00
.db 0x06,0x00,0x00,0x00,0x66,0x00,0x00,0x00,0x3C,0x00,0x00,0x00,0x00,0x00,0x00,0x00
.db 0x0C,0x00,0x00,0x00,0x1C,0x00,0x00,0x00,0x3C,0x00,0x00,0x00,0x6C,0x00,0x00,0x00
.db 0x7E,0x00,0x00,0x00,0x0C,0x00,0x00,0x00,0x0C,0x00,0x00,0x00,0x00,0x00,0x00,0x00
.db 0x7E,0x00,0x00,0x00,0x60,0x00,0x00,0x00,0x7C,0x00,0x00,0x00,0x06,0x00,0x00,0x00
.db 0x06,0x00,0x00,0x00,0x66,0x00,0x00,0x00,0x3C,0x00,0x00,0x00,0x00,0x00,0x00,0x00
.db 0x1C,0x00,0x00,0x00,0x30,0x00,0x00,0x00,0x60,0x00,0x00,0x00,0x7C,0x00,0x00,0x00
.db 0x66,0x00,0x00,0x00,0x66,0x00,0x00,0x00,0x3C,0x00,0x00,0x00,0x00,0x00,0x00,0x00
.db 0x7E,0x00,0x00,0x00,0x06,0x00,0x00,0x00,0x0C,0x00,0x00,0x00,0x18,0x00,0x00,0x00
.db 0x30,0x00,0x00,0x00,0x30,0x00,0x00,0x00,0x30,0x00,0x00,0x00,0x00,0x00,0x00,0x00
.db 0x3C,0x00,0x00,0x00,0x66,0x00,0x00,0x00,0x66,0x00,0x00,0x00,0x3C,0x00,0x00,0x00
.db 0x66,0x00,0x00,0x00,0x66,0x00,0x00,0x00,0x3C,0x00,0x00,0x00,0x00,0x00,0x00,0x00
.db 0x3C,0x00,0x00,0x00,0x66,0x00,0x00,0x00,0x66,0x00,0x00,0x00,0x3E,0x00,0x00,0x00
.db 0x06,0x00,0x00,0x00,0x0C,0x00,0x00,0x00,0x38,0x00,0x00,0x00,0x00,0x00,0x00,0x00
.db 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x18,0x00,0x00,0x00,0x18,0x00,0x00,0x00
.db 0x00,0x00,0x00,0x00,0x18,0x00,0x00,0x00,0x18,0x00,0x00,0x00,0x00,0x00,0x00,0x00
.db 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x18,0x00,0x00,0x00,0x18,0x00,0x00,0x00
.db 0x00,0x00,0x00,0x00,0x18,0x00,0x00,0x00,0x18,0x00,0x00,0x00,0x30,0x00,0x00,0x00
.db 0x0C,0x00,0x00,0x00,0x18,0x00,0x00,0x00,0x30,0x00,0x00,0x00,0x60,0x00,0x00,0x00
.db 0x30,0x00,0x00,0x00,0x18,0x00,0x00,0x00,0x0C,0x00,0x00,0x00,0x00,0x00,0x00,0x00
.db 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x7E,0x00,0x00,0x00,0x00,0x00,0x00,0x00
.db 0x7E,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00
.db 0x30,0x00,0x00,0x00,0x18,0x00,0x00,0x00,0x0C,0x00,0x00,0x00,0x06,0x00,0x00,0x00
.db 0x0C,0x00,0x00,0x00,0x18,0x00,0x00,0x00,0x30,0x00,0x00,0x00,0x00,0x00,0x00,0x00
.db 0x3C,0x00,0x00,0x00,0x66,0x00,0x00,0x00,0x0C,0x00,0x00,0x00,0x18,0x00,0x00,0x00
.db 0x18,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x18,0x00,0x00,0x00,0x00,0x00,0x00,0x00
.db 0x3C,0x00,0x00,0x00,0x66,0x00,0x00,0x00,0x6E,0x00,0x00,0x00,0x6A,0x00,0x00,0x00
.db 0x6E,0x00,0x00,0x00,0x60,0x00,0x00,0x00,0x3C,0x00,0x00,0x00,0x00,0x00,0x00,0x00
.db 0x3C,0x00,0x00,0x00,0x66,0x00,0x00,0x00,0x66,0x00,0x00,0x00,0x7E,0x00,0x00,0x00
.db 0x66,0x00,0x00,0x00,0x66,0x00,0x00,0x00,0x66,0x00,0x00,0x00,0x00,0x00,0x00,0x00
.db 0x7C,0x00,0x00,0x00,0x66,0x00,0x00,0x00,0x66,0x00,0x00,0x00,0x7C,0x00,0x00,0x00
.db 0x66,0x00,0x00,0x00,0x66,0x00,0x00,0x00,0x7C,0x00,0x00,0x00,0x00,0x00,0x00,0x00
.db 0x3C,0x00,0x00,0x00,0x66,0x00,0x00,0x00,0x60,0x00,0x00,0x00,0x60,0x00,0x00,0x00
.db 0x60,0x00,0x00,0x00,0x66,0x00,0x00,0x00,0x3C,0x00,0x00,0x00,0x00,0x00,0x00,0x00
.db 0x78,0x00,0x00,0x00,0x6C,0x00,0x00,0x00,0x66,0x00,0x00,0x00,0x66,0x00,0x00,0x00
.db 0x66,0x00,0x00,0x00,0x6C,0x00,0x00,0x00,0x78,0x00,0x00,0x00,0x00,0x00,0x00,0x00
.db 0x7E,0x00,0x00,0x00,0x60,0x00,0x00,0x00,0x60,0x00,0x00,0x00,0x7C,0x00,0x00,0x00
.db 0x60,0x00,0x00,0x00,0x60,0x00,0x00,0x00,0x7E,0x00,0x00,0x00,0x00,0x00,0x00,0x00
.db 0x7E,0x00,0x00,0x00,0x60,0x00,0x00,0x00,0x60,0x00,0x00,0x00,0x7C,0x00,0x00,0x00
.db 0x60,0x00,0x00,0x00,0x60,0x00,0x00,0x00,0x60,0x00,0x00,0x00,0x00,0x00,0x00,0x00
.db 0x3C,0x00,0x00,0x00,0x66,0x00,0x00,0x00,0x60,0x00,0x00,0x00,0x6E,0x00,0x00,0x00
.db 0x66,0x00,0x00,0x00,0x66,0x00,0x00,0x00,0x3C,0x00,0x00,0x00,0x00,0x00,0x00,0x00
.db 0x66,0x00,0x00,0x00,0x66,0x00,0x00,0x00,0x66,0x00,0x00,0x00,0x7E,0x00,0x00,0x00
.db 0x66,0x00,0x00,0x00,0x66,0x00,0x00,0x00,0x66,0x00,0x00,0x00,0x00,0x00,0x00,0x00
.db 0x7E,0x00,0x00,0x00,0x18,0x00,0x00,0x00,0x18,0x00,0x00,0x00,0x18,0x00,0x00,0x00
.db 0x18,0x00,0x00,0x00,0x18,0x00,0x00,0x00,0x7E,0x00,0x00,0x00,0x00,0x00,0x00,0x00
.db 0x3E,0x00,0x00,0x00,0x0C,0x00,0x00,0x00,0x0C,0x00,0x00,0x00,0x0C,0x00,0x00,0x00
.db 0x0C,0x00,0x00,0x00,0x6C,0x00,0x00,0x00,0x38,0x00,0x00,0x00,0x00,0x00,0x00,0x00
.db 0x66,0x00,0x00,0x00,0x6C,0x00,0x00,0x00,0x78,0x00,0x00,0x00,0x70,0x00,0x00,0x00
.db 0x78,0x00,0x00,0x00,0x6C,0x00,0x00,0x00,0x66,0x00,0x00,0x00,0x00,0x00,0x00,0x00
.db 0x60,0x00,0x00,0x00,0x60,0x00,0x00,0x00,0x60,0x00,0x00,0x00,0x60,0x00,0x00,0x00
.db 0x60,0x00,0x00,0x00,0x60,0x00,0x00,0x00,0x7E,0x00,0x00,0x00,0x00,0x00,0x00,0x00
.db 0x63,0x00,0x00,0x00,0x77,0x00,0x00,0x00,0x7F,0x00,0x00,0x00,0x6B,0x00,0x00,0x00
.db 0x6B,0x00,0x00,0x00,0x63,0x00,0x00,0x00,0x63,0x00,0x00,0x00,0x00,0x00,0x00,0x00
.db 0x66,0x00,0x00,0x00,0x66,0x00,0x00,0x00,0x76,0x00,0x00,0x00,0x7E,0x00,0x00,0x00
.db 0x6E,0x00,0x00,0x00,0x66,0x00,0x00,0x00,0x66,0x00,0x00,0x00,0x00,0x00,0x00,0x00
.db 0x3C,0x00,0x00,0x00,0x66,0x00,0x00,0x00,0x66,0x00,0x00,0x00,0x66,0x00,0x00,0x00
.db 0x66,0x00,0x00,0x00,0x66,0x00,0x00,0x00,0x3C,0x00,0x00,0x00,0x00,0x00,0x00,0x00
.db 0x7C,0x00,0x00,0x00,0x66,0x00,0x00,0x00,0x66,0x00,0x00,0x00,0x7C,0x00,0x00,0x00
.db 0x60,0x00,0x00,0x00,0x60,0x00,0x00,0x00,0x60,0x00,0x00,0x00,0x00,0x00,0x00,0x00
.db 0x3C,0x00,0x00,0x00,0x66,0x00,0x00,0x00,0x66,0x00,0x00,0x00,0x66,0x00,0x00,0x00
.db 0x6A,0x00,0x00,0x00,0x6C,0x00,0x00,0x00,0x36,0x00,0x00,0x00,0x00,0x00,0x00,0x00
.db 0x7C,0x00,0x00,0x00,0x66,0x00,0x00,0x00,0x66,0x00,0x00,0x00,0x7C,0x00,0x00,0x00
.db 0x6C,0x00,0x00,0x00,0x66,0x00,0x00,0x00,0x66,0x00,0x00,0x00,0x00,0x00,0x00,0x00
.db 0x3C,0x00,0x00,0x00,0x66,0x00,0x00,0x00,0x60,0x00,0x00,0x00,0x3C,0x00,0x00,0x00
.db 0x06,0x00,0x00,0x00,0x66,0x00,0x00,0x00,0x3C,0x00,0x00,0x00,0x00,0x00,0x00,0x00
.db 0x7E,0x00,0x00,0x00,0x18,0x00,0x00,0x00,0x18,0x00,0x00,0x00,0x18,0x00,0x00,0x00
.db 0x18,0x00,0x00,0x00,0x18,0x00,0x00,0x00,0x18,0x00,0x00,0x00,0x00,0x00,0x00,0x00
.db 0x66,0x00,0x00,0x00,0x66,0x00,0x00,0x00,0x66,0x00,0x00,0x00,0x66,0x00,0x00,0x00
.db 0x66,0x00,0x00,0x00,0x66,0x00,0x00,0x00,0x3C,0x00,0x00,0x00,0x00,0x00,0x00,0x00
.db 0x66,0x00,0x00,0x00,0x66,0x00,0x00,0x00,0x66,0x00,0x00,0x00,0x66,0x00,0x00,0x00
.db 0x66,0x00,0x00,0x00,0x3C,0x00,0x00,0x00,0x18,0x00,0x00,0x00,0x00,0x00,0x00,0x00
.db 0x63,0x00,0x00,0x00,0x63,0x00,0x00,0x00,0x6B,0x00,0x00,0x00,0x6B,0x00,0x00,0x00
.db 0x7F,0x00,0x00,0x00,0x77,0x00,0x00,0x00,0x63,0x00,0x00,0x00,0x00,0x00,0x00,0x00
.db 0x66,0x00,0x00,0x00,0x66,0x00,0x00,0x00,0x3C,0x00,0x00,0x00,0x18,0x00,0x00,0x00
.db 0x3C,0x00,0x00,0x00,0x66,0x00,0x00,0x00,0x66,0x00,0x00,0x00,0x00,0x00,0x00,0x00
.db 0x66,0x00,0x00,0x00,0x66,0x00,0x00,0x00,0x66,0x00,0x00,0x00,0x3C,0x00,0x00,0x00
.db 0x18,0x00,0x00,0x00,0x18,0x00,0x00,0x00,0x18,0x00,0x00,0x00,0x00,0x00,0x00,0x00
.db 0x7E,0x00,0x00,0x00,0x06,0x00,0x00,0x00,0x0C,0x00,0x00,0x00,0x18,0x00,0x00,0x00
.db 0x30,0x00,0x00,0x00,0x60,0x00,0x00,0x00,0x7E,0x00,0x00,0x00,0x00,0x00,0x00,0x00
.db 0x7C,0x00,0x00,0x00,0x60,0x00,0x00,0x00,0x60,0x00,0x00,0x00,0x60,0x00,0x00,0x00
.db 0x60,0x00,0x00,0x00,0x60,0x00,0x00,0x00,0x7C,0x00,0x00,0x00,0x00,0x00,0x00,0x00
.db 0x00,0x00,0x00,0x00,0x60,0x00,0x00,0x00,0x30,0x00,0x00,0x00,0x18,0x00,0x00,0x00
.db 0x0C,0x00,0x00,0x00,0x06,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00
.db 0x3E,0x00,0x00,0x00,0x06,0x00,0x00,0x00,0x06,0x00,0x00,0x00,0x06,0x00,0x00,0x00
.db 0x06,0x00,0x00,0x00,0x06,0x00,0x00,0x00,0x3E,0x00,0x00,0x00,0x00,0x00,0x00,0x00
.db 0x18,0x00,0x00,0x00,0x3C,0x00,0x00,0x00,0x66,0x00,0x00,0x00,0x42,0x00,0x00,0x00
.db 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00
.db 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00
.db 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0xFF,0x00,0x00,0x00
.db 0x1C,0x00,0x00,0x00,0x36,0x00,0x00,0x00,0x30,0x00,0x00,0x00,0x7C,0x00,0x00,0x00
.db 0x30,0x00,0x00,0x00,0x30,0x00,0x00,0x00,0x7E,0x00,0x00,0x00,0x00,0x00,0x00,0x00
.db 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x3C,0x00,0x00,0x00,0x06,0x00,0x00,0x00
.db 0x3E,0x00,0x00,0x00,0x66,0x00,0x00,0x00,0x3E,0x00,0x00,0x00,0x00,0x00,0x00,0x00
.db 0x60,0x00,0x00,0x00,0x60,0x00,0x00,0x00,0x7C,0x00,0x00,0x00,0x66,0x00,0x00,0x00
.db 0x66,0x00,0x00,0x00,0x66,0x00,0x00,0x00,0x7C,0x00,0x00,0x00,0x00,0x00,0x00,0x00
.db 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x3C,0x00,0x00,0x00,0x66,0x00,0x00,0x00
.db 0x60,0x00,0x00,0x00,0x66,0x00,0x00,0x00,0x3C,0x00,0x00,0x00,0x00,0x00,0x00,0x00
.db 0x06,0x00,0x00,0x00,0x06,0x00,0x00,0x00,0x3E,0x00,0x00,0x00,0x66,0x00,0x00,0x00
.db 0x66,0x00,0x00,0x00,0x66,0x00,0x00,0x00,0x3E,0x00,0x00,0x00,0x00,0x00,0x00,0x00
.db 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x3C,0x00,0x00,0x00,0x66,0x00,0x00,0x00
.db 0x7E,0x00,0x00,0x00,0x60,0x00,0x00,0x00,0x3C,0x00,0x00,0x00,0x00,0x00,0x00,0x00
.db 0x1C,0x00,0x00,0x00,0x30,0x00,0x00,0x00,0x30,0x00,0x00,0x00,0x7C,0x00,0x00,0x00
.db 0x30,0x00,0x00,0x00,0x30,0x00,0x00,0x00,0x30,0x00,0x00,0x00,0x00,0x00,0x00,0x00
.db 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x3E,0x00,0x00,0x00,0x66,0x00,0x00,0x00
.db 0x66,0x00,0x00,0x00,0x3E,0x00,0x00,0x00,0x06,0x00,0x00,0x00,0x3C,0x00,0x00,0x00
.db 0x60,0x00,0x00,0x00,0x60,0x00,0x00,0x00,0x7C,0x00,0x00,0x00,0x66,0x00,0x00,0x00
.db 0x66,0x00,0x00,0x00,0x66,0x00,0x00,0x00,0x66,0x00,0x00,0x00,0x00,0x00,0x00,0x00
.db 0x18,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x38,0x00,0x00,0x00,0x18,0x00,0x00,0x00
.db 0x18,0x00,0x00,0x00,0x18,0x00,0x00,0x00,0x3C,0x00,0x00,0x00,0x00,0x00,0x00,0x00
.db 0x18,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x38,0x00,0x00,0x00,0x18,0x00,0x00,0x00
.db 0x18,0x00,0x00,0x00,0x18,0x00,0x00,0x00,0x18,0x00,0x00,0x00,0x70,0x00,0x00,0x00
.db 0x60,0x00,0x00,0x00,0x60,0x00,0x00,0x00,0x66,0x00,0x00,0x00,0x6C,0x00,0x00,0x00
.db 0x78,0x00,0x00,0x00,0x6C,0x00,0x00,0x00,0x66,0x00,0x00,0x00,0x00,0x00,0x00,0x00
.db 0x38,0x00,0x00,0x00,0x18,0x00,0x00,0x00,0x18,0x00,0x00,0x00,0x18,0x00,0x00,0x00
.db 0x18,0x00,0x00,0x00,0x18,0x00,0x00,0x00,0x3C,0x00,0x00,0x00,0x00,0x00,0x00,0x00
.db 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x36,0x00,0x00,0x00,0x7F,0x00,0x00,0x00
.db 0x6B,0x00,0x00,0x00,0x6B,0x00,0x00,0x00,0x63,0x00,0x00,0x00,0x00,0x00,0x00,0x00
.db 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x7C,0x00,0x00,0x00,0x66,0x00,0x00,0x00
.db 0x66,0x00,0x00,0x00,0x66,0x00,0x00,0x00,0x66,0x00,0x00,0x00,0x00,0x00,0x00,0x00
.db 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x3C,0x00,0x00,0x00,0x66,0x00,0x00,0x00
.db 0x66,0x00,0x00,0x00,0x66,0x00,0x00,0x00,0x3C,0x00,0x00,0x00,0x00,0x00,0x00,0x00
.db 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x7C,0x00,0x00,0x00,0x66,0x00,0x00,0x00
.db 0x66,0x00,0x00,0x00,0x7C,0x00,0x00,0x00,0x60,0x00,0x00,0x00,0x60,0x00,0x00,0x00
.db 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x3E,0x00,0x00,0x00,0x66,0x00,0x00,0x00
.db 0x66,0x00,0x00,0x00,0x3E,0x00,0x00,0x00,0x06,0x00,0x00,0x00,0x07,0x00,0x00,0x00
.db 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x6C,0x00,0x00,0x00,0x76,0x00,0x00,0x00
.db 0x60,0x00,0x00,0x00,0x60,0x00,0x00,0x00,0x60,0x00,0x00,0x00,0x00,0x00,0x00,0x00
.db 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x3E,0x00,0x00,0x00,0x60,0x00,0x00,0x00
.db 0x3C,0x00,0x00,0x00,0x06,0x00,0x00,0x00,0x7C,0x00,0x00,0x00,0x00,0x00,0x00,0x00
.db 0x30,0x00,0x00,0x00,0x30,0x00,0x00,0x00,0x7C,0x00,0x00,0x00,0x30,0x00,0x00,0x00
.db 0x30,0x00,0x00,0x00,0x30,0x00,0x00,0x00,0x1C,0x00,0x00,0x00,0x00,0x00,0x00,0x00
.db 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x66,0x00,0x00,0x00,0x66,0x00,0x00,0x00
.db 0x66,0x00,0x00,0x00,0x66,0x00,0x00,0x00,0x3E,0x00,0x00,0x00,0x00,0x00,0x00,0x00
.db 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x66,0x00,0x00,0x00,0x66,0x00,0x00,0x00
.db 0x66,0x00,0x00,0x00,0x3C,0x00,0x00,0x00,0x18,0x00,0x00,0x00,0x00,0x00,0x00,0x00
.db 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x63,0x00,0x00,0x00,0x6B,0x00,0x00,0x00
.db 0x6B,0x00,0x00,0x00,0x7F,0x00,0x00,0x00,0x36,0x00,0x00,0x00,0x00,0x00,0x00,0x00
.db 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x66,0x00,0x00,0x00,0x3C,0x00,0x00,0x00
.db 0x18,0x00,0x00,0x00,0x3C,0x00,0x00,0x00,0x66,0x00,0x00,0x00,0x00,0x00,0x00,0x00
.db 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x66,0x00,0x00,0x00,0x66,0x00,0x00,0x00
.db 0x66,0x00,0x00,0x00,0x3E,0x00,0x00,0x00,0x06,0x00,0x00,0x00,0x3C,0x00,0x00,0x00
.db 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x7E,0x00,0x00,0x00,0x0C,0x00,0x00,0x00
.db 0x18,0x00,0x00,0x00,0x30,0x00,0x00,0x00,0x7E,0x00,0x00,0x00,0x00,0x00,0x00,0x00
.db 0x0C,0x00,0x00,0x00,0x18,0x00,0x00,0x00,0x18,0x00,0x00,0x00,0x70,0x00,0x00,0x00
.db 0x18,0x00,0x00,0x00,0x18,0x00,0x00,0x00,0x0C,0x00,0x00,0x00,0x00,0x00,0x00,0x00
.db 0x18,0x00,0x00,0x00,0x18,0x00,0x00,0x00,0x18,0x00,0x00,0x00,0x00,0x00,0x00,0x00
.db 0x18,0x00,0x00,0x00,0x18,0x00,0x00,0x00,0x18,0x00,0x00,0x00,0x00,0x00,0x00,0x00
.db 0x30,0x00,0x00,0x00,0x18,0x00,0x00,0x00,0x18,0x00,0x00,0x00,0x0E,0x00,0x00,0x00
.db 0x18,0x00,0x00,0x00,0x18,0x00,0x00,0x00,0x30,0x00,0x00,0x00,0x00,0x00,0x00,0x00
.db 0x31,0x00,0x00,0x00,0x6B,0x00,0x00,0x00,0x46,0x00,0x00,0x00,0x00,0x00,0x00,0x00
.db 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00
vdpFontDataEnd:

