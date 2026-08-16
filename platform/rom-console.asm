; Resident MODX-compatible 80x24 console for the network-first Juku ROM.
; Copyright (c) 2026 Danila Sukharev
; BSD-2-Clause; see ../LICENSE-BSD-2-Clause.
;
; Text policy, cursor state, cell arithmetic, and the immutable MIT font stay
; visible in mode 1. Packed row values are prepared in low RAM and committed by
; JROMHELPENTRY, because selecting mode 3 hides this code immediately.

        include "rom-console-state.inc"

VIDSTRIDE       equ     50
COLS            equ     80
ROWS            equ     24
ROWBYTES        equ     400
CURSORLINE      equ     350
CURSORPERIOD    equ     0200h
JROMHELPENTRY   equ     JROMHELPBASE

ROMCONINIT:
        xra     a
        sta     RCCOL
        sta     RCROW
        sta     RCESC
        sta     RCCURVISIBLE
        call    RCCURSORRELOAD
        call    RCMODXVIDEO
        mvi     a,RCOPCLEAR
        sta     RCOP
        call    JROMHELPENTRY
        xra     a
        ret

RCMODXVIDEO:
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

; A = character. Preserve the caller-visible registers like the RAM oracle.
ROMCONOUT:
        push    psw
        push    b
        push    d
        push    h
        sta     RCOUTCHAR
        call    RCCURSORHIDE
        lda     RCOUTCHAR
        mov     e,a
        lda     RCESC
        ora     a
        jz      RCNOESC
        xra     a
        sta     RCESC
        mov     a,e
        cpi     'L'
        cz      ROMCONINIT
        jmp     RCOUTDONE
RCNOESC:
        mov     a,e
        cpi     01bh
        jnz     RCNOTESC
        mvi     a,1
        sta     RCESC
        jmp     RCOUTDONE
RCNOTESC:
        cpi     0dh
        jnz     RCNOTCR
        xra     a
        sta     RCCOL
        jmp     RCOUTDONE
RCNOTCR:
        cpi     0ah
        jnz     RCNOTLF
        call    RCNEWLINE
        jmp     RCOUTDONE
RCNOTLF:
        cpi     08h
        jnz     RCPRINTABLE
        lda     RCCOL
        ora     a
        jz      RCOUTDONE
        dcr     a
        sta     RCCOL
        jmp     RCOUTDONE

RCPRINTABLE:
        cpi     020h
        jc      RCOUTDONE
        cpi     07fh
        jc      RCCHAROK
        mvi     e,'?'
RCCHAROK:
        mov     a,e
        sta     RCOUTCHAR
        call    RCCELLADDR

        lda     RCOUTCHAR
        sui     020h
        mov     l,a
        mvi     h,0
        mov     c,l
        mvi     b,0
        dad     h
        dad     h
        dad     b
        dad     b
        dad     b
        lxi     d,RAMFONT80
        dad     d
        xchg
        lxi     h,RCPIXELS
        mvi     a,7
        sta     RCWORK
RCPREPROW:
        ldax    d
        inx     d
        call    RCPREPBYTE
        lda     RCWORK
        dcr     a
        sta     RCWORK
        jnz     RCPREPROW
        xra     a
        call    RCPREPBYTE
        mvi     a,8
        sta     RCROWS
        mvi     a,RCOPDRAW
        sta     RCOP
        call    JROMHELPENTRY

        lda     RCCOL
        inr     a
        cpi     COLS
        jc      RCSAVECOL
        xra     a
        sta     RCCOL
        call    RCNEWLINE
        jmp     RCOUTDONE
RCSAVECOL:
        sta     RCCOL
RCOUTDONE:
        call    RCCURSORSHOW
        call    RCCURSORRELOAD
        pop     h
        pop     d
        pop     b
        pop     psw
        ret

RCNEWLINE:
        lda     RCROW
        inr     a
        cpi     ROWS
        jc      RCSAVEROW
        mvi     a,RCOPSCROLL
        sta     RCOP
        call    JROMHELPENTRY
        mvi     a,ROWS-1
