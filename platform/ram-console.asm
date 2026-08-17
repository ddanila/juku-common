; DIP-selectable bitmap console for RAM-owned Juku systems.
; Copyright (c) 2026 Danila Sukharev
; BSD-2-Clause; see ../LICENSE-BSD-2-Clause.
;
; Period MODX evidence establishes a 50-byte (400-pixel) scanline, a 5x7
; font, an eighth blank/cursor scanline, and 9,600 framebuffer bytes.  The
; screen is therefore 80x24 even though one contemporary note calls it 80x25.
;
; Code executes below D800h. Framebuffer read/modify/write requires memory
; mode 3. A transitional consumer restores mode 1; a fully RAM-owned system
; keeps mode 3 selected.

MODEPORT        equ     006h
VRAM            equ     0d800h
SCREENBYTES     equ     9600
CURSORPERIOD    equ     0200h           ; about 0.35 s per phase on CS00015

.ifdef RAMKEYBOARD
        extrn   RKCONFIG
.endif

; Exact MODX writes after the stock video setup. They change the scan timing
; from the normal 320-pixel mode to its 400-pixel mode. Reset remains the
; documented way back to the stock modes.
RAMMODXVIDEO:
        mvi     a,073h
        out     017h
        mvi     a,014h
        out     011h
        mvi     a,003h
        out     012h
        mvi     a,01ah
        out     015h
        mvi     a,001h
        out     015h
        mvi     a,045h
        out     016h
        ret

; S21 bits 2:1 select the same historical modes exposed by EktaSoft's ESC M n:
; 00 = 40x24, 01 = 53x24, 10 = 64x20, 11 = MODX-compatible 80x24.
; The first two share stock 320x241 raster timing; 64x20 uses 384x201.
; Bits 4:3 select 00 English, 01 Estonian, 10 Russian CP866, and 11 the
; English/user-remap fallback. Locale glyphs share this renderer and retain
; the CP437 B0h..DFh text-interface bank.
RAMSETMODE:
        sta     RAMVIDMODE
        ora     a
        jz      RAMMODE40
        dcr     a
        jz      RAMMODE53
        dcr     a
        jz      RAMMODE64
RAMMODE80:
        mvi     a,80
        sta     RAMCOLS
        mvi     a,24
        sta     RAMROWS
        mvi     a,5
        sta     RAMCELLWIDTH
        mvi     a,8
        sta     RAMCELLHEIGHT
        mvi     a,0f8h
        sta     RAMCELLMASK
        mvi     a,50
        sta     RAMVIDSTRIDE
        lxi     h,400
        shld    RAMROWBYTES
        lxi     h,350
        shld    RAMCURSORLINE
        jmp     RAMMODXVIDEO
RAMMODE40:
        mvi     a,40
        sta     RAMCOLS
        mvi     a,8
        sta     RAMCELLWIDTH
        mvi     a,0ffh
        sta     RAMCELLMASK
        jmp     RAMMODESTOCK
RAMMODE53:
        mvi     a,53
        sta     RAMCOLS
        mvi     a,6
        sta     RAMCELLWIDTH
        mvi     a,0fch
        sta     RAMCELLMASK
RAMMODESTOCK:
        mvi     a,24
        sta     RAMROWS
        mvi     a,10
        sta     RAMCELLHEIGHT
        mvi     a,40
        sta     RAMVIDSTRIDE
        lxi     h,400
        shld    RAMROWBYTES
        lxi     h,360
        shld    RAMCURSORLINE
        mvi     a,024h
        out     011h
        mvi     a,008h
        out     012h
        mvi     a,072h
        out     015h
        xra     a
        out     015h
        mvi     a,025h
        out     016h
        ret
RAMMODE64:
        mvi     a,64
        sta     RAMCOLS
        mvi     a,20
        sta     RAMROWS
        mvi     a,6
        sta     RAMCELLWIDTH
        mvi     a,10
        sta     RAMCELLHEIGHT
        mvi     a,0fch
        sta     RAMCELLMASK
        mvi     a,48
        sta     RAMVIDSTRIDE
        lxi     h,480
        shld    RAMROWBYTES
        lxi     h,432
        shld    RAMCURSORLINE
        mvi     a,016h
        out     011h
        mvi     a,004h
        out     012h
        mvi     a,012h
        out     015h
        mvi     a,001h
        out     015h
        mvi     a,045h
        out     016h
        ret

