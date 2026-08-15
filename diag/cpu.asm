; Non-destructive Intel 8080 ALU, flag, register-pair and stack-path test.
;
; Interface:
;   call diag_cpu_test
;   A = 00h success
;       01h ALU/flag/rotate/DAA failure
;       02h 16-bit register-pair or increment failure
;       04h SP or PUSH/POP data-path failure
;
; The routine is origin-independent, performs no I/O, writes no static data,
; and restores SP exactly before returning. BC, DE, HL, A and flags are
; destroyed. It requires a writable stack with room for three extra words.

diag_cpu_test:
        ; ADD: 7F+01=80; S=1, Z=0, CY=0, parity odd.
        mvi     a,07fh
        adi     1
        jp      diag_cpu_alu_fail
        jz      diag_cpu_alu_fail
        jc      diag_cpu_alu_fail
        jpe     diag_cpu_alu_fail
        cpi     080h
        jnz     diag_cpu_alu_fail

        ; ADC: FE+01+CY=00; S=0, Z=1, CY=1, parity even.
        stc
        mvi     a,0feh
        aci     1
        jnz     diag_cpu_alu_fail
        jnc     diag_cpu_alu_fail
        jm      diag_cpu_alu_fail
        jpo     diag_cpu_alu_fail

        ; SUB: 00-01=FF; S=1, Z=0, borrow/CY=1, parity even.
        xra     a
        sui     1
        jp      diag_cpu_alu_fail
        jz      diag_cpu_alu_fail
        jnc     diag_cpu_alu_fail
        jpo     diag_cpu_alu_fail
        cpi     0ffh
        jnz     diag_cpu_alu_fail

        ; SBB: 10-0F-CY=00; S=0, Z=1, CY=0, parity even.
        stc
        mvi     a,010h
        sbi     00fh
        jnz     diag_cpu_alu_fail
        jc      diag_cpu_alu_fail
        jm      diag_cpu_alu_fail
        jpo     diag_cpu_alu_fail

        ; Logical operations set S/Z/P from their result and clear carry.
        mvi     a,055h
        ani     00fh
        jz      diag_cpu_alu_fail
        jc      diag_cpu_alu_fail
        jm      diag_cpu_alu_fail
        jpo     diag_cpu_alu_fail
        cpi     5
        jnz     diag_cpu_alu_fail

        mvi     a,0aah
        xri     0ffh
        jz      diag_cpu_alu_fail
        jc      diag_cpu_alu_fail
        jm      diag_cpu_alu_fail
        jpo     diag_cpu_alu_fail
        cpi     055h
        jnz     diag_cpu_alu_fail

        mvi     a,080h
        ori     1
        jp      diag_cpu_alu_fail
        jz      diag_cpu_alu_fail
        jc      diag_cpu_alu_fail
        jpo     diag_cpu_alu_fail
        cpi     081h
        jnz     diag_cpu_alu_fail

        ; CMP must set equality/borrow flags without changing A.
        mvi     a,042h
        cpi     042h
        jnz     diag_cpu_alu_fail
        jc      diag_cpu_alu_fail
        jm      diag_cpu_alu_fail
        jpo     diag_cpu_alu_fail
        cpi     042h
        jnz     diag_cpu_alu_fail

        mvi     a,010h
        cpi     020h
        jz      diag_cpu_alu_fail
        jnc     diag_cpu_alu_fail
        jp      diag_cpu_alu_fail
        jpo     diag_cpu_alu_fail
        cpi     010h
        jnz     diag_cpu_alu_fail

        ; Rotates change carry but leave the established Z/S/P state alone.
        xra     a
        mvi     a,081h
        rlc
        jnc     diag_cpu_alu_fail
        jnz     diag_cpu_alu_fail
        jm      diag_cpu_alu_fail
        jpo     diag_cpu_alu_fail
        cpi     3
        jnz     diag_cpu_alu_fail

        xra     a
        mvi     a,1
        rrc
        jnc     diag_cpu_alu_fail
        jnz     diag_cpu_alu_fail
        jm      diag_cpu_alu_fail
        jpo     diag_cpu_alu_fail
        cpi     080h
        jnz     diag_cpu_alu_fail

        xra     a
        stc
        mvi     a,080h
        ral
        jnc     diag_cpu_alu_fail
        jnz     diag_cpu_alu_fail
        jm      diag_cpu_alu_fail
        jpo     diag_cpu_alu_fail
        cpi     1
        jnz     diag_cpu_alu_fail

        xra     a
        stc
        mvi     a,1
        rar
        jnc     diag_cpu_alu_fail
        jnz     diag_cpu_alu_fail
        jm      diag_cpu_alu_fail
        jpo     diag_cpu_alu_fail
        cpi     080h
        jnz     diag_cpu_alu_fail

        ; INR/DCR update S/Z/P while preserving carry.
        stc
        mvi     b,07fh
        inr     b
        jnc     diag_cpu_alu_fail
        jp      diag_cpu_alu_fail
        jz      diag_cpu_alu_fail
        jpe     diag_cpu_alu_fail
        mov     a,b
        cpi     080h
        jnz     diag_cpu_alu_fail

        stc
        mvi     c,0
        dcr     c
        jnc     diag_cpu_alu_fail
        jp      diag_cpu_alu_fail
        jz      diag_cpu_alu_fail
        jpo     diag_cpu_alu_fail
        mov     a,c
        cpi     0ffh
        jnz     diag_cpu_alu_fail

        ; DAA consumes the preceding ADD's half-carry/carry state.
        mvi     a,9
        adi     9
        daa
        jz      diag_cpu_alu_fail
        jc      diag_cpu_alu_fail
        jm      diag_cpu_alu_fail
        jpo     diag_cpu_alu_fail
        cpi     018h
        jnz     diag_cpu_alu_fail

        mvi     a,099h
        adi     099h
        daa
        jz      diag_cpu_alu_fail
        jnc     diag_cpu_alu_fail
        jp      diag_cpu_alu_fail
        jpe     diag_cpu_alu_fail
        cpi     098h
        jnz     diag_cpu_alu_fail
        jmp     diag_cpu_pairs

diag_cpu_alu_fail:
        mvi     a,1
        ret

diag_cpu_pairs:
        ; Cover the high-bit INX failure observed in CS00015's former D1.
        lxi     b,00fffh
        inx     b
        mov     a,b
        cpi     010h
        jnz     diag_cpu_pair_fail
        mov     a,c
        ora     a
        jnz     diag_cpu_pair_fail

        lxi     d,01a00h
        inx     d
        mov     a,d
        cpi     01ah
        jnz     diag_cpu_pair_fail
        mov     a,e
        cpi     1
        jnz     diag_cpu_pair_fail

        lxi     h,05a00h
        inx     h
        mov     a,h
        cpi     05ah
        jnz     diag_cpu_pair_fail
        mov     a,l
        cpi     1
        jnz     diag_cpu_pair_fail

        lxi     h,01a00h
        lxi     d,1
        dad     d
        mov     a,h
        cpi     01ah
        jnz     diag_cpu_pair_fail
        mov     a,l
        cpi     1
        jnz     diag_cpu_pair_fail
        jmp     diag_cpu_stack

diag_cpu_pair_fail:
        mvi     a,2
        ret

diag_cpu_stack:
        ; Save the caller's exact SP without changing it, then test INX SP.
        lxi     h,0
        dad     sp
        xchg
        lxi     sp,09a00h
        inx     sp
        lxi     h,0
        dad     sp
        mov     a,h
        cpi     09ah
        jnz     diag_cpu_sp_fail
        mov     a,l
        cpi     1
        jnz     diag_cpu_sp_fail
        xchg
        sphl

        ; Exercise stack byte order and every pair's PUSH/POP data path.
        lxi     b,01234h
        lxi     d,05678h
        lxi     h,09abch
        push    b
        push    d
        push    h
        pop     b
        pop     h
        pop     d
        mov     a,b
        cpi     09ah
        jnz     diag_cpu_stack_fail
        mov     a,c
        cpi     0bch
        jnz     diag_cpu_stack_fail
        mov     a,h
        cpi     056h
        jnz     diag_cpu_stack_fail
        mov     a,l
        cpi     078h
        jnz     diag_cpu_stack_fail
        mov     a,d
        cpi     012h
        jnz     diag_cpu_stack_fail
        mov     a,e
        cpi     034h
        jnz     diag_cpu_stack_fail
        xra     a
        ret

diag_cpu_sp_fail:
        xchg
        sphl
diag_cpu_stack_fail:
        mvi     a,4
        ret
