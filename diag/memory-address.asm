; Non-destructive power-of-two RAM address-alias diagnostic for the Intel 8080.
;
; Input:  HL = aligned base byte, A = number of address bits to test (1..15).
;         Every address base+(1<<n) for n in [0,A) must be writable RAM.
; Output: A = zero on success, one if any pair did not remain independent.
; Preserved: every tested byte.
; Destroyed: A, BC, DE, HL, and flags.
; Stack: five extra words beyond the CALL return address.
;
; The two locations are restored after every comparison.  This is deliberately
; a separate mechanism from the byte-cell/data-lane test in memory.asm: a
; shorted address line can make both 00h and FFh look healthy at either alias.

diag_memory_address_test:
        mov     c,a             ; number of address bits remaining
        lxi     d,1             ; current power-of-two offset
        mvi     b,0             ; sticky failure result

diag_memory_address_next:
        push    d               ; preserve the current offset
        push    h               ; preserve the base pointer

        mov     a,m             ; save the base before either write
        push    psw
        dad     d               ; HL = base + current offset
        mov     a,m             ; save the candidate before either write
        push    psw

        mov     a,l             ; HL = candidate - offset = base
        sub     e
        mov     l,a
        mov     a,h
        sbb     d
        mov     h,a
        mvi     m,0aah
        dad     d               ; HL = candidate
        mvi     m,055h

        mov     a,m             ; candidate must retain 55h
        xri     055h
        jz      diag_memory_address_candidate_ok
        mvi     b,1
diag_memory_address_candidate_ok:
        pop     psw             ; restore candidate first
        mov     m,a

        pop     psw             ; A = original base byte
        pop     h               ; HL = base
        mov     e,a             ; offset is still saved on the stack
        mov     a,m             ; base must still retain AAh
        xri     0aah
        jz      diag_memory_address_base_ok
        mvi     b,1
diag_memory_address_base_ok:
        mov     m,e             ; restore original base byte
        pop     d               ; recover current offset

        mov     a,e             ; DE <<= 1
        add     a
        mov     e,a
        mov     a,d
        ral
        mov     d,a
        dcr     c
        jnz     diag_memory_address_next

        mov     a,b
        ret