RAMCONINIT:
        xra     a
        sta     RAMCOL
        sta     RAMROW
        sta     RAMESC
        sta     RAMCURVISIBLE
        call    RAMCURSORRELOAD
        call    RKCONFIG
        sta     RAMCONFIG
.ifdef RAMLOCALEFONTS
        push    psw
        rrc
        rrc
        rrc
        ani     3
        sta     RAMLOCALE
        pop     psw
.endif
        rrc
        ani     3
        call    RAMSETMODE
        call    RAMVIDEO
        lxi     h,VRAM
        lxi     b,SCREENBYTES
        call    RAMCLEAR
        jmp     RAMNORMAL

; A = character. Preserve every caller-visible register.
RAMCONOUT:
        push    psw
        push    b
        push    d
        push    h
        sta     RAMOUTCHAR
        call    RAMCURSORHIDE
        lda     RAMOUTCHAR
        mov     e,a

        lda     RAMESC
        ora     a
        jz      RAMNOESC
        xra     a
        sta     RAMESC
        mov     a,e
        cpi     'L'
        cz      RAMCONINIT
        jmp     RAMOUTDONE

RAMNOESC:
        mov     a,e
        cpi     01bh
        jnz     RAMNOTESC
        mvi     a,1
        sta     RAMESC
        jmp     RAMOUTDONE
RAMNOTESC:
        cpi     0dh
        jnz     RAMNOTCR
        xra     a
        sta     RAMCOL
        jmp     RAMOUTDONE
RAMNOTCR:
        cpi     0ah
        jnz     RAMNOTLF
        call    RAMNEWLINE
        jmp     RAMOUTDONE
RAMNOTLF:
        cpi     08h
        jnz     RAMPRINTABLE
        lda     RAMCOL
        ora     a
        jz      RAMOUTDONE
        dcr     a
        sta     RAMCOL
        jmp     RAMOUTDONE

RAMPRINTABLE:
        cpi     020h
        jc      RAMOUTDONE
        cpi     07fh
        jc      RAMCHARASCII
.ifdef RAMLOCALEFONTS
        lda     RAMLOCALE
        cpi     1
        jz      RAMCHAREST
        cpi     2
        jz      RAMCHARRUS
.endif
RAMCHARPSEUDOTRY:
        lda     RAMVIDMODE
        cpi     3
        jnz     RAMCHARQUESTION
        lxi     h,RAMFONTPSEUDOCODES
        mvi     b,17
        mvi     c,0
RAMCHARPSEUDOLOOK:
        mov     a,e
        cmp     m
        jz      RAMCHARPSEUDO
        inx     h
        inr     c
        dcr     b
        jnz     RAMCHARPSEUDOLOOK
        jmp     RAMCHARQUESTION
RAMCHARPSEUDO:
        mvi     a,8
        sta     RAMFONTROWS
.ifdef RAMLOCALEFONTS
        lxi     h,RAMFONTPSEUDO
        shld    RAMFONTBASEPTR
.endif
        mov     a,c
        jmp     RAMCHARINDEX
RAMCHARQUESTION:
        mvi     e,'?'                   ; bound characters outside the font
RAMCHARASCII:
        mvi     a,7
        sta     RAMFONTROWS
.ifdef RAMLOCALEFONTS
        lxi     h,RAMFONT80
        shld    RAMFONTBASEPTR
.endif
RAMCHARBASE:
        mov     a,e
        sui     020h
RAMCHARINDEX:
        sta     RAMOUTCHAR              ; RAMCELLADDR uses DE as scratch
        ; Calculate the packed framebuffer cell first. RAMCELLADDR also saves
        ; the bit shift for the five-pixel field in RAMSHIFT.
        call    RAMCELLADDR
        push    h

        ; Font pointer = selected table + glyph index * seven/eight rows.
        lda     RAMOUTCHAR
        mov     l,a
        mvi     h,0
        mov     c,l
        mvi     b,0
        lda     RAMFONTROWS
        cpi     8
        jz      RAMFONTMUL8
        dad     h                       ; 2n
        dad     h                       ; 4n
        dad     b                       ; 5n
        dad     b                       ; 6n
        dad     b                       ; 7n
        jmp     RAMFONTREADY
