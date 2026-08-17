; Polled Juku keyboard for the RAM-owned BIOS.
; Copyright (c) 2026 Danila Sukharev
; BSD-2-Clause; see ../LICENSE-BSD-2-Clause.
;
; D26 port A selects one of the fifteen matrix columns. Port B returns the
; 74148 row code plus the dedicated active-low SHIFT and CTRL contacts. This
; implementation deliberately needs no RomBios state and no frame interrupt.

.ifndef ROMKEYBOARD
        cseg
        public  RKINIT
        public  RKSTAT
        public  RKIN
        public  RKCONFIG
.ifdef RAMKEYREMAP
        public  RKSETREMAP
.endif
.endif

KEYCOLPORT      equ     004h
KEYROWPORT      equ     005h

RKINIT:
        xra     a
        sta     RAMKEYDOWN
        sta     RAMKEYREADY
        sta     RAMKEYCHAR
.ifdef RAMKEYREMAP
        sta     RAMKEYREMAPCOUNT
.endif
        ret

; Return FFh if a translated key is pending, zero otherwise. A physical key
; must be released before another press is accepted, which supplies the
; debounce/one-character semantics CP/M expects from repeated CONST calls.
RKSTAT:
        lda     RAMKEYREADY
        ora     a
        jz      RAMKEYNEW
        mvi     a,0ffh
        ret
RAMKEYNEW:
        call    RAMKEYSCAN
        mov     e,a
        lda     RAMKEYDOWN
        ora     a
        jz      RAMKEYUP
        mov     a,e
        ora     a
        jnz     RAMKEYNONE
        sta     RAMKEYDOWN
        ret
RAMKEYUP:
        mov     a,e
        ora     a
        rz
        sta     RAMKEYCHAR
        mvi     a,1
        sta     RAMKEYDOWN
        sta     RAMKEYREADY
        mvi     a,0ffh
        ret
RAMKEYNONE:
        xra     a
        ret

RKIN:
        call    RKSTAT
        ora     a
        jz      RKIN
        xra     a
        sta     RAMKEYREADY
        lda     RAMKEYCHAR
        ret

; Return the raw eight-position S21 configuration byte in A. The keyboard
; drawing assigns S21.1..S21.8 to scan positions 8..15 and logical bits 7..0.
; A closed switch pulls CONTRDAT/PB5 low, hence the complement before testing
; bit 5. No debounce is needed: configuration is sampled only at startup.
RKCONFIG:
        push    b
        push    d
        mvi     b,8
        mvi     c,8
        mvi     d,0
RKCONFIG1:
        mov     a,b
        out     KEYCOLPORT
        in      KEYROWPORT
        cma
        ani     020h
        mov     e,a
        mov     a,d
        add     a
        mov     d,a
        mov     a,e
        ora     a
        jz      RKCONFIG2
        mov     a,d
        ori     1
        mov     d,a
RKCONFIG2:
        inr     b
        dcr     c
        jnz     RKCONFIG1
        mov     a,d
        pop     d
        pop     b
        ret

; Scan all columns and return one ASCII/control byte, or zero for no supported
; contact. The table is indexed as column*6 plus the drawing's encoder input.
RAMKEYSCAN:
        push    b
        push    d
        push    h
        mvi     b,0
RAMKEYCOL:
        mov     a,b
        out     KEYCOLPORT
        in      KEYROWPORT
        mov     c,a
        ani     00fh
        cpi     00fh
        jnz     RAMKEYFOUND
        inr     b
        mov     a,b
        cpi     15
        jc      RAMKEYCOL
        xra     a
        jmp     RAMKEYDONE

RAMKEYFOUND:
        ; HL = column*6.
        mov     l,b
        mvi     h,0
        dad     h
        mov     d,h
        mov     e,l
        dad     h
        dad     d

        ; Encoded low nibble is 0Eh,0Ch,...,04h for rows 0..5.
        mov     a,c
        cma
        ani     00eh
        rrc
        mov     e,a
        mvi     d,0
        dad     d
        lxi     d,RAMKEYTABLE
        dad     d
        mov     b,m
        mov     a,b
        ora     a
        jz      RAMKEYDONE

        ; CTRL turns ASCII letters into CP/M control codes.
        mov     a,c
        ani     080h
        jnz     RAMKEYSHIFT
        mov     a,b
        ani     05fh
        cpi     'A'
        jc      RAMKEYBASE
        cpi     'Z'+1
        jnc     RAMKEYBASE
        ani     01fh
        jmp     RAMKEYDONE

