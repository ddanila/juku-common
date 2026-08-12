; Four bars of the familiar diagnostic riff, at 112 BPM.
;
; This data is assembler-neutral between NASM and zmac. Consumers provide the
; speaker driver and include this file where they want the table to reside.
; Each row is a D57 channel-1 divisor for its 2 MHz source clock, followed by
; sounding and silent eighth-note counts. The full table is 32 eighth notes.

note_table:
        dw      5102            ; G4   392.00 Hz
        db      1,1
        dw      4290            ; Bb4  466.20 Hz
        db      1,1
        dw      3822            ; C5   523.29 Hz
        db      2,1
        dw      5102            ; G4   392.00 Hz
        db      1,1
        dw      4290            ; Bb4  466.20 Hz
        db      1,1
        dw      3608            ; Db5  554.32 Hz
        db      1,0
        dw      3822            ; C5   523.29 Hz
        db      2,2
        dw      5102            ; G4   392.00 Hz
        db      1,1
        dw      4290            ; Bb4  466.20 Hz
        db      1,1
        dw      3822            ; C5   523.29 Hz
        db      2,1
        dw      4290            ; Bb4  466.20 Hz
        db      1,1
        dw      5102            ; G4   392.00 Hz
        db      5,2
