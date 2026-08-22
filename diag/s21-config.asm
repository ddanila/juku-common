; Non-destructive Juku S21 configuration sampler for the Intel 8080.
;
; Copyright (c) 2026 Danila Sukharev
; BSD-2-Clause; see ../LICENSE-BSD-2-Clause.
;
; The caller supplies DIAG_KEYCOL_PORT and DIAG_KEYROW_PORT.  S21.1..S21.8
; are scanned as keyboard columns 8..15; the active-low configuration contact
; is D26 port-B bit 5.  The result uses the historical Juku raw order: S21.1
; becomes bit 7 and S21.8 becomes bit 0.
;
; Output:    A = raw eight-position S21 byte.
; Preserved: BC, DE, HL and the selected keyboard column.
; Destroyed: flags.
;
; The routine performs no debounce and changes the D26 column only for the
; duration of the bounded scan.  It does not depend on RomBios or JukuNet ROM
; services and is suitable for a live CP/M diagnostic.

diag_s21_config_read:
        push    b
        push    d
        in      DIAG_KEYCOL_PORT
        mov     e,a
        mvi     b,8
        mvi     c,8
        mvi     d,0

diag_s21_config_next:
        mov     a,b
        out     DIAG_KEYCOL_PORT
        in      DIAG_KEYROW_PORT
        cma
        ani     020h
        push    psw
        mov     a,d
        add     a
        mov     d,a
        pop     psw
        jz      diag_s21_config_open
        mov     a,d
        ori     1
        mov     d,a

diag_s21_config_open:
        inr     b
        dcr     c
        jnz     diag_s21_config_next
        mov     a,e
        out     DIAG_KEYCOL_PORT
        mov     a,d
        pop     d
        pop     b
        ret