RAMFONTMUL8:
        dad     h
        dad     h
        dad     h
RAMFONTREADY:
.ifdef RAMLOCALEFONTS
        xchg                            ; DE = glyph byte offset
        lhld    RAMFONTBASEPTR
        dad     d
.else
        lda     RAMFONTROWS
        cpi     8
        lxi     d,RAMFONT80
        jnz     RAMFONTBASEOK
        lxi     d,RAMFONTPSEUDO
RAMFONTBASEOK:
        dad     d
.endif
        xchg                            ; DE = font rows
        pop     h                       ; HL = packed framebuffer cell

        call    RAMVIDEO
        call    RAMDRAWGLYPH
        call    RAMNORMAL

        lda     RAMCOL
        inr     a
        mov     b,a
        lda     RAMCOLS
        mov     c,a
        mov     a,b
        cmp     c
        jc      RAMSAVECOL
        xra     a
        sta     RAMCOL
        call    RAMNEWLINE
        jmp     RAMOUTDONE
RAMSAVECOL:
        sta     RAMCOL

RAMOUTDONE:
        call    RAMCURSORSHOW
        call    RAMCURSORRELOAD
        pop     h
        pop     d
        pop     b
        pop     psw
        ret

.ifdef RAMLOCALEFONTS
; Sparse locale banks return a compact glyph index without changing the
; renderer. Estonian uses the ISO-8859-1 byte values of its eight national
; letters. Russian uses CP866, whose Cyrillic ranges avoid CP437 B0h..DFh.
RAMCHAREST:
        lxi     h,RAMFONTESTONIAN
        shld    RAMFONTBASEPTR
        lxi     h,RAMFONTESTONIANCODES
        mvi     b,8
        call    RAMFONTSEARCH
        jnc     RAMCHARLOCALE
        jmp     RAMCHARPSEUDOTRY
RAMCHARRUS:
        lxi     h,RAMFONTCP866
        shld    RAMFONTBASEPTR
        lxi     h,RAMFONTCP866CODES
        mvi     b,66
        call    RAMFONTSEARCH
        jnc     RAMCHARLOCALE
        jmp     RAMCHARPSEUDOTRY
RAMCHARLOCALE:
        mvi     b,7
        mov     c,a
        mov     a,b
        sta     RAMFONTROWS
        mov     a,c
        jmp     RAMCHARINDEX

; E = byte, HL = code table, B = count. Return A=index/CY clear, or CY set.
RAMFONTSEARCH:
        mvi     c,0
RAMFONTSEARCH1:
        mov     a,e
        cmp     m
        jz      RAMFONTFOUND
        inx     h
        inr     c
        dcr     b
        jnz     RAMFONTSEARCH1
        stc
        ret
RAMFONTFOUND:
        mov     a,c
        ora     a                       ; clear carry
        ret
.endif

RAMNEWLINE:
        lda     RAMROW
        inr     a
        mov     b,a
        lda     RAMROWS
        mov     c,a
        mov     a,b
        cmp     c
        jc      RAMSAVEROW
        call    RAMSCROLL
        lda     RAMROWS
        dcr     a
RAMSAVEROW:
        sta     RAMROW
        ret

RAMSCROLL:
        call    RAMVIDEO
        lhld    RAMROWBYTES
        lxi     d,VRAM
        dad     d
        xchg                            ; DE = source after first text row
        push    d
        lhld    RAMROWBYTES
        xchg                            ; DE = bytes removed
        lxi     h,SCREENBYTES
        mov     a,l
        sub     e
        mov     c,a
        mov     a,h
        sbb     d
        mov     b,a                     ; BC = retained bytes
        pop     d
        lxi     h,VRAM