RCSAVEROW:
        sta     RCROW
        ret

; Publish packed cell address and the shifted two-byte preservation mask.
RCCELLADDR:
        lxi     h,0d800h
        lda     RCROW
        mov     b,a
        lxi     d,ROWBYTES
RCROWADDR:
        mov     a,b
        ora     a
        jz      RCROWREADY
        dad     d
        dcr     b
        jmp     RCROWADDR
RCROWREADY:
        push    h
        lda     RCCOL
        mov     l,a
        mvi     h,0
        mov     e,l
        mvi     d,0
        dad     h
        dad     h
        dad     d
        mov     a,l
        ani     7
        sta     RCSHIFT
        mvi     b,3
RCBYTEOFF:
        xra     a
        mov     a,h
        rar
        mov     h,a
        mov     a,l
        rar
        mov     l,a
        dcr     b
        jnz     RCBYTEOFF
        xchg
        pop     h
        dad     d
        shld    RCADDR

        mvi     b,0f8h
        mvi     c,0
        call    RCSHIFTBC
        mov     a,b
        cma
        sta     RCMASK
        mov     a,c
        cma
        sta     RCMASK+1
        ret

; A is one left-aligned five-pixel row, HL is the prepared output pointer.
RCPREPBYTE:
        mov     b,a
        mvi     c,0
        call    RCSHIFTBC
        mov     m,b
        inx     h
        mov     m,c
        inx     h
        ret

; Shift BC right by the current packed-cell bit offset.
RCSHIFTBC:
        lda     RCSHIFT
        sta     RCWORK+1
RCSHIFTBC1:
        ora     a
        rz
        mov     a,b
        ora     a
        rar
        mov     b,a
        mov     a,c
        rar
        mov     c,a
        lda     RCWORK+1
        dcr     a
        sta     RCWORK+1
        jmp     RCSHIFTBC1

RCCURSORPREP:
        push    psw
        call    RCCELLADDR
        lhld    RCADDR
        lxi     b,CURSORLINE
        dad     b
        shld    RCADDR
        pop     psw
        lxi     h,RCPIXELS
        call    RCPREPBYTE
        mvi     a,1
        sta     RCROWS
        mvi     a,RCOPDRAW
        sta     RCOP
        call    JROMHELPENTRY
        ret

RCCURSORSHOW:
        lda     RCCURVISIBLE
        ora     a
        rnz
        mvi     a,0f8h
        call    RCCURSORPREP
        mvi     a,1
        sta     RCCURVISIBLE
        ret
RCCURSORHIDE:
        lda     RCCURVISIBLE
        ora     a
        rz
        xra     a
        call    RCCURSORPREP
        xra     a
        sta     RCCURVISIBLE
        ret

RCCURSORRELOAD:
        lxi     h,CURSORPERIOD
        shld    RCCURCOUNT
        ret

ROMCONTICK:
        push    psw
        push    b
        push    d
        push    h
        lhld    RCCURCOUNT
        dcx     h
        mov     a,h
        ora     l
        jnz     RCCURSAVE
        call    RCCURSORRELOAD
        lda     RCCURVISIBLE
        ora     a
        jz      RCCURSHOW1
        call    RCCURSORHIDE
        jmp     RCCURDONE
RCCURSHOW1:
        call    RCCURSORSHOW
        jmp     RCCURDONE
RCCURSAVE:
        shld    RCCURCOUNT
RCCURDONE:
        pop     h
        pop     d
        pop     b
        pop     psw
        ret

ROMCONSTAT:
        call    ROMCONTICK
        jmp     RKSTAT

ROMCONIN:
        call    ROMCONTICK
        call    RKSTAT
        ora     a
        jz      ROMCONIN
        jmp     RKIN

CREEP_ASCII_ONLY equ     1
        include "creep-console-font.asm"
ROMCONEND:
