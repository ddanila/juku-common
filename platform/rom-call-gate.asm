; Low-RAM gate for the versioned network-first Juku ROM ABI.
; Copyright (c) 2026 Danila Sukharev
; BSD-2-Clause; see ../LICENSE-BSD-2-Clause.
;
; Include this source at JROMGATEBASE. The gate selects memory mode 1 before
; every resident-ROM call, preserves the caller's A/flags while doing so, and
; leaves interrupts disabled. JCGINIT must pass before any other entry is used.

        include "rom-abi.inc"

JCGMODEPORT     equ     006h

JCGINIT:
        di
        call    JCGMODE1
        lxi     h,JROMABIBASE
        lxi     d,JCGSIGNATURE
        mvi     b,8
JCGSIGLOOP:
        ldax    d
        cmp     m
        jnz     JCGFAIL
        inx     d
        inx     h
        dcr     b
        jnz     JCGSIGLOOP
        mov     a,m                     ; ABI major at FF08h
        cpi     JROMABIMAJOR
        jnz     JCGFAIL
        inx     h
        mov     a,m                     ; require ROM minor >= consumer minor
        cpi     JROMABIMINOR
        jc      JCGFAIL
        mvi     a,1
        sta     JCGREADY
        xra     a
        ret
JCGFAIL:
        xra     a
        sta     JCGREADY
        dcr     a                       ; FFh = no compatible ROM
        ret

; Preserve A and flags, leave every other register untouched, select mode 1,
; and keep interrupts disabled. Mode 1 is every ROM service's postcondition.
JCGMODE1:
        push    psw
        di
        in      JCGMODEPORT
        ani     0fch
        ori     1
        out     JCGMODEPORT
        pop     psw
        ret

JCGCONINIT:     call JCGMODE1
                jmp  JROMCONINIT
JCGCONSTAT:     call JCGMODE1
                jmp  JROMCONSTAT
JCGCONIN:       call JCGMODE1
                jmp  JROMCONIN
JCGCONOUT:      call JCGMODE1
                jmp  JROMCONOUT
JCGSERINIT:     call JCGMODE1
                jmp  JROMSERINIT
JCGSERRX:       call JCGMODE1
                jmp  JROMSERRX
JCGSERTX:       call JCGMODE1
                jmp  JROMSERTX
JCGNETDISK:     call JCGMODE1
                jmp  JROMNETDISK
JCGKEYINIT:     call JCGMODE1
                jmp  JROMKEYINIT
JCGKEYSCAN:     call JCGMODE1
                jmp  JROMKEYSCAN
JCGSOUND:       call JCGMODE1
                jmp  JROMSOUND
JCGDIAG:        call JCGMODE1
                jmp  JROMDIAG
JCGGETINFO:     call JCGMODE1
                jmp  JROMGETINFO

JCGREADY:       db      0
JCGSIGNATURE:   db      'J','U','K','U','A','B','I',0
JCGEND:

