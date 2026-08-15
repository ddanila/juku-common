; NetDisk v3 read-ahead client for RAM-owned Juku systems.
; Copyright (c) 2026 Danila Sukharev
; BSD-2-Clause; see ../LICENSE-BSD-2-Clause.
;
; Replies carry up to three translated CP/M records, a bounded encoding per
; record, and CRC-16/IBM over the complete DJ body. Consumers select one of
; the qualified workspace layouts at assembly time.

.ifndef ROMNETDISK
        cseg
        public  N3READ
        public  N3INV
        public  N3ENA
        extrn   NRWDISK
.endif

USARTDATA      equ     008h
USARTCTL       equ     009h
.ifdef ROMNETDISK
SEKDSK         equ     ROMNETSTATEBASE
SEKTRK         equ     ROMNETSTATEBASE+1
SEKSEC         equ     ROMNETSTATEBASE+3
MEMADR         equ     ROMNETSTATEBASE+4
.else
.ifdef CPM3ADAPTER
SEKDSK         equ     0b11ah
SEKTRK         equ     0b11bh
SEKSEC         equ     0b11dh
MEMADR         equ     0b12eh
.else
SEKDSK         equ     0d61ah
SEKTRK         equ     0d61bh
SEKSEC         equ     0d61dh
MEMADR         equ     0d62eh
.endif
.endif
DKRD           equ     011h
DKWR           equ     012h
DKRC           equ     013h
DKRA           equ     014h
DKWA           equ     015h

.ifndef ROMNETDISK
.ifdef CPM3ADAPTER
CACHE          equ     0b280h
.else
CACHE          equ     0d080h
.endif
.endif
SLOTSIZE       equ     131

N3ENA: sta     N3MODE
N3INV: xra     a
        sta     N3COUNT
        ret

N3READ:
        lda     N3MODE
        cpi     3
        jz      N3LOOK
        cpi     2
        mvi     a,DKRC
.ifdef ROMNETDISK
        jmp     N3ERROR
.else
        jz      NRWDISK
        mvi     a,DKRD
        jmp     NRWDISK
.endif

; Search all cached track/sector keys before asking the host again.
N3LOOK: lda     N3COUNT
        ora     a
        jz      N3MISS
        mov     b,a
        lda     N3DRIVE
        mov     c,a
        lda     SEKDSK
        cmp     c
        jnz     N3MISS
.ifdef ROMNETDISK
        lhld    N3CACHE
.else
        lxi     h,CACHE
.endif
N3LK1: lda     SEKTRK
        cmp     m
        jnz     N3NEXT
        inx     h
        lda     SEKTRK+1
        cmp     m
        dcx     h
        jnz     N3NEXT
        inx     h
        inx     h
        lda     SEKSEC
        cmp     m
        dcx     h
        dcx     h
        jz      N3COPY
N3NEXT:lxi     d,SLOTSIZE
        dad     d
        dcr     b
        jnz     N3LK1

N3MISS:
.ifdef ROMNETDISK
        mvi     a,DKRA
        sta     N3OP
N3START:
.endif
        lda     N3SEQ
        inr     a
        sta     N3SEQ
        mvi     a,3
        sta     N3TRIES
N3RETRY:
        mvi     a,035h
        out     USARTCTL
        mvi     b,0
        mvi     a,'J'
        call    N3SEND
        mvi     a,'D'
        call    N3SEND
.ifdef ROMNETDISK
        lda     N3OP
.else
        mvi     a,DKRA
.endif
        call    N3SEND
        lda     N3SEQ
        call    N3SEND
        lda     SEKDSK
        call    N3SEND
        lda     SEKTRK
        call    N3SEND
        lda     SEKTRK+1
        call    N3SEND
        lda     SEKSEC
        call    N3SEND
.ifdef ROMNETDISK
        lda     N3OP
        cpi     DKWA
        jnz     N3HEADER
        lhld    MEMADR
        mvi     d,128
N3WBYTE:
        mov     a,m
        call    N3SEND
        inx     h
        dcr     d
        jnz     N3WBYTE
N3HEADER:
.endif
        mov     a,b
        call    N3TX
.ifdef ROMNETDISK
        call    N3TURN
.else
        ; The legacy value is retained only so paced cosim can reproduce the
        ; physical CS00015 failure before accepting the turnaround fix.
.ifdef NETDISK_V3_LEGACY_DRAIN
        lxi     b,400
.else
        lxi     b,128
.endif
N3DRAIN:
        dcx     b
        mov     a,b
        ora     c
        jnz     N3DRAIN
        mvi     a,034h
        out     USARTCTL
.endif

N3SYNC:call    N3RX
        jc      N3BAD
        cpi     'D'
        jnz     N3SYNC
        call    N3RX
        jc      N3BAD
        cpi     'J'
        jnz     N3SYNC
        lxi     d,0
        mvi     a,'D'
        call    N3CRC
        mvi     a,'J'
        call    N3CRC
        call    N3RXC
        jc      N3BAD
        mov     c,a
        lda     N3SEQ
        cmp     c
        jnz     N3BAD
        call    N3RXC
        jc      N3BAD
        sta     N3STATUS
        call    N3RXC
        jc      N3BAD
        ora     a
        jz      N3END
        cpi     4
        jnc     N3BAD
        sta     N3COUNT
        mov     c,a
.ifdef ROMNETDISK
        lhld    N3CACHE
.else
        lxi     h,CACHE
.endif
N3REC: call    N3RXC
        jc      N3BAD
        mov     m,a
        inx     h
        call    N3RXC
        jc      N3BAD
        mov     m,a
        inx     h
        call    N3RXC
        jc      N3BAD
        mov     m,a
        inx     h
        call    N3RXC
        jc      N3BAD
        ora     a
        jz      N3RAW
        dcr     a
        jz      N3FILLRX
        dcr     a
        jz      N3E5
        dcr     a
        jnz     N3BAD
        call    N3RXC
        jc      N3BAD
        cpi     128
        jnc     N3BAD
        sta     N3PREFIX
        mov     b,a
N3PREF:mov     a,b
        ora     a
        jz      N3PREEND
        call    N3RXC
        jc      N3BAD
        mov     m,a
        inx     h
        dcr     b
        jmp     N3PREF
N3PREEND:
        call    N3RXC
        jc      N3BAD
        mov     b,a
        lda     N3PREFIX
        cma
        adi     129
        jmp     N3FIL1

N3RAW: mvi     b,128
N3RAW1:call    N3RXC
        jc      N3BAD
        mov     m,a
        inx     h
        dcr     b
        jnz     N3RAW1
        jmp     N3RDN
N3FILLRX:
        call    N3RXC
        jc      N3BAD
        jmp     N3FILL
N3E5:  mvi     a,0e5h
N3FILL:mov     b,a
        mvi     a,128
N3FIL1:mov     m,b
        inx     h
        dcr     a
        jnz     N3FIL1
N3RDN: dcr     c
        jnz     N3REC

N3END: call    N3RX
        jc      N3BAD
        cmp     d
        jnz     N3BAD
        call    N3RX
        jc      N3BAD
        cmp     e
        jnz     N3BAD
        lda     N3STATUS
        ora     a
        jnz     N3ERROR
.ifdef ROMNETDISK
        lda     N3OP
        cpi     DKWA
        jz      N3DONE
.endif
        lda     SEKDSK
        sta     N3DRIVE
.ifdef ROMNETDISK
        lhld    N3CACHE
.else
        lxi     h,CACHE
.endif
N3COPY:inx     h
        inx     h
        inx     h
        xchg
        lhld    MEMADR
        xchg
        mvi     b,128
N3CP1: mov     a,m
        stax    d
        inx     h
        inx     d
        dcr     b
        jnz     N3CP1
N3DONE:
        xra     a
        ret
N3ERROR:
        call    N3INV
        mvi     a,1
        ret

N3BAD: lda     N3TRIES
        dcr     a
        sta     N3TRIES
        jnz     N3RETRY
        jmp     N3ERROR

.ifdef ROMNETDISK
; V3 synchronous write-through reuses the CRC reply and retry state machine.
; Invalidate first so an uncertain result can never expose stale cached data.
N3WRITE:
        call    N3INV
        mvi     a,DKWA
        sta     N3OP
        jmp     N3START
.endif

N3SEND:mov     c,a
        xra     b
        mov     b,a
        mov     a,c
N3TX:  mov     c,a
N3TX1: in      USARTCTL
        ani     1
        jz      N3TX1
        mov     a,c
        out     USARTDATA
        ret

.ifdef ROMNETDISK
; TxRDY says only that the holding register is free. The checksum can still be
; behind one byte in the shifter, so cover two 8O1 characters before releasing
; TxEN. The legacy delay remains selectable for the physical-failure fixture.
N3TURN:
.ifdef NETDISK_V3_LEGACY_DRAIN
        lxi     b,400
.else
        lxi     b,128
.endif
N3TURN1:
        dcx     b
        mov     a,b
        ora     c
        jnz     N3TURN1
        mvi     a,034h
        out     USARTCTL
        ret
.endif
N3RX:  push    b
        lxi     b,0            ; 65536 status polls, about one second
N3RX1: in      USARTCTL
        ani     2
        jnz     N3RX2
        dcx     b
        mov     a,b
        ora     c
        jnz     N3RX1
        pop     b
        stc
        ret
N3RX2:
        in      USARTDATA
        pop     b
        ora     a              ; return data with carry clear
        ret
N3RXC: call    N3RX
        rc
        push    psw
        call    N3CRC
        pop     psw
        ret

; CRC-16/IBM, input byte A and running CRC DE; preserves HL.
N3CRC: push    h
        xra     e
        mov     l,a
        add     a
        push    psw
        xra     l
        mov     l,a
        pop     psw
        mvi     a,0
        jpe     N3CPE
        mvi     a,3
N3CPE: jnc     N3CNC
        xri     2
N3CNC: mov     h,a
        rar
        dad     h
        dad     h
        dad     h
        dad     h
        dad     h
        dad     h
        ora     l
        xra     d
        mov     e,a
        mov     d,h
        pop     h
        ret

.ifdef ROMNETDISK
N3MODE         equ     ROMNETSTATEBASE+6
N3SEQ          equ     ROMNETSTATEBASE+7
N3COUNT        equ     ROMNETSTATEBASE+8
N3DRIVE        equ     ROMNETSTATEBASE+9
N3STATUS       equ     ROMNETSTATEBASE+10
N3PREFIX       equ     ROMNETSTATEBASE+11
N3TRIES        equ     ROMNETSTATEBASE+12
N3CACHE        equ     ROMNETSTATEBASE+13
N3OP           equ     ROMNETSTATEBASE+15
ROMNETEND:
.else
N3MODE: db      1
N3SEQ:  db      0
N3COUNT:db      0
N3DRIVE:db      0
N3STATUS:db     0
N3PREFIX:db     0
N3TRIES:db      0
        end
.endif
