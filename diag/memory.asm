; Non-destructive byte-cell RAM diagnostic for the Intel 8080.
;
; See README.md for the calling convention. Keep this file origin-independent:
; consumers include it at the address appropriate for their environment.

diag_memory_test:
        mvi     c,0             ; accumulated mismatch bits

diag_memory_next:
        mov     b,m             ; preserve original byte

        mvi     m,0
        mov     a,m
        ora     c
        mov     c,a

        mvi     m,0ffh
        mov     a,m
        xri     0ffh
        ora     c
        mov     c,a

        mov     m,b             ; restore before advancing
        inx     h

        mov     a,h
        cmp     d
        jnz     diag_memory_next
        mov     a,l
        cmp     e
        jnz     diag_memory_next

        mov     a,c
        ret
