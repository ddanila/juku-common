; Origin-independent Juku speaker player for smoke-table.asm.
;
; Include smoke-table.asm after this file so note_table resolves locally.
;
; Interface for smoke_play:
;   input: none
;   output: the twelve-note phrase has completed and the speaker is silent
;   destroyed: A, BC, DE, HL, flags; interrupts are disabled
;   preserved: SP and all memory
;   hardware: D57 channel 1 only (ports 19h and 1Bh)

smoke_play:
        di
        lxi     h,note_table
        mvi     d,12

smoke_note_loop:
        mvi     a,076h          ; D57 ch1, LSB+MSB, mode 3
        out     01bh            ; PIT control
        mov     a,m             ; divisor low
        out     019h            ; channel 1 data
        inx     h
        mov     a,m             ; divisor high
        out     019h
        inx     h

        mov     e,m             ; sounding eighth-note units
        inx     h
smoke_tone_unit:
        lxi     b,22321         ; nominal 267.852 ms at 2 MHz
smoke_note_delay:
        dcx     b
        mov     a,b
        ora     c
        jnz     smoke_note_delay
        dcr     e
        jnz     smoke_tone_unit

        mvi     a,050h          ; D57 ch1, LSB-only, mode 0
        out     01bh
        mvi     a,1             ; static high = silence
        out     019h

        mov     e,m             ; silent eighth-note units
        inx     h
        mov     a,e
        ora     a
        jz      smoke_gap_done  ; D-flat leads directly into C
smoke_gap_unit:
        lxi     b,22321
smoke_gap_delay:
        dcx     b
        mov     a,b
        ora     c
        jnz     smoke_gap_delay
        dcr     e
        jnz     smoke_gap_unit

smoke_gap_done:
        dcr     d
        jnz     smoke_note_loop
        ret
