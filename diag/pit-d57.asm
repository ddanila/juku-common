; Non-destructive D57 channel-0 latch/read diagnostic for Intel 8253 systems.
;
; The consumer defines DIAG_PIT_CONTROL and DIAG_PIT_COUNT0. The channel must
; already run in the production mode-2/count-4 configuration. Latching does
; not change its mode, count, output, or the USART clock.
; Output: A=0 when the live latched count is 1..4, A=1 otherwise.

diag_pit_d57_test:
        xra     a                       ; latch channel 0
        out     DIAG_PIT_CONTROL
        in      DIAG_PIT_COUNT0
        ora     a
        jz      diag_pit_d57_fail
        cpi     5
        jnc     diag_pit_d57_fail
        xra     a
        ret
diag_pit_d57_fail:
        mvi     a,1
        ret
