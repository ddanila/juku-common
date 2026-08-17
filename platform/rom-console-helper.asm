; Low-RAM framebuffer primitive for the resident Juku console.
; Copyright (c) 2026 Danila Sukharev
; BSD-2-Clause; see ../LICENSE-BSD-2-Clause.
;
; Code executing in D800h..FFFFh disappears when mode 3 exposes video RAM.
; The resident side therefore prepares complete two-byte packed rows in the
; fixed workspace and calls this copied helper for clear, scroll, or merge.

        include "rom-abi.inc"
        include "rom-console-state.inc"

MODEPORT        equ     006h
VRAM            equ     0d800h
SCREENBYTES     equ     9600
SCROLLBYTES     equ     9200
ROWBYTES        equ     400
VIDSTRIDE       equ     50

        org     JROMHELPBASE

JROMHELPENTRY:
        push    psw
        push    b
        push    d
        push    h
        di
        in      MODEPORT
        ani     0fch
        ori     3
        out     MODEPORT
        lda     RCOP
        ora     a
        jz      RCHELP_CLEAR
        dcr     a
        jz      RCHELP_SCROLL

RCHELP_DRAW:
        lhld    RCADDR
        lxi     d,RCPIXELS
RCHELP_DRAW1:
        ldax    d
        mov     b,a
        lda     RCMASK
        ana     m
        ora     b
        mov     m,a
        inx     d
        inx     h
        ldax    d
        mov     b,a
        lda     RCMASK+1
        ana     m
        ora     b
        mov     m,a
        inx     d
.ifdef ROM_ABI_LOCALE
        lda     RCVIDSTEP
        mov     c,a
        mvi     b,0
.else
        lxi     b,VIDSTRIDE-1
.endif
        dad     b
        lda     RCROWS
        dcr     a
        sta     RCROWS
        jnz     RCHELP_DRAW1
        jmp     RCHELP_DONE

RCHELP_SCROLL:
.ifdef ROM_ABI_LOCALE
        lhld    RCSCROLLSOURCE
        xchg
        lhld    RCSCROLLBYTES
        mov     b,h
        mov     c,l
        lxi     h,VRAM
.else
        lxi     h,VRAM
        lxi     d,VRAM+ROWBYTES
        lxi     b,SCROLLBYTES
.endif
RCHELP_COPY:
        ldax    d
        mov     m,a
        inx     d
        inx     h
        dcx     b
        mov     a,b
        ora     c
        jnz     RCHELP_COPY
.ifdef ROM_ABI_LOCALE
        ; Every supported text row is 256..511 bytes, so its high byte is 1.
        lda     RCROWBYTES
        mov     c,a
        mvi     b,1
.else
        lxi     b,ROWBYTES
.endif
        jmp     RCHELP_ZERO

RCHELP_CLEAR:
        lxi     h,VRAM
        lxi     b,SCREENBYTES
RCHELP_ZERO:
RCHELP_ZERO1:
        xra     a
        mov     m,a
        inx     h
        dcx     b
        mov     a,b
        ora     c
        jnz     RCHELP_ZERO1

RCHELP_DONE:
        in      MODEPORT
        ani     0fch
        ori     1
        out     MODEPORT
        pop     h
        pop     d
        pop     b
        pop     psw
        ret

JROMHELPEND:
        end
