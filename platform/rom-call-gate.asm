; Low-RAM gate for the versioned network-first Juku ROM ABI.
; Copyright (c) 2026 Danila Sukharev
; BSD-2-Clause; see ../LICENSE-BSD-2-Clause.
;
; Include this source at JROMGATEBASE. The gate selects memory mode 1 before
; every resident-ROM call, preserves the caller's A/flags while doing so, and
; leaves interrupts disabled. JCGINIT must pass before any other entry is used.

        include "rom-abi.inc"

JCGMODEPORT     equ     006h

; Stable low-RAM vector table. Keep this order synchronized with rom-abi.inc.
JCGINIT:        jmp     JCGINITIMPL
JCGCONINIT:     jmp     JCGCONINITIMPL
JCGCONSTAT:     jmp     JCGCONSTATIMPL
JCGCONIN:       jmp     JCGCONINIMPL
JCGCONOUT:      jmp     JCGCONOUTIMPL
JCGSERINIT:     jmp     JCGSERINITIMPL
JCGSERRX:       jmp     JCGSERRXIMPL
JCGSERTX:       jmp     JCGSERTXIMPL
JCGNETDISK:     jmp     JCGNETDISKIMPL
JCGKEYINIT:     jmp     JCGKEYINITIMPL
JCGKEYSCAN:     jmp     JCGKEYSCANIMPL
JCGSOUND:       jmp     JCGSOUNDIMPL
JCGDIAG:        jmp     JCGDIAGIMPL
JCGGETINFO:     jmp     JCGGETINFOIMPL

JCGINITIMPL:
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
        call    JROMINIT
        ora     a
        rz
        jmp     JCGFAIL
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

JCGCONINITIMPL: call JCGMODE1
                jmp  JROMCONINIT
JCGCONSTATIMPL: call JCGMODE1
                jmp  JROMCONSTAT
JCGCONINIMPL:   call JCGMODE1
                jmp  JROMCONIN
JCGCONOUTIMPL:  call JCGMODE1
                jmp  JROMCONOUT
JCGSERINITIMPL: call JCGMODE1
                jmp  JROMSERINIT
JCGSERRXIMPL:   call JCGMODE1
                jmp  JROMSERRX
JCGSERTXIMPL:   call JCGMODE1
                jmp  JROMSERTX
JCGNETDISKIMPL: call JCGMODE1
                jmp  JROMNETDISK
JCGKEYINITIMPL: call JCGMODE1
                jmp  JROMKEYINIT
JCGKEYSCANIMPL: call JCGMODE1
                jmp  JROMKEYSCAN
JCGSOUNDIMPL:   call JCGMODE1
                jmp  JROMSOUND
JCGDIAGIMPL:    call JCGMODE1
                jmp  JROMDIAG
JCGGETINFOIMPL: call JCGMODE1
                jmp  JROMGETINFO

JCGREADY:       db      0
JCGSIGNATURE:   db      'J','U','K','U','A','B','I',0
JCGEND:
