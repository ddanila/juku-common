; Origin-independent byte signature comparison.
;
; Input: HL=observed bytes, DE=expected bytes, B=nonzero byte count.
; Output: A=0 exact match, A=1 mismatch. Memory is unchanged.

diag_signature_test:
        ldax    d
        cmp     m
        jnz     diag_signature_fail
        inx     d
        inx     h
        dcr     b
        jnz     diag_signature_test
        xra     a
        ret
diag_signature_fail:
        mvi     a,1
        ret