RAMKEYSHIFT:
        mov     a,c
        ani     040h
        jnz     RAMKEYBASE
        mov     a,b
        cpi     'a'
        jc      RAMKEYSHIFTPUNCT
        cpi     'z'+1
        jnc     RAMKEYSHIFTPUNCT
        sui     020h
        jmp     RAMKEYDONE
RAMKEYSHIFTPUNCT:
        lxi     h,RAMKEYSHIFTS
RAMKEYSHIFT1:
        mov     a,m
        ora     a
        jz      RAMKEYBASE
        cmp     b
        inx     h
        jz      RAMKEYSHIFTED
        inx     h
        jmp     RAMKEYSHIFT1
RAMKEYSHIFTED:
        mov     a,m
        jmp     RAMKEYDONE
RAMKEYBASE:
        mov     a,b
RAMKEYDONE:
.ifdef RAMKEYREMAP
        call    RAMKEYAPPLY
.endif
        pop     h
        pop     d
        pop     b
        ret

.ifdef RAMKEYREMAP
; Install up to four byte-to-byte substitutions. A is the pair count and HL
; points to interleaved input/output bytes. Zero disables remapping. The small
; copied table remains valid after a transient configuration utility exits.
RKSETREMAP:
        cpi     5
        jc      RKSETREMAP1
        mvi     a,4
RKSETREMAP1:
        sta     RAMKEYREMAPCOUNT
        ora     a
        rz
        mov     b,a
        lxi     d,RAMKEYREMAPTABLE
RKSETREMAP2:
        mov     a,m
        stax    d
        inx     h
        inx     d
        mov     a,m
        stax    d
        inx     h
        inx     d
        dcr     b
        jnz     RKSETREMAP2
        ret

; Apply the first matching substitution and otherwise return A unchanged.
RAMKEYAPPLY:
        mov     b,a
        lda     RAMKEYREMAPCOUNT
        ora     a
        mov     c,a
        mov     a,b
        rz
        lxi     h,RAMKEYREMAPTABLE
RAMKEYAPPLY1:
        cmp     m
        inx     h
        jz      RAMKEYREMAPPED
        inx     h
        dcr     c
        jnz     RAMKEYAPPLY1
        ret
RAMKEYREMAPPED:
        mov     a,m
        ret
.endif

; Rows are encoder inputs 0..5 (factory rows 5,4,6,2,1,3).
RAMKEYTABLE:
        db      0,'n',0,'y','6','h'
        db      0,'x',0,'w','2','s'
        db      0,'v',0,'r','4','f'
        db      0,0,0,09h,01bh,0
        db      0,'b',0,'t','5','g'
        db      0,'z',0,'q','1','a'
        db      0,'c',0,'e','3','d'
        db      0,'m',0,'u','7','j'
        db      0,0,07fh,']',0,0dh
        db      0,0,0,'[',0,0
        db      0,0,0,0,0,':'
        db      0,';',020h,05ch,'-',0
        db      0,'/',0,'p','0',0
        db      0,'.',08h,'o','9','l'
        db      0,',',0,'i','8','k'

; Interleaved unshifted/shifted punctuation pairs, zero terminated.
RAMKEYSHIFTS:
        db      '0','_','1','!','2',022h,'3','#','4','$'
        db      '5','%','6','&','7',027h,'8','(','9',')'
        db      '.','>',',','<','/','?',';','+','-','='
        db      ':','*',05ch,'^',0

.ifdef ROMKEYBOARD
; A resident-ROM wrapper supplies three bytes of mutable low-RAM state. The
; code and immutable translation tables can then be included verbatim in ROM.
RAMKEYDOWN     equ     ROMKEYSTATEBASE
RAMKEYREADY    equ     ROMKEYSTATEBASE+1
RAMKEYCHAR     equ     ROMKEYSTATEBASE+2
.ifdef RAMKEYREMAP
RAMKEYREMAPCOUNT equ   ROMKEYREMAPBASE
RAMKEYREMAPTABLE equ   ROMKEYREMAPBASE+1
.endif
ROMKEYEND:
.else
RAMKEYDOWN:     db      0
RAMKEYREADY:    db      0
RAMKEYCHAR:     db      0
.ifdef RAMKEYREMAP
RAMKEYREMAPCOUNT: db    0
RAMKEYREMAPTABLE: ds    8
.endif

        end
.endif
