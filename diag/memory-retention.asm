; Non-destructive single-cell RAM retention diagnostic for the Intel 8080.
;
; Input:  HL = writable test byte, BC = nonzero delay-loop count.
; Output: A = accumulated data-bit mismatch mask after 00h and FFh holds.
; Preserved: HL, BC, and the original test byte.
; Destroyed: A, DE, and flags.
; Stack: two extra words beyond the CALL return address.
;
; This routine supplies only the mechanism.  The caller chooses a delay which
; is meaningful for its CPU clock and refresh policy, and must keep code and
; stack alive during the hold.  It does not disable hardware refresh.

diag_memory_retention_test:
        mov     d,m             ; original byte
        push    b               ; retain the caller's delay count

        mvi     m,0
        call    diag_memory_retention_delay
        mov     a,m             ; expected 00h; A is the first mismatch mask
        mov     e,a

        pop     b
        push    b
        mvi     m,0ffh
        call    diag_memory_retention_delay
        mov     a,m
        xri     0ffh
        ora     e
        mov     e,a

        mov     m,d             ; restore before exposing the result
        pop     b
        mov     a,e
        ret

diag_memory_retention_delay:
        dcx     b
        mov     a,b
        ora     c
        jnz     diag_memory_retention_delay
        ret