RAMCOPY:
        ldax    d
        mov     m,a
        inx     d
        inx     h
        dcx     b
        mov     a,b
        ora     c
        jnz     RAMCOPY
        push    h
        lhld    RAMROWBYTES
        mov     b,h
        mov     c,l
        pop     h
        call    RAMCLEAR
        jmp     RAMNORMAL

; Return HL at the first byte touched by the current packed cell and retain
; (column * 5) modulo 8 in RAMSHIFT.
RAMCELLADDR:
        lda     RAMROW
        mov     b,a
        lhld    RAMROWBYTES
        xchg
        lxi     h,VRAM
RAMROWADDR:
        mov     a,b
        ora     a
        jz      RAMROWREADY
        dad     d
        dcr     b
        jmp     RAMROWADDR
RAMROWREADY:
        push    h
        lda     RAMCOL
        mov     l,a
        mvi     h,0
        mov     e,l
        mvi     d,0
        lda     RAMCELLWIDTH
        cpi     8
        jz      RAMCOLMUL8
        dad     h                       ; 2n
        dad     h                       ; 4n
        dad     d                       ; 5n
        cpi     6
        jnz     RAMCOLMULDONE
        dad     d                       ; 6n
        jmp     RAMCOLMULDONE
RAMCOLMUL8:
        dad     h
        dad     h
        dad     h
RAMCOLMULDONE:
        mov     a,l
        ani     7
        sta     RAMSHIFT
        mvi     b,3
RAMBYTEOFF:
        xra     a                       ; clear carry
        mov     a,h
        rar
        mov     h,a
        mov     a,l
        rar
        mov     l,a
        dcr     b
        jnz     RAMBYTEOFF
        xchg                            ; DE = floor(column * 5 / 8)
        pop     h
        dad     d
        ret

; DE = selected font rows, HL = top scanline cell address.
RAMDRAWGLYPH:
        lda     RAMFONTROWS
        sta     RAMGLYPHROWS
RAMGLYPH:
        ldax    d
        inx     d
        push    d
        push    h
        call    RAMPAINTBYTE
        pop     h
        lda     RAMVIDSTRIDE
        mov     c,a
        mvi     b,0
        dad     b
        pop     d
        lda     RAMGLYPHROWS
        dcr     a
        sta     RAMGLYPHROWS
        jnz     RAMGLYPH
        lda     RAMCELLHEIGHT
        mov     b,a
        lda     RAMFONTROWS
        mov     c,a
        mov     a,b
        sub     c
        rz
        sta     RAMGLYPHROWS
RAMGLYPHBLANK:
        xra     a
        call    RAMPAINTBYTE
        lda     RAMGLYPHROWS
        dcr     a
        sta     RAMGLYPHROWS
        rz
        lda     RAMVIDSTRIDE
        mov     c,a
        mvi     b,0
        dad     b
        jmp     RAMGLYPHBLANK

; Replace the current five-pixel field. A contains five MSB-first pixels, HL
; addresses the first of at most two framebuffer bytes, and RAMSHIFT is 0..7.
RAMPAINTBYTE:
        mov     b,a                     ; BC = 16-bit pixel field
        mvi     c,0
        lda     RAMCELLMASK
        mov     d,a                     ; DE = 16-bit replacement mask
        mvi     e,0
        lda     RAMSHIFT
        sta     RAMWORKSHIFT
RAMPAINTSHIFT:
        ora     a
        jz      RAMPAINTMERGE
        mov     a,b
        ora     a                       ; clear carry
        rar
        mov     b,a
        mov     a,c
        rar
        mov     c,a
        mov     a,d
        ora     a                       ; clear carry
        rar
        mov     d,a
        mov     a,e
        rar
        mov     e,a
        lda     RAMWORKSHIFT
        dcr     a
        sta     RAMWORKSHIFT
        jmp     RAMPAINTSHIFT
RAMPAINTMERGE:
        mov     a,d
        cma
        ana     m
        ora     b
        mov     m,a
        inx     h
        mov     a,e
        cma
        ana     m
        ora     c
        mov     m,a
        ret

; Toggle the underline field. XOR preserves a CP437 glyph whose connecting
; vertical stroke occupies the eighth scanline when the cursor moves over it.
RAMCURSORPAINT:
        call    RAMCELLADDR
        push    h
        lhld    RAMCURSORLINE
        mov     b,h
        mov     c,l
        pop     h
        dad     b
        lda     RAMCELLMASK
        mov     b,a
        mvi     c,0
        lda     RAMSHIFT
RAMCURSORSHIFT:
        ora     a
        jz      RAMCURSORMERGE
        mov     a,b
        ora     a
        rar
        mov     b,a
        mov     a,c
        rar
        mov     c,a
        lda     RAMSHIFT
        dcr     a
        sta     RAMSHIFT
        jmp     RAMCURSORSHIFT
RAMCURSORMERGE:
        mov     a,m
        xra     b
        mov     m,a
        inx     h
        mov     a,m
        xra     c
        mov     m,a
        ret

RAMCURSORSHOW:
        lda     RAMCURVISIBLE
        ora     a
        rnz
        call    RAMVIDEO
        call    RAMCURSORPAINT
        mvi     a,1
        sta     RAMCURVISIBLE
        jmp     RAMNORMAL

RAMCURSORHIDE:
        lda     RAMCURVISIBLE
        ora     a
        rz
        call    RAMVIDEO
        xra     a
        call    RAMCURSORPAINT
        xra     a
        sta     RAMCURVISIBLE
        jmp     RAMNORMAL

RAMCURSORRELOAD:
        lxi     h,CURSORPERIOD
        shld    RAMCURCOUNT
        ret

; Call from the BIOS console-status path. All registers and the caller's
; result are preserved. The polled keyboard makes the phase independent of
; interrupts while still producing a human-scale blink at an idle prompt.
RAMCONTICK:
        push    psw
        push    b
        push    d
        push    h
        lhld    RAMCURCOUNT
        dcx     h
        mov     a,h
        ora     l
        jnz     RAMCURSAVE
        call    RAMCURSORRELOAD
        lda     RAMCURVISIBLE
        ora     a
        jz      RAMCURSHOW1
        call    RAMCURSORHIDE
        jmp     RAMCURDONE
RAMCURSHOW1:
        call    RAMCURSORSHOW
        jmp     RAMCURDONE
RAMCURSAVE:
        shld    RAMCURCOUNT
RAMCURDONE:
        pop     h
        pop     d
        pop     b
        pop     psw
        ret

; Fill BC bytes at HL with zero.
RAMCLEAR:
RAMCLEAR1:
        mvi     m,0
        inx     h
        dcx     b
        mov     a,b
        ora     c
        jnz     RAMCLEAR1
        ret

RAMVIDEO:
        di
        in      MODEPORT
        ani     0fch
        ori     3
        out     MODEPORT
        ret

RAMNORMAL:
.ifdef RAMCONSOLE_MODE1
        in      MODEPORT
        ani     0fch
        ori     1
        out     MODEPORT
.else
.ifndef RAMKEYBOARD
        in      MODEPORT
        ani     0fch
        ori     1
        out     MODEPORT
.endif
.endif
        ei
        ret

RAMCOL:         db      0
RAMROW:         db      0
RAMESC:         db      0
RAMOUTCHAR:     db      0
RAMSHIFT:       db      0
RAMWORKSHIFT:   db      0
RAMGLYPHROWS:   db      0
RAMFONTROWS:    db      7
RAMCURVISIBLE:  db      0
RAMCURCOUNT:    dw      CURSORPERIOD
RAMCONFIG:      db      0
.ifdef RAMLOCALEFONTS
RAMLOCALE:      db      0
.endif
RAMVIDMODE:     db      3
RAMCOLS:        db      80
RAMROWS:        db      24
RAMCELLWIDTH:   db      5
RAMCELLHEIGHT:  db      8
RAMCELLMASK:    db      0f8h
RAMVIDSTRIDE:   db      50
RAMROWBYTES:    dw      400
RAMCURSORLINE:  dw      350
.ifdef RAMLOCALEFONTS
RAMFONTBASEPTR: dw      RAMFONT80
.endif

        include "creep-console-font.asm"
.ifdef RAMLOCALEFONTS
        include "locale-console-fonts.asm"
.endif
