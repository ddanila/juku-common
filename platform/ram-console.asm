; Native MODX-compatible 80x24 bitmap console for RAM-owned Juku systems.
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
VIDSTRIDE       equ     50              ; 400 pixels
COLS            equ     80
ROWS            equ     24
CELLHEIGHT      equ     8
ROWBYTES        equ     400             ; 50 * 8 scanlines
SCREENBYTES     equ     9600            ; 80 * 24 * 5 packed pixels
SCROLLBYTES     equ     9200            ; retain rows 1..23
CURSORLINE      equ     350             ; seventh scanline in the cell
CURSORPERIOD    equ     0400h           ; about 0.7 s per phase on CS00015

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

RAMCONINIT:
        xra     a
        sta     RAMCOL
        sta     RAMROW
        sta     RAMESC
        sta     RAMCURVISIBLE
        call    RAMCURSORRELOAD
        call    RAMVIDEO
        call    RAMMODXVIDEO
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
        jc      RAMCHAROK
        mvi     e,'?'                   ; bound characters outside the font
RAMCHAROK:
        mov     a,e
        sta     RAMOUTCHAR              ; RAMCELLADDR uses DE as scratch
        ; Calculate the packed framebuffer cell first. RAMCELLADDR also saves
        ; the bit shift for the five-pixel field in RAMSHIFT.
        call    RAMCELLADDR
        push    h

        ; Font pointer = RAMFONT + (character - 20h) * 7.
        lda     RAMOUTCHAR
        sui     020h
        mov     l,a
        mvi     h,0
        mov     c,l
        mvi     b,0
        dad     h                       ; 2n
        dad     h                       ; 4n
        dad     b                       ; 5n
        dad     b                       ; 6n
        dad     b                       ; 7n
        lxi     d,RAMFONT
        dad     d
        xchg                            ; DE = seven font rows
        pop     h                       ; HL = packed framebuffer cell

        call    RAMVIDEO
        call    RAMDRAWGLYPH
        call    RAMNORMAL

        lda     RAMCOL
        inr     a
        cpi     COLS
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

RAMNEWLINE:
        lda     RAMROW
        inr     a
        cpi     ROWS
        jc      RAMSAVEROW
        call    RAMSCROLL
        mvi     a,ROWS-1
RAMSAVEROW:
        sta     RAMROW
        ret

RAMSCROLL:
        call    RAMVIDEO
        lxi     h,VRAM
        lxi     d,VRAM+ROWBYTES
        lxi     b,SCROLLBYTES
RAMCOPY:
        ldax    d
        mov     m,a
        inx     d
        inx     h
        dcx     b
        mov     a,b
        ora     c
        jnz     RAMCOPY
        lxi     b,ROWBYTES
        call    RAMCLEAR
        jmp     RAMNORMAL

; Return HL at the first byte touched by the current packed cell and retain
; (column * 5) modulo 8 in RAMSHIFT.
RAMCELLADDR:
        lxi     h,VRAM
        lda     RAMROW
        mov     b,a
        lxi     d,ROWBYTES
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
        dad     h                       ; 2n
        dad     h                       ; 4n
        dad     d                       ; 5n
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

; DE = seven scanline bytes, HL = top scanline cell address.
RAMDRAWGLYPH:
        mvi     a,7
        sta     RAMGLYPHROWS
RAMGLYPH:
        ldax    d
        inx     d
        push    d
        push    h
        call    RAMPAINTBYTE
        pop     h
        lxi     b,VIDSTRIDE
        dad     b
        pop     d
        lda     RAMGLYPHROWS
        dcr     a
        sta     RAMGLYPHROWS
        jnz     RAMGLYPH
        xra     a                       ; eighth scanline is blank/cursor
        call    RAMPAINTBYTE
        ret

; Replace the current five-pixel field. A contains five MSB-first pixels, HL
; addresses the first of at most two framebuffer bytes, and RAMSHIFT is 0..7.
RAMPAINTBYTE:
        mov     b,a                     ; BC = 16-bit pixel field
        mvi     c,0
        mvi     d,0f8h                  ; DE = 16-bit replacement mask
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

; Paint or erase the five-pixel underline at the current cell. A is 00h or
; F8h. The eighth scanline is otherwise always blank, so no shadow buffer is
; needed and mode-3 read/modify/write remains exact.
RAMCURSORPAINT:
        sta     RAMPAINTVALUE
        call    RAMCELLADDR
        lxi     b,CURSORLINE
        dad     b
        lda     RAMPAINTVALUE
        jmp     RAMPAINTBYTE

RAMCURSORSHOW:
        lda     RAMCURVISIBLE
        ora     a
        rnz
        call    RAMVIDEO
        mvi     a,0f8h
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
.ifndef RAMKEYBOARD
        in      MODEPORT
        ani     0fch
        ori     1
        out     MODEPORT
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
RAMPAINTVALUE:  db      0
RAMCURVISIBLE:  db      0
RAMCURCOUNT:    dw      CURSORPERIOD

        include "ram-console-font.asm"
