; Origin-independent additive integrity checksum for the Intel 8080.
;
; Input:  HL = first byte, DE = exclusive end.
; Output: A = eight-bit additive checksum.
; Preserved: DE and the checked bytes.
; Destroyed: A, C, HL, and flags.

diag_checksum8:
        mvi     c,0

diag_checksum8_next:
        mov     a,c
        add     m
        mov     c,a
        inx     h

        mov     a,h
        cmp     d
        jnz     diag_checksum8_next
        mov     a,l
        cmp     e
        jnz     diag_checksum8_next

        mov     a,c
        ret
