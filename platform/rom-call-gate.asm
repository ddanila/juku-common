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
.ifdef ROM_ABI_EXTENDED
; ABI 1.2 uses one register-preserving dispatcher so three appended services
; still fit below the fixed D700h framebuffer helper. The return address of
; each CALL identifies its immutable vector slot.
JCGCONINIT:     call    JCGDISPATCH
JCGCONSTAT:     call    JCGDISPATCH
JCGCONIN:       call    JCGDISPATCH
JCGCONOUT:      call    JCGDISPATCH
JCGSERINIT:     call    JCGDISPATCH
JCGSERRX:       call    JCGDISPATCH
JCGSERTX:       call    JCGDISPATCH
JCGNETDISK:     call    JCGDISPATCH
JCGKEYINIT:     call    JCGDISPATCH
JCGKEYSCAN:     call    JCGDISPATCH
JCGSOUND:       call    JCGDISPATCH
JCGDIAG:        call    JCGDISPATCH
JCGGETINFO:     call    JCGDISPATCH
JCGCONFIG:      call    JCGDISPATCH
JCGKEYREMAP:    call    JCGDISPATCH
JCGBOOTPOLICY:  call    JCGDISPATCH
JCGCONBLOCK:    call    JCGDISPATCH
JCGNETMULTI:    call    JCGDISPATCH
JCGKEYRAW:      call    JCGDISPATCH
.ifdef ROM_ABI_HOSTSERVICES
JCGHOST:        call    JCGDISPATCH
.endif
.else
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
.ifdef ROM_ABI_LOCALE
JCGCONFIG:      jmp     JCGCONFIGIMPL
JCGKEYREMAP:    jmp     JCGKEYREMAPIMPL
.endif
.endif

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

.ifdef ROM_ABI_EXTENDED
; JCGDISPATCH is entered by CALL from a fixed three-byte vector. JCGMODE1
; preserves the service inputs. XTHL then exposes the vector return address
; while keeping the caller's original HL on the stack. The selected resident
; target is installed into a low-RAM jump, all inputs are restored exactly,
; and the synthetic vector return word is discarded before the tail jump.
JCGDISPATCH:
        call    JCGMODE1
        xthl
        push    psw
        push    b
        push    d
        mov     a,l
        sui     026h                    ; return after JCGCONINIT at D623h
        lxi     h,JCGTARGETS
JCGDISPATCH1:
        ora     a
        jz      JCGDISPATCH2
        sui     3
        inx     h
        inx     h
        jmp     JCGDISPATCH1
JCGDISPATCH2:
        mov     e,m
        inx     h
        mov     d,m
        xchg
        shld    JCGJUMP+1
        pop     d
        pop     b
        pop     psw
        xthl
        inx     sp
        inx     sp
JCGJUMP:
        jmp     0

JCGTARGETS:
        dw      JROMCONINIT,JROMCONSTAT,JROMCONIN,JROMCONOUT
        dw      JROMSERINIT,JROMSERRX,JROMSERTX,JROMNETDISK
        dw      JROMKEYINIT,JROMKEYSCAN,JROMSOUND,JROMDIAG,JROMGETINFO
        dw      JROMCONFIG,JROMKEYREMAP,JROMBOOTPOLICY
        dw      JROMCONBLOCK,JROMNETMULTI,JROMKEYRAW
.ifdef ROM_ABI_HOSTSERVICES
        dw      JROMHOST
.endif
.else
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
.ifdef ROM_ABI_LOCALE
JCGCONFIGIMPL:  call JCGMODE1
                jmp  JROMCONFIG
JCGKEYREMAPIMPL: call JCGMODE1
                jmp  JROMKEYREMAP
.endif
.endif

JCGREADY:       db      0
JCGSIGNATURE:   db      'J','U','K','U','A','B','I',0
JCGEND:
